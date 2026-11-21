"""Exercise actual shared IND qualification; never connects to a terminal."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
adapter=ROOT/'Tests/Marcotrades/replay_us30_context.py'
env={'__file__':str(adapter)}
exec(compile(adapter.read_text().split("main = r'''",1)[0],str(adapter),'exec'),env)
main=r'''
int checks=0;
void check(bool ok){++checks;if(!ok){std::cerr<<"Failure "<<checks<<"\n";std::exit(1);}}
void event(CMarketStructure&ms,datetime t,string name){ms.all_event_times.Add(t);ms.all_event_names.Add(name);}
void setup(CInducementLogic&ind){ind.Init(2,0,false,false,false,false,false,false,true,0,false);}
void prepare(CInducementZone&z,bool bull){z.isBullish=bull;z.createdTime=100;z.touchCount=2;z.lastTouchTime=160;}
int main(){
 for(bool bull:{false,true})for(int before:{-1,0,1})for(int after:{-1,1}){
  CInducementLogic ind;setup(ind);CMarketStructure ms;CInducementZone zone;prepare(zone,bull);
  if(before)event(ms,90,before==1?"BL-BOS":"BR-CHoCH");
  event(ms,150,after==1?"BL-CHoCH":"BR-BOS");
  ind.QualifyZone(&zone,&ms,180,240);
  bool reject=before==(bull?-1:1)&&after==(bull?-1:1);
  check(zone.structureRejected==reject);check(zone.isInducement==!reject);
  check(zone.structureBefore==before&&zone.structureAfter==after);
  check(zone.qualifiedTime==(reject?0:240));check(zone.inducementTime==(reject?0:160));
 }
 for(bool bull:{false,true}){
  CInducementLogic ind;setup(ind);CMarketStructure ms;CInducementZone z;prepare(z,bull);
  string opposing=bull?"BR-BOS":"BL-BOS",support=bull?"BL-CHoCH":"BR-CHoCH";
  event(ms,90,opposing); // Unbroken opposing trend persists after origin without a new event.
  ind.QualifyZone(&z,&ms,180,240);check(z.structureRejected&&!z.isInducement);
  event(ms,300,support);ind.QualifyZone(&z,&ms,360,420);
  check(z.structureRejected&&!z.isInducement&&z.qualifiedTime==0); // A rejected source is not resurrected later.
  CInducementZone future;prepare(future,bull);
  ind.QualifyZone(&future,&ms,180,240);check(future.structureRejected); // Ignore future events.
  CInducementZone later;prepare(later,bull);
  ind.QualifyZone(&later,&ms,360,420);check(later.isInducement&&!later.structureRejected);
  // Late harvesting still uses the first qualifying touch, not the last extra touch.
  CInducementZone harvested;prepare(harvested,bull);harvested.touchCount=3;harvested.lastTouchTime=170;
  harvested.touchTimes.Add(140);harvested.touchTimes.Add(160);harvested.touchTimes.Add(170);
  ind.QualifyZone(&harvested,&ms,360,420);check(harvested.isInducement&&harvested.inducementTime==160);
  // Once legitimately qualified, a subsequent trend change does not rewrite its old status.
  event(ms,400,opposing);ind.QualifyZone(&later,&ms,420,480);
  check(later.isInducement&&later.qualifiedTime==420);
  // A zone created on the event candle must not use that same event as BEFORE evidence.
  CMarketStructure sameBar;event(sameBar,100,opposing);CInducementZone same;prepare(same,bull);
  ind.QualifyZone(&same,&sameBar,180,240);check(same.isInducement&&same.structureBefore==0);
  // Do not mistake liquidity sweeps or the engine's initial trend for BOS/CHoCH.
  CMarketStructure sweeps;event(sweeps,90,"SSL-Swept");event(sweeps,150,"BSL-Swept");
  CInducementZone swept;prepare(swept,bull);ind.QualifyZone(&swept,&sweeps,180,240);
  check(swept.isInducement&&swept.structureBefore==0&&swept.structureAfter==0);
  // A CHoCH reclassified as a sweep must not override the last valid structural direction.
  CMarketStructure renamed;event(renamed,80,support);event(renamed,90,"SSL-Swept");event(renamed,150,opposing);
  CInducementZone valid;prepare(valid,bull);ind.QualifyZone(&valid,&renamed,180,240);
  check(valid.isInducement&&!valid.structureRejected);
  CInducementZone insufficient;prepare(insufficient,bull);insufficient.touchCount=1;
  ind.QualifyZone(&insufficient,&ms,180,240);check(!insufficient.structureRejected&&!insufficient.isInducement);
  insufficient.touchCount=2;ind.QualifyZone(&insufficient,&ms,100,160);
  check(!insufficient.structureRejected&&!insufficient.isInducement);
  // A rejected cluster master cannot swallow a later independent candidate.
  ind.RegisterZone("test",bull,110,100,100,0,nullptr,1);
  auto master=(CInducementZone*)ind.m_zones.At(0);prepare(*master,bull);
  ind.QualifyZone(master,&ms,180,240);check(master->structureRejected);
  ind.RegisterZone("test",bull,110,100,200,1,nullptr,1);check(ind.m_zones.Total()==2);
  // Process(), which all programs call, must run the same gate before exposing INDs.
  CInducementLogic pipeline;setup(pipeline);auto rejected=new CInducementZone();prepare(*rejected,bull);
  rejected->zoneHigh=110;rejected->zoneLow=100;pipeline.m_zones.Add(rejected);
  std::vector<datetime> time={180};std::vector<double> open={105},high={109},low={101},close={106};
  pipeline.Process(0,time,open,high,low,close,nullptr,&ms,nullptr,nullptr,nullptr,nullptr,nullptr,1);
  check(rejected->structureRejected&&!rejected->isInducement);
 }
 std::cout<<"PASS: "<<checks<<" shared IND before/after structure checks (both directions, causal cutoff, qualification, clustering)\n";
}
'''
visual=(ROOT/'Indicators/Custom/Marcotrades/liquiduity_block.mq5').read_text(encoding='utf-8-sig')
loop=visual[visual.index('   for(int i = start; i < rates_total; i++)'):]
assert loop.index('if(is_last) continue;')<loop.index('ms.Update(')<loop.index('indLogic.Process(')
out=ROOT/'Tests/Marcotrades/_review'
cpp,exe=out/'ind_structure.cpp',out/'ind_structure.exe'
cpp.write_text(env['mock']+env['source']+main,encoding='utf-8')
result=subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2','-fmax-errors=5',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:raise SystemExit(result.stderr)
result=subprocess.run([str(exe)],capture_output=True,text=True)
(out/'ind_structure_results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout,end='')
if result.returncode:raise SystemExit(result.stderr or f'Exit code {result.returncode}')
