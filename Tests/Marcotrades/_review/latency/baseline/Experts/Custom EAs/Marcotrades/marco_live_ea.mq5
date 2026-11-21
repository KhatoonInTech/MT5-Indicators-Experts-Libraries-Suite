#define MARCO_LOG_PROGRAM "marco_live_ea"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                                marco_live_ea.mq5 |
//|                 Marcotrades Dual-TF Live Auto-Trader             |
//|                 With Interactive Custom Order Panel & HUD        |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "2.00"
#property description "Automated Live SMC Execution using Liquidity Blocks & M1 Inducement TPs"

#include <Custom\Marcotrades\marco_live.mqh>

enum ENUM_LB_LABEL_POS
  {
   LB_LABEL_RIGHT,    // Right Edge (Active Price Action)
   LB_LABEL_CENTER,   // Historical Center
   LB_LABEL_LEFT      // Left Edge (Zone Creation)
  };

enum ENUM_LABEL_POS
  {
   LABEL_POS_RIGHT,    // Right Edge (Active Price Action)
   LABEL_POS_CENTER,   // Historical Center
   LABEL_POS_LEFT      // Left Edge (Zone Creation)
  };

// =============================================================================
// LIVE ORDER EXECUTION SETTINGS
// =============================================================================
input group "=== Live Execution & Risk Control ==="
input ulong           InpMagicNumber              = 778899;       // EA Magic Number
input double          InpMaxRiskPercent           = 10.0;         // Risk per trade (% of Balance)
input double          InpSLBufferPips             = 2.0;          // SL Buffer outside Liquidity Block (Pips)
input ENUM_TIMEFRAMES InpTPTimeframe              = PERIOD_M1;    // LTF for Opposing Inducement TPs
input int             InpMaxSpreadPoints          = 50;           // Maximum Allowable Spread (Points, 0=Disabled)
input int             InpMaxOpenPositionsPerSym   = 2;            // Max Simultaneous Positions per Symbol
input int             InpBacktestDays             = 5;            // Historical Horizon in Days for Setup Mapping

// =============================================================================
// ORDER PANEL SETTINGS
// =============================================================================
input group "=== Custom Order Panel ==="
input bool            InpShowOrderPanel           = true;         // Show Interactive Custom Order Panel?

// =============================================================================
// SMC STRUCTURAL CONFIGURATION
// =============================================================================
input group "=== Structural Lines (BOS, CHoCH, Sweeps) ==="
input bool              InpShowStructuralLines      = true;         // Show Structure Lines (BOS, CHoCH, Sweeps)
input bool              InpShowSwingHL              = true;         // Show Latest Swing High/Low Lines

input group "=== Liquidity Block Triggers ==="
input bool              InpTrackSweepsAnywhere      = true;         // Track TF-BL-LB-SSL & TF-BR-LB-BSL
input bool              InpTrackPostInducementCHoCH = true;         // Track TF-BL-LB-IND & TF-BR-LB-IND

input group "=== Liquidity Block Display & Visuals ==="
input bool              InpShowBullishLB            = true;         // Display Bullish Liquidity Blocks
input bool              InpShowBearishLB            = true;         // Display Bearish Liquidity Blocks
input bool              InpShowMitigatedLB          = false;        // Display Mitigated Liquidity Blocks
input bool              showfreshLBonly             = true;         // Fade LBs touched by ZigZag Pivot
input color             InpColorBullishLB           = C'0,220,220'; // Bullish LB Color (Electric Aqua)
input color             InpColorBearishLB           = C'255,20,147';// Bearish LB Color (Deep Pink)
input color             InpColorMitigatedLB         = clrGray;      // Mitigated Color
input color             InpColorLBText              = clrWhite;     // Foreground Label Text Color
input ENUM_LB_LABEL_POS InpLBLabelPos               = LB_LABEL_CENTER;// Label Position on Box

input group "=== Inducement Rules ==="
input bool            InpShowUnderlyingInducement = true;         // Master Toggle for Inducements
input int             InpMinTouches               = 3;            // Min touches for Inducement qualification
input double          InpProximityPips            = 1.0;          // Touch proximity buffer outside zone (Pips)
input bool            InpShowBuyersInducement     = true;         // Display Buyers' Inducement (Bullish Zones)
input bool            InpShowSellersInducement    = true;         // Display Sellers' Inducement (Bearish Zones)
input bool            InpShowMitigatedInducement  = false;        // Display historically mitigated inducements
input bool            InpShowTouchCount           = true;         // Display touch count in box label
input bool            InpStrictOriginPivots       = true;         // Enforce Strict Origin (Buyers=Pivot Low, Sellers=Pivot High)

input group "=== Anti-Clustering & Zone Prolongation ==="
input bool            InpMergeClusteredZones      = true;         // Prolong single master inducement & prevent stacking
input double          InpClusterTolerancePips     = 10.0;         // Cluster tolerance range (Pips)
input bool            InpMergeExpandBounds        = false;        // Expand master boundaries to cover cluster

input group "=== SMC Zone Sources ==="
input bool            InpCheckDemandSupply        = true;         // Demand / Supply Zones
input bool            InpCheckOrderBlocks         = true;         // Order Blocks
input bool            InpCheckSwingPOIs           = true;         // Swing POIs
input bool            InpCheckFlipZones           = false;        // Flip Zones
input bool            InpCheckBreakers            = false;        // Breaker Blocks

input group "=== Visual Styles & Palette ==="
input color           InpColorBuyerInducement     = C'30,144,255';// Buyers' Inducement Box Color (DodgerBlue)
input color           InpColorSellerInducement    = C'255,69,0';  // Sellers' Inducement Box Color (OrangeRed)
input color           InpColorMitigated           = clrGray;      // Mitigated Inducement Color
input color           InpColorText                = clrWhite;     // High-Contrast Label Text Color
input ENUM_LABEL_POS  InpLabelPosition            = LABEL_POS_CENTER; // Label Display Position on Box

input group "=== Structural ZigZag Configuration ==="
input double          InpDeviation                = 0.15;         // Price deviation for reversals (%)
input int             InpDepth                    = 5;            // Lookback depth for structural swings
input color           InpZZColor                  = clrGold;      // ZigZag line color
input bool            InpShowZigZagLines          = false;        // Display ZigZag lines
input string          InpPriceDiff                = "Percent";    // Diff Mode (Absolute/Percent)

// Multi-Asset & Multi-Timeframe Definitions
string target_symbols[] = {"XAUUSDc", "XAGUSDc", "US30c", "US500c", "USTECc", "USOILc", "UKOILc", "BTCUSDc", "ETHUSDc"};
ENUM_TIMEFRAMES target_timeframes[] = {PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};

// Engines
CMarcoLiveEngine  LiveEngine;
CMarcoCustomPanel CustomPanel;
CTrade            ManualTrade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Starting Marcotrades Live Auto-Trading EA with Custom Order Panel...");

// 1. Initialize Multi-Symbol Scanner & Execution Engine
   LiveEngine.Initialize(
      target_symbols, target_timeframes, InpTPTimeframe, InpMagicNumber,
      InpMaxRiskPercent, InpSLBufferPips, InpDepth, InpDeviation, InpBacktestDays,
      InpTrackSweepsAnywhere, InpTrackPostInducementCHoCH,
      InpMinTouches, InpProximityPips, InpStrictOriginPivots,
      InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds
   );

// 2. Initialize Manual Trade Handler
   ManualTrade.SetExpertMagicNumber(InpMagicNumber);
   ManualTrade.SetMarginMode();
   ManualTrade.SetTypeFillingBySymbol(_Symbol);

// 3. Render Custom Interactive Order Panel
   if(InpShowOrderPanel)
     {
      CustomPanel.Render(InpMaxRiskPercent);
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
   CustomPanel.Destroy();
   Print("🛑 Marcotrades Live Auto-Trading EA stopped.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
// 1. Automated First-Touch Execution across all configured symbols & TFs
   if(CustomPanel.IsAutoTradingEnabled())
     {
      LiveEngine.OnTick(InpMaxSpreadPoints, InpMaxOpenPositionsPerSym);
     }

// 2. Real-time Panel HUD update (with exact Guardrails Spread)
   if(InpShowOrderPanel)
     {
      CustomPanel.UpdateHUD(_Symbol, InpMaxRiskPercent);
     }
  }

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
// Clock tick & HUD pulse
   if(InpShowOrderPanel)
     {
      CustomPanel.UpdateHUD(_Symbol, InpMaxRiskPercent);
     }
  }

//+------------------------------------------------------------------+
//| Chart Event Dispatcher (Panel Drag, Clicks, Stepper, Safe Trade) |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   if(InpShowOrderPanel)
     {
      CustomPanel.OnChartEvent(id, lparam, dparam, sparam, ManualTrade, InpMaxRiskPercent, InpMagicNumber);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Marcotrades\marco_live_ea.mq5

// END FILE: Experts\Custom EAs\Marcotrades\marco_live_ea.mq5
