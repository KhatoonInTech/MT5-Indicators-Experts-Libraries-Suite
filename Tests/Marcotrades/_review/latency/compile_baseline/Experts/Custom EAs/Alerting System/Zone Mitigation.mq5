#define MARCO_LOG_PROGRAM "Zone Mitigation"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                       Experts\zone_mitigation.mq5|
//|      SMC Multi-Symbol Wick Touch Alert Engine based on zigzag/HL |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.15"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\zone_mitigation.mqh"

input group "Alert Settings"
input bool   sendTestMockAlertOnStart = false;
input int    scanSpeedPerSecond       = 10;           // Number of charts to scan per second (Prevents Crash)

input group "Alert Filters - Demand/Supply Zones"
input bool   alertDemandZones         = true;
input bool   alertSupplyZones         = true;
input bool   alertMitigDemandZones    = false;
input bool   alertMitigSupplyZones    = false;

input group "Alert Filters - Order Blocks"
input bool   alertBullishOB           = true;
input bool   alertBearishOB           = true;
input bool   alertMitigBullishOB      = false;
input bool   alertMitigBearishOB      = false;

input group "Alert Filters - Swing POIs"
input bool   alertBullishPOI          = true;
input bool   alertBearishPOI          = true;
input bool   alertMitigBullishPOI     = false;
input bool   alertMitigBearishPOI     = false;

input group "Alert Filters - Flip Zones"
input bool   alertDemandFlipZones     = true;         // Alert Demand Flip Zones (Longs)
input bool   alertSupplyFlipZones     = true;         // Alert Supply Flip Zones (Shorts)
input bool   alertMitigDemandFlipZones = false;        // Alert Mitigated Demand Flips
input bool   alertMitigSupplyFlipZones = false;        // Alert Mitigated Supply Flips

input group "Alert Filters - Breaker Blocks"
input bool   alertBullishBreaker      = true;
input bool   alertBearishBreaker       = true;
input bool   alertMitigBullishBreaker = false;
input bool   alertMitigBearishBreaker = false;

// ==================================================================
// ZIG ZAG & CORE SETTINGS
// ==================================================================
input group "--- For Forex Pairs ---"
input int    fx_maxLookback          = 10000;
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
input group "Forex: PERIOD_M1 (Confirmation)"
input double fx_dev_M1               = 0.001;
input int    fx_dep_M1               = 1;

input group "--- For Metals Pairs ---"
input int    met_maxLookback          = 10000;
input group "Metals: PERIOD_D1"
input double met_dev_D1               = 5.0;
input int    met_dep_D1               = 15;
input group "Metals: PERIOD_H4"
input double met_dev_H4               = 5.0;
input int    met_dep_H4               = 15;
input group "Metals: PERIOD_H1"
input double met_dev_H1               = 1.0;
input int    met_dep_H1               = 15;
input group "Metals: PERIOD_M15"
input double met_dev_M15              = 1.0;
input int    met_dep_M15              = 5;
input group "Metals: PERIOD_M1 (Confirmation)"
input double met_dev_M1               = 0.001;
input int    met_dep_M1               = 1;

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
input double cry_dev_M15              = 1.0;
input int    cry_dep_M15              = 5;
input group "Crypto: PERIOD_M1 (Confirmation)"
input double cry_dev_M1               = 0.001;
input int    cry_dep_M1               = 1;

// Global objects via Pointers
SMCScannerConfig*       global_config;
CZoneMitigationEngine*  scanner_engine;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Zone Mitigation... Clean Architecture Enabled.");

   CLTFConfirmationEngine::m_fx_dev_m1 = fx_dev_M1;
   CLTFConfirmationEngine::m_fx_dep_m1 = fx_dep_M1;
   CLTFConfirmationEngine::m_mc_dev_m1 = cry_dev_M1;
   CLTFConfirmationEngine::m_mc_dep_m1 = cry_dep_M1;
   CLTFConfirmationEngine::m_fx_maxLookback = fx_maxLookback;
   CLTFConfirmationEngine::m_mc_maxLookback = cry_maxLookback;

   global_config = new SMCScannerConfig();
   global_config.scanSpeedPerSecond    = scanSpeedPerSecond;

   global_config.alertDemandZones      = alertDemandZones;
   global_config.alertSupplyZones      = alertSupplyZones;
   global_config.alertMitigDemandZones = alertMitigDemandZones;
   global_config.alertMitigSupplyZones = alertMitigSupplyZones;

   global_config.alertBullishOB        = alertBullishOB;
   global_config.alertBearishOB        = alertBearishOB;
   global_config.alertMitigBullishOB   = alertMitigBullishOB;
   global_config.alertMitigBearishOB   = alertMitigBearishOB;

   global_config.alertBullishPOI       = alertBullishPOI;
   global_config.alertBearishPOI       = alertBearishPOI;
   global_config.alertMitigBullishPOI  = alertMitigBullishPOI;
   global_config.alertMitigBearishPOI  = alertMitigBearishPOI;

   global_config.alertDemandFlipZones      = alertDemandFlipZones;
   global_config.alertSupplyFlipZones      = alertSupplyFlipZones;
   global_config.alertMitigDemandFlipZones = alertMitigDemandFlipZones;
   global_config.alertMitigSupplyFlipZones = alertMitigSupplyFlipZones;

   global_config.alertBullishBreaker   = alertBullishBreaker;
   global_config.alertBearishBreaker    = alertBearishBreaker;
   global_config.alertMitigBullishBreaker = alertMitigBullishBreaker;
   global_config.alertMitigBearishBreaker = alertMitigBearishBreaker;

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

   scanner_engine = new CZoneMitigationEngine();
   scanner_engine.Initialize(global_config);

   if(sendTestMockAlertOnStart)
     {
      SendDemoAlert();
     }

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   if(scanner_engine)
      delete scanner_engine;
   if(global_config)
      delete global_config;
   Print("🛑 SMC Global Scanner (ZigZag HL) Stopped.");
  }

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

// END FILE: Experts\Custom EAs\Alerting System\Zone Mitigation.mq5

// END FILE: Experts\Custom EAs\Alerting System\Zone Mitigation.mq5
