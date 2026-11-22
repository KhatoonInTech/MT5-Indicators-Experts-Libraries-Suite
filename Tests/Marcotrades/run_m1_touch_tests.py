"""Exercise production live M1 touch/confirmation methods with supplied pivot events.

No broker orders. ZigZag is a deterministic event source here: this regression
tests missed wick detection and first-pivot retention, not ZigZag calculation.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
live = (root / 'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
back = (root / 'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig').replace("m_sim.", "")
policy = (root / 'Include/Custom/Marcotrades/trade_rejection.mqh').read_text(encoding='utf-8-sig')
policy = policy[policy.index('enum ENUM_TRADE_REJECTION_ACTION'):policy.index('// Immutable versions')]


def method(source, name):
    start = re.search(r'   (?:void|bool)\s+' + name + r'\(', source).start()
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


methods = '\n'.join(method(live, name) for name in (
    'CaptureM1PivotConfirmations', 'FeedM1EntryBar', 'ArmM1Entry', 'CheckIndWaitBoundary',
    'CaptureSetupIndContext', 'IndEntryReady', 'SkipIndPivot', 'SkipIndEntryPrice', 'GetSetupIndWaitPivot',
    'DiscardPivotEntry', 'ObservePivotEntryRange', 'GetLatestEntryPivot', 'GetM1EntryPivot'))
for pointer in ('zz', 'zzEntry', 'pv', 'first', 'current', 'm1LBContext', 'ind', 'ms', 'zone'):
    methods = methods.replace(pointer + '.', pointer + '->')
# The live expiry decision is outside the feed method; retain its production policy.
assert 'CTradeRejection::M1Expired(m_last_entry_bar, firstPivotConfirmTime)' in live
assert 'ArmM1Entry(k, run_time[closed_i], run_low[closed_i], run_high[closed_i]);' in back
assert 'ArmM1Entry(k, barTime, low, high);' in method(live, 'FeedM1EntryBar')

mock = r'''
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
struct Context {CMarcoIndEntryFilter indEntry;int rejectionHistory=0;void Update(datetime,double,double,double,double,ZigZag*,double){}};
struct SLivePivotConfirmation {datetime pivotTime=0;double price=0;bool isHigh=false;datetime availableTime=0;};
struct OpposingWait {bool required=false;};
struct Zone {OpposingWait opposingWait{};SMarcoPivotWatch pivotWatch{};SMarcoPivotEntry pivotEntry{};SMarcoIndWait indWait{};string id="LB_BEAR_1794450000";bool isBullish=false,isMitigated=false;int touchCount=0;
 datetime confirmedTime=13*3600+5*60,entryTriggerTime=13*3600+5*60,m1TouchTime=0,m1ConfirmTime=0,m1PivotTime=0,mitigationTime=0;
 double zoneLow=7607.79,zoneHigh=7612.80,m1PivotPrice=0;};
'''
ind_policy = (root/'Include/Custom/Marcotrades/m1_ind_entry.mqh').read_text(encoding='utf-8-sig')
ind_policy = re.sub(r'\b(\w+)\s+(\w+)\[\];',r'std::vector<\1> \2;',ind_policy)
pivot_policy=(root/'Include/Custom/Marcotrades/pivot_entry.mqh').read_text(encoding='utf-8-sig')
pivot_policy=pivot_policy.replace('MqlRates source[], confirmation[];', 'std::vector<MqlRates> source, confirmation;')
pivot_adapter=r'''
struct MqlRates {datetime time;double open,high,low,close;};
int iBarShift(string,int,datetime,bool){return -1;}
int CopyRates(string,int,int,int,std::vector<MqlRates>&){return 0;}
'''
mock = mock.replace('struct Context {',ind_policy+'\n'+pivot_adapter+pivot_policy+'\nstruct Context {')
# These entry decisions must stay identical across the live and simulation engines.
for name in ('CheckIndWaitBoundary','CaptureSetupIndContext','IndEntryReady','SkipIndPivot',
             'SkipIndEntryPrice','GetSetupIndWaitPivot','DiscardPivotEntry','ObservePivotEntryRange','GetLatestEntryPivot','GetM1EntryPivot'):
    assert method(live,name)==method(back,name), name
prefix = mock + policy + r'''
class Engine {public:
 string m_symbol="US500m";int m_entryTF=ENTRY_TF_M1,m_tradeTF=PERIOD_M5,m_entryBarCount=0,m_htf_lb_count=1;
 bool m_applyEntryPolicyToPreventionExits=false;double m_last_entry_close=0;
 void ObserveOpposingEntryBar(int,datetime,double,double,double,double){}
 void ObserveOpposingEntry(int,datetime,double,double,datetime,int){}
 double m_slBufferPips=50;datetime m_last_entry_bar=0;ZigZag zigzag;ZigZag* zzEntry=&zigzag;
 Context* m1LBContext=nullptr;std::vector<Zone> m_htf_lbs{Zone{}};
 CMarcoIndEntryFilter m_setupIndEntry;
 std::vector<SLivePivotConfirmation> m_m1PivotConfirmations,m_pivotConfirmations;bool opposing=false;
 double GetPipSize(string){return .10;}
 bool BlockM1OpposingLeg(int k,datetime now){if(!opposing)return false;
 CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,now);return true;}
 void AuditChochTouches(datetime,double,double,datetime,ZigZag*,int,int){}
'''
cases = r'''
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
 // Special reversal entries always use M1 plus setup-TF IND checks, even
 // with ordinary entry TF set to the setup TF. Keep the supplied CHoCH pivot.
 for(bool buy:{false,true})for(int source:{0,1})for(int mode:{IND_ENTRY_PRICE,IND_ENTRY_PIVOT,IND_ENTRY_EITHER}){
  Engine e;Context ctx;e.m1LBContext=&ctx;e.m_entryTF=ENTRY_TF_LB;e.m_applyEntryPolicyToPreventionExits=true;
  auto &z=e.m_htf_lbs[0];z.isBullish=buy;z.zoneLow=80;z.zoneHigh=120;z.opposingWait.required=true;
  auto &ind=source==0 ? e.m_setupIndEntry : ctx.indEntry;
  CMarcoIndEntryFilter::Configure((ENUM_MARCO_IND_ENTRY_FILTER)mode);
  ind.Begin(95,105);ind.Zone("special-ind",buy,95,105,240);ind.End(240);
  check(e.SkipIndPivot(0,240,100,360)==(mode!=IND_ENTRY_PRICE));
  CMarcoIndEntryFilter::Reset(z.indWait);
  check(e.SkipIndEntryPrice(0,360,100,240,360)==(mode!=IND_ENTRY_PIVOT));
  if(mode!=IND_ENTRY_PIVOT){check(z.indWait.rejectedPivot==240);check(z.indWait.rejectedAvailable==360);}
 }
 CMarcoPivotEntry::Configure(ENTRY_AFTER_CONFIRMATION);
 std::cout<<"PASS: "<<checks<<" M1/setup IND, waiting, first-pivot and expiry checks (both directions)\n";
}
'''
with tempfile.TemporaryDirectory(prefix='marco_m1_touch_') as directory:
    cpp, binary = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    cpp.write_text(prefix + methods + cases, encoding='utf-8')
    compiler = shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
    subprocess.run([compiler, '-std=c++17', '-O2', str(cpp), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
    # Regression proof: restoring the missing closed-range arm must fail these cases.
    broken = methods.replace('ArmM1Entry(k, barTime, low, high);', '// old tick-only arming')
    cpp.write_text(prefix + broken + cases, encoding='utf-8')
    subprocess.run([compiler, '-std=c++17', '-O2', str(cpp), '-o', str(binary)], check=True)
    result = subprocess.run([str(binary)], capture_output=True, text=True)
    assert result.returncode != 0 and 'M1 touch failure 2' in result.stderr
    print('PASS: old tick-only behavior reproduces the missed first touch')
    # Regression proof: the former frozen-pivot branch must fail replacement tests.
    broken = methods.replace('if(CMarcoPivotEntry::Enabled())\n         return GetLatestEntryPivot(k,now,zzEntry,true,pivotTime,pivotPrice,confirmTime);',
                             '// regression: keep using the saved pivot')
    assert broken != methods
    cpp.write_text(prefix + broken + cases, encoding='utf-8')
    subprocess.run([compiler, '-std=c++17', '-O2', str(cpp), '-o', str(binary)], check=True)
    result = subprocess.run([str(binary)], capture_output=True, text=True)
    assert result.returncode != 0 and 'M1 touch failure' in result.stderr
    print('PASS: restoring the stale saved-pivot behavior fails the replacement regression')
