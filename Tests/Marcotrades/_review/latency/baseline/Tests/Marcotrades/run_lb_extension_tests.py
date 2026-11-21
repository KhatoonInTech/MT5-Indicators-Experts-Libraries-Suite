"""Exercise the production causal history + structural-exit policy without MT5."""
from pathlib import Path
import re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
parts = [(root / 'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()]
parts.append(r'''
using uint=unsigned int;
enum {PERIOD_CURRENT=0, PERIOD_M1=1, PERIOD_M3=3, TIME_DATE=1, TIME_SECONDS=2};
template<class T> int ArraySize(const std::vector<T>& v){return (int)v.size();}
template<class T> void ArrayResize(std::vector<T>& v,int n){v.resize(n);}
string EnumToString(int x){return std::to_string(x);}
string TimeToString(datetime x,int){return std::to_string(x);}
template<class...T> void Print(T...){}
template<class...T> string StringFormat(string format,T...){return format;}
''')
for name in ('trade_rejection.mqh', 'staged_tp.mqh', 'lb_extension.mqh'):
    source = (root / 'Include/Custom/Marcotrades' / name).read_text(encoding='utf-8-sig')
    source = re.sub(r'^#include.*$', '', source, flags=re.M)
    source = re.sub(r'\blong\b', 'long long', source)
    source = re.sub(r'\b(\w+)\s+(\w+)\[\];', r'std::vector<\1> \2;', source)
    parts.append(source)

# Exercise the actual simulator integration, including source pivot and 75% gate.
engine=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
start=engine.index('   double ExtensionSourcePivot(')
end=engine.index('   void ApplyStructureExits(',start)
methods=engine[start:end].replace('m1LBContext.rejectionHistory','m1LBContext->rejectionHistory')
parts.append(r"""
enum {ENTRY_TF_M1=1, ENTRY_TF_LB=0};
template<class...T> void PrintFormat(T...){}
class CMarcoSymbolUnits{public:static bool BufferedStop(string,double pivot,double buffer,bool buy,double &stop){stop=pivot+(buy?-buffer:buffer);return true;}};
struct Pivot {datetime pivotTime,availableTime; bool isHigh;double price;};
struct Context {CTradeRejectionHistory rejectionHistory;};
class Engine {public:
 std::vector<Pivot> m_m1PivotConfirmations,m_pivotConfirmations;
 int m_entryTF=ENTRY_TF_M1,m_tradeTF=3;string m_symbol="TEST";
 double m_fallbackRR=1,m_slBufferPips=1;
 CTradeRejectionHistory m_htfRejection;Context context;Context* m1LBContext=&context;
"""+methods+'};')
parts.append(r"""
int checks=0;
void check(bool ok){++checks;if(!ok){std::cerr<<"Failed extension check "<<checks<<"\n";std::abort();}}
void zone(CTradeRejectionHistory& h,string id,bool bull,double low,double high,datetime created=150,datetime known=200,datetime mitigation=0){
 h.BeginZones();h.Zone(id,bull,low,high,created,mitigation,0,known);h.EndZones(known);
}
int main(){
 for(bool buy:{false,true})for(int preferred:{ENTRY_TF_M1,ENTRY_TF_LB}){
  int d=buy?1:-1;SMarcoTPPlan p;
  check(CMarcoStagedTP::Build(p,buy,100,100-d*10,100+d*20,100+d*30,1,0,0,.01,2));
  Engine e;e.m_entryTF=preferred;SMarcoExtensionState state{};
  double lo=buy?110:80,hi=buy?120:90;
  zone(e.m_htfRejection,"setup",buy,lo,hi);
  zone(e.context.rejectionHistory,"m1",buy,lo,hi,160);
  e.m_pivotConfirmations.push_back({150,190,!buy,100.0+d*6});
  e.m_m1PivotConfirmations.push_back({160,190,!buy,100.0+d*4});
  check(!e.ExtendFromNewLB(p,state,100,199)); // Future LB unavailable.
  check(e.ExtendFromNewLB(p,state,100,200));
  check(p.extensionCount==1 && p.price[1]==100+d*40); // Both TFs, once.
  check(CMarcoStagedTP::Stop(p)==100-d*10 && !p.breakeven); // Below 75%: no SL move.
  check(!e.ExtendFromNewLB(p,state,100,201));check(p.extensionCount==1);
  CMarcoStagedTP::Exit(p,0,.5,100+d*20,210);CMarcoStagedTP::Exit(p,2,.25,100+d*10,210);
  check(p.remaining==.25);
  zone(e.m_htfRejection,"setup2",buy,lo,hi,250,300);
  zone(e.context.rejectionHistory,"m12",buy,lo,hi,260,300);
  e.m_pivotConfirmations.push_back({250,290,!buy,100.0+d*6});
  e.m_m1PivotConfirmations.push_back({260,290,!buy,100.0+d*4});
  check(e.ExtendFromNewLB(p,state,100,300));check(p.price[1]==100+d*50);
  check(CMarcoStagedTP::Stop(p)==100+d*(preferred==ENTRY_TF_M1?3:5));
  check(!e.ExtendFromNewLB(p,state,100,301));
  // Renaming bounds on an existing LB is not a new extension.
  zone(e.m_htfRejection,"setup2",buy,lo-1,hi+1,250,310);
  check(!e.ExtendFromNewLB(p,state,100,310));check(p.extensionCount==2);
  // New event with loss-side source cannot loosen the existing profitable stop.
  zone(e.m_htfRejection,"setup3",buy,lo,hi,350,400);
  e.m_pivotConfirmations.push_back({350,390,!buy,100.0-d*5});
  check(e.ExtendFromNewLB(p,state,100,400));check(p.extensionCount==3);
  check(CMarcoStagedTP::Stop(p)==100+d*(preferred==ENTRY_TF_M1?3:5));
 }
 for(bool buy:{false,true})for(int kind=0;kind<5;kind++){
  SMarcoTPPlan p;check(CMarcoStagedTP::Build(p,buy,100,buy?90:110,buy?120:80,buy?130:70,1,0,0,.01,2));
  Engine e;SMarcoExtensionState state{};
  zone(e.m_htfRejection,"ineligible",kind==0?!buy:buy,
       kind==1?200:(buy?105:85),kind==1?210:(buy?110:90),kind==2?50:150,kind==3?90:200,kind==4?190:0);
  e.ExtendFromNewLB(p,state,100,200);check(p.extensionCount==0);
 }
 for(bool buy:{false,true}){
  Engine guard;SMarcoTPPlan plan;SMarcoExtensionState seen{};
  check(CMarcoStagedTP::Build(plan,buy,100,buy?90:110,buy?120:80,buy?130:70,1,0,0,.01,2));
  guard.m_htfRejection.BeginZones();
  guard.m_htfRejection.Zone("exit-only",buy,buy?110:80,buy?120:90,150,0,190,200,true);
  guard.m_htfRejection.EndZones(200);
  check(!guard.ExtendFromNewLB(plan,seen,100,200)&&plan.extensionCount==0);
 }
 // Partial overlap is sufficient, and SL falls back to BE when pivot is on the loss side.
 Engine e;SMarcoTPPlan p;SMarcoExtensionState state{};
 check(CMarcoStagedTP::Build(p,true,100,90,120,130,1,0,0,.01,2));
 CMarcoStagedTP::Exit(p,0,.5,120,120);CMarcoStagedTP::Exit(p,2,.25,110,120);
 zone(e.m_htfRejection,"overlap",true,129,135);
 e.m_pivotConfirmations.push_back({150,190,false,95});
 e.ExtendFromNewLB(p,state,100,200);check(p.extensionCount==1);check(CMarcoStagedTP::Stop(p)==100);
 std::cout<<"PASS: "<<checks<<" LB extension checks: actual engine, both directions, simultaneous TFs, source preference, 75% threshold, deduplication\n";
}
""")
with tempfile.TemporaryDirectory(prefix='marco_extension_tests_') as directory:
    source,binary=Path(directory)/'test.cpp',Path(directory)/'test.exe'
    source.write_text('\n'.join(parts),encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(source),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
