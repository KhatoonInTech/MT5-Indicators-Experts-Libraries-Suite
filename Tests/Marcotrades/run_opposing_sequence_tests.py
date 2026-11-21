"""Production opposing-event sequence and durable live manager with a fake broker."""
from pathlib import Path
import re, subprocess
root=Path(__file__).resolve().parents[2]
parts=[(root/'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()]
parts.append(r'''
using uint=unsigned int;
enum {PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M3=3,TIME_DATE=1,TIME_SECONDS=2};
template<class T> int ArraySize(const std::vector<T>&v){return (int)v.size();}
template<class T> void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
string EnumToString(int x){return std::to_string(x);}
string TimeToString(datetime x,int){return std::to_string(x);}
template<class...T>void Print(T...){}
''')
for name in ('trade_rejection.mqh','staged_tp.mqh','opposing_sequence.mqh','staged_tp_live.mqh'):
    source=(root/'Include/Custom/Marcotrades'/name).read_text(encoding='utf-8-sig')
    source=re.sub(r'^#include.*$','',source,flags=re.M)
    source=re.sub(r'\blong\b','long long',source)
    source=re.sub(r'\b(\w+)\s+(\w+)\[\];',r'std::vector<\1> \2;',source)
    parts.append(source)
parts.append('enum {ENTRY_TF_M1=1, ENTRY_TF_LB=2}; struct EntryContext { CTradeRejectionHistory rawExitHistory; };')
for name,cls in [('marco_live_auto.mqh','LiveObserver'),('marco_backtest.mqh','BacktestObserver')]:
    source=(root/'Include/Custom/Marcotrades'/name).read_text(encoding='utf-8-sig')
    start=source.index('   SMarcoSequenceSignal ObserveOpposingSequence(')
    body=source.index('{',start);end=body+1;depth=1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    method=source[start:end].replace('m1LBContext.rawExitHistory','m1LBContext->rawExitHistory')
    parts.append('class '+cls+' { public: int m_entryTF=ENTRY_TF_M1,m_tradeTF=PERIOD_M3; EntryContext *m1LBContext=nullptr; CTradeRejectionHistory m_htfRawExit;\n'+method+'\n};')
parts.append(r'''
int checks=0;
void check(bool v){++checks;if(!v){std::cerr<<"Failed check "<<checks<<"\n";abort();}}
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
void preentry(CTradeRejectionHistory &h,int d,string kind,bool sweep=false,int available=60){
 h.Observe(sweep?(d==1?"SSL-Swept":"BSL-Swept"):(d==1?"BR-CHoCH":"BL-CHoCH"),40,available,20,105,105);
 h.BeginZones();h.Zone(kind,d==-1,104,106,20,0,40,available);h.EndZones(available);
}
void continuation(CTradeRejectionHistory &h,int d,int time=120,int available=180){
 // This BOS no longer originates within the LB: it must inherit the first link.
 h.Observe(d==1?"BR-BOS":"BL-BOS",time,available,110,95,95);
}
void preentryTests(){
 for(int d:{-1,1})for(int tf:{1,3})for(bool swept:{false,true}){
  string kind=d==1?(swept?"BR-LB-SSL":"BR-LB-IND"):(swept?"BL-LB-BSL":"BL-LB-IND");
  int slot=tf==1?1:0;
  // IND and sweep sources both support CHoCH -> entry -> adjacent BOS.
  for(bool sweepLabel:{false,true}){
   auto p=plan(d);CTradeRejectionHistory h;preentry(h,d,kind,sweepLabel);
   eq(advance(h,p,100-d*2,100,slot,tf).action,0);eq(p.sequence.step,0);
   continuation(h,d);eq(advance(h,p,100-d*2,179,slot,tf).action,0);
   auto a=advance(h,p,100-d*2,180,slot,tf);
   eq(a.action,2);eq(a.step,2);eq(a.share,1);eq(a.tf,tf);check(a.lbId==kind);
   eq(p.sequence.firstEvent,40);eq(p.sequence.closed[0],0);check(!p.breakeven);
   fill(p,100-d*2,180);eq(p.remaining,0);eq(p.sequence.closed[1],1);
   eq(advance(h,p,100-d*2,190,slot,tf).action,0);
  }
  // An event's closed-bar availability, not its candle's open, is decisive.
  auto p=plan(d);CTradeRejectionHistory h;preentry(h,d,kind);continuation(h,d,80,140);
  eq(advance(h,p,100-d*2,140,slot,tf).action,2);
  // TP or exact entry price cannot trigger the new losing-price full exit.
  for(double price:{100.0,100.0+d*2}){
   p=plan(d);h.Reset();preentry(h,d,kind);continuation(h,d);
   eq(advance(h,p,price,180,slot,tf).action,0);
   eq(advance(h,p,100-d*2,190,slot,tf).action,0); // No delayed reuse of a consumed BOS.
  }
  // There is no close just because the pre-entry structure exists.
  p=plan(d);h.Reset();preentry(h,d,kind);
  eq(advance(h,p,100-d*2,500,slot,tf).action,0);
  // A newer structure already known at entry interrupts the seed.
  h.Observe(d==1?"BL-BOS":"BR-BOS",70,90,65,95,95);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // An intervening post-entry direction change also breaks adjacency.
  p=plan(d);h.Reset();preentry(h,d,kind);
  h.Observe(d==1?"BL-BOS":"BR-BOS",110,150,105,95,95);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // A revision of the first event to the opposite direction cancels the link.
  p=plan(d);h.Reset();preentry(h,d,kind);
  h.Observe(d==1?"BSL-Swept":"SSL-Swept",40,160,20,105,105);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // Neither a later LB nor a later relabel may retrofit a pre-entry first event.
  p=plan(d);h.Reset();preentry(h,d,kind);h.Reset();
  h.Observe(d==1?"BR-CHoCH":"BL-CHoCH",40,60,20,105,105);
  h.BeginZones();h.Zone(kind,d==-1,104,106,20,0,40,130);h.EndZones(130);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  p=plan(d);h.Reset();preentry(h,-d,kind);
  h.Observe(d==1?"BR-CHoCH":"BL-CHoCH",40,130,20,105,105);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // An unlinked latest opposing event cannot borrow an older LB's link.
  p=plan(d);h.Reset();preentry(h,d,kind);continuation(h,d,70,90);continuation(h,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // Histories from different TFs must never form a pair together.
  p=plan(d);h.Reset();preentry(h,d,kind);CTradeRejectionHistory other;continuation(other,d);
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  eq(advance(other,p,100-d*2,180,1-slot,tf==1?3:1).action,0);
  // Existing/recovered cursors must not replay an event already consumed.
  p=plan(d);h.Reset();preentry(h,d,kind);continuation(h,d);p.sequence.seen[slot]=120;
  eq(advance(h,p,100-d*2,180,slot,tf).action,0);
  // Durable live close of the actual remainder, retry after rejection/reload.
  reset(d);p=plan(d);p.remaining=.75;volume=3;h.Reset();preentry(h,d,kind);continuation(h,d);
  save(p);auto restored=load();advance(h,restored.plan,100-d*2,180,slot,tf);save(restored.plan);
  CTrade trade;bid=ask=100-d*2;mode=1;
  CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);
  eq(volume,3);eq(load().plan.sequence.requestedLots,3);check(load().plan.sequence.pending);
  mode=0;clockNow+=6;CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1);
  eq(volume,0);eq(load().plan.sequence.closed[0],0);eq(load().plan.sequence.closed[1],.75);
  eq(load().plan.sequence.firstEvent,40);eq(sends,2);
 }
}
template<class Observer>void observerTests(){
 for(int d:{-1,1})for(bool onM1:{false,true})for(int mode:{ENTRY_TF_M1,ENTRY_TF_LB}){
  Observer o;EntryContext m1;o.m1LBContext=&m1;o.m_entryTF=mode;
  auto &full=onM1?m1.rawExitHistory:o.m_htfRawExit;
  auto &partial=onM1?o.m_htfRawExit:m1.rawExitHistory;
  preentry(full,d,"pre-entry-LB");continuation(full,d,300,360);
  // The other TF has an ordinary first linked structure in the same cycle.
  event(partial,d,200);source(partial,d);
  auto p=plan(d);auto a=o.ObserveOpposingSequence(p,100,360,100-d*2);
  eq(a.action,2);eq(a.share,1);eq(a.tf,onM1?1:3);eq(p.sequence.closed[0],0);
  // Profit-side execution retains the normal partial policy on the other TF.
  p=plan(d);a=o.ObserveOpposingSequence(p,100,360,100+d*2);
  eq(a.action,1);eq(a.share,.25);eq(a.tf,onM1?3:1);
 }
 // A setup on M1 is observed once, not paired with a duplicate M1 context.
 Observer o;EntryContext m1;o.m1LBContext=&m1;o.m_tradeTF=PERIOD_M1;
 preentry(o.m_htfRawExit,1,"M1-LB");continuation(o.m_htfRawExit,1);
 auto p=plan(1);eq(o.ObserveOpposingSequence(p,100,180,98).action,2);
 eq(o.ObserveOpposingSequence(p,100,181,98).action,0);
}
int main(){
 preentryTests();
 observerTests<LiveObserver>();observerTests<BacktestObserver>();
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
   double share=secondProfit?(firstProfit?.25:0):1;
   eq(a.share,share);eq(a.step,2);
   if(share>0)fill(p,100+d*(secondProfit?3:-3),360);
   eq(p.remaining,secondProfit?(firstProfit?.5625:.5):0);
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
   eq(volume,secondProfit?(firstProfit?2.25:2):0);
   st=load();eq(st.plan.sequence.step,2);
   if(firstProfit && secondProfit)eq(st.plan.sequence.closed[1],.1875);
   if(!firstProfit && !secondProfit)eq(st.plan.sequence.closed[1],.5);
   if(!firstProfit && secondProfit){eq(st.plan.sequence.closed[1],0);eq(sends,1);eq(sl,100-d*10);}
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
''')
out=root/'Tests/Marcotrades/_review';out.mkdir(exist_ok=True)
cpp=out/'opposing_sequence.cpp';exe=out/'opposing_sequence.exe'
cpp.write_text('\n'.join(parts),encoding='utf-8')
subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)
