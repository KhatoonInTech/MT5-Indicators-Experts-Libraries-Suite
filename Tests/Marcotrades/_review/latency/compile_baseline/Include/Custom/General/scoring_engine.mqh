//+------------------------------------------------------------------+
//|                                  Include\Custom\General\scoring_engine.mqh.mqh |
//|                               SMC Setup Quality & Probability Engine|
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated / Custom Engine"
#property version   "1.01"

#ifndef SCORING_ENGINE_MQH
#define SCORING_ENGINE_MQH

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CScoringEngine
  {
public:

   //+------------------------------------------------------------------+
   //| Main Scoring Function (Out of 100 Points)                        |
   //+------------------------------------------------------------------+
   static int        EvaluateSetupQuality(
      string symbol,
      ENUM_TIMEFRAMES tf,
      bool isBullish,
      long zoneCreatedTime,
      int touches,
      ZigZag* zigZag,
      string &reasoning_append
   )
     {
      int total_score = 0;
      string reasons = "";

      // Fetch the recent 6 candles (Index 0 is the current touch candle)
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(symbol, tf, 0, 6, rates) < 6)
        {
         reasoning_append = "Not enough data for scoring.";
         return 50;
        }

      // =================================================================
      // POINT 1: Candle Momentum Before Touch (15 Points)
      // Look at the size of the 3-5 candles before the zone is touched.
      // =================================================================
      int lookback = 5;
      double likely_body = 0.0;
      double unlikely_body = 0.0;

      for(int j = 1; j <= lookback; j++)
        {
         double o = rates[j].open;
         double c = rates[j].close;
         double body = MathAbs(c - o);

         if(isBullish)   // Bullish Zone -> Green is likely, Red is unlikely
           {
            if(c > o)
               likely_body += body;
            else
               unlikely_body += body;
           }
         else            // Bearish Zone -> Red is likely, Green is unlikely
           {
            if(c < o)
               likely_body += body;
            else
               unlikely_body += body;
           }
        }

      double total_body = likely_body + unlikely_body;
      int pts_momentum = 0;
      if(total_body > 0)
        {
         double ratio = likely_body / total_body;
         pts_momentum = (int)(ratio * 15.0);
         total_score += pts_momentum;
         reasons += StringFormat("Candle Momentum: %d/15. ", pts_momentum);
        }
      else
        {
         reasons += "Candle Momentum: 0/15. ";
        }

      // =================================================================
      // POINTS 2 & 3: Trend & Structural BOS / CHoCH Sequences (25 Points)
      // =================================================================
      double H[10];
      int h_idx = 0;
      double L[10];
      int l_idx = 0;

      for(int j = zigZag.pivots.Total() - 1; j >= 0; j--)
        {
         Pivot* p = (Pivot*)zigZag.pivots.At(j);
         if(p.isHigh)
           {
            if(h_idx < 10)
               H[h_idx++] = p.end.price;
           }
         else
           {
            if(l_idx < 10)
               L[l_idx++] = p.end.price;
           }
         if(h_idx >= 10 && l_idx >= 10)
            break;
        }

      int struct_score = 0;
      if(isBullish)
        {
         int bull_bos = 0;
         for(int j = 0; j < h_idx - 1; j++)
           {
            if(H[j] > H[j+1])
               bull_bos++;
            else
               break;
           }

         bool pattern_b = false;
         if(h_idx >= 3 && l_idx >= 6)
           {
            if(H[0] > H[1] && H[1] > H[2])
              {
               if(L[2] < L[3] && L[3] < L[4] && L[4] < L[5])
                 {
                  pattern_b = true;
                 }
              }
           }

         if(pattern_b)
           {
            struct_score = 25;
            reasons += "Struct: 3 Bear BOS -> Bull CHoCH -> Bull BOS (25/25). ";
           }
         else
           {
            struct_score = (int)MathMin(25, bull_bos * 5);
            reasons += StringFormat("Struct: Consec Bull BOS x%d (%d/25). ", bull_bos, struct_score);
           }
        }
      else
        {
         int bear_bos = 0;
         for(int j = 0; j < l_idx - 1; j++)
           {
            if(L[j] < L[j+1])
               bear_bos++;
            else
               break;
           }

         bool pattern_b = false;
         if(l_idx >= 3 && h_idx >= 6)
           {
            if(L[0] < L[1] && L[1] < L[2])
              {
               if(H[2] > H[3] && H[3] > H[4] && H[4] > H[5])
                 {
                  pattern_b = true;
                 }
              }
           }

         if(pattern_b)
           {
            struct_score = 25;
            reasons += "Struct: 3 Bull BOS -> Bear CHoCH -> Bear BOS (25/25). ";
           }
         else
           {
            struct_score = (int)MathMin(25, bear_bos * 5);
            reasons += StringFormat("Struct: Consec Bear BOS x%d (%d/25). ", bear_bos, struct_score);
           }
        }
      total_score += struct_score;

      // =================================================================
      // POINT 4: Freshness of Zone (20 Points)
      // =================================================================
      int fresh_pts = 0;
      if(touches == 0)
         fresh_pts = 20;
      else
         if(touches == 1)
            fresh_pts = 10;
         else
            if(touches == 2)
               fresh_pts = 5;

      total_score += fresh_pts;
      reasons += StringFormat("Freshness: %d touches (%d/20). ", touches, fresh_pts);

      // =================================================================
      // POINT 5: Session Timing NY/London (15 Points)
      // =================================================================
      int broker_offset = (int)(TimeCurrent() - TimeGMT());
      datetime utc_t = rates[0].time - broker_offset;

      MqlDateTime dt;
      TimeToStruct(utc_t, dt);
      int h = dt.hour;

      int sess_pts = 0;
      string sess_name = "";

      if(h >= 12 && h < 18)
        {
         sess_pts = 15;
         sess_name = "NY+Lon Overlap";
        }
      else
         if(h >= 8 && h < 12)
           {
            sess_pts = 10;
            sess_name = "London Only";
           }
         else
            if(h >= 18 && h < 21)
              {
               sess_pts = 10;
               sess_name = "NY Only";
              }
            else
              {
               sess_pts = 0;
               sess_name = "Off-Session";
              }

      total_score += sess_pts;
      reasons += StringFormat("Session: %s (%d/15). ", sess_name, sess_pts);

      // =================================================================
      // POINT 6: Sweep, Displacement, & Cumulative Volume (25 Points)
      // =================================================================
      int k_zone = -1;
      for(int j = 0; j < zigZag.pivots.Total(); j++)
        {
         Pivot* p = (Pivot*)zigZag.pivots.At(j);
         if((long)p.end.time == zoneCreatedTime)
           {
            k_zone = j;
            break;
           }
        }

      int sdv_pts = 0;
      if(k_zone >= 0)
        {
         Pivot* P_zone = (Pivot*)zigZag.pivots.At(k_zone);
         Pivot* P_prev_same = (k_zone >= 2) ? (Pivot*)zigZag.pivots.At(k_zone - 2) : NULL;
         Pivot* P_next = (k_zone + 1 < zigZag.pivots.Total()) ? (Pivot*)zigZag.pivots.At(k_zone + 1) : NULL;

         double avg_disp = 0;
         double avg_vol = 0;
         int count = 0;
         for(int j = zigZag.pivots.Total() - 1; j >= 0 && count < 10; j--)
           {
            Pivot* p = (Pivot*)zigZag.pivots.At(j);
            avg_disp += MathAbs(p.end.price - p.start.price);
            avg_vol += p.vol;
            count++;
           }
         if(count > 0)
           {
            avg_disp /= count;
            avg_vol /= count;
           }

         bool sweep = false;
         double disp = 0;
         double vol = 0;

         if(isBullish)
           {
            if(P_prev_same != NULL && P_zone.end.price < P_prev_same.end.price)
               sweep = true;
           }
         else
           {
            if(P_prev_same != NULL && P_zone.end.price > P_prev_same.end.price)
               sweep = true;
           }

         if(P_next != NULL)
           {
            disp = MathAbs(P_next.end.price - P_zone.end.price);
            vol = P_next.vol;
           }
         else
           {
            disp = MathAbs(rates[0].close - P_zone.end.price);
            vol = rates[0].tick_volume;
           }

         if(sweep)
           {
            sdv_pts += 5;
            reasons += "Sweep: Yes (5). ";
           }
         else
           {
            reasons += "Sweep: No (0). ";
           }

         if(disp > avg_disp)
           {
            sdv_pts += 10;
            reasons += "Disp: High (10). ";
           }
         else
           {
            reasons += "Disp: Low (0). ";
           }

         if(vol > avg_vol)
           {
            sdv_pts += 10;
            reasons += "Vol: High (10). ";
           }
         else
           {
            reasons += "Vol: Low (0). ";
           }

        }
      else
        {
         reasons += "ZZ Context: Zone Pivot unavailable (0/25). ";
        }
      total_score += sdv_pts;

      reasoning_append = reasons;

      return (int)MathMax(0, MathMin(100, total_score));
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\scoring_engine.mqh

// END FILE: Include\Custom\General\scoring_engine.mqh
