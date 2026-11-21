
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
// Shared previous-session history boundary. Times are broker/server candle times.
#ifndef MARCO_HISTORY_CONTEXT_MQH
#define MARCO_HISTORY_CONTEXT_MQH
class CMarcoHistoryContext
  {
public:
   static datetime DayStart(datetime time) { return time-time%86400; }
   static bool TradingWindow(datetime now, datetime start) { return now>=start; }
   static bool ResolveStart(string symbol, datetime tradingStart, datetime &historyStart)
     {
      historyStart=0;
      datetime day=DayStart(tradingStart);
      if(day<=0) return false;
      // Date/count overload: obtain the last M1 bar strictly before this trading day.
      // On weekends/holidays this selects the previous available trading day.
      std::vector<MqlRates> previous;
      int copied=CopyRates(symbol,PERIOD_M1,(datetime)(day-1),1,previous);
      if(copied!=1 || !SeriesInfoInteger(symbol,PERIOD_M1,SERIES_SYNCHRONIZED) ||
         previous[0].time<=0 || previous[0].time>=day) return false;
      historyStart=DayStart(previous[0].time);
      return true;
     }
   static bool HasPriorContext(datetime firstBar, datetime tradingStart)
     { return firstBar>0 && firstBar<DayStart(tradingStart); }
  };
#endif
int WindowBarCount(const int count,const std::vector<datetime> &times,const datetime endTime)
  {
   int left=0,right=count;
   while(left<right)
     {
      int mid=left+(right-left)/2;
      if(times[mid]<=endTime) left=mid+1;
      else right=mid;
     }
   return left;
  }

bool ClosedByWindowEnd(const datetime barTime,const datetime endTime,const int seconds)
  {
   return seconds>0 && barTime+seconds<=endTime;
  }

bool ResolveWarmupStart(const int count, const std::vector<datetime> &times, int &startBar,
                        datetime &contextStart, datetime &historyStart)
  {
   startBar=0;
   contextStart=0;
   historyStart=0;
   if(count<=0) return false;
   contextStart=InpUseAnchorSlider ? g_anchor_time :
                times[MathMax(0,count-MathMax(1,InpMaxLookbackBars))];
   if(contextStart<=0 || contextStart>times[count-1]) return false;
   if(!CMarcoHistoryContext::ResolveStart(_Symbol,contextStart,historyStart)) return false;

   std::vector<MqlRates> warmup;
   int copied=CopyRates(_Symbol,_Period,historyStart,contextStart,warmup);
   if(copied<=0 || !SeriesInfoInteger(_Symbol,_Period,SERIES_SYNCHRONIZED) ||
      !CMarcoHistoryContext::HasPriorContext(warmup[0].time,contextStart)) return false;
   // CopyRates also requests missing history from the terminal. If the chart
   // has not received it yet, return 0 from OnCalculate and retry on its update.
   for(int i=0;i<count;i++)
     {
      if(times[i]<warmup[0].time) continue;
      if(times[i]!=warmup[0].time) return false;
      startBar=i;
      return count-startBar>=InpDepth*2;
     }
   return false;
  }
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
