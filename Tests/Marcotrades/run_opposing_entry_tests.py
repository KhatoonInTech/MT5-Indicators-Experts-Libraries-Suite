"""Production entry-prevention regression: linked opposing structures and both TF leg sources."""
from pathlib import Path
import re,subprocess,tempfile,shutil
root=Path(__file__).resolve().parents[2]
policy=(root/'Include/Custom/Marcotrades/trade_rejection.mqh').read_text(encoding='utf-8-sig')
back=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
live=(root/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
def method(s):
 start=s.index('   bool              IsLegComingFromOppositeLB(');return s[start:s.index('\n     }',start)+7]
assert method(back)==method(live)
assert 'buffer, m_sim.run_time[i])' in back and 'buffer, TimeCurrent())' in live
for text in [back,live]:
 assert 'history.OpposingChoch(' in text
 assert 'm_htf_lbs[cached].entryTriggerTime>0 && m_htf_lbs[cached].sourceActive' in text
mock=(root/'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()+r'''
using uint=unsigned int;
enum{PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,TIME_DATE=1,TIME_SECONDS=2};
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
string EnumToString(int x){return std::to_string(x);}string TimeToString(datetime x,int){return std::to_string(x);}
template<class...T>void Print(T...){}
int checks=0;
#define CHECK(x) do{++checks;if(!(x)){std::cerr<<"FAILED line "<<__LINE__<<": "<<#x<<"\n";std::exit(1);}}while(0)
'''
adapted=re.sub(r'^#include.*$','',policy,flags=re.M)
adapted=re.sub(r'\b(\w+)\s+(\w+)\[\];',r'std::vector<\1> \2;',adapted)
method_cpp=method(back)
for name in ['zzHtfRef','pv','selected','m1LBContext']:
 method_cpp=method_cpp.replace(name+'.',name+'->')
method_cpp=method_cpp.replace('pv->end.','pv->end->').replace('selected->start.','selected->start->')
engine=r'''
struct Point{datetime time;double price;};
struct Pivot{Point *start,*end;string ln="ZZ";};
struct Pivots{std::vector<Pivot*> v;int Total(){return v.size();}Pivot*At(int i){return v[i];}};
struct ZigZag{Pivots pivots;Pivot* projection=nullptr;};
struct Context{CTradeRejectionHistory rejectionHistory;};
class Engine{public:string m_symbol="ETHUSDc";int m_tradeTF=2;CTradeRejectionHistory m_htfRejection;Context context;Context *m1LBContext=&context;
'''+method_cpp+'};\n'
cases=r'''
void zone(CTradeRejectionHistory &h,bool buy,datetime known=260,datetime mitigation=0,datetime cause=200,double low=-1,double high=-1){
 if(low<0){low=buy?110:80;high=buy?120:90;}
 h.BeginZones();h.Zone("opposing",!buy,low,high,100,mitigation,cause,known);h.EndZones(known);
}
void event(CTradeRejectionHistory &h,bool buy,string suffix,datetime at,datetime known,datetime origin=150,bool linked=true){h.Observe((buy?"BR-":"BL-")+suffix,at,known,origin,linked?(buy?115:85):100);}
bool block(CTradeRejectionHistory &h,bool buy,datetime now=400){return h.OpposingChoch(buy,300,390,395,now,1,0).action==TRADE_RETIRE_ZONE;}
int main(){
 for(bool buy:{false,true}){
  CTradeRejectionHistory h;
  // A qualified LB linked to the latest BOS must veto either trade direction.
  zone(h,buy);event(h,buy,"BOS",280,300);CHECK(block(h,buy));
  CHECK(!block(h,buy,259)); // Qualification/event still unavailable.
  h.Reset();event(h,buy,"BOS",280,300);CHECK(!block(h,buy)); // BOS alone is insufficient.
  event(h,buy,"CHoCH",200,230);zone(h,buy,401);CHECK(!block(h,buy));CHECK(block(h,buy,401));
  h.Reset();zone(h,buy);event(h,buy,"BOS",280,300,150,false);CHECK(!block(h,buy));
  // Keep the source link through uninterrupted same-direction continuation.
  h.Reset();event(h,buy,"CHoCH",200,230);event(h,buy,"BOS",280,300,270,false);zone(h,buy,260);
  CHECK(block(h,buy));
  h.Observe(buy?"SSL-Swept":"BSL-Swept",320,340,310,100);CHECK(block(h,buy));
  // An intervening candidate-direction structure ends the old source chain.
  event(h,!buy,"BOS",250,270,240,false);CHECK(!block(h,buy));
  // Latest reversal also releases structural context.
  event(h,!buy,"CHoCH",350,380);CHECK(!block(h,buy));
  // Future reversal cannot retrospectively release earlier entries.
  CHECK(h.OpposingChoch(buy,300,390,395,379,1,0).action==TRADE_ALLOW); // touch not yet available
  h.Reset();zone(h,buy);event(h,buy,"CHoCH",200,230);event(h,buy,"BOS",280,300,270,false);
  event(h,!buy,"CHoCH",350,410);CHECK(block(h,buy));CHECK(!block(h,buy,410));
  // Reclassification takes effect only at its availability time.
  h.Reset();zone(h,buy);event(h,buy,"CHoCH",200,230);event(h,buy,"BOS",280,300,270,false);
  h.Observe(buy?"BSL-Swept":"SSL-Swept",200,410,999,999);CHECK(block(h,buy));CHECK(!block(h,buy,410));
  // Mitigated or removed sources cannot keep vetoing fresh entries.
  h.Reset();zone(h,buy);event(h,buy,"BOS",280,300);zone(h,buy,400,340);CHECK(!block(h,buy));
  h.Reset();zone(h,buy);event(h,buy,"BOS",280,300);h.BeginZones();h.EndZones(400);CHECK(!block(h,buy));
  // Expansion after an event cannot invent an earlier geometry link.
  h.Reset();zone(h,buy,260,0,0,90,105);event(h,buy,"BOS",280,300);
  zone(h,buy,350,0,0,70,130);CHECK(!block(h,buy));
  // Source pivot after the incoming-leg origin, or structure after leg end.
  h.Reset();zone(h,buy);event(h,buy,"BOS",280,300,310);CHECK(!block(h,buy));
  h.Reset();zone(h,buy);event(h,buy,"BOS",391,392);CHECK(!block(h,buy));
  // Direct pivot-leg matching consults qualified HTF and M1 snapshots.
  Engine e;Point origin{150,buy?115.:85.},end{300,100};Pivot selected{&origin,&end};ZigZag zz;zz.pivots.v={&selected,&selected};
  CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
  zone(e.m_htfRejection,buy,401);CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
  CHECK(e.IsLegComingFromOppositeLB(buy,300,&zz,0,401));
  e.m_htfRejection.Reset();zone(e.context.rejectionHistory,buy);CHECK(e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
  zone(e.context.rejectionHistory,buy,400,340);CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
  // A projection cannot supply the selected pivot or its origin.
  e.context.rejectionHistory.Reset();zone(e.m_htfRejection,buy);zz.projection=&selected;
  CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));zz.projection=nullptr;selected.ln="ZZ_Proj";
  CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
  selected.ln="ZZ";origin.price=100;CHECK(!e.IsLegComingFromOppositeLB(buy,300,&zz,0,400));
 }
 // Reproduce the recorded ETHUSDc decision with its exact timestamps/prices.
 // 17 Nov 2026: M2 source created 05:20, qualified 09:02, BOS at 09:00 from 08:08.
 const datetime day=1794873600;
 CTradeRejectionHistory eth;
 eth.Zone("LB_BEAR_1794892800",false,1832.03,1841.59,day+5*3600+20*60,0,0,day+9*3600+2*60);
 eth.Observe("BR-BOS",day+9*3600,day+9*3600+2*60,day+8*3600+8*60,1832.24);
 auto actual=eth.OpposingChoch(true,day+8*3600+52*60,day+9*3600+5*60,day+9*3600+7*60,day+9*3600+7*60,2,0,true);
 CHECK(actual.action==TRADE_RETIRE_ZONE);CHECK(actual.opposingId=="LB_BEAR_1794892800");CHECK(actual.sourceTF==2);
 std::cout<<"PASS: "<<checks<<" opposing-structure/qualified-leg checks, including recorded ETHUSDc decision\n";
}
'''
source=mock+adapted+engine+cases
compiler=shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
with tempfile.TemporaryDirectory(prefix='opposing_entry_') as td:
 cpp=Path(td)/'test.cpp';exe=Path(td)/'test.exe';cpp.write_text(source)
 subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
 broken=source.replace('if(StructureDirection(latest.name)!=opposing)','if(latest.name != (candidateBull ? "BR-CHoCH" : "BL-CHoCH"))')
 assert broken!=source;cpp.write_text(broken)
 subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
 test=subprocess.run([str(exe)],capture_output=True);assert test.returncode!=0
 print('PASS: restoring CHoCH-only entry filter fails regression')
