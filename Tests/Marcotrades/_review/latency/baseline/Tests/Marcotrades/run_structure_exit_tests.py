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
''')
for name in ('trade_rejection.mqh', 'staged_tp.mqh', 'structure_exit.mqh'):
    source = (root / 'Include/Custom/Marcotrades' / name).read_text(encoding='utf-8-sig')
    source = re.sub(r'^#include.*$', '', source, flags=re.M)
    source = re.sub(r'\blong\b', 'long long', source)
    source = re.sub(r'\b(\w+)\s+(\w+)\[\];', r'std::vector<\1> \2;', source)
    parts.append(source)
parts.append(r'''
int checks=0;
void check(bool ok){++checks;if(!ok){std::cerr<<"Failed check "<<checks<<"\n";std::abort();}}
void event(CTradeRejectionHistory& h,bool buy,double line,datetime t=200,datetime available=260){
 h.Observe(buy?"BR-CHoCH":"BL-CHoCH",t,available,150,buy?115:85,line);
}
void zone(CTradeRejectionHistory& h,bool buy,double low,double high,datetime created=150,datetime available=260,datetime cause=200){
 h.BeginZones();h.Zone("opposing",!buy,low,high,created,0,cause,available);h.EndZones(available);
}
int main(){
 for(bool buy:{false,true}){
  SMarcoTPPlan p;check(CMarcoStagedTP::Build(p,buy,100,buy?90:110,buy?120:80,buy?130:70,1,2,0,.01,2));
  CTradeRejectionHistory h;
  event(h,buy,buy?95:105);zone(h,buy,buy?114:84,buy?116:86);
  check(CMarcoStructureExit::Evaluate(h,p,100,259,3).action==0); // Cannot use future CHoCH/LB.
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==2); // SL-side CHoCH.
  check(CMarcoStructureExit::Evaluate(h,p,261,300,3).action==0); // Before-entry CHoCH.
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,buy?129:69,buy?140:71);
  auto signal=CMarcoStructureExit::Evaluate(h,p,100,260,1);
  check(signal.action==1 && signal.tf==1 && signal.eventTime==200); // Partial overlap with far TP.
  p.structureTime[0]=270;check(CMarcoStructureExit::Evaluate(h,p,100,300,1).action==0);
  p.structureTime[0]=0;
  h.Observe(buy?"BR-BOS":"BL-BOS",280,340,150,buy?115:85,buy?111:89);
  check(CMarcoStructureExit::Evaluate(h,p,100,340,3).action==1); // Catch-up must not lose a qualifying CHoCH behind BOS.
  // A delayed source LB can only trigger once its explicit causal link is available.
  h.Reset();event(h,buy,buy?95:105);
  h.Observe(buy?"BR-BOS":"BL-BOS",280,340,150,buy?115:85,buy?111:89);
  check(CMarcoStructureExit::Evaluate(h,p,100,340,1).action==0);
  zone(h,buy,buy?114:84,buy?116:86,150,400,200);
  check(CMarcoStructureExit::Evaluate(h,p,100,399,1).action==0);
  check(CMarcoStructureExit::Evaluate(h,p,100,400,1).action==2);
  // A reclassification of the earlier CHoCH invalidates it only when known.
  h.Observe(buy?"BSL-Swept":"SSL-Swept",200,420,999,999,buy?95:105);
  check(CMarcoStructureExit::Evaluate(h,p,100,419,1).action==2);
  check(CMarcoStructureExit::Evaluate(h,p,100,420,1).action==0);
  SRejectionEvent latest;check(h.Latest(420,latest) && latest.time==280); // Revision is not a new market event.
  SRejectionEvent revised;check(h.EventAt(h.EventCount()-1,420,revised) && revised.originTime==150);
  int count=h.EventCount();h.Observe(buy?"BR-BOS":"BL-BOS",280,430,999,999,999);
  check(h.EventCount()==count); // Unchanged older observations do not duplicate events.
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,buy?114:84,buy?116:86,50);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Old origin is not a new LB.
  h.Reset();zone(h,buy,buy?114:84,buy?116:86,150,50,0);
  event(h,buy,buy?110:90);zone(h,buy,buy?113:83,buy?117:87,150,260,200);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Bounds/cause update does not recreate LB.
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,buy?114:84,buy?116:86,150,260,0);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==1); // Source inside known LB, no causal tag.
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,buy?121:71,buy?122:72,150,260,0);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Unrelated opposing LB.
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,99,101);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==2); // Both regions: full wins.
  p.structureTime[0]=270;check(CMarcoStructureExit::Evaluate(h,p,100,300,3).action==2); // Full still allowed after half.
  p.structureTime[0]=0;
  h.BeginZones();h.EndZones(280);check(CMarcoStructureExit::Evaluate(h,p,100,300,3).action==0);
  h.Reset();event(h,buy,buy?110:90);zone(h,buy,buy?140:50,buy?150:60);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Beyond TP, no overlap.
  h.Reset();event(h,!buy,buy?95:105);zone(h,buy,buy?114:84,buy?116:86);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Same-direction CHoCH.
  h.Reset();event(h,buy,0);zone(h,buy,99,101);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,3).action==0); // Missing break price fails closed.
  h.Reset();event(h,buy,buy?95:105);
  h.BeginZones();h.Zone("vetoed",!buy,buy?114:84,buy?116:86,150,0,200,260,true);h.EndZones(260);
  check(CMarcoStructureExit::Evaluate(h,p,100,260,1).action==2); // IND veto must not disable protection.
  check(h.OpposingChoch(buy,150,260,260,260,1,0).action==TRADE_RETIRE_ZONE); // Entry-vetoed source still blocks opposing entries.
  h.BeginZones();h.Zone("vetoed",!buy,buy?114:84,buy?116:86,150,0,200,270,false);h.EndZones(270);
  check(h.OpposingChoch(buy,150,270,270,270,1,0).action==TRADE_RETIRE_ZONE); // Control: regular LB rejects.
 }
 std::cout<<"PASS: "<<checks<<" structural-exit checks (both directions, causal links, time availability, overlap, precedence)\n";
}
''')
with tempfile.TemporaryDirectory(prefix='marco_structure_tests_') as directory:
    source, binary = Path(directory) / 'test.cpp', Path(directory) / 'test.exe'
    source.write_text('\n'.join(parts), encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe', '-std=c++17', '-O2',
                    str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
