//+------------------------------------------------------------------+
//|                                     Include\Custom\ZigZag\zone_touch.mqh|
//|        SMC Multi-Symbol Wick Touch Alert Engine based on Bid/Ask |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.21"

// =========================================================================
// SAFE STANDALONE CLEAN SYMBOL PREPROCESSOR GUARD
// =========================================================================
#ifndef CLEAN_SYMBOL_FN
#define CLEAN_SYMBOL_FN
string CleanSymbol(string sym)
  {
   int len = StringLen(sym);
   if(len > 1 && StringSubstr(sym, len - 1, 1) == "m")
     {
      return StringSubstr(sym, 0, len - 1);
     }
   return sym;
  }
#endif

#include <Arrays\ArrayString.mqh>
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

string zt_WebhookURL = ALERTS_TEAMS_URL;

// =============================================================================
// SCANNER CONFIGURATION
// =============================================================================
class SMCScannerConfig
  {
public:
   int               scanSpeedPerSecond;

   bool              alertDemandZones;
   bool              alertSupplyZones;
   bool              alertMitigDemandZones;
   bool              alertMitigSupplyZones;

   bool              alertBullishOB;
   bool              alertBearishOB;
   bool              alertMitigBullishOB;
   bool              alertMitigBearishOB;

   bool              alertBullishPOI;
   bool              alertBearishPOI;
   bool              alertMitigBullishPOI;
   bool              alertMitigBearishPOI;

   bool              alertDemandFlipZones;
   bool              alertSupplyFlipZones;
   bool              alertMitigDemandFlipZones;
   bool              alertMitigSupplyFlipZones;

   bool              alertBullishBreaker;
   bool              alertBearishBreaker;
   bool              alertMitigBullishBreaker;
   bool              alertMitigBearishBreaker;

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

                     SMCScannerConfig() {}
  };

// =============================================================================
// SCANNER INSTANCE ENGINE
// =============================================================================
class CScannerInstance
  {
private:
   SMCScannerConfig*  m_cfg;

public:
   string             symbol;
   ENUM_TIMEFRAMES    tf;
   int                prev_calculated;
   bool               is_first_scan_complete;

   int                m_maxLookback;
   double             m_deviation;
   int                m_depth;

   ZigZag*            zigZag;
   CMarketStructure*  ms;
   CDemandSupplyLogic* dsLogic;
   CSwingPOILogic*    spLogic;
   COrderBlockLogic*  obLogic;
   CFlipZoneLogic*    fzLogic;
   CBreakerBlockLogic* bbLogic;

   CArrayString       alerted_keys;

                     CScannerInstance(string _symbol, ENUM_TIMEFRAMES _tf, double devInput, int depInput, int maxLB, SMCScannerConfig* config)
     {
      symbol = _symbol;
      tf = _tf;
      m_maxLookback = maxLB;
      m_deviation = devInput;
      m_depth = depInput;
      m_cfg = config;

      prev_calculated = 0;
      is_first_scan_complete = false;

      Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      zigZag = newInstance(s);

      ms = new CMarketStructure();
      ms.Init(false, false);

      dsLogic = new CDemandSupplyLogic();
      spLogic = new CSwingPOILogic();
      obLogic = new COrderBlockLogic();
      fzLogic = new CFlipZoneLogic();
      bbLogic = new CBreakerBlockLogic();
     }

                    ~CScannerInstance()
     {
      if(CheckPointer(zigZag) == POINTER_DYNAMIC)
         delete zigZag;
      if(CheckPointer(ms) == POINTER_DYNAMIC)
         delete ms;
      if(CheckPointer(dsLogic) == POINTER_DYNAMIC)
         delete dsLogic;
      if(CheckPointer(spLogic) == POINTER_DYNAMIC)
         delete spLogic;
      if(CheckPointer(obLogic) == POINTER_DYNAMIC)
         delete obLogic;
      if(CheckPointer(fzLogic) == POINTER_DYNAMIC)
         delete fzLogic;
      if(CheckPointer(bbLogic) == POINTER_DYNAMIC)
         delete bbLogic;
     }

   string            GetZoneKey(bool isDemand, bool isMitigated, double zHigh, double zLow)
     {
      return StringFormat("%s_%s_%.5f_%.5f", isDemand ? "D" : "S", isMitigated ? "M" : "F", zHigh, zLow);
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

      double high[], low[], close[];
      datetime time[];
      long vol[];

      if(CopyTime(symbol, tf, 0, to_copy, time) <= 0)
         return;
      if(CopyHigh(symbol, tf, 0, to_copy, high) <= 0)
         return;
      if(CopyLow(symbol, tf, 0, to_copy, low) <= 0)
         return;
      if(CopyClose(symbol, tf, 0, to_copy, close) <= 0)
         return;
      if(CopyTickVolume(symbol, tf, 0, to_copy, vol) <= 0)
         return;

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
        }
      prev_calculated = rates_total;
     }

   void              EvaluateWickTouches()
     {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      if(bid == 0.0 || ask == 0.0)
         return;

      double h = ask;
      double l = bid;

      bool alertedBullishThisScan = false;
      bool alertedBearishThisScan = false;

      bbLogic.UpdateMitigation(ask, bid, TimeCurrent());

      // 1. ORDER BLOCKS
      for(int i = 0; i < obLogic.poi_demandTime.Total(); i++)
        {
         bool isMitigated = (obLogic.poi_demandMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigBullishOB)
            continue;
         if(!isMitigated && !m_cfg.alertBullishOB)
            continue;

         long zTime = obLogic.poi_demandTime.At(i);
         if(obLogic.ob_time_found(&ms.ob_bull_struct_times, (datetime)zTime) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, (datetime)zTime))
           {
            double zHigh = obLogic.poi_demandZoneHigh.At(i);
            double zLow = obLogic.poi_demandZoneLow.At(i);
            string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);

            if(IsAlertedKey(localKey))
               continue;

            if(l <= zHigh && h >= zLow)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBullishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "ORDER-BLOCK", true, zHigh, zLow, zTime, 3, i);
                  alertedBullishThisScan = true;
                 }
              }
           }
        }
      for(int i = 0; i < obLogic.poi_supplyTime.Total(); i++)
        {
         bool isMitigated = (obLogic.poi_supplyMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigBearishOB)
            continue;
         if(!isMitigated && !m_cfg.alertBearishOB)
            continue;

         long zTime = obLogic.poi_supplyTime.At(i);
         if(obLogic.ob_time_found(&ms.ob_bear_struct_times, (datetime)zTime) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, (datetime)zTime))
           {
            double zHigh = obLogic.poi_supplyZoneHigh.At(i);
            double zLow = obLogic.poi_supplyZoneLow.At(i);
            string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);

            if(IsAlertedKey(localKey))
               continue;

            if(h >= zLow && l <= zHigh)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBearishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "ORDER-BLOCK", false, zHigh, zLow, zTime, 3, i);
                  alertedBearishThisScan = true;
                 }
              }
           }
        }

      // 2. SWING POIs
      for(int i = 0; i < spLogic.poi_demandTime.Total(); i++)
        {
         bool isMitigated = (spLogic.poi_demandMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigBullishPOI)
            continue;
         if(!isMitigated && !m_cfg.alertBullishPOI)
            continue;

         long zTime = spLogic.poi_demandTime.At(i);
         if(spLogic.ob_time_found(&ms.ob_bull_struct_times, (datetime)zTime))
           {
            double zHigh = spLogic.poi_demandZoneHigh.At(i);
            double zLow = spLogic.poi_demandZoneLow.At(i);
            string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);

            if(IsAlertedKey(localKey))
               continue;

            if(l <= zHigh && h >= zLow)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBullishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "SWING POI", true, zHigh, zLow, zTime, 2, i);
                  alertedBullishThisScan = true;
                 }
              }
           }
        }
      for(int i = 0; i < spLogic.poi_supplyTime.Total(); i++)
        {
         bool isMitigated = (spLogic.poi_supplyMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigBearishPOI)
            continue;
         if(!isMitigated && !m_cfg.alertBearishPOI)
            continue;

         long zTime = spLogic.poi_supplyTime.At(i);
         if(spLogic.ob_time_found(&ms.ob_bear_struct_times, (datetime)zTime))
           {
            double zHigh = spLogic.poi_supplyZoneHigh.At(i);
            double zLow = spLogic.poi_supplyZoneLow.At(i);
            string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);

            if(IsAlertedKey(localKey))
               continue;

            if(h >= zLow && l <= zHigh)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBearishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "SWING POI", false, zHigh, zLow, zTime, 2, i);
                  alertedBearishThisScan = true;
                 }
              }
           }
        }

      // 3. DEMAND / SUPPLY ZONES
      for(int i = 0; i < dsLogic.poi_demandTime.Total(); i++)
        {
         bool isMitigated = (dsLogic.poi_demandMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigDemandZones)
            continue;
         if(!isMitigated && !m_cfg.alertDemandZones)
            continue;

         double zHigh = dsLogic.poi_demandZoneHigh.At(i);
         double zLow = dsLogic.poi_demandZoneLow.At(i);
         string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);

         if(IsAlertedKey(localKey))
            continue;

         if(l <= zHigh && h >= zLow)
           {
            if(alerted_keys.Total() > 500)
               alerted_keys.Delete(0);
            alerted_keys.Add(localKey);

            if(is_first_scan_complete && !alertedBullishThisScan)
              {
               CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "DEMAND ZONE", true, zHigh, zLow, dsLogic.poi_demandTime.At(i), 1, i);
               alertedBullishThisScan = true;
              }
           }
        }
      for(int i = 0; i < dsLogic.poi_supplyTime.Total(); i++)
        {
         bool isMitigated = (dsLogic.poi_supplyMitigated.At(i) == 1);
         if(isMitigated && !m_cfg.alertMitigSupplyZones)
            continue;
         if(!isMitigated && !m_cfg.alertSupplyZones)
            continue;

         double zHigh = dsLogic.poi_supplyZoneHigh.At(i);
         double zLow = dsLogic.poi_supplyZoneLow.At(i);
         string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);

         if(IsAlertedKey(localKey))
            continue;

         if(h >= zLow && l <= zHigh)
           {
            if(alerted_keys.Total() > 500)
               alerted_keys.Delete(0);
            alerted_keys.Add(localKey);

            if(is_first_scan_complete && !alertedBearishThisScan)
              {
               CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "SUPPLY ZONE", false, zHigh, zLow, dsLogic.poi_supplyTime.At(i), 1, i);
               alertedBearishThisScan = true;
              }
           }
        }

      // 4. FLIP ZONES
      for(int i = 0; i < fzLogic.fz_time.Total(); i++)
        {
         bool isMitigated = (fzLogic.fz_mitigated.At(i) == 1);
         int zType = fzLogic.fz_type.At(i);

         if(zType == 1) // Demand Flip
           {
            if(isMitigated && !m_cfg.alertMitigDemandFlipZones)
               continue;
            if(!isMitigated && !m_cfg.alertDemandFlipZones)
               continue;

            double zHigh = fzLogic.fz_zoneHigh.At(i);
            double zLow = fzLogic.fz_zoneLow.At(i);
            string localKey = GetZoneKey(true, isMitigated, zHigh, zLow) + "_FLIP";

            if(IsAlertedKey(localKey))
               continue;

            if(l <= zHigh && h >= zLow)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBullishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "DEMAND FLIP", true, zHigh, zLow, fzLogic.fz_time.At(i), 4, i);
                  alertedBullishThisScan = true;
                 }
              }
           }
         else
            if(zType == -1) // Supply Flip
              {
               if(isMitigated && !m_cfg.alertMitigSupplyFlipZones)
                  continue;
               if(!isMitigated && !m_cfg.alertSupplyFlipZones)
                  continue;

               double zHigh = fzLogic.fz_zoneHigh.At(i);
               double zLow = fzLogic.fz_zoneLow.At(i);
               string localKey = GetZoneKey(false, isMitigated, zHigh, zLow) + "_FLIP";

               if(IsAlertedKey(localKey))
                  continue;

               if(h >= zLow && l <= zHigh)
                 {
                  if(alerted_keys.Total() > 500)
                     alerted_keys.Delete(0);
                  alerted_keys.Add(localKey);

                  if(is_first_scan_complete && !alertedBearishThisScan)
                    {
                     CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "SUPPLY FLIP", false, zHigh, zLow, fzLogic.fz_time.At(i), 4, i);
                     alertedBearishThisScan = true;
                    }
                 }
              }
        }

      // 5. BREAKER BLOCKS
      for(int i = 0; i < bbLogic.bb_time.Total(); i++)
        {
         bool isMitigated = (bbLogic.bb_mitigated.At(i) == 1);
         int zType = bbLogic.bb_type.At(i);

         if(zType == 1) // Bullish Breaker
           {
            if(isMitigated && !m_cfg.alertMitigBullishBreaker)
               continue;
            if(!isMitigated && !m_cfg.alertBullishBreaker)
               continue;

            double zHigh = bbLogic.bb_zoneHigh.At(i);
            double zLow  = bbLogic.bb_zoneLow.At(i);
            string localKey = GetZoneKey(true, isMitigated, zHigh, zLow) + "_BREAKER";

            if(IsAlertedKey(localKey))
               continue;

            if(l <= zHigh && h >= zLow)
              {
               if(alerted_keys.Total() > 500)
                  alerted_keys.Delete(0);
               alerted_keys.Add(localKey);

               if(is_first_scan_complete && !alertedBullishThisScan)
                 {
                  CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "BULL BREAKER", true, zHigh, zLow, bbLogic.bb_time.At(i), 5, i);
                  alertedBullishThisScan = true;
                 }
              }
           }
         else
            if(zType == -1) // Bearish Breaker
              {
               if(isMitigated && !m_cfg.alertMitigBearishBreaker)
                  continue;
               if(!isMitigated && !m_cfg.alertBearishBreaker)
                  continue;

               double zHigh = bbLogic.bb_zoneHigh.At(i);
               double zLow  = bbLogic.bb_zoneLow.At(i);
               string localKey = GetZoneKey(false, isMitigated, zHigh, zLow) + "_BREAKER";

               if(IsAlertedKey(localKey))
                  continue;

               if(h >= zLow && l <= zHigh)
                 {
                  if(alerted_keys.Total() > 500)
                     alerted_keys.Delete(0);
                  alerted_keys.Add(localKey);

                  if(is_first_scan_complete && !alertedBearishThisScan)
                    {
                     CLTFConfirmationEngine::AddHTFTouch("touch", symbol, tf, "BEAR BREAKER", false, zHigh, zLow, bbLogic.bb_time.At(i), 5, i);
                     alertedBearishThisScan = true;
                    }
                 }
              }
        }

      is_first_scan_complete = true;
     }
  };

// =============================================================================
// COORDINATED SCANNER MULTI-SYMBOL CONTROLLER
// =============================================================================
class CZoneMitigationEngine
  {
private:
   CScannerInstance* instances[];
   int               total_instances;
   int               current_scan_idx;
   SMCScannerConfig* m_cfg;
   bool              all_synced;

   bool              IsCrypto(string sym)
     {
      return (StringFind(sym, "BTC") >= 0);
     }

   bool              IsMetal(string sym)
     {
      return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0);
     }

public:
                     CZoneMitigationEngine()
     {
      total_instances = 0;
      current_scan_idx = 0;
      all_synced = false;
     }

                    ~CZoneMitigationEngine()
     {
      for(int i = 0; i < total_instances; i++)
        {
         if(CheckPointer(instances[i]) == POINTER_DYNAMIC)
            delete instances[i];
        }
     }

   void              Initialize(SMCScannerConfig* config)
     {
      CDailyReporter::ProcessPendingReports();
      LoadDailyAlerts("touch");

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

      int symCount = ArraySize(TargetSymbols);
      int tfCount  = ArraySize(TargetTFs);
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
                              dep = m_cfg.fx_dev_M15;
                             }
                 }
            instances[idx] = new CScannerInstance(TargetSymbols[s], tf, dev, dep, maxLB, m_cfg);
            idx++;
           }
        }
      Print("⚙️ Touch alert engine initialized with ", total_instances, " instances. History sync started...");
     }

   void              ProcessBatch()
     {
      int processed = 0;
      while(processed < m_cfg.scanSpeedPerSecond && total_instances > 0)
        {
         bool wasSynced = instances[current_scan_idx].is_first_scan_complete;

         instances[current_scan_idx].ProcessData();
         instances[current_scan_idx].EvaluateWickTouches();

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
               Print("✅ ALL TOUCH CHARTS SYNCED. Monitoring real-time touches.");
              }
           }
         processed++;
        }

      CLTFConfirmationEngine::ProcessLTFConfirmations();
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\zone_touch.mqh

// END FILE: Include\Custom\ZigZag\zone_touch.mqh
