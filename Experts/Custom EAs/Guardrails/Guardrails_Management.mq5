#define MARCO_LOG_PROGRAM "Guardrails_Management"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                    Guardrails_Management.mq5     | 
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "12.00"
#property description "Main Expert Advisor - Guardrails Risk Controller"

// Include the computation engine
#include <Custom\Guardrails\Guardrails_Management.mqh>

//--- Input Parameters
input group "=== Demand Zone Settings ==="
input double   InpDemandTop              = 0.00000;  // Demand Zone Top Price (e.g., 1.10500)
input double   InpDemandBottom           = 0.00000;  // Demand Zone Bottom Price (e.g., 1.10000)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Zone Protection (Inside Zone) ==="
input bool     InpBlockShorts            = true;     // Instantly close/delete shorts inside zone?
input ulong    InpMagicNumber            = 0;        // Magic Number (0 = applies to Manual Trades)

input group "=== Option B: Pre-Trade Lot Enforcer ==="
input bool     InpEnforceMaxLot          = true;     // [Option B] Abort trade if lot size is oversized?
input double   InpMaxSpreadShareOfRisk   = 100.0;    // Max spread cost allowed (% of 1% risk, 100 = 1% max)
input bool     InpShowOnChartHUD         = true;     // Show live Max Safe Lot HUD on chart?

input group "=== Option C: Spread-Excluded Risk Shield ==="
input bool     InpExcludeSpreadFromRisk  = true;     // [Option C] Measure 1% market move AFTER spread?
input double   InpMaxRiskPercent         = 1.0;      // Max Account Loss allowed (1.0 = 1%)
input bool     InpEmergencyCircuitBreaker= true;     // Force-close if floating loss hits 1%?

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Auto Breakeven (Outside Zone) ==="
input bool     InpAutoBreakeven          = true;     // Move SL to Entry Price when in profit?
input int      InpBreakevenBuffer        = 0;        // Extra buffer in points (e.g., 5 to cover commission)

//--- Instantiate master engine
CGuardrailsProtection Guardrails;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   return Guardrails.OnInit(InpDemandTop, InpDemandBottom, InpBlockShorts, InpMagicNumber,
                            InpEnforceMaxLot, InpMaxSpreadShareOfRisk, InpShowOnChartHUD,
                            InpExcludeSpreadFromRisk, InpMaxRiskPercent, InpEmergencyCircuitBreaker,
                            InpAutoBreakeven, InpBreakevenBuffer);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   Guardrails.OnDeinit(reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
   Guardrails.OnTick();
  }

//+------------------------------------------------------------------+
//| Trade event function                                             |
//+------------------------------------------------------------------+
void OnTrade()
  {
   Guardrails.OnTrade();
  }

//+------------------------------------------------------------------+
//| Trade transaction function (Catches SL Hits & Deal Closures)     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   Guardrails.OnTradeTransaction(trans, request, result);
  }

//+------------------------------------------------------------------+
//| Chart event function (Mouse clicks & dragging)                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   Guardrails.OnChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Guardrails\Guardrails_Management.mq5

// END FILE: Experts\Custom EAs\Guardrails\Guardrails_Management.mq5
