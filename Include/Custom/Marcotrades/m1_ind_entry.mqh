// Shared M1 inducement entry wait policy. No orders and no future candle data.
#ifndef MARCO_M1_IND_ENTRY_MQH
#define MARCO_M1_IND_ENTRY_MQH

enum ENUM_MARCO_IND_ENTRY_FILTER
  {
   IND_ENTRY_OFF = 0,        // Off
   IND_ENTRY_PIVOT = 1,      // Pivot inside setup TF or entry TF IND
   IND_ENTRY_PRICE = 2,      // Entry price inside setup TF or entry TF IND
   IND_ENTRY_EITHER = 3      // Pivot OR entry price inside either TF IND
  };

struct SMarcoIndWait
  {
   bool waiting;
   datetime since, rejectedPivot, rejectedAvailable;
   double low, high;
  };

struct SMarcoEntryInd
  {
   string id;
   bool bull, seen;
   double low, high;
   datetime available, until;
  };
struct SMarcoEntryChoch
  {
   bool bull;
   string name;
   datetime time, available, until;
  };

class CMarcoIndEntryFilter
  {
private:
   static ENUM_MARCO_IND_ENTRY_FILTER mode;
   SMarcoEntryInd zones[];
   SMarcoEntryChoch events[];
public:
   double lastLow, lastHigh;
   datetime knownThrough;
   CMarcoIndEntryFilter() { lastLow=0; lastHigh=0; knownThrough=0; }
   void Clear()
     { ArrayResize(zones,0); ArrayResize(events,0); lastLow=0; lastHigh=0; knownThrough=0; }
   static void Configure(ENUM_MARCO_IND_ENTRY_FILTER selected) { mode=selected; }
   static bool Enabled() { return mode!=IND_ENTRY_OFF; }
   static bool CheckPivot() { return mode==IND_ENTRY_PIVOT || mode==IND_ENTRY_EITHER; }
   static bool CheckPrice() { return mode==IND_ENTRY_PRICE || mode==IND_ENTRY_EITHER; }
   static void Reset(SMarcoIndWait &state)
     {
      state.waiting=false; state.since=0; state.rejectedPivot=0;
      state.rejectedAvailable=0; state.low=0; state.high=0;
     }

   void Begin(double low, double high)
     {
      lastLow=low; lastHigh=high;
      for(int i=0;i<ArraySize(zones);i++) zones[i].seen=false;
     }
   // Version bounds as they become known, so catch-up never uses future zones.
   void Zone(string id, bool bull, double low, double high, datetime available)
     {
      if(!Enabled()) return;
      for(int i=ArraySize(zones)-1;i>=0;i--)
         if(zones[i].id==id && zones[i].until==0)
           {
            if(zones[i].bull==bull && zones[i].low==low && zones[i].high==high)
              { zones[i].seen=true; return; }
            zones[i].until=available;
            break;
           }
      int n=ArraySize(zones); ArrayResize(zones,n+1);
      zones[n].id=id; zones[n].bull=bull; zones[n].low=low; zones[n].high=high;
      zones[n].available=available; zones[n].until=0; zones[n].seen=true;
     }
   void End(datetime available)
     {
      knownThrough=available;
      for(int i=0;i<ArraySize(zones);i++)
         if(!zones[i].seen && zones[i].until==0) zones[i].until=available;
     }
   void Observe(string name, datetime time, datetime available)
     {
      if(!Enabled() || time==0 || name=="") return;
      // Preserve event revisions: a CHoCH renamed as a sweep cannot release a wait.
      int n=ArraySize(events);
      for(int i=n-1;i>=0;i--)
         if(events[i].time==time)
           {
            if(events[i].name==name) return;
            events[i].until=available;
            break;
           }
      ArrayResize(events,n+1);
      events[n].name=name; events[n].bull=StringFind(name,"BL-")>=0;
      events[n].time=time; events[n].available=available; events[n].until=0;
     }
   bool Inside(bool bull, double price, datetime at, double &low, double &high, string &id)
     {
      bool found=false; low=0; high=0; id="";
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].bull!=bull || zones[i].available>at ||
            (zones[i].until>0 && at>=zones[i].until) ||
            price<zones[i].low || price>zones[i].high) continue;
         if(!found) { low=zones[i].low; high=zones[i].high; id=zones[i].id; }
         else { low=MathMin(low,zones[i].low); high=MathMax(high,zones[i].high); }
         found=true;
        }
      return found;
     }
   void Audit(string symbol, ENUM_TIMEFRAMES tf, bool bull, datetime now, double price,
              ENUM_TIMEFRAMES sourceTF=PERIOD_M1)
     {
      if(!CheckPrice()) return;
      int active=0, nearest=-1, ended=-1;
      double distance=0.0;
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].bull!=bull || zones[i].available>now) continue;
         if(zones[i].until>0 && now>=zones[i].until)
           {
            if(price>=zones[i].low && price<=zones[i].high &&
               (ended<0 || zones[i].until>zones[ended].until)) ended=i;
            continue;
           }
         active++;
         double gap=MathMax(zones[i].low-price,MathMax(price-zones[i].high,0.0));
         if(nearest<0 || gap<distance) { nearest=i; distance=gap; }
        }
      Print(StringFormat("[IND CHECK] %s setup=%s source=%s at=%s %s entry=%.8f known_through=%s active=%d nearest=%s bounds=[%.8f,%.8f] inside=%s",
                  symbol,EnumToString(tf),EnumToString(sourceTF),TimeToString(now,TIME_DATE|TIME_SECONDS),bull ? "BUY" : "SELL",price,
                  TimeToString(knownThrough,TIME_DATE|TIME_SECONDS),active,nearest<0 ? "none" : zones[nearest].id,
                  nearest<0 ? 0.0 : zones[nearest].low,nearest<0 ? 0.0 : zones[nearest].high,
                  nearest>=0 && distance==0.0 ? "yes" : "no"));
      if(ended>=0)
         PrintFormat("[IND CHECK] source=%s historical overlapping IND=%s bounds=[%.8f,%.8f] stopped being active at=%s; not an active entry blocker.",
                     EnumToString(sourceTF),zones[ended].id,zones[ended].low,zones[ended].high,TimeToString(zones[ended].until,TIME_DATE|TIME_SECONDS));
     }
   static void Wait(SMarcoIndWait &state, datetime pivot, datetime available,
                    datetime now, double low, double high)
     {
      if(state.waiting) { low=MathMin(low,state.low); high=MathMax(high,state.high); }
      state.waiting=true; state.since=now; state.rejectedPivot=pivot;
      state.rejectedAvailable=available; state.low=low; state.high=high;
     }
   bool SkipPivot(SMarcoIndWait &state, bool bull, datetime pivot, double price,
                  datetime available, string &id, ENUM_TIMEFRAMES pivotTF=PERIOD_M1)
     {
      double low=0,high=0;
      // Was the pivot formed inside an IND known at that candle's close?
      // Do not erase that fact if the IND is swept before pivot confirmation.
      datetime formed=pivot+PeriodSeconds(pivotTF);
      if(formed>available) formed=available;
      if(!CheckPivot() || !Inside(bull,price,formed,low,high,id)) return false;
      Wait(state,pivot,available,available,low,high);
      return true;
     }
   bool SkipPrice(SMarcoIndWait &state, bool bull, datetime pivot, datetime available,
                  datetime now, double price, string &id)
     {
      double low=0,high=0;
      if(!CheckPrice() || !Inside(bull,price,now,low,high,id)) return false;
      Wait(state,pivot,available,now,low,high);
      return true;
     }
   bool Ready(const SMarcoIndWait &state, bool bull, datetime pivot, double price,
              datetime available, double setupLow, double setupHigh, datetime now=0)
     {
      if(!Enabled() || !state.waiting) return true;
      if(pivot<=state.rejectedPivot || available<=state.rejectedAvailable || pivot<state.since) return false;
      // The original blocking IND remains the threshold even after it is swept.
      if(bull ? (price>=state.low || price<=setupLow) : (price<=state.high || price>=setupHigh)) return false;
      datetime knownAt=now>0 ? now : available;
      int latest=-1;
      for(int i=ArraySize(events)-1;i>=0;i--)
        {
         if(events[i].available>knownAt || (events[i].until>0 && knownAt>=events[i].until) ||
            StringFind(events[i].name,"CHoCH")<0) continue;
         if(latest<0 || events[i].time>events[latest].time) latest=i;
        }
      // A newer opposing CHoCH cancels the older directional permission, including
      // one arriving between pivot formation and confirmation or order submission.
      return latest>=0 && events[latest].bull==bull && events[latest].available>state.since &&
             events[latest].available<=pivot;
     }
   static bool Broken(const SMarcoIndWait &state, bool bull, double low, double high,
                      double setupLow, double setupHigh)
     {
      return Enabled() && state.waiting && (bull ? low<setupLow : high>setupHigh);
     }
  };
ENUM_MARCO_IND_ENTRY_FILTER CMarcoIndEntryFilter::mode=IND_ENTRY_OFF;
#endif
