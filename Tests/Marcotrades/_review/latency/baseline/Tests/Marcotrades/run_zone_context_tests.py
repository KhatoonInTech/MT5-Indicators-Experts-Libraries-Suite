"""Run production LB registration with different host-chart price precisions."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
lb = (root/'Include/Custom/Marcotrades/liquidity_blocks.mqh').read_text(encoding='utf-8-sig')
policy = (root/'Include/Custom/Marcotrades/trade_rejection.mqh').read_text(encoding='utf-8-sig')
policy = policy[policy.index('enum ENUM_TRADE_REJECTION_ACTION'):policy.index('// Immutable versions')]

def method(source, name):
    start = re.search(r'   (?:void|bool)\s+'+name+r'\(', source).start()
    opening = source.index('{', start)
    end, depth = opening+1, 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

methods = '\n'.join(method(lb, n) for n in ('Init', 'IsLBRegistered', 'RecordExitSource', 'RegisterLiquidityBlock'))
for pointer in ('indLogic', 'iz', 'exist', 'lb', 'known', 'source'):
    methods = methods.replace(pointer+'.', pointer+'->')
methods = methods.replace('"LB_" +', 'string("LB_") +')
methods = methods.replace('"EXIT_ONLY_LB_"+', 'string("EXIT_ONLY_LB_")+')
enum = lb[lb.index('enum ENUM_LB_TRIGGER'):lb.index('//+------------------------------------------------------------------+', lb.index('enum ENUM_LB_TRIGGER'))]
mock = (root/'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()
mock += r'''
using uint=unsigned int;
enum {PERIOD_CURRENT=0,PERIOD_M1=1,POINTER_DYNAMIC=1};
double _Point=.001;
template<class T> int CheckPointer(T*p){return p?POINTER_DYNAMIC:0;}
template<class T> int ArraySize(const std::vector<T>& v){return int(v.size());}
struct CObject {virtual ~CObject()=default;};
struct CArrayObj {std::vector<CObject*> v;int Total(){return int(v.size());}
 CObject* At(int i){return v.at(i);}void Add(CObject*p){v.push_back(p);}
 ~CArrayObj(){for(auto p:v)delete p;}};
struct CArrayString {std::vector<string> v;int Total(){return int(v.size());}
 string At(int i){return v.at(i);}void Add(string s){v.push_back(s);}};
struct CInducementZone: CObject {bool isInducement=true,isBullish=true;
 double zoneLow=99,zoneHigh=100;datetime createdTime=10,inducementTime=20,mitigationTime=0;};
struct CInducementLogic {CArrayObj m_zones;};
'''
mock += enum + r'''
struct CLiquidityBlock: CObject {string id;bool isBullish;ENUM_LB_TRIGGER triggerType;
 double zoneHigh,zoneLow;datetime createdTime,sweepLineTime=0,inducementOriginTime=0,causalChochTime=0;
 int createdBarIndex;};
'''
mock += policy + r'''
class Engine {public:
 datetime m_zoneStartTime=0;double m_symbolPoint=0;bool m_trackSweepsAnywhere,m_trackPostInducementCHoCH;
 CArrayObj m_liquidity_blocks,m_exit_sources;CArrayString m_registered_lb_keys;
'''+methods+r'''
};
int checks=0;void check(bool ok){checks++;if(!ok){std::cerr<<"FAIL "<<checks<<"\n";std::abort();}}
int count(double host,double target){
 _Point=host;Engine e;e.Init(true,true,target);
 e.RegisterLiquidityBlock(true,LB_TRIGGER_BL_IND,100,99,1000,0,0,nullptr);
 e.RegisterLiquidityBlock(true,LB_TRIGGER_BL_IND,100.05,99.05,2000,1,0,nullptr);
 return e.m_liquidity_blocks.Total();
}
int main(){
 for(double host:{.00001,.001,.01,.1,1.0}){
  check(count(host,.1)==1); // US30 behavior independent of the chart running the EA.
  check(count(host,.001)==2); // Gold precision must not inherit the US30 chart's point.
 }
 // Same source pivot still merges, and opposite directions remain separate.
 Engine e;e.Init(true,true,.1);
 e.RegisterLiquidityBlock(true,LB_TRIGGER_BL_IND,100,99,1000,0,0,nullptr);
 e.RegisterLiquidityBlock(true,LB_TRIGGER_BL_BSL,103,98,1000,0,10,nullptr,0,20);
 check(e.m_liquidity_blocks.Total()==1);
 auto zone=(CLiquidityBlock*)e.m_liquidity_blocks.At(0);
 check(zone->triggerType==LB_TRIGGER_BL_IND_BSL && zone->causalChochTime==20);
 e.RegisterLiquidityBlock(false,LB_TRIGGER_BR_IND,100,99,1000,0,0,nullptr);
 check(e.m_liquidity_blocks.Total()==2);
 // The existing active-IND exclusion is preserved.
 CInducementLogic ind;ind.m_zones.Add(new CInducementZone());
 Engine blocked;blocked.Init(true,true,.1);
 blocked.RegisterLiquidityBlock(true,LB_TRIGGER_BL_IND,100,99,1000,0,0,&ind);
 check(blocked.m_liquidity_blocks.Total()==0);
 check(blocked.m_exit_sources.Total()==0); // No causal CHoCH: do not manufacture one.
 for(bool bull:{false,true}){
  auto iz=(CInducementZone*)ind.m_zones.At(0);iz->isBullish=bull;
  Engine guard;guard.Init(true,true,.1);
  for(int repeat=0;repeat<2;repeat++)
   guard.RegisterLiquidityBlock(bull,bull?LB_TRIGGER_BL_BSL:LB_TRIGGER_BR_SSL,100,99,1000,0,100,&ind,0,1100);
  check(guard.m_liquidity_blocks.Total()==0); // Entry remains rejected.
  check(guard.m_exit_sources.Total()==1); // Deduplicated source retained for exits.
  auto source=(CLiquidityBlock*)guard.m_exit_sources.At(0);
  check(source->isBullish==bull&&source->causalChochTime==1100&&source->createdTime==1000);
 }
 std::cout<<"PASS: "<<checks<<" production LB context checks\n";
}
'''
for name in ('marco_backtest', 'marco_live_auto'):
    engine = (root/f'Include/Custom/Marcotrades/{name}.mqh').read_text(encoding='utf-8-sig')
    assert 'lbs.Init(sweeps, postInd, symbolPoint);' in engine
    for detector in ('lbLogicHtf','lbLogicLtf'):
        call = re.search(detector+r'\.Init\(([^;]+)\);', engine).group(1)
        assert 'symbolUnits.point' in call or 'SymbolInfoDouble(m_symbol,SYMBOL_POINT)' in call
    assert 'all_event_origin_times.At(e)' in engine
market = (root/'Include/Custom/ZigZag/market_structure.mqh').read_text(encoding='utf-8-sig')
sweep = market[market.index('GetSweepExtremePivotTime('):market.index('get_swing_color()')]
assert 'ObjectFind(' not in sweep and 'ObjectGetInteger(' not in sweep
visual = (root/'Indicators/Custom/Marcotrades/liquiduity_block.mq5').read_text(encoding='utf-8-sig')
assert 'CMarcoSymbolUnits::PipSize(_Symbol)' in visual
assert 'CMarcoSymbolUnits::Configure(InpPipSizeOverrides)' in visual
with tempfile.TemporaryDirectory(prefix='marco_zone_context_') as directory:
    cpp, exe = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    cpp.write_text(mock, encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
