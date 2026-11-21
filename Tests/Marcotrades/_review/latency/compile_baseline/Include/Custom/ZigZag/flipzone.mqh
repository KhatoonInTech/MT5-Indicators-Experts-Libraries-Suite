//+------------------------------------------------------------------+
//|                                   Include\Custom\ZigZag\flipzone.mqh    |
//|                 Demand & Supply Flip Zone Engine                 |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.01"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>

// =============================================================================
// FLIP ZONE DECOUPLED LOGIC CLASS
// =============================================================================
class CFlipZoneLogic
  {
public:
   datetime          fz_last_breakout_time;

   CArrayLong        fz_time;
   CArrayDouble      fz_zoneLow;
   CArrayDouble      fz_zoneHigh;
   CArrayInt         fz_type;       // 1 = Demand Flip (Long), -1 = Supply Flip (Short)
   CArrayInt         fz_mitigated;  // 0 = Fresh, 1 = Mitigated

                     CFlipZoneLogic() { fz_last_breakout_time = 0; }

   void              ResetState()
     {
      fz_last_breakout_time = 0;
      fz_time.Clear();
      fz_zoneLow.Clear();
      fz_zoneHigh.Clear();
      fz_type.Clear();
      fz_mitigated.Clear();
     }

   // --- MAIN LOGIC CALCULATOR (Mirrors Pine Script exact logic) ---
   void              DetectFlipZones(int current_i, const datetime &time[], const double &high[], const double &low[], const double &close[], ZigZag* zigZag, CMarketStructure* ms, CDemandSupplyLogic* dsLogic)
     {
      if(time[current_i] < zigZag.zoneStartTime || ms.last_breakout_time < zigZag.zoneStartTime) return;
      // TRIGGER: Only process when a fresh Market Shift (BOS or CHoCH) occurs [2593]
      if(ms.last_breakout_time <= fz_last_breakout_time || ms.last_breakout_time == 0)
         return;

      bool found_flip = false;
      double zc_high = EMPTY_VALUE;
      double zc_low  = EMPTY_VALUE;
      int type_val = 0;
      long p_time = 0;

      // -----------------------------------------------------------------------
      // CASE A: DEMAND FLIP ZONE (Bearish to Bullish Market Shift) [2593]
      // -----------------------------------------------------------------------
      if(ms.trend == 1)
        {
         Pivot* last_low_p = NULL;
         int sz = zigZag.pivots.Total();
         if(sz > 0)
           {
            // Loop backward from the end of the pivots array to find the last low pivot [2593]
            for(int k = sz - 1; k >= 0; k--)
              {
               Pivot* p = (Pivot*)zigZag.pivots.At(k);
               if(p != NULL && !p.isHigh && StringFind(p.ln, "ZZ_Proj") < 0)
                 {
                  last_low_p = p;
                  break;
                 }
              }
           }

         if(last_low_p != NULL)
           {
            // Scan backward in history to find the exact bar matching the pivot's end time
            int lookback = (int)MathMin(current_i, 500);
            for(int j = 0; j <= lookback; j++)
              {
               int idx = current_i - j;
               if(time[idx] == last_low_p.end.time)
                 {
                  zc_high = high[idx];
                  zc_low  = low[idx];
                  break;
                 }
               if(time[idx] < last_low_p.end.time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               found_flip = true;
               type_val = 1; // Demand Flip (Long Zone)
               p_time = last_low_p.end.time;
              }
           }
        }
      // -----------------------------------------------------------------------
      // CASE B: SUPPLY FLIP ZONE (Bullish to Bearish Market Shift) [2593]
      // -----------------------------------------------------------------------
      else
         if(ms.trend == -1)
           {
            Pivot* last_high_p = NULL;
            int sz = zigZag.pivots.Total();
            if(sz > 0)
              {
               // Loop backward from the end of the pivots array to find the last high pivot [2593]
               for(int k = sz - 1; k >= 0; k--)
                 {
                  Pivot* p = (Pivot*)zigZag.pivots.At(k);
                  if(p != NULL && p.isHigh && StringFind(p.ln, "ZZ_Proj") < 0)
                    {
                     last_high_p = p;
                     break;
                    }
                 }
              }

            if(last_high_p != NULL)
              {
               // Scan backward in history to find the exact bar matching the pivot's end time
               int lookback = (int)MathMin(current_i, 500);
               for(int j = 0; j <= lookback; j++)
                 {
                  int idx = current_i - j;
                  if(time[idx] == last_high_p.end.time)
                    {
                     zc_high = high[idx];
                     zc_low  = low[idx];
                     break;
                    }
                  if(time[idx] < last_high_p.end.time)
                     break;
                 }

               if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
                 {
                  found_flip = true;
                  type_val = -1; // Supply Flip (Short Zone)
                  p_time = last_high_p.end.time;
                 }
              }
           }

      if(found_flip && p_time >= zigZag.zoneStartTime)
        {
         fz_time.Add((long)p_time);
         fz_zoneLow.Add(zc_low);
         fz_zoneHigh.Add(zc_high);
         fz_type.Add(type_val);
         fz_mitigated.Add(0);

         // Lock current breakout sequence to prevent double-logging
         fz_last_breakout_time = ms.last_breakout_time;
        }
     }

   // --- MITIGATION CHECKER ---
   void              UpdateMitigation(double close_i)
     {
      for(int m = 0; m < fz_mitigated.Total(); m++)
        {
         if(fz_mitigated.At(m) == 0)
           {
            if(fz_type.At(m) == 1) // Demand Flip (Long)
              {
               // Mitigated if price closes below the bottom of the flip zone [2593]
               if(close_i < fz_zoneLow.At(m))
                  fz_mitigated.Update(m, 1);
              }
            else
               if(fz_type.At(m) == -1) // Supply Flip (Short)
                 {
                  // Mitigated if price closes above the top of the flip zone [2593]
                  if(close_i > fz_zoneHigh.At(m))
                     fz_mitigated.Update(m, 1);
                 }
           }
        }
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\flipzone.mqh

// END FILE: Include\Custom\ZigZag\flipzone.mqh
