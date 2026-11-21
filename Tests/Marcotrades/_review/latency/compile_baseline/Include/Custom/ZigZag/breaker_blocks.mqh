//+------------------------------------------------------------------+
//|                                Include\Custom\Custom\ZigZag\breaker_blocks.mqh |
//|                     SMC Breaker Block Calculation Engine         |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.00"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>

// =============================================================================
// BREAKER BLOCK ENGINE LOGIC CLASS
// =============================================================================
class CBreakerBlockLogic
  {
public:
   CArrayLong        processed_failed_bull_times;
   CArrayLong        processed_failed_bear_times;

   CArrayLong        bb_time;
   CArrayDouble      bb_zoneLow;
   CArrayDouble      bb_zoneHigh;
   CArrayInt         bb_type;       // 1 = Bullish Breaker (Long), -1 = Bearish Breaker (Short)
   CArrayInt         bb_mitigated;  // 0 = Fresh, 1 = Mitigated
   CArrayLong        bb_mitigation_time; // Stores bar time of mitigation (0 if fresh)

                     CBreakerBlockLogic() {}

   void              ResetState()
     {
      processed_failed_bull_times.Clear();
      processed_failed_bear_times.Clear();
      bb_time.Clear();
      bb_zoneLow.Clear();
      bb_zoneHigh.Clear();
      bb_type.Clear();
      bb_mitigated.Clear();
      bb_mitigation_time.Clear();
     }

   // --- MAIN CALCULATION MODULE ---
   void              DetectBreakers(ZigZag* zigZag, CDemandSupplyLogic* dsLogic, CSwingPOILogic* spLogic, COrderBlockLogic* obLogic, CFlipZoneLogic* fzLogic)
     {
      if(zigZag == NULL || zigZag.pivots.Total() < 2)
         return;

      int sz = zigZag.pivots.Total();
      // Inspect the last 2 confirmed pivots (excluding any active updating projection)
      int start_idx = MathMax(0, sz - 3);
      int end_idx = sz - 2;

      for(int idx = start_idx; idx <= end_idx; idx++)
        {
         Pivot* p = (Pivot*)zigZag.pivots.At(idx);
         if(p == NULL || (zigZag.projection != NULL && p == zigZag.projection))
            continue;

         datetime p_time = p.end.time;
         double p_price = p.end.price;

         if(p.isHigh) // High Pivot breaks Bearish zones -> creates a Bullish Breaker Block
           {
            // 1. Check Supply Zones
            if(dsLogic != NULL)
              {
               for(int i = 0; i < dsLogic.poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)dsLogic.poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = dsLogic.poi_supplyZoneHigh.At(i);
                     double zLow  = dsLogic.poi_supplyZoneLow.At(i);
                     if(p_price > zHigh)
                       {
                        processed_failed_bear_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(1); // Bullish Breaker
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 2. Check Bearish Swing POIs
            if(spLogic != NULL)
              {
               for(int i = 0; i < spLogic.poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)spLogic.poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = spLogic.poi_supplyZoneHigh.At(i);
                     double zLow  = spLogic.poi_supplyZoneLow.At(i);
                     if(p_price > zHigh)
                       {
                        processed_failed_bear_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(1);
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 3. Check Bearish OBs
            if(obLogic != NULL)
              {
               for(int i = 0; i < obLogic.poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)obLogic.poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = obLogic.poi_supplyZoneHigh.At(i);
                     double zLow  = obLogic.poi_supplyZoneLow.At(i);
                     if(p_price > zHigh)
                       {
                        processed_failed_bear_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(1);
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 4. Check Supply Flip Zones
            if(fzLogic != NULL)
              {
               for(int i = 0; i < fzLogic.fz_time.Total(); i++)
                 {
                  if(fzLogic.fz_type.At(i) == -1) // Supply Flip
                    {
                     datetime zTime = (datetime)fzLogic.fz_time.At(i);
                     if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                       {
                        double zHigh = fzLogic.fz_zoneHigh.At(i);
                        double zLow  = fzLogic.fz_zoneLow.At(i);
                        if(p_price > zHigh)
                          {
                           processed_failed_bear_times.Add((long)zTime);
                           bb_time.Add((long)zTime);
                           bb_zoneLow.Add(zLow);
                           bb_zoneHigh.Add(zHigh);
                           bb_type.Add(1);
                           bb_mitigated.Add(0);
                           bb_mitigation_time.Add(0);
                          }
                       }
                    }
                 }
              }
           }
         else // Low Pivot breaks Bullish zones -> creates a Bearish Breaker Block
           {
            // 1. Check Demand Zones
            if(dsLogic != NULL)
              {
               for(int i = 0; i < dsLogic.poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)dsLogic.poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = dsLogic.poi_demandZoneHigh.At(i);
                     double zLow  = dsLogic.poi_demandZoneLow.At(i);
                     if(p_price < zLow)
                       {
                        processed_failed_bull_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(-1); // Bearish Breaker
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 2. Check Bullish Swing POIs
            if(spLogic != NULL)
              {
               for(int i = 0; i < spLogic.poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)spLogic.poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = spLogic.poi_demandZoneHigh.At(i);
                     double zLow  = spLogic.poi_demandZoneLow.At(i);
                     if(p_price < zLow)
                       {
                        processed_failed_bull_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(-1);
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 3. Check Bullish OBs
            if(obLogic != NULL)
              {
               for(int i = 0; i < obLogic.poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)obLogic.poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = obLogic.poi_demandZoneHigh.At(i);
                     double zLow  = obLogic.poi_demandZoneLow.At(i);
                     if(p_price < zLow)
                       {
                        processed_failed_bull_times.Add((long)zTime);
                        bb_time.Add((long)zTime);
                        bb_zoneLow.Add(zLow);
                        bb_zoneHigh.Add(zHigh);
                        bb_type.Add(-1);
                        bb_mitigated.Add(0);
                        bb_mitigation_time.Add(0);
                       }
                    }
                 }
              }
            // 4. Check Demand Flip Zones
            if(fzLogic != NULL)
              {
               for(int i = 0; i < fzLogic.fz_time.Total(); i++)
                 {
                  if(fzLogic.fz_type.At(i) == 1) // Demand Flip
                    {
                     datetime zTime = (datetime)fzLogic.fz_time.At(i);
                     if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                       {
                        double zHigh = fzLogic.fz_zoneHigh.At(i);
                        double zLow  = fzLogic.fz_zoneLow.At(i);
                        if(p_price < zLow)
                          {
                           processed_failed_bull_times.Add((long)zTime);
                           bb_time.Add((long)zTime);
                           bb_zoneLow.Add(zLow);
                           bb_zoneHigh.Add(zHigh);
                           bb_type.Add(-1);
                           bb_mitigated.Add(0);
                           bb_mitigation_time.Add(0);
                          }
                       }
                    }
                 }
              }
           }
        }
     }

   // --- CHRONOLOGICAL EXTREME MITIGATION MODULE ---
   void              UpdateMitigation(double high_val, double low_val, datetime current_time)
     {
      for(int m = 0; m < bb_mitigated.Total(); m++)
        {
         if(bb_mitigated.At(m) == 0)
           {
            if(bb_type.At(m) == 1) // Bullish Breaker
              {
               // Mitigated if the low of the price leg walks past the block low boundary
               if(low_val < bb_zoneLow.At(m))
                 {
                  bb_mitigated.Update(m, 1);
                  bb_mitigation_time.Update(m, (long)current_time);
                 }
              }
            else
               if(bb_type.At(m) == -1) // Bearish Breaker
                 {
                  // Mitigated if the high of the price leg walks past the block high boundary
                  if(high_val > bb_zoneHigh.At(m))
                    {
                     bb_mitigated.Update(m, 1);
                     bb_mitigation_time.Update(m, (long)current_time);
                    }
                 }
           }
        }
     }

private:
   bool              IsProcessed(CArrayLong &arr, datetime t)
     {
      for(int j = 0; j < arr.Total(); j++)
        {
         if(arr.At(j) == (long)t)
            return true;
        }
      return false;
     }
  };

//+------------------------------------------------------------------+
//| Helper Metric Allocator                                          |
//+------------------------------------------------------------------+
CMarketMetrics* GetBreakerBlockZoneMetrics(CBreakerBlockLogic* logic, int index)
  {
   CMarketMetrics* metrics = new CMarketMetrics();
   datetime currentTime = TimeCurrent();
   if(logic != NULL && index >= 0 && index < logic.bb_time.Total())
     {
      metrics.zoneLow = logic.bb_zoneLow.At(index);
      metrics.zoneHigh = logic.bb_zoneHigh.At(index);
      metrics.isMitigated = (logic.bb_mitigated.At(index) == 1);
      metrics.zoneAgeSeconds = (long)(currentTime - (datetime)logic.bb_time.At(index));
     }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\breaker_blocks.mqh

// END FILE: Include\Custom\ZigZag\breaker_blocks.mqh
