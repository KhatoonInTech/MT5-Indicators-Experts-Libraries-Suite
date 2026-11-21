//+------------------------------------------------------------------+
//|                  Include\Custom\Marcotrades\liquidity_swept_backtesting.mqh |
//|                 Liquidity Swept Backtesting Simulation Engine    |
//|                 Integrated with Guardrails Risk & Marcotrades SMC|
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.01"

#ifndef LIQUIDITY_SWEPT_BACKTESTING_MQH
#define LIQUIDITY_SWEPT_BACKTESTING_MQH

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\Inducements.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mql_plotting.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\teams_alert.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\poc_analyzer.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\entry_model.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mq5_dashboard.mqh"

#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayString.mqh>

// =========================================================================
// API IMPORTS & HELPER GUARDS
// =========================================================================
#ifndef SHELL_EXECUTE_DEF
#define SHELL_EXECUTE_DEF
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import
#endif

#ifndef FIND_CHART_ID_FN
#define FIND_CHART_ID_FN
long FindChartID(string sym, ENUM_TIMEFRAMES tf)
  {
   long currChart = ChartFirst();
   while(currChart >= 0)
     {
      if(ChartSymbol(currChart) == sym && ChartPeriod(currChart) == tf)
        {
         return currChart;
        }
      currChart = ChartNext(currChart);
     }
   return -1;
  }
#endif

//+------------------------------------------------------------------+
//| Simulated Trade Record Model                                     |
//+------------------------------------------------------------------+
struct SLiquiditySweptTrade
  {
   ulong             ticket;
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   int               direction;          // 1 = BUY, -1 = SELL
   string            nomenclature;       // TF-BL-LB-IND, TF-BR-LB-IND, TF-BL-LB-SSL, TF-BR-LB-BSL
   datetime          openTime;
   double            openPrice;
   double            slPrice;
   double            tpPrice;
   double            lots;
   double            riskAmount;
   double            targetProfit;
   string            opposingInducementId;

   bool              isOpen;
   datetime          closeTime;
   double            closePrice;
   double            realizedProfit;
   double            rMultiple;
   string            outcome;            // "WIN", "LOSS", "BE", "OPEN"
   bool              isBreakevenSet;
  };

//+------------------------------------------------------------------+
//| Backtest Performance Metrics Tracker                             |
//+------------------------------------------------------------------+
class CLiquiditySweptMetrics
  {
public:
   int               totalTrades;
   int               wins;
   int               losses;
   int               breakevens;
   double            winRate;
   double            totalProfit;
   double            maxDrawdown;
   double            avgRMultiple;
   double            profitFactor;

   int               trades_BL_IND;
   int               wins_BL_IND;
   int               trades_BR_IND;
   int               wins_BR_IND;
   int               trades_BL_SSL;
   int               wins_BL_SSL;
   int               trades_BR_BSL;
   int               wins_BR_BSL;

                     CLiquiditySweptMetrics() { Reset(); }

   void              Reset()
     {
      totalTrades   = 0;
      wins          = 0;
      losses        = 0;
      breakevens    = 0;
      winRate       = 0.0;
      totalProfit   = 0.0;
      maxDrawdown   = 0.0;
      avgRMultiple  = 0.0;
      profitFactor  = 0.0;
      trades_BL_IND = 0;
      wins_BL_IND = 0;
      trades_BR_IND = 0;
      wins_BR_IND = 0;
      trades_BL_SSL = 0;
      wins_BL_SSL = 0;
      trades_BR_BSL = 0;
      wins_BR_BSL = 0;
     }

   void              Calculate()
     {
      int completed = wins + losses + breakevens;
      if(completed > 0)
         winRate = ((double)wins / completed) * 100.0;
      else
         winRate = 0.0;
     }
  };

//+------------------------------------------------------------------+
//| Single-Symbol Backtest Instance                                  |
//+------------------------------------------------------------------+
class CLiquiditySweptBacktestInstance
  {
public:
   string                 symbol;
   ENUM_TIMEFRAMES        tradeTF;
   ENUM_TIMEFRAMES        tpInducementTF;

   // Engine Parameters
   int                    m_maxLookback;
   double                 m_deviation;
   int                    m_depth;

   // Guardrails Parameters
   double                 m_maxRiskPercent;
   bool                   m_enforceMaxLot;
   bool                   m_excludeSpread;
   bool                   m_autoBreakeven;
   double                 m_beMultiplier;
   int                    m_beBuffer;

   // Trigger Configuration
   bool                   m_triggerBLCHoCH;
   bool                   m_triggerSSLSwept;
   bool                   m_triggerBRCHoCH;
   bool                   m_triggerBSLSwept;
   double                 m_slBufferPips;
   double                 m_minRRRatio;

   // Visual Debugging
   bool                   m_drawCharts;
   color                  m_colWin;
   color                  m_colLoss;

   // SMC Core Engines
   ZigZag*                zigZag;
   CMarketStructure*      ms;
   CDemandSupplyLogic*    dsLogic;
   CSwingPOILogic*        spLogic;
   COrderBlockLogic*      obLogic;
   CFlipZoneLogic*        fzLogic;
   CBreakerBlockLogic*    bbLogic;
   CInducementLogic*      indLogic;
   CLiquidityBlockLogic*  lbLogic;

   // Dedicated TP Inducement TF Engine (if TP timeframe differs from trade TF)
   ZigZag*                tp_zigZag;
   CMarketStructure*      tp_ms;
   CDemandSupplyLogic*    tp_dsLogic;
   CSwingPOILogic*        tp_spLogic;
   COrderBlockLogic*      tp_obLogic;
   CFlipZoneLogic*        tp_fzLogic;
   CBreakerBlockLogic*    tp_bbLogic;
   CInducementLogic*      tp_indLogic;

   SLiquiditySweptTrade   m_trades[];
   CLiquiditySweptMetrics metrics;
   ulong                  m_ticket_counter;

                     CLiquiditySweptBacktestInstance(
      string _symbol, ENUM_TIMEFRAMES _tradeTF, ENUM_TIMEFRAMES _tpIndTF,
      double devInput, int depInput, int maxLB,
      double riskPct, bool enforceLot, bool excludeSpread,
      bool autoBE, double beMult, int beBuf,
      bool trigBLCHoCH, bool trigSSLSwept, bool trigBRCHoCH, bool trigBSLSwept,
      double slBufPips, double minRR,
      bool draw, color cWin, color cLoss,
      int minTouches, double proxPips, bool mergeClustered, double clusterTol
   )
     {
      symbol             = _symbol;
      tradeTF            = _tradeTF;
      tpInducementTF     = _tpIndTF;
      m_deviation        = devInput;
      m_depth            = depInput;
      m_maxLookback      = maxLB;

      m_maxRiskPercent   = riskPct;
      m_enforceMaxLot    = enforceLot;
      m_excludeSpread    = excludeSpread;
      m_autoBreakeven    = autoBE;
      m_beMultiplier     = beMult;
      m_beBuffer         = beBuf;

      m_triggerBLCHoCH   = trigBLCHoCH;
      m_triggerSSLSwept  = trigSSLSwept;
      m_triggerBRCHoCH   = trigBRCHoCH;
      m_triggerBSLSwept  = trigBSLSwept;
      m_slBufferPips     = slBufPips;
      m_minRRRatio       = minRR;

      m_drawCharts       = draw;
      m_colWin           = cWin;
      m_colLoss          = cLoss;
      m_ticket_counter   = 1000;

      // 1. Initialize Trade TF Engines
      Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      zigZag = newInstance(s);

      ms       = new CMarketStructure();
      ms.Init(false, false);
      dsLogic  = new CDemandSupplyLogic();
      spLogic  = new CSwingPOILogic();
      obLogic  = new COrderBlockLogic();
      fzLogic  = new CFlipZoneLogic();
      bbLogic  = new CBreakerBlockLogic();

      indLogic = new CInducementLogic();
      indLogic.Init(minTouches, proxPips, true, true, true, false, false, true, mergeClustered, clusterTol, false);

      lbLogic  = new CLiquidityBlockLogic();
      lbLogic.Init(trigSSLSwept || trigBSLSwept, trigBLCHoCH || trigBRCHoCH);

      // 2. Initialize TP Timeframe Inducement Engine
      if(tpInducementTF != tradeTF)
        {
         Settings* s_tp = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
         s_tp.draw = false;
         tp_zigZag   = newInstance(s_tp);
         tp_ms       = new CMarketStructure();
         tp_ms.Init(false, false);
         tp_dsLogic  = new CDemandSupplyLogic();
         tp_spLogic  = new CSwingPOILogic();
         tp_obLogic  = new COrderBlockLogic();
         tp_fzLogic  = new CFlipZoneLogic();
         tp_bbLogic  = new CBreakerBlockLogic();
         tp_indLogic = new CInducementLogic();
         tp_indLogic.Init(minTouches, proxPips, true, true, true, false, false, true, mergeClustered, clusterTol, false);
        }
      else
        {
         tp_zigZag   = NULL;
         tp_ms       = NULL;
         tp_dsLogic  = NULL;
         tp_spLogic  = NULL;
         tp_obLogic  = NULL;
         tp_fzLogic  = NULL;
         tp_bbLogic  = NULL;
         tp_indLogic = NULL;
        }

      metrics.Reset();
     }

                    ~CLiquiditySweptBacktestInstance()
     {
      if(CheckPointer(zigZag)      == POINTER_DYNAMIC)
         delete zigZag;
      if(CheckPointer(ms)          == POINTER_DYNAMIC)
         delete ms;
      if(CheckPointer(dsLogic)     == POINTER_DYNAMIC)
         delete dsLogic;
      if(CheckPointer(spLogic)     == POINTER_DYNAMIC)
         delete spLogic;
      if(CheckPointer(obLogic)     == POINTER_DYNAMIC)
         delete obLogic;
      if(CheckPointer(fzLogic)     == POINTER_DYNAMIC)
         delete fzLogic;
      if(CheckPointer(bbLogic)     == POINTER_DYNAMIC)
         delete bbLogic;
      if(CheckPointer(indLogic)    == POINTER_DYNAMIC)
         delete indLogic;
      if(CheckPointer(lbLogic)     == POINTER_DYNAMIC)
         delete lbLogic;

      if(CheckPointer(tp_zigZag)   == POINTER_DYNAMIC)
         delete tp_zigZag;
      if(CheckPointer(tp_ms)       == POINTER_DYNAMIC)
         delete tp_ms;
      if(CheckPointer(tp_dsLogic)  == POINTER_DYNAMIC)
         delete tp_dsLogic;
      if(CheckPointer(tp_spLogic)  == POINTER_DYNAMIC)
         delete tp_spLogic;
      if(CheckPointer(tp_obLogic)  == POINTER_DYNAMIC)
         delete tp_obLogic;
      if(CheckPointer(tp_fzLogic)  == POINTER_DYNAMIC)
         delete tp_fzLogic;
      if(CheckPointer(tp_bbLogic)  == POINTER_DYNAMIC)
         delete tp_bbLogic;
      if(CheckPointer(tp_indLogic) == POINTER_DYNAMIC)
         delete tp_indLogic;
     }

   // Search the very next opposing unmitigated inducement zone
   bool              FindNextOpposingInducement(bool isBuy, double entryPrice, datetime currentTime,
         double &tpPrice, string &opposingId)
     {
      CInducementLogic* targetIndLogic = (tp_indLogic != NULL) ? tp_indLogic : indLogic;
      if(targetIndLogic == NULL)
         return false;

      tpPrice = 0.0;
      opposingId = "";
      double bestDist = DBL_MAX;

      for(int z = 0; z < targetIndLogic.m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)targetIndLogic.m_zones.At(z);
         if(zone == NULL || !zone.isInducement)
            continue;

         // Zone must still be unmitigated or mitigated strictly after current bar
         if(zone.isMitigated && zone.mitigationTime <= currentTime)
            continue;

         if(isBuy)
           {
            // For BUY: Look for Sellers' Inducement (Bearish) above entry
            if(!zone.isBullish && zone.zoneLow > entryPrice)
              {
               double dist = zone.zoneLow - entryPrice;
               if(dist < bestDist)
                 {
                  bestDist   = dist;
                  tpPrice    = zone.zoneLow; // Target front edge of opposing resistance
                  opposingId = zone.id;
                 }
              }
           }
         else
           {
            // For SELL: Look for Buyers' Inducement (Bullish) below entry
            if(zone.isBullish && zone.zoneHigh < entryPrice)
              {
               double dist = entryPrice - zone.zoneHigh;
               if(dist < bestDist)
                 {
                  bestDist   = dist;
                  tpPrice    = zone.zoneHigh; // Target front edge of opposing support
                  opposingId = zone.id;
                 }
              }
           }
        }

      return (tpPrice > 0.0);
     }

   // Universal Tick Value Resolver for simulation
   double            GetTickValue()
     {
      double tv = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tv <= 0)
         tv = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0)
         tv = 1.0;
      return tv;
     }

   // Calculate position sizing compliant with Guardrails Option B & C
   double            CalculateLotSize(double riskDistance, double price)
     {
      double balance = 10000.0; // Standard Backtest Account Base
      double riskMoney = balance * (m_maxRiskPercent / 100.0);

      double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0)
         tickSize = point;
      double tickVal  = GetTickValue();

      double lossPerLot = (riskDistance / tickSize) * tickVal;
      double lot = (lossPerLot > 0) ? (riskMoney / lossPerLot) : 0.01;

      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      if(lotStep <= 0)
         lotStep = 0.01;
      if(minLot <= 0)
         minLot = 0.01;
      if(maxLot <= 0)
         maxLot = 100.0;

      lot = MathFloor(lot / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(lot, maxLot));
      return NormalizeDouble(lot, 2);
     }

   // Execute Backtest Loop over Historical Data
   bool              RunBacktest()
     {
      int rates_total = Bars(symbol, tradeTF);
      if(rates_total < m_depth * 2)
         return false;

      int start_bar = MathMax(0, rates_total - m_maxLookback);
      int to_copy   = rates_total - start_bar;
      if(to_copy <= 0)
         return false;

      datetime time[];
      double open[], high[], low[], close[];
      long vol[];
      if(CopyTime(symbol, tradeTF, 0, to_copy, time) <= 0 ||
         CopyOpen(symbol, tradeTF, 0, to_copy, open) <= 0 ||
         CopyHigh(symbol, tradeTF, 0, to_copy, high) <= 0 ||
         CopyLow(symbol, tradeTF, 0, to_copy, low) <= 0 ||
         CopyClose(symbol, tradeTF, 0, to_copy, close) <= 0 ||
         CopyTickVolume(symbol, tradeTF, 0, to_copy, vol) <= 0)
         return false;

      datetime tp_time[];
      double tp_high[], tp_low[], tp_close[], tp_open[];
      long tp_vol[];
      int tp_copy = 0;
      if(tpInducementTF != tradeTF)
        {
         int tp_rates = Bars(symbol, tpInducementTF);
         int tp_start = MathMax(0, tp_rates - m_maxLookback);
         tp_copy = tp_rates - tp_start;
         CopyTime(symbol, tpInducementTF, 0, tp_copy, tp_time);
         CopyOpen(symbol, tpInducementTF, 0, tp_copy, tp_open);
         CopyHigh(symbol, tpInducementTF, 0, tp_copy, tp_high);
         CopyLow(symbol, tpInducementTF, 0, tp_copy, tp_low);
         CopyClose(symbol, tpInducementTF, 0, tp_copy, tp_close);
         CopyTickVolume(symbol, tpInducementTF, 0, tp_copy, tp_vol);
        }

      int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
      double slBuffer = m_slBufferPips * pipSize;

      string tfStr = ms.tf_str();
      datetime last_checked_bo = 0;

      // Main Chronological Bar Simulator Loop
      for(int i = 0; i < to_copy; i++)
        {
         bool is_last = (i == to_copy - 1);
         int bar_idx  = start_bar + i;

         // 1. Process Core Trade TF Structure
         zigZag.update(high[i], low[i], time[i], vol[i], bar_idx, !is_last, is_last);
         ms.Update(i, time, high, low, close, zigZag);
         dsLogic.DetectPOIs(i, time, high, low, zigZag);
         dsLogic.UpdateMitigation(close[i]);
         spLogic.DetectPOIs(i, time, high, low, zigZag);
         spLogic.UpdateMitigation(close[i]);
         obLogic.DetectPOIs(i, time, high, low, zigZag);
         obLogic.UpdateMitigation(close[i]);
         fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
         fzLogic.UpdateMitigation(close[i]);
         bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);
         bbLogic.UpdateMitigation(high[i], low[i], time[i]);

         indLogic.Process(i, time, open, high, low, close, zigZag, ms, dsLogic, spLogic, obLogic, fzLogic, bbLogic, pipSize);
         lbLogic.Process(i, time, high, low, ms, spLogic, indLogic, zigZag);

         // 2. Synchronize TP Timeframe Inducements (if separate timeframe)
         if(tpInducementTF != tradeTF && tp_copy > 0)
           {
            int tp_i = -1;
            for(int k = tp_copy - 1; k >= 0; k--)
              {
               if(tp_time[k] <= time[i])
                 {
                  tp_i = k;
                  break;
                 }
              }
            if(tp_i >= 0)
              {
               tp_zigZag.update(tp_high[tp_i], tp_low[tp_i], tp_time[tp_i], tp_vol[tp_i], tp_i, false, true);
               tp_ms.Update(tp_i, tp_time, tp_high, tp_low, tp_close, tp_zigZag);
               tp_dsLogic.DetectPOIs(tp_i, tp_time, tp_high, tp_low, tp_zigZag);
               tp_dsLogic.UpdateMitigation(tp_close[tp_i]);
               tp_spLogic.DetectPOIs(tp_i, tp_time, tp_high, tp_low, tp_zigZag);
               tp_spLogic.UpdateMitigation(tp_close[tp_i]);
               tp_obLogic.DetectPOIs(tp_i, tp_time, tp_high, tp_low, tp_zigZag);
               tp_obLogic.UpdateMitigation(tp_close[tp_i]);
               tp_fzLogic.DetectFlipZones(tp_i, tp_time, tp_high, tp_low, tp_close, tp_zigZag, tp_ms, tp_dsLogic);
               tp_fzLogic.UpdateMitigation(tp_close[tp_i]);
               tp_bbLogic.DetectBreakers(tp_zigZag, tp_dsLogic, tp_spLogic, tp_obLogic, tp_fzLogic);
               tp_bbLogic.UpdateMitigation(tp_high[tp_i], tp_low[tp_i], tp_time[tp_i]);
               tp_indLogic.Process(tp_i, tp_time, tp_open, tp_high, tp_low, tp_close,
                                   tp_zigZag, tp_ms, tp_dsLogic, tp_spLogic, tp_obLogic, tp_fzLogic, tp_bbLogic, pipSize);
              }
           }

         // -------------------------------------------------------------
         // 3. MANAGE ACTIVE OPEN TRADES (Simulate Tick Hits & Guardrails)
         // -------------------------------------------------------------
         for(int t = 0; t < ArraySize(m_trades); t++)
           {
            if(!m_trades[t].isOpen)
               continue;

            // Check Auto-Breakeven
            if(m_autoBreakeven && !m_trades[t].isBreakevenSet)
              {
               double spreadPts = 10.0;
               double beDist = m_beMultiplier * (spreadPts * point);

               if(m_trades[t].direction == 1) // BUY
                 {
                  if(close[i] >= m_trades[t].openPrice + beDist)
                    {
                     m_trades[t].slPrice = NormalizeDouble(m_trades[t].openPrice + (m_beBuffer * point), digits);
                     m_trades[t].isBreakevenSet = true;
                    }
                 }
               else // SELL
                 {
                  if(close[i] <= m_trades[t].openPrice - beDist)
                    {
                     m_trades[t].slPrice = NormalizeDouble(m_trades[t].openPrice - (m_beBuffer * point), digits);
                     m_trades[t].isBreakevenSet = true;
                    }
                 }
              }

            // Check Trade Close (SL or TP hit)
            if(m_trades[t].direction == 1) // BUY
              {
               if(low[i] <= m_trades[t].slPrice)
                 {
                  m_trades[t].isOpen         = false;
                  m_trades[t].closeTime      = time[i];
                  m_trades[t].closePrice     = m_trades[t].slPrice;
                  m_trades[t].realizedProfit = (m_trades[t].slPrice - m_trades[t].openPrice) / point * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * m_trades[t].lots;
                  m_trades[t].outcome        = m_trades[t].isBreakevenSet ? "BE" : "LOSS";
                  m_trades[t].rMultiple      = m_trades[t].isBreakevenSet ? 0.0 : -1.0;
                 }
               else
                  if(high[i] >= m_trades[t].tpPrice)
                    {
                     m_trades[t].isOpen         = false;
                     m_trades[t].closeTime      = time[i];
                     m_trades[t].closePrice     = m_trades[t].tpPrice;
                     m_trades[t].realizedProfit = (m_trades[t].tpPrice - m_trades[t].openPrice) / point * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * m_trades[t].lots;
                     m_trades[t].outcome        = "WIN";
                     m_trades[t].rMultiple      = MathAbs(m_trades[t].tpPrice - m_trades[t].openPrice) / MathAbs(m_trades[t].openPrice - (m_trades[t].slPrice));
                    }
              }
            else // SELL
              {
               if(high[i] >= m_trades[t].slPrice)
                 {
                  m_trades[t].isOpen         = false;
                  m_trades[t].closeTime      = time[i];
                  m_trades[t].closePrice     = m_trades[t].slPrice;
                  m_trades[t].realizedProfit = (m_trades[t].openPrice - m_trades[t].slPrice) / point * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * m_trades[t].lots;
                  m_trades[t].outcome        = m_trades[t].isBreakevenSet ? "BE" : "LOSS";
                  m_trades[t].rMultiple      = m_trades[t].isBreakevenSet ? 0.0 : -1.0;
                 }
               else
                  if(low[i] <= m_trades[t].tpPrice)
                    {
                     m_trades[t].isOpen         = false;
                     m_trades[t].closeTime      = time[i];
                     m_trades[t].closePrice     = m_trades[t].tpPrice;
                     m_trades[t].realizedProfit = (m_trades[t].openPrice - m_trades[t].tpPrice) / point * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * m_trades[t].lots;
                     m_trades[t].outcome        = "WIN";
                     m_trades[t].rMultiple      = MathAbs(m_trades[t].openPrice - m_trades[t].tpPrice) / MathAbs(m_trades[t].slPrice - m_trades[t].openPrice);
                    }
              }
           }

         // -------------------------------------------------------------
         // 4. DETECT ENTRY TRIGGERS AT THE EXACT BREAKOUT BAR
         // -------------------------------------------------------------
         if(ms.last_breakout_time > 0 && ms.last_breakout_time != last_checked_bo)
           {
            last_checked_bo = ms.last_breakout_time;

            int totalLB = lbLogic.m_liquidity_blocks.Total();
            if(totalLB > 0)
              {
               CLiquidityBlock* latestLB = (CLiquidityBlock*)lbLogic.m_liquidity_blocks.At(totalLB - 1);
               if(latestLB != NULL && latestLB.createdBarIndex == i)
                 {
                  bool shouldTrade = false;
                  int dir = latestLB.isBullish ? 1 : -1;
                  string code = latestLB.GetNomenclature(tfStr);

                  if(latestLB.triggerType == LB_TRIGGER_BL_IND && m_triggerBLCHoCH)
                     shouldTrade = true;
                  if(latestLB.triggerType == LB_TRIGGER_BL_SSL && m_triggerSSLSwept)
                     shouldTrade = true;
                  if(latestLB.triggerType == LB_TRIGGER_BR_IND && m_triggerBRCHoCH)
                     shouldTrade = true;
                  if(latestLB.triggerType == LB_TRIGGER_BR_BSL && m_triggerBSLSwept)
                     shouldTrade = true;

                  if(shouldTrade)
                    {
                     double entryPx = close[i];
                     double slPx    = 0.0;
                     double tpPx    = 0.0;
                     string oppId   = "";

                     if(dir == 1) // BUY
                       {
                        slPx = NormalizeDouble(latestLB.zoneLow - slBuffer, digits);
                        if(!FindNextOpposingInducement(true, entryPx, time[i], tpPx, oppId))
                          {
                           tpPx = NormalizeDouble(entryPx + 2.0 * MathAbs(entryPx - slPx), digits);
                          }
                       }
                     else // SELL
                       {
                        slPx = NormalizeDouble(latestLB.zoneHigh + slBuffer, digits);
                        if(!FindNextOpposingInducement(false, entryPx, time[i], tpPx, oppId))
                          {
                           tpPx = NormalizeDouble(entryPx - 2.0 * MathAbs(slPx - entryPx), digits);
                          }
                       }

                     double riskDist   = MathAbs(entryPx - slPx);
                     double rewardDist = MathAbs(tpPx - entryPx);
                     double rrRatio    = (riskDist > 0) ? (rewardDist / riskDist) : 0.0;

                     if(rrRatio >= m_minRRRatio && riskDist > 0 && rewardDist > 0)
                       {
                        double lots = CalculateLotSize(riskDist, entryPx);

                        int sz = ArraySize(m_trades);
                        ArrayResize(m_trades, sz + 1);
                        m_trades[sz].ticket               = ++m_ticket_counter;
                        m_trades[sz].symbol               = symbol;
                        m_trades[sz].tf                   = tradeTF;
                        m_trades[sz].direction            = dir;
                        m_trades[sz].nomenclature         = code;
                        m_trades[sz].openTime             = time[i];
                        m_trades[sz].openPrice            = entryPx;
                        m_trades[sz].slPrice              = slPx;
                        m_trades[sz].tpPrice              = tpPx;
                        m_trades[sz].lots                 = lots;
                        m_trades[sz].riskAmount           = (riskDist / point) * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * lots;
                        m_trades[sz].targetProfit         = (rewardDist / point) * (GetTickValue() / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point)) * lots;
                        m_trades[sz].opposingInducementId = oppId;
                        m_trades[sz].isOpen               = true;
                        m_trades[sz].closeTime            = 0;
                        m_trades[sz].closePrice           = 0.0;
                        m_trades[sz].realizedProfit       = 0.0;
                        m_trades[sz].rMultiple            = 0.0;
                        m_trades[sz].outcome              = "OPEN";
                        m_trades[sz].isBreakevenSet       = false;
                       }
                    }
                 }
              }
           }
        }

      // -------------------------------------------------------------
      // 5. ACCUMULATE METRICS AND OPTIONAL CHART PLOTTING
      // -------------------------------------------------------------
      metrics.Reset();
      for(int t = 0; t < ArraySize(m_trades); t++)
        {
         metrics.totalTrades++;
         if(m_trades[t].outcome == "WIN")
           {
            metrics.wins++;
            metrics.totalProfit += m_trades[t].realizedProfit;
            metrics.avgRMultiple += m_trades[t].rMultiple;

            if(m_trades[t].nomenclature == tfStr + "-BL-LB-IND")
              {
               metrics.trades_BL_IND++;
               metrics.wins_BL_IND++;
              }
            if(m_trades[t].nomenclature == tfStr + "-BR-LB-IND")
              {
               metrics.trades_BR_IND++;
               metrics.wins_BR_IND++;
              }
            if(m_trades[t].nomenclature == tfStr + "-BL-LB-SSL")
              {
               metrics.trades_BL_SSL++;
               metrics.wins_BL_SSL++;
              }
            if(m_trades[t].nomenclature == tfStr + "-BR-LB-BSL")
              {
               metrics.trades_BR_BSL++;
               metrics.wins_BR_BSL++;
              }
           }
         else
            if(m_trades[t].outcome == "LOSS")
              {
               metrics.losses++;
               metrics.totalProfit += m_trades[t].realizedProfit;
               metrics.avgRMultiple -= 1.0;

               if(m_trades[t].nomenclature == tfStr + "-BL-LB-IND")
                  metrics.trades_BL_IND++;
               if(m_trades[t].nomenclature == tfStr + "-BR-LB-IND")
                  metrics.trades_BR_IND++;
               if(m_trades[t].nomenclature == tfStr + "-BL-LB-SSL")
                  metrics.trades_BL_SSL++;
               if(m_trades[t].nomenclature == tfStr + "-BR-LB-BSL")
                  metrics.trades_BR_BSL++;
              }
            else
               if(m_trades[t].outcome == "BE")
                 {
                  metrics.breakevens++;
                  metrics.totalProfit += m_trades[t].realizedProfit;

                  if(m_trades[t].nomenclature == tfStr + "-BL-LB-IND")
                     metrics.trades_BL_IND++;
                  if(m_trades[t].nomenclature == tfStr + "-BR-LB-IND")
                     metrics.trades_BR_IND++;
                  if(m_trades[t].nomenclature == tfStr + "-BL-LB-SSL")
                     metrics.trades_BL_SSL++;
                  if(m_trades[t].nomenclature == tfStr + "-BR-LB-BSL")
                     metrics.trades_BR_BSL++;
                 }

         if(m_drawCharts)
            DrawTradeDebug(m_trades[t]);
        }

      metrics.Calculate();
      return true;
     }

   // Visual Debugging Plotter on Matching Charts
   void              DrawTradeDebug(SLiquiditySweptTrade &trade)
     {
      long targetChart = FindChartID(symbol, tradeTF);
      if(targetChart < 0)
         return;

      string boxId = "LS_BT_" + trade.nomenclature + "_" + IntegerToString(trade.ticket);
      color fillCol = (trade.outcome == "WIN") ? m_colWin : ((trade.outcome == "LOSS") ? m_colLoss : clrGray);

      datetime endT = (trade.closeTime > 0) ? trade.closeTime : TimeCurrent();
      double topP   = MathMax(trade.openPrice, MathMax(trade.slPrice, trade.tpPrice));
      double botP   = MathMin(trade.openPrice, MathMin(trade.slPrice, trade.tpPrice));

      ObjectCreate(targetChart, boxId, OBJ_RECTANGLE, 0, trade.openTime, topP, endT, botP);
      ObjectSetInteger(targetChart, boxId, OBJPROP_COLOR, ColorToARGB_Custom(fillCol, 35));
      ObjectSetInteger(targetChart, boxId, OBJPROP_FILL, true);
      ObjectSetInteger(targetChart, boxId, OBJPROP_BACK, true);

      string el = boxId + "_entry";
      ObjectCreate(targetChart, el, OBJ_TREND, 0, trade.openTime, trade.openPrice, endT, trade.openPrice);
      ObjectSetInteger(targetChart, el, OBJPROP_COLOR, fillCol);
      ObjectSetInteger(targetChart, el, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(targetChart, el, OBJPROP_RAY_RIGHT, false);

      string sll = boxId + "_sl";
      ObjectCreate(targetChart, sll, OBJ_TREND, 0, trade.openTime, trade.slPrice, endT, trade.slPrice);
      ObjectSetInteger(targetChart, sll, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(targetChart, sll, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(targetChart, sll, OBJPROP_RAY_RIGHT, false);

      string tpl = boxId + "_tp";
      ObjectCreate(targetChart, tpl, OBJ_TREND, 0, trade.openTime, trade.tpPrice, endT, trade.tpPrice);
      ObjectSetInteger(targetChart, tpl, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(targetChart, tpl, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(targetChart, tpl, OBJPROP_RAY_RIGHT, false);

      string lbl = boxId + "_lbl";
      ObjectCreate(targetChart, lbl, OBJ_TEXT, 0, trade.openTime, trade.openPrice);
      ObjectSetString(targetChart, lbl, OBJPROP_TEXT, trade.nomenclature + " [" + trade.outcome + "]");
      ObjectSetInteger(targetChart, lbl, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(targetChart, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetString(targetChart, lbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(targetChart, lbl, OBJPROP_BACK, false);

      ChartRedraw(targetChart);
     }
  };

// =============================================================================
// COORDINATED MULTI-SYMBOL BACKTEST REPORT ENGINE
// =============================================================================
class CLiquiditySweptBacktestEngine
  {
private:
   CLiquiditySweptBacktestInstance* instances[];
   int                             total_instances;
   int                             current_scan_idx;
   bool                            report_published;
   string                          master_csv_report;

   bool              IsCrypto(string sym) { return (StringFind(sym, "BTC") >= 0); }
   bool              IsMetal(string sym)  { return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0); }

public:
                     CLiquiditySweptBacktestEngine()
     {
      total_instances  = 0;
      current_scan_idx = 0;
      report_published = false;
      master_csv_report= "";
     }

                    ~CLiquiditySweptBacktestEngine()
     {
      for(int i = 0; i < total_instances; i++)
         if(CheckPointer(instances[i]) == POINTER_DYNAMIC)
            delete instances[i];
     }

   void              Initialize(
      ENUM_TIMEFRAMES tradeTF, ENUM_TIMEFRAMES tpIndTF,
      int scanSpeed, double riskPct, bool enforceLot, bool excludeSpread,
      bool autoBE, double beMult, int beBuf,
      bool trigBLCHoCH, bool trigSSLSwept, bool trigBRCHoCH, bool trigBSLSwept,
      double slBufPips, double minRR,
      bool draw, color cWin, color cLoss,
      int minTouches, double proxPips, bool mergeClustered, double clusterTol,
      int fxLB, double fxD1Dev, int fxD1Dep, double fxH4Dev, int fxH4Dep, double fxH1Dev, int fxH1Dep, double fxM15Dev, int fxM15Dep,
      int metLB, double metD1Dev, int metD1Dep, double metH4Dev, int metH4Dep, double metH1Dev, int metH1Dep, double metM15Dev, int metM15Dep,
      int cryLB, double cryD1Dev, int cryD1Dep, double cryH4Dev, int cryH4Dep, double cryH1Dev, int cryH1Dep, double cryM15Dev, int cryM15Dep
   )
     {
      string TargetSymbols[] =
        {
         "BTCUSDm", "XAGUSDm", "XAUUSDm",
         "AUDCADm", "AUDCHFm", "AUDJPYm", "AUDNZDm", "AUDUSDm",
         "CADCHFm", "CADJPYm", "CHFJPYm",
         "EURAUDm", "EURCADm", "EURCHFm", "EURGBPm", "EURJPYm", "EURNZDm", "EURUSDm",
         "GBPAUDm", "GBPCADm", "GBPCHFm", "GBPJPYm", "GBPNZDm", "GBPUSDm",
         "NZDCADm", "NZDCHFm", "NZDJPYm", "NZDUSDm",
         "USDCADm", "USDCHFm", "USDJPYm"
        };

      total_instances = ArraySize(TargetSymbols);
      ArrayResize(instances, total_instances);

      for(int s = 0; s < total_instances; s++)
        {
         SymbolSelect(TargetSymbols[s], true);
         bool isMet = IsMetal(TargetSymbols[s]);
         bool isCry = IsCrypto(TargetSymbols[s]);

         int maxLB  = isMet ? metLB : (isCry ? cryLB : fxLB);
         double dev = 1.0;
         int dep    = 15;

         if(isMet)
           {
            if(tradeTF == PERIOD_D1)
              {
               dev = metD1Dev;
               dep = metD1Dep;
              }
            else
               if(tradeTF == PERIOD_H4)
                 {
                  dev = metH4Dev;
                  dep = metH4Dep;
                 }
               else
                  if(tradeTF == PERIOD_H1)
                    {
                     dev = metH1Dev;
                     dep = metH1Dep;
                    }
                  else
                     if(tradeTF == PERIOD_M15)
                       {
                        dev = metM15Dev;
                        dep = metM15Dep;
                       }
           }
         else
            if(isCry)
              {
               if(tradeTF == PERIOD_D1)
                 {
                  dev = cryD1Dev;
                  dep = cryD1Dep;
                 }
               else
                  if(tradeTF == PERIOD_H4)
                    {
                     dev = cryH4Dev;
                     dep = cryH4Dep;
                    }
                  else
                     if(tradeTF == PERIOD_H1)
                       {
                        dev = cryH1Dev;
                        dep = cryH1Dep;
                       }
                     else
                        if(tradeTF == PERIOD_M15)
                          {
                           dev = cryM15Dev;
                           dep = cryM15Dep;
                          }
              }
            else
              {
               if(tradeTF == PERIOD_D1)
                 {
                  dev = fxD1Dev;
                  dep = fxD1Dep;
                 }
               else
                  if(tradeTF == PERIOD_H4)
                    {
                     dev = fxH4Dev;
                     dep = fxH4Dep;
                    }
                  else
                     if(tradeTF == PERIOD_H1)
                       {
                        dev = fxH1Dev;
                        dep = fxH1Dep;
                       }
                     else
                        if(tradeTF == PERIOD_M15)
                          {
                           dev = fxM15Dev;
                           dep = fxM15Dep;
                          }
              }

         instances[s] = new CLiquiditySweptBacktestInstance(
            TargetSymbols[s], tradeTF, tpIndTF, dev, dep, maxLB,
            riskPct, enforceLot, excludeSpread, autoBE, beMult, beBuf,
            trigBLCHoCH, trigSSLSwept, trigBRCHoCH, trigBSLSwept,
            slBufPips, minRR, draw, cWin, cLoss,
            minTouches, proxPips, mergeClustered, clusterTol
         );
        }

      master_csv_report = "Symbol,TradeTF,TPInducementTF,TotalTrades,Wins,Losses,Breakevens,WinRate,TotalProfit,AvgRMultiple," +
                          "TF-BL-LB-IND_Trades,TF-BL-LB-IND_Wins,TF-BR-LB-IND_Trades,TF-BR-LB-IND_Wins," +
                          "TF-BL-LB-SSL_Trades,TF-BL-LB-SSL_Wins,TF-BR-LB-BSL_Trades,TF-BR-LB-BSL_Wins\r\n";

      PrintFormat("🚀 Liquidity Swept Backtest Engine initialized for %d symbols. Timeframe: %s | TP Inducement TF: %s",
                  total_instances, EnumToString(tradeTF), EnumToString(tpIndTF));
     }

   void              ProcessBatch(int speed)
     {
      if(report_published)
         return;

      int processed = 0;
      while(processed < speed && current_scan_idx < total_instances)
        {
         PrintFormat("[%d/%d] 🔄 Backtesting: %s...", current_scan_idx + 1, total_instances, instances[current_scan_idx].symbol);
         instances[current_scan_idx].RunBacktest();

         CLiquiditySweptMetrics m = instances[current_scan_idx].metrics;
         master_csv_report += StringFormat(
                                 "%s,%s,%s,%d,%d,%d,%d,%.2f,%.2f,%.2f,%d,%d,%d,%d,%d,%d,%d,%d\r\n",
                                 CleanSymbol(instances[current_scan_idx].symbol),
                                 EnumToString(instances[current_scan_idx].tradeTF),
                                 EnumToString(instances[current_scan_idx].tpInducementTF),
                                 m.totalTrades, m.wins, m.losses, m.breakevens, m.winRate, m.totalProfit, m.avgRMultiple,
                                 m.trades_BL_IND, m.wins_BL_IND, m.trades_BR_IND, m.wins_BR_IND,
                                 m.trades_BL_SSL, m.wins_BL_SSL, m.trades_BR_BSL, m.wins_BR_BSL
                              );

         current_scan_idx++;
         processed++;
        }

      if(current_scan_idx >= total_instances)
        {
         string fileName = "SMC_Liquidity_Swept_Backtest_Report.csv";
         int fh = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
         if(fh != INVALID_HANDLE)
           {
            FileWriteString(fh, master_csv_report);
            FileClose(fh);
            PrintFormat("💾 Master Report saved: MQL5/Files/%s", fileName);
           }

         string data_path  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
         string py_command = "/c python format_and_upload.py";
         ShellExecuteW(0, "open", "cmd.exe", py_command, data_path, 0);

         report_published = true;
         Print("🎉 Multi-Symbol Liquidity Swept Backtest fully complete!");
        }
     }

   bool              IsCompleted() { return report_published; }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_swept_backtesting.mqh
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_swept_backtesting.mqh

// END FILE: Include\Custom\Marcotrades\liquidity_swept_backtesting.mqh
