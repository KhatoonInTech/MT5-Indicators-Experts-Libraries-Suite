#define MARCO_LOG_PROGRAM "liquidity_swept"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                              liquidity_swept.mq5 |
//|                 SMC Multi-Symbol Liquidity Swept Backtest Engine |
//|                 Compliant with Guardrails Risk & Marcotrades SMC |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.01"

#include <Custom\Marcotrades\liquidity_swept_backtesting.mqh>

input group "Strategy Setup & Target Timeframe Settings"
input ENUM_TIMEFRAMES InpTradeTimeframe          = PERIOD_M15;   // Primary Trading Timeframe
input ENUM_TIMEFRAMES InpTPInducementTF          = PERIOD_M15;   // Timeframe for Opposing Inducement TP
input double          InpSLBufferPips            = 2.0;          // SL Buffer outside Liquidity Block (Pips)
input double          InpMinRRRatio              = 1.5;          // Minimum Risk:Reward to qualify entry

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Trigger Filters (Nomenclature)"
input bool            InpTriggerBLCHoCH          = true;         // TF-BL-LB-IND (1st BL-CHoCH post Buyers' Inducement)
input bool            InpTriggerSSLSwept         = true;         // TF-BL-LB-SSL (1st SSL-Swept post Buyers' Inducement)
input bool            InpTriggerBRCHoCH          = true;         // TF-BR-LB-IND (1st BR-CHoCH post Sellers' Inducement)
input bool            InpTriggerBSLSwept         = true;         // TF-BR-LB-BSL (1st BSL-Swept post Sellers' Inducement)

input group "Inducement Validation & Anti-Clustering"
input int             InpMinTouches              = 3;            // Min touches for Inducement qualification
input double          InpProximityPips           = 1.0;          // Touch proximity buffer outside zone (Pips)
input bool            InpMergeClusteredZones     = true;         // Prolong master inducement & prevent stacking
input double          InpClusterTolerancePips    = 10.0;         // Cluster tolerance range (Pips)

input group "Guardrails Risk & Position Sizing"
input bool            InpEnforceMaxLot           = true;         // Enforce Max Safe Lot
input double          InpMaxRiskPercent          = 1.0;          // Max Account Risk (%)
input bool            InpExcludeSpreadFromRisk   = true;         // Exclude Spread from 1% risk calculation
input bool            InpAutoBreakeven           = true;         // Move SL to Breakeven when in profit
input double          InpBreakevenMultiplier     = 10.0;         // Profit distance required (x Spread)
input int             InpBreakevenBuffer         = 0;            // Breakeven Buffer in points

input group "Backtest & Visual Debugging"
input int             scanSpeedPerSecond         = 3;            // Number of symbols backtested per second
input bool            drawOnAllCharts            = false;        // Draw Trades on Matching Open Charts
input color           successZoneColor           = clrSpringGreen;
input color           failZoneColor              = clrSalmon;

input group "--- For Forex Pairs ---"
input int             fx_maxLookback             = 5000;
input group "Forex: PERIOD_D1"
input double          fx_dev_D1                  = 2.20;
input int             fx_dep_D1                  = 17;
input group "Forex: PERIOD_H4"
input double          fx_dev_H4                  = 0.80;
input int             fx_dep_H4                  = 17;
input group "Forex: PERIOD_H1"
input double          fx_dev_H1                  = 0.20;
input int             fx_dep_H1                  = 19;
input group "Forex: PERIOD_M15"
input double          fx_dev_M15                 = 0.15;
input int             fx_dep_M15                 = 16;

input group "--- For Metals Pairs ---"
input int             met_maxLookback            = 10000;
input group "Metals: PERIOD_D1"
input double          met_dev_D1                 = 5.0;
input int             met_dep_D1                 = 15;
input group "Metals: PERIOD_H4"
input double          met_dev_H4                 = 5.0;
input int             met_dep_H4                 = 15;
input group "Metals: PERIOD_H1"
input double          met_dev_H1                 = 1.0;
input int             met_dep_H1                 = 15;
input group "Metals: PERIOD_M15"
input double          met_dev_M15                = 1.0;
input int             met_dep_M15                = 5;

input group "--- For Crypto Pairs ---"
input int             cry_maxLookback            = 10000;
input group "Crypto: PERIOD_D1"
input double          cry_dev_D1                 = 5.0;
input int             cry_dep_D1                 = 15;
input group "Crypto: PERIOD_H4"
input double          cry_dev_H4                 = 5.0;
input int             cry_dep_H4                 = 15;
input group "Crypto: PERIOD_H1"
input double          cry_dev_H1                 = 2.66;
input int             cry_dep_H1                 = 11;
input group "Crypto: PERIOD_M15"
input double          cry_dev_M15                = 2.66;
input int             cry_dep_M15                = 12;

// Master Backtest Engine Instance
CLiquiditySweptBacktestEngine* engine = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Liquidity Swept Backtest Engine...");

   engine = new CLiquiditySweptBacktestEngine();
   engine.Initialize(
      InpTradeTimeframe, InpTPInducementTF,
      scanSpeedPerSecond, InpMaxRiskPercent, InpEnforceMaxLot, InpExcludeSpreadFromRisk,
      InpAutoBreakeven, InpBreakevenMultiplier, InpBreakevenBuffer,
      InpTriggerBLCHoCH, InpTriggerSSLSwept, InpTriggerBRCHoCH, InpTriggerBSLSwept,
      InpSLBufferPips, InpMinRRRatio,
      drawOnAllCharts, successZoneColor, failZoneColor,
      InpMinTouches, InpProximityPips, InpMergeClusteredZones, InpClusterTolerancePips,
      fx_maxLookback, fx_dev_D1, fx_dep_D1, fx_dev_H4, fx_dep_H4, fx_dev_H1, fx_dep_H1, fx_dev_M15, fx_dep_M15,
      met_maxLookback, met_dev_D1, met_dep_D1, met_dev_H4, met_dep_H4, met_dev_H1, met_dep_H1, met_dev_M15, met_dep_M15,
      cry_maxLookback, cry_dev_D1, cry_dep_D1, cry_dev_H4, cry_dep_H4, cry_dev_H1, cry_dep_H1, cry_dev_M15, cry_dep_M15
   );

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   if(engine != NULL)
      delete engine;

   long currChart = ChartFirst();
   while(currChart >= 0)
     {
      ObjectsDeleteAll(currChart, "LS_BT_");
      ChartRedraw(currChart);
      currChart = ChartNext(currChart);
     }

   Print("🛑 SMC Liquidity Swept Backtest Engine Stopped.");
  }

//+------------------------------------------------------------------+
//| Expert timer batch execution function                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(engine != NULL)
     {
      engine.ProcessBatch(scanSpeedPerSecond);
      if(engine.IsCompleted())
        {
         EventKillTimer();
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
// Scheduled batch execution is driven via OnTimer()
  }
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Backtesting\liquidity_swept.mq5
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Backtesting\liquidity_swept.mq5

// END FILE: Experts\Custom EAs\Backtesting\liquidity_swept.mq5
