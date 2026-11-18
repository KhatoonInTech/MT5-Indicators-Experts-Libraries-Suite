"""Production-engine replay: warmup state, zone origins and drawing boundaries."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
adapter = ROOT/'Tests/Marcotrades/replay_us30_context.py'
env = {'__file__': str(adapter)}
exec(compile(adapter.read_text().split("main = r'''", 1)[0], str(adapter), 'exec'), env)
mock = env['mock']
mock = mock.replace('template<class...A>void ObjectCreate(A...){}', '''
datetime drawFloor=0;int drawingCount=0,badDrawings=0;
template<class...A>void ObjectCreate(int,string,int,int,datetime t,double,A...){
 ++drawingCount;if(t<drawFloor)++badDrawings;
}''')
mock = mock.replace('template<class...A>static void DrawLine(A...){}', '''
static void DrawLine(string,datetime t,double,datetime,double,int,int,int,bool){
 ++drawingCount;if(t<drawFloor)++badDrawings;
}''')
mock = mock.replace('template<class...A>static void DrawLabel(A...){}', '''
template<class...A>static void DrawLabel(string,datetime t,double,A...){
 ++drawingCount;if(t<drawFloor)++badDrawings;
}''')
main = r'''
int checks=0;
void checked(bool ok,int line){++checks;if(!ok){std::cerr<<"failure "<<checks<<" at generated line "<<line<<"\n";std::exit(1);}}
#define check(x) checked((x),__LINE__)
void origins(CArrayLong& times,datetime day){for(int i=0;i<times.Total();++i)check(times.At(i)>=day);}
struct Bar {datetime time;double open,high,low,close;};
int main(){
 const datetime day=1794528000;
 std::vector<Bar> minutes;
 for(int i=0;i<2880;++i){double o=1000+i*.03+25*std::sin(i/70.)+8*std::cos(i/17.);
  double c=1000+(i+1)*.03+25*std::sin((i+1)/70.)+8*std::cos((i+1)/17.);
  minutes.push_back({day-86400+i*60,o,std::max(o,c)+.3,std::min(o,c)-.3,c});}
 for(int tf:{1,2,3,4,5,10,12,15,30,60}){
  std::vector<Bar> bars;
  for(int i=0;i<int(minutes.size());i+=tf){auto b=minutes[i];
   for(int j=i+1;j<i+tf;++j){b.high=std::max(b.high,minutes[j].high);b.low=std::min(b.low,minutes[j].low);b.close=minutes[j].close;}
   bars.push_back(b);}
  auto settings=new Settings(.001,1,0,true,false,false,false,"Absolute");settings->draw=true;
  auto zz=new ZigZag(settings);zz->zoneStartTime=day;zz->drawStartTime=day;
  auto referenceSettings=new Settings(.001,1,0,true,false,false,false,"Absolute");referenceSettings->draw=false;
  auto reference=new ZigZag(referenceSettings);
  CMarcoM1LBContext context,baseline;
  context.Init(true,true,2,0,false,false,0,false,true,true,true,true,true,.01);
  baseline.Init(true,true,2,0,false,false,0,false,true,true,true,true,true,.01);
  context.ms->Init(true,true,tf);context.ms->m_drawStartTime=day;
  baseline.ms->Init(false,false,tf);
  drawFloor=day;drawingCount=0;badDrawings=0;
  int before=0;
  for(int i=0;i<int(bars.size());++i){auto b=bars[i];
   zz->update(b.high,b.low,b.time,10,i,true,false);
   reference->update(b.high,b.low,b.time,10,i,true,false);
   context.Update(b.time,b.open,b.high,b.low,b.close,zz,.01);
   baseline.Update(b.time,b.open,b.high,b.low,b.close,reference,.01);
   check(context.ms->trend==baseline.ms->trend);
   check(context.ms->protected_level_price==baseline.ms->protected_level_price);
   check(context.ms->target_level_price==baseline.ms->target_level_price);
   check(context.ms->last_breakout_time==baseline.ms->last_breakout_time);
   check(zz->pivots->Total()==reference->pivots->Total());
   check(badDrawings==0);
   if(b.time<day){
    check(drawingCount==0);
    check(context.ds->poi_demandTime.Total()+context.ds->poi_supplyTime.Total()==0);
    check(context.sp->poi_demandTime.Total()+context.sp->poi_supplyTime.Total()==0);
    check(context.ob->poi_demandTime.Total()+context.ob->poi_supplyTime.Total()==0);
    check(context.fz->fz_time.Total()==0);
    check(context.ind->m_zones.Total()==0);
    check(context.lbs->m_liquidity_blocks.Total()+context.lbs->m_exit_sources.Total()==0);
    ++before;
   }
  }
  check(before>0&&zz->pivots->Total()>2&&context.ms->last_breakout_time>0);
  check(drawingCount>0);
  check(context.ds->poi_demandTime.Total()+context.ds->poi_supplyTime.Total()>0);
  origins(context.ds->poi_demandTime,day);origins(context.ds->poi_supplyTime,day);
  origins(context.sp->poi_demandTime,day);origins(context.sp->poi_supplyTime,day);
  origins(context.ob->poi_demandTime,day);origins(context.ob->poi_supplyTime,day);
  origins(context.fz->fz_time,day);
  origins(context.bb->bb_time,day);
  for(int i=0;i<context.ind->m_zones.Total();++i)
   check(((CInducementZone*)context.ind->m_zones.At(i))->createdTime>=day);
  for(int i=0;i<context.lbs->m_liquidity_blocks.Total();++i)
   check(((CLiquidityBlock*)context.lbs->m_liquidity_blocks.At(i))->createdTime>=day);
  for(int i=0;i<context.lbs->m_exit_sources.Total();++i)
   check(((CLiquidityBlock*)context.lbs->m_exit_sources.At(i))->createdTime>=day);
  // Late confirmation must never resurrect a warmup-origin zone.
  int count=context.ind->m_zones.Total();
  context.ind->RegisterZone("DS",true,100,90,day-60,2000,zz,.01);
  check(context.ind->m_zones.Total()==count);
  count=context.lbs->m_liquidity_blocks.Total();
  context.lbs->RegisterLiquidityBlock(true,LB_TRIGGER_BL_BSL,100,90,day-60,2000,day,context.ind);
  check(context.lbs->m_liquidity_blocks.Total()==count);
  delete zz;delete reference;
  std::cout<<"TF "<<tf<<": same swings/structure; no warmup zones/drawings; new-day zones allowed\n";
 }
 std::cout<<checks<<" structure-only warmup checks passed\n";
}
'''
out = ROOT/'Tests/Marcotrades/_review'
suffix = '_live' if env['engine']=='marco_live_auto' else ''
cpp, exe = out/f'structure_only{suffix}.cpp', out/f'structure_only{suffix}.exe'
cpp.write_text(mock+env['source']+main, encoding='utf-8')
result = subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2','-fmax-errors=5',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:
    raise SystemExit(result.stderr)
result = subprocess.run([str(exe)],capture_output=True,text=True)
(out/f'structure_only{suffix}_results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout,end='')
if result.returncode:
    raise SystemExit(result.stderr or str(result.returncode))
