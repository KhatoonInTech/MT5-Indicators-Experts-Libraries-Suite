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
      MqlRates previous[];
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
