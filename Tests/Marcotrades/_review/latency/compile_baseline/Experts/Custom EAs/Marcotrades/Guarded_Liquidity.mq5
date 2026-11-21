#define MARCO_LOG_PROGRAM "Guarded_Liquidity"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|             Experts\Custom EAs\Marcotrades\Guarded_Liquidity.mq5 |
//|     SMC Guarded Liquidity System (Inducements + LBs + Guardrails)|
//|        Copyright 2026, Marcotrades SMC Quantitative Architecture |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property link      "https://marcotrades.com"
#property version   "1.00"
#property description "Unified EA combining Inducements, Liquidity Blocks, and Guardrails Shield"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\Guarded_Liquidity.mqh"

// ==================================================================
// 1. GUARDRAILS ACCOUNT & AUTO-TEMPLATE
// ==================================================================
input group "=== 1. Guardrails Account & Auto-Template ==="
input bool   InpManageAllSymbols              = true;     // Manage Trades on ALL Symbols across Account?
input bool   InpAutoSaveDefaultTemplate       = true;     // Auto-launch Panel on any new chart (default.tpl)
input ulong  InpMagicNumber                   = 0;        // Magic Number (0 = Manual Trades)

// ==================================================================
// 2. GUARDRAILS RISK & PRE-TRADE ENFORCEMENT
// ==================================================================
input group "=== 2. Guardrails Risk & Pre-Trade Protection ==="
input bool   InpShowOrderPanel                = true;     // Show Pre-Trade Protection Order Panel?
input bool   InpEnforceMaxLot                 = true;     // Strict Gatekeeper: Block Oversized Lots
input double InpMaxRiskPercent                = 1.0;      // Max Account Loss Allowed per Trade (% Balance)
input bool   InpExcludeSpreadFromRisk         = true;     // Measure 1% market move AFTER spread?
input bool   InpEmergencyCircuitBreaker       = false;    // Force-close if floating loss hits 1%?
input double InpMaxSpreadShareOfRisk          = 100.0;    // Max spread cost allowed (% of 1% risk)
input bool   InpBlockShortsInBullish          = true;     // Block Shorts in Bullish Zones?
input bool   InpBlockLongsInBearish           = true;     // Block Longs in Bearish Zones?
input ENUM_ZONE_SELECTION InpZoneRiskSource   = ZONE_SELECT_LIQUIDITY_BLOCKS; // Primary Zone Type for 1% Risk SL

// ==================================================================
// 3. GUARDRAILS AUTO BREAKEVEN
// ==================================================================
input group "=== 3. Guardrails Auto Breakeven ==="
input bool   InpAutoBreakeven                 = true;     // Move SL to Entry Price when in profit?
input bool   InpWaitCandleClose               = true;     // Wait for candle close confirmation?
input double InpBreakevenSpreadMultiplier     = 10.0;     // Profit distance required (x Spread, e.g. 10x)
input int    InpBreakevenBuffer               = 0;        // Extra buffer in points (to cover commissions)

// ==================================================================
// 4. DYNAMIC PROFIT PROTECTION (TAKE PROFIT GUARDRAIL)
// ==================================================================
input group "=== 4. Dynamic Profit Protection (Take Profit Guardrail) ==="
input bool   InpEnableProfitGuard             = true;     // Enable Dynamic Profit Protection Guardrail?
input double InpTPActivationPercent           = 50.0;     // Activation Profit on Candle Close (% of Balance)
input double InpMaxProfitGivebackPercent      = 15.0;     // Max Profit Giveback on Opposing Candle Close (%)
input double InpPartialClosePercent           = 50.0;     // Partial Close Volume (% of Current Lot)
input bool   InpAdvancedProfitSaving          = true;     // Advanced Profit Saving (Cascade Scale-Out on Pullback)?
input bool   InpAutoTrade                     = true;     // Auto-Trade on Trend Continuation (Crosses First Peak)?

// ==================================================================
// 5. MARKET STRUCTURE & STRUCTURAL LINES
// ==================================================================
input group "=== 5. Market Structure & Structural Lines ==="
input bool   InpShowStructuralLines           = true;     // Show Structure Lines (BOS, CHoCH, Sweeps)
input bool   InpShowSwingHL                   = true;     // Show Latest Swing High/Low Lines

// ==================================================================
// 6. LIQUIDITY BLOCKS (TRIGGERS & VISUALS)
// ==================================================================
input group "=== 6. Liquidity Block Engine (Triggers & Visuals) ==="
input bool              InpTrackSweepsAnywhere      = true;         // Track TF-BL-LB-SSL & TF-BR-LB-BSL
input bool              InpTrackPostInducementCHoCH = true;         // Track TF-BL-LB-IND & TF-BR-LB-IND
input bool              InpShowBullishLB            = true;         // Display Bullish Liquidity Blocks
input bool              InpShowBearishLB            = true;         // Display Bearish Liquidity Blocks
input bool              InpShowMitigatedLB          = true;         // Display Mitigated Liquidity Blocks
input color             InpColorBullishLB           = C'0,220,220'; // Bullish LB Color (Electric Aqua)
input color             InpColorBearishLB           = C'255,20,147';// Bearish LB Color (Deep Pink)
input color             InpColorMitigatedLB         = clrGray;      // Mitigated Color
input color             InpColorLBText              = clrWhite;     // Foreground Label Text Color
input ENUM_LB_LABEL_POS InpLBLabelPos               = LB_LABEL_CENTER;// Label Position on Box

// ==================================================================
// 7. INDUCEMENTS (RULES, HARVESTING SOURCES & VISUALS)
// ==================================================================
input group "=== 7a. Inducement Engine Rules ==="
input int             InpMinTouches               = 3;            // Min touches for Inducement qualification
input double          InpProximityPips            = 0.5;          // Touch proximity buffer outside zone (Pips)
input bool            InpStrictOriginPivots       = true;         // Enforce Strict Origin (Buyers=Pivot Low, Sellers=Pivot High)
input bool            InpMergeClusteredZones      = true;         // Prolong single master inducement & prevent stacking
input double          InpClusterTolerancePips     = 10.0;         // Cluster tolerance range (Pips)
input bool            InpMergeExpandBounds        = false;         // Expand master boundaries to cover cluster

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== 7b. Inducement SMC Zone Sources (from Inducements.mq5) ==="
input bool            InpCheckDemandSupply        = true;         // Harvest Demand / Supply Zones for Inducements
input bool            InpCheckOrderBlocks         = true;         // Harvest Order Blocks for Inducements
input bool            InpCheckSwingPOIs           = true;         // Harvest Swing POIs for Inducements
input bool            InpCheckFlipZones           = false;        // Harvest Flip Zones for Inducements
input bool            InpCheckBreakers            = false;        // Harvest Breaker Blocks for Inducements

input group "=== 7c. Inducement Display & Visuals ==="
input bool            InpShowBuyersInducement     = true;         // Display Buyers' Inducement (Bullish Zones)
input bool            InpShowSellersInducement    = true;         // Display Sellers' Inducement (Bearish Zones)
input bool            InpShowMitigatedInducement  = true;         // Display historically mitigated inducements
input bool            InpShowTouchCount           = true;         // Display touch count in box label
input color           InpColorBuyerInducement     = C'30,144,255';// Buyers' Inducement Box Color (DodgerBlue)
input color           InpColorSellerInducement    = C'255,69,0';  // Sellers' Inducement Box Color (OrangeRed)
input color           InpColorMitigatedInd        = clrGray;      // Mitigated Inducement Color
input color           InpColorIndText             = clrWhite;     // High-Contrast Label Text Color
input ENUM_LABEL_POS  InpIndLabelPosition         = LABEL_POS_CENTER;// Label Display Position on Box

// ==================================================================
// 8. ACTIVE ZONES FOR GUARDRAILS VIOLATION CHECKS & RISK SOURCING
// ==================================================================
input group "=== 8. Active Underlying SMC Zones (Violations & Sourcing) ==="
input bool   InpUseLiquidityBlocks            = true;     // Check Liquidity Blocks (LBs) for Guardrails?
input bool   InpUseInducements                = true;     // Check Inducement Zones for Guardrails?
input bool   InpUseDemandSupply               = true;     // Check Demand / Supply Zones?
input bool   InpUseOrderBlocks                = true;     // Check Order Blocks?
input bool   InpUseFlipZones                  = false;     // Check Flip Zones?
input bool   InpUseBreakerBlocks              = false;    // Check Breaker Blocks?
input bool   InpUseSwingPOIs                  = true;     // Check Swing POIs?
input bool   InpDrawZones                     = false;    // Draw Underlying SMC Zones?

// ==================================================================
// 9. CENTRAL ZIGZAG VISUAL CONTROLS
// ==================================================================
input group "=== 9. Central ZigZag Visual Controls ==="
input bool   InpDrawZigZag                    = true;     // Draw ZigZag Lines
input color  lineColorInput                   = clrGold;  // ZigZag Line Color
input bool   extendInput                      = true;     // Extend to last bar (Projection Pivots)
input bool   showPriceInput                   = false;    // Display reversal price
input bool   showVolInput                     = false;    // Display cumulative volume
input bool   showChgInput                     = false;    // Display reversal price change
input string priceDiffInput                   = "Percent";// Difference Mode (Absolute/Percent)

// ==================================================================
// 10. MULTI-ASSET ZIGZAG CONFIGURATION (UNIFIED CORE)
// ==================================================================
input group "=== 10. Multi-Asset Category Override ==="
input ENUM_ASSET_TYPE InpAssetCategory        = ASSET_TYPE_AUTO; // Asset Category (Auto Detects by Default)

input group "--- For Forex Pairs ---"
input int    fx_maxLookback                   = 3000;
input double fx_dev_D1                        = 1.0;
input int    fx_dep_D1                        = 15;
input double fx_dev_H4                        = 0.5;
input int    fx_dep_H4                        = 2;
input double fx_dev_H1                        = 0.5;
input int    fx_dep_H1                        = 15;
input double fx_dev_M15                       = 0.15;
input int    fx_dep_M15                       = 3;
input double fx_dev_M1                        = 0.15;
input int    fx_dep_M1                        = 3;

input group "--- For Metals Pairs ---"
input int    met_maxLookback                  = 3000;
input double met_dev_D1                       = 5.0;
input int    met_dep_D1                       = 15;
input double met_dev_H4                       = 5.0;
input int    met_dep_H4                       = 15;
input double met_dev_H1                       = 1.0;
input int    met_dep_H1                       = 15;
input double met_dev_M15                      = 0.15;
input int    met_dep_M15                      = 3;
input double met_dev_M1                       = 0.15;
input int    met_dep_M1                       = 3;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback                  = 3000;
input double cry_dev_D1                       = 5.0;
input int    cry_dep_D1                       = 15;
input double cry_dev_H4                       = 5.0;
input int    cry_dep_H4                       = 15;
input double cry_dev_H1                       = 1.0;
input int    cry_dep_H1                       = 15;
input double cry_dev_M15                      = 0.15;
input int    cry_dep_M15                      = 3;
input double cry_dev_M1                       = 0.15;
input int    cry_dep_M1                       = 3;

// Master Guarded Liquidity Engine Instance
CGuardedLiquidityEngine GuardedEngine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Guarded Liquidity EA (Inducements + LBs + Guardrails)...");

// Pack Multi-Asset ZigZag Settings into the unified struct
   SZigZagParams zz;
   zz.fx_maxLookback   = fx_maxLookback;
   zz.fx_dev_D1        = fx_dev_D1;
   zz.fx_dep_D1        = fx_dep_D1;
   zz.fx_dev_H4        = fx_dev_H4;
   zz.fx_dep_H4        = fx_dep_H4;
   zz.fx_dev_H1        = fx_dev_H1;
   zz.fx_dep_H1        = fx_dep_H1;
   zz.fx_dev_M15       = fx_dev_M15;
   zz.fx_dep_M15       = fx_dep_M15;
   zz.fx_dev_M1        = fx_dev_M1;
   zz.fx_dep_M1        = fx_dep_M1;

   zz.met_maxLookback  = met_maxLookback;
   zz.met_dev_D1       = met_dev_D1;
   zz.met_dep_D1       = met_dep_D1;
   zz.met_dev_H4       = met_dev_H4;
   zz.met_dep_H4       = met_dep_H4;
   zz.met_dev_H1       = met_dev_H1;
   zz.met_dep_H1       = met_dep_H1;
   zz.met_dev_M15      = met_dev_M15;
   zz.met_dep_M15      = met_dep_M15;
   zz.met_dev_M1       = met_dev_M1;
   zz.met_dep_M1       = met_dep_M1;

   zz.cry_maxLookback  = cry_maxLookback;
   zz.cry_dev_D1       = cry_dev_D1;
   zz.cry_dep_D1       = cry_dep_D1;
   zz.cry_dev_H4       = cry_dev_H4;
   zz.cry_dep_H4       = cry_dep_H4;
   zz.cry_dev_H1       = cry_dev_H1;
   zz.cry_dep_H1       = cry_dep_H1;
   zz.cry_dev_M15      = cry_dev_M15;
   zz.cry_dep_M15      = cry_dep_M15;
   zz.cry_dev_M1       = cry_dev_M1;
   zz.cry_dep_M1       = cry_dep_M1;

// Call the 71-parameter OnInitGuarded method
   return GuardedEngine.OnInitGuarded(
             InpManageAllSymbols, InpAutoSaveDefaultTemplate, InpMagicNumber,
             InpShowOrderPanel, InpEnforceMaxLot, InpMaxRiskPercent, InpExcludeSpreadFromRisk, InpEmergencyCircuitBreaker,
             InpMaxSpreadShareOfRisk, InpBlockShortsInBullish, InpBlockLongsInBearish, InpZoneRiskSource,
             InpAutoBreakeven, InpWaitCandleClose, InpBreakevenSpreadMultiplier, InpBreakevenBuffer,
             InpEnableProfitGuard, InpTPActivationPercent, InpMaxProfitGivebackPercent, InpPartialClosePercent, InpAdvancedProfitSaving, InpAutoTrade,
             InpShowStructuralLines, InpShowSwingHL,
             InpTrackSweepsAnywhere, InpTrackPostInducementCHoCH,
             InpShowBullishLB, InpShowBearishLB, InpShowMitigatedLB,
             InpColorBullishLB, InpColorBearishLB, InpColorMitigatedLB, InpColorLBText, InpLBLabelPos,
             InpMinTouches, InpProximityPips, InpStrictOriginPivots, InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds,
             InpCheckDemandSupply, InpCheckOrderBlocks, InpCheckSwingPOIs, InpCheckFlipZones, InpCheckBreakers,
             InpShowBuyersInducement, InpShowSellersInducement, InpShowMitigatedInducement, InpShowTouchCount,
             InpColorBuyerInducement, InpColorSellerInducement, InpColorMitigatedInd, InpColorIndText, InpIndLabelPosition,
             InpUseLiquidityBlocks, InpUseInducements, InpUseDemandSupply, InpUseOrderBlocks, InpUseFlipZones, InpUseBreakerBlocks, InpUseSwingPOIs, InpDrawZones,
             InpDrawZigZag, lineColorInput, extendInput, showPriceInput, showVolInput, showChgInput, priceDiffInput,
             InpAssetCategory, zz
          );
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   GuardedEngine.OnDeinitGuarded(reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_marcoDailyLog.Pulse();
   GuardedEngine.OnTickGuarded();
  }

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   GuardedEngine.OnTimerGuarded();
  }

//+------------------------------------------------------------------+
//| Expert trade function                                            |
//+------------------------------------------------------------------+
void OnTrade()
  {
   GuardedEngine.OnTradeGuarded();
  }

//+------------------------------------------------------------------+
//| Expert trade transaction function                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   GuardedEngine.OnTradeTransactionGuarded(trans, request, result);
  }

//+------------------------------------------------------------------+
//| Expert chart event function (Mouse clicks & dragging)            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   GuardedEngine.OnChartEventGuarded(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Marcotrades\Guarded_Liquidity.mq5

// END FILE: Experts\Custom EAs\Marcotrades\Guarded_Liquidity.mq5
