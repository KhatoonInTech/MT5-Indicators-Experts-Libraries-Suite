"""Execute the shared MQL entry-timing policy in a candle/quote adapter; no orders."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root/'Include/Custom/Marcotrades/pivot_entry.mqh').read_text(encoding='utf-8-sig')
source = source.replace('MqlRates source[], confirmation[];',
                        'std::vector<MqlRates> source, confirmation;')
mock = r'''
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <cmath>
using string=std::string; using datetime=long long; using ENUM_TIMEFRAMES=int;
enum {TIME_DATE=1,TIME_SECONDS=2};
struct MqlRates {datetime time;double open,high,low,close;};
std::vector<MqlRates> candles;
int reads=0;
int PeriodSeconds(int tf){return tf*60;}
int iBarShift(string,int tf,datetime t,bool exact){
 for(int i=0;i<(int)candles.size();++i)
  if(exact ? candles[i].time==t : candles[i].time<=t && t<candles[i].time+tf*60)return i;
 return -1;
}
int CopyRates(string,int,int index,int,std::vector<MqlRates>&v){
 ++reads;if(index<0||index>=(int)candles.size())return 0;v={candles[index]};return 1;
}
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
double MathAbs(double x){return std::abs(x);}
double MathFloor(double x){return std::floor(x);}
double MathCeil(double x){return std::ceil(x);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
double NormalizeDouble(double x,int n){double s=std::pow(10.,n);return std::round(x*s)/s;}
template<class T>void ZeroMemory(T &v){v=T{};}
string EnumToString(int x){return std::to_string(x);}
string TimeToString(datetime x,int){return std::to_string(x);}
template<class...T>void PrintFormat(T...){}
int checks=0;
#define CHECK(x) do{++checks;if(!(x)){std::cerr<<"Failed line "<<__LINE__<<": "<<#x<<"\n";std::exit(1);}}while(0)
'''
tests = r'''
int main(){
 SMarcoPivotEntry state{};
 CMarcoPivotEntry::Configure(ENTRY_AFTER_CONFIRMATION);
 CHECK(!CMarcoPivotEntry::Enabled());
 CHECK(CMarcoPivotEntry::Prepare(state,"S",1,true,0,0,0));
 CHECK(CMarcoPivotEntry::Quote(state,true,0));
 double fill,hi,lo;bool intra;
 CHECK(CMarcoPivotEntry::Bar(state,true,100,110,90,105,fill,intra,hi,lo));
 CHECK(fill==100&&!intra&&hi==110&&lo==90);
 CMarcoPivotEntry::Configure(ENTRY_PIVOT_CANDLE_EDGE);
 for(int tf : {1,3,5,60})for(bool buy : {false,true}){
  datetime pivot=100*tf*60,confirmed=pivot+2*tf*60;
  double edge=buy?110:90;
  candles={{pivot,100,110,90,100},{pivot+tf*60,100,112,88,100}};
  state={};reads=0;
  CHECK(!CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed,confirmed-1));
  CHECK(reads==0);
  CHECK(CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed,confirmed));
  CHECK(state.level==edge&&!state.nextOpen&&CMarcoPivotEntry::Waiting(state));
  CHECK(reads==2);
  // Crossing by wick alone must not activate the close-based fallback.
  CHECK(!CMarcoPivotEntry::Quote(state,buy,100));
  CHECK(CMarcoPivotEntry::Quote(state,buy,edge));
  CHECK(CMarcoPivotEntry::Quote(state,buy,buy?111:89));
  CHECK(CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed,confirmed+3600));
  CHECK(reads==2); // cached per pivot, no repeated history fetch
  CHECK(!CMarcoPivotEntry::Bar(state,buy,100,109,91,100,fill,intra,hi,lo));
  CHECK(CMarcoPivotEntry::Bar(state,buy,100,115,85,100,fill,intra,hi,lo));
  CHECK(intra&&fill==edge);
  CHECK(buy ? hi==115&&lo==100 : hi==115&&lo==85);
  CHECK(CMarcoPivotEntry::Bar(state,buy,100,115,85,99,fill,intra,hi,lo));
  CHECK(buy ? hi==115&&lo==85 : hi==99&&lo==85);
  CHECK(CMarcoPivotEntry::Bar(state,buy,buy?113:87,115,85,100,fill,intra,hi,lo));
  CHECK(!intra&&fill==(buy?113:87)); // gap fills at available open, never stale level
  for(double close : {edge,buy?112.:88.}){
   state={};candles[1].close=close;
   CHECK(CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed,confirmed));
   CHECK(state.nextOpen&&!CMarcoPivotEntry::Waiting(state));
   CHECK(CMarcoPivotEntry::Bar(state,buy,100,108,92,100,fill,intra,hi,lo));
   CHECK(fill==100&&!intra); // next-open fallback even if price gaps back
  }
  state={};
  CHECK(!CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot+1,confirmed,confirmed));
  CHECK(!CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed-1,confirmed));
  candles.clear();
  CHECK(!CMarcoPivotEntry::Prepare(state,"S",tf,buy,pivot,confirmed,confirmed));
 }
 // Exercise the real staged-exit policy on the clipped first-candle segment.
 // An adverse wick before entry cannot stop a position that did not yet exist.
 for(bool buy : {false,true})for(bool adverseAfter : {false,true}){
  state={60,120,100,false};
  double open=buy?99:101;
  double close=buy?(adverseAfter?98:101):(adverseAfter?102:99);
  CHECK(CMarcoPivotEntry::Bar(state,buy,open,105,95,close,fill,intra,hi,lo));
  CHECK(intra&&fill==100);
  SMarcoTPPlan plan{};double lastExit=0;
  CHECK(CMarcoStagedTP::Build(plan,buy,fill,buy?98:102,0,0,10,2,0,.01,2));
  CMarcoStagedTP::Bar(plan,180,fill,hi,lo,close,false,0,false,0,lastExit);
  CHECK(adverseAfter ? plan.remaining==0&&plan.realizedR==-1 : plan.remaining==1&&plan.realizedR==0);
 }
 std::cout<<checks<<" pivot-entry and first-candle exit checks passed\n";
}
'''
compiler = shutil.which('g++')
assert compiler, 'g++ required'
with tempfile.TemporaryDirectory() as d:
    cpp, exe = Path(d)/'pivot_entry.cpp', Path(d)/'pivot_entry.exe'
    staged=(root/'Include/Custom/Marcotrades/staged_tp.mqh').read_text(encoding='utf-8-sig')
    cpp.write_text(mock+source+staged+tests)
    subprocess.run([compiler,'-std=c++17',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)

# The three clients must configure the same shared policy; cache varies by mode.
for path in ('Experts/Custom EAs/Marcotrades/marco_live_auto_ea.mq5',
             'Experts/Custom EAs/Backtesting/marco_backtest_ea.mq5',
             'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5'):
    text=(root/path).read_text(encoding='utf-8-sig')
    # Users may choose different defaults in individual clients; both enum
    # values must still route through the same execution policy.
    assert any('InpEntryTiming = '+mode in text for mode in
               ('ENTRY_AFTER_CONFIRMATION','ENTRY_PIVOT_CANDLE_EDGE'))
    assert 'CMarcoPivotEntry::Configure(InpEntryTiming);' in text
indicator=(root/'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5').read_text(encoding='utf-8-sig')
assert 'key+="|InpEntryTiming="+(string)InpEntryTiming;' in indicator
snapshot=root/'Tests/Marcotrades/_review/pivot_entry_zigzag.sha256'
if snapshot.exists():
    assert hashlib.sha256((root/'Include/Custom/ZigZag/ZigZag.mqh').read_bytes()).hexdigest()==snapshot.read_text()
print('Three-client configuration, cache key and unchanged ZigZag verified')
