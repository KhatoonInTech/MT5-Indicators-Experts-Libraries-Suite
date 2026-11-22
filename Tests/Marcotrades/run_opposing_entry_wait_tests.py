"""Opposing-LB entry waits: production helpers, both engines and durable position state."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
base=root/'Tests/Marcotrades/run_opposing_sequence_tests.py'
env={'__file__':str(base)}
exec(compile(base.read_text().split("parts.append(r'"+"''\nint checks=",1)[0],str(base),'exec'),env)
parts=env['parts']
parts.append(r'''
const int SYMBOL_POINT=999;
struct Point {datetime time;double price;};
struct Pivot {bool isHigh;Point *end;string ln;};
struct Pivots {std::vector<Pivot*> v;int Total(){return v.size();}Pivot* At(int i){return v.at(i);}};
struct ZigZag {Pivots pivots;Pivot *projection=nullptr;};
struct TestLB {bool sourceActive=true,isMitigated=false,isBullish=false;int touchCount=0;
 datetime entryTriggerTime=60,m1PivotTime=0,m1ConfirmTime=0;double m1PivotPrice=0,zoneLow=100,zoneHigh=110;
 int pivotEntry=0,pivotWatch=0;string id="setup";SMarcoOpposingEntryWait opposingWait{};};
''')
for name,cls in [('marco_live_auto.mqh','LiveWait'),('marco_backtest.mqh','BacktestWait')]:
 source=(root/'Include/Custom/Marcotrades'/name).read_text(encoding='utf-8-sig')
 methods=[]
 for sig in ('   void ObserveOpposingEntry(', '   void ObserveOpposingEntryBar(', '   bool ResolveOpposingEntry('):
  start=source.index(sig);end=source.index('{',start)+1;depth=1
  while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
  method=source[start:end].replace('m1LBContext.','m1LBContext->').replace('zzEntry.','zzEntry->').replace('pivot.end.','pivot->end->').replace('pivot.','pivot->')
  methods.append(method)
 parts.append('class '+cls+''' {public:
 bool m_applyEntryPolicyToPreventionExits=true;int m_tradeTF=3;double m_slBufferPips=2;
 string m_symbol="TEST";TestLB m_htf_lbs[1];CTradeRejectionHistory m_htfRawExit;
 EntryContext context;EntryContext *m1LBContext=&context;ZigZag zz;ZigZag *zzEntry=&zz;
 datetime m_last_entry_bar=0;double m_last_entry_close=0;
 double GetPipSize(string){return 1;}
'''+'\n'.join(methods)+'\n};')
parts.append(r'''
int checks=0;
void checkAt(bool ok,int line){checks++;if(!ok){std::cerr<<"check "<<checks<<" line "<<line<<" failed\n";abort();}}
#define check(x) checkAt((x),__LINE__)
void eq(double a,double b){check(std::abs(a-b)<1e-8);}
void seed(CTradeRejectionHistory &h,bool bull,int chain=0,bool sweep=false,int zoneAvailable=660){
 h.Observe(bull?(sweep?"SSL-Swept":"BR-CHoCH"):(sweep?"BSL-Swept":"BL-CHoCH"),600,660,540,bull?125:85,105);
 h.BeginZones();h.Zone("opposing",!bull,bull?120:80,bull?130:90,540,0,600,zoneAvailable);h.EndZones(zoneAvailable);
 for(int i=0;i<chain;i++)h.Observe(bull?"BR-BOS":"BL-BOS",660+i*60,720+i*60,650+i*60,50,50);
}
void reversal(CTradeRejectionHistory &h,bool bull,int t=1200,int available=1260){
 h.Observe(bull?"BL-CHoCH":"BR-CHoCH",t,available,t-20,bull?101:109,105);
}
SMarcoTPPlan plan(bool bull){SMarcoTPPlan p;check(CMarcoStagedTP::Build(p,bull,105,bull?90:120,bull?125:85,bull?135:75,1,2,0,.01,2));return p;}
template<class Engine> void engineCases(){
 for(bool bull:{false,true})for(int tf:{1,3})for(bool sweep:{false,true})for(int chain:{0,1,5}){
  Engine e;e.m_htf_lbs[0].isBullish=bull;
  auto &h=tf==1?e.context.rawExitHistory:e.m_htfRawExit;seed(h,bull,chain,sweep);
  e.ObserveOpposingEntry(0,1080,105,105,1080,tf);
  check(e.m_htf_lbs[0].opposingWait.required);check(e.m_htf_lbs[0].opposingWait.waiting);
  eq(e.m_htf_lbs[0].opposingWait.since,1080);eq(e.m_htf_lbs[0].touchCount,0);check(!e.m_htf_lbs[0].isMitigated);
  reversal(e.context.rawExitHistory,bull);e.m_last_entry_bar=1200;e.m_last_entry_close=105;
  Point point{1180,bull?101.:109.};Pivot pivot{!bull,&point,"locked"};e.zz.pivots.v.push_back(&pivot);
  SRejectionEvent event;
  check(!e.ResolveOpposingEntry(0,1259,105,event));check(e.ResolveOpposingEntry(0,1260,105,event));
  check(!e.ResolveOpposingEntry(0,1320,105,event)); // expired event cannot be replayed
  check(e.ResolveOpposingEntry(0,1260,bull?113:97,event)); // fill may be outside the band
  e.m_last_entry_close=bull?113:97;check(e.ResolveOpposingEntry(0,1260,bull?114:96,event));e.m_last_entry_close=105;
  check(!e.ResolveOpposingEntry(0,1260,0,event));
  for(double swing:{97.99,98.,112.,112.01}){
   e.context.rawExitHistory.Reset();e.context.rawExitHistory.Observe(bull?"BL-CHoCH":"BR-CHoCH",1200,1260,1180,swing,105);
   point.price=swing;check(e.ResolveOpposingEntry(0,1260,bull?114:96,event)==(swing>=98 && swing<=112));
  }
  e.context.rawExitHistory.Reset();reversal(e.context.rawExitHistory,bull);point.price=bull?101.:109.;
  point.time=1190;check(!e.ResolveOpposingEntry(0,1260,105,event));point.time=1180; // replaced pivot
  e.zz.projection=&pivot;check(!e.ResolveOpposingEntry(0,1260,105,event));e.zz.projection=nullptr;
  e.m_applyEntryPolicyToPreventionExits=false;check(!e.ResolveOpposingEntry(0,1260,105,event));
 }
 for(bool bull:{false,true}){
  Engine e;e.m_htf_lbs[0].isBullish=bull;seed(e.context.rawExitHistory,bull);
  e.m_applyEntryPolicyToPreventionExits=false;e.ObserveOpposingEntry(0,840,105,105,840,1);
  check(!e.m_htf_lbs[0].opposingWait.required);e.m_applyEntryPolicyToPreventionExits=true;
  e.m_htf_lbs[0].isMitigated=true;e.ObserveOpposingEntry(0,840,105,105,840,1);check(!e.m_htf_lbs[0].opposingWait.required);
  e.m_htf_lbs[0].isMitigated=false;e.ObserveOpposingEntry(0,840,105,105,840,1);
  e.ObserveOpposingEntry(0,900,bull?113:97,bull?113:97,900,1);check(e.m_htf_lbs[0].opposingWait.waiting);check(e.m_htf_lbs[0].opposingWait.required);
  e.ObserveOpposingEntry(0,960,105,105,960,1);check(e.m_htf_lbs[0].opposingWait.waiting);eq(e.m_htf_lbs[0].opposingWait.since,840);eq(e.m_htf_lbs[0].touchCount,0);
  // A touch and a reversal can occur within the same completed candle.
  Engine same;same.m_htf_lbs[0].isBullish=bull;seed(same.context.rawExitHistory,bull);
  same.ObserveOpposingEntryBar(0,900,bull?113:97,bull?113:111,bull?99:97,105);
  check(same.m_htf_lbs[0].opposingWait.waiting);
  reversal(same.context.rawExitHistory,bull,900,960);same.m_last_entry_bar=900;same.m_last_entry_close=105;
  Point point{880,bull?101.:109.};Pivot pivot{!bull,&point,"locked"};same.zz.pivots.v.push_back(&pivot);
  SRejectionEvent signal;check(same.ResolveOpposingEntry(0,960,105,signal));
  // A tick can start a wait partway through that same candle.
  same.m_htf_lbs[0].opposingWait.since=930;check(same.ResolveOpposingEntry(0,960,105,signal));
  same.m_htf_lbs[0].isMitigated=true;check(!same.ResolveOpposingEntry(0,960,105,signal));
  // A source created at the HTF close cannot be used earlier in its candle.
  Engine future;future.m_htf_lbs[0].isBullish=bull;seed(future.m_htfRawExit,bull,0,false,960);
  future.ObserveOpposingEntryBar(0,900,105,110,100,105);check(!future.m_htf_lbs[0].opposingWait.required);
  future.ObserveOpposingEntry(0,960,105,105,960,3);check(future.m_htf_lbs[0].opposingWait.required);
  // Reconstructing the same closed input after restart yields the same wait.
  Engine replay;replay.m_htf_lbs[0].isBullish=bull;seed(replay.context.rawExitHistory,bull);
  replay.ObserveOpposingEntryBar(0,900,bull?113:97,bull?113:111,bull?99:97,105);
  check(replay.m_htf_lbs[0].opposingWait.waiting);eq(replay.m_htf_lbs[0].opposingWait.since,900);
  // Real call order: leave the band during the CHoCH candle, observe the
  // outside close, then scan the executable quote. Only the swing is in-band.
  Engine outside;outside.m_htf_lbs[0].isBullish=bull;seed(outside.context.rawExitHistory,bull);
  outside.ObserveOpposingEntry(0,840,105,105,840,1);
  outside.ObserveOpposingEntryBar(0,900,105,bull?114:110,bull?100:96,bull?114:96);
  reversal(outside.context.rawExitHistory,bull,900,960);outside.m_last_entry_bar=900;outside.m_last_entry_close=bull?114:96;
  outside.zz.pivots.v.push_back(&pivot);
  outside.ObserveOpposingEntry(0,960,bull?114:96,bull?114:96,960,1);
  check(outside.ResolveOpposingEntry(0,960,bull?115:95,signal));
  outside.m_htf_lbs[0].sourceActive=false;check(!outside.ResolveOpposingEntry(0,960,105,signal));
  outside.m_htf_lbs[0].sourceActive=true;outside.m_htf_lbs[0].touchCount=1;
  check(!outside.ResolveOpposingEntry(0,960,105,signal));
  // An older HTF catch-up sample cannot cancel the newer wait.
  e.ObserveOpposingEntry(0,780,97,97,840,3);check(e.m_htf_lbs[0].opposingWait.waiting);
 }
}
void failedCases(){
 for(bool bull:{false,true})for(string nextKind:{"CHoCH","BOS"}){
  auto p=plan(bull);p.reversalEntryEvent=1200;CTradeRejectionHistory h;reversal(h,bull);
  h.Observe(bull?"SSL-Swept":"BSL-Swept",1200,1380,1180,bull?101:109,105);
  h.Observe((bull?"BR-":"BL-")+nextKind,1320,1380,1300,105,105);
  SMarcoSequenceSignal a{};
  check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1379,bull?103:107,a));
  check(CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1380,bull?103:107,a));
  eq(a.action,2);eq(a.share,1);check(p.sequence.pending);eq(p.sequence.step,2);
  check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1381,bull?103:107,a));
  // Other entries and unrelated sweeps must not acquire this new full exit.
  p=plan(bull);check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1380,bull?103:107,a));
  p.reversalEntryEvent=1199;check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1380,bull?103:107,a));
  for(double price:{105.,bull?107.:103.}){p=plan(bull);p.reversalEntryEvent=1200;check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1380,price,a));check(p.reversalEntryDone);}
  // Entry-direction BOS alone cannot close any volume.
  p=plan(bull);p.reversalEntryEvent=1200;h.Reset();reversal(h,bull);h.Observe(bull?"BL-BOS":"BR-BOS",1320,1380,1300,105,105);
  check(!CMarcoOpposingEntryWait::FailedEntry(h,p,1260,1380,bull?103:107,a));check(p.reversalEntryDone);eq(p.remaining,1);check(!p.sequence.pending);
 }
}
void recoveryCases(){
 for(bool bull:{false,true}){
  files.clear();handles.clear();SMarcoLiveTPState state{};state.pendingStage=-1;state.lots=4;state.riskCash=60;state.plan=plan(bull);state.plan.reversalEntryEvent=1200;
  state.extension.seen="M3|zone";check(CMarcoLiveStagedTP::Save(magic,identifier,state));SMarcoLiveTPState loaded;
  check(CMarcoLiveStagedTP::Load(magic,identifier,loaded));eq(loaded.plan.reversalEntryEvent,1200);check(!loaded.plan.reversalEntryDone);check(loaded.extension.seen==state.extension.seen);
  CTradeRejectionHistory h;reversal(h,bull);h.Observe(bull?"SSL-Swept":"BSL-Swept",1200,1380,1180,105,105);h.Observe(bull?"BR-CHoCH":"BL-CHoCH",1320,1380,1300,105,105);
  SMarcoSequenceSignal a{};check(CMarcoOpposingEntryWait::FailedEntry(h,loaded.plan,1260,1380,bull?103:107,a));
  check(CMarcoLiveStagedTP::Save(magic,identifier,loaded));check(CMarcoLiveStagedTP::Load(magic,identifier,state));check(state.plan.reversalEntryDone);check(state.plan.sequence.pending);eq(state.plan.sequence.share,1);
  volume=4;bid=ask=bull?103:107;sl=bull?90:120;tp=bull?135:75;sends=0;mode=1;clockNow=1380;CTrade trade;
  CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(volume,4);
  check(CMarcoLiveStagedTP::Load(magic,identifier,state));check(state.plan.sequence.pending);
  mode=0;clockNow+=6;CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);eq(volume,0);
  // v5 positions migrate with the extension disabled, preserving their old plan.
  state={};state.pendingStage=-1;state.lots=4;state.riskCash=60;state.plan=plan(bull);check(CMarcoLiveStagedTP::Save(magic,identifier,state));
  auto &old=files[CMarcoLiveStagedTP::Path(magic,identifier)];old.resize(436);int32_t v5=5;std::memcpy(old.data(),&v5,4);
  check(CMarcoLiveStagedTP::Load(magic,identifier,loaded));eq(loaded.plan.reversalEntryEvent,0);eq(loaded.plan.remaining,1);eq(files[CMarcoLiveStagedTP::Path(magic,identifier)].size(),448);
 }
}
int main(){
 engineCases<LiveWait>();engineCases<BacktestWait>();failedCases();recoveryCases();
 for(bool bull:{false,true}){
  CTradeRejectionHistory h;SRejectionEvent e;string id;seed(h,bull,2,false,900);
  check(!CMarcoOpposingEntryWait::OpposingSource(h,bull,899,1,e,id));check(CMarcoOpposingEntryWait::OpposingSource(h,bull,900,1,e,id));
  h.Observe(bull?"BL-CHoCH":"BR-CHoCH",960,1020,940,105,105);check(!CMarcoOpposingEntryWait::OpposingSource(h,bull,1020,1,e,id));
  h.Observe(bull?"BR-BOS":"BL-BOS",1080,1140,1060,50,50);check(!CMarcoOpposingEntryWait::OpposingSource(h,bull,1140,1,e,id));
 }
 std::cout<<checks<<" opposing-entry wait assertions passed\n";
}
''')
with tempfile.TemporaryDirectory(prefix='marco_opposing_wait_') as tmp:
 cpp=Path(tmp)/'test.cpp';exe=Path(tmp)/'test.exe';cpp.write_text('\n'.join(parts),encoding='utf-8')
 subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
