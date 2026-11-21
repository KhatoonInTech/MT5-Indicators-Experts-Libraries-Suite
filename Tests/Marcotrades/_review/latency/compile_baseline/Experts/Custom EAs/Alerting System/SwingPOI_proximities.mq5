#define MARCO_LOG_PROGRAM "SwingPOI_proximities"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                               Experts/ZigZag/swing_poi_proximities.mq5 |
//|                         Swing POI Proximity Monitor and Alert EA  |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.03"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_poi_proximities.mqh"

// Input Configurations
input group "--- Proximity Parameters ---"
input double MaxPipsDistance = 5.0;     // Max allowable pips from Swing POI boundary
input group "Alert Settings"
input bool   sendTestMockAlertOnStart = false;
input int    scanSpeedPerSecond       = 15;           // Number of charts to scan per second (Prevents Crash)

// ==================================================================
// ZIG ZAG & CORE SETTINGS
// ==================================================================
input group "--- For Forex Pairs ---"
input int    fx_maxLookback          = 3000;
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
input double fx_dev_M15              = 0.5;
input int    fx_dep_M15              = 5;

input group "--- For Metals Pairs ---"
input int    met_maxLookback          = 5000;
input group "Metals: PERIOD_D1"
input double met_dev_D1               = 5.0;
input int    met_dep_D1               = 15;
input group "Metals: PERIOD_H4"
input double met_dev_H4               = 5.0;
input int    met_dep_H4               = 15;
input group "Metals: PERIOD_H1"
input double met_dev_H1               = 2.66;
input int    met_dep_H1               = 11;
input group "Metals: PERIOD_M15"
input double met_dev_M15              = 2.66;
input int    met_dep_M15              = 12;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback          = 5000;
input group "Crypto: PERIOD_D1"
input double cry_dev_D1               = 5.0;
input int    cry_dep_D1               = 15;
input group "Crypto: PERIOD_H4"
input double cry_dev_H4               = 5.0;
input int    cry_dep_H4               = 15;
input group "Crypto: PERIOD_H1"
input double cry_dev_H1               = 2.66;
input int    cry_dep_H1               = 11;
input group "Crypto: PERIOD_M15"
input double cry_dev_M15              = 2.66;
input int    cry_dep_M15              = 12;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Swing POI Proximity Monitor Expert...");

   // 1. Assign static configurations to CSwingPOIProximityScanner
   CSwingPOIProximityScanner::fx_maxLookback = fx_maxLookback;
   CSwingPOIProximityScanner::fx_dev_D1      = fx_dev_D1;
   CSwingPOIProximityScanner::fx_dep_D1      = fx_dep_D1;
   CSwingPOIProximityScanner::fx_dev_H4      = fx_dev_H4;
   CSwingPOIProximityScanner::fx_dep_H4      = fx_dep_H4;
   CSwingPOIProximityScanner::fx_dev_H1      = fx_dev_H1;
   CSwingPOIProximityScanner::fx_dep_H1      = fx_dep_H1;
   CSwingPOIProximityScanner::fx_dev_M15     = fx_dev_M15;
   CSwingPOIProximityScanner::fx_dep_M15     = fx_dep_M15;

   // 2. Assign Metals static configuration parameters
   CSwingPOIProximityScanner::met_maxLookback = met_maxLookback;
   CSwingPOIProximityScanner::met_dev_D1      = met_dev_D1;
   CSwingPOIProximityScanner::met_dep_D1      = met_dep_D1;
   CSwingPOIProximityScanner::met_dev_H4      = met_dev_H4;
   CSwingPOIProximityScanner::met_dep_H4      = met_dep_H4;
   CSwingPOIProximityScanner::met_dev_H1      = met_dev_H1;
   CSwingPOIProximityScanner::met_dep_H1      = met_dep_H1;
   CSwingPOIProximityScanner::met_dev_M15     = met_dev_M15;
   CSwingPOIProximityScanner::met_dep_M15     = met_dep_M15;

   // 3. Assign Crypto static configuration parameters
   CSwingPOIProximityScanner::cry_maxLookback = cry_maxLookback;
   CSwingPOIProximityScanner::cry_dev_D1      = cry_dev_D1;
   CSwingPOIProximityScanner::cry_dep_D1      = cry_dep_D1;
   CSwingPOIProximityScanner::cry_dev_H4      = cry_dev_H4;
   CSwingPOIProximityScanner::cry_dep_H4      = cry_dep_H4;
   CSwingPOIProximityScanner::cry_dev_H1      = cry_dev_H1;
   CSwingPOIProximityScanner::cry_dep_H1      = cry_dep_H1;
   CSwingPOIProximityScanner::cry_dev_M15     = cry_dev_M15;
   CSwingPOIProximityScanner::cry_dep_M15     = cry_dep_M15;

   // 4. Optional connectivity mock alert
   if(sendTestMockAlertOnStart)
     {
      SendDemoAlert();
     }

   // 5. Run the first sweep immediately
   CSwingPOIProximityScanner::RunSwingPOIScan(MaxPipsDistance);

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
   Print("🛑 SMC Swing POI Proximity Monitor expert shut down safely.");
  }

//+------------------------------------------------------------------+
//| OnTimer scheduled clock validator                                |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   CSwingPOIProximityScanner::Process(MaxPipsDistance);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
// Timer schedules structural daily sweeps; ticks are bypassed.
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Alerting System\SwingPOI_proximities.mq5

// END FILE: Experts\Custom EAs\Alerting System\SwingPOI_proximities.mq5
