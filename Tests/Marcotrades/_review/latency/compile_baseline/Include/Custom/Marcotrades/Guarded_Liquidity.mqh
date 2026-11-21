//+------------------------------------------------------------------+
//|                  Include\Custom\Marcotrades\Guarded_Liquidity.mqh|
//|        Unified Engine: Inducements + Liquidity Blocks + Guardrails|
//|                     1000% Indicator-Matched Visuals & Risk Rules |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.00"
#property strict

#ifndef GUARDED_LIQUIDITY_MQH
#define GUARDED_LIQUIDITY_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mql_plotting.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\Inducements.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Protection.mqh"

#ifndef ENUM_LABEL_POS_DEF
#define ENUM_LABEL_POS_DEF
enum ENUM_LABEL_POS
  {
   LABEL_POS_RIGHT,    // Right Edge (Active Price Action)
   LABEL_POS_CENTER,   // Historical Center
   LABEL_POS_LEFT      // Left Edge (Zone Creation)
  };
#endif

#ifndef ENUM_LB_LABEL_POS_DEF
#define ENUM_LB_LABEL_POS_DEF
enum ENUM_LB_LABEL_POS
  {
   LB_LABEL_RIGHT,    // Right Edge (Active Price Action)
   LB_LABEL_CENTER,   // Historical Center
   LB_LABEL_LEFT      // Left Edge (Zone Creation)
  };
#endif

//+------------------------------------------------------------------+
//| Class CGuardedLiquidityEngine                                    |
//| Inherits Guardrails framework and integrates Inducements and LBs |
//+------------------------------------------------------------------+
class CGuardedLiquidityEngine : public CGuardrailsProtection
  {
protected:
   // Sub-engines
   CInducementLogic*     m_indLogic;
   CLiquidityBlockLogic* m_lbLogic;

   // Inducements Configurations & Visuals
   bool                  m_showBuyersInducement;
   bool                  m_showSellersInducement;
   bool                  m_showMitigatedInducement;
   bool                  m_showTouchCount;
   color                 m_colBuyerInducement;
   color                 m_colSellerInducement;
   color                 m_colMitigatedInd;
   color                 m_colIndText;
   ENUM_LABEL_POS        m_indLabelPos;

   // Liquidity Blocks Configurations & Visuals
   bool                  m_showBullishLB;
   bool                  m_showBearishLB;
   bool                  m_showMitigatedLB;
   color                 m_colBullishLB;
   color                 m_colBearishLB;
   color                 m_colMitigatedLB;
   color                 m_colLBText;
   ENUM_LB_LABEL_POS     m_lbLabelPos;

   // Structural Line Displays
   bool                  m_showStructuralLines;
   bool                  m_showSwingHL;

   // Guardrail Zone Filtering Integration
   bool                  m_useLiquidityBlocksForGuard;
   bool                  m_useInducementsForGuard;

   // Helper methods
   double                GetPipSize();
   void                  UpdateGuardedLiquidity();
   void                  DrawInducements();
   void                  DrawLiquidityBlocks();
   void                  EnforceAllDrawingsBackground();

   // Structural Seekers & Violations with LBs & Inducements
   bool                  IsInBullishZoneGuarded(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time = 0);
   bool                  IsInBearishZoneGuarded(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time = 0);
   bool                  GetNearestBullishBoundaryGuarded(string sym, double price, double &outBoundary, string &outName, datetime at_time = 0);
   bool                  GetNearestBearishBoundaryGuarded(string sym, double price, double &outBoundary, string &outName, datetime at_time = 0);
   double                CalculateMaxAllowedLotGuarded(string sym, int direction, double custom_price = 0.0, datetime at_time = 0);

public:
                     CGuardedLiquidityEngine();
   virtual          ~CGuardedLiquidityEngine();


   int               OnInitGuarded(
      bool manageAll, bool autoSaveTpl, ulong magic,
      // Guardrails Pre-Trade Risk
      bool showPanel, bool enforceMaxLot, double maxRiskPct, bool excludeSpread, bool emergencyCut,
      double maxSpreadShare, bool blockShortsBull, bool blockLongsBear, ENUM_ZONE_SELECTION zoneSource,
      // Auto-Breakeven
      bool autoBE, bool waitCandleClose, double beSpreadMult, int beBuffer,
      // Profit Protection Guardrail
      bool enableProfitGuard, double tpActivationPct, double maxGivebackPct, double partialClosePct, bool advancedProfitSaving, bool autoTrade,
      // Structural lines
      bool showStructuralLines, bool showSwingHL,
      // Liquidity Block Engine
      bool trackSweepsAnywhere, bool trackPostIndCHoCH,
      bool showBullLB, bool showBearLB, bool showMitigatedLB,
      color colBullLB, color colBearLB, color colMitigatedLB, color colLBText, ENUM_LB_LABEL_POS lbLabelPos,
      // Inducement Engine Rules
      int minTouches, double proxPips, bool strictOriginPivots, bool mergeClustered, double clusterTolerancePips, bool expandBounds,
      // Inducement Harvesting Sources (from Inducements.mq5)
      bool checkDS, bool checkOB, bool checkSP, bool checkFZ, bool checkBB,
      // Inducement Visuals
      bool showBuyersInd, bool showSellersInd, bool showMitigatedInd, bool showTouchCount,
      color colBuyerInd, color colSellerInd, color colMitigatedInd, color colIndText, ENUM_LABEL_POS indLabelPos,
      // Active Zones for Guardrails Violation Checks & Sourcing
      bool useLB, bool useInd, bool useDS, bool useOB, bool useFZ, bool useBB, bool useSP, bool drawSMCZones,
      // Central ZigZag Visual Controls
      bool drawZZ, color zzColor, bool zzExtend, bool zzShowPrice, bool zzShowVol, bool zzShowChg, string zzPriceDiff,
      // Multi-Asset Settings
      ENUM_ASSET_TYPE assetCat, SZigZagParams &zz
   );

   void              OnDeinitGuarded(const int reason);
   void              OnTickGuarded();
   void              OnTimerGuarded();
   void              OnTradeGuarded();
   void              OnTradeTransactionGuarded(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   void              OnChartEventGuarded(const int id, const long &lparam, const double &dparam, const string &sparam);

   void              RunMasterGuardedShield();
   void              UpdatePanelHUDGuarded();
   void              ExecutePreTradeBuyGuarded();
   void              ExecutePreTradeSellGuarded();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGuardedLiquidityEngine::CGuardedLiquidityEngine()
  {
   m_indLogic                  = new CInducementLogic();
   m_lbLogic                   = new CLiquidityBlockLogic();

   m_showBuyersInducement      = true;
   m_showSellersInducement     = true;
   m_showMitigatedInducement   = true;
   m_showTouchCount            = true;
   m_colBuyerInducement        = C'30,144,255';
   m_colSellerInducement       = C'255,69,0';
   m_colMitigatedInd           = clrGray;
   m_colIndText                = clrWhite;
   m_indLabelPos               = LABEL_POS_RIGHT;

   m_showBullishLB             = true;
   m_showBearishLB             = true;
   m_showMitigatedLB           = true;
   m_colBullishLB              = C'0,220,220';
   m_colBearishLB              = C'255,20,147';
   m_colMitigatedLB            = clrGray;
   m_colLBText                 = clrWhite;
   m_lbLabelPos                = LB_LABEL_CENTER;

   m_showStructuralLines       = true;
   m_showSwingHL               = true;

   m_useLiquidityBlocksForGuard= true;
   m_useInducementsForGuard    = true;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGuardedLiquidityEngine::~CGuardedLiquidityEngine()
  {
   if(CheckPointer(m_indLogic) == POINTER_DYNAMIC)
      delete m_indLogic;
   if(CheckPointer(m_lbLogic) == POINTER_DYNAMIC)
      delete m_lbLogic;

   ObjectsDeleteAll(0, "LB_");
   ObjectsDeleteAll(0, "IND_");
  }

//+------------------------------------------------------------------+
//| Universal Pip Size Resolver                                      |
//+------------------------------------------------------------------+
double CGuardedLiquidityEngine::GetPipSize()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

//+------------------------------------------------------------------+
//| Engine Master Initializer                                        |
//+------------------------------------------------------------------+
int CGuardedLiquidityEngine::OnInitGuarded(
   bool manageAll, bool autoSaveTpl, ulong magic,
   bool showPanel, bool enforceMaxLot, double maxRiskPct, bool excludeSpread, bool emergencyCut,
   double maxSpreadShare, bool blockShortsBull, bool blockLongsBear, ENUM_ZONE_SELECTION zoneSource,
   bool autoBE, bool waitCandleClose, double beSpreadMult, int beBuffer,
   bool enableProfitGuard, double tpActivationPct, double maxGivebackPct, double partialClosePct, bool advancedProfitSaving, bool autoTrade,
   bool showStructuralLines, bool showSwingHL,
   bool trackSweepsAnywhere, bool trackPostIndCHoCH,
   bool showBullLB, bool showBearLB, bool showMitigatedLB,
   color colBullLB, color colBearLB, color colMitigatedLB, color colLBText, ENUM_LB_LABEL_POS lbLabelPos,
   int minTouches, double proxPips, bool strictOriginPivots, bool mergeClustered, double clusterTolerancePips, bool expandBounds,
   bool checkDS, bool checkOB, bool checkSP, bool checkFZ, bool checkBB,
   bool showBuyersInd, bool showSellersInd, bool showMitigatedInd, bool showTouchCount,
   color colBuyerInd, color colSellerInd, color colMitigatedInd, color colIndText, ENUM_LABEL_POS indLabelPos,
   bool useLB, bool useInd, bool useDS, bool useOB, bool useFZ, bool useBB, bool useSP, bool drawSMCZones,
   bool drawZZ, color zzColor, bool zzExtend, bool zzShowPrice, bool zzShowVol, bool zzShowChg, string zzPriceDiff,
   ENUM_ASSET_TYPE assetCat, SZigZagParams &zz)
  {
   CGuardrailsProtection::OnInit(
      manageAll, autoSaveTpl,
      blockShortsBull, blockLongsBear,
      useDS, useOB, useFZ, useBB, useSP,
      drawZZ, zzColor, zzExtend, zzShowPrice, zzShowVol, zzShowChg, zzPriceDiff,
      showStructuralLines, drawSMCZones,
      magic, enforceMaxLot, maxSpreadShare,
      true, showPanel, excludeSpread,
      maxRiskPct, emergencyCut,
      autoBE, beBuffer, waitCandleClose, beSpreadMult,
      enableProfitGuard, tpActivationPct, maxGivebackPct, partialClosePct, advancedProfitSaving, autoTrade,
      zoneSource, assetCat, zz
   );

   m_showStructuralLines        = showStructuralLines;
   m_showSwingHL                = showSwingHL;

   m_showBullishLB              = showBullLB;
   m_showBearishLB              = showBearLB;
   m_showMitigatedLB            = showMitigatedLB;
   m_colBullishLB               = colBullLB;
   m_colBearishLB               = colBearLB;
   m_colMitigatedLB             = colMitigatedLB;
   m_colLBText                  = colLBText;
   m_lbLabelPos                 = lbLabelPos;
   m_useLiquidityBlocksForGuard = useLB;

   m_showBuyersInducement       = showBuyersInd;
   m_showSellersInducement      = showSellersInd;
   m_showMitigatedInducement    = showMitigatedInd;
   m_showTouchCount             = showTouchCount;
   m_colBuyerInducement         = colBuyerInd;
   m_colSellerInducement        = colSellerInd;
   m_colMitigatedInd            = colMitigatedInd;
   m_colIndText                 = colIndText;
   m_indLabelPos                = indLabelPos;
   m_useInducementsForGuard     = useInd;

   m_indLogic.Init(minTouches, proxPips,
                   checkDS, checkOB, checkSP, checkFZ, checkBB, strictOriginPivots,
                   mergeClustered, clusterTolerancePips, expandBounds);

   m_lbLogic.Init(trackSweepsAnywhere, trackPostIndCHoCH);

   UpdateGuardedLiquidity();
   UpdatePanelHUDGuarded();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Master Deinitialization                                          |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnDeinitGuarded(const int reason)
  {
   CGuardrailsProtection::OnDeinit(reason);

   ObjectsDeleteAll(0, "LB_");
   ObjectsDeleteAll(0, "IND_");
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Chronological & Incremental SMC + Inducements + LBs Engine       |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::UpdateGuardedLiquidity()
  {
   datetime cur_time = iTime(_Symbol, _Period, 0);
   double   cur_bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double   cur_ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

// Real-time mitigation checks on incoming tick
   if(m_dsLogic != NULL)
      m_dsLogic.UpdateMitigation(cur_bid);
   if(m_fzLogic != NULL)
      m_fzLogic.UpdateMitigation(cur_bid);
   if(m_obLogic != NULL)
      m_obLogic.UpdateMitigation(cur_bid);
   if(m_spLogic != NULL)
      m_spLogic.UpdateMitigation(cur_bid);
   if(m_bbLogic != NULL)
      m_bbLogic.UpdateMitigation(cur_ask, cur_bid, TimeCurrent());

   CheckViolatedZoneExpiration();

   double activeDev = 0.5;
   int    activeDep = 10;
   int    activeLookback = 3000;
   GetActiveZigZagParams(activeDev, activeDep, activeLookback);
   double pipSize = GetPipSize();

// FULL HISTORICAL REINITIALIZATION ON STARTUP, TIMEFRAME, OR PARAMETER CHANGE
   if(!m_smc_initialized || m_last_period != _Period || activeDev != m_last_dev || activeDep != m_last_dep)
     {
      m_last_dev    = activeDev;
      m_last_dep    = activeDep;
      m_last_period = _Period;

      int rates_total = Bars(_Symbol, _Period);
      if(rates_total < activeDep * 2)
         return;

      int bars_to_load = (int)MathMax(50, MathMin(activeLookback, rates_total));

      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      int copied = CopyRates(_Symbol, _Period, 0, bars_to_load, rates);
      if(copied < activeDep * 2)
         return;

      ArrayResize(m_chart_times, copied);
      ArrayResize(m_chart_highs, copied);
      ArrayResize(m_chart_lows, copied);
      ArrayResize(m_chart_closes, copied);
      double open_arr[];
      ArrayResize(open_arr, copied);
      m_chart_bars_loaded = copied;

      for(int j = 0; j < copied; j++)
        {
         m_chart_times[j]  = rates[j].time;
         open_arr[j]       = rates[j].open;
         m_chart_highs[j]  = rates[j].high;
         m_chart_lows[j]   = rates[j].low;
         m_chart_closes[j] = rates[j].close;
        }

      // Cleanup prior drawings
      ObjectsDeleteAll(0, "ZZ_Ln_");
      ObjectsDeleteAll(0, "ZZ_Lbl_");
      ObjectsDeleteAll(0, "ZZ_Proj_");
      ObjectsDeleteAll(0, "BOSCHoCH_");
      ObjectsDeleteAll(0, "SWING_");
      ObjectsDeleteAll(0, "SMC_");
      ObjectsDeleteAll(0, "IND_");
      ObjectsDeleteAll(0, "LB_");

      m_dsLogic.ResetState();
      m_spLogic.ResetState();
      m_obLogic.ResetState();
      m_fzLogic.ResetState();
      m_bbLogic.ResetState();
      m_indLogic.ResetState();
      m_lbLogic.ResetState();
      m_ms.ResetState();
      m_ms.Init(m_showStructuralLines, m_showSwingHL);

      if(CheckPointer(m_zigZag) == POINTER_DYNAMIC)
         delete m_zigZag;

      Settings* s = new Settings(activeDev, activeDep, m_zzLineColor, m_zzExtend, m_zzShowPrice, m_zzShowVol, m_zzShowChg, m_zzPriceDiff);
      s.draw = m_drawZigZag;
      m_zigZag = newInstance(s);

      // Chronological bar-by-bar evaluation loop (1000% indicator matching)
      for(int i = 0; i < copied; i++)
        {
         bool is_last = (i == copied - 1);
         m_zigZag.update(m_chart_highs[i], m_chart_lows[i], m_chart_times[i], rates[i].tick_volume, i, !is_last, is_last);
         m_ms.Update(i, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag);

         m_dsLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_dsLogic.UpdateMitigation(m_chart_closes[i]);

         m_spLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_spLogic.UpdateMitigation(m_chart_closes[i]);

         m_obLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_obLogic.UpdateMitigation(m_chart_closes[i]);

         if(m_obLogic.poi_demandTime.Total() > 0)
           {
            datetime tz = (datetime)m_obLogic.poi_demandTime.At(m_obLogic.poi_demandTime.Total() - 1);
            if(m_obLogic.ob_time_found(&m_ms.ob_bull_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bull_valid_times, tz))
               if(m_obLogic.CheckBullishOB(tz, i, m_chart_times, m_chart_highs, m_chart_lows))
                  m_obLogic.ob_bull_valid_times.Add((long)tz);
           }
         if(m_obLogic.poi_supplyTime.Total() > 0)
           {
            datetime tz = (datetime)m_obLogic.poi_supplyTime.At(m_obLogic.poi_supplyTime.Total() - 1);
            if(m_obLogic.ob_time_found(&m_ms.ob_bear_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bear_valid_times, tz))
               if(m_obLogic.CheckBearishOB(tz, i, m_chart_times, m_chart_highs, m_chart_lows))
                  m_obLogic.ob_bear_valid_times.Add((long)tz);
           }

         m_fzLogic.DetectFlipZones(i, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag, m_ms, m_dsLogic);
         m_fzLogic.UpdateMitigation(m_chart_closes[i]);

         m_bbLogic.DetectBreakers(m_zigZag, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic);
         m_bbLogic.UpdateMitigation(m_chart_highs[i], m_chart_lows[i], m_chart_times[i]);

         // Process Inducements & Liquidity Blocks chronologically
         m_indLogic.Process(i, m_chart_times, open_arr, m_chart_highs, m_chart_lows, m_chart_closes,
                            m_zigZag, m_ms, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic, m_bbLogic, pipSize);
         m_lbLogic.Process(i, m_chart_times, m_chart_highs, m_chart_lows, m_ms, m_spLogic, m_indLogic, m_zigZag);
        }

      DrawActiveSMCZones();
      DrawInducements();
      DrawLiquidityBlocks();
      EnforceAllDrawingsBackground();
      ChartRedraw(0);

      m_smc_initialized   = true;
      m_last_smc_bar_time = cur_time;
      return;
     }

// REAL-TIME INCREMENTAL BAR & TICK MAINTENANCE
   MqlRates current_rates[];
   ArraySetAsSeries(current_rates, false);
   if(CopyRates(_Symbol, _Period, 0, 2, current_rates) < 2)
      return;

   int last_idx = m_chart_bars_loaded - 1;

   if(cur_time > m_last_smc_bar_time)
     {
      m_last_smc_bar_time = cur_time;
      m_chart_bars_loaded++;
      last_idx = m_chart_bars_loaded - 1;

      ArrayResize(m_chart_times, m_chart_bars_loaded);
      ArrayResize(m_chart_highs, m_chart_bars_loaded);
      ArrayResize(m_chart_lows, m_chart_bars_loaded);
      ArrayResize(m_chart_closes, m_chart_bars_loaded);

      m_chart_times[last_idx]  = current_rates[1].time;
      m_chart_highs[last_idx]  = current_rates[1].high;
      m_chart_lows[last_idx]   = current_rates[1].low;
      m_chart_closes[last_idx] = current_rates[1].close;
     }
   else
     {
      m_chart_highs[last_idx]  = current_rates[1].high;
      m_chart_lows[last_idx]   = current_rates[1].low;
      m_chart_closes[last_idx] = current_rates[1].close;
     }

   double open_live[];
   ArrayResize(open_live, m_chart_bars_loaded);
   open_live[last_idx] = current_rates[1].open;

   m_zigZag.update(m_chart_highs[last_idx], m_chart_lows[last_idx], m_chart_times[last_idx], current_rates[1].tick_volume, last_idx, false, true);
   m_ms.Update(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag);

   m_dsLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
   m_spLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
   m_obLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);

   if(m_obLogic.poi_demandTime.Total() > 0)
     {
      datetime tz = (datetime)m_obLogic.poi_demandTime.At(m_obLogic.poi_demandTime.Total() - 1);
      if(m_obLogic.ob_time_found(&m_ms.ob_bull_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bull_valid_times, tz))
         if(m_obLogic.CheckBullishOB(tz, last_idx, m_chart_times, m_chart_highs, m_chart_lows))
            m_obLogic.ob_bull_valid_times.Add((long)tz);
     }
   if(m_obLogic.poi_supplyTime.Total() > 0)
     {
      datetime tz = (datetime)m_obLogic.poi_supplyTime.At(m_obLogic.poi_supplyTime.Total() - 1);
      if(m_obLogic.ob_time_found(&m_ms.ob_bear_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bear_valid_times, tz))
         if(m_obLogic.CheckBearishOB(tz, last_idx, m_chart_times, m_chart_highs, m_chart_lows))
            m_obLogic.ob_bear_valid_times.Add((long)tz);
     }

   m_fzLogic.DetectFlipZones(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag, m_ms, m_dsLogic);
   m_bbLogic.DetectBreakers(m_zigZag, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic);

   m_indLogic.Process(last_idx, m_chart_times, open_live, m_chart_highs, m_chart_lows, m_chart_closes,
                      m_zigZag, m_ms, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic, m_bbLogic, pipSize);
   m_lbLogic.Process(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_ms, m_spLogic, m_indLogic);

   DrawActiveSMCZones();
   DrawInducements();
   DrawLiquidityBlocks();
   EnforceAllDrawingsBackground();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Exact Indicator Replica: Draw Inducements                        |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::DrawInducements()
  {
   if(m_indLogic == NULL)
      return;

   datetime extend_right = TimeCurrent() + (35 * PeriodSeconds());
   string tfStr = (m_ms != NULL) ? m_ms.tf_str() : "";

   for(int z = 0; z < m_indLogic.m_zones.Total(); z++)
     {
      CInducementZone* zone = (CInducementZone*)m_indLogic.m_zones.At(z);
      if(zone == NULL)
         continue;

      string boxId = "IND_" + zone.id;
      string lblId = boxId + "_lbl";

      if(!zone.isInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      if(zone.isBullish && !m_showBuyersInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }
      if(!zone.isBullish && !m_showSellersInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      if(zone.isMitigated && !m_showMitigatedInducement)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      datetime rightEdge = zone.isMitigated ? zone.mitigationTime : extend_right;
      color boxClr = zone.isBullish ? m_colBuyerInducement : m_colSellerInducement;
      if(zone.isMitigated)
         boxClr = m_colMitigatedInd;

      // Draw / Update Box
      if(ObjectFind(0, boxId) < 0)
        {
         ObjectCreate(0, boxId, OBJ_RECTANGLE, 0, zone.createdTime, zone.zoneHigh, rightEdge, zone.zoneLow);
         ObjectSetInteger(0, boxId, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxId, OBJPROP_BACK, true);
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

      string touchSuffix = m_showTouchCount ? StringFormat(" [Touches: %d]", zone.touchCount) : "";
      string labelText = "";
      if(zone.isBullish)
         labelText = tfStr + (zone.isMitigated ? " BUYERS' INDUCEMENT [MITIGATED]" : " BUYERS' INDUCEMENT") + touchSuffix;
      else
         labelText = tfStr + (zone.isMitigated ? " SELLERS' INDUCEMENT [MITIGATED]" : " SELLERS' INDUCEMENT") + touchSuffix;

      datetime lblTime = zone.createdTime;
      ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT;

      if(m_indLabelPos == LABEL_POS_RIGHT)
        {
         lblTime = rightEdge;
         anchor  = ANCHOR_RIGHT;
        }
      else
         if(m_indLabelPos == LABEL_POS_CENTER)
           {
            lblTime = zone.createdTime + (datetime)((rightEdge - zone.createdTime) / 2);
            anchor  = ANCHOR_CENTER;
           }

      double midPrice = zone.zoneLow + (zone.zoneHigh - zone.zoneLow) / 2.0;

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
      ObjectSetInteger(0, lblId, OBJPROP_COLOR, m_colIndText);
      ObjectSetInteger(0, lblId, OBJPROP_ANCHOR, anchor);
     }
  }

//+------------------------------------------------------------------+
//| Exact Indicator Replica: Draw Liquidity Blocks                   |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::DrawLiquidityBlocks()
  {
   if(m_lbLogic == NULL)
      return;

   datetime extend_right = TimeCurrent() + (35 * PeriodSeconds());
   string tfStr = (m_ms != NULL) ? m_ms.tf_str() : "";

   for(int l = 0; l < m_lbLogic.m_liquidity_blocks.Total(); l++)
     {
      CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(l);
      if(lb == NULL)
         continue;

      string boxId = "LB_" + lb.id;
      string lblId = boxId + "_lbl";

      if(lb.isBullish && !m_showBullishLB)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }
      if(!lb.isBullish && !m_showBearishLB)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }
      if(lb.isMitigated && !m_showMitigatedLB)
        {
         ObjectDelete(0, boxId);
         ObjectDelete(0, lblId);
         continue;
        }

      datetime rightEdge = lb.isMitigated ? lb.mitigationTime : extend_right;

      color boxClr = lb.isBullish ? m_colBullishLB : m_colBearishLB;
      if(lb.isMitigated)
         boxClr = m_colMitigatedLB;

      if(ObjectFind(0, boxId) < 0)
        {
         ObjectCreate(0, boxId, OBJ_RECTANGLE, 0, lb.createdTime, lb.zoneHigh, rightEdge, lb.zoneLow);
         ObjectSetInteger(0, boxId, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxId, OBJPROP_BACK, true);
         ObjectSetInteger(0, boxId, OBJPROP_SELECTABLE, false);
        }
      else
        {
         ObjectSetInteger(0, boxId, OBJPROP_TIME, 0, lb.createdTime);
         ObjectSetDouble(0, boxId, OBJPROP_PRICE, 0, lb.zoneHigh);
         ObjectSetInteger(0, boxId, OBJPROP_TIME, 1, rightEdge);
         ObjectSetDouble(0, boxId, OBJPROP_PRICE, 1, lb.zoneLow);
        }
      ObjectSetInteger(0, boxId, OBJPROP_COLOR, boxClr);

      // Nomenclature formatting: TF-BL-LB-IND, TF-BR-LB-IND, TF-BL-LB-SSL, TF-BR-LB-BSL
      string labelText = lb.GetNomenclature(tfStr);
      if(lb.isMitigated)
         labelText += " [MITIGATED]";

      datetime lblTime = lb.createdTime;
      ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT;

      if(m_lbLabelPos == LB_LABEL_RIGHT)
        {
         lblTime = rightEdge;
         anchor  = ANCHOR_RIGHT;
        }
      else
         if(m_lbLabelPos == LB_LABEL_CENTER)
           {
            lblTime = lb.createdTime + (datetime)((rightEdge - lb.createdTime) / 2);
            anchor  = ANCHOR_CENTER;
           }

      double midPrice = lb.zoneLow + (lb.zoneHigh - lb.zoneLow) / 2.0;

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
      ObjectSetInteger(0, lblId, OBJPROP_COLOR, m_colLBText);
      ObjectSetInteger(0, lblId, OBJPROP_ANCHOR, anchor);
     }
  }

//+------------------------------------------------------------------+
//| Enforce Background/Foreground Separation on Drawings             |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::EnforceAllDrawingsBackground()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if((StringFind(name, "ZZ_Ln_") == 0) ||
         (StringFind(name, "ZZ_Proj_Ln") == 0) ||
         (StringFind(name, "BOSCHoCH_") == 0 && StringFind(name, "_lbl") < 0) ||
         (StringFind(name, "SWING_") == 0 && StringFind(name, "_LBL") < 0) ||
         (StringFind(name, "SMC_") == 0 && StringFind(name, "_lbl") < 0) ||
         (StringFind(name, "IND_") == 0 && StringFind(name, "_lbl") < 0) ||
         (StringFind(name, "LB_") == 0 && StringFind(name, "_lbl") < 0) ||
         (StringFind(name, "RG_Violated_") == 0 && StringFind(name, "_Lbl") < 0))
        {
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
      else
         if(StringFind(name, "_lbl") >= 0 || StringFind(name, "_Lbl") >= 0 ||
            StringFind(name, "_LBL") >= 0 || StringFind(name, "ZZ_Lbl_") == 0)
           {
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
           }
     }
  }

//+------------------------------------------------------------------+
//| Extended Bullish Zone Check (Includes Liquidity Blocks & Ind)    |
//+------------------------------------------------------------------+
bool CGuardedLiquidityEngine::IsInBullishZoneGuarded(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time)
  {
// 1. Check Base SMC Zones
   if(IsInBullishZone(price, zoneType, outLow, outHigh, outTime, at_time))
      return true;

// 2. Check Active Bullish Liquidity Blocks
   if(m_useLiquidityBlocksForGuard && m_lbLogic != NULL)
     {
      for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
         if(lb != NULL && lb.isBullish && !lb.isMitigated)
           {
            if(at_time > 0 && lb.createdTime > at_time)
               continue;
            if(price >= lb.zoneLow && price <= lb.zoneHigh)
              {
               zoneType = lb.GetNomenclature(m_ms.tf_str());
               outLow   = lb.zoneLow;
               outHigh  = lb.zoneHigh;
               outTime  = lb.createdTime;
               return true;
              }
           }
        }
     }

// 3. Check Active Buyers' Inducements
   if(m_useInducementsForGuard && m_indLogic != NULL)
     {
      for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
        {
         CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
         if(ind != NULL && ind.isInducement && ind.isBullish && !ind.isMitigated)
           {
            if(at_time > 0 && ind.createdTime > at_time)
               continue;
            if(price >= ind.zoneLow && price <= ind.zoneHigh)
              {
               zoneType = "Buyers' Inducement";
               outLow   = ind.zoneLow;
               outHigh  = ind.zoneHigh;
               outTime  = ind.createdTime;
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Extended Bearish Zone Check (Includes Liquidity Blocks & Ind)    |
//+------------------------------------------------------------------+
bool CGuardedLiquidityEngine::IsInBearishZoneGuarded(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time)
  {
// 1. Check Base SMC Zones
   if(IsInBearishZone(price, zoneType, outLow, outHigh, outTime, at_time))
      return true;

// 2. Check Active Bearish Liquidity Blocks
   if(m_useLiquidityBlocksForGuard && m_lbLogic != NULL)
     {
      for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
         if(lb != NULL && !lb.isBullish && !lb.isMitigated)
           {
            if(at_time > 0 && lb.createdTime > at_time)
               continue;
            if(price >= lb.zoneLow && price <= lb.zoneHigh)
              {
               zoneType = lb.GetNomenclature(m_ms.tf_str());
               outLow   = lb.zoneLow;
               outHigh  = lb.zoneHigh;
               outTime  = lb.createdTime;
               return true;
              }
           }
        }
     }

// 3. Check Active Sellers' Inducements
   if(m_useInducementsForGuard && m_indLogic != NULL)
     {
      for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
        {
         CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
         if(ind != NULL && ind.isInducement && !ind.isBullish && !ind.isMitigated)
           {
            if(at_time > 0 && ind.createdTime > at_time)
               continue;
            if(price >= ind.zoneLow && price <= ind.zoneHigh)
              {
               zoneType = "Sellers' Inducement";
               outLow   = ind.zoneLow;
               outHigh  = ind.zoneHigh;
               outTime  = ind.createdTime;
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Extended Nearest Bullish Boundary Seeker                         |
//+------------------------------------------------------------------+
bool CGuardedLiquidityEngine::GetNearestBullishBoundaryGuarded(string sym, double price, double &outBoundary, string &outName, datetime at_time)
  {
   outBoundary = 0.0;
   outName     = "";
   double min_dist = DBL_MAX;

// Direct Selection: Liquidity Blocks Only
   if(m_zoneRiskSource == ZONE_SELECT_LIQUIDITY_BLOCKS && m_lbLogic != NULL)
     {
      for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
         if(lb != NULL && lb.isBullish && !lb.isMitigated)
           {
            if(at_time > 0 && lb.createdTime > at_time)
               continue;
            if(lb.zoneLow < price && (price - lb.zoneLow) < min_dist)
              {
               min_dist    = price - lb.zoneLow;
               outBoundary = lb.zoneLow;
               outName     = lb.GetNomenclature(m_ms.tf_str());
              }
           }
        }
      return (outBoundary > 0.0);
     }

// Direct Selection: Inducements Only
   if(m_zoneRiskSource == ZONE_SELECT_INDUCEMENTS && m_indLogic != NULL)
     {
      for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
        {
         CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
         if(ind != NULL && ind.isInducement && ind.isBullish && !ind.isMitigated)
           {
            if(at_time > 0 && ind.createdTime > at_time)
               continue;
            if(ind.zoneLow < price && (price - ind.zoneLow) < min_dist)
              {
               min_dist    = price - ind.zoneLow;
               outBoundary = ind.zoneLow;
               outName     = "Buyers' Inducement";
              }
           }
        }
      return (outBoundary > 0.0);
     }

// Base SMC checks
   bool found = GetNearestBullishBoundary(sym, price, outBoundary, outName, at_time);
   if(found && outBoundary > 0.0)
      min_dist = price - outBoundary;

// Nearest All: compare against LBs and Inducements
   if(m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL)
     {
      if(m_useLiquidityBlocksForGuard && m_lbLogic != NULL)
        {
         for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
            if(lb != NULL && lb.isBullish && !lb.isMitigated)
              {
               if(at_time > 0 && lb.createdTime > at_time)
                  continue;
               if(lb.zoneLow < price && (price - lb.zoneLow) < min_dist)
                 {
                  min_dist    = price - lb.zoneLow;
                  outBoundary = lb.zoneLow;
                  outName     = lb.GetNomenclature(m_ms.tf_str());
                  found       = true;
                 }
              }
           }
        }

      if(m_useInducementsForGuard && m_indLogic != NULL)
        {
         for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
           {
            CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
            if(ind != NULL && ind.isInducement && ind.isBullish && !ind.isMitigated)
              {
               if(at_time > 0 && ind.createdTime > at_time)
                  continue;
               if(ind.zoneLow < price && (price - ind.zoneLow) < min_dist)
                 {
                  min_dist    = price - ind.zoneLow;
                  outBoundary = ind.zoneLow;
                  outName     = "Buyers' Inducement";
                  found       = true;
                 }
              }
           }
        }
     }

   return (outBoundary > 0.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CGuardedLiquidityEngine::GetNearestBearishBoundaryGuarded(string sym, double price, double &outBoundary, string &outName, datetime at_time)
  {
   outBoundary = 0.0;
   outName     = "";
   double min_dist = DBL_MAX;

// Direct Selection: Liquidity Blocks Only
   if(m_zoneRiskSource == ZONE_SELECT_LIQUIDITY_BLOCKS && m_lbLogic != NULL)
     {
      for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
         if(lb != NULL && !lb.isBullish && !lb.isMitigated)
           {
            if(at_time > 0 && lb.createdTime > at_time)
               continue;
            if(lb.zoneHigh > price && (lb.zoneHigh - price) < min_dist)
              {
               min_dist    = lb.zoneHigh - price;
               outBoundary = lb.zoneHigh;
               outName     = lb.GetNomenclature(m_ms.tf_str());
              }
           }
        }
      return (outBoundary > 0.0);
     }

// Direct Selection: Inducements Only
   if(m_zoneRiskSource == ZONE_SELECT_INDUCEMENTS && m_indLogic != NULL)
     {
      for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
        {
         CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
         if(ind != NULL && ind.isInducement && !ind.isBullish && !ind.isMitigated)
           {
            if(at_time > 0 && ind.createdTime > at_time)
               continue;
            if(ind.zoneHigh > price && (ind.zoneHigh - price) < min_dist)
              {
               min_dist    = ind.zoneHigh - price;
               outBoundary = ind.zoneHigh;
               outName     = "Sellers' Inducement";
              }
           }
        }
      return (outBoundary > 0.0);
     }

// Base SMC checks
   bool found = GetNearestBearishBoundary(sym, price, outBoundary, outName, at_time);
   if(found && outBoundary > 0.0)
      min_dist = outBoundary - price;

// Nearest All: compare against LBs and Inducements
   if(m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL)
     {
      if(m_useLiquidityBlocksForGuard && m_lbLogic != NULL)
        {
         for(int i = 0; i < m_lbLogic.m_liquidity_blocks.Total(); i++)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_lbLogic.m_liquidity_blocks.At(i);
            if(lb != NULL && !lb.isBullish && !lb.isMitigated)
              {
               if(at_time > 0 && lb.createdTime > at_time)
                  continue;
               if(lb.zoneHigh > price && (lb.zoneHigh - price) < min_dist)
                 {
                  min_dist    = lb.zoneHigh - price;
                  outBoundary = lb.zoneHigh;
                  outName     = lb.GetNomenclature(m_ms.tf_str());
                  found       = true;
                 }
              }
           }
        }

      if(m_useInducementsForGuard && m_indLogic != NULL)
        {
         for(int i = 0; i < m_indLogic.m_zones.Total(); i++)
           {
            CInducementZone* ind = (CInducementZone*)m_indLogic.m_zones.At(i);
            if(ind != NULL && ind.isInducement && !ind.isBullish && !ind.isMitigated)
              {
               if(at_time > 0 && ind.createdTime > at_time)
                  continue;
               if(ind.zoneHigh > price && (ind.zoneHigh - price) < min_dist)
                 {
                  min_dist    = ind.zoneHigh - price;
                  outBoundary = ind.zoneHigh;
                  outName     = "Sellers' Inducement";
                  found       = true;
                 }
              }
           }
        }
     }

   return (outBoundary > 0.0);
  }

//+------------------------------------------------------------------+
//| Calculate Max Safe Lot Size with LBs & Inducements Included      |
//+------------------------------------------------------------------+
double CGuardedLiquidityEngine::CalculateMaxAllowedLotGuarded(string sym, int direction, double custom_price, datetime at_time)
  {
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free_margin <= 0.0)
      free_margin = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0 || free_margin <= 0.0)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   double max_risk_money = balance * (m_maxRiskPercent / 100.0);

   double ask       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_BID);
   double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = point;
   double tick_val  = GetSymbolTickValue(sym);

   double price_distance = 0.0;
   string zName          = "";
   double zBoundary      = 0.0;

   if(direction == -1)
     {
      if(GetNearestBearishBoundaryGuarded(sym, bid, zBoundary, zName, at_time))
         price_distance = MathAbs(zBoundary - bid);
     }
   else
      if(direction == 1)
        {
         if(GetNearestBullishBoundaryGuarded(sym, ask, zBoundary, zName, at_time))
            price_distance = MathAbs(ask - zBoundary);
        }
      else
        {
         double buy_dist = 0.0, sell_dist = 0.0;
         if(GetNearestBearishBoundaryGuarded(sym, bid, zBoundary, zName, at_time))
            sell_dist = MathAbs(zBoundary - bid);
         if(GetNearestBullishBoundaryGuarded(sym, ask, zBoundary, zName, at_time))
            buy_dist = MathAbs(ask - zBoundary);

         if(buy_dist > 0.0 && sell_dist > 0.0)
            price_distance = MathMin(buy_dist, sell_dist);
         else
            price_distance = MathMax(buy_dist, sell_dist);
        }

   if(price_distance <= 0.0)
      price_distance = 100.0 * point * 10;

   if(!m_excludeSpread)
     {
      long sp_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
      price_distance += (sp_pts * point);
     }

   double loss_per_lot = (price_distance / tick_size) * tick_val;
   double max_lot_by_risk = (loss_per_lot > 0.0) ? (max_risk_money / loss_per_lot) : 0.01;

   double margin_1_lot = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ask, margin_1_lot) || margin_1_lot <= 0.0)
     {
      long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(lev <= 0)
         lev = 100;
      double csz = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      margin_1_lot = (1.0 * csz * ask) / (double)lev;
     }

   double max_lot_by_margin = max_lot_by_risk;
   if(margin_1_lot > 0.0)
      max_lot_by_margin = (free_margin * 0.90) / margin_1_lot;

   double max_lot = MathMin(max_lot_by_risk, max_lot_by_margin);

   double lot_step       = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double min_lot        = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot_broker = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);

   if(lot_step > 0.0)
      max_lot = MathFloor(max_lot / lot_step) * lot_step;

   max_lot = MathMax(min_lot, MathMin(max_lot, max_lot_broker));
   int lot_digits = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step > 0.0 ? lot_step : 0.01)));

   return NormalizeDouble(max_lot, lot_digits);
  }

//+------------------------------------------------------------------+
//| Pre-Trade Buy with Extended Zone Checking                        |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::ExecutePreTradeBuyGuarded()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockLongsInBearish && IsInBearishZoneGuarded(ask, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, false);
      Print("🛑 BUY BLOCKED: Price is currently inside a Bearish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBullishBoundaryGuarded(_Symbol, ask, zBoundary, zName))
      zBoundary = ask - (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_buy = CalculateMaxAllowedLotGuarded(_Symbol, 1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_buy : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_buy)
     {
      double oversize = lot_to_trade - max_safe_buy;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 BUY BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_buy));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot_to_trade, ask, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 BUY BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Buy(lot_to_trade, _Symbol, ask, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

//+------------------------------------------------------------------+
//| Pre-Trade Sell with Extended Zone Checking                       |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::ExecutePreTradeSellGuarded()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockShortsInBullish && IsInBullishZoneGuarded(bid, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, true);
      Print("🛑 SELL BLOCKED: Price is currently inside a Bullish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBearishBoundaryGuarded(_Symbol, bid, zBoundary, zName))
      zBoundary = bid + (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_sell = CalculateMaxAllowedLotGuarded(_Symbol, -1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_sell : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_sell)
     {
      double oversize = lot_to_trade - max_safe_sell;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 SELL BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_sell));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lot_to_trade, bid, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 SELL BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Sell(lot_to_trade, _Symbol, bid, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

//+------------------------------------------------------------------+
//| Update Draggable Panel HUD Numbers with Guarded Lot Sizing       |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::UpdatePanelHUDGuarded()
  {
   if(!m_showOrderPanel)
      return;

   UpdatePanelHUD();

   if(m_panel_minimized)
      return;

   double max_safe_buy  = CalculateMaxAllowedLotGuarded(_Symbol, 1);
   double max_safe_sell = CalculateMaxAllowedLotGuarded(_Symbol, -1);

// Update directional safe lot HUD box
   ObjectSetString(0, PANEL_PREFIX + "C4_Val", OBJPROP_TEXT, StringFormat("%.2f | %.2f", max_safe_buy, max_safe_sell));
  }

//+------------------------------------------------------------------+
//| Unified Master Shield Loop                                       |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::RunMasterGuardedShield()
  {
   UpdateGuardedLiquidity();

   AuditRunningPositions();

   CheckProfitProtectionGuard();

   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         string pos_sym = m_position.Symbol();

         if(!m_manageAllSymbols && pos_sym != _Symbol)
            continue;

         if(m_magicNumber == 0 || m_position.Magic() == m_magicNumber)
           {
            if(m_emergencyCircuitBreaker)
               CheckEmergencyLossCut(pos_sym);

            if(m_autoBreakeven)
               CheckAndSetBreakevenSL(pos_sym);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnTickGuarded()
  {
   RunMasterGuardedShield();
   UpdatePanelHUDGuarded();
  }

//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnTimerGuarded()
  {
   RunMasterGuardedShield();
   UpdatePanelHUDGuarded();
  }

//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnTradeGuarded()
  {
   RunMasterGuardedShield();
   UpdatePanelHUDGuarded();
  }

//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnTradeTransactionGuarded(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   UpdatePanelHUDGuarded();
  }

//+------------------------------------------------------------------+
void CGuardedLiquidityEngine::OnChartEventGuarded(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == PANEL_PREFIX + "BtnBuy")
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ExecutePreTradeBuyGuarded();
         ChartRedraw(0);
         return;
        }
      else
         if(sparam == PANEL_PREFIX + "BtnSell")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ExecutePreTradeSellGuarded();
            ChartRedraw(0);
            return;
           }
     }

   ProcessChartEvents(id, lparam, dparam, sparam);
  }

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\Guarded_Liquidity.mqh

// END FILE: Include\Custom\Marcotrades\Guarded_Liquidity.mqh
