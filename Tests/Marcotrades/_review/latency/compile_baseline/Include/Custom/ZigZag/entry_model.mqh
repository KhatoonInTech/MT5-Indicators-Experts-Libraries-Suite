//+------------------------------------------------------------------+
//|                                   Include/ZigZag/entry_model.mqh |
//|                       Centralized 2R Setup & Evaluation Model    |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.36"

#ifndef ENTRY_MODEL_MQH
#define ENTRY_MODEL_MQH

#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayString.mqh>

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\teams_alert.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"

// =========================================================================
// STANDARD TRADE SETUP MODELS
// =========================================================================
struct TradeSetup2R
  {
   double            entryPrice;
   double            slPrice;
   double            tpPrice;
   double            riskPrice;
   double            rewardPrice;
   double            estLoss;
   double            estProfit;
  };

struct HTFSwingCache
  {
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   datetime          lastHTFBarTime;
   double            swingHigh;
   double            swingLow;
  };

class CLTFConfirmationEngine;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CEntryModel
  {
private:
   static HTFSwingCache m_swing_caches[];

public:
   // --- Programmatic HTF Swing Tracker ---
   static bool       CalculateHTFSwingLevels(string symbol, ENUM_TIMEFRAMES tf, double &swingHigh, double &swingLow)
     {
      swingHigh = EMPTY_VALUE;
      swingLow  = EMPTY_VALUE;

      bool isMC = (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0);
      double dev = isMC ? 0.50 : 0.10;
      int dep    = 10;

      Settings* s = new Settings(dev, dep, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      ZigZag* zz = newInstance(s);
      CMarketStructure* msLocal = new CMarketStructure();
      msLocal.Init(false, false);

      int rates_total = Bars(symbol, tf);
      if(rates_total < dep * 2)
        {
         delete zz;
         delete msLocal;
         return false;
        }

      int maxLB = 3000;
      int start_bar = MathMax(0, rates_total - maxLB);
      int to_copy = rates_total - start_bar;

      double high[], low[], close[];
      datetime time[];
      long vol[];

      if(CopyTime(symbol, tf, 0, to_copy, time) <= 0 ||
         CopyHigh(symbol, tf, 0, to_copy, high) <= 0 ||
         CopyLow(symbol, tf, 0, to_copy, low) <= 0 ||
         CopyClose(symbol, tf, 0, to_copy, close) <= 0 ||
         CopyTickVolume(symbol, tf, 0, to_copy, vol) <= 0)
        {
         delete zz;
         delete msLocal;
         return false;
        }

      for(int i = 0; i < to_copy; i++)
        {
         bool is_last = (i == to_copy - 1);
         int bar_index = start_bar + i;
         zz.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
         msLocal.Update(i, time, high, low, close, zz);
        }

      double active_high = (msLocal.trend == -1) ? msLocal.protected_level_price : msLocal.target_level_price;
      double active_low  = (msLocal.trend == 1)  ? msLocal.protected_level_price : msLocal.target_level_price;

      delete zz;
      delete msLocal;

      if(active_high != EMPTY_VALUE && active_low != EMPTY_VALUE && active_high > active_low)
        {
         swingHigh = active_high;
         swingLow  = active_low;
         return true;
        }
      return false;
     }

   // --- Performance Optimized Lookup Caching ---
   static bool       GetHTFSwingLevelsCached(string symbol, ENUM_TIMEFRAMES tf, double &swingHigh, double &swingLow)
     {
      datetime currentHTFBarTime = iTime(symbol, tf, 0);
      if(currentHTFBarTime == 0)
         currentHTFBarTime = TimeCurrent() - (TimeCurrent() % PeriodSeconds(tf));

      int size = ArraySize(m_swing_caches);
      for(int i = 0; i < size; i++)
        {
         if(m_swing_caches[i].symbol == symbol && m_swing_caches[i].tf == tf)
           {
            if(m_swing_caches[i].lastHTFBarTime == currentHTFBarTime)
              {
               swingHigh = m_swing_caches[i].swingHigh;
               swingLow  = m_swing_caches[i].swingLow;
               return (swingHigh != EMPTY_VALUE && swingLow != EMPTY_VALUE);
              }

            double sh = 0.0, sl = 0.0;
            if(CalculateHTFSwingLevels(symbol, tf, sh, sl))
              {
               m_swing_caches[i].lastHTFBarTime = currentHTFBarTime;
               m_swing_caches[i].swingHigh = sh;
               m_swing_caches[i].swingLow  = sl;
               swingHigh = sh;
               swingLow  = sl;
               return true;
              }
            return false;
           }
        }

      double sh = 0.0, sl = 0.0;
      if(CalculateHTFSwingLevels(symbol, tf, sh, sl))
        {
         ArrayResize(m_swing_caches, size + 1);
         m_swing_caches[size].symbol = symbol;
         m_swing_caches[size].tf = tf;
         m_swing_caches[size].lastHTFBarTime = currentHTFBarTime;
         m_swing_caches[size].swingHigh = sh;
         m_swing_caches[size].swingLow  = sl;
         swingHigh = sh;
         swingLow  = sl;
         return true;
        }
      return false;
     }

   // --- Premium and Discount Validator ---
   static bool       IsZoneInAllowedDiscountPremium(string symbol, ENUM_TIMEFRAMES htf_tf, bool isBullish, double zHigh, double zLow)
     {
      double swingHigh = 0.0;
      double swingLow  = 0.0;
      if(!GetHTFSwingLevelsCached(symbol, htf_tf, swingHigh, swingLow))
         return true; // Fallback to avoid trade blocking on initialization delays

      double L = swingHigh - swingLow;
      if(L <= 0)
         return true;

      if(isBullish)
        {
         // Discount Zone: Swing Low to (Swing Low + L/3)
         double discountThreshold = swingLow + (L / 3.0);
         return (zHigh <= discountThreshold);
        }
      else
        {
         // Premium Zone: (Swing Low + 2L/3) to Swing High
         double premiumThreshold = swingLow + (2.0 * L / 3.0);
         return (zLow >= premiumThreshold);
        }
     }

   static void       CalculateLiveSetup(string symbol, bool isDemand, double zoneHigh, double zoneLow, double livePrice, double pipSize, double bufferPips, TradeSetup2R &setup)
     {
      setup.entryPrice = livePrice;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(isDemand)
        {
         setup.slPrice = zoneLow - (bufferPips * pipSize);
         setup.riskPrice = MathAbs(setup.entryPrice - setup.slPrice);
         setup.rewardPrice = setup.riskPrice * 2.0;
         setup.tpPrice = setup.entryPrice + setup.rewardPrice;
        }
      else
        {
         setup.slPrice = zoneHigh + (bufferPips * pipSize);
         setup.riskPrice = MathAbs(setup.slPrice - setup.entryPrice);
         setup.rewardPrice = setup.riskPrice * 2.0;
         setup.tpPrice = setup.entryPrice - setup.rewardPrice;
        }

      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0)
         tickSize = point;

      setup.estLoss   = (setup.riskPrice / tickSize) * tickValue;
      setup.estProfit = (setup.rewardPrice / tickSize) * tickValue;
     }

   static void       CalculateBacktestSetup(bool isBullish, double zoneHigh, double zoneLow, double pipSize, double bufferPips, double &sl, double &tp)
     {
      double zWidth = zoneHigh - zoneLow;
      if(isBullish)
        {
         sl = zoneLow - (bufferPips * pipSize);
         tp = zoneHigh + 2.0 * (zWidth + bufferPips * pipSize);
        }
      else
        {
         sl = zoneHigh + (bufferPips * pipSize);
         tp = zoneLow - 2.0 * (zWidth + bufferPips * pipSize);
        }
     }

   static string     EvaluateTradeOutcomeM1(string symbol, datetime entryTime, string direction, double sl, double tp)
     {
      double high[], low[];
      int copied = CopyHigh(symbol, PERIOD_M1, entryTime, TimeCurrent(), high);
      CopyLow(symbol, PERIOD_M1, entryTime, TimeCurrent(), low);
      if(copied <= 0)
         return "PENDING";

      for(int i = 0; i < copied; i++)
        {
         if(direction == "BULLISH")
           {
            if(low[i] <= sl && sl > 0)
               return "LOSS";
            if(high[i] >= tp && tp > 0)
               return "WIN";
           }
         else
           {
            if(high[i] >= sl && sl > 0)
               return "LOSS";
            if(low[i] <= tp && tp > 0)
               return "WIN";
           }
        }
      return "PENDING";
     }

   // Event-driven historical 1-minute confirmation backtest simulator (Called by Backtester & Optimizer)
   static int        EvaluateM1ConfirmedBacktest(string symbol, bool isBullish, datetime htfTouchTime, double htfZoneHigh, double htfZoneLow, double pipSize, double &outEntry, double &outSL, double &outTP, datetime &outM1TouchTime, ENUM_TIMEFRAMES htf_tf = PERIOD_H4)
     {
      outEntry = 0.0;
      outSL = 0.0;
      outTP = 0.0;
      outM1TouchTime = 0;

      datetime m1_time[];
      double m1_open[], m1_high[], m1_low[], m1_close[];
      long m1_vol[];

      int copied = CopyTime(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_time);
      if(copied <= 30)
         return 0;

      if(CopyOpen(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_open) < copied)
         return 0;
      if(CopyHigh(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_high) < copied)
         return 0;
      if(CopyLow(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_low) < copied)
         return 0;
      if(CopyClose(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_close) < copied)
         return 0;
      if(CopyTickVolume(symbol, PERIOD_M1, htfTouchTime, TimeCurrent(), m1_vol) < copied)
         return 0;

      bool isMC = (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0);
      double dev = isMC ? CLTFConfirmationEngine::m_mc_dev_m1 : CLTFConfirmationEngine::m_fx_dev_m1;
      int dep    = isMC ? CLTFConfirmationEngine::m_mc_dep_m1 : CLTFConfirmationEngine::m_fx_dep_m1;

      Settings* s = new Settings(dev, dep, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      ZigZag* zz = newInstance(s);
      CMarketStructure* ms = new CMarketStructure();
      ms.Init(false, false);
      CDemandSupplyLogic* ds = new CDemandSupplyLogic();
      CSwingPOILogic* sp = new CSwingPOILogic();
      COrderBlockLogic* ob = new COrderBlockLogic();
      CFlipZoneLogic* fz = new CFlipZoneLogic();
      CBreakerBlockLogic* bb = new CBreakerBlockLogic();

      bool chochFound = false;
      datetime chochTime = 0;

      bool liqBosFound = false;
      datetime liqBosTime = 0;

      bool tradeActive = false;
      double entry = 0.0, sl = 0.0, tp = 0.0;
      int tradeResult = 0;

      ENUM_TIMEFRAMES tf_to_use = (htf_tf == PERIOD_H4 && _Period != PERIOD_M1) ? _Period : htf_tf;

      for(int i = 0; i < copied; i++)
        {
         bool is_last = (i == copied - 1);
         zz.update(m1_high[i], m1_low[i], m1_time[i], m1_vol[i], i, !is_last, is_last);
         ms.Update(i, m1_time, m1_high, m1_low, m1_close, zz);

         ds.DetectPOIs(i, m1_time, m1_high, m1_low, zz);
         ds.UpdateMitigation(m1_close[i]);

         sp.DetectPOIs(i, m1_time, m1_high, m1_low, zz);
         sp.UpdateMitigation(m1_close[i]);

         ob.DetectPOIs(i, m1_time, m1_high, m1_low, zz);
         ob.UpdateMitigation(m1_close[i]);

         fz.DetectFlipZones(i, m1_time, m1_high, m1_low, m1_close, zz, ms, ds);
         fz.UpdateMitigation(m1_close[i]);

         bb.DetectBreakers(zz, ds, sp, ob, fz);
         bb.UpdateMitigation(m1_high[i], m1_low[i], m1_time[i]);

         if(ob.poi_demandTime.Total() > 0)
           {
            datetime tz = (datetime)ob.poi_demandTime.At(ob.poi_demandTime.Total() - 1);
            if(ob.ob_time_found(&ms.ob_bull_struct_times, tz) && !ob.ob_time_found(&ob.ob_bull_valid_times, tz))
               if(ob.CheckBullishOB(tz, i, m1_time, m1_high, m1_low))
                  ob.ob_bull_valid_times.Add((long)tz);
           }
         if(ob.poi_supplyTime.Total() > 0)
           {
            datetime tz = (datetime)ob.poi_supplyTime.At(ob.poi_supplyTime.Total() - 1);
            if(ob.ob_time_found(&ms.ob_bear_struct_times, tz) && !ob.ob_time_found(&ob.ob_bear_valid_times, tz))
               if(ob.CheckBearishOB(tz, i, m1_time, m1_high, m1_low))
                  ob.ob_bear_valid_times.Add((long)tz);
           }

         // Monitor 1m CHoCH and Liquidity Swept BOS events concurrently
         if(!chochFound && !liqBosFound)
           {
            if(isBullish)
              {
               if(ms.trend == 1 && ms.last_breakout_time >= htfTouchTime)
                 {
                  // --- ENTRY MODEL 1: Market Shift Model (CHoCH) ---
                  if(ms.ev1_name == "BL-CHoCH")
                    {
                     chochFound = true;
                     chochTime = ms.last_breakout_time;
                    }
                  else
                     // --- ENTRY MODEL 2: Liquidity Swept Model (BOS + Swept) ---
                     if(ms.ev1_name == "BL-BOS" && ms.ev2_name == "SSL-Swept")
                       {
                        liqBosFound = true;
                        liqBosTime = ms.last_breakout_time;
                       }
                 }
              }
            else
              {
               if(ms.trend == -1 && ms.last_breakout_time >= htfTouchTime)
                 {
                  // --- ENTRY MODEL 1: Market Shift Model (CHoCH) ---
                  if(ms.ev1_name == "BR-CHoCH")
                    {
                     chochFound = true;
                     chochTime = ms.last_breakout_time;
                    }
                  else
                     // --- ENTRY MODEL 2: Liquidity Swept Model (BOS + Swept) ---
                     if(ms.ev1_name == "BR-BOS" && ms.ev2_name == "BSL-Swept")
                       {
                        liqBosFound = true;
                        liqBosTime = ms.last_breakout_time;
                       }
                 }
              }
           }

         // Once M1 Confirmation is verified, scan for M1 zone retracement with Premium/Discount validation
         if((chochFound || liqBosFound) && !tradeActive)
           {
            bool valid_choch_pullback = false;
            bool valid_liq_pullback = false;

            for(int p = 0; p < zz.pivots.Total(); p++)
              {
               Pivot* pv = (Pivot*)zz.pivots.At(p);
               if(pv == NULL || (zz.projection != NULL && pv == zz.projection))
                  continue;

               if(chochFound && pv.end.time > chochTime && pv.end.time < m1_time[i])
                 {
                  if(isBullish && pv.isHigh)
                     valid_choch_pullback = true;
                  if(!isBullish && !pv.isHigh)
                     valid_choch_pullback = true;
                 }

               if(liqBosFound && pv.end.time > liqBosTime && pv.end.time < m1_time[i])
                 {
                  if(isBullish && pv.isHigh)
                     valid_liq_pullback = true;
                  if(!isBullish && !pv.isHigh)
                     valid_liq_pullback = true;
                 }
              }

            if(!valid_choch_pullback && !valid_liq_pullback)
               continue;

            double h = m1_high[i];
            double l = m1_low[i];
            bool triggered = false;
            double zHigh = 0.0, zLow = 0.0;

            if(isBullish)
              {
               for(int k=0; k<ds.poi_demandTime.Total(); k++)
                 {
                  double tempHigh = ds.poi_demandZoneHigh.At(k);
                  double tempLow  = ds.poi_demandZoneLow.At(k);
                  if(ds.poi_demandMitigated.At(k) == 0 && l <= tempHigh && h >= tempLow)
                    {
                     if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, true, tempHigh, tempLow))
                       { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<sp.poi_demandTime.Total(); k++)
                    {
                     datetime zt = (datetime)sp.poi_demandTime.At(k);
                     double tempHigh = sp.poi_demandZoneHigh.At(k);
                     double tempLow  = sp.poi_demandZoneLow.At(k);
                     if(sp.poi_demandMitigated.At(k) == 0 && sp.ob_time_found(&ms.ob_bull_struct_times, zt) && l <= tempHigh && h >= tempLow)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, true, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<ob.poi_demandTime.Total(); k++)
                    {
                     datetime zt = (datetime)ob.poi_demandTime.At(k);
                     double tempHigh = ob.poi_demandZoneHigh.At(k);
                     double tempLow  = ob.poi_demandZoneLow.At(k);
                     if(ob.poi_demandMitigated.At(k) == 0 && ob.ob_time_found(&ms.ob_bull_struct_times, zt) && ob.ob_time_found(&ob.ob_bull_valid_times, zt) && l <= tempHigh && h >= tempLow)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, true, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<fz.fz_time.Total(); k++)
                    {
                     double tempHigh = fz.fz_zoneHigh.At(k);
                     double tempLow  = fz.fz_zoneLow.At(k);
                     if(fz.fz_type.At(k) == 1 && fz.fz_mitigated.At(k) == 0 && l <= tempHigh && h >= tempLow)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, true, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<bb.bb_time.Total(); k++)
                    {
                     double tempHigh = bb.bb_zoneHigh.At(k);
                     double tempLow  = bb.bb_zoneLow.At(k);
                     if(bb.bb_type.At(k) == 1 && bb.bb_mitigated.At(k) == 0 && l <= tempHigh && h >= tempLow)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, true, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
              }
            else
              {
               for(int k=0; k<ds.poi_supplyTime.Total(); k++)
                 {
                  double tempHigh = ds.poi_supplyZoneHigh.At(k);
                  double tempLow  = ds.poi_supplyZoneLow.At(k);
                  if(ds.poi_supplyMitigated.At(k) == 0 && h >= tempLow && l <= tempHigh)
                    {
                     if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, false, tempHigh, tempLow))
                       { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<sp.poi_supplyTime.Total(); k++)
                    {
                     datetime zt = (datetime)sp.poi_supplyTime.At(k);
                     double tempHigh = sp.poi_supplyZoneHigh.At(k);
                     double tempLow  = sp.poi_supplyZoneLow.At(k);
                     if(sp.poi_supplyMitigated.At(k) == 0 && sp.ob_time_found(&ms.ob_bear_struct_times, zt) && h >= tempLow && l <= tempHigh)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, false, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<ob.poi_supplyTime.Total(); k++)
                    {
                     datetime zt = (datetime)ob.poi_supplyTime.At(k);
                     double tempHigh = ob.poi_supplyZoneHigh.At(k);
                     double tempLow  = ob.poi_supplyZoneLow.At(k);
                     if(ob.poi_supplyMitigated.At(k) == 0 && ob.ob_time_found(&ms.ob_bear_struct_times, zt) && ob.ob_time_found(&ob.ob_bear_valid_times, zt) && h >= tempLow && l <= tempHigh)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, false, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<fz.fz_time.Total(); k++)
                    {
                     double tempHigh = fz.fz_zoneHigh.At(k);
                     double tempLow  = fz.fz_zoneLow.At(k);
                     if(fz.fz_type.At(k) == -1 && fz.fz_mitigated.At(k) == 0 && h >= tempLow && l <= tempHigh)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, false, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
               if(!triggered)
                 {
                  for(int k=0; k<bb.bb_time.Total(); k++)
                    {
                     double tempHigh = bb.bb_zoneHigh.At(k);
                     double tempLow  = bb.bb_zoneLow.At(k);
                     if(bb.bb_type.At(k) == -1 && bb.bb_mitigated.At(k) == 0 && h >= tempLow && l <= tempHigh)
                       {
                        if(IsZoneInAllowedDiscountPremium(symbol, tf_to_use, false, tempHigh, tempLow))
                          { triggered = true; zHigh = tempHigh; zLow = tempLow; break; }
                       }
                    }
                 }
              }

            if(triggered)
              {
               tradeActive = true;
               outM1TouchTime = m1_time[i];
               entry = isBullish ? zHigh : zLow;
               if(isBullish)
                 {
                  // SL based on M1 Zone Low
                  sl = zLow - (3.0 * pipSize);

                  // Target (TP) 2R based on HTF Zone Low (risk calculated from M1 Entry to HTF SL)
                  double htfRisk = MathAbs(entry - (htfZoneLow - 3.0 * pipSize));
                  tp = entry + 2.0 * htfRisk;
                 }
               else
                 {
                  // SL based on M1 Zone High
                  sl = zHigh + (3.0 * pipSize);

                  // Target (TP) 2R based on HTF Zone High (risk calculated from HTF SL to M1 Entry)
                  double htfRisk = MathAbs((htfZoneHigh + 3.0 * pipSize) - entry);
                  tp = entry - 2.0 * htfRisk;
                 }
               outEntry = entry;
               outSL = sl;
               outTP = tp;
              }
           }

         // Track trade state changes
         if(tradeActive)
           {
            double h = m1_high[i];
            double l = m1_low[i];
            if(isBullish)
              {
               if(l <= sl)
                 {
                  tradeResult = -1;
                  break;
                 }
               if(h >= tp)
                 {
                  tradeResult = 1;
                  break;
                 }
              }
            else
              {
               if(h >= sl)
                 {
                  tradeResult = -1;
                  break;
                 }
               if(l <= tp)
                 {
                  tradeResult = 1;
                  break;
                 }
              }
           }
        }

      if(CheckPointer(zz) == POINTER_DYNAMIC)
         delete zz;
      if(CheckPointer(ms) == POINTER_DYNAMIC)
         delete ms;
      if(CheckPointer(ds) == POINTER_DYNAMIC)
         delete ds;
      if(CheckPointer(sp) == POINTER_DYNAMIC)
         delete sp;
      if(CheckPointer(ob) == POINTER_DYNAMIC)
         delete ob;
      if(CheckPointer(fz) == POINTER_DYNAMIC)
         delete fz;
      if(CheckPointer(bb) == POINTER_DYNAMIC)
         delete bb;

      return tradeResult;
     }
  };

// =========================================================================
// CENTRALIZED PERFORMANCE LOGGING IMPLEMENTATIONS
// =========================================================================
CArrayString g_daily_alerts;
string       g_daily_alerts_date = "";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadDailyAlerts(string suffix)
  {
   g_daily_alerts_date = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(g_daily_alerts_date, ".", "-");
   string fileName = g_daily_alerts_date + "_" + suffix + "_alert.csv";

   g_daily_alerts.Clear();
   if(!FileIsExist(fileName))
     {
      int c_fh = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(c_fh != INVALID_HANDLE)
        {
         FileWriteString(c_fh, "Time,Symbol,Timeframe,Type,Direction,Entry,SL,TP,Key\n");
         FileClose(c_fh);
        }
     }

   int fh = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(fh != INVALID_HANDLE)
     {
      while(!FileIsEnding(fh))
        {
         string line = FileReadString(fh);
         if(line == "" || StringFind(line, "Time,Symbol") == 0)
            continue;
         string parts[];
         int cnt = StringSplit(line, ',', parts);
         if(cnt >= 9)
            g_daily_alerts.Add(parts[8]);
        }
      FileClose(fh);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckAndRegisterDailyAlert(string suffix, string fullKey, string symbol, string tfStr, string obType, string dir, double entry, double sl, double tp)
  {
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(today, ".", "-");
   if(today != g_daily_alerts_date)
      LoadDailyAlerts(suffix);

   for(int i = 0; i < g_daily_alerts.Total(); i++)
     {
      if(g_daily_alerts.At(i) == fullKey)
         return true;
     }

   g_daily_alerts.Add(fullKey);
   string fileName = g_daily_alerts_date + "_" + suffix + "_alert.csv";
   int fh = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(fh != INVALID_HANDLE)
     {
      FileSeek(fh, 0, SEEK_END);
      string line = IntegerToString(TimeCurrent()) + "," + symbol + "," + tfStr + "," + obType + "," + dir + "," +
                    DoubleToString(entry, 5) + "," + DoubleToString(sl, 5) + "," + DoubleToString(tp, 5) + "," + fullKey;
      FileWriteString(fh, line + "\n");
      FileClose(fh);
     }
   return false;
  }

// =========================================================================
// LTF CONFIRMATION STATE MACHINE MODEL
// =========================================================================
struct PendingConfirmation
  {
   string            symbol;
   ENUM_TIMEFRAMES   htf_tf;
   string            htf_zoneLabel;
   bool              isBullish;
   double            htf_zHigh;
   double            htf_zLow;
   datetime          htf_zTime;
   int               htf_listType;
   int               htf_index;
   datetime          htf_touchTime;

   // Market Shift (CHoCH) Model & Liquidity Swept Model Combined Tracker
   int               state;           // 0=wait confirmation trigger, 1=wait retracement, 3=triggered/expired
   datetime          m1_triggerTime;

   string            suffix;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLTFM1Instance
  {
public:
   string             symbol;
   ZigZag*            zigZag;
   CMarketStructure*  ms;
   CDemandSupplyLogic* dsLogic;
   CSwingPOILogic*    spLogic;
   COrderBlockLogic*  obLogic;
   CFlipZoneLogic*    fzLogic;
   CBreakerBlockLogic* bbLogic;
   int                prev_calculated;

                     CLTFM1Instance(string sym, double deviation, int depth)
     {
      symbol = sym;
      prev_calculated = 0;

      Settings* s = new Settings(deviation, depth, clrNONE, true, false, false, false, "Percent");
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

                    ~CLTFM1Instance()
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

   void              Process();
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLTFConfirmationEngine
  {
private:
   static PendingConfirmation m_pending[];
   static CLTFM1Instance*    m_m1_instances[];

public:
   static double             m_fx_dev_m1;
   static int                m_fx_dep_m1;
   static double             m_mc_dev_m1;
   static int                m_mc_dep_m1;

   static int                m_fx_maxLookback;
   static int                m_mc_maxLookback;

   static CLTFM1Instance* GetM1Instance(string symbol)
     {
      int size = ArraySize(m_m1_instances);
      for(int i = 0; i < size; i++)
        {
         if(m_m1_instances[i] != NULL && m_m1_instances[i].symbol == symbol)
            return m_m1_instances[i];
        }

      bool isMC = (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0);
      double dev = isMC ? m_mc_dev_m1 : m_fx_dev_m1;
      int dep    = isMC ? m_mc_dep_m1 : m_fx_dep_m1;

      CLTFM1Instance* inst = new CLTFM1Instance(symbol, dev, dep);
      ArrayResize(m_m1_instances, size + 1);
      m_m1_instances[size] = inst;
      return inst;
     }

   static void       CleanupUnusedInstances()
     {
      int p_size = ArraySize(m_pending);
      int m_size = ArraySize(m_m1_instances);
      if(m_size == 0)
         return;

      bool used[];
      ArrayResize(used, m_size);
      ArrayInitialize(used, false);

      for(int i = 0; i < p_size; i++)
        {
         if(m_pending[i].state != 3) // Active confirmation exists
           {
            for(int j = 0; j < m_size; j++)
              {
               if(m_m1_instances[j] != NULL && m_m1_instances[j].symbol == m_pending[i].symbol)
                 {
                  used[j] = true;
                  break;
                 }
              }
           }
        }

      int active_count = 0;
      for(int j = 0; j < m_size; j++)
        {
         if(!used[j] && m_m1_instances[j] != NULL)
           {
            delete m_m1_instances[j];
            m_m1_instances[j] = NULL;
           }
         if(m_m1_instances[j] != NULL)
            active_count++;
        }

      if(active_count < m_size)
        {
         CLTFM1Instance* temp[];
         ArrayResize(temp, active_count);
         int idx = 0;
         for(int j = 0; j < m_size; j++)
           {
            if(m_m1_instances[j] != NULL)
              {
               temp[idx] = m_m1_instances[j];
               idx++;
              }
           }
         ArrayResize(m_m1_instances, active_count);
         for(int j = 0; j < active_count; j++)
           {
            m_m1_instances[j] = temp[j];
           }
        }
     }

public:
   static void       AddHTFTouch(string suffix, string symbol, ENUM_TIMEFRAMES tf, string zoneLabel, bool isBullish, double zHigh, double zLow, datetime zTime, int listType, int index)
     {
      int p_size = ArraySize(m_pending);
      for(int i = 0; i < p_size; i++)
        {
         if(m_pending[i].symbol == symbol && m_pending[i].htf_tf == tf && m_pending[i].htf_zoneLabel == zoneLabel && m_pending[i].htf_zTime == zTime && m_pending[i].state != 3)
            return;
        }

      PendingConfirmation pc;
      pc.symbol         = symbol;
      pc.htf_tf         = tf;
      pc.htf_zoneLabel  = zoneLabel;
      pc.isBullish      = isBullish;
      pc.htf_zHigh      = zHigh;
      pc.htf_zLow       = zLow;
      pc.htf_zTime      = zTime;
      pc.htf_listType   = listType;
      pc.htf_index      = index;
      pc.htf_touchTime  = TimeCurrent();

      pc.state          = 0;
      pc.m1_triggerTime = 0;
      pc.suffix         = suffix;

      ArrayResize(m_pending, p_size + 1);
      m_pending[p_size] = pc;

      PrintFormat("⏳ Registered HTF Touch (%s): %s %s %s. Waiting for M1 Confirmation Models...", suffix, symbol, EnumToString(tf), zoneLabel);
     }

   static void       TriggerM1Alert(PendingConfirmation &pc, string m1_zoneLabel, double zHigh, double zLow, long zTime, int index, int listType, CLTFM1Instance* m1_inst, string model_name, datetime trigger_time);
   static void       ProcessLTFConfirmations();
  };

//+------------------------------------------------------------------+
void CLTFM1Instance::Process()
  {
   datetime temp_sync[];
   if(CopyTime(symbol, PERIOD_M1, 0, 2000, temp_sync) <= 0)
      return;

   int rates_total = Bars(symbol, PERIOD_M1);
   if(rates_total < 30)
      return;

   bool isMC = (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0);
   int maxLB = isMC ? CLTFConfirmationEngine::m_mc_maxLookback : CLTFConfirmationEngine::m_fx_maxLookback;
   if(maxLB <= 0)
      maxLB = 10000;

   int start_bar = MathMax(0, rates_total - maxLB);
   int to_copy = rates_total - start_bar;

   double high[], low[], close[];
   datetime time[];
   long vol[];

   if(CopyTime(symbol, PERIOD_M1, 0, to_copy, time) <= 0)
      return;
   if(CopyHigh(symbol, PERIOD_M1, 0, to_copy, high) <= 0)
      return;
   if(CopyLow(symbol, PERIOD_M1, 0, to_copy, low) <= 0)
      return;
   if(CopyClose(symbol, PERIOD_M1, 0, to_copy, close) <= 0)
      return;
   if(CopyTickVolume(symbol, PERIOD_M1, 0, to_copy, vol) <= 0)
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
            if(obLogic.CheckBullishOB(tz, i, time, high, low))
               obLogic.ob_bull_valid_times.Add((long)tz);
        }
      if(obLogic.poi_supplyTime.Total() > 0)
        {
         datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
         if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz))
            if(obLogic.CheckBearishOB(tz, i, time, high, low))
               obLogic.ob_bear_valid_times.Add((long)tz);
        }
     }
   prev_calculated = rates_total;
  }

//+------------------------------------------------------------------+
void CLTFConfirmationEngine::ProcessLTFConfirmations()
  {
   int p_size = ArraySize(m_pending);
   if(p_size == 0)
      return;

   bool updated = false;

   for(int i = 0; i < p_size; i++)
     {
      if(m_pending[i].state == 3)
         continue;

      if(TimeCurrent() - m_pending[i].htf_touchTime > 86400)
        {
         m_pending[i].state = 3;
         PrintFormat("🕒 Confirmation expired for %s %s %s.", m_pending[i].symbol, EnumToString(m_pending[i].htf_tf), m_pending[i].htf_zoneLabel);
         updated = true;
         continue;
        }

      CLTFM1Instance* m1_inst = GetM1Instance(m_pending[i].symbol);
      if(m1_inst == NULL)
         continue;

      m1_inst.Process();
      datetime htf_m1_bar = m_pending[i].htf_touchTime - (m_pending[i].htf_touchTime % 60);
      string active_model_name = "";

      // -------------------------------------------------------------
      // 1. COMBINED ENTRY MODEL TRIGGER VERIFICATION
      // -------------------------------------------------------------
      if(m_pending[i].state == 0)
        {
         if(m_pending[i].isBullish)
           {
            if(m1_inst.ms.trend == 1 && m1_inst.ms.last_breakout_time >= htf_m1_bar)
              {
               // --- ENTRY MODEL 1: Market Shift Model (CHoCH) ---
               if(m1_inst.ms.ev1_name == "BL-CHoCH")
                 {
                  m_pending[i].state = 1;
                  m_pending[i].m1_triggerTime = m1_inst.ms.last_breakout_time;
                  PrintFormat("⚡ M1 Market Shift (CHoCH) verified for %s. Checking retracement...", m_pending[i].symbol);
                  updated = true;
                 }
               else
                  // --- ENTRY MODEL 2: Liquidity Swept Model (BOS + Swept) ---
                  if(m1_inst.ms.ev1_name == "BL-BOS" && m1_inst.ms.ev2_name == "SSL-Swept")
                    {
                     m_pending[i].state = 1;
                     m_pending[i].m1_triggerTime = m1_inst.ms.last_breakout_time;
                     PrintFormat("💧 M1 Liquidity Swept (BL-BOS) verified for %s. Checking retracement...", m_pending[i].symbol);
                     updated = true;
                    }
              }
           }
         else
           {
            if(m1_inst.ms.trend == -1 && m1_inst.ms.last_breakout_time >= htf_m1_bar)
              {
               // --- ENTRY MODEL 1: Market Shift Model (CHoCH) ---
               if(m1_inst.ms.ev1_name == "BR-CHoCH")
                 {
                  m_pending[i].state = 1;
                  m_pending[i].m1_triggerTime = m1_inst.ms.last_breakout_time;
                  PrintFormat("⚡ M1 Market Shift (CHoCH) verified for %s. Checking retracement...", m_pending[i].symbol);
                  updated = true;
                 }
               else
                  // --- ENTRY MODEL 2: Liquidity Swept Model (BOS + Swept) ---
                  if(m1_inst.ms.ev1_name == "BR-BOS" && m1_inst.ms.ev2_name == "BSL-Swept")
                    {
                     m_pending[i].state = 1;
                     m_pending[i].m1_triggerTime = m1_inst.ms.last_breakout_time;
                     PrintFormat("💧 M1 Liquidity Swept (BR-BOS) verified for %s. Checking retracement...", m_pending[i].symbol);
                     updated = true;
                    }
              }
           }
        }

      // -------------------------------------------------------------
      // 2. RETRACEMENT & ZONE TOUCH EVALUATOR
      // -------------------------------------------------------------
      if(m_pending[i].state == 1)
        {
         bool valid_pullback = false;

         for(int p = 0; p < m1_inst.zigZag.pivots.Total(); p++)
           {
            Pivot* pv = (Pivot*)m1_inst.zigZag.pivots.At(p);
            if(pv == NULL || (m1_inst.zigZag.projection != NULL && pv == m1_inst.zigZag.projection))
               continue;

            if(pv.end.time > m_pending[i].m1_triggerTime && pv.end.time < TimeCurrent())
              {
               if(m_pending[i].isBullish && pv.isHigh)
                  valid_pullback = true;
               if(!m_pending[i].isBullish && !pv.isHigh)
                  valid_pullback = true;
              }
           }

         if(!valid_pullback)
            continue;

         double liveBid = SymbolInfoDouble(m_pending[i].symbol, SYMBOL_BID);
         double liveAsk = SymbolInfoDouble(m_pending[i].symbol, SYMBOL_ASK);
         if(liveBid == 0.0 || liveAsk == 0.0)
            continue;

         double m1_high[], m1_low[];
         CopyHigh(m_pending[i].symbol, PERIOD_M1, 0, 1, m1_high);
         CopyLow(m_pending[i].symbol, PERIOD_M1, 0, 1, m1_low);
         double h = (ArraySize(m1_high) > 0) ? MathMax(liveBid, m1_high[0]) : liveBid;
         double l = (ArraySize(m1_low) > 0)  ? MathMin(liveAsk, m1_low[0])  : liveAsk;

         bool triggered = false;

         active_model_name = (m1_inst.ms.ev1_name == "BL-BOS" || m1_inst.ms.ev1_name == "BR-BOS") ? "Liquidity Swept Entry Model" : "Market Shift Entry Model";

         if(m_pending[i].isBullish)
           {
            for(int k = 0; k < m1_inst.dsLogic.poi_demandTime.Total(); k++)
              {
               double zHigh = m1_inst.dsLogic.poi_demandZoneHigh.At(k);
               double zLow  = m1_inst.dsLogic.poi_demandZoneLow.At(k);
               bool isMit = (m1_inst.dsLogic.poi_demandMitigated.At(k) == 1);
               if(!isMit && l <= zHigh && h >= zLow)
                 {
                  if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, true, zHigh, zLow))
                    {
                     TriggerM1Alert(m_pending[i], "DEMAND ZONE", zHigh, zLow, m1_inst.dsLogic.poi_demandTime.At(k), k, 1, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                     triggered = true;
                     break;
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.spLogic.poi_demandTime.Total(); k++)
              {
               long zTime = m1_inst.spLogic.poi_demandTime.At(k);
               if(m1_inst.spLogic.ob_time_found(&m1_inst.ms.ob_bull_struct_times, (datetime)zTime))
                 {
                  double zHigh = m1_inst.spLogic.poi_demandZoneHigh.At(k);
                  double zLow  = m1_inst.spLogic.poi_demandZoneLow.At(k);
                  bool isMit = (m1_inst.spLogic.poi_demandMitigated.At(k) == 1);
                  if(!isMit && l <= zHigh && h >= zLow)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, true, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "SWING POI", zHigh, zLow, zTime, k, 2, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.obLogic.poi_demandTime.Total(); k++)
              {
               long zTime = m1_inst.obLogic.poi_demandTime.At(k);
               if(m1_inst.obLogic.ob_time_found(&m1_inst.ms.ob_bull_struct_times, (datetime)zTime) && m1_inst.obLogic.ob_time_found(&m1_inst.obLogic.ob_bull_valid_times, (datetime)zTime))
                 {
                  double zHigh = m1_inst.obLogic.poi_demandZoneHigh.At(k);
                  double zLow  = m1_inst.obLogic.poi_demandZoneLow.At(k);
                  bool isMit = (m1_inst.obLogic.poi_demandMitigated.At(k) == 1);
                  if(!isMit && l <= zHigh && h >= zLow)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, true, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "ORDER-BLOCK", zHigh, zLow, zTime, k, 3, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.fzLogic.fz_time.Total(); k++)
              {
               if(m1_inst.fzLogic.fz_type.At(k) == 1)
                 {
                  double zHigh = m1_inst.fzLogic.fz_zoneHigh.At(k);
                  double zLow  = m1_inst.fzLogic.fz_zoneLow.At(k);
                  bool isMit = (m1_inst.fzLogic.fz_mitigated.At(k) == 1);
                  if(!isMit && l <= zHigh && h >= zLow)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, true, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "DEMAND FLIP", zHigh, zLow, m1_inst.fzLogic.fz_time.At(k), k, 4, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.bbLogic.bb_time.Total(); k++)
              {
               if(m1_inst.bbLogic.bb_type.At(k) == 1)
                 {
                  double zHigh = m1_inst.bbLogic.bb_zoneHigh.At(k);
                  double zLow  = m1_inst.bbLogic.bb_zoneLow.At(k);
                  bool isMit = (m1_inst.bbLogic.bb_mitigated.At(k) == 1);
                  if(!isMit && l <= zHigh && h >= zLow)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, true, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "Bullish Breaker", zHigh, zLow, m1_inst.bbLogic.bb_time.At(k), k, 5, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }
           }
         else
           {
            for(int k = 0; k < m1_inst.dsLogic.poi_supplyTime.Total(); k++)
              {
               double zHigh = m1_inst.dsLogic.poi_supplyZoneHigh.At(k);
               double zLow  = m1_inst.dsLogic.poi_supplyZoneLow.At(k);
               bool isMit = (m1_inst.dsLogic.poi_supplyMitigated.At(k) == 1);
               if(!isMit && h >= zLow && l <= zHigh)
                 {
                  if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, false, zHigh, zLow))
                    {
                     TriggerM1Alert(m_pending[i], "SUPPLY ZONE", zHigh, zLow, m1_inst.dsLogic.poi_supplyTime.At(k), k, 1, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                     triggered = true;
                     break;
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.spLogic.poi_supplyTime.Total(); k++)
              {
               long zTime = m1_inst.spLogic.poi_supplyTime.At(k);
               if(m1_inst.spLogic.ob_time_found(&m1_inst.ms.ob_bear_struct_times, (datetime)zTime))
                 {
                  double zHigh = m1_inst.spLogic.poi_supplyZoneHigh.At(k);
                  double zLow  = m1_inst.spLogic.poi_supplyZoneLow.At(k);
                  bool isMit = (m1_inst.spLogic.poi_supplyMitigated.At(k) == 1);
                  if(!isMit && h >= zLow && l <= zHigh)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, false, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "SWING POI", zHigh, zLow, zTime, k, 2, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.obLogic.poi_supplyTime.Total(); k++)
              {
               long zTime = m1_inst.obLogic.poi_supplyTime.At(k);
               if(m1_inst.obLogic.ob_time_found(&m1_inst.ms.ob_bear_struct_times, (datetime)zTime) && m1_inst.obLogic.ob_time_found(&m1_inst.obLogic.ob_bear_valid_times, (datetime)zTime))
                 {
                  double zHigh = m1_inst.obLogic.poi_supplyZoneHigh.At(k);
                  double zLow  = m1_inst.obLogic.poi_supplyZoneLow.At(k);
                  bool isMit = (m1_inst.obLogic.poi_supplyMitigated.At(k) == 1);
                  if(!isMit && h >= zLow && l <= zHigh)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, false, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "ORDER-BLOCK", zHigh, zLow, zTime, k, 3, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.fzLogic.fz_time.Total(); k++)
              {
               if(m1_inst.fzLogic.fz_type.At(k) == -1)
                 {
                  double zHigh = m1_inst.fzLogic.fz_zoneHigh.At(k);
                  double zLow  = m1_inst.fzLogic.fz_zoneLow.At(k);
                  bool isMit = (m1_inst.fzLogic.fz_mitigated.At(k) == 1);
                  if(!isMit && h >= zLow && l <= zHigh)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, false, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "SUPPLY FLIP", zHigh, zLow, m1_inst.fzLogic.fz_time.At(k), k, 4, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }

            for(int k = 0; k < m1_inst.bbLogic.bb_time.Total(); k++)
              {
               if(m1_inst.bbLogic.bb_type.At(k) == -1)
                 {
                  double zHigh = m1_inst.bbLogic.bb_zoneHigh.At(k);
                  double zLow  = m1_inst.bbLogic.bb_zoneLow.At(k);
                  bool isMit = (m1_inst.bbLogic.bb_mitigated.At(k) == 1);
                  if(!isMit && h >= zLow && l <= zHigh)
                    {
                     if(CEntryModel::IsZoneInAllowedDiscountPremium(m_pending[i].symbol, m_pending[i].htf_tf, false, zHigh, zLow))
                       {
                        TriggerM1Alert(m_pending[i], "Bearish Breaker", zHigh, zLow, m1_inst.bbLogic.bb_time.At(k), k, 5, m1_inst, active_model_name, m_pending[i].m1_triggerTime);
                        triggered = true;
                        break;
                       }
                    }
                 }
              }
            if(triggered)
              {
               updated = true;
               continue;
              }
           }
        }
     }

   if(updated)
     {
      int active_count = 0;
      for(int i = 0; i < p_size; i++)
        {
         if(m_pending[i].state != 3)
            active_count++;
        }

      if(active_count < p_size)
        {
         PendingConfirmation temp[];
         ArrayResize(temp, active_count);
         int idx = 0;
         for(int i = 0; i < p_size; i++)
           {
            if(m_pending[i].state != 3)
              {
               temp[idx] = m_pending[i];
               idx++;
              }
           }
         ArrayResize(m_pending, active_count);
         for(int i = 0; i < active_count; i++)
           {
            m_pending[i] = temp[i];
           }
        }
     }

   CleanupUnusedInstances();
  }

//+------------------------------------------------------------------+
void CLTFConfirmationEngine::TriggerM1Alert(PendingConfirmation &pc, string m1_zoneLabel, double zHigh, double zLow, long zTime, int index, int listType, CLTFM1Instance* m1_inst, string model_name, datetime trigger_time)
  {
   pc.state = 3; // Immediately mark entire pending tracking as complete.

   OBAnalysis oa;
   oa.zoneLabel       = pc.htf_zoneLabel;
   oa.zoneHigh        = pc.htf_zHigh;
   oa.zoneLow         = pc.htf_zLow;
   oa.zoneCreatedTime = pc.htf_zTime;
   oa.isFresh         = true;
   oa.isPreviouslyMitigated = false;
   oa.touchCount      = 0;

   bool isMC = (StringFind(pc.symbol, "BTC") >= 0 || StringFind(pc.symbol, "XAU") >= 0 || StringFind(pc.symbol, "XAG") >= 0);
   int maxLB = isMC ? m_mc_maxLookback : m_fx_maxLookback;
   if(maxLB <= 0)
      maxLB = 10000;

   oa.maxLookbackBars = maxLB;
   oa.deviationInput  = m1_inst.zigZag.settings.devThreshold;
   oa.depthInput      = m1_inst.zigZag.settings.depth;

   oa.trendBias = pc.isBullish ? "BULLISH" : "BEARISH";
   oa.marketStructureType = pc.isBullish ? "HH & HL (Confirmed on M1)" : "LH & LL (Confirmed on M1)";
   oa.bosDetected = true;
   oa.chochDetected = true;
   oa.lastBosTime = trigger_time;
   oa.lastBosType = pc.isBullish ? "M1 Bullish Confirmation" : "M1 Bearish Confirmation";

   long vol[];
   CopyTickVolume(pc.symbol, PERIOD_M1, 0, 1, vol);
   oa.tickVolume = (ArraySize(vol) > 0) ? vol[0] : 0;
   oa.realVolume = 0;
   oa.cumulativeVolume = (long)m1_inst.zigZag.cVols.get(0);

   Pivot* lastP = m1_inst.zigZag.lastPivot();
   if(lastP != NULL && lastP.start != NULL && lastP.end != NULL)
     {
      oa.zzReversalPrice = lastP.end.price;
      oa.zzPriorReversalPrice = lastP.start.price;
      oa.zzPriceChange = lastP.end.price - lastP.start.price;
      oa.zzDirection = (oa.zzPriceChange > 0) ? "UP" : "DOWN";
     }
   else
     {
      oa.zzReversalPrice = 0;
      oa.zzPriorReversalPrice = 0;
      oa.zzPriceChange = 0;
      oa.zzDirection = "UNKNOWN";
     }

   int digits = (int)SymbolInfoInteger(pc.symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(pc.symbol, SYMBOL_POINT);
   double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

   double liveBid = SymbolInfoDouble(pc.symbol, SYMBOL_BID);
   double liveAsk = SymbolInfoDouble(pc.symbol, SYMBOL_ASK);
   double livePrice = pc.isBullish ? liveAsk : liveBid;

   double slBuffer = 3.0 * pipSize;

   if(pc.isBullish)
     {
      // 1. SL is based on M1 Bullish Zone Low (zLow) - 3 pip buffer
      oa.slPrice = zLow - slBuffer;

      // 2. TP is based on 2x the distance to the HTF Zone Low (Reward based on HTF structure invalidation)
      double htfRisk = MathAbs(livePrice - (pc.htf_zLow - slBuffer));
      oa.tpPrice = livePrice + 2.0 * htfRisk;
     }
   else
     {
      // 1. SL is based on M1 Bearish Zone High (zHigh) + 3 pip buffer
      oa.slPrice = zHigh + slBuffer;

      // 2. TP is based on 2x the distance to the HTF Zone High (Reward based on HTF structure invalidation)
      double htfRisk = MathAbs((pc.htf_zHigh + slBuffer) - livePrice);
      oa.tpPrice = livePrice - 2.0 * htfRisk;
     }

   double tickSize  = SymbolInfoDouble(pc.symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(pc.symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0)
      tickSize = point;

   double riskPrice = MathAbs(livePrice - oa.slPrice);
   double rewardPrice = MathAbs(oa.tpPrice - livePrice);

   oa.estLoss   = (riskPrice / tickSize) * tickValue;
   oa.estProfit = (rewardPrice / tickSize) * tickValue;

   datetime arr_time[];
   double   arr_open[], arr_high[], arr_low[], arr_close[];
   int      lookback_bars = 15;

   CopyTime(pc.symbol, PERIOD_M1, 0, lookback_bars, arr_time);
   CopyOpen(pc.symbol, PERIOD_M1, 0, lookback_bars, arr_open);
   CopyHigh(pc.symbol, PERIOD_M1, 0, lookback_bars, arr_high);
   CopyLow(pc.symbol, PERIOD_M1, 0, lookback_bars, arr_low);
   CopyClose(pc.symbol, PERIOD_M1, 0, lookback_bars, arr_close);

   int touch_index = ArraySize(arr_time) - 1;
   if(touch_index < 0)
      touch_index = 0;

   CPoCAnalyzer pocEngine;
   PoCResult pocRes = pocEngine.EvaluateZone(
                         pc.isBullish, (datetime)zTime, zHigh, zLow,
                         touch_index, arr_time, arr_open, arr_high, arr_low, arr_close,
                         m1_inst.zigZag, m1_inst.ms, m1_inst.dsLogic, m1_inst.spLogic, m1_inst.obLogic, livePrice, pipSize, PERIOD_M1, "0800-1200", "1200-1600"
                      );

   oa.setupQuality   = pocRes.finalScore;
   oa.recommendation = "M1 CONFIRMED TARGET SETUP";

   string detailText = StringFormat(
                          "- ⚡ **M1 Entry Model:** %s\\n\\n"
                          "- 🕒 **M1 Confirmation Time:** %s\\n\\n"
                          "- 🎯 **M1 Retracement Trigger Zone:** %s (High: %.5f, Low: %.5f)\\n\\n"
                          "- 🕒 **M1 Zone Created:** %s\\n\\n"
                          "- 🧩 **HTF Original Zone:** %s (%s) Touched at %s\\n\\n",
                          model_name,
                          TimeToString(trigger_time, TIME_MINUTES),
                          m1_zoneLabel, zHigh, zLow,
                          TimeToString((datetime)zTime, TIME_MINUTES),
                          pc.htf_zoneLabel,
                          StringSubstr(EnumToString(pc.htf_tf), 7),
                          TimeToString(pc.htf_touchTime, TIME_MINUTES)
                       );

   oa.reasoning = detailText + pocRes.reasoning;
   string obType = pc.isBullish ? "BULLISH" : "BEARISH";

   Print("+++ 🚀 M1 CONFIRMED Touch Alert Sent: ", pc.symbol, " ", StringSubstr(EnumToString(pc.htf_tf), 7), " ", obType);
   SendOBAlert(pc.symbol, pc.htf_tf, obType, oa, ALERTS_TEAMS_URL);

   string fullKey = StringFormat("%s_%s_%s_%s_%s_%.5f_%.5f", pc.symbol, EnumToString(pc.htf_tf), pc.htf_zoneLabel, obType, pc.isBullish ? "M" : "F", zHigh, zLow);
   CheckAndRegisterDailyAlert(pc.suffix, fullKey, pc.symbol, "M1", pc.htf_zoneLabel, obType, livePrice, oa.slPrice, oa.tpPrice);
  }

PendingConfirmation CLTFConfirmationEngine::m_pending[];
CLTFM1Instance* CLTFConfirmationEngine::m_m1_instances[];
double CLTFConfirmationEngine::m_fx_dev_m1 = 0.10;
int CLTFConfirmationEngine::m_fx_dep_m1 = 10;
double CLTFConfirmationEngine::m_mc_dev_m1 = 0.50;
int CLTFConfirmationEngine::m_mc_dep_m1 = 10;
int CLTFConfirmationEngine::m_fx_maxLookback = 10000;
int CLTFConfirmationEngine::m_mc_maxLookback = 10000;

HTFSwingCache CEntryModel::m_swing_caches[];

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\entry_model.mqh

// END FILE: Include\Custom\ZigZag\entry_model.mqh
