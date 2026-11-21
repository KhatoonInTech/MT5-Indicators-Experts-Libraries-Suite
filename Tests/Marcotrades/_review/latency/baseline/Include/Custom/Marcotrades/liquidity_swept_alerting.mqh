//+------------------------------------------------------------------+
//|                      Include\Custom\Marcotrades\liquidity_swept_alerting.mqh |
//|                 Smart Money Concepts: Liquidity Swept Alert Engine|
//|                 - TF-BL-LB-IND & TF-BL-LB-SSL                    |
//|                 - TF-BR-LB-IND & TF-BR-LB-BSL                    |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.00"

#ifndef LIQUIDITY_SWEPT_ALERTING_MQH
#define LIQUIDITY_SWEPT_ALERTING_MQH

#include <Custom\Marcotrades\Inducements.mqh>
#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\ZigZag\order_blocks.mqh>
#include <Custom\ZigZag\flipzone.mqh>
#include <Custom\ZigZag\breaker_blocks.mqh>
#include <Custom\General\teams_alert.mqh>
#include <Custom\General\poc_analyzer.mqh>
#include <Custom\ZigZag\entry_model.mqh>
#include <Custom\General\mq5_dashboard.mqh>

// =============================================================================
// SCANNER CONFIGURATION CLASS
// =============================================================================
class SLiquiditySweptConfig
  {
public:
   int               scanSpeedPerSecond;

   // Trigger Filters
   bool              alertBLCHoCH;        // TF-BL-LB-IND
   bool              alertSSLSwept;       // TF-BL-LB-SSL
   bool              alertBRCHoCH;        // TF-BR-LB-IND
   bool              alertBSLSwept;       // TF-BR-LB-BSL

   // Inducement Engine Settings
   int               minTouches;
   double            proximityPips;
   bool              mergeClustered;
   double            clusterTolerancePips;

   // ZigZag Configurations
   int               fx_maxLookback;
   double            fx_dev_D1;
   int               fx_dep_D1;
   double            fx_dev_H4;
   int               fx_dep_H4;
   double            fx_dev_H1;
   int               fx_dep_H1;
   double            fx_dev_M15;
   int               fx_dep_M15;

   int               met_maxLookback;
   double            met_dev_D1;
   int               met_dep_D1;
   double            met_dev_H4;
   int               met_dep_H4;
   double            met_dev_H1;
   int               met_dep_H1;
   double            met_dev_M15;
   int               met_dep_M15;

   int               cry_maxLookback;
   double            cry_dev_D1;
   int               cry_dep_D1;
   double            cry_dev_H4;
   int               cry_dep_H4;
   double            cry_dev_H1;
   int               cry_dep_H1;
   double            cry_dev_M15;
   int               cry_dep_M15;

                     SLiquiditySweptConfig() {}
  };

// =============================================================================
// INDUCEMENT MITIGATION STATE TRACKER
// =============================================================================
struct SInducementMitigState
  {
   string            inducementId;
   bool              isBullish;           // true = Buyers' Inducement, false = Sellers' Inducement
   double            inducementBoundary;  // zoneLow (Bullish) or zoneHigh (Bearish)
   datetime          mitigationTime;
   bool              chochCaptured;       // 1st CHoCH fulfilled
   bool              sweepCaptured;       // 1st Swept fulfilled
  };

// =============================================================================
// SCANNER INSTANCE (Single Symbol & Timeframe Processor)
// =============================================================================
class CLiquiditySweptInstance
  {
private:
   SLiquiditySweptConfig* m_cfg;

   int               FindBarIndexByTime(datetime targetTime, const datetime &time[], int rates_total)
     {
      int left = 0;
      int right = rates_total - 1;
      while(left <= right)
        {
         int mid = left + (right - left) / 2;
         if(time[mid] == targetTime)
            return mid;
         if(time[mid] < targetTime)
            left = mid + 1;
         else
            right = mid - 1;
        }
      return -1;
     }

public:
   string                 symbol;
   ENUM_TIMEFRAMES        tf;
   int                    prev_calculated;
   bool                   is_first_scan_complete;

   int                    m_maxLookback;
   double                 m_deviation;
   int                    m_depth;

   ZigZag*                zigZag;
   CMarketStructure*      ms;
   CDemandSupplyLogic*    dsLogic;
   CSwingPOILogic*        spLogic;
   COrderBlockLogic*      obLogic;
   CFlipZoneLogic*        fzLogic;
   CBreakerBlockLogic*    bbLogic;
   CInducementLogic*      indLogic;

   CArrayString           alerted_keys;
   datetime               m_last_breakout_evaluated;
   SInducementMitigState  m_tracked_inducements[];

                     CLiquiditySweptInstance(string _symbol, ENUM_TIMEFRAMES _tf, double devInput, int depInput, int maxLB, SLiquiditySweptConfig* config)
     {
      symbol                 = _symbol;
      tf                     = _tf;
      m_maxLookback          = maxLB;
      m_deviation            = devInput;
      m_depth                = depInput;
      m_cfg                  = config;

      prev_calculated        = 0;
      is_first_scan_complete = false;
      m_last_breakout_evaluated = 0;

      Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      zigZag = newInstance(s);

      ms = new CMarketStructure();
      ms.Init(false, false);

      dsLogic  = new CDemandSupplyLogic();
      spLogic  = new CSwingPOILogic();
      obLogic  = new COrderBlockLogic();
      fzLogic  = new CFlipZoneLogic();
      bbLogic  = new CBreakerBlockLogic();

      indLogic = new CInducementLogic();
      indLogic.Init(m_cfg.minTouches, m_cfg.proximityPips,
                    true, true, true, false, false, true,
                    m_cfg.mergeClustered, m_cfg.clusterTolerancePips, false);
     }

                    ~CLiquiditySweptInstance()
     {
      if(CheckPointer(zigZag)   == POINTER_DYNAMIC)
         delete zigZag;
      if(CheckPointer(ms)       == POINTER_DYNAMIC)
         delete ms;
      if(CheckPointer(dsLogic)  == POINTER_DYNAMIC)
         delete dsLogic;
      if(CheckPointer(spLogic)  == POINTER_DYNAMIC)
         delete spLogic;
      if(CheckPointer(obLogic)  == POINTER_DYNAMIC)
         delete obLogic;
      if(CheckPointer(fzLogic)  == POINTER_DYNAMIC)
         delete fzLogic;
      if(CheckPointer(bbLogic)  == POINTER_DYNAMIC)
         delete bbLogic;
      if(CheckPointer(indLogic) == POINTER_DYNAMIC)
         delete indLogic;
     }

   bool              IsAlertedKey(string key)
     {
      for(int i = 0; i < alerted_keys.Total(); i++)
        {
         if(alerted_keys.At(i) == key)
            return true;
        }
      return false;
     }

   void              ProcessData()
     {
      int rates_total = Bars(symbol, tf);
      if(rates_total < m_depth * 2)
         return;

      int start_bar = MathMax(0, rates_total - m_maxLookback);
      int to_copy = rates_total - start_bar;

      double high[], low[], close[], open[];
      datetime time[];
      long vol[];

      if(CopyTime(symbol, tf, 0, to_copy, time) <= 0)
         return;
      if(CopyOpen(symbol, tf, 0, to_copy, open) <= 0)
         return;
      if(CopyHigh(symbol, tf, 0, to_copy, high) <= 0)
         return;
      if(CopyLow(symbol, tf, 0, to_copy, low) <= 0)
         return;
      if(CopyClose(symbol, tf, 0, to_copy, close) <= 0)
         return;
      if(CopyTickVolume(symbol, tf, 0, to_copy, vol) <= 0)
         return;

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

      int start = (prev_calculated == 0) ? 0 : prev_calculated - start_bar - 1;
      if(start < 0)
         start = 0;

      for(int i = start; i < to_copy; i++)
        {
         bool is_last = (i == to_copy - 1);
         int bar_index = start_bar + i;

         zigZag.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
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

         indLogic.Process(i, time, open, high, low, close,
                          zigZag, ms, dsLogic, spLogic, obLogic,
                          fzLogic, bbLogic, pipSize);
        }
      prev_calculated = rates_total;
     }

   // Resolve exact Swing POI bounds at a protected pivot timestamp
   bool              ResolveSwingPOIBounds(datetime protTime, bool isBullish, const datetime &time[],
                                           const double &high[], const double &low[], int rates_total,
                                           double &outHigh, double &outLow)
     {
      outHigh = 0.0;
      outLow  = 0.0;

      if(spLogic != NULL)
        {
         if(isBullish)
           {
            for(int k = 0; k < spLogic.poi_demandTime.Total(); k++)
              {
               if((datetime)spLogic.poi_demandTime.At(k) == protTime)
                 {
                  outHigh = spLogic.poi_demandZoneHigh.At(k);
                  outLow  = spLogic.poi_demandZoneLow.At(k);
                  return true;
                 }
              }
           }
         else
           {
            for(int k = 0; k < spLogic.poi_supplyTime.Total(); k++)
              {
               if((datetime)spLogic.poi_supplyTime.At(k) == protTime)
                 {
                  outHigh = spLogic.poi_supplyZoneHigh.At(k);
                  outLow  = spLogic.poi_supplyZoneLow.At(k);
                  return true;
                 }
              }
           }
        }

      int idx = FindBarIndexByTime(protTime, time, rates_total);
      if(idx >= 0)
        {
         outHigh = high[idx];
         outLow  = low[idx];
         return true;
        }

      return false;
     }

   // Sync newly mitigated inducements into tracking buffer
   void              SyncMitigatedInducements()
     {
      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic.m_zones.At(z);
         if(ind == NULL || !ind.isInducement || !ind.isMitigated || ind.mitigationTime == 0)
            continue;

         bool exists = false;
         for(int t = 0; t < ArraySize(m_tracked_inducements); t++)
           {
            if(m_tracked_inducements[t].inducementId == ind.id)
              {
               exists = true;
               break;
              }
           }

         if(!exists)
           {
            int sz = ArraySize(m_tracked_inducements);
            ArrayResize(m_tracked_inducements, sz + 1);
            m_tracked_inducements[sz].inducementId       = ind.id;
            m_tracked_inducements[sz].isBullish          = ind.isBullish;
            m_tracked_inducements[sz].inducementBoundary = ind.isBullish ? ind.zoneLow : ind.zoneHigh;
            m_tracked_inducements[sz].mitigationTime     = ind.mitigationTime;
            m_tracked_inducements[sz].chochCaptured      = false;
            m_tracked_inducements[sz].sweepCaptured      = false;
           }
        }
     }

   // Master Trigger Evaluation
   void              EvaluateTriggers()
     {
      SyncMitigatedInducements();

      if(ms.last_breakout_time == 0 || ms.last_breakout_time == m_last_breakout_evaluated)
         return;

      datetime boTime = ms.last_breakout_time;

      int to_copy = Bars(symbol, tf);
      if(to_copy > m_maxLookback)
         to_copy = m_maxLookback;

      datetime time[];
      double open[], high[], low[], close[];
      if(CopyTime(symbol, tf, 0, to_copy, time) <= 0 ||
         CopyOpen(symbol, tf, 0, to_copy, open) <= 0 ||
         CopyHigh(symbol, tf, 0, to_copy, high) <= 0 ||
         CopyLow(symbol, tf, 0, to_copy, low) <= 0 ||
         CopyClose(symbol, tf, 0, to_copy, close) <= 0)
         return;

      string tfStr = ms.tf_str();

      for(int t = 0; t < ArraySize(m_tracked_inducements); t++)
        {
         if(boTime < m_tracked_inducements[t].mitigationTime)
            continue;

         // -----------------------------------------------------------------
         // BULLISH REVERSAL TRIGGERS (Post Buyers' Inducement Mitigation)
         // -----------------------------------------------------------------
         if(m_tracked_inducements[t].isBullish)
           {
            // Floor pivot must have swept below the bullish inducement zone low
            bool sweptBelow = (ms.protected_level_price <= m_tracked_inducements[t].inducementBoundary ||
                               ms.protected_level_time >= m_tracked_inducements[t].mitigationTime);

            if(!sweptBelow)
               continue;

            // Trigger A: 1st BL-CHoCH -> TF-BL-LB-IND
            if(m_cfg.alertBLCHoCH && !m_tracked_inducements[t].chochCaptured)
              {
               if(ms.trend == 1 && (ms.ev1_name == "BL-CHoCH" || ms.ev2_name == "BL-CHoCH"))
                 {
                  SendLiquiditySweptAlert(tfStr + "-BL-LB-IND", "BULLISH", ms.protected_level_time,
                                          m_tracked_inducements[t], time, open, high, low, close, to_copy);
                  m_tracked_inducements[t].chochCaptured = true;
                 }
              }

            // Trigger B: 1st SSL-Swept -> TF-BL-LB-SSL
            if(m_cfg.alertSSLSwept && !m_tracked_inducements[t].sweepCaptured)
              {
               if(ms.ev1_name == "SSL-Swept" || ms.ev2_name == "SSL-Swept")
                 {
                  SendLiquiditySweptAlert(tfStr + "-BL-LB-SSL", "BULLISH", ms.protected_level_time,
                                          m_tracked_inducements[t], time, open, high, low, close, to_copy);
                  m_tracked_inducements[t].sweepCaptured = true;
                 }
              }
           }
         // -----------------------------------------------------------------
         // BEARISH REVERSAL TRIGGERS (Post Sellers' Inducement Mitigation)
         // -----------------------------------------------------------------
         else
           {
            // Ceiling pivot must have swept above the bearish inducement zone high
            bool sweptAbove = (ms.protected_level_price >= m_tracked_inducements[t].inducementBoundary ||
                               ms.protected_level_time >= m_tracked_inducements[t].mitigationTime);

            if(!sweptAbove)
               continue;

            // Trigger A: 1st BR-CHoCH -> TF-BR-LB-IND
            if(m_cfg.alertBRCHoCH && !m_tracked_inducements[t].chochCaptured)
              {
               if(ms.trend == -1 && (ms.ev1_name == "BR-CHoCH" || ms.ev2_name == "BR-CHoCH"))
                 {
                  SendLiquiditySweptAlert(tfStr + "-BR-LB-IND", "BEARISH", ms.protected_level_time,
                                          m_tracked_inducements[t], time, open, high, low, close, to_copy);
                  m_tracked_inducements[t].chochCaptured = true;
                 }
              }

            // Trigger B: 1st BSL-Swept -> TF-BR-LB-BSL
            if(m_cfg.alertBSLSwept && !m_tracked_inducements[t].sweepCaptured)
              {
               if(ms.ev1_name == "BSL-Swept" || ms.ev2_name == "BSL-Swept")
                 {
                  SendLiquiditySweptAlert(tfStr + "-BR-LB-BSL", "BEARISH", ms.protected_level_time,
                                          m_tracked_inducements[t], time, open, high, low, close, to_copy);
                  m_tracked_inducements[t].sweepCaptured = true;
                 }
              }
           }
        }

      m_last_breakout_evaluated = ms.last_breakout_time;
      is_first_scan_complete    = true;
     }

   // Format & Dispatch Alert
   void              SendLiquiditySweptAlert(string nomenclature, string obType, datetime protTime,
         SInducementMitigState &ind, const datetime &time[],
         const double &open[], const double &high[],
         const double &low[], const double &close[], int rates_total)
     {
      double zHigh = 0.0, zLow = 0.0;
      bool isBull = (obType == "BULLISH");

      if(!ResolveSwingPOIBounds(protTime, isBull, time, high, low, rates_total, zHigh, zLow))
         return;

      string alertKey = StringFormat("%s_%s_%s_%s_%.5f_%.5f", symbol, EnumToString(tf), nomenclature, obType, zHigh, zLow);
      if(IsAlertedKey(alertKey))
         return;

      if(alerted_keys.Total() > 500)
         alerted_keys.Delete(0);
      alerted_keys.Add(alertKey);

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

      double liveBid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double liveAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double livePrice = isBull ? liveAsk : liveBid;

      OBAnalysis oa;
      oa.zoneLabel       = nomenclature;
      oa.zoneHigh        = zHigh;
      oa.zoneLow         = zLow;
      oa.zoneCreatedTime = protTime;
      oa.isFresh         = true;
      oa.isPreviouslyMitigated = false;
      oa.touchCount      = 0;

      oa.maxLookbackBars = m_maxLookback;
      oa.deviationInput  = m_deviation;
      oa.depthInput      = m_depth;

      oa.trendBias = isBull ? "BULLISH" : "BEARISH";
      oa.marketStructureType = isBull ? "HH & HL (Reversal CHoCH)" : "LH & LL (Reversal CHoCH)";
      oa.bosDetected   = false;
      oa.chochDetected = true;
      oa.lastBosTime   = ms.last_breakout_time;
      oa.lastBosType   = nomenclature;

      long vol[];
      CopyTickVolume(symbol, tf, 0, 1, vol);
      oa.tickVolume = (ArraySize(vol) > 0) ? vol[0] : 0;
      oa.realVolume = 0;
      oa.cumulativeVolume = (long)zigZag.cVols.get(0);

      Pivot* lastP = zigZag.lastPivot();
      if(lastP != NULL && lastP.start != NULL && lastP.end != NULL)
        {
         oa.zzReversalPrice      = lastP.end.price;
         oa.zzPriorReversalPrice = lastP.start.price;
         oa.zzPriceChange        = lastP.end.price - lastP.start.price;
         oa.zzDirection          = (oa.zzPriceChange > 0) ? "UP" : "DOWN";
        }
      else
        {
         oa.zzReversalPrice = 0;
         oa.zzPriorReversalPrice = 0;
         oa.zzPriceChange = 0;
         oa.zzDirection = "UNKNOWN";
        }

      // 1:2 R:R Parameters
      double slBuffer = 3.0 * pipSize;
      if(isBull)
        {
         oa.slPrice = zLow - slBuffer;
         double riskPrice = MathAbs(livePrice - oa.slPrice);
         oa.tpPrice = livePrice + 2.0 * riskPrice;
        }
      else
        {
         oa.slPrice = zHigh + slBuffer;
         double riskPrice = MathAbs(oa.slPrice - livePrice);
         oa.tpPrice = livePrice - 2.0 * riskPrice;
        }

      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0)
         tickSize = point;

      oa.estLoss   = (MathAbs(livePrice - oa.slPrice) / tickSize) * tickValue;
      oa.estProfit = (MathAbs(oa.tpPrice - livePrice) / tickSize) * tickValue;

      // 9-Point Confluence Scoring (PoC)
      CPoCAnalyzer pocEngine;
      PoCResult pocRes = pocEngine.EvaluateZone(
                            isBull, protTime, zHigh, zLow, rates_total - 1,
                            time, open, high, low, close,
                            zigZag, ms, dsLogic, spLogic, obLogic,
                            livePrice, pipSize, tf
                         );

      oa.setupQuality   = pocRes.finalScore;
      oa.recommendation = (pocRes.finalScore >= 80) ? "HIGH PROBABILITY LIQUIDITY BLOCK" : "CONFIRMED INDUCEMENT REVERSAL";

      string detailHeader = StringFormat(
                               "- ⚡ **Structure Tag:** %s\\n\\n"
                               "- 🎯 **Mitigated Inducement:** %s (%s) Level: %.5f\\n\\n"
                               "- 🕒 **Inducement Mitigation Time:** %s\\n\\n"
                               "- 🌊 **Liquidity Block Swing POI:** High: %.5f | Low: %.5f\\n\\n",
                               nomenclature,
                               ind.inducementId,
                               ind.isBullish ? "Buyers' Inducement" : "Sellers' Inducement",
                               ind.inducementBoundary,
                               TimeToString(ind.mitigationTime, TIME_MINUTES),
                               zHigh, zLow
                            );

      oa.reasoning = detailHeader + pocRes.reasoning;

      // Dispatch Webhook to Microsoft Teams
      SendOBAlert(symbol, tf, obType, oa, ALERTS_TEAMS_URL);

      // Register into Daily CSV Logs
      CheckAndRegisterDailyAlert("liquidity_swept", alertKey, symbol, StringSubstr(EnumToString(tf), 7), nomenclature, obType, livePrice, oa.slPrice, oa.tpPrice);

      PrintFormat("+++ 🚀 LIQUIDITY SWEPT ALERT SENT: %s %s [%s] @ %.5f", symbol, StringSubstr(EnumToString(tf), 7), nomenclature, livePrice);
     }
  };

// =============================================================================
// COORDINATED SCANNER ENGINE (32-Symbol Controller)
// =============================================================================
class CLiquiditySweptAlertEngine
  {
private:
   CLiquiditySweptInstance* instances[];
   int                      total_instances;
   int                      current_scan_idx;
   SLiquiditySweptConfig*   m_cfg;
   bool                     all_synced;

   bool              IsCrypto(string sym) { return (StringFind(sym, "BTC") >= 0); }
   bool              IsMetal(string sym)  { return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0); }

public:
                     CLiquiditySweptAlertEngine()
     {
      total_instances  = 0;
      current_scan_idx = 0;
      all_synced       = false;
     }

                    ~CLiquiditySweptAlertEngine()
     {
      for(int i = 0; i < total_instances; i++)
        {
         if(CheckPointer(instances[i]) == POINTER_DYNAMIC)
            delete instances[i];
        }
     }

   void              Initialize(SLiquiditySweptConfig* config)
     {
      CDailyReporter::ProcessPendingReports();
      LoadDailyAlerts("liquidity_swept");

      m_cfg = config;

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

      ENUM_TIMEFRAMES TargetTFs[] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };

      int symCount    = ArraySize(TargetSymbols);
      int tfCount     = ArraySize(TargetTFs);
      total_instances = symCount * tfCount;
      ArrayResize(instances, total_instances);

      int idx = 0;
      for(int s = 0; s < symCount; s++)
        {
         SymbolSelect(TargetSymbols[s], true);
         bool isMet = IsMetal(TargetSymbols[s]);
         bool isCry = IsCrypto(TargetSymbols[s]);

         for(int t = 0; t < tfCount; t++)
           {
            ENUM_TIMEFRAMES tf = TargetTFs[t];
            double dev = 1.0;
            int dep = 15;
            int maxLB = isMet ? m_cfg.met_maxLookback : (isCry ? m_cfg.cry_maxLookback : m_cfg.fx_maxLookback);

            if(isMet)
              {
               if(tf == PERIOD_D1)
                 {
                  dev = m_cfg.met_dev_D1;
                  dep = m_cfg.met_dep_D1;
                 }
               else
                  if(tf == PERIOD_H4)
                    {
                     dev = m_cfg.met_dev_H4;
                     dep = m_cfg.met_dep_H4;
                    }
                  else
                     if(tf == PERIOD_H1)
                       {
                        dev = m_cfg.met_dev_H1;
                        dep = m_cfg.met_dep_H1;
                       }
                     else
                        if(tf == PERIOD_M15)
                          {
                           dev = m_cfg.met_dev_M15;
                           dep = m_cfg.met_dep_M15;
                          }
              }
            else
               if(isCry)
                 {
                  if(tf == PERIOD_D1)
                    {
                     dev = m_cfg.cry_dev_D1;
                     dep = m_cfg.cry_dep_D1;
                    }
                  else
                     if(tf == PERIOD_H4)
                       {
                        dev = m_cfg.cry_dev_H4;
                        dep = m_cfg.cry_dep_H4;
                       }
                     else
                        if(tf == PERIOD_H1)
                          {
                           dev = m_cfg.cry_dev_H1;
                           dep = m_cfg.cry_dep_H1;
                          }
                        else
                           if(tf == PERIOD_M15)
                             {
                              dev = m_cfg.cry_dev_M15;
                              dep = m_cfg.cry_dep_M15;
                             }
                 }
               else
                 {
                  if(tf == PERIOD_D1)
                    {
                     dev = m_cfg.fx_dev_D1;
                     dep = m_cfg.fx_dep_D1;
                    }
                  else
                     if(tf == PERIOD_H4)
                       {
                        dev = m_cfg.fx_dev_H4;
                        dep = m_cfg.fx_dep_H4;
                       }
                     else
                        if(tf == PERIOD_H1)
                          {
                           dev = m_cfg.fx_dev_H1;
                           dep = m_cfg.fx_dep_H1;
                          }
                        else
                           if(tf == PERIOD_M15)
                             {
                              dev = m_cfg.fx_dev_M15;
                              dep = m_cfg.fx_dep_M15;
                             }
                 }

            instances[idx] = new CLiquiditySweptInstance(TargetSymbols[s], tf, dev, dep, maxLB, m_cfg);
            idx++;
           }
        }
      PrintFormat("⚙️ Liquidity Swept Alert Engine initialized with %d instances.", total_instances);
     }

   void              ProcessBatch()
     {
      int processed = 0;
      while(processed < m_cfg.scanSpeedPerSecond && total_instances > 0)
        {
         bool wasSynced = instances[current_scan_idx].is_first_scan_complete;

         instances[current_scan_idx].ProcessData();
         instances[current_scan_idx].EvaluateTriggers();

         if(!wasSynced && instances[current_scan_idx].is_first_scan_complete)
           {
            string tfStr = StringSubstr(EnumToString(instances[current_scan_idx].tf), 7);
            PrintFormat("[%d/%d] 🔄 Synced: %s, %s", current_scan_idx + 1, total_instances, instances[current_scan_idx].symbol, tfStr);
           }

         current_scan_idx++;

         if(current_scan_idx >= total_instances)
           {
            current_scan_idx = 0;
            if(!all_synced)
              {
               all_synced = true;
               Print("✅ ALL LIQUIDITY SWEPT CHARTS SYNCED. Actively monitoring triggers.");
              }
           }
         processed++;
        }
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_swept_alerting.mqh
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_swept_alerting.mqh

// END FILE: Include\Custom\Marcotrades\liquidity_swept_alerting.mqh
