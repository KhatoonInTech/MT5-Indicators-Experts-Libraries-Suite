"""Run production lower-TF admission and both engines' candidate publishers offline."""
from pathlib import Path
import re, shutil, subprocess, tempfile

root=Path(__file__).resolve().parents[2]
header=(root/'Include/Custom/Marcotrades/lb_tf_preference.mqh').read_text(encoding='utf-8-sig')
cluster=(root/'Include/Custom/Marcotrades/lb_entry_clusters.mqh').read_text(encoding='utf-8-sig')
live=(root/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
back=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')

def method(text,name):
    start=re.search(r'^\s*(?:void|bool)\s+'+name+r'\(',text,re.M).start()
    pos=text.index('{',start)+1;depth=1
    while depth:
        depth+=(text[pos]=='{')-(text[pos]=='}');pos+=1
    return text[start:pos]

def adapt(text):
    text=re.sub(r'^(\s*)static (\w+) (\w+)\[\];',r'\1static std::vector<\2> \3;',text,flags=re.M)
    text=re.sub(r'^(\w+) (\w+::\w+)\[\];',r'std::vector<\1> \2;',text,flags=re.M)
    text=re.sub(r'^(\s*)(\w+) (\w+)\[\];',r'\1std::vector<\2> \3;',text,flags=re.M)
    text=text.replace('logic.','logic->').replace('lb.','lb->')
    return text

mock=r'''
#include <string>
#include <vector>
#include <cmath>
#include <algorithm>
#include <iostream>
#include <cstdlib>
using string=std::string;using datetime=long long;using ENUM_TIMEFRAMES=int;
enum {PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,PERIOD_M15=15,PERIOD_H1=16385};
int PeriodSeconds(int tf){return tf>=16385?(tf-16384)*3600:tf*60;}
string EnumToString(int tf){return std::to_string(tf);}
string IntegerToString(int v){return std::to_string(v);}
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>int ArrayResize(std::vector<T>&v,int n){v.resize(n);return n;}
template<class T>T MathAbs(T v){return std::abs(v);}
template<class T>T MathMax(T a,T b){return std::max(a,b);}
template<class T>T MathMin(T a,T b){return std::min(a,b);}
bool MathIsValidNumber(double v){return std::isfinite(v);}
int logs=0;template<class...T>void PrintFormat(T...){logs++;}
int checks=0;
#define CHECK(x) do{checks++;if(!(x)){std::cerr<<"FAILED "<<__LINE__<<": "<<#x<<"\n";std::exit(1);}}while(0)
enum {LB_TRIGGER_BL_IND=1,LB_TRIGGER_BR_IND=2,LB_TRIGGER_BL_BSL=3,LB_TRIGGER_BR_SSL=4};
struct CLiquidityBlock{string id;bool isMitigated=false,isBullish=false;double zoneLow=120,zoneHigh=180;};
struct Blocks{std::vector<CLiquidityBlock*> values;int Total(){return values.size();}CLiquidityBlock* At(int i){return values[i];}};
struct CLiquidityBlockLogic{Blocks m_liquidity_blocks;};
struct CachedLB{string id="L",preferredLTF="";bool sourceActive=true,isBullish=false,isMitigated=false;int touchCount=0,triggerType=LB_TRIGGER_BR_IND;double zoneLow=120,zoneHigh=180;datetime entryTriggerTime=100,createdTime=10,confirmedTime=50,inducementOriginTime=1,sweepLineTime=1;};
class CTradeRejection{public:static bool Used(int t,bool m){return t>0||m;}static bool OutsideSession(datetime o,datetime c,datetime f,datetime d){return o<d||c<d||f<d;}};
'''
observers=''
for label,source in [('Live',live),('Backtest',back)]:
    observers+=f'class {label}Observer{{public:\n'
    observers+='string m_symbol="S";ENUM_TIMEFRAMES m_tradeTF=2;int m_htf_lb_count=1;std::vector<CachedLB> m_htf_lbs={CachedLB{}};\n'
    observers+=adapt(method(source,'ObserveTFPreferences'))+adapt(method(source,'DeferToLowerTF'))+'\n};\n'

cases=r'''
bool preferred(int tf,bool bull,double low,double high,datetime now,string symbol="S"){
 SMarcoLBTFChoice c;return CMarcoLBTFPreference::Preferred(symbol,tf,bull,low,high,now,c);
}
template<class Observer>void publisherChecks(){
 CMarcoLBTFPreference::Configure(true);CMarcoLBEntryClusters book;Observer p;
 CLiquidityBlock raw;raw.id="L";CLiquidityBlockLogic logic;logic.m_liquidity_blocks.values={&raw};
 book.Observe("S",2,"L",-1,120,180,200,false,10);
 p.ObserveTFPreferences(book,219,&logic);CHECK(!preferred(15,false,100,200,219));
 p.ObserveTFPreferences(book,220,&logic);CHECK(preferred(15,false,100,200,220));
 // Registered historical envelopes are deliberately not used as current geometry.
 book.Observe("S",2,"L",-1,80,220,221,false,10);
 p.ObserveTFPreferences(book,221,&logic);CHECK(preferred(15,false,100,200,221));
 // Reclassification, use, qualification, session, authoritative mitigation and
 // rejection/trade cluster barriers all remove this preference on refresh.
 p.m_htf_lbs[0].sourceActive=false;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));
 p.m_htf_lbs[0].sourceActive=true;p.m_htf_lbs[0].touchCount=1;
 p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));p.m_htf_lbs[0].touchCount=0;
 p.m_htf_lbs[0].isMitigated=true;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));p.m_htf_lbs[0].isMitigated=false;
 p.m_htf_lbs[0].entryTriggerTime=0;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));p.m_htf_lbs[0].entryTriggerTime=100;
 raw.isMitigated=true;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));raw.isMitigated=false;
 p.m_htf_lbs[0].inducementOriginTime=-1;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));p.m_htf_lbs[0].inducementOriginTime=1;
 logic.m_liquidity_blocks.values.clear();p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));logic.m_liquidity_blocks.values={&raw};
 book.RejectOpposing("S",2,"L",200);p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));
 book.Clear();book.Observe("S",2,"L",-1,120,180,200,false,10);CHECK(book.Consume("S",2,"L",200));
 p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));
 // Ordinary sweep setup is preferred without adding an IND prerequisite.
 book.Clear();book.Observe("S",2,"L",-1,120,180,200,false,10);p.m_htf_lbs[0].triggerType=LB_TRIGGER_BR_SSL;
 p.ObserveTFPreferences(book,221,&logic);CHECK(preferred(15,false,100,200,221));
 p.m_htf_lbs[0].sweepLineTime=-1;p.ObserveTFPreferences(book,221,&logic);CHECK(!preferred(15,false,100,200,221));p.m_htf_lbs[0].sweepLineTime=1;
 p.ObserveTFPreferences(book,221,&logic);
 Observer higher;higher.m_tradeTF=15;higher.m_htf_lbs[0].zoneLow=100;higher.m_htf_lbs[0].zoneHigh=200;
 int before=logs;CHECK(higher.DeferToLowerTF(0,221));CHECK(logs==before+1);
 CHECK(higher.DeferToLowerTF(0,221));CHECK(logs==before+1);
 CHECK(higher.m_htf_lbs[0].touchCount==0);CHECK(!higher.m_htf_lbs[0].isMitigated);CHECK(book.nodes[0].usedAt==0);
 CMarcoLBTFPreference::ResetOwner("S",2);CHECK(!higher.DeferToLowerTF(0,221));CHECK(higher.m_htf_lbs[0].preferredLTF=="");
 // A freshly registered HTF bridge can join an older rejected neighbour.
 // Republishing after all registrations prevents the now-blocked LTF from
 // suppressing the new HTF IND that legitimately passes the renewal exception.
 book.Clear();book.Observe("S",2,"L",-1,120,180,300,false,10);
 book.Observe("S",3,"rejected",-1,190,210,300,false,10);book.RejectOpposing("S",3,"rejected",200);
 p.ObserveTFPreferences(book,300,&logic);CHECK(preferred(15,false,100,220,300));
 book.Observe("S",15,"fresh",-1,100,220,300,false,250,300);
 string reason;datetime used=0;CHECK(!book.Blocked("S",15,"fresh",300,reason,used));
 p.ObserveTFPreferences(book,300,&logic);CHECK(!preferred(15,false,100,220,300));
}
int main(){
 for(bool bull:{false,true})for(int lower:{1,2,3,5,10})for(int higher:{15,30,16385}){
  CMarcoLBTFPreference::Configure(true);
  CMarcoLBTFPreference::Observe("S",lower,"L",bull,120,180,100,100);
  CHECK(preferred(higher,bull,100,200,100));CHECK(!preferred(higher,!bull,100,200,100));
  CHECK(!preferred(lower,bull,100,200,100));CHECK(!preferred(higher,bull,100,200,99));
  CHECK(!preferred(higher,bull,100,200,86400));CHECK(!preferred(higher,bull,100,200,100,"X"));
  CHECK(preferred(higher,bull,130,200,100)==bull);CHECK(preferred(higher,bull,100,170,100)==!bull);
  CHECK(!preferred(higher,bull,120,180,100));
  // Sharing the distal edge is allowed; sharing the entry-side edge is not deeper.
  CHECK(preferred(higher,bull,bull?120:100,bull?200:180,100));
  CHECK(!preferred(higher,bull,bull?100:120,bull?180:200,100));
  CMarcoLBTFPreference::Configure(false);CHECK(!preferred(higher,bull,100,200,100));
 }
 CMarcoLBTFPreference::Configure(true);
 CMarcoLBTFPreference::Observe("S",2,"future",false,120,180,101,100);CHECK(!preferred(15,false,100,200,101));
 CMarcoLBTFPreference::Observe("S",2,"bad",false,180,120,100,100);CHECK(!preferred(15,false,100,200,100));
 // User's directional partial overlaps: buys may extend below the HTF low,
 // sells above its high, but the entry edge must remain strictly inside.
 for(bool bull:{false,true}){
  CMarcoLBTFPreference::Configure(true);
  CMarcoLBTFPreference::Observe("S",2,"partial",bull,bull?80:120,bull?180:220,100,100);
  CHECK(preferred(15,bull,100,200,100));
  CHECK(!preferred(15,bull,bull?180:100,bull?200:120,100)); // Mere boundary contact.
  CHECK(!preferred(15,bull,bull?181:100,bull?200:119,100)); // Gap.
  CMarcoLBTFPreference::ResetOwner("S",2);
  CMarcoLBTFPreference::Observe("S",2,"shallower",bull,bull?120:80,bull?220:180,100,100);
  CHECK(!preferred(15,bull,100,200,100));
 }
 CMarcoLBTFPreference::Clear();
 // Multi-level nesting: both bigger setups wait; smallest executes its own policy.
 CMarcoLBTFPreference::Observe("S",5,"middle",false,110,190,100,100);
 CMarcoLBTFPreference::Observe("S",2,"small",false,120,180,100,100);
 SMarcoLBTFChoice c;CHECK(CMarcoLBTFPreference::Preferred("S",15,false,100,200,100,c));CHECK(c.tf==2);
 CHECK(preferred(5,false,110,190,100));CHECK(!preferred(2,false,120,180,100));
 CMarcoLBTFPreference::ResetOwner("S",2);CHECK(CMarcoLBTFPreference::Preferred("S",15,false,100,200,100,c));CHECK(c.tf==5);
 CMarcoLBTFPreference::ResetOwner("X",5);CHECK(preferred(15,false,100,200,100));
 CMarcoLBTFPreference::Clear();CHECK(!preferred(15,false,100,200,100));
 publisherChecks<LiveObserver>();publisherChecks<BacktestObserver>();
 std::cout<<"PASS: "<<checks<<" lower-TF preference and production publisher checks\n";
}
'''

# Admission waits precede pivot expiry/consumption and order submission. All-TF
# publication uses the established prepare phase, not post-trade discovery.
for source,start_name,time_arg in [(live,'ProcessLive','TimeCurrent()'),(back,'RunSimulation','m_sim.run_time[i]')]:
    scope=source[source.index('   void              ProcessLive('):] if start_name=='ProcessLive' else source[source.index('// 3. SCAN NEW ENTRY'):]
    assert scope.index('DeferToLowerTF(k,'+time_arg+')') < scope.index('CTradeRejection::M1Expired(')
    assert scope.index('CheckChochRejection(') < scope.index('DeferToLowerTF(')
assert 'ObserveTFPreferences(s_clusters,now,m_sim.lbLogicHtf);' in method(back,'RegisterPreparedTFPreferences')
batch=back[back.index('class CMarcoSimulationBatch'):]
assert batch.index('items[i].RegisterPreparedClusters(next);') < batch.index('items[i].RegisterPreparedTFPreferences(next);') < batch.index('if(!Run(items[i],c,next,false,phase==0))')
assert 'ObserveTFPreferences(state.book,now,m_instances[i].lbLogicHtf);' in method(live,'PrepareSymbolClusters')
assert 'if(!changed && !CMarcoLBTFPreference::Enabled()) return true;' in live
for path in ['Experts/Custom EAs/Marcotrades/marco_live_auto_ea.mq5','Experts/Custom EAs/Backtesting/marco_backtest_ea.mq5','Indicators/Custom/Marcotrades/marco_backtest_trades.mq5']:
    s=(root/path).read_text(encoding='utf-8-sig')
    assert 'input bool InpPreferLowerTFLB = true;' in s
    assert 'CMarcoLBTFPreference::Configure(InpPreferLowerTFLB);' in s
    if 'Indicators/' in path:assert 'key+="|InpPreferLowerTFLB="+(string)InpPreferLowerTFLB;' in s

source=mock+adapt(cluster)+adapt(header)+observers+cases
compiler=shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
with tempfile.TemporaryDirectory(prefix='marco_ltf_') as td:
    cpp=Path(td)/'preference.cpp';exe=Path(td)/'preference.exe';cpp.write_text(source,encoding='utf8')
    subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
    broken=source.replace('candidate.high<=low || candidate.high>=high','false || candidate.high>=high')
    assert broken!=source
    cpp.write_text(broken,encoding='utf8')
    subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
    result=subprocess.run([str(exe)],capture_output=True,text=True)
    assert result.returncode!=0,'boundary-only overlap mutation escaped'
print('PASS: three-client wiring, cache isolation and directional-overlap mutation checks')
