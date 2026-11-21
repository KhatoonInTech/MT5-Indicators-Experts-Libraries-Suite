"""Exact US30 no-clustering entry regression, using production M1 contexts."""
from pathlib import Path
import subprocess, sys
base=Path(__file__).with_name('replay_us30_context.py')
exec(compile(base.read_text().split("main = r" + chr(39)*3)[0],str(base),'exec'))
main = r'''
int main(int argc,char**argv){
 CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);
 Settings* settings=new Settings(.001,1,0,false,false,false,false,"Absolute");settings->draw=false;
 ZigZag* zz=newInstance(settings);CMarcoM1LBContext ctx;
 ctx.Init(true,true,2,1,true,false,10,false,true,true,true,false,false,.1);
 SMarcoIndWait wait;CMarcoIndEntryFilter::Reset(wait);
 std::ifstream f(argv[1]);string line;std::getline(f,line);int i=0;
 bool checked=false;
 while(std::getline(f,line)){
  std::replace(line.begin(),line.end(),',',' ');std::istringstream s(line);
  datetime t;double o,h,l,c;long volume,real;int spread;s>>t>>o>>h>>l>>c>>volume>>spread>>real;
  zz->update(h,l,t,volume,i++,true,false);ctx.Update(t,o,h,l,c,zz,1.0);
  string stamp=TimeToString(t+60);
  if(stamp=="2026.11.12 20:03"){
   string id;assert(ctx.indEntry.SkipPrice(wait,true,t-60,t+60,t+60,52412.8,id));
   std::cout<<"FIRST ENTRY BLOCKED "<<stamp<<" IND="<<id<<" bounds="<<wait.low<<","<<wait.high<<"\n";
  }
  if(stamp=="2026.11.12 20:36"){
   double low,high;string id;
   std::cout<<"INSIDE_ACTIVE_IND "<<ctx.indEntry.Inside(true,52381.8,t+60,low,high,id)<<"\n";
   bool ready=ctx.indEntry.Ready(wait,true,t-60,52377.9,t+60,52251.4,52416.3);
   auto result=ctx.rejectionHistory.OpposingChoch(true,t-360,t-60,t+60,t+60,1,50);
   std::cout<<"WAIT_READY="<<ready<<" STRUCTURE_ACTION="<<result.action<<" SOURCE="<<result.opposingId<<"\n";
   for(int e=0;e<ctx.indEntry.events.size();e++){
    auto ev=ctx.indEntry.events[e];if(ev.time>=1794513780)
      std::cout<<"WAIT_EVENT "<<TimeToString(ev.time)<<" bull="<<ev.bull<<" known="<<TimeToString(ev.available)<<"\n";
   }
   for(int z=0;z<ctx.ind->m_zones.Total();z++){
    auto zone=(CInducementZone*)ctx.ind->m_zones.At(z);
    if(zone->isBullish&&zone->zoneLow<52390&&zone->zoneHigh>52330)
      std::cout<<"IND "<<zone->id<<" bounds="<<zone->zoneLow<<","<<zone->zoneHigh<<" qualified="<<zone->isInducement<<" touches="<<zone->touchCount<<" mitigated="<<TimeToString(zone->mitigationTime)<<"\n";
   }
   if(argc>2){assert(!ready);assert(result.action==TRADE_RETIRE_ZONE);assert(result.eventTime==t-180);}
   checked=true;break;
  }
 }
 assert(checked);delete zz;
}
'''
suffix='_live' if engine=='marco_live_auto' else ''
cpp=OUT/f'us30_no_cluster{suffix}.cpp';exe=OUT/f'us30_no_cluster{suffix}.exe'
cpp.write_text(mock+source+main,encoding='utf-8')
r=subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
args=[str(exe),str(OUT/'us30_20261112_m1.csv')]
if '--assert-fixed' in sys.argv:args.append('assert')
r=subprocess.run(args,capture_output=True,text=True)
print(r.stdout);print(r.stderr)
(OUT/f'us30_no_cluster{suffix}_replay.txt').write_text(r.stdout,encoding='utf-8')
raise SystemExit(r.returncode)
