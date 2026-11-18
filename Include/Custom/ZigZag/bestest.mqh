//+------------------------------------------------------------------+
//|                                        Include\Custom\ZigZag\bestest.mqh |
//|                    SMC Historical Zone Event-Driven Simulator     |
//|                    v4.10 — Synchronized Datapool State Engine     |
//+------------------------------------------------------------------+
#ifndef CBESTEST_INSTANCE_MQH
#define CBESTEST_INSTANCE_MQH

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\ZigZag\order_blocks.mqh>
#include <Custom\ZigZag\flipzone.mqh>
#include <Custom\ZigZag\breaker_blocks.mqh>
#include <Custom\ZigZag\entry_model.mqh>

// =========================================================================
// STREAMLINED DATA MODELS FOR OPTIMIZER (ZoneStatsLite & BacktestMetricsLite)
// =========================================================================
class ZoneStatsLite
  {
public:
   int               success;
   int               fail;
   int               pending;

                     ZoneStatsLite() { Init(); }
   void              Init() { success = 0; fail = 0; pending = 0; }
   double            Ratio()
     {
      int total = success + fail;
      if(total == 0)
         return 0.0;
      return ((double)success / total) * 100.0;
     }
   void              RecordSuccess() { success++; }
   void              RecordFail()    { fail++; }
   void              RecordPending() { pending++; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class BacktestMetricsLite
  {
public:
   ZoneStatsLite     demand;
   ZoneStatsLite     supply;
   ZoneStatsLite     bullPOI;
   ZoneStatsLite     bearPOI;
   ZoneStatsLite     bullOB;
   ZoneStatsLite     bearOB;
   ZoneStatsLite     demandFlip;
   ZoneStatsLite     supplyFlip;
   ZoneStatsLite     bullBreaker;
   ZoneStatsLite     bearBreaker;

                     BacktestMetricsLite() { Init(); }
   void              Init()
     {
      demand.Init();
      supply.Init();
      bullPOI.Init();
      bearPOI.Init();
      bullOB.Init();
      bearOB.Init();
      demandFlip.Init();
      supplyFlip.Init();
      bullBreaker.Init();
      bearBreaker.Init();
     }
  };

// =========================================================================
// LAYER 1 — OHLC CACHE
// =========================================================================
class CSymbolTFCache
  {
public:
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   datetime          time[];
   double            open[];
   double            high[];
   double            low[];
   double            close[];
   long              vol[];
   int               bars;
   int               start_bar;
   double            pipSize;

                     CSymbolTFCache() { bars = 0; start_bar = 0; pipSize = 0.0; }

   bool              Load(string sym, ENUM_TIMEFRAMES t, int maxLookback)
     {
      symbol = sym;
      tf     = t;

      datetime temp_time[];
      CopyTime(sym, t, 0, 1, temp_time);

      int rates_total = Bars(sym, t);
      if(rates_total <= 0)
         return false;

      if(rates_total < maxLookback)
        {
         CopyTime(sym, t, 0, maxLookback, temp_time);
         rates_total = Bars(sym, t);

         if(rates_total < maxLookback)
           {
            PrintFormat("⏳ Synchronizing history for %s %s... (Available: %d, Requested: %d)",
                        sym, EnumToString(t), rates_total, maxLookback);
            return false;
           }
        }

      start_bar    = MathMax(0, rates_total - maxLookback);
      int to_copy  = rates_total - start_bar;

      int copied = CopyTime(sym, t, 0, to_copy, time);
      if(copied < to_copy)
         return false;

      if(CopyOpen(sym, t, 0, copied, open)  < copied)
         return false;
      if(CopyHigh(sym, t, 0, copied, high)  < copied)
         return false;
      if(CopyLow(sym, t, 0, copied, low)   < copied)
         return false;
      if(CopyClose(sym, t, 0, copied, close) < copied)
         return false;
      if(CopyTickVolume(sym, t, 0, copied, vol) < copied)
         return false;

      bars = copied;

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

      return true;
     }
  };

// =========================================================================
// LAYER 2 — SINGLE COMBO EVALUATOR (Optimized Chronological Engine)
// =========================================================================
class CBestestInstance
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   double            m_deviation;
   int               m_depth;

   bool              m_draw;
   color             m_cSucc, m_cFail;
   bool              m_drwDem, m_drwSup, m_drwBullP, m_drwBearP, m_drwBullO, m_drwBearO;

   ZigZag*            zigZag;
   CMarketStructure*  ms;
   CDemandSupplyLogic* dsLogic;
   CSwingPOILogic*    spLogic;
   COrderBlockLogic*  obLogic;
   CFlipZoneLogic*    fzLogic;
   CBreakerBlockLogic* bbLogic;

   int               EvaluateZoneLite(CSymbolTFCache* cache, bool isBullish, double zHigh, double zLow, datetime zTime, double pipSize)
     {
      int rates_total = cache.bars;
      int startIdx = -1;

      for(int i = 0; i < rates_total; i++)
        {
         if(cache.time[i] == zTime)
           {
            startIdx = i;
            break;
           }
        }

      if(startIdx == -1)
         return 0;

      bool hasLeftZone = false;
      int touchIdx = -1;

      for(int i = startIdx + 1; i < rates_total; i++)
        {
         if(isBullish)
           {
            if(!hasLeftZone && cache.close[i] > zHigh)
               hasLeftZone = true;

            if(hasLeftZone && cache.low[i] <= zHigh)
              {
               int pivotCount = 0;
               for(int p = 0; p < zigZag.pivots.Total(); p++)
                 {
                  Pivot* pv = (Pivot*)zigZag.pivots.At(p);
                  if(pv.end.time > zTime && pv.end.time < cache.time[i])
                     pivotCount++;
                 }
               if(pivotCount >= 1)
                 {
                  touchIdx = i;
                  break;
                 }
              }
           }
         else
           {
            if(!hasLeftZone && cache.close[i] < zLow)
               hasLeftZone = true;

            if(hasLeftZone && cache.high[i] >= zLow)
              {
               int pivotCount = 0;
               for(int p = 0; p < zigZag.pivots.Total(); p++)
                 {
                  Pivot* pv = (Pivot*)zigZag.pivots.At(p);
                  if(pv.end.time > zTime && pv.end.time < cache.time[i])
                     pivotCount++;
                 }
               if(pivotCount >= 1)
                 {
                  touchIdx = i;
                  break;
                 }
              }
           }
        }

      if(touchIdx == -1)
         return 0;

      double m1_entry = 0.0, m1_sl = 0.0, m1_tp = 0.0;
      datetime m1_touchTime = 0;
    return CEntryModel::EvaluateM1ConfirmedBacktest(cache.symbol, isBullish, cache.time[touchIdx], zHigh, zLow, pipSize, m1_entry, m1_sl, m1_tp, m1_touchTime, cache.tf);

       }
public:
   BacktestMetricsLite   metrics;

                     CBestestInstance(string sym, ENUM_TIMEFRAMES tfVal, double devVal, int depVal, int maxLB,
                    bool drawVal, color cS, color cF,
                    bool dD, bool dS, bool dBP, bool dBrP, bool dBO, bool dBrO)
     {
      m_symbol    = sym;
      m_tf        = tfVal;
      m_deviation = devVal;
      m_depth     = depVal;
      m_draw      = drawVal;
      m_cSucc     = cS;
      m_cFail     = cF;
      m_drwDem    = dD;
      m_drwSup    = dS;
      m_drwBullP  = dBP;
      m_drwBearP  = dBrP;
      m_drwBullO  = dBO;
      m_drwBearO  = dBrO;

      zigZag  = NULL;
      ms      = NULL;
      dsLogic = NULL;
      spLogic = NULL;
      obLogic = NULL;
      fzLogic = NULL;
      bbLogic = NULL;

      metrics.Init();
     }

                    ~CBestestInstance()
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

   bool              RunBacktest()
     {
      CSymbolTFCache tmp;
      if(!tmp.Load(m_symbol, m_tf, 10000))
         return false;
      return RunBacktestFromCache(&tmp, false, false, false, false, false, false, false, false, false, false);
     }

   bool              RunBacktestFromCache(CSymbolTFCache* cache,
                                          bool skipDem, bool skipSup,
                                          bool skipBP, bool skipBrP,
                                          bool skipBO, bool skipBrO,
                                          bool skipDemFlip, bool skipSupFlip,
                                          bool skipBullBB, bool skipBearBB)
     {
      int to_copy = cache.bars;
      if(to_copy < m_depth * 2)
         return true;

      // Reset dynamic allocations on optimization sweeps to release heap fragmentation safely
      if(CheckPointer(zigZag) == POINTER_DYNAMIC)
        {
         delete zigZag;
         zigZag = NULL;
        }
      if(CheckPointer(ms) == POINTER_DYNAMIC)
        {
         delete ms;
         ms = NULL;
        }
      if(CheckPointer(dsLogic) == POINTER_DYNAMIC)
        {
         delete dsLogic;
         dsLogic = NULL;
        }
      if(CheckPointer(spLogic) == POINTER_DYNAMIC)
        {
         delete spLogic;
         spLogic = NULL;
        }
      if(CheckPointer(obLogic) == POINTER_DYNAMIC)
        {
         delete obLogic;
         obLogic = NULL;
        }
      if(CheckPointer(fzLogic) == POINTER_DYNAMIC)
        {
         delete fzLogic;
         fzLogic = NULL;
        }
      if(CheckPointer(bbLogic) == POINTER_DYNAMIC)
        {
         delete bbLogic;
         bbLogic = NULL;
        }

      Settings* s = new Settings(m_deviation, m_depth, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      zigZag  = newInstance(s);

      ms      = new CMarketStructure();
      ms.Init(false, false);
      dsLogic = new CDemandSupplyLogic();
      spLogic = new CSwingPOILogic();
      obLogic = new COrderBlockLogic();
      fzLogic = new CFlipZoneLogic();
      bbLogic = new CBreakerBlockLogic();

      metrics.Init();

      // Main chronological simulation loop
      for(int i = 0; i < to_copy; i++)
        {
         bool is_last   = (i == to_copy - 1);
         int  bar_index = cache.start_bar + i;

         zigZag.update(cache.high[i], cache.low[i], cache.time[i], cache.vol[i], bar_index, !is_last, is_last);
         ms.Update(i, cache.time, cache.high, cache.low, cache.close, zigZag);

         if(!skipDem || !skipSup)
            dsLogic.DetectPOIs(i, cache.time, cache.high, cache.low, zigZag);
         if(!skipBP || !skipBrP)
            spLogic.DetectPOIs(i, cache.time, cache.high, cache.low, zigZag);
         if(!skipBO || !skipBrO)
            obLogic.DetectPOIs(i, cache.time, cache.high, cache.low, zigZag);

         // Dynamically build history for Flip Zones
         if(!skipDemFlip || !skipSupFlip)
            fzLogic.DetectFlipZones(i, cache.time, cache.high, cache.low, cache.close, zigZag, ms, dsLogic);

         // Process Breakers
         if(!skipBullBB || !skipBearBB)
            bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);

         if(!skipBO && obLogic.poi_demandTime.Total() > 0)
           {
            datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
            if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz))
               if(obLogic.CheckBullishOB(tz, i, cache.time, cache.high, cache.low))
                  obLogic.ob_bull_valid_times.Add((long)tz);
           }
         if(!skipBrO && obLogic.poi_supplyTime.Total() > 0)
           {
            datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
            if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz))
               if(obLogic.CheckBearishOB(tz, i, cache.time, cache.high, cache.low))
                  obLogic.ob_bear_valid_times.Add((long)tz);
           }
        }

      double pipSize = cache.pipSize;

      // --- Post-run evaluation loops ---
      if(!skipDem)
        {
         for(int i = 0; i < dsLogic.poi_demandTime.Total(); i++)
           {
            int res = EvaluateZoneLite(cache, true, dsLogic.poi_demandZoneHigh.At(i), dsLogic.poi_demandZoneLow.At(i), (datetime)dsLogic.poi_demandTime.At(i), pipSize);
            if(res == 1)
               metrics.demand.RecordSuccess();
            else
               if(res == -1)
                  metrics.demand.RecordFail();
               else
                  metrics.demand.RecordPending();
           }
        }
      if(!skipSup)
        {
         for(int i = 0; i < dsLogic.poi_supplyTime.Total(); i++)
           {
            int res = EvaluateZoneLite(cache, false, dsLogic.poi_supplyZoneHigh.At(i), dsLogic.poi_supplyZoneLow.At(i), (datetime)dsLogic.poi_supplyTime.At(i), pipSize);
            if(res == 1)
               metrics.supply.RecordSuccess();
            else
               if(res == -1)
                  metrics.supply.RecordFail();
               else
                  metrics.supply.RecordPending();
           }
        }
      if(!skipBP)
        {
         for(int i = 0; i < spLogic.poi_demandTime.Total(); i++)
           {
            datetime zTime = (datetime)spLogic.poi_demandTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bull_struct_times, zTime))
              {
               int res = EvaluateZoneLite(cache, true, spLogic.poi_demandZoneHigh.At(i), spLogic.poi_demandZoneLow.At(i), zTime, pipSize);
               if(res == 1)
                  metrics.bullPOI.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bullPOI.RecordFail();
                  else
                     metrics.bullPOI.RecordPending();
              }
           }
        }
      if(!skipBrP)
        {
         for(int i = 0; i < spLogic.poi_supplyTime.Total(); i++)
           {
            datetime zTime = (datetime)spLogic.poi_supplyTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bear_struct_times, zTime))
              {
               int res = EvaluateZoneLite(cache, false, spLogic.poi_supplyZoneHigh.At(i), spLogic.poi_supplyZoneLow.At(i), zTime, pipSize);
               if(res == 1)
                  metrics.bearPOI.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bearPOI.RecordFail();
                  else
                     metrics.bearPOI.RecordPending();
              }
           }
        }
      if(!skipBO)
        {
         for(int i = 0; i < obLogic.poi_demandTime.Total(); i++)
           {
            datetime zTime = (datetime)obLogic.poi_demandTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bull_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, zTime))
              {
               int res = EvaluateZoneLite(cache, true, obLogic.poi_demandZoneHigh.At(i), obLogic.poi_demandZoneLow.At(i), zTime, pipSize);
               if(res == 1)
                  metrics.bullOB.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bullOB.RecordFail();
                  else
                     metrics.bullOB.RecordPending();
              }
           }
        }
      if(!skipBrO)
        {
         for(int i = 0; i < obLogic.poi_supplyTime.Total(); i++)
           {
            datetime zTime = (datetime)obLogic.poi_supplyTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bear_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, zTime))
              {
               int res = EvaluateZoneLite(cache, false, obLogic.poi_supplyZoneHigh.At(i), obLogic.poi_supplyZoneLow.At(i), zTime, pipSize);
               if(res == 1)
                  metrics.bearOB.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bearOB.RecordFail();
                  else
                     metrics.bearOB.RecordPending();
              }
           }
        }

      // --- Evaluate Demand Flip Zones ---
      if(!skipDemFlip)
        {
         for(int i = 0; i < fzLogic.fz_time.Total(); i++)
           {
            if(fzLogic.fz_type.At(i) == 1)
              {
               int res = EvaluateZoneLite(cache, true, fzLogic.fz_zoneHigh.At(i), fzLogic.fz_zoneLow.At(i), (datetime)fzLogic.fz_time.At(i), pipSize);
               if(res == 1)
                  metrics.demandFlip.RecordSuccess();
               else
                  if(res == -1)
                     metrics.demandFlip.RecordFail();
                  else
                     metrics.demandFlip.RecordPending();
              }
           }
        }
      // --- Evaluate Supply Flip Zones ---
      if(!skipSupFlip)
        {
         for(int i = 0; i < fzLogic.fz_time.Total(); i++)
           {
            if(fzLogic.fz_type.At(i) == -1)
              {
               int res = EvaluateZoneLite(cache, false, fzLogic.fz_zoneHigh.At(i), fzLogic.fz_zoneLow.At(i), (datetime)fzLogic.fz_time.At(i), pipSize);
               if(res == 1)
                  metrics.supplyFlip.RecordSuccess();
               else
                  if(res == -1)
                     metrics.supplyFlip.RecordFail();
                  else
                     metrics.supplyFlip.RecordPending();
              }
           }
        }

      // --- Evaluate Bullish Breaker Zones ---
      if(!skipBullBB)
        {
         for(int i = 0; i < bbLogic.bb_time.Total(); i++)
           {
            if(bbLogic.bb_type.At(i) == 1)
              {
               int res = EvaluateZoneLite(cache, true, bbLogic.bb_zoneHigh.At(i), bbLogic.bb_zoneLow.At(i), (datetime)bbLogic.bb_time.At(i), pipSize);
               if(res == 1)
                  metrics.bullBreaker.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bullBreaker.RecordFail();
                  else
                     metrics.bullBreaker.RecordPending();
              }
           }
        }
      // --- Evaluate Bearish Breaker Zones ---
      if(!skipBearBB)
        {
         for(int i = 0; i < bbLogic.bb_time.Total(); i++)
           {
            if(bbLogic.bb_type.At(i) == -1)
              {
               int res = EvaluateZoneLite(cache, false, bbLogic.bb_zoneHigh.At(i), bbLogic.bb_zoneLow.At(i), (datetime)bbLogic.bb_time.At(i), pipSize);
               if(res == 1)
                  metrics.bearBreaker.RecordSuccess();
               else
                  if(res == -1)
                     metrics.bearBreaker.RecordFail();
                  else
                     metrics.bearBreaker.RecordPending();
              }
           }
        }

      return true;
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\bestest.mqh

// END FILE: Include\Custom\ZigZag\bestest.mqh
