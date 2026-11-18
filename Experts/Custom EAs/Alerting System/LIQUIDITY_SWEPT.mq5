#define MARCO_LOG_PROGRAM "LIQUIDITY_SWEPT"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                              LIQUIDITY_SWEPT.mq5 |
//|        SMC Post-Inducement Mitigation & Liquidity Swept Alert EA |
//|        - TF-BL-LB-IND & TF-BL-LB-SSL                             |
//|        - TF-BR-LB-IND & TF-BR-LB-BSL                             |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.00"

#include <Custom\Marcotrades\liquidity_swept_alerting.mqh>

input group "Alert Settings"
input bool   sendTestMockAlertOnStart = false;        // Send test Teams alert on startup
input int    scanSpeedPerSecond       = 10;           // Number of charts to scan per second

input group "Liquidity Swept Trigger Filters"
input bool   alertBLCHoCH             = true;         // TF-BL-LB-IND (1st BL-CHoCH post Buyers' Inducement)
input bool   alertSSLSwept            = true;         // TF-BL-LB-SSL (1st SSL-Swept post Buyers' Inducement)
input bool   alertBRCHoCH             = true;         // TF-BR-LB-IND (1st BR-CHoCH post Sellers' Inducement)
input bool   alertBSLSwept            = true;         // TF-BR-LB-BSL (1st BSL-Swept post Sellers' Inducement)

input group "Inducement Validation Engine"
input int    InpMinTouches            = 3;            // Min touches to qualify as Inducement
input double InpProximityPips         = 1.0;          // Touch proximity buffer outside zone (Pips)
input bool   InpMergeClusteredZones   = true;         // Prolong single master inducement & prevent stacking
input double InpClusterTolerancePips  = 10.0;         // Cluster tolerance range (Pips)

// ==================================================================
// ZIG ZAG & CORE TIMEFRAME CONFIGURATIONS
// ==================================================================
input group "--- For Forex Pairs ---"
input int    fx_maxLookback          = 5000;
input group "Forex: PERIOD_D1"
input double fx_dev_D1               = 1.0;
input int    fx_dep_D1               = 15;
input group "Forex: PERIOD_H4"
input double fx_dev_H4               = 0.5;
input int    fx_dep_H4               = 2;
input group "Forex: PERIOD_H1"
input double fx_dev_H1               = 0.5;
input int    fx_dep_H1               = 15;
input group "Forex: PERIOD_M15"
input double fx_dev_M15              = 0.15;
input int    fx_dep_M15              = 5;

input group "--- For Metals Pairs ---"
input int    met_maxLookback          = 5000;
input group "Metals: PERIOD_D1"
input double met_dev_D1               = 5.0;
input int    met_dep_D1               = 15;
input group "Metals: PERIOD_H4"
input double met_dev_H4               = 1.999;
input int    met_dep_H4               = 3;
input group "Metals: PERIOD_H1"
input double met_dev_H1               = 3.935;
input int    met_dep_H1               = 13;
input group "Metals: PERIOD_M15"
input double met_dev_M15              = 1.0;
input int    met_dep_M15              = 5;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback          = 10000;
input group "Crypto: PERIOD_D1"
input double cry_dev_D1               = 5.0;
input int    cry_dep_D1               = 15;
input group "Crypto: PERIOD_H4"
input double cry_dev_H4               = 5.0;
input int    cry_dep_H4               = 15;
input group "Crypto: PERIOD_H1"
input double cry_dev_H1               = 1.0;
input int    cry_dep_H1               = 15;
input group "Crypto: PERIOD_M15"
input double cry_dev_M15              = 0.15;
input int    cry_dep_M15              = 5;

// Global Objects
SLiquiditySweptConfig*      global_config  = NULL;
CLiquiditySweptAlertEngine* scanner_engine = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Liquidity Swept Alert Engine...");

   global_config = new SLiquiditySweptConfig();
   global_config.scanSpeedPerSecond    = scanSpeedPerSecond;

   global_config.alertBLCHoCH          = alertBLCHoCH;
   global_config.alertSSLSwept         = alertSSLSwept;
   global_config.alertBRCHoCH          = alertBRCHoCH;
   global_config.alertBSLSwept         = alertBSLSwept;

   global_config.minTouches            = InpMinTouches;
   global_config.proximityPips         = InpProximityPips;
   global_config.mergeClustered        = InpMergeClusteredZones;
   global_config.clusterTolerancePips  = InpClusterTolerancePips;

   global_config.fx_maxLookback        = fx_maxLookback;
   global_config.fx_dev_D1             = fx_dev_D1;
   global_config.fx_dep_D1             = fx_dep_D1;
   global_config.fx_dev_H4             = fx_dev_H4;
   global_config.fx_dep_H4             = fx_dep_H4;
   global_config.fx_dev_H1             = fx_dev_H1;
   global_config.fx_dep_H1             = fx_dep_H1;
   global_config.fx_dev_M15            = fx_dev_M15;
   global_config.fx_dep_M15            = fx_dep_M15;

   global_config.met_maxLookback       = met_maxLookback;
   global_config.met_dev_D1            = met_dev_D1;
   global_config.met_dep_D1            = met_dep_D1;
   global_config.met_dev_H4            = met_dev_H4;
   global_config.met_dep_H4            = met_dep_H4;
   global_config.met_dev_H1            = met_dev_H1;
   global_config.met_dep_H1            = met_dep_H1;
   global_config.met_dev_M15           = met_dev_M15;
   global_config.met_dep_M15           = met_dep_M15;

   global_config.cry_maxLookback       = cry_maxLookback;
   global_config.cry_dev_D1            = cry_dev_D1;
   global_config.cry_dep_D1            = cry_dep_D1;
   global_config.cry_dev_H4            = cry_dev_H4;
   global_config.cry_dep_H4            = cry_dep_H4;
   global_config.cry_dev_H1            = cry_dev_H1;
   global_config.cry_dep_H1            = cry_dep_H1;
   global_config.cry_dev_M15           = cry_dev_M15;
   global_config.cry_dep_M15           = cry_dep_M15;

   scanner_engine = new CLiquiditySweptAlertEngine();
   scanner_engine.Initialize(global_config);

   if(sendTestMockAlertOnStart)
     {
      SendDemoAlert();
     }

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
   if(scanner_engine)
      delete scanner_engine;
   if(global_config)
      delete global_config;
   Print("🛑 SMC Liquidity Swept Alert Engine stopped.");
  }

//+------------------------------------------------------------------+
//| Expert timer batch execution function                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(scanner_engine)
     {
      scanner_engine.ProcessBatch();
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
// Scheduled batch scans are driven via OnTimer()
  }
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Alerting System\LIQUIDITY_SWEPT.mq5
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Alerting System\LIQUIDITY_SWEPT.mq5

// END FILE: Experts\Custom EAs\Alerting System\LIQUIDITY_SWEPT.mq5
