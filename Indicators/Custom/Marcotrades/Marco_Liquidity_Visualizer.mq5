#define MARCO_LOG_PROGRAM "Marco_Liquidity_Visualizer"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|             Indicators\Custom\Marcotrades\Marco_Liquidity_Visualizer.mq5|
//|        Visualizes Traps, Inducements, Liquidity Blocks, and EL   |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect / Inter Equity System"
#property version   "4.10"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\Marcotrades\marco_core.mqh>

// ==================================================================
// 1. DRAW SETTINGS & ZIGZAG VISUAL CONTROLS
// ==================================================================
input group "=== Draw Settings ==="
input bool   InpDrawZigZag                    = true;     // Draw ZigZag
input color  lineColorInput                   = clrGold;  // ZigZag Line Color
input bool   extendInput                      = true;     // Extend to last bar (Projection Pivots)
input bool   showPriceInput                   = false;    // Display reversal price
input bool   showVolInput                     = false;    // Display cumulative volume
input bool   showChgInput                     = false;    // Display reversal price change
input string priceDiffInput                   = "Percent";// Difference Mode (Absolute/Percent)
input bool   InpDrawMarketStructure           = true;     // Draw Market Structure (BOS, CHoCH, swing high/low, etc)
input bool   InpDrawZones                     = false;    // Draw Zones
input bool   InpShowEngineeredLQ              = true;     // Show Engineered LQ Lines (💵)
input bool   InpShowTraps                     = true;     // Show Pink Trap Boxes (❌)
input bool   InpShowLiquidityBlocks           = true;     // Show Liquidity Blocks (LB)
input bool   InpShowTargetEye                 = true;     // Show "Keep An Eye Here!! 👁️"

// ==================================================================
// 2. ASSET CATEGORY OVERRIDE
// ==================================================================
input group "=== Asset Category ==="
input ENUM_ASSET_TYPE InpAssetCategory        = ASSET_TYPE_AUTO; // Asset Category (Auto Detects by Default)

// ==================================================================
// 3. ZIG ZAG & CORE SETTINGS
// ==================================================================
input group "--- For Forex Pairs ---"
input int    fx_maxLookback                   = 1000;
input group "Forex: PERIOD_D1"
input double fx_dev_D1                        = 1.0;
input int    fx_dep_D1                        = 15;
input group "Forex: PERIOD_H4"
input double fx_dev_H4                        = 0.5;
input int    fx_dep_H4                        = 2;
input group "Forex: PERIOD_H1"
input double fx_dev_H1                        = 0.5;
input int    fx_dep_H1                        = 15;
input group "Forex: PERIOD_M15"
input double fx_dev_M15                       = 0.5;
input int    fx_dep_M15                       = 5;
input group "Forex: PERIOD_M1 (Confirmation)"
input double fx_dev_M1                        = 0.001;
input int    fx_dep_M1                        = 1;

input group "--- For Metals Pairs ---"
input int    met_maxLookback                  = 1000;
input group "Metals: PERIOD_D1"
input double met_dev_D1                       = 5.0;
input int    met_dep_D1                       = 15;
input group "Metals: PERIOD_H4"
input double met_dev_H4                       = 5.0;
input int    met_dep_H4                       = 15;
input group "Metals: PERIOD_H1"
input double met_dev_H1                       = 1.0;
input int    met_dep_H1                       = 15;
input group "Metals: PERIOD_M15"
input double met_dev_M15                      = 1.0;
input int    met_dep_M15                      = 5;
input group "Metals: PERIOD_M1 (Confirmation)"
input double met_dev_M1                       = 0.001;
input int    met_dep_M1                       = 1;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback                  = 1000;
input group "Crypto: PERIOD_D1"
input double cry_dev_D1                       = 5.0;
input int    cry_dep_D1                       = 15;
input group "Crypto: PERIOD_H4"
input double cry_dev_H4                       = 5.0;
input int    cry_dep_H4                       = 15;
input group "Crypto: PERIOD_H1"
input double cry_dev_H1                       = 1.0;
input int    cry_dep_H1                       = 15;
input group "Crypto: PERIOD_M15"
input double cry_dev_M15                      = 1.0;
input int    cry_dep_M15                      = 5;
input group "Crypto: PERIOD_M1 (Confirmation)"
input double cry_dev_M1                       = 0.001;
input int    cry_dep_M1                       = 1;

CMarcoCoreLogic g_engine;

//+------------------------------------------------------------------+
//| Indicator Initialization                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   SZigZagParams zz;
   zz.fx_maxLookback   = fx_maxLookback;
   zz.fx_dev_D1        = fx_dev_D1;
   zz.fx_dep_D1 = fx_dep_D1;
   zz.fx_dev_H4        = fx_dev_H4;
   zz.fx_dep_H4 = fx_dep_H4;
   zz.fx_dev_H1        = fx_dev_H1;
   zz.fx_dep_H1 = fx_dep_H1;
   zz.fx_dev_M15       = fx_dev_M15;
   zz.fx_dep_M15 = fx_dep_M15;
   zz.fx_dev_M1        = fx_dev_M1;
   zz.fx_dep_M1 = fx_dep_M1;

   zz.met_maxLookback  = met_maxLookback;
   zz.met_dev_D1       = met_dev_D1;
   zz.met_dep_D1 = met_dep_D1;
   zz.met_dev_H4       = met_dev_H4;
   zz.met_dep_H4 = met_dep_H4;
   zz.met_dev_H1       = met_dev_H1;
   zz.met_dep_H1 = met_dep_H1;
   zz.met_dev_M15      = met_dev_M15;
   zz.met_dep_M15 = met_dep_M15;
   zz.met_dev_M1       = met_dev_M1;
   zz.met_dep_M1 = met_dep_M1;

   zz.cry_maxLookback  = cry_maxLookback;
   zz.cry_dev_D1       = cry_dev_D1;
   zz.cry_dep_D1 = cry_dep_D1;
   zz.cry_dev_H4       = cry_dev_H4;
   zz.cry_dep_H4 = cry_dep_H4;
   zz.cry_dev_H1       = cry_dev_H1;
   zz.cry_dep_H1 = cry_dep_H1;
   zz.cry_dev_M15      = cry_dev_M15;
   zz.cry_dep_M15 = cry_dep_M15;
   zz.cry_dev_M1       = cry_dev_M1;
   zz.cry_dep_M1 = cry_dep_M1;

   g_engine.Init(_Symbol, _Period, InpAssetCategory, zz,
                 InpDrawZigZag, lineColorInput, extendInput,
                 InpDrawMarketStructure, InpShowEngineeredLQ,
                 InpShowTraps, InpShowLiquidityBlocks, InpShowTargetEye);

   ChartRedraw(0);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Indicator Deinitialization                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   g_engine.Cleanup();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Indicator Calculation Loop                                       |
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
   if(rates_total < 30)
      return 0;

   bool bSig = false, sSig = false;
   SMarcoSignal bData, sData;

   g_engine.UpdatePivots(rates_total, time, open, high, low, close, volume, bSig, sSig, bData, sData);

   return(rates_total);
  }
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\Marcotrades\Marco_Liquidity_Visualizer.mq5

// END FILE: Indicators\Custom\Marcotrades\Marco_Liquidity_Visualizer.mq5
