#define MARCO_LOG_PROGRAM "marco_live_auto_ea"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                         marco_live_auto_ea.mq5   |
//|                 Live Dual-Timeframe SMC Automated Trader         |
//|                 With RiskyMode & Strict Freshness Engine         |
//|                 With Symbol Suffix Resolver & Limit Mode         |
//|                 With Daily CSV Journal & Dynamic TP Priorities   |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.52"

#include <Custom\Marcotrades\marco_live_auto.mqh>

// Guard: Guarantees ENUM_TP_PRIORITY is defined before inputs
#ifndef ENUM_TP_PRIORITY_DEF
#define ENUM_TP_PRIORITY_DEF
enum ENUM_TP_PRIORITY
  {
   TP_PRIORITY_LB,       // Opposing LB (Liquidity Block)
   TP_PRIORITY_IND,      // Opposing IND (Inducement)
   TP_PRIORITY_FALLBACK  // Fallback R:R
  };
#endif
#ifndef ENUM_SL_LOCATION_DEF
#define ENUM_SL_LOCATION_DEF
enum ENUM_SL_LOCATION
  {
   SL_LOCATION_LB_BOUNDARIES,     // LB boundaries
   SL_LOCATION_CONFIRM_PIVOT      // Confirmation pivot
  };
#endif
input group "=== Live EA Time Controls ==="
input string           InpStartTime                = "00:00";       // Daily Entry Session Start (HH:MM)
input string           InpEndTime                  = "23:59";       // Daily Report Time (HH:MM; structure is retained)
input int              InpScanSpeedPerSecond       = 20;            // Number of simulations per tick

input group "=== WhatsApp Alerts ==="
input bool             InpSendWhatsAppAlert        = true;          // Send Final Report to WhatsApp (Agent)

input group "=== Risk & Guardrails ==="
input double           InpMaxRiskPercent           = 25.0;          // Risk per trade (% of selected capital)
input ENUM_MARCO_RISK_CAPITAL InpRiskCapital = RISK_CAPITAL_FREE_MARGIN; // Capital used by InpMaxRiskPercent
input bool             InpBlockManualTrade         = true;          // Block/Kill Unauthorized Manual Trades
input bool             InpAllowOverlappingTrades = true; // Allow same-direction overlap (open trade >= 50% TP; never opposite)
input bool InpPreferLowerTFLB = true; // Prefer deeper qualified LTF LB overlapping same-direction HTF LB
input ulong            InpMagicNumber              = 778899;        // EA Magic Number
input group "=== Take Profit Protection & Execution ==="
input bool             InpAdjustTPForSpread        = true;          // Adjust TP for Broker Spread (Pre-Trade)
input bool             InpEnableVicinityExit       = true;          // Enable 1-Pip TP Vicinity Rejection Exit
input double           InpTPVicinityPips           = 3.0;           // Vicinity Distance from TP (Pips)
input ENUM_TIMEFRAMES  InpTPVicinityTF             = PERIOD_M1;     // Rejection Candle Timeframe

input group "=== Strategy Execution Models ==="
input ENUM_MARCO_ENTRY_TF InpEntryTF = ENTRY_TF_M1; // Entry TF: M1 / LB TF (M1 always requires pivot confirmation)
input ENUM_MARCO_ENTRY_TIMING InpEntryTiming = ENTRY_AFTER_CONFIRMATION; // Entry timing: next open / pivot candle edge
input ENUM_MARCO_IND_ENTRY_FILTER InpM1IndEntryFilter = IND_ENTRY_PRICE; // Skip IND on setup + entry TF: Pivot / Entry price / Either / Off
input ENUM_TIMEFRAMES  InpTPTimeframe              = PERIOD_M1;     // Compatibility input: staged TP zones always use M1
input ENUM_TP_PRIORITY InpTPPriority1              = TP_PRIORITY_FALLBACK; // TP Priority #1 Target (Opposing LB, IND, Fallback)
input ENUM_SL_LOCATION InpSLlocation               = SL_LOCATION_CONFIRM_PIVOT; // SL Location {LB boundaries, Confirmation pivot}
input bool             InpBlockLessRR              = false;         // Block trades where Priority 1 or 2 TP R:R < InpFallbackRR
input bool             InpUseFallbackTP            = true;          // Compatibility input: staged exits always include fallback RR
input double           InpFallbackRR               = 1.0;           // Fallback R:R Ratio (e.g., 2.0 for 2R)
input double           InpSLBufferPips             = 75.0;           // SL Buffer outside Liquidity Block (Pips)
input string InpPipSizeOverrides = ""; // Price per pip overrides: US500=0.1;XAUUSD=0.01
input bool             InpRequireZZConfirmation    = true;          // Require ZigZag Pivot inside Zone (false = Limit Orders)
input bool             InpRiskyMode                = true;          // Risky Mode: Ignore pre-confirmation touches (trades 1st touch post-conf)
input int              InpMinTouches               = 2;             // Min touches for Inducement qualification
input double           InpDeviation                = 0.001;         // ZigZag Deviation
input int              InpDepth                    = 1;             // ZigZag Depth
input string           InpPriceDiff                = "Absolute";    // Diff Mode (Absolute/Percent)

input group "=== Liquidity Block Triggers ==="
input bool             InpTrackSweepsAnywhere      = true;          // Track TF-BL-LB-SSL & TF-BR-LB-BSL
input bool             InpTrackPostInducementCHoCH = true;          // Track TF-BL-LB-IND & TF-BR-LB-IND
input bool             InpApplyEntryLBPolicyToPreventionExits = true; // Apply entry-qualified LB rules to prevention and position exits
input double           InpProximityPips            = 1.0;           // Touch proximity buffer outside zone (Pips)
input bool             InpStrictOriginPivots       = true;          // Enforce Strict Origin (Buyers=Pivot Low, Sellers=Pivot High)

input group "=== Anti-Clustering & Zone Prolongation ==="
input bool             InpMergeClusteredZones      = true;          // Prolong single master inducement & prevent stacking
input double           InpClusterTolerancePips     = 5.0;          // Cluster tolerance range (Pips)
input bool             InpMergeExpandBounds        = false;         // Expand master boundaries to cover cluster

input group "=== SMC Zone Sources ==="
input bool             InpCheckDemandSupply        = true;          // Demand / Supply Zones
input bool             InpCheckOrderBlocks         = true;          // Order Blocks
input bool             InpCheckSwingPOIs           = true;          // Swing POIs
input bool             InpCheckFlipZones           = false;         // Flip Zones
input bool             InpCheckBreakers            = false;         // Breaker Blocks

// Base Multi-Asset Definitions (Clean Suffix-Free Names)
string target_symbols_base[] = {"XAUUSD", "XAGUSD", "US30", "US500", "USTEC", "USOIL", "UKOIL", "BTCUSD", "ETHUSD"};
ENUM_TIMEFRAMES target_timeframes[] = {PERIOD_M2, PERIOD_M3, PERIOD_M4,  PERIOD_M5, PERIOD_M10, PERIOD_M12, PERIOD_M15 };

// Master Engine Instance
CMarcoLiveAutoEngine  LiveAutoEngine;

//+------------------------------------------------------------------+
//| Auto-Detect Symbol Suffix & Display Broker Diagnostics           |
//+------------------------------------------------------------------+
void ResolveBrokerSymbols(string &base_symbols[], string &actual_symbols[])
  {
   int cnt = 0;
   ArrayResize(actual_symbols, ArraySize(base_symbols));

   Print("======================================================");
   Print("🏦 BROKER & ACCOUNT DIAGNOSTICS (LIVE AUTO)");
   PrintFormat("   Company:  %s", AccountInfoString(ACCOUNT_COMPANY));
   PrintFormat("   Server:   %s", AccountInfoString(ACCOUNT_SERVER));
   PrintFormat("   Balance:  %.2f %s", AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoString(ACCOUNT_CURRENCY));
   PrintFormat("   Equity:   %.2f %s", AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoString(ACCOUNT_CURRENCY));
   PrintFormat("   Leverage: 1:%d", (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
   Print("======================================================");
   Print("🔎 SYMBOL RESOLUTION & SPECIFICATIONS");

   for(int i = 0; i < ArraySize(base_symbols); i++)
     {
      string base = base_symbols[i];
      string match = base;
      bool found = false;

      for(int s = 0; s < SymbolsTotal(false); s++)
        {
         string sym = SymbolName(s, false);
         if(StringFind(sym, base) == 0 && StringLen(sym) <= StringLen(base) + 5)
           {
            match = sym;
            found = true;
            break;
           }
        }

      if(!found)
        {
         for(int s = 0; s < SymbolsTotal(false); s++)
           {
            string sym = SymbolName(s, false);
            if(StringFind(sym, base) >= 0 && StringLen(sym) <= StringLen(base) + 6)
              {
               match = sym;
               found = true;
               break;
              }
           }
        }

      if(found)
        {
         SymbolSelect(match, true);
         actual_symbols[cnt++] = match;
         string suffix = (StringLen(match) > StringLen(base)) ? StringSubstr(match, StringLen(base)) : "(None)";
         PrintFormat("   ✅ %s mapped to -> %s [Suffix: %s]", base, match, suffix);
        }
      else
        {
         PrintFormat("   ❌ %s -> No matching symbol found on this broker!", base);
        }
     }
   ArrayResize(actual_symbols, cnt);
   Print("======================================================");
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   if(!CMarcoRiskCapital::Configure(InpRiskCapital)) return INIT_PARAMETERS_INCORRECT;
   if(!CMarcoSymbolUnits::Configure(InpPipSizeOverrides)) return INIT_PARAMETERS_INCORRECT;
   CMarcoIndEntryFilter::Configure(InpM1IndEntryFilter);
   CMarcoPivotEntry::Configure(InpEntryTiming);
   CMarcoLBTFPreference::Configure(InpPreferLowerTFLB);
   if(!MathIsValidNumber(InpFallbackRR) || InpFallbackRR<=0)
     { Print("[TP CONFIG] InpFallbackRR must be positive for staged exits."); return INIT_PARAMETERS_INCORRECT; }
   Print("🚀 Booting Marcotrades LIVE SMC Auto-Trader...");

   string actual_symbols[];
   ResolveBrokerSymbols(target_symbols_base, actual_symbols);

   if(ArraySize(actual_symbols) == 0)
     {
      Print("❌ INIT FAILED: No target symbols resolved on this broker!");
      return(INIT_FAILED);
     }

   LiveAutoEngine.Init(
      actual_symbols,
      target_timeframes,
      InpTPTimeframe,
      InpScanSpeedPerSecond,
      InpSendWhatsAppAlert,
      InpStartTime,
      InpEndTime,
      InpMaxRiskPercent,
      InpSLBufferPips,
      InpDepth,
      InpDeviation,
      InpMagicNumber,
      InpBlockManualTrade,
      InpTrackSweepsAnywhere,
      InpTrackPostInducementCHoCH,
      InpMinTouches,
      InpProximityPips,
      InpStrictOriginPivots,
      InpMergeClusteredZones,
      InpClusterTolerancePips,
      InpMergeExpandBounds,
      InpCheckDemandSupply,
      InpCheckOrderBlocks,
      InpCheckSwingPOIs,
      InpCheckFlipZones,
      InpCheckBreakers,
      InpRiskyMode,
      InpRequireZZConfirmation,
      InpUseFallbackTP,
      InpFallbackRR,
      InpPriceDiff,
      InpBlockLessRR,
      InpTPPriority1,
      InpAllowOverlappingTrades, 
      InpSLlocation,
      InpAdjustTPForSpread,
      InpEnableVicinityExit,
      InpTPVicinityPips,
      InpTPVicinityTF,
      InpEntryTF,
      InpApplyEntryLBPolicyToPreventionExits
   );
   if(InpEntryTF == ENTRY_TF_M1)
     {
      if(!EventSetMillisecondTimer(100))
         return(INIT_FAILED);
     }
   else
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
   LiveAutoEngine.Deinit();
   Print("🛑 Marcotrades LIVE Auto-Trader safely shut down.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
   LiveAutoEngine.OnTick();
  }

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   LiveAutoEngine.CheckDailyRollover();
   if(InpEntryTF == ENTRY_TF_M1)
      LiveAutoEngine.OnTick();
  }

//+------------------------------------------------------------------+
//| Expert trade transaction function                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   LiveAutoEngine.OnTradeTransaction(trans, request, result);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Marcotrades\marco_live_auto_ea.mq5
