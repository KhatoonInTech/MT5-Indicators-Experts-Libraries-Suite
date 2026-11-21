#define MARCO_LOG_PROGRAM "liquidity"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                 Indicators\Custom\ZigZag\liquidity.mq5  |
//|                             Dynamic Projection Liquidity Plotter |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\liquidity.mqh"

//--- Input Parameters
input group             "--- Visibility ---"
input bool              showZigZagInput      = false;     // Show Zig Zag Lines

input group             "--- Zig Zag Settings ---"
input double            deviationInput       = 0.5;       // Price deviation for reversals (%)
input int               depthInput           = 15;        // Pivot legs
input color             lineColorInput       = C'41,98,255'; // Line color
input bool              extendInput          = true;      // Extend to last bar
input bool              showPriceInput       = true;      // Display reversal price
input bool              showVolInput         = true;      // Display cumulative volume
input bool              showChgInput         = true;      // Display reversal price change
input string            priceDiffInput       = "Absolute"; // Difference Mode ("Absolute" or "Percent")

input group             "--- Liquidity Settings ---"
input double            threshold            = 0.0005;    // EQ Sensitivity (Double Tops/Bottoms)
input double            slope_tol            = 0.1;       // Trendline Sensitivity (%)
input color             bslColor             = clrRed;    // BSL Color
input color             sslColor             = clrBlue;   // SSL Color

//--- Global Variables
ZigZag*                 zigZag;
CLiquidityLogic*        liqLogic;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   if(depthInput < 2)
     {
      Print("Invalid depthInput. Minimum is 2.");
      return INIT_PARAMETERS_INCORRECT;
     }

// Initialize ZigZag with exact parameter mapping
   Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, showPriceInput, showVolInput, showChgInput, priceDiffInput);
   s.draw = showZigZagInput;
   zigZag = newInstance(s);

// Initialize Liquidity Logic Component
   liqLogic = new CLiquidityLogic();
   liqLogic.Init(threshold, slope_tol, bslColor, sslColor);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   if(zigZag != NULL)
      delete zigZag;
   if(liqLogic != NULL)
      delete liqLogic;

// Centralized Graphic Object Cleanups
   ObjectsDeleteAll(0, "Liq_");
   ObjectsDeleteAll(0, "ZZ_");
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   g_marcoDailyLog.Pulse();
// Set all standard time and OHLC arrays in non-series format (oldest bar at index 0)
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);

   int limit = prev_calculated;
   if(limit > 0)
      limit--; // Re-calculate the active candle

   if(prev_calculated == 0)
     {
      liqLogic.ResetState();
      liqLogic.Cleanup();
      ObjectsDeleteAll(0, "ZZ_");
     }

   for(int i = limit; i < rates_total; i++)
     {
      bool is_last = (i == rates_total - 1);

      // 1. Process and update underlying ZigZag logic
      zigZag.update(high[i], low[i], time[i], tick_volume[i], i, !is_last, is_last);

      // 2. Compute liquidity detection states and update real-time projections
      liqLogic.DetectLiquidity(i, time, high, low, zigZag);
      liqLogic.UpdateActiveLevels(i, time, high, low, close);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\ZigZag\liquidity.mq5

// END FILE: Indicators\Custom\ZigZag\liquidity.mq5
