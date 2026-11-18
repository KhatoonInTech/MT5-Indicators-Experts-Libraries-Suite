"""Exercise the visualizer's actual warmup selector without terminal/broker access."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
text = (ROOT/'Indicators/Custom/Marcotrades/liquiduity_block.mq5').read_text(encoding='utf-8-sig')
helper = (ROOT/'Include/Custom/Marcotrades/history_context.mqh').read_text(encoding='utf-8-sig')
start = text.index('int WindowBarCount(')
selector_start = text.index('bool ResolveWarmupStart(', start)
opening = text.index('{', selector_start)
end = opening + 1
depth = 1
while depth:
    depth += (text[end] == '{') - (text[end] == '}')
    end += 1
selector = text[start:end]
source = helper + selector
source = re.sub(r'const datetime &(\w+)\[\]', r'const std::vector<datetime> &\1', source)
source = re.sub(r'MqlRates (\w+)\[\];', r'std::vector<MqlRates> \1;', source)
calc = text[text.index('int OnCalculate(', end):]
assert calc.index('ResolveWarmupStart(') < calc.index('ResetState();') < calc.index('ReinitEngines();')
assert 'prev_calculated==0 || prev_calculated>rates_total || anchor_moved' in calc
assert '86400' not in calc
assert 'start=start_bar;' in calc and 'for(int i = start; i < window_count; i++)' in calc
assert 'ResolveWarmupStart(window_count,time,' in calc
assert calc.index('ClosedByWindowEnd(time[i],endTime,PeriodSeconds())') < calc.index('zigZag.update(')
assert 'if(InpEndTime>0) extend_right=(datetime)MathMin(extend_right,endTime);' in calc
assert '(InpEndTime==0 || InpEndTime>now) ? now : InpEndTime' in calc
assert 'ArraySetAsSeries(time,false)' in calc

# Display-mode integration: entry readiness is latched during chronological
# replay, entry-only rendering excludes guard-only sources, and raw/all modes
# include the exact exit-source registry consumed by the trade engines.
assert 'enum ENUM_LB_DISPLAY_MODE' in text
for option in ('LB_DISPLAY_RAW_PREVENTION_EXITS','LB_DISPLAY_ENTRY_SETUP_ONLY','LB_DISPLAY_ALL'):
    assert option in text
assert 'input ENUM_LB_DISPLAY_MODE InpLBDisplayMode' in text
assert calc.index('lbLogic.Process(') < calc.index('TrackEntrySetupLBs(time[i]);')
assert 'EntryTriggerStructureTime(lb.isBullish,lb.triggerType' in text
assert 'g_entry_lb_states[index].armedTime=cutoff' in text
assert 'lbLogic.m_exit_sources.Total()' in calc
render_start=text.index('bool ShouldRenderLiquidityBlock(')
render_end=text.index('void RenderLiquidityBlock(',render_start)
render_policy=text[render_start:render_end]
assert 'entryEligible && !exitOnly' in render_policy
assert 'InpApplyEntryLBPolicyToPreventionExits' in render_policy
assert 'preventionExitEligible' in render_policy
assert '[ENTRY+RAW]' not in text
assert 'IsEntrySetupLB(containingLB.id)' in calc

mock = r'''
#include <vector>
#include <string>
#include <algorithm>
#include <iostream>
#include <cstdlib>
using datetime=long long;using string=std::string;
struct MqlRates{datetime time;};
int checks=0;
void checked(bool value,int line){++checks;if(!value){std::cerr<<"failed at "<<line;std::exit(1);}}
#define check(x) checked((x),__LINE__)
int MathMax(int a,int b){return std::max(a,b);}
const int PERIOD_M1=1,SERIES_SYNCHRONIZED=1;
string _Symbol="TEST";int _Period=1;
bool InpUseAnchorSlider=true;int InpMaxLookbackBars=3,InpDepth=1;
datetime g_anchor_time=0;
std::vector<datetime> m1History,tfHistory;
bool m1Synced=true,tfSynced=true;
int copyError=0;
datetime requestedStart=0,requestedEnd=0;
bool SeriesInfoInteger(string,int tf,int){return tf==PERIOD_M1?m1Synced:tfSynced;}
int CopyRates(string,int,datetime end,int count,std::vector<MqlRates>&out){
 out.clear();if(copyError)return -1;check(count==1);
 for(auto t:m1History)if(t<=end && (out.empty()||t>out[0].time))out={{t}};
 return out.size();
}
int CopyRates(string,int,datetime start,datetime end,std::vector<MqlRates>&out){
 requestedStart=start;requestedEnd=end;out.clear();if(copyError)return -1;
 for(auto t:tfHistory)if(t>=start&&t<=end)out.push_back({t});return out.size();
}
'''
main = r'''
int main(){
 const datetime day=1794528000;
 for(int tf:{1,2,3,4,5,10,12,15,30,60}){
  _Period=tf;int step=tf*60;g_anchor_time=day;m1History={day-60};
  tfHistory={day-86400+step,day-86400+2*step,day-step,day,day+step,day+2*step};
  std::vector<datetime> chart={day-2*86400};chart.insert(chart.end(),tfHistory.begin(),tfHistory.end());
  int bar=-1;datetime context=0,history=0;
  check(ResolveWarmupStart(chart.size(),chart,bar,context,history));
  check(bar==1&&context==day&&history==day-86400);
  check(requestedStart==day-86400&&requestedEnd==day);
  // Historical endpoint: the boundary bar is available but its final OHLC is
  // not. Later chart bars must neither qualify nor mitigate a historical zone.
  check(WindowBarCount(chart.size(),chart,day+step)==6);
  check(WindowBarCount(chart.size(),chart,day+step-1)==5);
  check(WindowBarCount(chart.size(),chart,day+3*step)==int(chart.size()));
  check(WindowBarCount(0,chart,day)==0);
  check(WindowBarCount(chart.size(),chart,day-4*86400)==0);
  check(ClosedByWindowEnd(day,day+step,step));
  check(!ClosedByWindowEnd(day,day+step-1,step));
  check(!ClosedByWindowEnd(day+step,day+step,step));
  check(!ClosedByWindowEnd(day,day+step,0));
  InpUseAnchorSlider=false;InpMaxLookbackBars=2;
  int windowCount=WindowBarCount(chart.size(),chart,day+step);
  check(ResolveWarmupStart(windowCount,chart,bar,context,history));
  check(context==day); // Relative to cutoff, not the newest chart bar.
  InpUseAnchorSlider=true;InpMaxLookbackBars=3;
  g_anchor_time=day+step;
  check(ResolveWarmupStart(chart.size(),chart,bar,context,history)&&bar==1&&history==day-86400);
  // Missing chart history must not silently begin at the anchor/current day.
  std::vector<datetime> incomplete={day,day+step};
  check(!ResolveWarmupStart(incomplete.size(),incomplete,bar,context,history));
  std::vector<datetime> partial={day-step,day,day+step};
  check(!ResolveWarmupStart(partial.size(),partial,bar,context,history));
  InpUseAnchorSlider=false;
  check(ResolveWarmupStart(chart.size(),chart,bar,context,history));
  check(context==day&&bar==1&&history==day-86400);InpUseAnchorSlider=true;
  // Previous trading day across weekend; use that day's opening candle on this TF.
  m1History={day-2*86400-60};tfHistory={day-3*86400+step,day-step,day,day+step};chart=tfHistory;
  g_anchor_time=day;
  check(ResolveWarmupStart(chart.size(),chart,bar,context,history)&&history==day-3*86400&&bar==0);
  copyError=-1;check(!ResolveWarmupStart(chart.size(),chart,bar,context,history));copyError=0;
  m1Synced=false;check(!ResolveWarmupStart(chart.size(),chart,bar,context,history));m1Synced=true;
  if(tf!=1){tfSynced=false;check(!ResolveWarmupStart(chart.size(),chart,bar,context,history));tfSynced=true;}
  g_anchor_time=day+86400;check(!ResolveWarmupStart(chart.size(),chart,bar,context,history));
  g_anchor_time=day;m1History.clear();check(!ResolveWarmupStart(chart.size(),chart,bar,context,history));
  check(!ResolveWarmupStart(0,chart,bar,context,history));
  std::cout<<"TF "<<tf<<": anchor, intraday anchor, lookback, weekend and missing history passed\n";
 }
 std::cout<<checks<<" liquidity warmup assertions passed; midnight reset/integration guards passed\n";
}
'''
out = ROOT/'Tests/Marcotrades/_review'
cpp, exe = out/'liquidity_warmup.cpp', out/'liquidity_warmup.exe'
cpp.write_text(mock+source+main, encoding='utf-8')
result = subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:
    raise SystemExit(result.stderr)
result = subprocess.run([str(exe)],capture_output=True,text=True)
(out/'liquidity_warmup_results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout,end='')
if result.returncode:
    raise SystemExit(result.stderr)
