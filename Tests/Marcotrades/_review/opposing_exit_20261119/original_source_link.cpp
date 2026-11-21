#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <vector>
using string=std::string;
using datetime=long long;
using ulong=unsigned long long;
using ENUM_TIMEFRAMES=int;
template<class T> void ZeroMemory(T &v){ v=T{}; }
bool MathIsValidNumber(double v){return std::isfinite(v);}
double MathAbs(double v){return std::abs(v);}
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
double MathFloor(double v){return std::floor(v);}
double MathCeil(double v){return std::ceil(v);}
double NormalizeDouble(double v,int d){double n=std::pow(10.,d);return std::round(v*n)/n;}
string IntegerToString(long long n){return std::to_string(n);}
int StringLen(const string&s){return int(s.size());}
int StringFind(const string&s,const string&needle){auto pos=s.find(needle);return pos==string::npos?-1:int(pos);}
int StringGetCharacter(const string&s,int i){return (unsigned char)s.at(i);}
enum {FILE_WRITE=1,FILE_BIN=2,FILE_READ=4,FILE_REWRITE=8,FILE_UNICODE=16,INVALID_HANDLE=-1,
 ACCOUNT_LOGIN=10,POSITION_IDENTIFIER,POSITION_SL,POSITION_TP,POSITION_SYMBOL,POSITION_MAGIC,
 POSITION_VOLUME,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MIN,SYMBOL_TRADE_TICK_SIZE,SYMBOL_DIGITS,TERMINAL_TRADE_ALLOWED,MQL_TRADE_ALLOWED,
 ACCOUNT_TRADE_ALLOWED,ACCOUNT_TRADE_EXPERT,ORDER_STATE,ORDER_STATE_REJECTED,
 ORDER_STATE_CANCELED,ORDER_STATE_EXPIRED,TRADE_ACTION_DEAL,ORDER_TYPE_SELL,ORDER_TYPE_BUY,
 ORDER_FILLING_FOK,TRADE_RETCODE_DONE=100,TRADE_RETCODE_PLACED,TRADE_RETCODE_TIMEOUT,
 TRADE_RETCODE_CONNECTION,TRADE_RETCODE_DONE_PARTIAL,TRADE_RETCODE_REJECT};
struct MqlTick {double bid,ask;};
struct MqlTradeRequest {int action,type,type_filling,deviation; ulong position; long long magic; string symbol,comment; double price,volume;};
struct MqlTradeResult {ulong order; int retcode; double volume,price;};
struct MqlTradeCheckResult {int retcode;};
std::map<string,std::vector<char>> files;
struct Handle {string path; size_t offset;};
std::map<int,Handle> handles; int nextHandle=0;
bool FolderCreate(const string&){return true;}
int FileOpen(const string& path,int flags){
 if((flags&FILE_READ)&&!files.count(path))return INVALID_HANDLE;
 if(flags&FILE_WRITE)files[path].clear();
 handles[++nextHandle]={path,0};return nextHandle;
}
template<class T> void put(int f,T v){auto &h=handles.at(f);auto &b=files[h.path];size_t end=h.offset+sizeof v;b.resize(end);std::memcpy(b.data()+h.offset,&v,sizeof v);h.offset=end;}
template<class T> T get(int f){auto &h=handles.at(f);auto &b=files.at(h.path);assert(h.offset+sizeof(T)<=b.size());T v;std::memcpy(&v,b.data()+h.offset,sizeof v);h.offset+=sizeof v;return v;}
void FileWriteInteger(int f,int v){put<int32_t>(f,v);}
void FileWriteDouble(int f,double v){put(f,v);}
void FileWriteLong(int f,long long v){put<int64_t>(f,v);}
int FileReadInteger(int f){return get<int32_t>(f);}
double FileReadDouble(int f){return get<double>(f);}
long long FileReadLong(int f){return get<int64_t>(f);}
size_t FileTell(int f){return handles.at(f).offset;}
size_t FileSize(int f){return files.at(handles.at(f).path).size();}
unsigned int FileWriteString(int f,const string&s,int n){for(int i=0;i<n;i++)put<uint16_t>(f,(uint16_t)(unsigned char)s.at(i));return n*2;}
string FileReadString(int f,int n){string s;for(int i=0;i<n;i++)s+=(char)get<uint16_t>(f);return s;}
void FileFlush(int){}
void FileClose(int f){handles.erase(f);}
bool FileMove(const string&a,int,const string&b,int){files[b]=files.at(a);files.erase(a);return true;}
double volume=4,sl=90,tp=130,bid=100,ask=100,step=0.01;
ulong identifier=6000000000ULL,ticket=7000000000ULL;
long long magic=77;
int sends=0,mode=0; bool modifyAllowed=true,enabled=true,rejectSLOnly=false;
datetime clockNow=1000; MqlTradeRequest pending{};
int PositionsTotal(){return volume>0?1:0;}
ulong PositionGetTicket(int){return ticket;}
long long PositionGetInteger(int p){return p==POSITION_IDENTIFIER?identifier:magic;}
double PositionGetDouble(int p){return p==POSITION_SL?sl:(p==POSITION_TP?tp:volume);}
string PositionGetString(int){return "TEST";}
double SymbolInfoDouble(const string&,int){return step;}
long long SymbolInfoInteger(const string&,int){return 2;}
bool SymbolInfoTick(const string&,MqlTick&t){t.bid=bid;t.ask=ask;return true;}
long long AccountInfoInteger(int p){return p==ACCOUNT_LOGIN?42:enabled;}
bool TerminalInfoInteger(int){return enabled;}
bool MQLInfoInteger(int){return enabled;}
datetime TimeCurrent(){return clockNow;}
bool HistoryOrderSelect(ulong){return false;}
long long HistoryOrderGetInteger(ulong,int){return ORDER_STATE_REJECTED;}
datetime iTime(const string&,int,int){return 900;}
int PeriodSeconds(int){return 60;}
double iOpen(const string&,int,int){return 110;}
double iClose(const string&,int,int){return 109;}
template<class...T> void PrintFormat(const char*,T...){}
bool OrderCheck(const MqlTradeRequest&r,MqlTradeCheckResult&c){
 bool valid=r.volume>0&&r.volume<=volume+1e-9&&std::abs(r.volume/step-std::round(r.volume/step))<1e-7;
 c.retcode=valid?TRADE_RETCODE_DONE:TRADE_RETCODE_REJECT;return valid;
}
struct CTrade {
 int last=0; double lastPrice=0;
 void SetAsyncMode(bool){}
 bool PositionModify(ulong t,double stop,double target){assert(t==ticket);bool allowed=modifyAllowed && !(rejectSLOnly && std::abs(stop-sl)>1e-9);if(allowed){sl=stop;tp=target;}last=allowed?TRADE_RETCODE_DONE:TRADE_RETCODE_REJECT;return allowed;}
 bool PositionClose(ulong t){assert(t==ticket);lastPrice=bid;volume=0;last=TRADE_RETCODE_DONE;return true;}
 int ResultRetcode(){return last;}
 double ResultPrice(){return lastPrice;}
 bool OrderSend(const MqlTradeRequest&r,MqlTradeResult&out){
   assert(r.position==ticket);assert(r.magic==magic);assert(r.volume<=volume+1e-9);sends++;
   out.order=8000000000ULL+sends;out.price=r.price;
   if(mode==1){out.retcode=TRADE_RETCODE_REJECT;return false;}
   if(mode==2){pending=r;out.retcode=TRADE_RETCODE_TIMEOUT;return false;}
   volume-=r.volume;out.volume=r.volume;out.retcode=TRADE_RETCODE_DONE;return true;
 }
};


using uint=unsigned int;
enum {PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M3=3,TIME_DATE=1,TIME_SECONDS=2};
template<class T> int ArraySize(const std::vector<T>&v){return (int)v.size();}
template<class T> void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
string EnumToString(int x){return std::to_string(x);}
string TimeToString(datetime x,int){return std::to_string(x);}
template<class...T>void Print(T...){}

// Shared rejection policy. Data collection, detection and order submission stay with callers.
#ifndef MARCO_TRADE_REJECTION_MQH
#define MARCO_TRADE_REJECTION_MQH

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

// Immutable versions preserve the information available during chronological catch-up.
struct SRejectionEvent
  {
   string name;
   datetime time, available, originTime, until;
   double originPrice, linePrice;
  };
struct SRejectionLB
  {
   string id;
   bool bull, seen, entryVetoed;
   double low, high;
   datetime created, mitigation, choch, available, until;
  };

class CTradeRejectionHistory
  {
private:
   std::vector<SRejectionEvent> events;
   std::vector<SRejectionLB> zones;
   // Sorted identity indexes; public snapshot arrays retain their append order.
   std::vector<datetime> eventKeys;
   std::vector<int> eventHeads;
   std::vector<int> eventPrevious;
   std::vector<string> zoneKeys;
   std::vector<int> zoneHeads;
   std::vector<int> zonePrevious;
   int EventSlot(datetime key)
     {
      int lo=0,hi=ArraySize(eventKeys);
      while(lo<hi) { int mid=(lo+hi)/2; if(eventKeys[mid]<key) lo=mid+1; else hi=mid; }
      return lo;
     }
   int ZoneSlot(string key)
     {
      int lo=0,hi=ArraySize(zoneKeys);
      while(lo<hi) { int mid=(lo+hi)/2; if(zoneKeys[mid]<key) lo=mid+1; else hi=mid; }
      return lo;
     }
   bool PreviousEvent(datetime before,datetime now,SRejectionEvent &event)
     {
      for(int slot=EventSlot(before)-1;slot>=0;slot--)
         for(int i=eventHeads[slot];i>=0;i=eventPrevious[i])
            if(EventAt(i,now,event)) return true;
      return false;
     }
   STradeRejection AllowWithTrace(string reason, bool diagnostics)
     {
      if(diagnostics) Print("[CHOCH AUDIT] decision=ALLOW reason=", reason);
      return CTradeRejection::Decision(TRADE_ALLOW, REJECT_NONE);
     }
public:
   void Reset()
     {
      ArrayResize(events,0); ArrayResize(zones,0);
      ArrayResize(eventKeys,0); ArrayResize(eventHeads,0); ArrayResize(eventPrevious,0);
      ArrayResize(zoneKeys,0); ArrayResize(zoneHeads,0); ArrayResize(zonePrevious,0);
     }
   void Observe(string name, datetime time, datetime available, datetime originTime, double originPrice, double linePrice = 0.0)
     {
      if(time == 0 || name == "") return;
      int n = ArraySize(events);
      // A previous event may be reclassified after a newer event is recorded.
      // Keep its source and an availability-bounded version; do not reorder the market.
      int slot=EventSlot(time),count=ArraySize(eventKeys),previous=-1;
      if(slot<count && eventKeys[slot]==time)
        {
         previous=eventHeads[slot];
         if(events[previous].name==name) return;
         originTime=events[previous].originTime;
         originPrice=events[previous].originPrice;
         events[previous].until=available;
        }
      else
        {
         ArrayResize(eventKeys,count+1); ArrayResize(eventHeads,count+1);
         for(int j=count;j>slot;j--) { eventKeys[j]=eventKeys[j-1]; eventHeads[j]=eventHeads[j-1]; }
         eventKeys[slot]=time;
        }
      eventHeads[slot]=n;
      ArrayResize(eventPrevious,n+1); eventPrevious[n]=previous;
      ArrayResize(events,n+1);
      events[n].name=name; events[n].time=time; events[n].available=available;
      events[n].originTime=originTime; events[n].originPrice=originPrice;
      events[n].linePrice=linePrice; events[n].until=0;
     }
   int EventCount() { return ArraySize(events); }
   bool EventAt(int index, datetime now, SRejectionEvent &event)
     {
      if(index<0 || index>=ArraySize(events) || events[index].available>now ||
         (events[index].until>0 && now>=events[index].until)) return false;
      event=events[index]; return true;
     }
   bool Latest(datetime now, SRejectionEvent &event)
     {
      for(int slot=ArraySize(eventKeys)-1;slot>=0;slot--)
         for(int i=eventHeads[slot];i>=0;i=eventPrevious[i])
            if(EventAt(i,now,event)) return true;
      return false;
     }
   int ZoneCount() { return ArraySize(zones); }
   bool ZoneAt(int index, SRejectionLB &zone)
     {
      if(index<0 || index>=ArraySize(zones)) return false;
      zone=zones[index]; return true;
     }
   void BeginZones()
     {
      for(int i=0; i<ArraySize(zones); i++) zones[i].seen=false;
     }
   void Zone(string id, bool bull, double low, double high, datetime created,
             datetime mitigation, datetime choch, datetime now, bool entryVetoed = false)
     {
      int slot=ZoneSlot(id),count=ArraySize(zoneKeys),previous=-1;
      if(slot<count && zoneKeys[slot]==id)
        {
         previous=zoneHeads[slot];
         int i=previous;
         if(zones[i].until==0)
           {
            zones[i].seen=true;
            if(zones[i].bull==bull && zones[i].low==low && zones[i].high==high &&
               zones[i].created==created && zones[i].mitigation==mitigation && zones[i].choch==choch && zones[i].entryVetoed==entryVetoed) return;
            zones[i].until=now;
           }
        }
      else
        {
         ArrayResize(zoneKeys,count+1); ArrayResize(zoneHeads,count+1);
         for(int j=count;j>slot;j--) { zoneKeys[j]=zoneKeys[j-1]; zoneHeads[j]=zoneHeads[j-1]; }
         zoneKeys[slot]=id;
        }
      int n=ArraySize(zones); ArrayResize(zones,n+1);
      ArrayResize(zonePrevious,n+1); zonePrevious[n]=previous; zoneHeads[slot]=n;
      zones[n].entryVetoed=entryVetoed;
      zones[n].id=id; zones[n].bull=bull; zones[n].low=low; zones[n].high=high;
      zones[n].created=created; zones[n].mitigation=mitigation; zones[n].choch=choch;
      zones[n].available=now; zones[n].until=0; zones[n].seen=true;
     }
   void EndZones(datetime now)
     {
      for(int i=0; i<ArraySize(zones); i++)
         if(zones[i].until==0 && !zones[i].seen) zones[i].until=now;
     }
   static int StructureDirection(string name)
     {
      if(name=="BL-CHoCH" || name=="BL-BOS" || name=="BSL-Swept") return 1;
      if(name=="BR-CHoCH" || name=="BR-BOS" || name=="SSL-Swept") return -1;
      return 0;
     }
   bool ActiveSource(const SRejectionLB &lb,bool candidateBull,datetime now,ENUM_TIMEFRAMES tf)
     {
      return lb.bull!=candidateBull && lb.available<=now && (lb.until==0 || now<lb.until) &&
             (lb.mitigation==0 || now<lb.mitigation+PeriodSeconds(tf));
     }
   // Consult the same available/qualified LB snapshots as structural prevention.
   bool IncomingLeg(bool candidateBull,datetime origin,double price,datetime now,
                    ENUM_TIMEFRAMES tf,double buffer,string &id)
     {
      id="";
      if(origin<=0 || origin>now) return false;
      for(int b=ArraySize(zones)-1;b>=0;b--)
        {
         SRejectionLB lb=zones[b];
         if(!ActiveSource(lb,candidateBull,now,tf)) continue;
         if(CTradeRejection::OriginInside(origin,price,lb.created,lb.mitigation,PeriodSeconds(tf),lb.low,lb.high,buffer))
           { id=lb.id; return true; }
        }
      return false;
     }
   // Name retained for existing callers. The veto follows an uninterrupted
   // opposing CHoCH/BOS/sweep sequence, not just an immediately latest CHoCH.
   STradeRejection OpposingChoch(bool candidateBull, datetime legOrigin, datetime legEnd,
                                datetime touch, datetime now, ENUM_TIMEFRAMES tf, double buffer, bool diagnostics = false)
     {
      STradeRejection result=CTradeRejection::Decision(TRADE_ALLOW, REJECT_NONE);
      if(diagnostics)
         PrintFormat("[CHOCH AUDIT] source=%s target=%s at=%s touch=%s leg_origin=%s leg_end=%s",
                     EnumToString(tf), candidateBull ? "BL-LB" : "BR-LB", TimeToString(now, TIME_DATE|TIME_SECONDS),
                     TimeToString(touch, TIME_DATE|TIME_SECONDS), TimeToString(legOrigin, TIME_DATE|TIME_SECONDS),
                     TimeToString(legEnd, TIME_DATE|TIME_SECONDS));
      if(touch==0) return AllowWithTrace("NO_RECORDED_TOUCH", diagnostics);
      if(now<touch) return AllowWithTrace("TOUCH_NOT_YET_AVAILABLE", diagnostics);
      if(legOrigin==0) return AllowWithTrace("NO_MATCHING_INCOMING_LEG", diagnostics);
      if(legOrigin>touch) return AllowWithTrace("LEG_STARTED_AFTER_RECORDED_TOUCH", diagnostics);
      SRejectionEvent latest;
      if(!Latest(now,latest)) return AllowWithTrace("NO_AVAILABLE_STRUCTURE", diagnostics);
      int opposing=candidateBull ? -1 : 1;
      if(diagnostics)
         PrintFormat("[CHOCH AUDIT] latest=%s event=%s available=%s source_pivot=%s source_price=%.8f",
                     latest.name, TimeToString(latest.time, TIME_DATE|TIME_SECONDS), TimeToString(latest.available, TIME_DATE|TIME_SECONDS),
                     TimeToString(latest.originTime, TIME_DATE|TIME_SECONDS), latest.originPrice);
      if(StructureDirection(latest.name)!=opposing)
         return AllowWithTrace("LATEST_STRUCTURE_IS_NOT_OPPOSING", diagnostics);
      if(legEnd>0 && latest.time>legEnd)
         return AllowWithTrace("STRUCTURE_AFTER_TOUCHING_LEG_ENDED", diagnostics);
      SRejectionEvent ev=latest;
      for(int chain=0;chain<ArraySize(events);chain++)
        {
         // A candidate-direction event or reclassification ends the chain.
         if(StructureDirection(ev.name)!=opposing) break;
         if(ev.originTime>0 && ev.originTime<=legOrigin)
            for(int b=ArraySize(zones)-1;b>=0;b--)
              {
               SRejectionLB lb=zones[b];
               if(!ActiveSource(lb,candidateBull,now,tf)) continue;
               bool produced=lb.choch==ev.time;
               bool stemmed=false;
               if(!produced)
                  for(int v=b;v>=0;v=zonePrevious[v])
                    {
                     SRejectionLB source=zones[v];
                     if(source.id!=lb.id || source.available>ev.available ||
                        (source.until>0 && ev.available>=source.until)) continue;
                     stemmed=CTradeRejection::OriginInside(ev.originTime,ev.originPrice,source.created,
                               source.mitigation,PeriodSeconds(tf),source.low,source.high,buffer);
                     break;
                    }
               if(!produced && !stemmed) continue;
               result.action=TRADE_RETIRE_ZONE; result.reason=REJECT_OPPOSING_CHOCH_LB;
               result.sourceTF=tf; result.opposingId=lb.id; result.eventTime=ev.time;
               if(diagnostics)
                  PrintFormat("[CHOCH AUDIT] decision=REJECT reason=OPPOSING_STRUCTURE_LB source=%s LB=%s latest=%s linked=%s linked_at=%s origin=%s price=%.8f",
                              EnumToString(tf),lb.id,latest.name,ev.name,TimeToString(ev.time,TIME_DATE|TIME_SECONDS),
                              TimeToString(ev.originTime,TIME_DATE|TIME_SECONDS),ev.originPrice);
               return result;
              }
         // Event revisions are appended out of order. Select the preceding event
         // by its structural time, using only the version available at entry.
         SRejectionEvent previous;
         if(!PreviousEvent(ev.time,now,previous)) break;
         ev=previous;
        }
      return AllowWithTrace("NO_ACTIVE_OPPOSING_LB_LINKED_TO_STRUCTURE_CHAIN", diagnostics);
     }

  };
#endif

// Shared partial-exit policy with durable target extensions. Kind: 0=LB, 1=IND, 2=RR, 3=RR+1.
#ifndef MARCO_STAGED_TP_MQH
#define MARCO_STAGED_TP_MQH
struct SMarcoOpposingSequence
  {
   datetime seen[2];
   int step, tf;
   datetime firstEvent;
   bool firstProfit, pending;
   double share, requestedLots;
   double closed[2], price[2];
   datetime time[2];
  };
struct SMarcoTPPlan
  {
   int count, direction;
   double entry, initialSL, remaining, realizedR;
   bool breakeven;
   int kind[3];
   double price[3], fraction[3], closed[3], exitPrice[3];
   datetime exitTime[3], vicinityTime[3];
   // Index 0 = one-time half exit; index 1 = emergency full exit.
   double structureClosed[2], structurePrice[2];
   datetime structureTime[2];
   double protectedSL; // Profit-side stop requested by a same-direction LB.
   int extensionCount;
   datetime extensionTime;
   SMarcoOpposingSequence sequence;
  };

// Kept outside the fixed-size plan so indicator cache records remain serializable.
struct SMarcoExtensionState
  {
   string seen; // Delimited timeframe + LB ID keys, retained for the life of the trade.
  };

class CMarcoStagedTP
  {
public:
   static string Name(int kind)
     { return kind == 0 ? "LB" : (kind == 1 ? "IND" : (kind == 2 ? "RR" : "RR+1")); }

   static bool ValidTarget(int direction, double entry, double price)
     { return MathIsValidNumber(price) && price > 0.0 && direction * (price-entry) > 0.0; }

   static void Add(SMarcoTPPlan &plan, int kind, double price, double fraction)
     {
      int i = plan.count++;
      plan.kind[i] = kind;
      plan.price[i] = price;
      plan.fraction[i] = fraction;
     }

   static bool Build(SMarcoTPPlan &plan, bool buy, double entry, double sl,
                     double lb, double ind, double rr, int priority,
                     double spreadAdjustment, double tickSize, int digits)
     {
      ZeroMemory(plan);
      plan.direction = buy ? 1 : -1;
      plan.entry = entry;
      plan.initialSL = sl;
      plan.remaining = 1.0;
      double risk = plan.direction * (entry-sl);
      if(!MathIsValidNumber(risk) || risk <= 0 || !MathIsValidNumber(rr) || rr <= 0 ||
         !MathIsValidNumber(tickSize) || tickSize <= 0 || spreadAdjustment < 0 ||
         !MathIsValidNumber(spreadAdjustment) || priority < 0 || priority > 2) return false;
      bool hasLB = ValidTarget(plan.direction, entry, lb);
      bool hasIND = ValidTarget(plan.direction, entry, ind);
      int structural = (hasLB ? 1 : 0) + (hasIND ? 1 : 0);
      double fallback = entry + plan.direction * rr * risk;
      if(structural == 2)
        {
         Add(plan, 0, lb, priority == 0 ? 0.50 : 0.25);
         Add(plan, 1, ind, priority == 1 ? 0.50 : 0.25);
         Add(plan, 2, fallback, priority == 2 ? 0.50 : 0.25);
        }
      else if(structural == 1)
        {
         Add(plan, hasLB ? 0 : 1, hasLB ? lb : ind, priority == 2 ? 0.25 : 0.75);
         Add(plan, 2, fallback, priority == 2 ? 0.75 : 0.25);
        }
      else
        {
         Add(plan, 2, fallback, 0.75);
         Add(plan, 3, entry + plan.direction * (rr+1.0) * risk, 0.25);
        }
      for(int i=0; i<plan.count; i++)
        {
         double adjusted = plan.price[i] - plan.direction * spreadAdjustment;
         // Round towards entry, preserving the existing spread-adjustment option.
         double units = adjusted / tickSize;
         plan.price[i] = NormalizeDouble((buy ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize, digits);
         // Do not silently turn an invalid adjusted TP into a different target.
         if(!ValidTarget(plan.direction, entry, plan.price[i])) return false;
        }
      return true;
     }

   static int Next(const SMarcoTPPlan &plan)
     {
      int next = -1;
      for(int i=0; i<plan.count; i++)
         if(plan.closed[i]+1e-9 < plan.fraction[i] &&
            (next < 0 || plan.direction*(plan.price[i]-plan.price[next]) < 0)) next=i;
      return next;
     }

   static double Farthest(const SMarcoTPPlan &plan)
     {
      double price = plan.price[0];
      for(int i=1; i<plan.count; i++)
         if(plan.direction*(plan.price[i]-price)>0) price=plan.price[i];
      return price;
     }

   static int LastPending(const SMarcoTPPlan &plan)
     {
      int last=-1;
      for(int i=0;i<plan.count;i++)
         if(plan.closed[i]+1e-9<plan.fraction[i] &&
            (last<0 || plan.direction*(plan.price[i]-plan.price[last])>0)) last=i;
      return last;
     }

   static double Stop(const SMarcoTPPlan &plan)
     {
      double stop=plan.breakeven ? plan.entry : plan.initialSL;
      if(plan.protectedSL>0 && plan.direction*(plan.protectedSL-stop)>0) stop=plan.protectedSL;
      return stop;
     }

   static void TightenStop(SMarcoTPPlan &plan, double candidate)
     {
      // Never cross to the loss side of entry, or loosen an already tighter stop.
      if(candidate<=0 || plan.direction*(candidate-plan.entry)<0) candidate=plan.entry;
      plan.breakeven=true;
      if(plan.protectedSL<=0 || plan.direction*(candidate-plan.protectedSL)>0) plan.protectedSL=candidate;
     }

   static bool Extend(SMarcoTPPlan &plan, int count, double rr, double tick, int digits, datetime now)
     {
      int last=LastPending(plan);
      if(last<0 || count<=0 || plan.remaining<=1e-9 || rr<=0 || tick<=0) return false;
      double distance=count*rr*MathAbs(plan.entry-plan.initialSL);
      double raw=plan.price[last]+plan.direction*distance;
      if(!MathIsValidNumber(raw) || !MathIsValidNumber(distance) || distance<=0 || raw<=0) return false;
      double units=raw/tick;
      double target=NormalizeDouble((plan.direction==1 ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*tick,digits);
      if(target<=0 || plan.direction*(target-plan.price[last])<=0) return false;
      plan.price[last]=target;
      plan.vicinityTime[last]=0; // A near-touch of the old TP cannot close the extended target.
      plan.extensionCount+=count; plan.extensionTime=now;
      return true;
     }

   static int Primary(const SMarcoTPPlan &plan)
     {
      int p=0;
      for(int i=1; i<plan.count; i++) if(plan.fraction[i]>plan.fraction[p]) p=i;
      return p;
     }

   static void RebaseFill(SMarcoTPPlan &plan, double fill, double rr, double adjustment, double tickSize, int digits)
     {
      plan.entry=fill;
      double risk=MathAbs(fill-plan.initialSL);
      // Zones and allocations stay frozen; RR distances use the actual filled entry.
      for(int i=0;i<plan.count;i++)
         if(plan.kind[i]>=2)
           {
            double multiple=rr+(plan.kind[i]==3 ? 1.0 : 0.0);
            double units=(fill+plan.direction*(multiple*risk-adjustment))/tickSize;
            plan.price[i]=NormalizeDouble((plan.direction==1 ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize,digits);
           }
     }

   static double Lots(double maximum, double step, double minimum)
     {
      if(step<=0 || minimum<=0 || maximum<=0) return 0;
      double lots=NormalizeDouble(MathFloor(maximum/(4.0*step)+1e-8)*4.0*step,8);
      return lots/4.0+1e-9 >= minimum ? lots : 0.0;
     }

   // A stage closes a share of ORIGINAL volume, never a share of the remainder.
   static double Exit(SMarcoTPPlan &plan, int stage, double fraction, double price, datetime time,
                      bool normalTarget=true)
     {
      fraction = MathMin(fraction, plan.remaining);
      if(stage>=0) fraction=MathMin(fraction, plan.fraction[stage]-plan.closed[stage]);
      if(fraction<=1e-9) return 0;
      double reward=fraction*plan.direction*(price-plan.entry)/MathAbs(plan.entry-plan.initialSL);
      plan.realizedR+=reward;
      plan.remaining=MathMax(0.0,plan.remaining-fraction);
      if(stage>=0)
        {
         plan.exitPrice[stage]=(plan.exitPrice[stage]*plan.closed[stage]+price*fraction)/(plan.closed[stage]+fraction);
         plan.closed[stage]+=fraction;
         plan.exitTime[stage]=time;
         // Only the normal, entry-time TP allocation is subject to this gate.
         // Structure exits can redistribute fractions and LB extensions have
         // their own stop rules; preserve their existing later-TP behaviour.
         bool otherScenario=!normalTarget || plan.extensionCount>0 ||
                            plan.structureClosed[0]>0 || plan.structureClosed[1]>0 ||
                            plan.sequence.closed[0]>0 || plan.sequence.closed[1]>0;
         // Until another scenario intervenes, fractions are the frozen entry
         // allocations: 50/25/25 or 75/25. The exception is two fully closed
         // quarter targets: together they protect the remaining half at BE.
         // A touch or an incomplete broker execution does not complete a stage.
         int completedQuarters=0;
         for(int i=0;i<plan.count;i++)
            if(MathAbs(plan.fraction[i]-0.25)<1e-9 &&
               plan.closed[i]+1e-9>=plan.fraction[i]) completedQuarters++;
         if(otherScenario || completedQuarters>=2 || (plan.fraction[stage]>=0.5 &&
                              plan.closed[stage]+1e-9>=plan.fraction[stage]))
            plan.breakeven=true;
        }
      return reward;
     }

   // A share of currently open volume; neither side may violate the broker lot grid.
   static double PartialLots(double remainingLots, double share, double step, double minimum)
     {
      if(step<=0 || minimum<=0 || share<=0 || share>=1 || remainingLots<=0) return 0;
      double lots=NormalizeDouble(MathFloor(remainingLots*share/step+1e-8)*step,8);
      return lots+1e-9>=minimum && remainingLots-lots+1e-9>=minimum ? lots : 0.0;
     }

   static double HalfLots(double remainingLots, double step, double minimum)
     { return PartialLots(remainingLots,0.5,step,minimum); }

   static void StructureExit(SMarcoTPPlan &plan, bool full, double fraction, double price,
                             datetime time, double originalLots, double step, double minimum,
                             bool moveToBreakeven=true)
     {
      double before=plan.remaining;
      fraction=MathMin(fraction,before);
      if(fraction<=1e-9) return;
      int index=full ? 1 : 0;
      double prior=plan.structureClosed[index];
      plan.structurePrice[index]=(plan.structurePrice[index]*prior+price*fraction)/(prior+fraction);
      plan.structureClosed[index]+=fraction; plan.structureTime[index]=time;
      Exit(plan,-1,fraction,price,time);
      if(!full && moveToBreakeven) plan.breakeven=true;
      // Reduce outstanding allocations proportionally, respecting broker volume steps.
      // Any indivisible residue stays at the farthest still-outstanding target.
      int last=-1; double allocated=0;
      for(int i=0;i<plan.count;i++)
        {
         double pending=plan.fraction[i]-plan.closed[i];
         if(pending<=1e-9) continue;
         if(last<0 || plan.direction*(plan.price[i]-plan.price[last])>0) last=i;
         double lots=NormalizeDouble(MathFloor(pending*plan.remaining/before*originalLots/step+1e-8)*step,8);
         if(lots+1e-9<minimum) lots=0;
         plan.fraction[i]=plan.closed[i]+lots/originalLots;
         allocated+=lots/originalLots;
        }
      if(last>=0) plan.fraction[last]+=MathMax(0.0,plan.remaining-allocated);
     }

   static void SequenceFill(SMarcoTPPlan &plan, double lots, double price, datetime time,
                            double originalLots, double step, double minimum)
     {
      int index=plan.sequence.step-1;
      if(index<0 || index>1 || lots<=0 || originalLots<=0) return;
      double fraction=MathMin(lots/originalLots,plan.remaining);
      if(fraction<=1e-9) return;
      double prior=plan.sequence.closed[index];
      plan.sequence.price[index]=(plan.sequence.price[index]*prior+price*fraction)/(prior+fraction);
      plan.sequence.closed[index]+=fraction; plan.sequence.time[index]=time;
      // Reuse allocation accounting without labelling these fills as legacy CHoCH exits.
      double oldClosed[2],oldPrice[2]; datetime oldTime[2];
      for(int i=0;i<2;i++) { oldClosed[i]=plan.structureClosed[i]; oldPrice[i]=plan.structurePrice[i]; oldTime[i]=plan.structureTime[i]; }
      StructureExit(plan,plan.sequence.share>=1,fraction,price,time,originalLots,step,minimum,
                    plan.direction*(price-plan.entry)>0);
      for(int i=0;i<2;i++) { plan.structureClosed[i]=oldClosed[i]; plan.structurePrice[i]=oldPrice[i]; plan.structureTime[i]=oldTime[i]; }
      plan.sequence.requestedLots=MathMax(0.0,plan.sequence.requestedLots-lots);
      if(plan.remaining<=1e-9 || plan.sequence.requestedLots<step*0.1)
        { plan.sequence.pending=false; plan.sequence.requestedLots=0; }
     }

   // OHLC fallback: bullish candle O-L-H-C; bearish candle O-H-L-C.
   // This is a deterministic simulation assumption, not reconstructed tick history.
   static void Bar(SMarcoTPPlan &plan, datetime time, double open, double high, double low, double close,
                   bool vicinity, double distance, bool rejection, datetime rejectionStart,
                   double &lastExit)
     {
      double path[4]; path[0]=open; path[1]=close>=open ? low : high;
      path[2]=close>=open ? high : low; path[3]=close;
      double stop=Stop(plan);
      if(plan.direction*(open-stop)<=0)
        { Exit(plan,-1,plan.remaining,open,time); lastExit=open; return; }
      for(int leg=0; leg<4 && plan.remaining>1e-9; leg++)
        {
         double end=path[leg];
         stop=Stop(plan);
         if(plan.direction*(end-stop)<=0)
           { Exit(plan,-1,plan.remaining,stop,time); lastExit=stop; return; }
         int stage=Next(plan);
         while(stage>=0 && plan.direction*(end-plan.price[stage])>=0)
           {
            double fill=leg==0 ? open : plan.price[stage];
            Exit(plan,stage,plan.fraction[stage]-plan.closed[stage],fill,time);
            lastExit=fill;
            stage=Next(plan);
           }
         if(vicinity && stage>=0 && plan.vicinityTime[stage]==0 &&
            plan.direction*(end-plan.price[stage])>=-distance) plan.vicinityTime[stage]=time;
        }
      if(vicinity && rejection && plan.direction*(close-plan.entry)>0)
         for(int i=0; i<plan.count; i++)
            if(plan.vicinityTime[i]>0 &&
               plan.closed[i]+1e-9<plan.fraction[i])
              {
               Exit(plan,i,plan.fraction[i]-plan.closed[i],close,time,false);
               lastExit=close;
              }
     }
  };
#endif

#ifndef MARCO_OPPOSING_SEQUENCE_MQH
#define MARCO_OPPOSING_SEQUENCE_MQH



struct SMarcoSequenceSignal
  {
   int action, step, tf; // 0=no close, 1=partial, 2=full remaining close.
   datetime eventTime;
   string lbId;
   double share;
   bool profit;
  };

class CMarcoOpposingSequence
  {
public:
   static int Direction(string name)
     {
      if(name=="BL-BOS" || name=="BL-CHoCH" || name=="BSL-Swept") return 1;
      if(name=="BR-BOS" || name=="BR-CHoCH" || name=="SSL-Swept") return -1;
      return 0;
     }

   static bool Source(CTradeRejectionHistory &history, const SRejectionEvent &event,
                      int direction, ENUM_TIMEFRAMES tf, string &id)
     {
      for(int i=history.ZoneCount()-1;i>=0;i--)
        {
         SRejectionLB lb;
         if(!history.ZoneAt(i,lb) || lb.bull!=(direction==1) || lb.available>event.available ||
            (lb.until>0 && event.available>=lb.until)) continue;
         if(lb.choch!=event.time &&
            !CTradeRejection::OriginInside(event.originTime,event.originPrice,lb.created,
                                          lb.mitigation,PeriodSeconds(tf),lb.low,lb.high,0)) continue;
         id=lb.id; return true;
        }
      return false;
     }

   static SMarcoSequenceSignal Advance(CTradeRejectionHistory &history, SMarcoOpposingSequence &state,
                                       int slot, ENUM_TIMEFRAMES tf, int direction, double entry,
                                       double executionPrice, datetime opened, datetime now)
     {
      SMarcoSequenceSignal result; ZeroMemory(result);
      if(state.pending || state.step>=2 || (state.step==1 && state.tf!=(int)tf)) return result;
      // Select by event time, not insertion order: label revisions are appended
      // to history but must never become another first/second structure.
      for(int pass=0;pass<history.EventCount();pass++)
        {
         SRejectionEvent next; bool found=false;
         for(int i=0;i<history.EventCount();i++)
           {
            SRejectionEvent event;
            if(!history.EventAt(i,now,event) || event.time<=state.seen[slot] ||
               event.time<opened || event.available<=opened || Direction(event.name)==0) continue;
            if(!found || event.time<next.time) { next=event; found=true; }
           }
         if(!found) break;
         state.seen[slot]=next.time;
         int opposing=-direction;
         if(state.step==1)
           {
            for(int i=0;i<history.EventCount();i++)
              {
               SRejectionEvent first;
               if(history.EventAt(i,now,first) && first.time==state.firstEvent && Direction(first.name)!=opposing)
                 { state.step=2; return result; }
              }
            // The next structural event must be adjacent on the SAME timeframe.
            // A return to the trade's direction cancels the outstanding second exit.
            state.step=2;
            if(Direction(next.name)!=opposing) return result;
            result.profit=direction*(executionPrice-entry)>0;
            result.share=state.firstProfit && result.profit ? 0.25 : 1.0;
           }
         else
           {
            if(Direction(next.name)!=opposing || !Source(history,next,opposing,tf,result.lbId)) continue;
            state.step=1; state.tf=(int)tf; state.firstEvent=next.time;
            state.firstProfit=direction*(executionPrice-entry)>0;
            result.profit=state.firstProfit;
            result.share=result.profit ? 0.25 : 0.50;
           }
         result.step=state.step; result.tf=(int)tf; result.eventTime=next.time;
         result.action=result.share>=1 ? 2 : (result.share>0 ? 1 : 0);
         state.pending=result.action>0; state.share=result.share; state.requestedLots=0;
         return result;
        }
      return result;
     }
  };
#endif

#ifndef MARCO_STAGED_TP_LIVE_MQH
#define MARCO_STAGED_TP_LIVE_MQH



struct SMarcoLiveTPState
  {
   SMarcoTPPlan plan;
   SMarcoExtensionState extension;
   double lots, riskCash;
   int pendingStage; // 0..2 normal TP, 3..6 structure/sequence, 7..9 vicinity TP.
   double pendingBefore, pendingVolume;
   ulong pendingOrder;
   datetime retryAt;
   int structureAction; // Durable intent: 1=half remaining, 2=full close.
  };

// Per-position durable state is separate from the daily report, so partial exits
// survive a chart/input restart and journal rewrites. Never recalculate target zones.
class CMarcoLiveStagedTP
  {
public:
   static ulong Select(ulong identifier)
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==identifier) return ticket;
        }
      return 0;
     }
   static string Path(long long magic, ulong identifier)
     {
      return "marcotrades\\LiveEA\\TP_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
             IntegerToString(magic)+"_"+IntegerToString(identifier)+".bin";
     }
   static bool Save(long long magic, ulong identifier, const SMarcoLiveTPState &state)
     {
      FolderCreate("marcotrades"); FolderCreate("marcotrades\\LiveEA");
      string path=Path(magic,identifier), temp=path+".tmp";
      int f=FileOpen(temp,FILE_WRITE|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      FileWriteInteger(f,5); FileWriteInteger(f,state.plan.count); FileWriteInteger(f,state.plan.direction);
      FileWriteDouble(f,state.plan.entry); FileWriteDouble(f,state.plan.initialSL);
      FileWriteDouble(f,state.plan.remaining); FileWriteDouble(f,state.plan.realizedR);
      FileWriteInteger(f,state.plan.breakeven ? 1 : 0);
      FileWriteDouble(f,state.lots); FileWriteDouble(f,state.riskCash);
      for(int i=0;i<3;i++)
        {
         FileWriteInteger(f,state.plan.kind[i]);
         FileWriteDouble(f,state.plan.price[i]); FileWriteDouble(f,state.plan.fraction[i]);
         FileWriteDouble(f,state.plan.closed[i]); FileWriteDouble(f,state.plan.exitPrice[i]);
         FileWriteLong(f,(long long)state.plan.exitTime[i]); FileWriteLong(f,(long long)state.plan.vicinityTime[i]);
        }
      FileWriteInteger(f,state.pendingStage); FileWriteDouble(f,state.pendingBefore);
      FileWriteDouble(f,state.pendingVolume); FileWriteLong(f,(long long)state.pendingOrder);
      FileWriteLong(f,(long long)state.retryAt);
      for(int i=0;i<2;i++)
        {
         FileWriteDouble(f,state.plan.structureClosed[i]); FileWriteDouble(f,state.plan.structurePrice[i]);
         FileWriteLong(f,(long long)state.plan.structureTime[i]);
        }
      FileWriteInteger(f,state.structureAction);
      FileWriteDouble(f,state.plan.protectedSL); FileWriteInteger(f,state.plan.extensionCount);
      FileWriteLong(f,(long long)state.plan.extensionTime);
      int keys=StringLen(state.extension.seen); FileWriteInteger(f,keys);
      if(keys>0) FileWriteString(f,state.extension.seen,keys);
      for(int i=0;i<2;i++) FileWriteLong(f,(long long)state.plan.sequence.seen[i]);
      FileWriteInteger(f,state.plan.sequence.step); FileWriteInteger(f,state.plan.sequence.tf);
      FileWriteLong(f,(long long)state.plan.sequence.firstEvent);
      FileWriteInteger(f,state.plan.sequence.firstProfit ? 1 : 0);
      FileWriteInteger(f,state.plan.sequence.pending ? 1 : 0);
      FileWriteDouble(f,state.plan.sequence.share); FileWriteDouble(f,state.plan.sequence.requestedLots);
      for(int i=0;i<2;i++)
        {
         FileWriteDouble(f,state.plan.sequence.closed[i]); FileWriteDouble(f,state.plan.sequence.price[i]);
         FileWriteLong(f,(long long)state.plan.sequence.time[i]);
        }
      FileFlush(f);
      bool complete=FileTell(f)==(ulong)(436+keys*2);
      FileClose(f);
      return complete && FileMove(temp,0,path,FILE_REWRITE);
     }
   static bool Load(long long magic, ulong identifier, SMarcoLiveTPState &state)
     {
      ZeroMemory(state); state.pendingStage=-1;
      int f=FileOpen(Path(magic,identifier),FILE_READ|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      ulong size=FileSize(f); int version=FileReadInteger(f);
      if(!((version==1 && size==256) || (version==2 && size==308) ||
           (version==3 && size>=332 && size<=2000332) || ((version==4 || version==5) && size>=436 && size<=2000436))) { FileClose(f); return false; }
      state.plan.count=FileReadInteger(f); state.plan.direction=FileReadInteger(f);
      state.plan.entry=FileReadDouble(f); state.plan.initialSL=FileReadDouble(f);
      state.plan.remaining=FileReadDouble(f); state.plan.realizedR=FileReadDouble(f);
      state.plan.breakeven=FileReadInteger(f)!=0;
      state.lots=FileReadDouble(f); state.riskCash=FileReadDouble(f);
      for(int i=0;i<3;i++)
        {
         state.plan.kind[i]=FileReadInteger(f);
         state.plan.price[i]=FileReadDouble(f); state.plan.fraction[i]=FileReadDouble(f);
         state.plan.closed[i]=FileReadDouble(f); state.plan.exitPrice[i]=FileReadDouble(f);
         state.plan.exitTime[i]=(datetime)FileReadLong(f); state.plan.vicinityTime[i]=(datetime)FileReadLong(f);
        }
      state.pendingStage=FileReadInteger(f); state.pendingBefore=FileReadDouble(f);
      state.pendingVolume=FileReadDouble(f); state.pendingOrder=(ulong)FileReadLong(f);
      state.retryAt=(datetime)FileReadLong(f);
      if(version>=2)
        {
         for(int i=0;i<2;i++)
           {
            state.plan.structureClosed[i]=FileReadDouble(f); state.plan.structurePrice[i]=FileReadDouble(f);
            state.plan.structureTime[i]=(datetime)FileReadLong(f);
           }
         state.structureAction=FileReadInteger(f);
        }
      if(version>=3)
        {
         state.plan.protectedSL=FileReadDouble(f); state.plan.extensionCount=FileReadInteger(f);
         state.plan.extensionTime=(datetime)FileReadLong(f);
         int keys=FileReadInteger(f);
         if(keys<0 || keys>1000000 || size!=(ulong)((version>=4 ? 436 : 332)+keys*2)) { FileClose(f); return false; }
         if(keys>0) state.extension.seen=FileReadString(f,keys);
         if(StringLen(state.extension.seen)!=keys) { FileClose(f); return false; }
        }
      if(version>=4)
        {
         for(int i=0;i<2;i++) state.plan.sequence.seen[i]=(datetime)FileReadLong(f);
         state.plan.sequence.step=FileReadInteger(f); state.plan.sequence.tf=FileReadInteger(f);
         state.plan.sequence.firstEvent=(datetime)FileReadLong(f);
         state.plan.sequence.firstProfit=FileReadInteger(f)!=0;
         state.plan.sequence.pending=FileReadInteger(f)!=0;
         state.plan.sequence.share=FileReadDouble(f); state.plan.sequence.requestedLots=FileReadDouble(f);
         for(int i=0;i<2;i++)
           {
            state.plan.sequence.closed[i]=FileReadDouble(f); state.plan.sequence.price[i]=FileReadDouble(f);
            state.plan.sequence.time[i]=(datetime)FileReadLong(f);
           }
        }
      else
        {
         // Upgrading a running position must not replay old opposing structures.
         state.plan.sequence.seen[0]=TimeCurrent(); state.plan.sequence.seen[1]=TimeCurrent();
         if(state.plan.structureClosed[0]>0 || state.plan.structureClosed[1]>0) state.plan.sequence.step=2;
        }
      FileClose(f);
      bool valid=state.plan.count>=2 && state.plan.count<=3 && MathAbs(state.plan.direction)==1 && state.lots>0 &&
             (state.pendingStage==-1 || (state.pendingStage>=0 && state.pendingStage<state.plan.count) ||
              state.pendingStage==3 || state.pendingStage==4 || state.pendingStage==5 || state.pendingStage==6 ||
              (version>=5 && state.pendingStage>=7 && state.pendingStage<7+state.plan.count)) &&
             state.structureAction>=0 && state.structureAction<=2 && state.plan.sequence.step>=0 && state.plan.sequence.step<=2 &&
             (!state.plan.sequence.pending || (state.plan.sequence.step>0 && state.plan.sequence.share>0 && state.plan.sequence.share<=1));
      return valid && (version>=5 || Save(magic,identifier,state));
     }

   static void Breakeven(CTrade &trade, ulong identifier, const SMarcoLiveTPState &state)
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return;
      ulong ticket=Select(identifier);
      if(ticket==0) return;
      double sl=PositionGetDouble(POSITION_SL);
      string symbol=PositionGetString(POSITION_SYMBOL);
      double grid=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      if(grid<=0) return;
      // A multi-fill average entry can fall between ticks. Round BE towards profit.
      double desired=CMarcoStagedTP::Stop(state.plan);
      double units=desired/grid;
      double be=NormalizeDouble((state.plan.direction==1 ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*grid,
                                (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
      int last=CMarcoStagedTP::LastPending(state.plan);
      double target=last>=0 ? state.plan.price[last] : CMarcoStagedTP::Farthest(state.plan);
      bool moveSL=(state.plan.breakeven || state.plan.protectedSL>0) && (sl<=0 || state.plan.direction*(sl-be)<-1e-9);
      if(!moveSL && MathAbs(PositionGetDouble(POSITION_TP)-target)<1e-9) return;
      // A rejected stops/freeze-level modification remains pending and is retried.
      trade.SetAsyncMode(false);
      bool modified=trade.PositionModify(ticket,moveSL ? be : sl,target);
      if(moveSL && (!modified || trade.ResultRetcode()!=TRADE_RETCODE_DONE))
        {
         // A too-close/frozen SL must not prevent the independent TP extension.
         if(Select(identifier)>0 && MathAbs(PositionGetDouble(POSITION_TP)-target)>1e-9)
            trade.PositionModify(ticket,PositionGetDouble(POSITION_SL),target);
        }
     }

   static void RecordFill(SMarcoLiveTPState &state, int stage, double lots, double price, string symbol)
     {
      if(stage>=7)
         CMarcoStagedTP::Exit(state.plan,stage-7,lots/state.lots,price,TimeCurrent(),false);
      else if(stage>=5)
        {
         CMarcoStagedTP::SequenceFill(state.plan,lots,price,TimeCurrent(),state.lots,
                                    SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
        }
      else if(stage>=3)
        {
         CMarcoStagedTP::StructureExit(state.plan,stage==4,lots/state.lots,price,TimeCurrent(),
                                      state.lots,SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
         if(stage==4 || state.structureAction==1) state.structureAction=0;
        }
      else CMarcoStagedTP::Exit(state.plan,stage,lots/state.lots,price,TimeCurrent());
     }

   static bool Manage(CTrade &trade, long long magic, ulong identifier, string symbol,
                      bool useVicinity, double vicinityDistance, ENUM_TIMEFRAMES vicinityTF, int structureAction=0)
     {
      SMarcoLiveTPState state;
      if(!Load(magic,identifier,state)) return false; // Legacy positions retain legacy handling.
      ulong ticket=Select(identifier);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol || PositionGetInteger(POSITION_MAGIC)!=magic) return false;
      if(structureAction>state.structureAction && (structureAction==2 || state.plan.structureTime[0]==0))
        {
         state.structureAction=structureAction;
         if(!Save(magic,identifier,state)) return false;
        }
      double volume=PositionGetDouble(POSITION_VOLUME);
      double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      if(step<=0) return false;
      MqlTick tick={}; if(!SymbolInfoTick(symbol,tick)) return false;
      double price=state.plan.direction==1 ? tick.bid : tick.ask;
      bool changed=false;
      // Persisted before sending: an uncertain request must never be blindly resent.
      if(state.pendingStage>=0)
        {
         double reduced=state.pendingBefore-volume;
         if(reduced>step*0.1)
           {
            RecordFill(state,state.pendingStage,reduced,price,symbol);
            state.pendingStage=-1; state.pendingOrder=0;
            if(!Save(magic,identifier,state)) return false;
            changed=true;
           }
         else if(state.pendingOrder>0 && HistoryOrderSelect(state.pendingOrder))
           {
            long long status=HistoryOrderGetInteger(state.pendingOrder,ORDER_STATE);
            if(status==ORDER_STATE_REJECTED || status==ORDER_STATE_CANCELED || status==ORDER_STATE_EXPIRED)
              {
               state.pendingStage=-1; state.pendingOrder=0; state.retryAt=TimeCurrent()+5;
               if(!Save(magic,identifier,state)) return false;
              }
            else return false;
           }
         else return false;
        }
      Breakeven(trade,identifier,state);
      // Do not allocate another strategy's/manual additions or unexplained reductions.
      if(MathAbs(volume-state.lots*state.plan.remaining)>step*0.1) return changed;
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return changed;
      if(TimeCurrent()<state.retryAt) return changed;
      // Broker stop/freeze limits may reject SL=entry. Protect the remainder at
      // market if price crosses the requested protective stop before the server accepts it.
      if(state.structureAction!=2 && (state.plan.breakeven || state.plan.protectedSL>0) &&
         state.plan.direction*(price-CMarcoStagedTP::Stop(state.plan))<=0)
        {
         trade.SetAsyncMode(false);
         if(trade.PositionClose(ticket) && trade.ResultRetcode()==TRADE_RETCODE_DONE)
           {
            CMarcoStagedTP::Exit(state.plan,-1,state.plan.remaining,trade.ResultPrice(),TimeCurrent());
            Save(magic,identifier,state);
            return true;
           }
         state.retryAt=TimeCurrent()+5; Save(magic,identifier,state);
         return changed;
        }
      for(int n=0;n<state.plan.count+1 && state.plan.remaining>1e-9;n++)
        {
         int stage=state.structureAction>0 ? (state.structureAction==2 ? 4 : 3) :
                   (state.plan.sequence.pending ? (state.plan.sequence.share>=1 ? 6 : 5) : CMarcoStagedTP::Next(state.plan));
         if(stage<0) break;
         bool structural=stage>=3;
         bool hit=structural;
         bool vicinityExit=false;
         if(!structural) hit=state.plan.direction*(price-state.plan.price[stage])>=0;
         if(!structural && useVicinity && state.plan.direction*(price-state.plan.price[stage])>=-vicinityDistance && state.plan.vicinityTime[stage]==0)
           {
            state.plan.vicinityTime[stage]=TimeCurrent();
            if(!Save(magic,identifier,state)) return changed;
           }
         if(!structural && !hit && useVicinity && state.plan.vicinityTime[stage]>0 && state.plan.direction*(price-state.plan.entry)>0)
           {
            datetime bar=iTime(symbol,vicinityTF,1);
            if(bar>0 && bar+PeriodSeconds(vicinityTF)>state.plan.vicinityTime[stage])
             {
               hit=state.plan.direction*(iClose(symbol,vicinityTF,1)-iOpen(symbol,vicinityTF,1))<0;
               vicinityExit=hit;
             }
           }
         if(!hit) break;
         ticket=Select(identifier); if(ticket==0) break;
         volume=PositionGetDouble(POSITION_VOLUME);
         double closeLots=volume;
         if(stage>=5)
           {
            if(state.plan.sequence.requestedLots<=0)
               state.plan.sequence.requestedLots=stage==6 ? volume : CMarcoStagedTP::PartialLots(volume,state.plan.sequence.share,step,SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
            closeLots=state.plan.sequence.requestedLots;
           }
         else if(stage==3) closeLots=CMarcoStagedTP::HalfLots(volume,step,SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
         else if(stage<3) closeLots=NormalizeDouble(state.lots*(state.plan.fraction[stage]-state.plan.closed[stage]),8);
         if(stage==3 && closeLots<=0)
           {
            PrintFormat("[CHOCH EXIT] %s #%I64u: remaining %.8f lots cannot be halved on broker lot grid; existing exits retained.",symbol,identifier,volume);
            state.plan.structureTime[0]=TimeCurrent(); state.structureAction=0;
            if(!Save(magic,identifier,state)) return changed;
            continue;
           }
         if(stage>=5 && closeLots<=0)
           {
            PrintFormat("[OPPOSING SEQUENCE SKIPPED] %s #%I64u step=%d: requested share cannot fit broker lot grid.",symbol,identifier,state.plan.sequence.step);
            state.plan.sequence.pending=false;
            if(!Save(magic,identifier,state)) return changed;
            continue;
           }
         closeLots=MathMin(closeLots,volume);
         MqlTradeRequest request={}; MqlTradeResult result={}; MqlTradeCheckResult check={};
         request.action=TRADE_ACTION_DEAL; request.position=ticket; request.symbol=symbol; request.magic=magic;
         request.type=state.plan.direction==1 ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price=price; request.volume=closeLots; request.deviation=10;
         request.type_filling=ORDER_FILLING_FOK;
         request.comment=stage>=5 ? "OPP SEQ "+IntegerToString(state.plan.sequence.step) :
                         (structural ? (stage==4 ? "CHOCH FULL" : "CHOCH HALF") : "MTP"+IntegerToString(stage));
         if(!OrderCheck(request,check) || (check.retcode!=TRADE_RETCODE_DONE && check.retcode!=0))
           { state.retryAt=TimeCurrent()+5; Save(magic,identifier,state); break; }
         state.pendingStage=vicinityExit ? stage+7 : stage;
         state.pendingBefore=volume; state.pendingVolume=closeLots; state.pendingOrder=0;
         if(!Save(magic,identifier,state)) break;
         trade.SetAsyncMode(false);
         bool sent=trade.OrderSend(request,result);
         state.pendingOrder=result.order;
         if(result.retcode==TRADE_RETCODE_DONE && result.volume>0)
           {
            RecordFill(state,state.pendingStage,result.volume,result.price,symbol);
            state.pendingStage=-1; state.pendingOrder=0;
            if(stage>=5)
               PrintFormat("[OPPOSING SEQUENCE FILLED] %s #%I64u step=%d: closed %.8f lots at %.8f remaining=%.8f",
                           symbol,identifier,state.plan.sequence.step,result.volume,result.price,state.lots*state.plan.remaining);
            else if(structural)
               PrintFormat("[CHOCH EXIT FILLED] %s #%I64u %s: closed %.8f lots at %.8f",symbol,identifier,stage==4 ? "FULL" : "HALF + BE",result.volume,result.price);
            else
               PrintFormat("[PARTIAL TP] %s #%I64u %s: closed %.8f lots of original %.8f; stop=%.8f BE_requested=%s",
                           symbol,identifier,CMarcoStagedTP::Name(state.plan.kind[stage]),result.volume,state.lots,
                           CMarcoStagedTP::Stop(state.plan),state.plan.breakeven ? "true" : "false");
            changed=true;
           }
         else if(result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_TIMEOUT &&
                 result.retcode!=TRADE_RETCODE_CONNECTION && result.retcode!=TRADE_RETCODE_DONE_PARTIAL && result.retcode!=0)
           { state.pendingStage=-1; state.pendingOrder=0; state.retryAt=TimeCurrent()+5; }
         if(state.pendingStage>=0)
            PrintFormat("[TP EXIT PENDING] %s #%I64u: code=%u order=%I64u; waiting for broker confirmation before another close.",
                        symbol,identifier,result.retcode,result.order);
         if(!Save(magic,identifier,state)) return changed;
         Breakeven(trade,identifier,state);
         if(state.pendingStage>=0 || !sent || result.retcode!=TRADE_RETCODE_DONE) break;
        }
      return changed;
     }
  };
#endif


int checks=0;
void check(bool v){++checks;if(!v){std::cerr<<"Failed check "<<checks<<"\n";std::exit(1);}}
void eq(double a,double b){check(std::abs(a-b)<1e-8);}
SMarcoTPPlan plan(int d){SMarcoTPPlan p;check(CMarcoStagedTP::Build(p,d==1,100,100-d*10,100+d*20,100+d*30,1,2,0,.01,2));return p;}
void event(CTradeRejectionHistory &h,int d,int t,string name=""){
 if(name=="") name=d==1?"BR-CHoCH":"BL-CHoCH";
 h.Observe(name,t,t+60,150,105,105);
}
void source(CTradeRejectionHistory &h,int d,int available=260){
 h.BeginZones();h.Zone("raw-opposing",d==-1,104,106,150,0,200,available);h.EndZones(available);
}
SMarcoSequenceSignal advance(CTradeRejectionHistory &h,SMarcoTPPlan &p,double price,int now,int slot=0,int tf=3){
 return CMarcoOpposingSequence::Advance(h,p.sequence,slot,tf,p.direction,p.entry,price,100,now);
}
void fill(SMarcoTPPlan &p,double price,int now){
 double lots=p.sequence.share>=1?4*p.remaining:CMarcoStagedTP::PartialLots(4*p.remaining,p.sequence.share,.01,.01);
 p.sequence.requestedLots=lots;CMarcoStagedTP::SequenceFill(p,lots,price,now,4,.01,.01);
}
void reset(int d){files.clear();handles.clear();volume=4;sl=100-d*10;tp=100+d*30;bid=ask=100;step=.01;sends=mode=0;modifyAllowed=enabled=true;clockNow=1000;}
SMarcoLiveTPState load(){SMarcoLiveTPState s;check(CMarcoLiveStagedTP::Load(magic,identifier,s));return s;}
void save(SMarcoTPPlan p){SMarcoLiveTPState s{};s.plan=p;s.lots=4;s.riskCash=40;s.pendingStage=-1;check(CMarcoLiveStagedTP::Save(magic,identifier,s));}
int main(){
 for(int d:{-1,1}){
  for(bool firstProfit:{false,true})for(bool secondProfit:{false,true}){
   auto p=plan(d);CTradeRejectionHistory h;event(h,d,200);source(h,d);
   auto a=advance(h,p,100+d*(firstProfit?2:-2),259);eq(a.action,0);
   a=advance(h,p,100+d*(firstProfit?2:-2),260);eq(a.action,1);eq(a.share,firstProfit?.25:.5);
   eq(advance(h,p,100,260).action,0); // Pending requests cannot repeat.
   fill(p,100+d*(firstProfit?2:-2),260);eq(p.remaining,firstProfit?.75:.5);check(p.breakeven==firstProfit);
   eq(p.structureClosed[0],0);eq(p.sequence.closed[0],firstProfit?.25:.5);
   eq(advance(h,p,100,270).action,0); // Same event cannot become second.
   event(h,d,300,d==1?"BR-BOS":"BL-BOS");
   a=advance(h,p,100+d*(secondProfit?3:-3),360);
   double share=firstProfit && secondProfit ? .25 : 1;
   eq(a.share,share);eq(a.step,2);
   if(share>0)fill(p,100+d*(secondProfit?3:-3),360);
   eq(p.remaining,firstProfit && secondProfit ? .5625 : 0);
   event(h,d,400,d==1?"BR-BOS":"BL-BOS");eq(advance(h,p,100,460).action,0);
  }
  auto p=plan(d);CTradeRejectionHistory h;event(h,d,200); // Unlinked structure never starts.
  eq(advance(h,p,100,260).action,0);source(h,d,300);
  eq(advance(h,p,100,300).action,0); // Later LB cannot retrofit the already observed event.
  p=plan(d);h.Reset();event(h,d,200);source(h,d);advance(h,p,100-d*2,260);fill(p,100-d*2,260);
  event(h,d,300,d==1?"BL-BOS":"BR-BOS");eq(advance(h,p,100,360).action,0);eq(p.sequence.step,2);
  // Cross-TF event cannot be the second event of an already selected sequence.
  p=plan(d);h.Reset();event(h,d,200);source(h,d);advance(h,p,100-d*2,260);fill(p,100-d*2,260);
  event(h,d,300,d==1?"BR-BOS":"BL-BOS");eq(advance(h,p,100,360,1,1).action,0);eq(p.sequence.step,1);
  // A reclassification invalidating the first event cancels the second close.
  h.Observe(d==1?"BSL-Swept":"SSL-Swept",200,360,150,105,105);
  eq(advance(h,p,100,360).action,0);eq(p.sequence.step,2);
  // An unbroken BOS continuation retains the original raw LB connection even
  // when its own pivot is outside the LB. Test both entry and setup TF slots.
  for(int tf:{1,2,3}){
   CTradeRejectionHistory chain;source(chain,d);
   event(chain,d,200);
   chain.Observe(d==1?"BR-BOS":"BL-BOS",300,360,290,99,99);
   chain.Observe(d==1?"BR-BOS":"BL-BOS",400,460,390,98,98);
   SRejectionEvent tail;check(chain.Latest(460,tail));string id;
   check(CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));check(id=="raw-opposing");
   // The first post-entry BOS outside the LB must still start the exit,
   // followed by a full close at the next BOS after a losing first exit.
   auto linkedPlan=plan(d);
   auto linkedSignal=CMarcoOpposingSequence::Advance(chain,linkedPlan.sequence,tf==1?1:0,
                     tf,d,100,100-d*2,270,360);
   eq(linkedSignal.step,1);eq(linkedSignal.share,.5);
   fill(linkedPlan,100-d*2,360);
   linkedSignal=CMarcoOpposingSequence::Advance(chain,linkedPlan.sequence,tf==1?1:0,
                     tf,d,100,100+d*2,270,460);
   eq(linkedSignal.step,2);eq(linkedSignal.action,2);eq(linkedSignal.share,1);
   fill(linkedPlan,100+d*2,460);eq(linkedPlan.remaining,0);
   // An intervening reversal breaks the link; future revisions cannot break it early.
   chain.Observe(d==1?"BL-BOS":"BR-BOS",300,470,290,99,99);
   check(CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));
   chain.Observe(d==1?"BR-BOS":"BL-BOS",500,560,490,98,98);
   check(chain.Latest(560,tail));check(!CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));
   // A vanished or mitigated LB cannot start a fresh post-entry exit sequence.
   chain.Reset();source(chain,d);event(chain,d,200);
   chain.BeginZones();chain.EndZones(350);
   chain.Observe(d==1?"BR-BOS":"BL-BOS",400,460,390,98,98);
   check(chain.Latest(460,tail));check(!CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));
   chain.Reset();source(chain,d);event(chain,d,200);
   chain.BeginZones();chain.Zone("raw-opposing",d==-1,104,106,150,270,200,350);chain.EndZones(350);
   chain.Observe(d==1?"BR-BOS":"BL-BOS",600,660,590,98,98);
   check(chain.Latest(660,tail));check(!CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));
   // A later expansion must not invent a link to the older event's pivot.
   chain.Reset();chain.Zone("expanded",d==-1,110,112,150,0,0,260);event(chain,d,200);
   chain.BeginZones();chain.Zone("expanded",d==-1,104,112,150,0,0,350);chain.EndZones(350);
   chain.Observe(d==1?"BR-BOS":"BL-BOS",400,460,390,98,98);
   check(chain.Latest(460,tail));check(!CMarcoOpposingSequence::Source(chain,tail,-d,tf,id));
  }
  // Live close request, persistence, BE only on profitable partials, and no resend.
  for(bool profit:{false,true}){
   reset(d);p=plan(d);h.Reset();event(h,d,200);source(h,d);
   advance(h,p,100+d*(profit?2:-2),260);save(p);CTrade trade;bid=ask=100+d*(profit?2:-2);
   check(CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1));
   eq(volume,profit?3:2);eq(sl,profit?100:100-d*10);
   auto st=load();eq(st.plan.sequence.step,1);check(!st.plan.sequence.pending);eq(st.plan.sequence.time[0],1000);
   eq(st.plan.sequence.closed[0],profit?.25:.5);eq(st.plan.structureClosed[0],0);
   CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(sends,1);
  }
  // Second live step uses the saved remainder and survives a reload between steps.
  for(bool firstProfit:{false,true})for(bool secondProfit:{false,true}){
   reset(d);p=plan(d);h.Reset();event(h,d,200);source(h,d);
   advance(h,p,100+d*(firstProfit?2:-2),260);save(p);CTrade trade;
   bid=ask=100+d*(firstProfit?2:-2);CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);
   auto st=load();event(h,d,300,d==1?"BR-BOS":"BL-BOS");
   advance(h,st.plan,100+d*(secondProfit?3:-3),360);check(CMarcoLiveStagedTP::Save(magic,identifier,st));
   bid=ask=100+d*(secondProfit?3:-3);clockNow+=60;
   CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);
   eq(volume,firstProfit && secondProfit ? 2.25 : 0);
   st=load();eq(st.plan.sequence.step,2);
   if(firstProfit && secondProfit)eq(st.plan.sequence.closed[1],.1875);
   if(!firstProfit && !secondProfit)eq(st.plan.sequence.closed[1],.5);
   if(!firstProfit && secondProfit){eq(st.plan.sequence.closed[1],.5);eq(sends,2);}
  }
  // A rejected request retries the same intended amount, not another 25%.
  reset(d);p=plan(d);h.Reset();event(h,d,200);source(h,d);advance(h,p,100+d*2,260);save(p);
  CTrade trade;bid=ask=100+d*2;mode=1;
  CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(volume,4);eq(load().plan.sequence.requestedLots,1);
  mode=0;clockNow+=6;CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(volume,3);eq(sends,2);
  // A timeout keeps the sequence pending until a real volume reduction is observed.
  reset(d);p=plan(d);h.Reset();event(h,d,200);source(h,d);advance(h,p,100-d*2,260);save(p);bid=ask=100-d*2;mode=2;
  CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(sends,1);eq(volume,4);
  CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(sends,1);
  volume-=pending.volume;mode=0;CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);
  eq(load().plan.sequence.closed[0],.5);eq(volume,2);eq(sends,1);
  // Upgrade v3 once; later loads must not move the observation cursor forward.
  reset(d);save(plan(d));auto &old=files[CMarcoLiveStagedTP::Path(magic,identifier)];old.resize(332);
  int32_t v3=3;std::memcpy(old.data(),&v3,4);auto migrated=load();
  eq(migrated.plan.sequence.seen[0],1000);eq(files[CMarcoLiveStagedTP::Path(magic,identifier)].size(),436);
  clockNow=2000;eq(load().plan.sequence.seen[0],1000);
 }
 std::cout<<checks<<" opposing-sequence assertions passed\n";
}
