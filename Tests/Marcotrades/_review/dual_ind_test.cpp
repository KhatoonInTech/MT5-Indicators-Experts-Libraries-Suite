
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
using string=std::string;using datetime=long long;using uint=unsigned int;using ENUM_TIMEFRAMES=int;
enum {PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M5=5,ENTRY_TF_M1=1,ENTRY_TF_LB=0,
 SYMBOL_DIGITS=1,TIME_DATE=1,TIME_SECONDS=2,TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,
 TRADE_RETCODE_PLACED=10008,TRADE_RETCODE_TIMEOUT=10012};
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}double MathAbs(double a){return std::abs(a);}
double NormalizeDouble(double x,int d){double scale=std::pow(10.,d);return std::round(x*scale)/scale;}
int PeriodSeconds(int tf){return tf*60;}int SymbolInfoInteger(string,int){return 2;}
int StringFind(string a,string b){auto p=a.find(b);return p==string::npos?-1:int(p);}
string EnumToString(int a){return std::to_string(a);}string TimeToString(datetime a,int){return std::to_string(a);}
template<class...T>void PrintFormat(T...){}
template<class...T>void Print(T...){}
template<class...T>string StringFormat(T...){return "audit";}
template<class T>void ZeroMemory(T &v){v=T{};}
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
struct Point {datetime time;double price;};
struct Pivot {bool isHigh;Point end;string ln="confirmed";};
struct PivotList {std::vector<Pivot*> values;int Total(){return values.size();}Pivot* At(int i){return values.at(i);}};
struct ZigZag {PivotList pivots;Pivot* projection=nullptr;Pivot* pending=nullptr;
 void update(double,double,datetime,long,int,bool,bool){if(pending){pivots.values.push_back(pending);pending=nullptr;}}};
template<class T>struct List {std::vector<T> values;int Total(){return values.size();}T At(int i){return values.at(i);}};
struct CInducementZone {string id;bool isBullish,isInducement,isMitigated;double zoneLow,zoneHigh;};
struct CInducementLogic {List<CInducementZone*> m_zones;};
struct CMarketStructure {List<string> all_event_names;List<datetime> all_event_times;};
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
   std::vector<SMarcoEntryInd> zones;
   std::vector<SMarcoEntryChoch> events;
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


struct MqlRates {datetime time;double open,high,low,close;};
int iBarShift(string,int,datetime,bool){return -1;}
int CopyRates(string,int,int,int,std::vector<MqlRates>&){return 0;}
// Entry execution policy only. ZigZag calculation and confirmation are unchanged.
#ifndef MARCO_PIVOT_ENTRY_MQH
#define MARCO_PIVOT_ENTRY_MQH

enum ENUM_MARCO_ENTRY_TIMING
  {
   ENTRY_AFTER_CONFIRMATION = 0, // Next candle open after confirmation (existing)
   ENTRY_PIVOT_CANDLE_EDGE = 1   // High-pivot candle LOW / low-pivot candle HIGH
  };

struct SMarcoPivotEntry
  {
   datetime pivot, confirmed;
   double level;
   bool nextOpen;
  };

// Separate from the prepared price level: keep this watermark when a pending
// pivot is discarded, so an older historical pivot cannot become its replacement.
struct SMarcoPivotWatch
  {
   datetime pivot, confirmed;
   double price;
   bool invalid;
  };

class CMarcoPivotEntry
  {
private:
   static ENUM_MARCO_ENTRY_TIMING mode;
public:
   static void Configure(ENUM_MARCO_ENTRY_TIMING value) { mode=value; }
   static bool Enabled() { return mode==ENTRY_PIVOT_CANDLE_EDGE; }
   static bool Passed(bool buy, double price, double level)
     { return buy ? price>=level : price<=level; }
   static bool Waiting(const SMarcoPivotEntry &state)
     { return Enabled() && state.confirmed>0 && !state.nextOpen; }

   static bool Prepare(SMarcoPivotEntry &state, string symbol, ENUM_TIMEFRAMES tf,
                       bool buy, datetime pivot, datetime confirmed, datetime now)
     {
      if(!Enabled()) return true;
      if(pivot<=0 || confirmed<=0 || confirmed>now) return false;
      if(state.pivot==pivot && state.confirmed==confirmed && state.level>0) return true;
      std::vector<MqlRates> source, confirmation;
      int p=iBarShift(symbol,tf,pivot,true);
      int c=iBarShift(symbol,tf,confirmed-1,false);
      if(p<0 || c<0 || CopyRates(symbol,tf,p,1,source)!=1 ||
         CopyRates(symbol,tf,c,1,confirmation)!=1) return false;
      int seconds=PeriodSeconds(tf);
      // Never read the current/unclosed candle or substitute a nearby pivot candle.
      if(source[0].time!=pivot || source[0].time+seconds>confirmed ||
         confirmation[0].time+seconds!=confirmed) return false;
      double level=buy ? source[0].high : source[0].low;
      if(level<=0 || confirmation[0].close<=0) return false;
      state.pivot=pivot; state.confirmed=confirmed; state.level=level;
      state.nextOpen=Passed(buy,confirmation[0].close,level);
      PrintFormat("[PIVOT ENTRY] %s %s %s pivot=%s confirmed=%s level=%.8f confirmation_close=%.8f action=%s",
                  symbol,EnumToString(tf),buy ? "BUY" : "SELL",TimeToString(pivot,TIME_DATE|TIME_SECONDS),
                  TimeToString(confirmed,TIME_DATE|TIME_SECONDS),level,confirmation[0].close,
                  state.nextOpen ? "NEXT_CANDLE_OPEN" : "WAIT_FOR_LEVEL");
      return true;
     }

   // Candle levels are Bid-chart levels. A buy executes at Ask after Bid reaches
   // the pivot candle high; a sell executes at Bid after Bid reaches its low.
   static bool Quote(const SMarcoPivotEntry &state, bool buy, double bid)
     { return !Waiting(state) || Passed(buy,bid,state.level); }

   // Use the existing exit replay path: bullish candle O-L-H-C, bearish O-H-L-C.
   // Return only the portion AFTER the entry-level crossing.
   // Signals/zone snapshots must already have been frozen at the bar's open.
   static bool Bar(const SMarcoPivotEntry &state, bool buy, double open, double high,
                   double low, double close, double &fill, bool &intrabar,
                   double &afterHigh, double &afterLow)
     {
      fill=open; intrabar=false; afterHigh=high; afterLow=low;
      if(!Waiting(state) || Passed(buy,open,state.level)) return true;
      if(!Passed(buy,buy ? high : low,state.level)) return false;
      fill=state.level; intrabar=true;
      if(buy && close>=open) afterLow=MathMin(fill,close);
      else if(!buy && close<open) afterHigh=MathMax(fill,close);
      return true;
     }
  };
ENUM_MARCO_ENTRY_TIMING CMarcoPivotEntry::mode=ENTRY_AFTER_CONFIRMATION;
#endif

struct Context {CMarcoIndEntryFilter indEntry;int rejectionHistory=0;void Update(datetime,double,double,double,double,ZigZag*,double){}};
struct SLivePivotConfirmation {datetime pivotTime=0;double price=0;bool isHigh=false;datetime availableTime=0;};
struct Zone {SMarcoPivotWatch pivotWatch{};SMarcoPivotEntry pivotEntry{};SMarcoIndWait indWait{};string id="LB_BEAR_1794450000";bool isBullish=false,isMitigated=false;int touchCount=0;
 datetime confirmedTime=13*3600+5*60,entryTriggerTime=13*3600+5*60,m1TouchTime=0,m1ConfirmTime=0,m1PivotTime=0,mitigationTime=0;
 double zoneLow=7607.79,zoneHigh=7612.80,m1PivotPrice=0;};
enum ENUM_TRADE_REJECTION_ACTION { TRADE_ALLOW, TRADE_SKIP_NOW, TRADE_RETIRE_ZONE };
enum ENUM_TRADE_REJECTION_REASON
  {
   REJECT_NONE, REJECT_USED, REJECT_SESSION, REJECT_UNCONFIRMED,
   REJECT_PRECONF_TOUCH, REJECT_BOUNDARY, REJECT_MULTIPLE_PIVOTS, REJECT_EXPIRED,
   REJECT_OPPOSING_ORIGIN, REJECT_OPPOSING_CHOCH_LB, REJECT_OVERLAP,
   REJECT_SL, REJECT_NO_TP, REJECT_RR, REJECT_EXECUTION, REJECT_FORMATION
  };

struct STradeRejection
  {
   ENUM_TRADE_REJECTION_ACTION action;
   ENUM_TRADE_REJECTION_REASON reason;
   ENUM_TIMEFRAMES sourceTF;
   string opposingId;
   datetime eventTime;
  };

class CTradeRejection
  {
public:
   static STradeRejection Decision(ENUM_TRADE_REJECTION_ACTION action, ENUM_TRADE_REJECTION_REASON reason)
     {
      STradeRejection result;
      result.action = action; result.reason = reason;
      result.sourceTF = PERIOD_CURRENT; result.opposingId = ""; result.eventTime = 0;
      return result;
     }
   static bool Used(int touches, bool mitigated) { return touches > 0 || mitigated; }
   static void Consume(int &touches, int count = 1) { touches = MathMax(touches, count); }
   static void Mitigate(bool &mitigated, datetime &at, datetime now) { mitigated = true; at = now; }
   static void Retire(int &touches, bool &mitigated, datetime &at, datetime now)
     {
      if(Used(touches, mitigated)) return;
      touches++;
      Mitigate(mitigated, at, now);
     }
   static bool OutsideSession(datetime origin, datetime created, datetime confirmed, datetime start)
     { return origin < start || created < start || confirmed < start; }
   static bool Unconfirmed(datetime confirmedBar, int seconds, datetime now)
     { return now < confirmedBar + seconds; }
   static bool PreConfirmation(bool risky, int priceTouches, int pivotTouches, bool broken)
     { return broken || (!risky && (priceTouches > 0 || pivotTouches > 0)); }
   static bool BoundaryBroken(bool bull, double low, double high, double zLow, double zHigh, double buffer)
     { return bull ? low < zLow - buffer : high > zHigh + buffer; }
   static bool Intersects(double low, double high, double zLow, double zHigh)
     { return low <= zHigh && high >= zLow; }
   static bool NearEntry(bool bull, double low, double high, double zLow, double zHigh, double pip, int digits)
     { return bull ? low <= NormalizeDouble(zHigh + pip, digits) && high >= zLow :
                    high >= NormalizeDouble(zLow - pip, digits) && low <= zHigh; }
   static bool DirectEntry(bool bull, double bid, double ask, double zLow, double zHigh, double buffer)
     { return bull ? ask <= zHigh && bid >= zLow - buffer : bid >= zLow && ask <= zHigh + buffer; }
   static bool MultiplePivots(int count) { return count > 1; }
   static bool NeedsPivot(int count) { return count != 1; }
   static bool Expired(datetime now, datetime confirmation, int seconds)
     { return now > confirmation + seconds; }
   static bool M1Expired(datetime lastClosedBar, datetime confirmation)
     { return lastClosedBar > confirmation - PeriodSeconds(PERIOD_M1); }
   static bool M1Pivot(bool bull, bool high, datetime pivot, double price, datetime touch,
                       datetime available, datetime now, double zLow, double zHigh)
     { return high != bull && pivot >= touch - touch % 60 && price >= zLow && price <= zHigh && available > touch && available <= now; }
   static bool OriginInside(datetime origin, double price, datetime created, datetime mitigation,
                            int seconds, double zLow, double zHigh, double buffer)
     {
      bool validTime = origin >= created && (mitigation == 0 || origin <= mitigation + seconds);
      return (validTime || origin == created) && price >= zLow - buffer && price <= zHigh + buffer;
     }
   // Direction is an unconditional symbol-level veto, independent of overlap/TP progress.
   // Callers restrict this to positions that are still open on the candidate symbol.
   static bool OppositeDirection(bool candidateBull, int openDirection)
     { return openDirection == (candidateBull ? -1 : 1); }
   static bool Overlap(bool allowed, double tpDistance, double covered)
     { return !allowed || tpDistance <= 0.0 || covered < 0.5 * tpDistance; }
   static bool InvalidSL(bool bull, double entry, double sl)
     { return bull ? sl >= entry : sl <= entry; }
   static bool StopTooClose(double risk, double minimum) { return risk <= minimum || risk <= 0.0; }
   static bool NoTP(double tp) { return tp == 0.0; }
   static bool LowRR(bool enabled, bool structural, double rr, double minimum)
     { return enabled && structural && rr < minimum; }
   static bool SizingInputs(double free, double risk, double step, double minimum, double maximum)
     { return free > 0 && risk > 0 && step > 0 && minimum > 0 && maximum >= minimum; }
   static bool MarginFits(double needed, double free) { return needed <= free * 0.90; }
   static bool CheckPassed(bool checked, uint code)
     { return checked && (code == 0 || code == TRADE_RETCODE_DONE); }
   static bool ReserveFits(double remaining, double free) { return remaining + 1e-8 >= free * 0.10; }
   static bool ExecutionAllowed(bool terminal, bool program, bool account, bool expert, datetime now, datetime next)
     { return terminal && program && account && expert && now >= next; }
   static bool ConsumeOrderResult(uint code)
     { return code == TRADE_RETCODE_PLACED || code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL || code == TRADE_RETCODE_TIMEOUT; }
   static bool WrongOrigin(bool strict, bool bull, bool pivotHigh) { return strict && bull == pivotHigh; }
   static bool ActiveInducementOverlap(bool bull, double low, double high, datetime origin,
                                       bool indBull, double indLow, double indHigh, datetime formed, datetime mitigated)
     { return bull == indBull && formed <= origin && (mitigated == 0 || mitigated >= origin) && Intersects(low, high, indLow, indHigh); }
   static bool Clustered(double low, double high, double otherLow, double otherHigh, double tolerance)
     { return Intersects(low, high, otherLow - tolerance, otherHigh + tolerance); }
   static bool SameLB(bool bull, datetime origin, double low, double high, bool otherBull,
                      datetime otherOrigin, double otherLow, double otherHigh, double tolerance)
     { return bull == otherBull && (origin == otherOrigin || (MathAbs(low-otherLow) <= tolerance && MathAbs(high-otherHigh) <= tolerance)); }
   static int RequiredStructures(int minutes) { return minutes <= 5 ? 5 : 3; }
  };


class Engine {public:
 string m_symbol="US500m";int m_entryTF=ENTRY_TF_M1,m_tradeTF=PERIOD_M5,m_entryBarCount=0,m_htf_lb_count=1;
 double m_slBufferPips=50;datetime m_last_entry_bar=0;ZigZag zigzag;ZigZag* zzEntry=&zigzag;
 Context* m1LBContext=nullptr;std::vector<Zone> m_htf_lbs{Zone{}};
 CMarcoIndEntryFilter m_setupIndEntry;
 std::vector<SLivePivotConfirmation> m_m1PivotConfirmations,m_pivotConfirmations;bool opposing=false;
 double GetPipSize(string){return .10;}
 bool BlockM1OpposingLeg(int k,datetime now){if(!opposing)return false;
 CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,now);return true;}
 void AuditChochTouches(datetime,double,double,datetime,ZigZag*,int,int){}
   void              CaptureM1PivotConfirmations(ZigZag* zz, datetime availableTime)
     {
      int oldSize = ArraySize(m_m1PivotConfirmations);
      int count = zz->pivots.Total();
      ArrayResize(m_m1PivotConfirmations, count);
      for(int p = 0; p < count; p++)
        {
         Pivot* pv = (Pivot*)zz->pivots.At(p);
         if(pv == NULL || pv == zz->projection || StringFind(pv->ln, "ZZ_Proj") >= 0)
           {
            m_m1PivotConfirmations[p].availableTime = 0;
            continue;
           }
         if(p >= oldSize || m_m1PivotConfirmations[p].availableTime == 0 ||
            m_m1PivotConfirmations[p].pivotTime != pv->end.time ||
            m_m1PivotConfirmations[p].price != pv->end.price ||
            m_m1PivotConfirmations[p].isHigh != pv->isHigh)
           {
            m_m1PivotConfirmations[p].pivotTime = pv->end.time;
            m_m1PivotConfirmations[p].price = pv->end.price;
            m_m1PivotConfirmations[p].isHigh = pv->isHigh;
            m_m1PivotConfirmations[p].availableTime = availableTime;
           }
        }
     }
   void              FeedM1EntryBar(datetime barTime, double open, double high, double low, double close, long volume)
     {
      if(zzEntry == NULL || barTime <= m_last_entry_bar || GetPipSize(m_symbol) <= 0.0)
         return;
      zzEntry->update(high, low, barTime, volume, m_entryBarCount++, true, false);
      if(m1LBContext != NULL)
         m1LBContext->Update(barTime, open, high, low, close, zzEntry, GetPipSize(m_symbol));
      CaptureM1PivotConfirmations(zzEntry, barTime + PeriodSeconds(PERIOD_M1));
      m_last_entry_bar = barTime;
      if(CMarcoPivotEntry::Enabled())
         for(int k=0;k<m_htf_lb_count;k++)
           {
            if(ObservePivotEntryRange(k,barTime,low,high)) continue;
            datetime pivot=0,confirmed=0; double price=0;
            if(m_entryTF==ENTRY_TF_M1 && m_htf_lbs[k].m1TouchTime>0)
               GetLatestEntryPivot(k,barTime+PeriodSeconds(PERIOD_M1),zzEntry,true,pivot,price,confirmed);
           }
      if(m1LBContext != NULL)
         AuditChochTouches(barTime, low, high, barTime + PeriodSeconds(PERIOD_M1), zzEntry,
                          PERIOD_M1, m1LBContext->rejectionHistory);
      // Latch the first eligible pivot before a later catch-up candle can replace it.
      for(int k = 0; k < m_htf_lb_count; k++)
        {
         if(m_htf_lbs[k].entryTriggerTime <= 0)
            continue;
         if(CheckIndWaitBoundary(k,barTime+PeriodSeconds(PERIOD_M1),low,high)) continue;
         if(m_entryTF != ENTRY_TF_M1) continue;
         if(CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated) ||
            barTime < m_htf_lbs[k].entryTriggerTime + PeriodSeconds(m_tradeTF))
            continue;
         // Match the simulator's closed-M1 range checks. A scan of the current
         // quote can miss a brief wick touch (or a wick that invalidates the LB).
         if(CTradeRejection::BoundaryBroken(m_htf_lbs[k].isBullish, low, high,
                                           m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh,
                                           m_slBufferPips * GetPipSize(m_symbol)))
           {
            CTradeRejection::Mitigate(m_htf_lbs[k].isMitigated, m_htf_lbs[k].mitigationTime, barTime);
            continue;
           }
         ArmM1Entry(k, barTime, low, high);
         if(m_htf_lbs[k].m1TouchTime == 0 || m_htf_lbs[k].m1ConfirmTime != 0)
            continue;
         datetime pivotTime = 0, confirmTime = 0;
         double pivotPrice = 0.0;
         GetM1EntryPivot(k, barTime + PeriodSeconds(PERIOD_M1), pivotTime, pivotPrice, confirmTime);
        }
     }
   void              ArmM1Entry(int k, datetime sampleTime, double sampleLow, double sampleHigh)
     {
      if(m_entryTF != ENTRY_TF_M1 || m_htf_lbs[k].m1TouchTime != 0 ||
         m_htf_lbs[k].entryTriggerTime <= 0 ||
         CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated) ||
         sampleTime < m_htf_lbs[k].entryTriggerTime + PeriodSeconds(m_tradeTF))
         return;
      double pip = GetPipSize(m_symbol); // Exactly one pip, independent of the SL buffer.
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      bool near = CTradeRejection::NearEntry(m_htf_lbs[k].isBullish, sampleLow, sampleHigh,
                            m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh, pip, digits);
      if(!near)
         return;
      m_htf_lbs[k].m1TouchTime = sampleTime;
      PrintFormat("[M1 ARMED] %s %s LB=%s touch=%s zone=[%.8f, %.8f]",
                  m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id, TimeToString(sampleTime, TIME_DATE|TIME_SECONDS),
                  m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh);
     }
   bool CheckIndWaitBoundary(int k, datetime now, double low, double high)
     {
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return false;
      if(!CMarcoIndEntryFilter::Broken(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,
                                       low,high,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh)) return false;
      CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,now);
      PrintFormat("[M1 IND WAIT CANCELLED] %s %s LB=%s: setup outer boundary breached.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id);
      return true;
     }
   void CaptureSetupIndContext(CInducementLogic* ind, CMarketStructure* ms,
                               datetime available, double low, double high)
     {
      if(!CMarcoIndEntryFilter::Enabled()) return;
      m_setupIndEntry.Begin(low,high);
      for(int z=0;z<ind->m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)ind->m_zones.At(z);
         if(zone!=NULL && zone->isInducement && !zone->isMitigated)
            m_setupIndEntry.Zone(zone->id,zone->isBullish,zone->zoneLow,zone->zoneHigh,available);
        }
      m_setupIndEntry.End(available);
      int n=ms->all_event_names.Total();
      for(int e=MathMax(0,n-3);e<n;e++)
         m_setupIndEntry.Observe(ms->all_event_names.At(e),(datetime)ms->all_event_times.At(e),available);
     }
   bool IndEntryReady(int k, datetime pivot, double price, datetime available, datetime now)
     {
      if(!CMarcoIndEntryFilter::Enabled() || !m_htf_lbs[k].indWait.waiting) return true;
      if(m_entryTF==ENTRY_TF_M1)
         return m1LBContext!=NULL && m1LBContext->indEntry.Ready(m_htf_lbs[k].indWait,
                   m_htf_lbs[k].isBullish,pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
      return m_setupIndEntry.Ready(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,
                   pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
     }
   bool SkipIndPivot(int k, datetime pivot, double price, datetime available)
     {
      if(!CMarcoIndEntryFilter::CheckPivot() || pivot<=0) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      ENUM_TIMEFRAMES entryTF=m_entryTF==ENTRY_TF_M1 ? PERIOD_M1 : m_tradeTF;
      string id="";
      if(m_setupIndEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      // Same timeframe is checked once. Both blockers contribute to the wait bounds.
      if(entryTF!=m_tradeTF && m1LBContext!=NULL &&
         m1LBContext->indEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(entryTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      return blocked;
     }
   bool SkipIndEntryPrice(int k, datetime now, double entry, datetime pivot=0, datetime confirmed=0)
     {
      if(!CMarcoIndEntryFilter::CheckPrice()) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      if(m_entryTF==ENTRY_TF_M1)
        { pivot=m_htf_lbs[k].m1PivotTime; confirmed=m_htf_lbs[k].m1ConfirmTime; }
      string id="";
      m_setupIndEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,m_tradeTF);
      if(m_setupIndEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
        {
         blocked=true;
         PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,entry);
        }
      if(m_entryTF==ENTRY_TF_M1 && m_tradeTF!=PERIOD_M1 && m1LBContext!=NULL)
        {
         m1LBContext->indEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,PERIOD_M1);
         if(m1LBContext->indEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
           {
            blocked=true;
            PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                        m_symbol,EnumToString(m_tradeTF),EnumToString(PERIOD_M1),id,entry);
           }
        }
      if(!blocked) return false;
      PrintFormat("[IND WAIT] %s setup=%s LB=%s: waiting for a new %s CHoCH and pivot beyond blocking INDs.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                  EnumToString(m_entryTF==ENTRY_TF_M1 ? PERIOD_M1 : m_tradeTF));
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
      if(m_entryTF==ENTRY_TF_M1 && m1LBContext!=NULL)
         CheckIndWaitBoundary(k,now,m1LBContext->indEntry.lastLow,m1LBContext->indEntry.lastHigh);
      else CheckIndWaitBoundary(k,now,m_setupIndEntry.lastLow,m_setupIndEntry.lastHigh);
      return true;
     }
   bool GetSetupIndWaitPivot(int k, datetime now, ZigZag* zz,
                             datetime &pivot, double &price, datetime &confirmed)
     {
      pivot=0; price=0; confirmed=0;
      if(zz==NULL) return false;
      for(int p=0;p<zz->pivots.Total() && p<ArraySize(m_pivotConfirmations);p++)
        {
         Pivot* pv=(Pivot*)zz->pivots.At(p);
         if(pv==NULL || pv==zz->projection || StringFind(pv->ln,"ZZ_Proj")>=0 ||
            pv->isHigh==m_htf_lbs[k].isBullish) continue;
         datetime available=m_pivotConfirmations[p].availableTime;
         if(available<=0 || available>now || !IndEntryReady(k,pv->end.time,pv->end.price,available,now)) continue;
         if(confirmed==0 || available<confirmed)
           { pivot=pv->end.time; price=pv->end.price; confirmed=available; }
        }
      return confirmed>0;
     }
   void DiscardPivotEntry(int k, datetime now, string reason)
     {
      if(!m_htf_lbs[k].pivotWatch.invalid && m_htf_lbs[k].pivotWatch.confirmed>0)
         PrintFormat("[PIVOT DISCARDED] %s setup=%s LB=%s pivot=%s price=%.8f at=%s reason=%s; waiting for latest confirmed pivot",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                     TimeToString(m_htf_lbs[k].pivotWatch.pivot,TIME_DATE|TIME_SECONDS),m_htf_lbs[k].pivotWatch.price,
                     TimeToString(now,TIME_DATE|TIME_SECONDS),reason);
      m_htf_lbs[k].pivotWatch.invalid=true;
      ZeroMemory(m_htf_lbs[k].pivotEntry);
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
     }
   bool ObservePivotEntryRange(int k, datetime sampleTime, double low, double high)
     {
      if(!CMarcoPivotEntry::Enabled() || m_htf_lbs[k].entryTriggerTime<=0 ||
         sampleTime<m_htf_lbs[k].entryTriggerTime+PeriodSeconds(m_tradeTF)) return false;
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return true;
      bool bull=m_htf_lbs[k].isBullish;
      // A waiting edge entry never receives the SL buffer as extra LB validity.
      if(CTradeRejection::BoundaryBroken(bull,low,high,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,0))
        {
         DiscardPivotEntry(k,sampleTime,"SETUP_LB_MITIGATED");
         CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,sampleTime);
         PrintFormat("[PIVOT WAIT CANCELLED] %s setup=%s LB=%s: setup LB boundary broken at %s",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,TimeToString(sampleTime,TIME_DATE|TIME_SECONDS));
         return true;
        }
      if(m_htf_lbs[k].pivotWatch.confirmed>0 && sampleTime>=m_htf_lbs[k].pivotWatch.confirmed &&
         (bull ? low<m_htf_lbs[k].pivotWatch.price : high>m_htf_lbs[k].pivotWatch.price))
         DiscardPivotEntry(k,sampleTime,"PIVOT_EXTREME_BROKEN");
      return false;
     }
   bool GetLatestEntryPivot(int k, datetime now, ZigZag* zz, bool m1,
                            datetime &pivot, double &price, datetime &confirmed)
     {
      pivot=0; price=0; confirmed=0;
      if(zz==NULL || CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return false;
      int selected=-1; datetime latest=0, known=0;
      int count=m1 ? ArraySize(m_m1PivotConfirmations) : ArraySize(m_pivotConfirmations);
      for(int p=0;p<zz->pivots.Total() && p<count;p++)
        {
         Pivot* pv=(Pivot*)zz->pivots.At(p);
         if(pv==NULL || pv==zz->projection || StringFind(pv->ln,"ZZ_Proj")>=0 ||
            pv->isHigh==m_htf_lbs[k].isBullish) continue;
         datetime available=m1 ? m_m1PivotConfirmations[p].availableTime : m_pivotConfirmations[p].availableTime;
         datetime at=m1 ? m_m1PivotConfirmations[p].pivotTime : m_pivotConfirmations[p].pivotTime;
         double value=m1 ? m_m1PivotConfirmations[p].price : m_pivotConfirmations[p].price;
         bool high=m1 ? m_m1PivotConfirmations[p].isHigh : m_pivotConfirmations[p].isHigh;
         // The availability record must describe this exact current endpoint.
         if(available<=0 || available>now || at!=pv->end.time || value!=pv->end.price || high!=pv->isHigh) continue;
         if(selected<0 || at>latest || (at==latest && available>known))
           { selected=p; latest=at; known=available; }
        }
      if(selected<0)
        { DiscardPivotEntry(k,now,"NO_CURRENT_CONFIRMED_PIVOT"); return false; }
      Pivot* current=(Pivot*)zz->pivots.At(selected);
      SMarcoPivotWatch previous=m_htf_lbs[k].pivotWatch;
      bool same=previous.pivot==latest && previous.price==current->end.price && previous.confirmed==known;
      if(previous.confirmed>0 && (latest<previous.pivot || known<previous.confirmed))
        { DiscardPivotEntry(k,now,"PIVOT_REMOVED_NO_NEW_CONFIRMATION"); return false; }
      if(same && previous.invalid) return false;
      if(!same)
        {
         if(previous.confirmed>0)
            PrintFormat("[PIVOT REPLACED] %s setup=%s LB=%s old=%s/%.8f latest=%s/%.8f confirmed=%s; recalculate entry edge and SL",
                        m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                        TimeToString(previous.pivot,TIME_DATE|TIME_SECONDS),previous.price,
                        TimeToString(latest,TIME_DATE|TIME_SECONDS),current->end.price,TimeToString(known,TIME_DATE|TIME_SECONDS));
         ZeroMemory(m_htf_lbs[k].pivotEntry);
         m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
         m_htf_lbs[k].pivotWatch.pivot=latest;
         m_htf_lbs[k].pivotWatch.price=current->end.price;
         m_htf_lbs[k].pivotWatch.confirmed=known;
         m_htf_lbs[k].pivotWatch.invalid=false;
        }
      bool bull=m_htf_lbs[k].isBullish;
      // Pick the latest endpoint FIRST. Never fall back to an older in-zone pivot
      // just because the latest pivot fails zone, IND, touch or CHoCH eligibility.
      if(current->end.price<m_htf_lbs[k].zoneLow || current->end.price>m_htf_lbs[k].zoneHigh) return false;
      if(m1)
        {
         if(!CTradeRejection::M1Pivot(bull,current->isHigh,latest,current->end.price,
                                     m_htf_lbs[k].m1TouchTime,known,now,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh)) return false;
        }
      else if(latest<=m_htf_lbs[k].entryTriggerTime) return false;
      if(!IndEntryReady(k,latest,current->end.price,known,now) || SkipIndPivot(k,latest,current->end.price,known)) return false;
      pivot=latest; price=current->end.price; confirmed=known;
      if(m1)
        {
         m_htf_lbs[k].m1PivotTime=pivot; m_htf_lbs[k].m1PivotPrice=price; m_htf_lbs[k].m1ConfirmTime=confirmed;
         if(BlockM1OpposingLeg(k,now)) return false;
        }
      return true;
     }
   bool              GetM1EntryPivot(int k, datetime now, datetime &pivotTime,
                                     double &pivotPrice, datetime &confirmTime)
     {
      pivotTime = 0;
      pivotPrice = 0.0;
      confirmTime = 0;
      if(zzEntry == NULL || m_htf_lbs[k].m1TouchTime == 0)
         return false;
      if(CMarcoPivotEntry::Enabled())
         return GetLatestEntryPivot(k,now,zzEntry,true,pivotTime,pivotPrice,confirmTime);
      // Opposing M1 origin invalidates the setup before pivot confirmation or execution.
      if(BlockM1OpposingLeg(k, now))
         return false;
      while(m_htf_lbs[k].m1ConfirmTime == 0)
        {
         int selected = -1;
         datetime earliest = 0;
         for(int p = 0; p < zzEntry->pivots.Total() && p < ArraySize(m_m1PivotConfirmations); p++)
           {
            Pivot* pv = (Pivot*)zzEntry->pivots.At(p);
            if(pv == NULL || pv == zzEntry->projection || StringFind(pv->ln, "ZZ_Proj") >= 0)
               continue;
            datetime available = m_m1PivotConfirmations[p].availableTime;
            if(m_htf_lbs[k].indWait.waiting &&
               (pv->end.time<=m_htf_lbs[k].indWait.rejectedPivot || available<=m_htf_lbs[k].indWait.rejectedAvailable)) continue;
            if(!IndEntryReady(k,pv->end.time,pv->end.price,available,now)) continue;
            if(!CTradeRejection::M1Pivot(m_htf_lbs[k].isBullish, pv->isHigh, pv->end.time, pv->end.price,
                                        m_htf_lbs[k].m1TouchTime, available, now, m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh))
               continue;
            if(selected < 0 || available < earliest)
              {
               selected = p;
               earliest = available;
              }
           }
         if(selected < 0)
            return false;
         Pivot* first = (Pivot*)zzEntry->pivots.At(selected);
         if(SkipIndPivot(k,first->end.time,first->end.price,earliest))
           {
            if(m1LBContext!=NULL && CheckIndWaitBoundary(k,now,m1LBContext->indEntry.lastLow,m1LBContext->indEntry.lastHigh)) return false;
            continue;
           }
         m_htf_lbs[k].m1PivotTime = first->end.time;
         m_htf_lbs[k].m1PivotPrice = first->end.price;
         m_htf_lbs[k].m1ConfirmTime = earliest;
         PrintFormat("[M1 CONFIRMED] %s %s LB=%s pivot=%s price=%.8f confirmed=%s",
                     m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id,
                     TimeToString(first->end.time, TIME_DATE|TIME_SECONDS), first->end.price,
                     TimeToString(earliest, TIME_DATE|TIME_SECONDS));
        }
      if(!IndEntryReady(k,m_htf_lbs[k].m1PivotTime,m_htf_lbs[k].m1PivotPrice,m_htf_lbs[k].m1ConfirmTime,now))
        {
         m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
         return false;
        }
      // Freeze the first qualifying confirmed pivot; a later one must not replace it.
      pivotTime = m_htf_lbs[k].m1PivotTime;
      pivotPrice = m_htf_lbs[k].m1PivotPrice;
      confirmTime = m_htf_lbs[k].m1ConfirmTime;
      return pivotPrice >= m_htf_lbs[k].zoneLow && pivotPrice <= m_htf_lbs[k].zoneHigh && confirmTime <= now;
     }
};
int checks=0;void checkAt(bool ok,int line){++checks;if(!ok){std::cerr<<"M1 touch failure "<<checks<<" at generated line "<<line<<"\n";std::exit(1);}}
#define check(value) checkAt((value),__LINE__)
constexpr datetime first=14*3600+40*60, third=14*3600+48*60;
void feed(Engine &e,datetime at,double low,double high){e.FeedM1EntryBar(at,low,high,low,high,1);}
int main(){
 for(bool buy:{false,true}){
  Engine e;Zone &z=e.m_htf_lbs[0];z.isBullish=buy;
  if(buy){z.zoneLow=7588;z.zoneHigh=7593;}
  double pivot=buy?7592.32:7608.48, outside=buy?7595:7604;
  // Every sampled quote misses the wick. Closed candle range must still arm it.
  e.ArmM1Entry(0,first+55,outside,outside);check(z.m1TouchTime==0);
  feed(e,first,std::min(outside,pivot),std::max(outside,pivot));check(z.m1TouchTime==first);
  check(z.m1ConfirmTime==0); // A touch alone is not confirmation.
  Pivot a{!buy,{first,pivot}};e.zigzag.pending=&a;
  feed(e,first+60,outside-.1,outside+.1);
  check(z.m1PivotTime==first);check(z.m1PivotPrice==pivot);check(z.m1ConfirmTime==first+120);
  check(!CTradeRejection::M1Expired(e.m_last_entry_bar,z.m1ConfirmTime));
  // A later confirmed pivot must never replace the first, including catch-up after downtime.
  Pivot c{!buy,{third,buy?7592.1:7608.67}};e.zigzag.pending=&c;
  feed(e,third+60,outside-.1,outside+.1);
  check(z.m1PivotTime==first);check(z.m1ConfirmTime==first+120);
  check(CTradeRejection::M1Expired(e.m_last_entry_bar,z.m1ConfirmTime));
  CTradeRejection::Consume(z.touchCount,1);
  e.ArmM1Entry(0,third+120,pivot,pivot);check(CTradeRejection::Used(z.touchCount,z.isMitigated));
  check(z.m1TouchTime==first);
  // A tick already armed the same minute: the candle must not overwrite its timestamp.
  Engine tick;tick.m_htf_lbs[0]=Zone{};tick.m_htf_lbs[0].isBullish=buy;
  tick.m_htf_lbs[0].zoneLow=z.zoneLow;tick.m_htf_lbs[0].zoneHigh=z.zoneHigh;
  tick.ArmM1Entry(0,first+17,pivot,pivot);
  feed(tick,first,std::min(pivot,outside),std::max(pivot,outside));
  check(tick.m_htf_lbs[0].m1TouchTime==first+17);
  tick.zigzag.pending=&a;feed(tick,first+60,outside-.1,outside+.1);
  check(tick.m_htf_lbs[0].m1ConfirmTime==first+120);
  // A wick crossing the outer boundary plus buffer retires the zone, even if price recovers.
  Engine broken;broken.m_htf_lbs[0]=Zone{};auto &b=broken.m_htf_lbs[0];b.isBullish=buy;b.zoneLow=z.zoneLow;b.zoneHigh=z.zoneHigh;
  feed(broken,first,buy?z.zoneLow-5.01:outside,buy?outside:z.zoneHigh+5.01);
  check(b.isMitigated);check(b.mitigationTime==first);check(b.m1TouchTime==0);
  // Opposing-LB rejection remains in force after recovering the missed touch.
  Engine blocked;blocked.m_htf_lbs[0]=Zone{};auto &q=blocked.m_htf_lbs[0];q.isBullish=buy;q.zoneLow=z.zoneLow;q.zoneHigh=z.zoneHigh;
  blocked.opposing=true;feed(blocked,first,std::min(pivot,outside),std::max(pivot,outside));check(q.isMitigated);check(q.m1ConfirmTime==0);
 }
 Engine early;early.m_htf_lbs[0].confirmedTime=first;early.m_htf_lbs[0].entryTriggerTime=first;
 feed(early,first+240,7604,7608.48);check(early.m_htf_lbs[0].m1TouchTime==0);
 feed(early,first+300,7604,7608.48);check(early.m_htf_lbs[0].m1TouchTime==first+300);
 // Repeated/older candle delivery cannot update state or manufacture a confirmation.
 int count=early.m_entryBarCount;feed(early,first+300,7600,7620);check(early.m_entryBarCount==count);check(!early.m_htf_lbs[0].isMitigated);
 Engine lb;lb.m_entryTF=ENTRY_TF_LB;feed(lb,first,7604,7608.48);check(lb.m_htf_lbs[0].m1TouchTime==0);

 // New same-direction IND wait rule: both sides and all dropdown modes.
 for(bool buy:{false,true}) for(auto mode:{IND_ENTRY_OFF,IND_ENTRY_PIVOT,IND_ENTRY_PRICE,IND_ENTRY_EITHER}) {
  CMarcoIndEntryFilter::Configure(mode);
  Engine e; Context ctx;e.m1LBContext=&ctx;auto &z=e.m_htf_lbs[0];z.isBullish=buy;
  z.zoneLow=90;z.zoneHigh=110;z.m1TouchTime=first;z.confirmedTime=first-600;z.entryTriggerTime=first-600;
  ctx.indEntry.Begin(94,106);ctx.indEntry.Zone("IND",buy,95,105,first-60);ctx.indEntry.End(first-60);
  Pivot a{!buy,{first,100}};e.zigzag.pivots.values.push_back(&a);e.CaptureM1PivotConfirmations(e.zzEntry,first+120);
  datetime pt=0,ct=0;double px=0;
  bool blocksPivot=mode==IND_ENTRY_PIVOT || mode==IND_ENTRY_EITHER;
  check(e.GetM1EntryPivot(0,first+120,pt,px,ct)==!blocksPivot);
  if(!blocksPivot){
   bool blocksPrice=mode==IND_ENTRY_PRICE;
   check(e.SkipIndEntryPrice(0,first+120,100)==blocksPrice);
   if(!blocksPrice){check(!z.indWait.waiting);continue;}
  }
  check(z.indWait.waiting);check(z.touchCount==0);check(!z.isMitigated);check(z.m1ConfirmTime==0);
  // Repeated checks cannot reuse the rejected pivot or mark the zone used.
  check(!e.GetM1EntryPivot(0,first+130,pt,px,ct));check(z.touchCount==0);
  Pivot b{!buy,{first+240,buy?94.:106.}};e.zigzag.pivots.values.push_back(&b);e.CaptureM1PivotConfirmations(e.zzEntry,first+360);
  check(!e.GetM1EntryPivot(0,first+360,pt,px,ct)); // No CHoCH yet.
  ctx.indEntry.Observe(buy?"BL-CHoCH":"BR-CHoCH",first,first+60);
  check(!e.GetM1EntryPivot(0,first+360,pt,px,ct)); // CHoCH before waiting is insufficient.
  ctx.indEntry.Observe(buy?"BR-CHoCH":"BL-CHoCH",first+120,first+180);
  check(!e.GetM1EntryPivot(0,first+360,pt,px,ct)); // Wrong direction.
  ctx.indEntry.Observe(buy?"BL-BOS":"BR-BOS",first+120,first+180);
  check(!e.GetM1EntryPivot(0,first+360,pt,px,ct)); // BOS is insufficient.
  // A later CHoCH cannot retroactively validate the earlier pivot.
  ctx.indEntry.Observe(buy?"BL-CHoCH":"BR-CHoCH",first+300,first+360);
  check(!e.GetM1EntryPivot(0,first+360,pt,px,ct));
  Pivot c{!buy,{first+420,buy?94.:106.}};e.zigzag.pivots.values.push_back(&c);e.CaptureM1PivotConfirmations(e.zzEntry,first+540);
  check(!e.GetM1EntryPivot(0,first+539,pt,px,ct)); // No future confirmation.
  check(e.GetM1EntryPivot(0,first+540,pt,px,ct));check(pt==first+420);check(px==(buy?94.:106.));
  check(!e.SkipIndEntryPrice(0,first+540,buy?94.:106.));check(z.touchCount==0);
  // A cached confirmation cannot bypass a newer opposite CHoCH before execution.
  ctx.indEntry.Observe(buy?"BR-CHoCH":"BL-CHoCH",first+480,first+550);
  check(!e.GetM1EntryPivot(0,first+550,pt,px,ct));check(z.m1ConfirmTime==0);
  // A wick outside the outer setup boundary cancels waiting even inside the usual SL buffer.
  check(e.CheckIndWaitBoundary(0,first+550,buy?89.99:94,buy?106:110.01));check(z.isMitigated);check(z.touchCount==1);
 }
 // Image-2 regression: matching-side zone elsewhere and opposite-side IND do not veto.
 for(bool buy:{false,true}){
  CMarcoIndEntryFilter::Configure(IND_ENTRY_EITHER);
  Engine e;Context ctx;e.m1LBContext=&ctx;auto &z=e.m_htf_lbs[0];z.isBullish=buy;
  z.zoneLow=90;z.zoneHigh=110;z.m1TouchTime=first;z.confirmedTime=first-600;z.entryTriggerTime=first-600;
  ctx.indEntry.Begin(91,109);ctx.indEntry.Zone("SAME",buy,95,105,first-60);
  ctx.indEntry.Zone("OPPOSITE",!buy,90,110,first-60);ctx.indEntry.End(first-60);
  Pivot a{!buy,{first,buy?94.:106.}};e.zigzag.pivots.values.push_back(&a);e.CaptureM1PivotConfirmations(e.zzEntry,first+120);
  datetime pt=0,ct=0;double px=0;
  check(e.GetM1EntryPivot(0,first+120,pt,px,ct));check(!e.SkipIndEntryPrice(0,first+120,buy?94.:106.));check(!z.indWait.waiting);
  // Pivot-only does not veto an entry price inside IND; entry-only ignores the pivot location.
  CMarcoIndEntryFilter::Configure(IND_ENTRY_PIVOT);check(!e.SkipIndEntryPrice(0,first+120,100));
 }

 for(bool buy:{false,true}){
  CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);
  Engine e;Context ctx;e.m1LBContext=&ctx;auto &z=e.m_htf_lbs[0];z.isBullish=buy;
  z.zoneLow=90;z.zoneHigh=110;z.m1TouchTime=first;z.confirmedTime=first-600;z.entryTriggerTime=first-600;
  ctx.indEntry.Begin(94,106);ctx.indEntry.Zone("IND",buy,95,105,first-60);ctx.indEntry.End(first-60);
  Pivot a{!buy,{first,100}};e.zigzag.pivots.values.push_back(&a);e.CaptureM1PivotConfirmations(e.zzEntry,first+120);
  datetime pt=0,ct=0;double px=0;
  check(e.GetM1EntryPivot(0,first+120,pt,px,ct));check(!e.SkipIndEntryPrice(0,first+120,buy?94.:106.));check(!z.indWait.waiting);
  // Formation inside IND remains blocked after that IND disappears before confirmation.
  CMarcoIndEntryFilter::Configure(IND_ENTRY_PIVOT);CMarcoIndEntryFilter history;SMarcoIndWait w{};string id;
  history.Begin(94,106);history.Zone("IND",buy,95,105,first);history.End(first);
  history.Begin(90,110);history.End(first+120);
  check(history.SkipPivot(w,buy,first,100,first+120,id));check(w.waiting);
  // A zone that becomes IND only after the pivot candle cannot retroactively block its formation.
  CMarcoIndEntryFilter future;SMarcoIndWait untouched{};
  future.Begin(94,106);future.Zone("LATER",buy,95,105,first+120);future.End(first+120);
  check(!future.SkipPivot(untouched,buy,first,100,first+120,id));
 }
 // Waiting permission uses the most recent valid CHoCH, including historical revisions.
 for(bool buy:{false,true}){
  CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);CMarcoIndEntryFilter f;SMarcoIndWait state{};
  CMarcoIndEntryFilter::Wait(state,100,120,120,95,105);
  double pivotPrice=buy?94:106;
  f.Observe(buy?"BL-CHoCH":"BR-CHoCH",180,240);
  check(f.Ready(state,buy,300,pivotPrice,360,90,110));
  f.Observe(buy?"BR-CHoCH":"BL-CHoCH",240,300);
  check(!f.Ready(state,buy,300,pivotPrice,360,90,110));
  f.Observe(buy?"BL-CHoCH":"BR-CHoCH",360,420);
  check(f.Ready(state,buy,480,pivotPrice,540,90,110));
  f.Observe(buy?"BSL-Swept":"SSL-Swept",360,600);
  check(f.Ready(state,buy,480,pivotPrice,540,90,110,599));
  check(!f.Ready(state,buy,480,pivotPrice,540,90,110,600));
  f.Observe(buy?"BL-CHoCH":"BR-CHoCH",660,720);
  check(!f.Ready(state,buy,700,pivotPrice,780,90,110)); // CHoCH was not known before pivot.
  check(f.Ready(state,buy,740,pivotPrice,780,90,110));
  f.Observe(buy?"BR-CHoCH":"BL-CHoCH",760,800);
  check(f.Ready(state,buy,740,pivotPrice,780,90,110,799));
  check(!f.Ready(state,buy,740,pivotPrice,780,90,110,800));
  CMarcoIndEntryFilter::Reset(state);
  check(f.Ready(state,buy,740,pivotPrice,780,90,110,800)); // Unaffected trades do not enter IND wait.
 }
 // Snapshot availability, mitigation/removal, clustered bounds, exact boundaries and strict release.
 CMarcoIndEntryFilter::Configure(IND_ENTRY_EITHER);CMarcoIndEntryFilter h;
 h.Begin(90,110);h.Zone("A",false,95,105,120);h.End(120);
 double lo=0,hi=0;string id;check(!h.Inside(false,100,119,lo,hi,id));check(h.Inside(false,95,120,lo,hi,id));
 h.Begin(90,110);h.Zone("A",false,95,107,180);h.Zone("B",false,104,109,180);h.End(180);
 check(!h.Inside(false,106,179,lo,hi,id));check(h.Inside(false,106,180,lo,hi,id));check(lo==95 && hi==109);
 SMarcoIndWait w{};check(h.SkipPrice(w,false,180,240,240,106,id));check(w.high==109);
 h.Begin(90,110);h.End(300);check(!h.Inside(false,106,300,lo,hi,id));check(h.Inside(false,106,299,lo,hi,id));
 h.Observe("BR-CHoCH",300,360);check(!h.Ready(w,false,420,109,540,90,110));
 check(!h.Ready(w,false,420,110,540,90,110));check(h.Ready(w,false,420,109.5,540,90,110));
 // The removed zone cannot release a wait without the required CHoCH.
 CMarcoIndEntryFilter noChoch;check(!noChoch.Ready(w,false,420,109.5,540,90,110));
 CMarcoIndEntryFilter::Reset(w);check(!w.waiting);check(noChoch.Ready(w,false,420,100,540,90,110));
 // Both timeframe sources, both directions and every input mode. Neither source
 // may short-circuit the other: overlapping blockers accumulate their bounds.
 for(bool buy:{false,true}) for(auto mode:{IND_ENTRY_OFF,IND_ENTRY_PIVOT,IND_ENTRY_PRICE,IND_ENTRY_EITHER})
 for(int sources=0;sources<4;sources++) {
  CMarcoIndEntryFilter::Configure(mode);Engine e;Context ctx;e.m1LBContext=&ctx;
  auto &z=e.m_htf_lbs[0];z.isBullish=buy;z.zoneLow=80;z.zoneHigh=120;
  e.m_setupIndEntry.Begin(90,110);ctx.indEntry.Begin(90,110);
  if(sources&1)e.m_setupIndEntry.Zone("SETUP",buy,95,105,120);
  if(sources&2)ctx.indEntry.Zone("ENTRY",buy,96,106,120);
  e.m_setupIndEntry.End(120);ctx.indEntry.End(120);
  bool pivotBlocked=sources!=0&&(mode==IND_ENTRY_PIVOT||mode==IND_ENTRY_EITHER);
  check(e.SkipIndPivot(0,180,100,300)==pivotBlocked);
  if(pivotBlocked){check(z.indWait.low==((sources&1)?95:96));check(z.indWait.high==((sources&2)?106:105));}
  CMarcoIndEntryFilter::Reset(z.indWait);
  bool priceBlocked=sources!=0&&(mode==IND_ENTRY_PRICE||mode==IND_ENTRY_EITHER);
  check(e.SkipIndEntryPrice(0,300,100)==priceBlocked);
  if(priceBlocked){check(z.indWait.low==((sources&1)?95:96));check(z.indWait.high==((sources&2)?106:105));}
  CMarcoIndEntryFilter::Reset(z.indWait);check(!e.SkipIndEntryPrice(0,300,115));
  check(!z.indWait.waiting);check(!e.SkipIndPivot(0,180,115,300));
 }
 for(bool buy:{false,true}) {
  CMarcoIndEntryFilter::Configure(IND_ENTRY_EITHER);Engine e;Context ctx;e.m1LBContext=&ctx;
  auto &z=e.m_htf_lbs[0];z.isBullish=buy;z.zoneLow=80;z.zoneHigh=120;
  // Actual setup snapshot ignores unqualified/mitigated zones and preserves availability.
  ctx.indEntry.Begin(90,110);ctx.indEntry.End(120);
  CInducementLogic ind;CMarketStructure ms;
  CInducementZone active{"A",buy,true,false,95,105},raw{"RAW",buy,false,false,90,110},dead{"DEAD",buy,true,true,85,115};
  ind.m_zones.values={&active,&raw,&dead};
  e.CaptureSetupIndContext(&ind,&ms,300,90,110);
  check(!e.SkipIndEntryPrice(0,299,100));check(e.SkipIndEntryPrice(0,300,100));
  check(z.indWait.low==95&&z.indWait.high==105);
  CMarcoIndEntryFilter::Reset(z.indWait);
  // M1 pivot formed before this setup IND was known is not retroactively blocked.
  check(!e.SkipIndPivot(0,180,100,360));
  active.isMitigated=true;e.CaptureSetupIndContext(&ind,&ms,420,90,110);
  check(!e.SkipIndEntryPrice(0,420,100));
  check(e.SkipIndPivot(0,300,100,480)); // Was inside at pivot candle close (360).
  // M1 wait resumes from M1 CHoCH, never an unrelated setup-TF event.
  double resume=buy?94:106;
  e.m_setupIndEntry.Observe(buy?"BL-CHoCH":"BR-CHoCH",480,540);
  check(!e.IndEntryReady(0,600,resume,660,660));
  ctx.indEntry.Observe(buy?"BL-CHoCH":"BR-CHoCH",480,540);
  check(e.IndEntryReady(0,600,resume,660,660));
  // In LB-entry mode, M1-only zones are irrelevant; the setup TF is also entry TF.
  e.m_entryTF=ENTRY_TF_LB;CMarcoIndEntryFilter::Reset(z.indWait);e.m_setupIndEntry.Clear();
  ctx.indEntry.Begin(90,110);ctx.indEntry.Zone("M1_ONLY",buy,95,105,120);ctx.indEntry.End(120);
  check(!e.SkipIndEntryPrice(0,300,100,180,300));
  active.isMitigated=false;e.CaptureSetupIndContext(&ind,&ms,300,90,110);
  // Setup pivot closes after five minutes, not after M1's single minute.
  check(e.SkipIndPivot(0,180,100,600));CMarcoIndEntryFilter::Reset(z.indWait);
  check(e.SkipIndEntryPrice(0,600,100,180,600));
  check(!e.IndEntryReady(0,900,resume,1200,1200));
  e.m_setupIndEntry.Observe(buy?"BL-CHoCH":"BR-CHoCH",600,900);
  Pivot rejected{!buy,{180,100}},next{!buy,{900,resume}};
  e.zigzag.pivots.values={&rejected,&next};
  e.m_pivotConfirmations={{180,100,!buy,600},{900,resume,!buy,1200}};
  datetime pivot=0,confirmed=0;double price=0;
  check(!e.GetSetupIndWaitPivot(0,1199,&e.zigzag,pivot,price,confirmed));
  check(e.GetSetupIndWaitPivot(0,1200,&e.zigzag,pivot,price,confirmed));
  check(pivot==900&&price==resume&&confirmed==1200);
  check(e.CheckIndWaitBoundary(0,1200,buy?79:90,buy?110:121));check(z.isMitigated);
  // LB-entry waits must also detect a boundary-breaking wick between live scans.
  Engine wick;wick.m_entryTF=ENTRY_TF_LB;auto &wz=wick.m_htf_lbs[0];
  wz.isBullish=buy;wz.zoneLow=80;wz.zoneHigh=120;wz.entryTriggerTime=60;
  CMarcoIndEntryFilter::Wait(wz.indWait,180,600,600,95,105);
  feed(wick,660,buy?79:90,buy?110:121);check(wz.isMitigated);
 }

 // Edge mode follows current confirmed endpoints, never a vanished saved pivot.
 CMarcoPivotEntry::Configure(ENTRY_PIVOT_CANDLE_EDGE);
 for(bool buy:{false,true})for(bool m1:{false,true}){
  Engine e;auto &z=e.m_htf_lbs[0];e.m_entryTF=m1?ENTRY_TF_M1:ENTRY_TF_LB;
  z.isBullish=buy;z.entryTriggerTime=60;z.zoneLow=90;z.zoneHigh=110;z.m1TouchTime=600;
  CMarcoIndEntryFilter::Configure(IND_ENTRY_OFF);
  double old=buy?96:104, revised=buy?95:105, newest=buy?94:106;
  Pivot prior{!buy,{480,buy?97.:103.}}, firstPivot{!buy,{600,old}}, replacement{!buy,{780,newest}};
  e.zigzag.pivots.values={&prior,&firstPivot};
  e.m_m1PivotConfirmations={{480,prior.end.price,!buy,540},{600,old,!buy,720}};
  e.m_pivotConfirmations=e.m_m1PivotConfirmations;
  datetime pt=0,ct=0;double px=0;
  auto select=[&](datetime now){return m1 ? e.GetM1EntryPivot(0,now,pt,px,ct) :
                          e.GetLatestEntryPivot(0,now,&e.zigzag,false,pt,px,ct);};
  check(select(720));check(pt==600&&px==old&&ct==720);
  z.pivotEntry={600,720,buy?103.:97.,false};
  // Same candle, different extreme: stale confirmation identity must not pass.
  firstPivot.end.price=revised;
  check(!select(750));check(z.pivotWatch.invalid);check(z.pivotEntry.level==0);
  e.m_m1PivotConfirmations[1]={600,revised,!buy,780};e.m_pivotConfirmations=e.m_m1PivotConfirmations;
  check(!select(779));check(select(780));check(px==revised&&ct==780&&!z.pivotWatch.invalid);
  // Removal or conversion to a projection cannot resurrect the prior pivot.
  e.zigzag.projection=&firstPivot;check(!select(800));check(z.pivotWatch.invalid);
  e.zigzag.pivots.values={&prior};check(!select(810));
  e.zigzag.projection=nullptr;e.zigzag.pivots.values={&prior,&replacement};
  e.m_m1PivotConfirmations[1]={780,newest,!buy,900};e.m_pivotConfirmations=e.m_m1PivotConfirmations;
  check(!select(899));check(select(900));check(pt==780&&px==newest&&ct==900);
  // A broken extreme invalidates the pending pivot without consuming a valid LB.
  check(!e.ObservePivotEntryRange(0,900,buy?93.:100.,buy?100.:107.));
  check(z.pivotWatch.invalid&&!z.isMitigated&&z.touchCount==0);check(!select(920));
  // A new confirmed replacement re-arms, with fresh level/SL reference.
  replacement.end={960,buy?92.:108.};
  e.m_m1PivotConfirmations[1]={960,replacement.end.price,!buy,1080};e.m_pivotConfirmations=e.m_m1PivotConfirmations;
  check(select(1080));check(px==replacement.end.price&&ct==1080);check(z.pivotEntry.level==0);
  // Latest endpoint outside the setup cannot fall back to an older in-zone one.
  Pivot outside{!buy,{1140,buy?89.:111.}};e.zigzag.pivots.values.push_back(&outside);
  e.m_m1PivotConfirmations.push_back({1140,outside.end.price,!buy,1260});e.m_pivotConfirmations=e.m_m1PivotConfirmations;
  check(!select(1260));
  // Mitigation uses the actual LB boundary, not its 50-pip SL buffer allowance.
  check(e.ObservePivotEntryRange(0,1260,buy?89.99:100.,buy?100.:110.01));
  check(z.isMitigated&&z.touchCount>0);check(!select(1320));
 }
 // Fresh pivots remain subject to both setup-TF and entry-TF entry-price vetoes.
 for(bool buy:{false,true})for(bool setupZone:{false,true}){
  Engine e;Context ctx;e.m1LBContext=&ctx;auto &z=e.m_htf_lbs[0];
  z.isBullish=buy;z.entryTriggerTime=60;z.zoneLow=80;z.zoneHigh=120;z.m1TouchTime=600;
  CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);
  Pivot a{!buy,{600,buy?90.:110.}},b{!buy,{780,buy?89.:111.}};
  e.zigzag.pivots.values={&a};e.m_m1PivotConfirmations={{600,a.end.price,!buy,720}};
  auto &context=setupZone?e.m_setupIndEntry:ctx.indEntry;
  context.Begin(80,120);context.Zone("BLOCK",buy,95,105,600);context.End(600);
  datetime pt=0,ct=0;double px=0;
  check(e.GetM1EntryPivot(0,720,pt,px,ct));
  e.zigzag.pivots.values={&b};e.m_m1PivotConfirmations={{780,b.end.price,!buy,900}};
  check(e.GetM1EntryPivot(0,900,pt,px,ct));check(px==b.end.price);
  check(e.SkipIndEntryPrice(0,900,100,pt,ct));check(z.indWait.waiting);
  check(!e.GetM1EntryPivot(0,960,pt,px,ct)); // Replacement never bypasses IND/CHoCH wait.
 }
 CMarcoPivotEntry::Configure(ENTRY_AFTER_CONFIRMATION);
 std::cout<<"PASS: "<<checks<<" M1/setup IND, waiting, first-pivot and expiry checks (both directions)\n";
}
