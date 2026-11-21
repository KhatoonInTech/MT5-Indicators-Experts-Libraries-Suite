//+------------------------------------------------------------------+
//|                               Include\Custom\ZigZag\order_blocks.mqh    |
//|                 Order Blocks 6-Step Validation Engine            |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.01"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class COrderBlockLogic
  {
public:
   datetime          poi_last_pivot_time;

   CArrayLong        poi_demandTime;
   CArrayDouble      poi_demandZoneLow;
   CArrayDouble      poi_demandZoneHigh;
   CArrayInt         poi_demandMitigated;

   CArrayLong        poi_supplyTime;
   CArrayDouble      poi_supplyZoneLow;
   CArrayDouble      poi_supplyZoneHigh;
   CArrayInt         poi_supplyMitigated;

   CArrayLong        ob_bull_valid_times;
   CArrayLong        ob_bear_valid_times;

                     COrderBlockLogic() { poi_last_pivot_time = 0; }

   void              ResetState()
     {
      poi_last_pivot_time = 0;
      poi_demandTime.Clear();
      poi_demandZoneLow.Clear();
      poi_demandZoneHigh.Clear();
      poi_demandMitigated.Clear();
      poi_supplyTime.Clear();
      poi_supplyZoneLow.Clear();
      poi_supplyZoneHigh.Clear();
      poi_supplyMitigated.Clear();
      ob_bull_valid_times.Clear();
      ob_bear_valid_times.Clear();
     }

   bool              ob_time_found(CArrayLong* arr, datetime t)
     {
      for(int j=0; j<arr.Total(); j++)
         if((datetime)arr.At(j) == t)
            return true;
      return false;
     }

   void              DetectPOIs(int i, const datetime &time[], const double &high[], const double &low[], ZigZag* zigZag)
     {
      if(zigZag.pivots.Total() >= 2)
        {
         Pivot* zp = (Pivot*)zigZag.pivots.At(zigZag.pivots.Total() - 2);
         if(zp.end.time < zigZag.zoneStartTime) return;
         if(poi_last_pivot_time == 0 || zp.end.time != poi_last_pivot_time)
           {
            poi_last_pivot_time = zp.end.time;

            double zc_high = EMPTY_VALUE;
            double zc_low = EMPTY_VALUE;
            int lookback = (int)MathMin(i, 500);
            for(int k = 0; k <= lookback; k++)
              {
               int j = i - k;
               if(time[j] == zp.end.time)
                 {
                  zc_high = high[j];
                  zc_low = low[j];
                  break;
                 }
               if(time[j] < zp.end.time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               if(!zp.isHigh)
                 {
                  poi_demandTime.Add((long)zp.end.time);
                  poi_demandZoneLow.Add(zc_low);
                  poi_demandZoneHigh.Add(zc_high);
                  poi_demandMitigated.Add(0);
                 }
               else
                 {
                  poi_supplyTime.Add((long)zp.end.time);
                  poi_supplyZoneLow.Add(zc_low);
                  poi_supplyZoneHigh.Add(zc_high);
                  poi_supplyMitigated.Add(0);
                 }
              }
           }
        }
     }

   void              UpdateMitigation(double close_i)
     {
      for(int m = 0; m < poi_demandMitigated.Total(); m++)
        {
         if(poi_demandMitigated.At(m) == 0 && close_i < poi_demandZoneLow.At(m))
           {
            poi_demandMitigated.Update(m, 1);
           }
        }
      for(int m = 0; m < poi_supplyMitigated.Total(); m++)
        {
         if(poi_supplyMitigated.At(m) == 0 && close_i > poi_supplyZoneHigh.At(m))
           {
            poi_supplyMitigated.Update(m, 1);
           }
        }
     }

   bool              CheckBullishOB(datetime pivot_time, int current_i, const datetime &time[], const double &high[], const double &low[])
     {
      double ob_pc_high = EMPTY_VALUE, ob_pc_low = EMPTY_VALUE;
      double ob_pm1_high = EMPTY_VALUE, ob_pm1_low = EMPTY_VALUE;
      double ob_pp1_high = EMPTY_VALUE, ob_pp1_low = EMPTY_VALUE;
      double ob_pp2_high = EMPTY_VALUE, ob_pp2_low = EMPTY_VALUE;

      for(int j = current_i; j >= 0; j--)
        {
         if(time[j] == pivot_time)
           {
            ob_pc_high = high[j];
            ob_pc_low = low[j];
            if(j - 1 >= 0)
              {
               ob_pm1_high = high[j - 1];
               ob_pm1_low = low[j - 1];
              }
            if(j + 1 <= current_i)
              {
               ob_pp1_high = high[j + 1];
               ob_pp1_low = low[j + 1];
              }
            if(j + 2 <= current_i)
              {
               ob_pp2_high = high[j + 2];
               ob_pp2_low = low[j + 2];
              }
            break;
           }
         if(time[j] < pivot_time)
            break;
        }

      if(ob_pc_high == EMPTY_VALUE || ob_pm1_high == EMPTY_VALUE || ob_pp1_high == EMPTY_VALUE || ob_pp2_high == EMPTY_VALUE)
         return false;
      return (ob_pc_low < ob_pm1_low && ob_pc_low < ob_pp1_low && ob_pc_high < ob_pp1_high && ob_pp1_high < ob_pp2_high && ob_pc_high < ob_pp2_low);
     }

   bool              CheckBearishOB(datetime pivot_time, int current_i, const datetime &time[], const double &high[], const double &low[])
     {
      double ob_pc_high = EMPTY_VALUE, ob_pc_low = EMPTY_VALUE;
      double ob_pm1_high = EMPTY_VALUE, ob_pm1_low = EMPTY_VALUE;
      double ob_pp1_high = EMPTY_VALUE, ob_pp1_low = EMPTY_VALUE;
      double ob_pp2_high = EMPTY_VALUE, ob_pp2_low = EMPTY_VALUE;

      for(int j = current_i; j >= 0; j--)
        {
         if(time[j] == pivot_time)
           {
            ob_pc_high = high[j];
            ob_pc_low = low[j];
            if(j - 1 >= 0)
              {
               ob_pm1_high = high[j - 1];
               ob_pm1_low = low[j - 1];
              }
            if(j + 1 <= current_i)
              {
               ob_pp1_high = high[j + 1];
               ob_pp1_low = low[j + 1];
              }
            if(j + 2 <= current_i)
              {
               ob_pp2_high = high[j + 2];
               ob_pp2_low = low[j + 2];
              }
            break;
           }
         if(time[j] < pivot_time)
            break;
        }

      if(ob_pc_high == EMPTY_VALUE || ob_pm1_high == EMPTY_VALUE || ob_pp1_high == EMPTY_VALUE || ob_pp2_high == EMPTY_VALUE)
         return false;
      return (ob_pc_high > ob_pm1_high && ob_pc_high > ob_pp1_high && ob_pc_low > ob_pp1_low && ob_pp1_low > ob_pp2_low && ob_pc_low > ob_pp2_high);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMarketMetrics* GetOrderBlockZoneMetrics(COrderBlockLogic* logic, bool isDemand, int index)
  {
   CMarketMetrics* metrics = new CMarketMetrics();
   datetime currentTime = TimeCurrent();
   if(isDemand && logic != NULL && index >= 0 && index < logic.poi_demandTime.Total())
     {
      metrics.zoneLow = logic.poi_demandZoneLow.At(index);
      metrics.zoneHigh = logic.poi_demandZoneHigh.At(index);
      metrics.isMitigated = (logic.poi_demandMitigated.At(index) == 1);
      metrics.zoneAgeSeconds = (long)(currentTime - (datetime)logic.poi_demandTime.At(index));
     }
   else
      if(!isDemand && logic != NULL && index >= 0 && index < logic.poi_supplyTime.Total())
        {
         metrics.zoneLow = logic.poi_supplyZoneLow.At(index);
         metrics.zoneHigh = logic.poi_supplyZoneHigh.At(index);
         metrics.isMitigated = (logic.poi_supplyMitigated.At(index) == 1);
         metrics.zoneAgeSeconds = (long)(currentTime - (datetime)logic.poi_supplyTime.At(index));
        }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\order_blocks.mqh

// END FILE: Include\Custom\ZigZag\order_blocks.mqh
