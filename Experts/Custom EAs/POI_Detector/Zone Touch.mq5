//+------------------------------------------------------------------+
//|                                             Expert\zone_touch.mq5|
//|        SMC Multi-Symbol Wick Touch Alert Engine based on Bid/Ask |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.13"

#include <ZigZag\zone_touch.mqh>

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

// ==================================================================
// ZIG ZAG & CORE SETTINGS
// ==================================================================
input group "--- For Forex Pairs ---"
input int    fx_maxLookback          = 10000;
input group "Forex: PERIOD_D1"
input double fx_dev_D1               = 1.0;
input int    fx_dep_D1               = 15;
input group "Forex: PERIOD_H4"
input double fx_dev_H4               = 1.0;
input int    fx_dep_H4               = 15;
input group "Forex: PERIOD_H1"
input double fx_dev_H1               = 0.5;
input int    fx_dep_H1               = 15;
input group "Forex: PERIOD_M15"
input double fx_dev_M15              = 0.5;
input int    fx_dep_M15              = 5;

input group "--- For Metals/Crypto Pairs ---"
input int    mc_maxLookback          = 10000;
input group "Metals/Crypto: PERIOD_D1"
input double mc_dev_D1               = 5.0;
input int    mc_dep_D1               = 15;
input group "Metals/Crypto: PERIOD_H4"
input double mc_dev_H4               = 5.0;
input int    mc_dep_H4               = 15;
input group "Metals/Crypto: PERIOD_H1"
input double mc_dev_H1               = 1.0;
input int    mc_dep_H1               = 15;
input group "Metals/Crypto: PERIOD_M15"
input double mc_dev_M15              = 1.0;
input int    mc_dep_M15              = 5;


// Global objects via Pointers
SMCScannerConfig*       global_config;
CZoneMitigationEngine*  scanner_engine;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("?? Initializing SMC Global Scanner (Bid/Ask Logic)... Clean Architecture Enabled.");

// 1. Instantiate the config object and populate it with user inputs
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

   global_config.fx_maxLookback        = fx_maxLookback;
   global_config.fx_dev_D1             = fx_dev_D1;
   global_config.fx_dep_D1  = fx_dep_D1;
   global_config.fx_dev_H4             = fx_dev_H4;
   global_config.fx_dep_H4  = fx_dep_H4;
   global_config.fx_dev_H1             = fx_dev_H1;
   global_config.fx_dep_H1  = fx_dep_H1;
   global_config.fx_dev_M15            = fx_dev_M15;
   global_config.fx_dep_M15 = fx_dep_M15;

   global_config.mc_maxLookback        = mc_maxLookback;
   global_config.mc_dev_D1             = mc_dev_D1;
   global_config.mc_dep_D1  = mc_dep_D1;
   global_config.mc_dev_H4             = mc_dev_H4;
   global_config.mc_dep_H4  = mc_dep_H4;
   global_config.mc_dev_H1             = mc_dev_H1;
   global_config.mc_dep_H1  = mc_dep_H1;
   global_config.mc_dev_M15            = mc_dev_M15;
   global_config.mc_dep_M15 = mc_dep_M15;

// 2. Instantiate and run the Engine, passing the pointer
   scanner_engine = new CZoneMitigationEngine();
   scanner_engine.Initialize(global_config); // CDailyReporter fires from inside this automatically

   if(sendTestMockAlertOnStart)
     {
      SendDemoAlert();
     }

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(scanner_engine)
      delete scanner_engine;
   if(global_config)
      delete global_config;
   Print("?? SMC Global Scanner (Bid/Ask) Stopped.");
  }

//+------------------------------------------------------------------+
//| OnTimer Event - Passes execution directly to the Engine          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(scanner_engine)
     {
      scanner_engine.ProcessBatch();
     }
  }
