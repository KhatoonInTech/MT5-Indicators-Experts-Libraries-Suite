"""Offline production-code regression: prior-day warmup and midnight continuity.

Uses the existing MQL-to-C++ adapter, real ZigZag/market-structure code, and
extracted production history/rollover methods. No terminal or broker connection.
"""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
adapter = ROOT / 'Tests/Marcotrades/replay_us30_context.py'
env = {'__file__': str(adapter)}
exec(compile(adapter.read_text().split("main = r'''", 1)[0], str(adapter), 'exec'), env)
live = (ROOT/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
back = (ROOT/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig').replace("m_sim.", "")
indicator = (ROOT/'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5').read_text(encoding='utf-8-sig')
helper = (ROOT/'Include/Custom/Marcotrades/history_context.mqh').read_text(encoding='utf-8-sig')
helper = helper.replace('MqlRates previous[];', 'std::vector<MqlRates> previous;')

def method(text, name):
    start = re.search(r'^\s*void\s+'+name+r'\(', text, re.M).start()
    opening = text.index('{', start)
    depth, end = 1, opening+1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

rollover = method(live, 'CheckDailyRollover')
journal = method(live, 'LoadDailyJournal')
prune_start = journal.index('      for(int i = 0; i < m_total_instances; i++)')
prune_end = journal.index('      if(!FileIsExist(filePath))', prune_start)
prune = journal[prune_start:prune_end]
for forbidden in ['ResetAndSync', 'CleanupEngines', 'WipeDaily', 'delete ', 'ArrayResize']:
    assert forbidden not in rollover, forbidden
assert live.count('ResetAndSync(') == 2  # declaration and initial attachment only
assert 'WipeDailyEnginesAndVisuals' not in live
assert 'm_last_entry_bar + 1 : m_historyStart' in live
assert 'm_last_htf_bar + 1 : m_historyStart' in live
assert 'm_last_ltf_bar + 1 : m_historyStart' in live
assert 'ResolveStart(m_symbol,m_startWindow,startTime)' in back
gate = back.index('if(!CMarcoHistoryContext::TradingWindow(run_time[i],m_startWindow)) continue;')
assert back.rfind('FeedM1EntryBar(', 0, gate) > back.index('for(int i=nextBar;i<run_copy;i++)')
assert gate < back.index('ResolveClosedBar(run_time[closed_i]')
for tf in ['m_tradeTF', 'm_tpTF']:
    assert f'CopyTime(m_symbol, {tf}, startTime, endTime' in back
assert 'CopyRates(m_symbol, PERIOD_M1, startTime, endTime' in back
assert 'CopyRates(_Symbol, tf, historyStart, g_windowEnd' in indicator
assert 'HasPriorContext(rates[0].time,InpStartWindow)' in indicator

mock = env['mock'].replace('datetime TimeCurrent(){return 1794528000;}',
                          'datetime testNow=1794528000; datetime TimeCurrent(){return testNow;}')
extra = r'''
int checks=0;
void checked(bool ok,int line){++checks;if(!ok){std::cerr<<"Check failed at generated line "<<line<<"\n";std::abort();}}
#define check(ok) checked((ok),__LINE__)
struct MqlRates{datetime time;double open,high,low,close;};
std::vector<MqlRates> available;
bool synchronized=true;int forcedCopy=1;datetime requestedEnd=0;
const int SERIES_SYNCHRONIZED=900;
bool SeriesInfoInteger(string,int,int){return synchronized;}
int CopyRates(string,int,datetime end,int count,std::vector<MqlRates>&result){
 requestedEnd=end;check(count==1);result.clear();
 if(forcedCopy<0)return forcedCopy;
 for(auto r:available)if(r.time<=end && (result.empty()||r.time>result[0].time))result={r};
 return int(result.size());
}
'''
roll_class = r'''
struct Rollover {
 datetime m_current_day_start=0;bool m_daily_report_sent=false;
 int reports=0,journals=0;
 datetime GetDailyReportTime(datetime day){return day+86399;}
 void GenerateDailyReport(datetime day,datetime end){check(end==day+86399);++reports;}
 void LoadDailyJournal(datetime day,bool preserveOpen){check(day==m_current_day_start&&preserveOpen);++journals;}
''' + rollover + '\n};\n'
journal_class = r'''
struct JournalTrade{int positionId;bool isOpen;double lots,stop;int partialState;};
struct JournalInstance{
 std::vector<JournalTrade> m_trades;CArrayString m_taken_setups;
 void RefreshTradeHistory(int i){if(m_trades[i].positionId==3)m_trades[i].isOpen=false;}
};
struct Journal{
 JournalInstance m_instances[2];int m_total_instances=2;
 void prepare(bool preserveOpen){
''' + prune + '\n}\n};\n'
main = r'''
struct Core {
 ZigZag *zz;CMarketStructure ms;
 std::vector<datetime> times;std::vector<double> highs,lows,closes;
 Core(int tf){auto s=new Settings(.001,1,0,true,false,false,false,"Absolute");s->draw=false;
  zz=newInstance(s);ms.Init(false,false,tf);}
 ~Core(){delete zz;}
 void feed(const MqlRates&r){int i=times.size();times.push_back(r.time);highs.push_back(r.high);
  lows.push_back(r.low);closes.push_back(r.close);
  zz->update(r.high,r.low,r.time,100,i,true,false);ms.Update(i,times,highs,lows,closes,zz);}
 string state(){std::ostringstream out;out<<std::setprecision(17);
  out<<ms.trend<<' '<<ms.last_breakout_time<<' '<<ms.target_level_price<<' '<<ms.target_level_time
     <<' '<<ms.protected_level_price<<' '<<ms.protected_level_time<<' '<<ms.ev1_name;
  for(int i=0;i<zz->pivots->Total();++i){auto p=(Pivot*)zz->pivots->At(i);
   out<<' '<<p->isHigh<<' '<<p->end->time<<' '<<p->end->price;}
  return out.str();}
};
int main(){
 const datetime day=1794528000;datetime start=-1;
 available={{day-60}};
 check(CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==day-86400);
 check(requestedEnd==day-1);
 check(CMarcoHistoryContext::ResolveStart("TEST",day+43200,start)&&start==day-86400);
 available={{day-2*86400-60}}; // previous available trading day across a weekend
 check(CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==day-3*86400);
 available.clear();check(!CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==0);
 available={{day+60}};check(!CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==0);
 available={{day-60}};synchronized=false;
 check(!CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==0);synchronized=true;
 forcedCopy=-1;check(!CMarcoHistoryContext::ResolveStart("TEST",day,start)&&start==0);forcedCopy=1;
 check(!CMarcoHistoryContext::ResolveStart("TEST",0,start));
 check(CMarcoHistoryContext::HasPriorContext(day-86400+3600,day+36000));
 check(!CMarcoHistoryContext::HasPriorContext(day,day+36000));
 check(!CMarcoHistoryContext::HasPriorContext(0,day));
 check(!CMarcoHistoryContext::TradingWindow(day-1,day));
 check(CMarcoHistoryContext::TradingWindow(day,day));
 check(!CMarcoHistoryContext::TradingWindow(day+3600,day+3601));

 // Deterministic OHLC fixture: two days, multiple reversals, aggregated independently
 // for each configured TF. Compare midnight rollover with uninterrupted execution.
 std::vector<MqlRates> minutes;
 for(int i=0;i<2880;++i){double o=1000+i*.03+25*std::sin(i/70.)+8*std::cos(i/17.);
  double c=1000+(i+1)*.03+25*std::sin((i+1)/70.)+8*std::cos((i+1)/17.);
  minutes.push_back({day-86400+i*60,o,std::max(o,c)+.3,std::min(o,c)-.3,c});}
 for(int tf:{1,2,3,4,5,10,12,15,30,60}){
  std::vector<MqlRates> bars;
  for(int i=0;i<int(minutes.size());i+=tf){auto b=minutes[i];
   for(int j=i+1;j<i+tf;++j){b.high=std::max(b.high,minutes[j].high);b.low=std::min(b.low,minutes[j].low);b.close=minutes[j].close;}
   bars.push_back(b);}
  Core baseline(tf),carry(tf);Rollover roll;roll.m_current_day_start=day-86400;
  int before=0;
  // Final bar is still open at 23:59:59; preserve it for the first post-midnight update.
  while(before<int(bars.size()) && bars[before].time+tf*60<day){baseline.feed(bars[before]);carry.feed(bars[before]);++before;}
  check(carry.zz->pivots->Total()>2);check(carry.ms.last_breakout_time>0);
  auto snapshot=carry.state();auto handle=carry.zz;
  testNow=day-2;roll.CheckDailyRollover();check(roll.reports==0);
  testNow=day-1;roll.CheckDailyRollover();check(roll.reports==1);
  roll.CheckDailyRollover();check(roll.reports==1);
  check(carry.state()==snapshot&&carry.zz==handle);
  testNow=day;roll.CheckDailyRollover();check(roll.journals==1&&!roll.m_daily_report_sent);
  check(carry.state()==snapshot&&carry.zz==handle);
  roll.CheckDailyRollover();check(roll.journals==1);
  for(int i=before;i<int(bars.size());++i){baseline.feed(bars[i]);carry.feed(bars[i]);check(carry.state()==baseline.state());}
  check(carry.times.back()>=day);check(carry.zz==handle);
  std::cout<<"TF="<<tf<<" prior pivots and market structure carried; uninterrupted replay matches\n";
 }
 Rollover late;late.m_current_day_start=day-86400;
 testNow=day+300;late.CheckDailyRollover();check(late.reports==1&&late.journals==1);
 late.CheckDailyRollover();check(late.reports==1&&late.journals==1);
 testNow=day+86399;late.CheckDailyRollover();check(late.reports==2);
 Journal journal;
 journal.m_instances[0].m_trades={{1,false,0,100,3},{2,true,.03,99,2},{3,true,.02,98,1},{4,true,.05,97,0}};
 journal.m_instances[1].m_trades={{5,true,.07,120,1}};
 journal.prepare(true);
 check(journal.m_instances[0].m_trades.size()==2);
 check(journal.m_instances[0].m_trades[0].positionId==2);
 check(journal.m_instances[0].m_trades[0].lots==.03&&journal.m_instances[0].m_trades[0].stop==99&&journal.m_instances[0].m_trades[0].partialState==2);
 check(journal.m_instances[0].m_trades[1].positionId==4);
 check(journal.m_instances[1].m_trades.size()==1&&journal.m_instances[1].m_trades[0].positionId==5);
 journal.prepare(true);check(journal.m_instances[0].m_trades.size()==2);
 journal.prepare(false);check(journal.m_instances[0].m_trades.empty()&&journal.m_instances[1].m_trades.empty());
 std::cout<<checks<<" history/rollover assertions passed; production integration guards passed\n";
}
'''
out = ROOT/'Tests/Marcotrades/_review'
cpp, exe = out/'history_context.cpp', out/'history_context.exe'
cpp.write_text(mock+extra+helper+env['source']+roll_class+journal_class+main, encoding='utf-8')
result = subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2','-fmax-errors=5',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:
    raise SystemExit(result.stderr)
result = subprocess.run([str(exe)],capture_output=True,text=True)
(out/'history_context_results.txt').write_text(result.stdout+result.stderr, encoding='utf-8')
print(result.stdout, end='')
if result.returncode:
    raise SystemExit(result.stderr or f'Regression failed: {result.returncode}')
