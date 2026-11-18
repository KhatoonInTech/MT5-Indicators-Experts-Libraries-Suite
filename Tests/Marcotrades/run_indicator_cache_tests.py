"""Exercise the indicator's actual cache, collection, drawing selection and lifecycle.

Uses an in-memory filesystem/MT5 adapter; never launches a terminal or sends orders.
"""
from pathlib import Path
import re, shutil, subprocess, tempfile

root=Path(__file__).resolve().parents[2]
indicator=(root/'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5').read_text(encoding='utf-8-sig')
back=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
policy=(root/'Include/Custom/Marcotrades/staged_tp.mqh').read_text(encoding='utf-8-sig')
mock=(root/'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()
mock=mock.replace('void FileWriteInteger(int f,int v){put<int32_t>(f,v);}',
                 'unsigned int FileWriteInteger(int f,int v){put<int32_t>(f,v);return 4;}')
mock=mock.replace('int FileReadInteger(int f){return get<int32_t>(f);}',
 'int FileReadInteger(int f){if(handles.at(f).offset+4>files.at(handles.at(f).path).size()) return 0; return get<int32_t>(f);}')

def function(name):
    start=re.search(r'^\w+ '+name+r'\(',indicator,re.M).start()
    body=indicator.index('{',start)
    depth=1; end=body+1
    while depth:
        depth+=(indicator[end]=='{')-(indicator[end]=='}'); end+=1
    return indicator[start:end]

def struct(source,name):
    return re.search(r'struct '+name+r'\s*\{.*?\n  };',source,re.S).group()

def adapt(source):
    source=source.replace('instance.','instance->')
    source=re.sub(r'\blong\b','long long',source)
    source=re.sub(r'\(string\)(\w+)',r'ToString(\1)',source)
    source=re.sub(r'\b(\w+)\s+(\w+)\[\]\s*(=\s*\{[^}]*\})?;',
        lambda m:'std::vector<'+m[1]+'> '+m[2]+(' '+m[3] if m[3] else '')+';',source)
    return source

defaults={'InpStartWindow':'100','InpEndWindow':'1000','InpStartingCapital':'500','InpMaxRiskPercent':'25',
          'InpDepth':'1','InpDeviation':'0.001','InpFillStrength':'25','InpMaxTrades':'2',
          'InpScanSpeedPerSecond':'15','InpFallbackRR':'1','InpTPVicinityTF':'0','InpSetupTF':'0','InpPipSizeOverrides':'""'}
inputs=[]
for kind,name in re.findall(r'^input\s+(\w+)\s+(Inp\w+)\s*=',indicator,re.M):
    cppkind='string' if kind=='string' else 'double' if kind=='double' else 'bool' if kind=='bool' else 'int'
    value=defaults.get(name,'"Absolute"' if kind=='string' else 'true' if kind=='bool' else '1')
    inputs.append(f'{cppkind} {name}={value};')

adapters=r'''
class DailyLogStub{public:void Start(){} void Pulse(){} void Write(string){}};
DailyLogStub g_marcoDailyLog;
string replayFingerprint="initial";
class CMarcoRiskCapital{public:static bool Configure(int mode){return mode>=0&&mode<=3;}};
class CMarcoIndEntryFilter{public:static void Configure(int){}};
class CMarcoPivotEntry{public:static void Configure(int){}};
class CMarcoSymbolUnits{public:static bool Configure(string value){return value!="invalid";}};
class CMarcoBrokerExecution{public:
 static bool Configure(bool,string){return true;}
 static string Fingerprint(){return replayFingerprint;}
};
#include <cstdio>
using uint=unsigned int;
using color=unsigned int;
enum {PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,PERIOD_M4=4,PERIOD_M5=5,PERIOD_M10=10,PERIOD_M12=12,PERIOD_M15=15,PERIOD_M30=30,PERIOD_H1=16385,
 ACCOUNT_SERVER=200,ACCOUNT_CURRENCY,ACCOUNT_LEVERAGE,CHART_COLOR_BACKGROUND,INDICATOR_SHORTNAME,
 TIME_DATE,TIME_MINUTES,INIT_PARAMETERS_INCORRECT,INIT_FAILED,INIT_SUCCEEDED,REASON_REMOVE,REASON_CHARTCLOSE,REASON_CHARTCHANGE,REASON_PARAMETERS};
const datetime __DATETIME__=424242;
int _Period=PERIOD_M3;
string _Symbol="TEST";
template<class T> string ToString(T v){return std::to_string(v);}
string ToString(const string &s){return s;}
const char* Arg(const string&s){return s.c_str();}
template<class T> T Arg(T v){return v;}
template<class...T> string StringFormat(const char* f,T...args){char b[4096];std::snprintf(b,sizeof b,f,Arg(args)...);return b;}
template<class...T> void Print(T...){}
string AccountInfoString(int p){return p==ACCOUNT_SERVER?"Demo":"USD";}
ulong ChartID(){return 1234;}
ulong GetMicrosecondCount(){static ulong n=0;return ++n;}
template<class T> int ArraySize(const std::vector<T>&v){return int(v.size());}
template<class T> int ArrayResize(std::vector<T>&v,int n){v.resize(n);return n;}
template<class T> int ArrayCopy(std::vector<T>&a,const std::vector<T>&b){a=b;return int(b.size());}
template<class T> uint FileWriteStruct(int f,const T&v){put<T>(f,v);return sizeof(T);}
template<class T> uint FileReadStruct(int f,T&v){if(handles.at(f).offset+sizeof(T)>files.at(handles.at(f).path).size())return 0;v=get<T>(f);return sizeof(T);}
bool FileDelete(const string&p){return files.erase(p)>0;}
string TimeToString(datetime t,int){return std::to_string(t);}
int timers=0;
bool EventSetTimer(int){timers++;return true;}
void EventKillTimer(){timers=0;}
void ClearClusterInstances(){}
void ChartRedraw(){}
color ChartGetInteger(int,int){return 0;}
void IndicatorSetString(int,const string&){}
std::vector<int> drawn;
void ObjectsDeleteAll(int,const string&){drawn.clear();}
string status;
void Status(const string&s){status=s;}
'''

engine=struct(back,'SBacktestGlobalTrade')+'\n'+struct(back,'SSimulatedTrade')+r'''
class CMarcoBacktestInstance {
public:
 static std::vector<SBacktestGlobalTrade> s_global_trades;
 static void ResetGlobalTrades(){s_global_trades.clear();}
 std::vector<SSimulatedTrade> m_trades;
 int m_wins=0,m_losses=0,m_tradeTF=3;
 double m_totalRewards=0;
};
std::vector<SBacktestGlobalTrade> CMarcoBacktestInstance::s_global_trades;
'''
cache=indicator[indicator.index('struct SDrawnBacktestTrade'):indicator.index('// MQL chart rectangles')]
drawing='void DrawTrade(const SDrawnBacktestTrade&t,int){drawn.push_back(t.tf);}\n'
drawing+='\n'.join(function(n) for n in ['MatchesDisplay','DrawAll','CollectTrades','AdvanceScenario','OnInit','OnDeinit'])

cases=r'''
int checks=0;
void check(bool ok){checks++;if(!ok){std::cerr<<"FAIL #"<<checks<<"\n";std::abort();}}
void addScenario(int tf,datetime time){
 CMarcoBacktestInstance instance;instance.m_tradeTF=tf;instance.m_wins=1;instance.m_totalRewards=1;
 SSimulatedTrade t{};t.symbol=_Symbol;t.setupType="setup";t.outcome="WIN";t.ticket=6000000000ULL+time;
 t.direction=1;t.openTime=time;t.closeTime=time+60;t.openPrice=100;t.slPrice=100;t.tpPrice=110;t.closePrice=110;
 t.lots=4;t.realizedProfit=40;
 CMarcoStagedTP::Build(t.tpPlan,true,100,90,120,130,1,0,0,.01,2);
 CMarcoStagedTP::Exit(t.tpPlan,2,.25,110,time+10);
 CMarcoStagedTP::StructureExit(t.tpPlan,false,.375,115,time+20,4,.01,.01);
 CMarcoStagedTP::Extend(t.tpPlan,1,1,.01,2,time+30);
 CMarcoStagedTP::TightenStop(t.tpPlan,102);
 instance.m_trades.push_back(t);CollectTrades(&instance);
 SBacktestGlobalTrade overlap{};overlap.symbol=_Symbol;overlap.openTime=time;overlap.openPrice=100;overlap.tpPrice=110;overlap.direction=1;
 CMarcoBacktestInstance::s_global_trades.push_back(overlap);
 AdvanceScenario(false);
}
int main(){
 const int scenarios=ArraySize(g_setupTFs);
 _Period=g_setupTFs[0];
 InpAllSetupTFs=false;InpSetupTF=PERIOD_CURRENT;
 check(OnInit()==INIT_SUCCEEDED);check(timers==1);check(g_windowEnd==1000);check(g_simulationVicinityTF==g_setupTFs[0]);
 string originalKey=g_cacheKey, originalPath=g_cachePath;
 addScenario(g_setupTFs[0],200);addScenario(g_setupTFs[1],300);
 check(g_trades.size()==2);check(g_nextTF==2);check(CMarcoBacktestInstance::s_global_trades.size()==2);
 // Indicator globals can disappear entirely on reinitialization. Disk must restore them.
 OnDeinit(REASON_CHARTCHANGE);g_trades.clear();g_nextTF=0;g_windowEnd=0;g_rewards=0;
 _Period=g_setupTFs[1];clockNow=1100;
 check(OnInit()==INIT_SUCCEEDED);check(g_nextTF==0);check(g_trades.empty());check(timers==1);
 check(g_simulationVicinityTF==g_setupTFs[0]);check(g_cacheKey==originalKey);check(g_windowEnd==1000);
 check(CMarcoBacktestInstance::s_global_trades.empty());check(drawn.empty());
 // Finish the remaining configured TFs exactly once. All records survive a display cap of two.
 for(int i=0;i<scenarios;i++) addScenario(g_setupTFs[i],200+i*100);
 check(g_finished);check(g_nextTF==scenarios);check(g_trades.size()==scenarios);check(g_totalTrades==scenarios);
 check(g_trades[0].ticket==6000000200ULL);check(g_trades[0].plan.closed[2]==.25);
 OnDeinit(REASON_CHARTCHANGE);g_trades.clear();g_finished=false;g_nextTF=0;
 _Period=g_setupTFs[0];check(OnInit()==INIT_SUCCEEDED);check(timers==0);check(g_finished);check(g_nextTF==scenarios);
 check(g_trades.size()==scenarios);check(drawn.size()==1&&drawn[0]==g_setupTFs[0]);check(g_wins==scenarios&&g_rewards==scenarios);
 check(g_trades[0].plan.structureClosed[0]==.375);check(g_trades[0].plan.structurePrice[0]==115);
 check(g_trades[0].plan.structureTime[0]==220);
 check(g_trades[0].plan.extensionCount==1);check(g_trades[0].plan.extensionTime==230);
 check(g_trades[0].plan.protectedSL==102);check(g_trades[0].plan.price[1]==140);
 // Display changes reload the same snapshot; no timer/engine restart and no truncation.
 OnDeinit(REASON_PARAMETERS);InpAllSetupTFs=true;check(OnInit()==INIT_SUCCEEDED);
 check(timers==0);check(g_trades.size()==scenarios);check(drawn.size()==2&&drawn[0]==g_setupTFs[scenarios-2]&&drawn[1]==g_setupTFs[scenarios-1]);
 OnDeinit(REASON_PARAMETERS);InpMaxTrades=10;check(OnInit()==INIT_SUCCEEDED);check(drawn.size()==scenarios);
 // A different strategy must not restore the old result.
 OnDeinit(REASON_PARAMETERS);InpDeviation=.002;check(OnInit()==INIT_SUCCEEDED);
 check(g_cacheKey!=originalKey);check(g_nextTF==0);check(g_trades.empty());check(timers==1);
 OnDeinit(REASON_PARAMETERS);InpDeviation=.001;check(OnInit()==INIT_SUCCEEDED);check(g_finished);
 // Different symbol and account/strategy identity never share results.
 OnDeinit(REASON_CHARTCHANGE);_Symbol="OTHER";check(OnInit()==INIT_SUCCEEDED);check(g_trades.empty());check(!g_finished);
 OnDeinit(REASON_CHARTCHANGE);_Symbol="TEST";check(OnInit()==INIT_SUCCEEDED);check(g_finished);
 // A mismatched key and truncated record/footer must fail without exposing partial results.
 string goodKey=g_cacheKey;g_cacheKey+="changed";check(!LoadSimulationCache());g_cacheKey=goodKey;
 auto goodFile=files.at(originalPath);files[originalPath].pop_back();check(!LoadSimulationCache());
 files[originalPath]=goodFile;files[originalPath].resize(5);check(!LoadSimulationCache());files[originalPath]=goodFile;
 // Results using the old US500 pip definition must not be restored.
 int32_t oldVersion=8;std::memcpy(files[originalPath].data()+sizeof(int32_t),&oldVersion,sizeof(oldVersion));
 check(!LoadSimulationCache());files[originalPath]=goodFile;
 check(LoadSimulationCache());check(g_trades.size()==scenarios);
 // A newly recorded broker decision invalidates old results, but unchanged
 // decisions retain the existing timeframe-switch caching behavior above.
 replayFingerprint="new rejection";check(SimulationCacheKey()!=goodKey);replayFingerprint="initial";
 int originalTF=g_setupTFs[0];g_setupTFs[0]=PERIOD_M1;check(SimulationCacheKey()!=goodKey);g_setupTFs[0]=originalTF;
 int originalCapital=InpRiskCapital;InpRiskCapital=(originalCapital+1)%4;check(SimulationCacheKey()!=goodKey);InpRiskCapital=originalCapital;
 int originalIndMode=InpM1IndEntryFilter;InpM1IndEntryFilter=0;check(SimulationCacheKey()!=goodKey);InpM1IndEntryFilter=originalIndMode;
 int originalTiming=InpEntryTiming;InpEntryTiming=1-originalTiming;check(SimulationCacheKey()!=goodKey);InpEntryTiming=originalTiming;
 InpPipSizeOverrides="US500=1";check(SimulationCacheKey()!=goodKey);InpPipSizeOverrides="";
 InpPipSizeOverrides="invalid";check(OnInit()==INIT_PARAMETERS_INCORRECT);InpPipSizeOverrides="";
 // Explicit removal clears the active cache and allows a fresh run on reattachment.
 OnDeinit(REASON_REMOVE);check(!files.count(originalPath));check(OnInit()==INIT_SUCCEEDED);check(g_nextTF==0&&timers==1);
 // EndWindow=0 keeps the original snapshot, rather than moving forward at each TF switch.
 InpEndWindow=0;clockNow=2000;check(OnInit()==INIT_SUCCEEDED);check(g_windowEnd==2000);
 OnDeinit(REASON_CHARTCHANGE);clockNow=3000;_Period=15;check(OnInit()==INIT_SUCCEEDED);check(g_windowEnd==2000);
 std::cout<<"PASS: "<<checks<<" cache/lifecycle checks; all-TF records, unfinished batch restart, overlap, filters, invalidation and corruption\n";
}
'''
source='\n'.join([mock,adapters,'\n'.join(inputs),adapt(policy),adapt(engine),adapt(cache),adapt(drawing),cases])
compiler=shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
with tempfile.TemporaryDirectory(prefix='marco_indicator_cache_tests_') as directory:
    cpp,exe=Path(directory)/'cache.cpp',Path(directory)/'cache.exe'
    cpp.write_text(source,encoding='utf-8')
    subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
