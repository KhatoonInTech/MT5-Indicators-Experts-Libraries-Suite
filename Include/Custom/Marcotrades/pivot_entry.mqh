// Entry execution policy only. ZigZag calculation and confirmation are unchanged.
#ifndef MARCO_PIVOT_ENTRY_MQH
#define MARCO_PIVOT_ENTRY_MQH

enum ENUM_MARCO_ENTRY_TIMING
  {
   ENTRY_AFTER_CONFIRMATION = 0, // Next candle open after confirmation (existing)
   ENTRY_PIVOT_CANDLE_EDGE = 1   // High-pivot candle LOW / low-pivot candle HIGH
  };

struct SMarcoPivotEntry
  {
   datetime pivot, confirmed;
   double level;
   bool nextOpen;
  };

// Separate from the prepared price level: keep this watermark when a pending
// pivot is discarded, so an older historical pivot cannot become its replacement.
struct SMarcoPivotWatch
  {
   datetime pivot, confirmed;
   double price;
   bool invalid;
  };

class CMarcoPivotEntry
  {
private:
   static ENUM_MARCO_ENTRY_TIMING mode;
public:
   static void Configure(ENUM_MARCO_ENTRY_TIMING value) { mode=value; }
   static bool Enabled() { return mode==ENTRY_PIVOT_CANDLE_EDGE; }
   static bool Passed(bool buy, double price, double level)
     { return buy ? price>=level : price<=level; }
   static bool Waiting(const SMarcoPivotEntry &state)
     { return Enabled() && state.confirmed>0 && !state.nextOpen; }

   static bool Prepare(SMarcoPivotEntry &state, string symbol, ENUM_TIMEFRAMES tf,
                       bool buy, datetime pivot, datetime confirmed, datetime now)
     {
      if(!Enabled()) return true;
      if(pivot<=0 || confirmed<=0 || confirmed>now) return false;
      if(state.pivot==pivot && state.confirmed==confirmed && state.level>0) return true;
      MqlRates source[], confirmation[];
      int p=iBarShift(symbol,tf,pivot,true);
      int c=iBarShift(symbol,tf,confirmed-1,false);
      if(p<0 || c<0 || CopyRates(symbol,tf,p,1,source)!=1 ||
         CopyRates(symbol,tf,c,1,confirmation)!=1) return false;
      int seconds=PeriodSeconds(tf);
      // Never read the current/unclosed candle or substitute a nearby pivot candle.
      if(source[0].time!=pivot || source[0].time+seconds>confirmed ||
         confirmation[0].time+seconds!=confirmed) return false;
      double level=buy ? source[0].high : source[0].low;
      if(level<=0 || confirmation[0].close<=0) return false;
      state.pivot=pivot; state.confirmed=confirmed; state.level=level;
      state.nextOpen=Passed(buy,confirmation[0].close,level);
      PrintFormat("[PIVOT ENTRY] %s %s %s pivot=%s confirmed=%s level=%.8f confirmation_close=%.8f action=%s",
                  symbol,EnumToString(tf),buy ? "BUY" : "SELL",TimeToString(pivot,TIME_DATE|TIME_SECONDS),
                  TimeToString(confirmed,TIME_DATE|TIME_SECONDS),level,confirmation[0].close,
                  state.nextOpen ? "NEXT_CANDLE_OPEN" : "WAIT_FOR_LEVEL");
      return true;
     }

   // Candle levels are Bid-chart levels. A buy executes at Ask after Bid reaches
   // the pivot candle high; a sell executes at Bid after Bid reaches its low.
   static bool Quote(const SMarcoPivotEntry &state, bool buy, double bid)
     { return !Waiting(state) || Passed(buy,bid,state.level); }

   // Use the existing exit replay path: bullish candle O-L-H-C, bearish O-H-L-C.
   // Return only the portion AFTER the entry-level crossing.
   // Signals/zone snapshots must already have been frozen at the bar's open.
   static bool Bar(const SMarcoPivotEntry &state, bool buy, double open, double high,
                   double low, double close, double &fill, bool &intrabar,
                   double &afterHigh, double &afterLow)
     {
      fill=open; intrabar=false; afterHigh=high; afterLow=low;
      if(!Waiting(state) || Passed(buy,open,state.level)) return true;
      if(!Passed(buy,buy ? high : low,state.level)) return false;
      fill=state.level; intrabar=true;
      if(buy && close>=open) afterLow=MathMin(fill,close);
      else if(!buy && close<open) afterHigh=MathMax(fill,close);
      return true;
     }
  };
ENUM_MARCO_ENTRY_TIMING CMarcoPivotEntry::mode=ENTRY_AFTER_CONFIRMATION;
#endif
