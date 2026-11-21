#define MARCO_LOG_PROGRAM "marco_backtest_ea"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                     marco_backtest_ea.mq5        |
//|                 Marcotrades Dual-TF LB/Inducement Simulator      |
//|                 Multi-Symbol & Multi-Timeframe Batch Processor   |
//|                 With Opposing Leg Filter & Dynamic TP Priorities |
//|                 With Overlapping Trade Concurrency Control       |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.73"

#include <Custom\Marcotrades\marco_backtest.mqh>
#include <Custom\General\WA_agent.mqh>
#include <Custom\General\report.mqh>

#ifndef ENUM_SL_LOCATION_DEF
#define ENUM_SL_LOCATION_DEF
enum ENUM_SL_LOCATION
  {
   SL_LOCATION_LB_BOUNDARIES,     // LB boundaries
   SL_LOCATION_CONFIRM_PIVOT      // Confirmation pivot
  };
#endif

input group "=== Strategy Simulator Config ==="
input datetime        InpStartWindow              = D'2026.11.16 00:00'; // Backtest Start Window (Date/Time)
input datetime        InpEndWindow                = D'2026.11.16 23:59'; // Backtest End Window (0 for Current Time)
input double          InpStartingCapital          = 500;               // Simulated Starting Capital ($)
input double          InpMaxRiskPercent           = 25.0;                // Risk per trade (% of selected capital)
input ENUM_MARCO_RISK_CAPITAL InpRiskCapital = RISK_CAPITAL_FREE_MARGIN; // Capital used by InpMaxRiskPercent
input bool            InpAllowOverlappingTrades = true; // Allow same-direction overlap (open trade >= 50% TP; never opposite)
input bool InpPreferLowerTFLB = true; // Prefer deeper qualified LTF LB overlapping same-direction HTF LB
input double          InpSLBufferPips             = 75.0;                 // SL Buffer outside Liquidity Block (Pips)
input string InpPipSizeOverrides = ""; // Price per pip overrides: US500=0.1;XAUUSD=0.01
input ENUM_MARCO_ENTRY_TF InpEntryTF = ENTRY_TF_M1; // Entry TF: M1 / LB TF (M1 always requires pivot confirmation)
input ENUM_MARCO_ENTRY_TIMING InpEntryTiming = ENTRY_PIVOT_CANDLE_EDGE; // Entry timing: next open / pivot candle edge
input ENUM_MARCO_IND_ENTRY_FILTER InpM1IndEntryFilter = IND_ENTRY_PRICE; // Skip IND on setup + entry TF: Pivot / Entry price / Either / Off
input ENUM_TIMEFRAMES InpTPTimeframe              = PERIOD_M1;           // Compatibility input: staged TP zones always use M1
input ENUM_TP_PRIORITY InpTPPriority1             = TP_PRIORITY_FALLBACK;     // TP Priority #1 Target (Opposing LB, IND, Fallback)
input ENUM_SL_LOCATION InpSLlocation              = SL_LOCATION_CONFIRM_PIVOT; // SL Location {LB boundaries, Confirmation pivot}
input bool            InpBlockLessRR              = false;                // Block trades where Priority 1 or 2 TP R:R < InpFallbackRR
input bool            InpUseFallbackTP            = true;                // Compatibility input: staged exits always include fallback RR
input double          InpFallbackRR               = 1.0;                 // Fallback R:R Multiple (e.g. 2.0 for 2R)
input int             InpScanSpeedPerSecond       = 15;                  // Number of simulations per tick
input bool            InpSendWhatsAppAlert        = true;                // Send Final Report to WhatsApp (Agent)
input bool            InpUseRecordedBrokerRejections = true;           // Exclude matching recorded broker-rejected attempts
input string          InpBrokerRejectionFile = "marcotrades\\BrokerExecution\\imported_rejections.csv"; // Optional imported log records (MQL5/Files)
input group "=== Take Profit Protection & Execution ==="
input bool             InpAdjustTPForSpread        = false;          // Adjust TP for Broker Spread (Pre-Trade)
input bool             InpEnableVicinityExit       = false;          // Enable 1-Pip TP Vicinity Rejection Exit
input double           InpTPVicinityPips           = 3.0;           // Vicinity Distance from TP (Pips)
input ENUM_TIMEFRAMES  InpTPVicinityTF             = PERIOD_M1;     // Rejection Candle Timeframe

input group "=== Strategy Settings==="
input bool            InpRequireZZConfirmation    = true;                // Require ZigZag Pivot inside Zone + Buffer
input bool            InpRiskyMode                = true;                // Risky Mode: Ignore pre-confirmation touches (trades 1st touch post-conf)
input int             InpMinTouches               = 2;                   // Min touches for Inducement qualification

input group "=== Liquidity Block Triggers ==="
input bool            InpTrackSweepsAnywhere      = true;                // Track TF-BL-LB-SSL & TF-BR-LB-BSL
input bool            InpTrackPostInducementCHoCH = true;                // Track TF-BL-LB-IND & TF-BR-LB-IND
input bool            InpApplyEntryLBPolicyToPreventionExits = true;    // Apply entry-qualified LB rules to prevention and position exits

input group "=== Inducement Rules ==="
input double          InpProximityPips            = 1.0;                 // Touch proximity buffer outside zone (Pips)
input bool            InpStrictOriginPivots       = true;                // Enforce Strict Origin (Buyers=Pivot Low, Sellers=Pivot High)

input group "=== Anti-Clustering & Zone Prolongation ==="
input bool            InpMergeClusteredZones      = true;                // Prolong single master inducement & prevent stacking
input double          InpClusterTolerancePips     = 5.0;                // Cluster tolerance range (Pips)
input bool            InpMergeExpandBounds        = false;               // Expand master boundaries to cover cluster

input group "=== SMC Zone Sources ==="
input bool            InpCheckDemandSupply        = true;                // Demand / Supply Zones
input bool            InpCheckOrderBlocks         = true;                // Order Blocks
input bool            InpCheckSwingPOIs           = true;                // Swing POIs
input bool            InpCheckFlipZones           = false;               // Flip Zones
input bool            InpCheckBreakers            = false;               // Breaker Blocks

input group "=== Structural ZigZag Configuration ==="
input double          InpDeviation                = 0.001;               // Price deviation for reversals (%)
input int             InpDepth                    = 1;                   // Lookback depth for structural swings
input string          InpPriceDiff                = "Absolute";          // Diff Mode (Absolute/Percent)

string target_symbols_base[] = {"XAUUSD", "XAGUSD", "US30", "US500", "USTEC", "USOIL", "UKOIL", "BTCUSD", "ETHUSD"};
ENUM_TIMEFRAMES target_timeframes[] = {PERIOD_M2, PERIOD_M3, PERIOD_M4,  PERIOD_M5, PERIOD_M10, PERIOD_M12, PERIOD_M15 };

CMarcoBacktestInstance* instances[];
CWhatsAppAgent          waAgent;
CBacktestReportManager  reportManager;

int      total_instances;
int      current_idx;
bool     is_finished;
datetime g_effective_end = 0;
bool     g_batch_initialized = false;
bool     g_preserve_chart_change = false;
string   g_batch_chart_symbol = "";

// Release a batch on removal, input changes, or a change of chart symbol.
void ClearBacktestBatch()
  {
   g_batch_initialized = false;
   g_preserve_chart_change = false;
   CMarcoBacktestInstance::ResetGlobalTrades();
   for(int i = 0; i < ArraySize(instances); i++)
     {
      if(CheckPointer(instances[i]) == POINTER_DYNAMIC)
         delete instances[i];
      instances[i] = NULL;
     }
   ArrayResize(instances, 0);
   total_instances = 0;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResolveBrokerSymbols(string &base_symbols[], string &actual_symbols[])
  {
   int cnt = 0;
   ArrayResize(actual_symbols, ArraySize(base_symbols));

   Print("======================================================");
   Print("🏦 BROKER & ACCOUNT DIAGNOSTICS (BACKTEST)");
   PrintFormat("   Company:  %s", AccountInfoString(ACCOUNT_COMPANY));
   PrintFormat("   Server:   %s", AccountInfoString(ACCOUNT_SERVER));
   PrintFormat("   Balance:  %.2f %s", AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoString(ACCOUNT_CURRENCY));
   Print("======================================================");

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
//|                                                                  |
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
   if(g_preserve_chart_change && g_batch_initialized)
     {
      g_preserve_chart_change = false;
      if(g_batch_chart_symbol == _Symbol)
        {
         // EA globals survive a chart timeframe change: retain results and batch position.
         if(!is_finished)
            EventSetTimer(1);
         Print("[BACKTEST] Chart timeframe changed; existing batch retained.");
         return(INIT_SUCCEEDED);
        }
      // REASON_CHARTCHANGE also covers symbol changes; those still start a fresh batch.
      ClearBacktestBatch();
     }

   Print("🚀 Initializing Marcotrades SMC Multi-Timeframe Backtester...");
   if(!CMarcoBrokerExecution::Configure(InpUseRecordedBrokerRejections,InpBrokerRejectionFile)) return INIT_FAILED;

// FIX: Reset static global trade registry across runs
   CMarcoBacktestInstance::ResetGlobalTrades();

   g_effective_end = (InpEndWindow == 0) ? TimeCurrent() : InpEndWindow;
   if(InpStartWindow >= g_effective_end)
     {
      PrintFormat("❌ INIT FAILED: StartWindow (%s) must be earlier than EndWindow (%s)!",
                  TimeToString(InpStartWindow, TIME_DATE|TIME_MINUTES),
                  TimeToString(g_effective_end, TIME_DATE|TIME_MINUTES));
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpSendWhatsAppAlert)
     {
      waAgent.Init();
     }

   string actual_symbols[];
   ResolveBrokerSymbols(target_symbols_base, actual_symbols);

   int num_symbols = ArraySize(actual_symbols);
   int num_tfs     = ArraySize(target_timeframes);

   if(num_symbols == 0)
     {
      Print("❌ INIT FAILED: No target symbols resolved on this broker!");
      return(INIT_FAILED);
     }

   total_instances = num_symbols * num_tfs;
   ArrayResize(instances, total_instances);
   current_idx = 0;
   is_finished = false;

   reportManager.Reset(InpStartingCapital);
   reportManager.SetExecutionNote(InpUseRecordedBrokerRejections ?
      "Recorded broker rejections excluded when symbol, setup and entry minute match. Volume rejections apply only to the rejected lot size. Unrecorded entries remain simulated." :
      "Independent simulation: recorded live broker rejections are not applied.");

   int inst_counter = 0;
   for(int s = 0; s < num_symbols; s++)
     {
      SymbolSelect(actual_symbols[s], true);

      for(int t = 0; t < num_tfs; t++)
        {
         instances[inst_counter] = new CMarcoBacktestInstance();
         instances[inst_counter].Init(
            actual_symbols[s], target_timeframes[t], InpTPTimeframe, InpStartingCapital,
            InpMaxRiskPercent, InpSLBufferPips, InpDepth, InpDeviation,
            InpStartWindow, InpEndWindow, InpRequireZZConfirmation, InpRiskyMode,
            InpUseFallbackTP, InpFallbackRR, InpPriceDiff, InpBlockLessRR, InpTPPriority1,
            InpAllowOverlappingTrades, InpSLlocation, InpAdjustTPForSpread, InpEnableVicinityExit, InpTPVicinityPips, InpEntryTF, InpTPVicinityTF,
            InpApplyEntryLBPolicyToPreventionExits
         );
         inst_counter++;
        }
     }

   string p1Str = "IND";
   if(InpTPPriority1 == TP_PRIORITY_LB)
      p1Str = "LB";
   else
      if(InpTPPriority1 == TP_PRIORITY_FALLBACK)
         p1Str = "Fallback";

   PrintFormat("⚙ Total Scenarios: %d | Window: %s -> %s | TP #1: %s | Overlapping Trades: %s | Block < FallbackRR: %s",
               total_instances,
               TimeToString(InpStartWindow, TIME_DATE|TIME_MINUTES),
               TimeToString(g_effective_end, TIME_DATE|TIME_MINUTES),
               p1Str,
               InpAllowOverlappingTrades ? "ALLOWED" : "BLOCKED",
               InpBlockLessRR ? "ENABLED" : "DISABLED");

   g_batch_chart_symbol = _Symbol;
   g_batch_initialized = true;
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   if(reason == REASON_CHARTCHANGE && g_batch_initialized)
     {
      // Defer cleanup until OnInit can distinguish a timeframe change from a symbol change.
      g_preserve_chart_change = true;
      return;
     }
   ClearBacktestBatch();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SMarcoSimulationConfig ClusterSimulationConfig()
  {
   SMarcoSimulationConfig c;
   c.sweeps=InpTrackSweepsAnywhere; c.postInd=InpTrackPostInducementCHoCH;
   c.touches=InpMinTouches; c.proximity=InpProximityPips; c.strictOrigin=InpStrictOriginPivots;
   c.merge=InpMergeClusteredZones; c.tolerance=InpClusterTolerancePips; c.expand=InpMergeExpandBounds;
   c.ds=InpCheckDemandSupply; c.ob=InpCheckOrderBlocks; c.sp=InpCheckSwingPOIs;
   c.fz=InpCheckFlipZones; c.bb=InpCheckBreakers;
   return c;
  }

void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(is_finished)
      return;

   // Simulate one symbol's setup timeframes together, then publish their results.
   if(current_idx<total_instances && !instances[current_idx].m_simComplete)
     {
      int end=current_idx+1;
      while(end<total_instances && instances[end].m_symbol==instances[current_idx].m_symbol) end++;
      SMarcoSimulationConfig c=ClusterSimulationConfig();
      if(!CMarcoSimulationBatch::Pump(instances,current_idx,end,c,250)) return;
     }
   int processed = 0;
   while(processed < InpScanSpeedPerSecond && current_idx < total_instances)
     {
      CMarcoBacktestInstance* inst = instances[current_idx];
      if(!inst.m_simComplete) break;
      PrintFormat("🛑 [%d/%d] Running Full Dual-TF Simulation for: %s on %s...",
                  current_idx + 1, total_instances, inst.m_symbol, EnumToString(inst.m_tradeTF));

      bool success = inst.RunSimulation(
                        InpTrackSweepsAnywhere, InpTrackPostInducementCHoCH,
                        InpMinTouches, InpProximityPips, InpStrictOriginPivots,
                        InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds,
                        InpCheckDemandSupply, InpCheckOrderBlocks, InpCheckSwingPOIs,
                        InpCheckFlipZones, InpCheckBreakers
                     );
      if(success)
        {
         int totalTrades = ArraySize(inst.m_trades);
         int openTrades = totalTrades - inst.m_wins - inst.m_losses;
         double winRate = (totalTrades > 0) ? ((double)inst.m_wins / totalTrades) * 100.0 : 0.0;
         double netProfit = inst.m_currentBalance - inst.m_startCapital;
         double contracts = inst.m_totalLots;
         double rewards   = inst.m_totalRewards;

         string setups    = "";
         string timeslots = "";
         for(int t = 0; t < ArraySize(inst.m_trades); t++)
           {
            string oT = TimeToString(inst.m_trades[t].openTime, TIME_DATE | TIME_MINUTES);
            if(timeslots != "")
               timeslots += "<br style=\"mso-data-placement:same-cell;\" />";

            if(inst.m_trades[t].outcome == "OPEN")
               timeslots += "<span style=\"background-color:#FFF59D; color:#7A5A00; font-weight:bold;\">" + oT + "</span>";
            else
              {
               string cT = TimeToString(inst.m_trades[t].closeTime, TIME_DATE | TIME_MINUTES);
               timeslots += oT + " &rarr; " + cT;
              }

            if(setups != "")
               setups += "<br style=\"mso-data-placement:same-cell;\" />";
            setups += inst.m_trades[t].setupType;
           }
         if(setups == "")
            setups = "-";
         if(timeslots == "")
            timeslots = "-";

         reportManager.AddScenarioResult(inst.m_symbol, inst.m_tradeTF, totalTrades, inst.m_wins, inst.m_losses, openTrades, winRate, contracts, rewards, setups, timeslots, inst.m_currentBalance, netProfit);

         PrintFormat("✅  Simulation complete for %s %s | Trades: %d | Contracts: %.2f L | Rewards: %+.2fR | Final Balance: $%.2f",
                     inst.m_symbol, StringSubstr(EnumToString(inst.m_tradeTF), 7), totalTrades, contracts, rewards, inst.m_currentBalance);
        }
      else
        {
         PrintFormat("❌ Simulation skipped (Insufficient history) for %s on %s", inst.m_symbol, EnumToString(inst.m_tradeTF));
        }

      current_idx++;
      processed++;
     }

   if(current_idx >= total_instances)
     {
      is_finished = true;

      string savedFileName = "";
      string waCaption     = "";

      if(reportManager.GenerateAndSave("marcotrades", "Marcotrades_DualTF_Backtest", InpStartWindow, g_effective_end, savedFileName, waCaption))
        {
         if(InpSendWhatsAppAlert)
           {
            Print("📤 Dispatching Bordered Report to WhatsApp...");
            waAgent.SendMessageWithFile(savedFileName, waCaption, "document", "application/vnd.ms-excel");
           }
        }

      Print("🎉 Multi-Timeframe Backtest batch fully complete!");
      EventKillTimer();
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Backtesting\marco_backtest_ea.mq5
