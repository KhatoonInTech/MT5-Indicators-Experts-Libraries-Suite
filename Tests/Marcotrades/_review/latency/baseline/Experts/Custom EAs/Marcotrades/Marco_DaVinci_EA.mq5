#define MARCO_LOG_PROGRAM "Marco_DaVinci_EA"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                  Experts\Custom EAs\Marcotrades\Marco_DaVinci_EA.mq5|
//|         Marco Strategy Auto-Trader with Guardrails Shield Engine |
//+------------------------------------------------------------------+
#property copyright "Inter Equity / Da Vinci Architecture"
#property link      "https://interequitytrading.com"
#property version   "4.10"
#property description "Automated Da Vinci Liquidity Model with Guardrails Risk Shield"

#include <Trade\Trade.mqh>
#include <Custom\Guardrails\Guardrails_Protection.mqh>
#include <Custom\Marcotrades\marco_core.mqh>

// ==================================================================
// 1. STRATEGY EXECUTION
// ==================================================================
input group "=== Marco Strategy Execution ==="
input ENUM_TIMEFRAMES InpSetupTF             = PERIOD_M15; // Setup Timeframe (M15 or H1 for Macro Structure)
input double          InpTargetRR            = 3.0;        // Minimum Risk-to-Reward Ratio

// ==================================================================
// 2. GUARDRAILS RISK SHIELD & SIZING
// ==================================================================
input group "=== Guardrails 1% Risk & Position Guard ==="
input double          InpMaxRiskPercent      = 1.0;        // Max Risk per Trade (% Balance)
input bool            InpEnforceMaxLot       = true;       // Strict Gatekeeper: Block Oversized Lots
input bool            InpCircuitBreaker      = false;      // Emergency Cut if floating loss hits max risk
input bool            InpAutoBreakeven       = true;       // Move SL to Breakeven when internal target reached
input int             InpBreakevenBuffer     = 0;          // Points to cover commission on Breakeven
input double          InpBreakevenSpreadMult = 10.0;       // Distance required for BE (x Spread)

input group "=== Marco Profit-Taking Guardrail ==="
input bool            InpEnableProfitGuard   = true;       // Enable Scaling at Internal Liquidity Pools
input double          InpTPActivationPct     = 50.0;       // Armed once position reaches profit threshold
input double          InpGivebackPct         = 15.0;       // Scale out if pullback from peak exceeds %
input double          InpPartialPct          = 50.0;       // Scale out 50% at Internal Liquidity

// ==================================================================
// 3. SESSION TIMING
// ==================================================================
input group "=== Session Execution Filter ==="
input bool            InpUseSessionFilter    = true;       // Enable Session Constraints?
input int             InpStartHourUTC        = 7;          // London Pre-Market Open (UTC)
input int             InpEndHourUTC          = 18;         // NY Close (UTC)

// ==================================================================
// 4. MULTI-ASSET ZIGZAG PARAMETERS
// ==================================================================
input group "=== Asset Category ==="
input ENUM_ASSET_TYPE InpAssetCategory        = ASSET_TYPE_AUTO;

input group "--- For Forex Pairs ---"
input int    fx_maxLookback                   = 1000;
input double fx_dev_D1                        = 1.0;
input int fx_dep_D1  = 15;
input double fx_dev_H4                        = 0.5;
input int fx_dep_H4  = 2;
input double fx_dev_H1                        = 0.5;
input int fx_dep_H1  = 15;
input double fx_dev_M15                       = 0.5;
input int fx_dep_M15 = 5;
input double fx_dev_M1                        = 0.001;
input int fx_dep_M1  = 1;

input group "--- For Metals Pairs ---"
input int    met_maxLookback                  = 1000;
input double met_dev_D1                       = 5.0;
input int met_dep_D1  = 15;
input double met_dev_H4                       = 5.0;
input int met_dep_H4  = 15;
input double met_dev_H1                       = 1.0;
input int met_dep_H1  = 15;
input double met_dev_M15                      = 1.0;
input int met_dep_M15 = 5;
input double met_dev_M1                       = 0.001;
input int met_dep_M1  = 1;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback                  = 1000;
input double cry_dev_D1                       = 5.0;
input int cry_dep_D1  = 15;
input double cry_dev_H4                       = 5.0;
input int cry_dep_H4  = 15;
input double cry_dev_H1                       = 1.0;
input int cry_dep_H1  = 15;
input double cry_dev_M15                      = 1.0;
input int cry_dep_M15 = 5;
input double cry_dev_M1                       = 0.001;
input int cry_dep_M1  = 1;

CGuardrailsProtection Guardrails;
CMarcoCoreLogic       MarcoEngine;
CTrade                TradeEngine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing ZigZag-Driven Marco Strategy EA with Guardrails Shield...");

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

// Initialize Guardrails Protection Framework
   Guardrails.OnInit(true, true, true, true,
                     true, true, true, false, true,
                     false, clrGold, true, false, false, false, "Percent",
                     false, false,
                     112233, InpEnforceMaxLot, 100.0,
                     true, true, true,
                     InpMaxRiskPercent, InpCircuitBreaker,
                     InpAutoBreakeven, InpBreakevenBuffer, true, InpBreakevenSpreadMult,
                     InpEnableProfitGuard, InpTPActivationPct, InpGivebackPct, InpPartialPct, true, true,
                     ZONE_SELECT_SWING_POIS, InpAssetCategory, zz);

// Initialize Marco Strategy Engine
   MarcoEngine.Init(_Symbol, InpSetupTF, InpAssetCategory, zz,
                    false, clrGold, true, false, true, true, true, true);

   TradeEngine.SetExpertMagicNumber(112233);
   TradeEngine.SetMarginMode();
   TradeEngine.SetTypeFillingBySymbol(_Symbol);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   Guardrails.OnDeinit(reason);
   MarcoEngine.Cleanup();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
// 1. Run Guardrails Shield (BE management, partials, circuit breaker)
   Guardrails.RunMasterShield();

// 2. Session Filter
   if(InpUseSessionFilter)
     {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      if(dt.hour < InpStartHourUTC || dt.hour >= InpEndHourUTC)
         return;
     }

// Single open trade limit per symbol
   if(PositionsTotal() > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return;
        }
     }

// 3. Scan Rates & Check for Confirmed ZigZag Setups
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, InpSetupTF, 0, 300, rates);
   if(copied < 40)
      return;

   datetime r_time[];
   double r_open[], r_high[], r_low[], r_close[];
   long r_vol[];
   ArrayResize(r_time, copied);
   ArrayResize(r_open, copied);
   ArrayResize(r_high, copied);
   ArrayResize(r_low, copied);
   ArrayResize(r_close, copied);
   ArrayResize(r_vol, copied);

   for(int k = 0; k < copied; k++)
     {
      r_time[k]  = rates[k].time;
      r_open[k]  = rates[k].open;
      r_high[k]  = rates[k].high;
      r_low[k]   = rates[k].low;
      r_close[k] = rates[k].close;
      r_vol[k]   = rates[k].tick_volume;
     }

   bool buyTriggered = false, sellTriggered = false;
   SMarcoSignal buySetup, sellSetup;

   MarcoEngine.UpdatePivots(copied, r_time, r_open, r_high, r_low, r_close, r_vol,
                            buyTriggered, sellTriggered, buySetup, sellSetup);

// 4. Execute Buy Trade via Guardrails Sizing
   if(buyTriggered)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = buySetup.sl_price;
      double tp  = buySetup.tp2_major;

      double safeLot = Guardrails.CalculateMaxAllowedLot(_Symbol, 1, ask);
      if(safeLot <= 0.0)
         safeLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      TradeEngine.SetAsyncMode(false);
      TradeEngine.Buy(safeLot, _Symbol, ask, sl, tp, "Marco DaVinci Long");
      PrintFormat("🎯 MARCO LONG EXECUTED: %.2f L at %.5f (SL: %.5f | TP: %.5f)", safeLot, ask, sl, tp);
     }

// 5. Execute Sell Trade via Guardrails Sizing
   if(sellTriggered)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = sellSetup.sl_price;
      double tp  = sellSetup.tp2_major;

      double safeLot = Guardrails.CalculateMaxAllowedLot(_Symbol, -1, bid);
      if(safeLot <= 0.0)
         safeLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      TradeEngine.SetAsyncMode(false);
      TradeEngine.Sell(safeLot, _Symbol, bid, sl, tp, "Marco DaVinci Short");
      PrintFormat("🎯 MARCO SHORT EXECUTED: %.2f L at %.5f (SL: %.5f | TP: %.5f)", safeLot, bid, sl, tp);
     }
  }

//+------------------------------------------------------------------+
//| Chart Event Dispatcher (Forwarded to Guardrails Panel)           |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   Guardrails.OnChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Marcotrades\Marco_DaVinci_EA.mq5

// END FILE: Experts\Custom EAs\Marcotrades\Marco_DaVinci_EA.mq5
