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
