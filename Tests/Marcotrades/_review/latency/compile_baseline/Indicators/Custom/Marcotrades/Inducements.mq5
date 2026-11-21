#define MARCO_LOG_PROGRAM "Inducements"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                               Indicators\Custom\Marcotrades\Inducements.mq5 |
//|                 Smart Money Concepts: Inducement Zone Visualizer |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.03"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\Inducements.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"

enum ENUM_LABEL_POS
  {
   LABEL_POS_RIGHT,    // Right Edge (Active Price Action)
   LABEL_POS_CENTER,   // Historical Center
   LABEL_POS_LEFT      // Left Edge (Zone Creation)
  };

// =============================================================================
// USER INPUT PARAMETERS
// =============================================================================
input group "=== Inducement Rules ==="
input int             InpMinTouches               = 3;            // Minimum touches to qualify as Inducement
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
input bool            InpCheckLiquidityBlocks     = true;         // Liquidity Blocks (LBs)
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
input bool            InpShowZigZagLines          = true;         // Display ZigZag structural lines

input group "=== Structural ZigZag Configuration ==="
input double          InpDeviation                = 0.15;          // Price deviation for reversals (%)
input int             InpDepth                    = 3;           // Lookback depth for structural swings
input color           InpZZColor                  = clrGold;      // ZigZag line color
input string          InpPriceDiff                = "Absolute";    // Diff Mode (Absolute/Percent)

input group "=== Performance Settings ==="
input int             InpMaxLookbackBars          = 3000;         // Max historical bars to scan

// =============================================================================
// GLOBAL ENGINES & DATA CONTAINERS
// =============================================================================
ZigZag*               zigZag   = NULL;
CMarketStructure*     ms       = NULL;
CDemandSupplyLogic*   dsLogic  = NULL;
CSwingPOILogic*       spLogic  = NULL;
COrderBlockLogic*     obLogic  = NULL;
CFlipZoneLogic*       fzLogic  = NULL;
CBreakerBlockLogic*   bbLogic  = NULL;
CLiquidityBlockLogic* lbLogic  = NULL;
CInducementLogic*     indLogic = NULL;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
// 1. Initialize ZigZag structural engine
   Settings* s = new Settings(InpDeviation, InpDepth, InpZZColor, true, false, false, false, InpPriceDiff);
   s.draw = InpShowZigZagLines;
   zigZag = newInstance(s);

// 2. Initialize Market Structure engine
   ms = new CMarketStructure();
   ms.Init(false, false);

// 3. Initialize SMC sub-engines
   dsLogic = new CDemandSupplyLogic();
   spLogic = new CSwingPOILogic();
   obLogic = new COrderBlockLogic();
   fzLogic = new CFlipZoneLogic();
   bbLogic = new CBreakerBlockLogic();

// 4. Initialize Liquidity Block engine
   lbLogic = new CLiquidityBlockLogic();
   lbLogic.Init(true, true);

// 5. Initialize Inducement Detection engine (with InpCheckLiquidityBlocks)
   indLogic = new CInducementLogic();
   indLogic.Init(InpMinTouches, InpProximityPips,
                 InpCheckLiquidityBlocks,
                 InpCheckDemandSupply, InpCheckOrderBlocks,
                 InpCheckSwingPOIs, InpCheckFlipZones,
                 InpCheckBreakers, InpStrictOriginPivots,
                 InpMergeClusteredZones, InpClusterTolerancePips,
                 InpMergeExpandBounds);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   if(zigZag   != NULL)
      delete zigZag;
   if(ms       != NULL)
      delete ms;
   if(dsLogic  != NULL)
      delete dsLogic;
   if(spLogic  != NULL)
      delete spLogic;
   if(obLogic  != NULL)
      delete obLogic;
   if(fzLogic  != NULL)
      delete fzLogic;
   if(bbLogic  != NULL)
      delete bbLogic;
   if(lbLogic  != NULL)
      delete lbLogic;
   if(indLogic != NULL)
      delete indLogic;

   ObjectsDeleteAll(0, "IND_");
   ObjectsDeleteAll(0, "ZZ_");
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Reset state during historical recalculation                      |
//+------------------------------------------------------------------+
void ResetState()
  {
   if(ms      != NULL)
      ms.ResetState();
   if(dsLogic != NULL)
      dsLogic.ResetState();
   if(spLogic != NULL)
      spLogic.ResetState();
   if(obLogic != NULL)
      obLogic.ResetState();
   if(fzLogic != NULL)
      fzLogic.ResetState();
   if(bbLogic != NULL)
      bbLogic.ResetState();
   if(lbLogic != NULL)
      lbLogic.ResetState();
   if(indLogic!= NULL)
      indLogic.ResetState();

   ObjectsDeleteAll(0, "IND_");
  }

//+------------------------------------------------------------------+
//| Universal Pip Size Resolver                                      |
//+------------------------------------------------------------------+
double GetPipSize()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   g_marcoDailyLog.Pulse();
   if(rates_total < InpDepth * 2)
      return 0;

   if(prev_calculated == 0)
      ResetState();

   int start_bar = 0;
   if(rates_total > InpMaxLookbackBars)
      start_bar = rates_total - InpMaxLookbackBars;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : start_bar;
   double pipSize = GetPipSize();

   for(int i = start; i < rates_total; i++)
     {
      bool is_last = (i == rates_total - 1);

      // 1. Process Core ZigZag & Structural Flows
      zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
      ms.Update(i, time, high, low, close, zigZag);

      // 2. Process SMC Zone Detection Libraries
      dsLogic.DetectPOIs(i, time, high, low, zigZag);
      dsLogic.UpdateMitigation(close[i]);

      spLogic.DetectPOIs(i, time, high, low, zigZag);
      spLogic.UpdateMitigation(close[i]);

      obLogic.DetectPOIs(i, time, high, low, zigZag);
      obLogic.UpdateMitigation(close[i]);

      if(obLogic.poi_demandTime.Total() > 0)
        {
         datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
         if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz))
           {
            if(obLogic.CheckBullishOB(tz, i, time, high, low))
               obLogic.ob_bull_valid_times.Add((long)tz);
           }
        }
      if(obLogic.poi_supplyTime.Total() > 0)
        {
         datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
         if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz))
           {
            if(obLogic.CheckBearishOB(tz, i, time, high, low))
               obLogic.ob_bear_valid_times.Add((long)tz);
           }
        }

      fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
      fzLogic.UpdateMitigation(close[i]);

      bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);
      bbLogic.UpdateMitigation(high[i], low[i], time[i]);

      // 3. Process Liquidity Block Engine (detects LBs & pushes to indLogic)
      lbLogic.Process(i, time, high, low, ms, spLogic, indLogic, zigZag, pipSize);

      // 4. Process Inducement Engine with anti-clustering & prolongation
      indLogic.Process(i, time, open, high, low, close,
                       zigZag, ms, dsLogic, spLogic, obLogic,
                       fzLogic, bbLogic, pipSize);

      // 5. Sync qualification status back to Liquidity Blocks
      lbLogic.SyncInducementStatus(indLogic);
     }

// -----------------------------------------------------------------
// DYNAMIC GRAPHICAL RENDERING MODULE
// -----------------------------------------------------------------
   datetime extend_right = time[rates_total - 1] + 35 * PeriodSeconds();
   string tfStr = ms.tf_str();

   for(int z = 0; z < indLogic.m_zones.Total(); z++)
     {
      CInducementZone* zone = (CInducementZone*)indLogic.m_zones.At(z);
      if(zone == NULL)
         continue;

      string boxId = "IND_" + zone.id;
      string lblId = boxId + "_lbl";

      // Only display zones that have qualified as Inducements
      if(!zone.isInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      if(zone.isBullish && !InpShowBuyersInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }
      if(!zone.isBullish && !InpShowSellersInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      if(zone.isMitigated && !InpShowMitigatedInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      // Prolong unmitigated inducement across the chart to current price action
      datetime rightEdge = zone.isMitigated ? zone.mitigationTime : extend_right;

      color boxClr = zone.isBullish ? InpColorBuyerInducement : InpColorSellerInducement;
      if(zone.isMitigated)
         boxClr = InpColorMitigated;

      // 1. CREATE / UPDATE BOX
      if(ObjectFind(0, boxId) < 0)
        {
         ObjectCreate(0, boxId, OBJ_RECTANGLE, 0, zone.createdTime, zone.zoneHigh, rightEdge, zone.zoneLow);
         ObjectSetInteger(0, boxId, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxId, OBJPROP_BACK, true); // Keep behind candles and text
         ObjectSetInteger(0, boxId, OBJPROP_SELECTABLE, false);
        }
      else
        {
         ObjectSetInteger(0, boxId, OBJPROP_TIME, 0, zone.createdTime);
         ObjectSetDouble(0, boxId, OBJPROP_PRICE, 0, zone.zoneHigh);
         ObjectSetInteger(0, boxId, OBJPROP_TIME, 1, rightEdge);
         ObjectSetDouble(0, boxId, OBJPROP_PRICE, 1, zone.zoneLow);
        }
      ObjectSetInteger(0, boxId, OBJPROP_COLOR, boxClr);

      // 2. BUILD TOUCH COUNT LABEL
      string touchSuffix = InpShowTouchCount ? StringFormat("-%d", zone.touchCount) : "";
      string labelText   = "";

      if(zone.isBullish)
         labelText = tfStr + "-BL-IND" + touchSuffix;
      else
         labelText = tfStr + "-BR-IND" + touchSuffix;

      // 3. COMPUTE VISIBLE ANCHOR POSITION
      datetime lblTime = zone.createdTime;
      ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT;

      if(InpLabelPosition == LABEL_POS_RIGHT)
        {
         lblTime = rightEdge;
         anchor  = ANCHOR_RIGHT;
        }
      else
         if(InpLabelPosition == LABEL_POS_CENTER)
           {
            lblTime = zone.createdTime + (datetime)((rightEdge - zone.createdTime) / 2);
            anchor  = ANCHOR_CENTER;
           }

      double midPrice = zone.zoneLow + (zone.zoneHigh - zone.zoneLow) / 2.0;

      // 4. CREATE / UPDATE FOREGROUND TEXT LABEL
      if(ObjectFind(0, lblId) < 0)
        {
         ObjectCreate(0, lblId, OBJ_TEXT, 0, lblTime, midPrice);
         ObjectSetInteger(0, lblId, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, lblId, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, lblId, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblId, OBJPROP_BACK, false);
         ObjectSetInteger(0, lblId, OBJPROP_ZORDER, 10);
        }
      else
        {
         ObjectSetInteger(0, lblId, OBJPROP_TIME, lblTime);
         ObjectSetDouble(0, lblId, OBJPROP_PRICE, midPrice);
        }

      ObjectSetString(0, lblId, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, lblId, OBJPROP_COLOR, InpColorText);
      ObjectSetInteger(0, lblId, OBJPROP_ANCHOR, anchor);
     }

   ChartRedraw(0);
   return(rates_total);
  }
//+------------------------------------------------------------------+
// END FILE: Indicators\Custom\Marcotrades\Inducements.mq5

// END FILE: Indicators\Custom\Marcotrades\Inducements.mq5
