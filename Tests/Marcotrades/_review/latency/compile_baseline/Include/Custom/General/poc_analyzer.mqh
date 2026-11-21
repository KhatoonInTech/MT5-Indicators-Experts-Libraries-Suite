//+------------------------------------------------------------------+
//|                                   Include\Custom\General\poc_analyzer.mqh|
//|                 Advanced 9-Point Confluence (PoC) Scoring Engine |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.25"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include <Arrays\ArrayString.mqh>
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"

struct PoCResult
  {
   int               finalScore;
   string            recommendation;
   string            reasoning;
   // Track individual PoC scores for advanced Backtest reporting
   int               p1_score;
   int               p2_score;
   int               p3_score;
   int               p4_score;
   int               p5_score;
   int               p6_score;
   int               p7_score;
   int               p8_score;
   int               p9_score;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPoCAnalyzer
  {
private:
   double            m_volThreshold;
   double            m_dispThreshold;

   double            GetBodySize(double open, double close)
     {
      return MathAbs(close - open);
     }

   // Convert broker server time to Pakistan Standard Time (GMT+5)
   datetime          ConvertBrokerToPKT(datetime brokerTime)
     {
      // Use TimeTradeServer instead of TimeCurrent to prevent frozen-tick drift
      int rawOffset = (int)(TimeTradeServer() - TimeGMT());

      // Round to the nearest 30 minutes to eliminate any temporary network latency or synchronization drift
      int brokerOffset = (int)MathRound((double)rawOffset / 1800.0) * 1800;

      // Fallback standard offset detection
      if(brokerOffset == 0 && TimeTradeServer() != TimeGMT())
        {
         brokerOffset = 2 * 3600;
        }

      datetime gmtTime = brokerTime - brokerOffset;
      datetime pktTime = gmtTime + 5 * 3600; // PKT is GMT+5

      // Print diagnostic time mapping to MT5 terminal journal
      MqlDateTime pkt_dt_check;
      TimeToStruct(pktTime, pkt_dt_check);
      int checkHM = pkt_dt_check.hour * 100 + pkt_dt_check.min;
      /* PrintFormat("🕒 SMC POC #5 Diagnostics — Broker Time: %s | Calculated PKT: %s | HourMin: %04d | Offset: %+d hrs",
                   TimeToString(brokerTime, TIME_DATE|TIME_MINUTES),
                   TimeToString(pktTime, TIME_DATE|TIME_MINUTES),
                   checkHM,
                   brokerOffset / 3600);
      */
      return pktTime;
     }

   int               EvaluateStructureSequence(ZigZag* zigZag, datetime targetTime, bool isBullish)
     {
      int breaks[];
      ArrayResize(breaks, 0);
      double hh = -1.0, ll = -1.0;

      for(int i = 0; i < zigZag.pivots.Total(); i++)
        {
         Pivot* p = (Pivot*)zigZag.pivots.At(i);
         if(p.end.time > targetTime)
            break;

         if(p.isHigh)
           {
            if(hh == -1.0 || p.end.price > hh)
              {
               hh = p.end.price;
               int s = ArraySize(breaks);
               ArrayResize(breaks, s + 1);
               breaks[s] = 1;
              }
           }
         else
           {
            if(ll == -1.0 || p.end.price < ll)
              {
               ll = p.end.price;
               int s = ArraySize(breaks);
               ArrayResize(breaks, s + 1);
               breaks[s] = -1;
              }
           }
        }

      int s = ArraySize(breaks);
      if(s < 5)
         return 0;

      int b1=breaks[s-5], b2=breaks[s-4], b3=breaks[s-3], b4=breaks[s-2], b5=breaks[s-1];

      if(isBullish)
        {
         if(b1==1 && b2==1 && b3==1 && b4==1 && b5==1)
            return 1;
         if(b1==-1 && b2==-1 && b3==-1 && b4==1 && b5==1)
            return 2;
        }
      else
        {
         if(b1==-1 && b2==-1 && b3==-1 && b4==-1 && b5==-1)
            return 1;
         if(b1==1 && b2==1 && b3==1 && b4==-1 && b5==-1)
            return 2;
        }
      return 0;
     }

public:
                     CPoCAnalyzer()
     {
      m_volThreshold = 1000;
      m_dispThreshold = 0.002;
     }

   PoCResult         EvaluateZone(bool isBullishZone, datetime zoneCreationTime, double zoneHigh, double zoneLow,
                                  int touch_index, const datetime &time[], const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  ZigZag* zigZag, CMarketStructure* ms,
                                  CDemandSupplyLogic* dsLogic, CSwingPOILogic* spLogic, COrderBlockLogic* obLogic,
                                  double livePrice, double pipSize,
                                  ENUM_TIMEFRAMES currentTF,
                                  string lonSession = "0800-1200", string nySession = "1200-1600")
     {
      PoCResult res;
      res.finalScore = 0;
      res.reasoning = "";

      int p1_score = 0, p2_score = 0, p3_score = 0, p4_score = 0, p5_score = 0, p6_score = 0, p7_score = 0, p8_score = 0, p9_score = 0;

      // ==========================================
      // PoC 1: Liquidity Sweep, Vol & Disp (Max 15)
      // ==========================================
      Pivot* originPivot = NULL;
      Pivot* prevSamePivot = NULL;
      int originIdx = -1;

      for(int p = zigZag.pivots.Total() - 1; p >= 0; p--)
        {
         Pivot* temp = (Pivot*)zigZag.pivots.At(p);
         if(temp.end.time == zoneCreationTime)
           {
            originPivot = temp;
            originIdx = p;
            break;
           }
        }
      if(originIdx >= 2)
         prevSamePivot = (Pivot*)zigZag.pivots.At(originIdx - 2);

      if(originPivot != NULL && prevSamePivot != NULL)
        {
         bool sweptLiquidity = isBullishZone ? (originPivot.end.price < prevSamePivot.end.price)
                               : (originPivot.end.price > prevSamePivot.end.price);

         double displacement = MathAbs(originPivot.end.price - originPivot.start.price);
         if(sweptLiquidity && originPivot.vol > m_volThreshold && displacement > m_dispThreshold)
           {
            p1_score = 15;
            res.reasoning += "- ✅ **Liquidity:** Swept + High Vol/Disp\\n\\n";
           }
         else
            if(sweptLiquidity)
              {
               p1_score = 8;
               res.reasoning += "- ☑️ **Liquidity:** Swept (Avg Vol)\\n\\n";
              }
            else
              {
               res.reasoning += "- ❌ **Liquidity:** No Sweep Detected\\n\\n";
              }
        }
      else
        {
         res.reasoning += "- ❌ **Liquidity:** Insufficient Historical Data\\n\\n";
        }

      // ==========================================
      // PoC 2: Approach Momentum 3-5 Bars (Max 15)
      // ==========================================
      double likelyBodySum = 0;
      double unlikelyBodySum = 0;
      int lookbackLimit = MathMax(0, touch_index - 5);
      int barsCounted = 0;

      for(int b = touch_index - 1; b >= lookbackLimit; b--)
        {
         double body = GetBodySize(open[b], close[b]);
         bool isGreen = close[b] > open[b];
         if(isBullishZone)
           {
            if(isGreen)
               likelyBodySum += body;
            else
               unlikelyBodySum += body;
           }
         else
           {
            if(!isGreen)
               likelyBodySum += body;
            else
               unlikelyBodySum += body;
           }
         barsCounted++;
         if(barsCounted >= 3)
            break;
        }

      if(unlikelyBodySum > (likelyBodySum * 2.0))
        {
         p2_score = 0;
         res.reasoning += "- ❌ **Momentum:** Dangerous Approach\\n\\n";
        }
      else
         if(likelyBodySum > unlikelyBodySum)
           {
            p2_score = 15;
            res.reasoning += "- ✅ **Momentum:** Favorable Approach\\n\\n";
           }
         else
           {
            p2_score = 5;
            res.reasoning += "- ⚠️ **Momentum:** Neutral Approach\\n\\n";
           }

      // ==========================================
      // PoC 3: Trend & Structural Sequences (Max 20)
      // ==========================================
      int seqStatus = EvaluateStructureSequence(zigZag, zoneCreationTime, isBullishZone);
      if(seqStatus == 1)
        {
         p3_score = 15;
         res.reasoning += "- ✅ **Structure:** Backed by 5+ BOS\\n\\n";
        }
      else
         if(seqStatus == 2)
           {
            p3_score = 20;
            res.reasoning += "- 🔥 **Structure:** Smart Money Trap Detected\\n\\n";
           }
         else
           {
            p3_score = 5;
            res.reasoning += "- ⚠️ **Structure:** Weak Sequence\\n\\n";
           }

      // ==========================================
      // PoC 4: Zone Freshness (Max 15)
      // ==========================================
      int touches = 0;
      for(int t = touch_index - 1; t >= 0; t--)
        {
         if(time[t] <= zoneCreationTime)
            break;
         if(isBullishZone && low[t] <= zoneHigh && high[t] >= zoneLow)
            touches++;
         if(!isBullishZone && high[t] >= zoneLow && low[t] <= zoneHigh)
            touches++;
        }

      if(touches == 0)
        {
         p4_score = 15;
         res.reasoning += "- ✅ **Freshness:** Zone is perfectly FRESH\\n\\n";
        }
      else
         if(touches == 1)
           {
            p4_score = 5;
            res.reasoning += "- ⚠️ **Freshness:** Mitigated Once\\n\\n";
           }
         else
           {
            p4_score = -10;
            res.reasoning += "- ❌ **Freshness:** Heavily Mitigated\\n\\n";
           }

      // ==========================================
      // PoC 5: Session Confluence (Max 10) - Pakistan Standard Time (PKT)
      // ==========================================
      datetime touchTime = time[touch_index];
      datetime pktTime = ConvertBrokerToPKT(touchTime);

      MqlDateTime pkt_dt;
      TimeToStruct(pktTime, pkt_dt);
      int pktHourMin = pkt_dt.hour * 100 + pkt_dt.min;

      bool inAsiaPKT    = (pktHourMin >= 300  && pktHourMin < 1400); // 3:00 AM to 2:00 PM
      bool inLondonPKT  = (pktHourMin >= 1200 && pktHourMin < 2100); // 12:00 PM to 9:00 PM
      bool inNYPKT      = (pktHourMin >= 1700 || pktHourMin < 200);   // 5:00 PM to 2:00 AM (next day)
      bool inOverlapPKT = (pktHourMin >= 1700 && pktHourMin < 2100); // 5:00 PM to 9:00 PM

      if(inOverlapPKT)
        {
         p5_score = 10;
         res.reasoning += "- ✅ **Session:** London & NY Overlap (PKT 5:00 PM - 9:00 PM)\\n\\n";
        }
      else
         if(inLondonPKT)
           {
            p5_score = 5;
            res.reasoning += "- ☑️ **Session:** London Session Active (PKT 12:00 PM - 9:00 PM)\\n\\n";
           }
         else
            if(inNYPKT)
              {
               p5_score = 5;
               res.reasoning += "- ☑️ **Session:** New York Session Active (PKT 5:00 PM - 2:00 AM)\\n\\n";
              }
            else
               if(inAsiaPKT)
                 {
                  p5_score = 5;
                  res.reasoning += "- ☑️ **Session:** Asian Session Active (PKT 3:00 AM - 2:00 PM)\\n\\n";
                 }
               else
                 {
                  p5_score = 0;
                  res.reasoning += "- ⚠️ **Session:** Outside Major Sessions (PKT)\\n\\n";
                 }

      // ==========================================
      // PoC 6: Fib Premium / Discount (Max 10)
      // ==========================================
      int creation_idx = -1;
      int low_b = 0;
      int high_b = touch_index;

      // 1. Locate the exact bar index where the zone was created using binary search
      while(low_b <= high_b)
        {
         int mid = low_b + (high_b - low_b) / 2;
         if(time[mid] == zoneCreationTime)
           {
            creation_idx = mid;
            break;
           }
         else
            if(time[mid] < zoneCreationTime)
               low_b = mid + 1;
            else
               high_b = mid - 1;
        }
      if(creation_idx == -1)
         creation_idx = 0;

      double swingHigh = -1.0;
      double swingLow  = -1.0;

      // 2. Identify structural leg boundaries between creation and touch index
      if(isBullishZone)
        {
         // Bullish Swing Leg: Swing Low is established at zone birth (zoneLow)
         // Swing High is the peak reached before the correction pullback touched the zone
         swingLow = zoneLow;
         for(int t = creation_idx; t <= touch_index; t++)
           {
            if(swingHigh == -1.0 || high[t] > swingHigh)
               swingHigh = high[t];
           }
        }
      else
        {
         // Bearish Swing Leg: Swing High is established at zone birth (zoneHigh)
         // Swing Low is the trough reached before the correction pullback touched the zone
         swingHigh = zoneHigh;
         for(int t = creation_idx; t <= touch_index; t++)
           {
            if(swingLow == -1.0 || low[t] < swingLow)
               swingLow = low[t];
           }
        }

      // 3. Evaluate zone position relative to structural leg midline
      if(swingHigh != -1.0 && swingLow != -1.0 && swingHigh > swingLow)
        {
         double midline = (swingHigh + swingLow) / 2.0;

         // Demand Zone is valid in Discount (bottom 50% of the swing leg)
         bool inDiscount = (zoneHigh <= midline);
         // Supply Zone is valid in Premium (top 50% of the swing leg)
         bool inPremium  = (zoneLow >= midline);

         if(isBullishZone && inDiscount)
           {
            p6_score = 10;
            res.reasoning += "- ✅ **Fibonacci:** Valid Discount Zone (Leg: " + DoubleToString(swingLow, _Digits) + " to " + DoubleToString(swingHigh, _Digits) + ")\\n\\n";
           }
         else
            if(!isBullishZone && inPremium)
              {
               p6_score = 10;
               res.reasoning += "- ✅ **Fibonacci:** Valid Premium Zone (Leg: " + DoubleToString(swingLow, _Digits) + " to " + DoubleToString(swingHigh, _Digits) + ")\\n\\n";
              }
            else
              {
               p6_score = 0;
               res.reasoning += "- ❌ **Fibonacci:** Poor Positioning (Zone not in Premium/Discount of the Swing Leg)\\n\\n";
              }
        }
      else
        {
         res.reasoning += "- ❌ **Fibonacci:** Structural swing leg boundaries could not be resolved\\n\\n";
        }

      // ==========================================
      // PoC 7: Distance to Zone Entrance (Max 15)
      // ==========================================
      double distancePips = 0;
      if(isBullishZone)
        {
         distancePips = (livePrice - zoneHigh) / pipSize;
         if(distancePips < 0)
            distancePips = 0;
        }
      else
        {
         distancePips = (zoneLow - livePrice) / pipSize;
         if(distancePips < 0)
            distancePips = 0;
        }

      if(distancePips >= 0.0 && distancePips <= 5.0)
        {
         p7_score = 15;
         res.reasoning += "- 🎯 **Proximity:** Optimal Entrance (" + DoubleToString(distancePips, 1) + " pips)\\n\\n";
        }
      else
         if(distancePips <= 15.0)
           {
            p7_score = 5;
            res.reasoning += "- ⚠️ **Proximity:** Acceptable (" + DoubleToString(distancePips, 1) + " pips)\\n\\n";
           }
         else
           {
            p7_score = -20;
            res.reasoning += "- ❌ **Proximity:** Too Far (" + DoubleToString(distancePips, 1) + " pips)\\n\\n";
           }

      // ==========================================
      // PoC 8: HTF-LTF Trend Alignment (Max 15)
      // ==========================================
      bool htfIsBullish = (ms.trend == 1);
      bool ltfIsBullish = (currentTF <= PERIOD_H1 && ms.trend == 1);

      if((isBullishZone && htfIsBullish) || (!isBullishZone && !htfIsBullish))
        {
         p8_score = 15;
         res.reasoning += "- ✅ **Alignment:** HTF & LTF Trend Synergy\\n\\n";
        }
      else
        {
         p8_score = -5;
         res.reasoning += "- ⚠️ **Alignment:** Counter-Trend Alert\\n\\n";
        }

      // ==========================================
      // PoC 9: Obstacle Zones Checking (Max 10)
      // ==========================================
      double sl, tp;
      if(isBullishZone)
        {
         sl = zoneLow - (3.0 * pipSize);
         double riskPrice = MathAbs(livePrice - sl);
         tp = livePrice + 2.0 * riskPrice;
        }
      else
        {
         sl = zoneHigh + (3.0 * pipSize);
         double riskPrice = MathAbs(sl - livePrice);
         tp = livePrice - 2.0 * riskPrice;
        }

      double rangeMax = MathMax(sl, tp);
      double rangeMin = MathMin(sl, tp);

      int opp_ds_count = 0;
      int opp_sp_count = 0;
      int opp_ob_count = 0;

      if(dsLogic != NULL && spLogic != NULL && obLogic != NULL)
        {
         if(isBullishZone)
           {
            // Check Supply Zones (Only Unmitigated ones)
            for(int i=0; i<dsLogic.poi_supplyTime.Total(); i++)
              {
               if((datetime)dsLogic.poi_supplyTime.At(i) > touchTime)
                  continue;
               if(dsLogic.poi_supplyMitigated.At(i) == 1)
                  continue;
               if(dsLogic.poi_supplyZoneLow.At(i) <= rangeMax && dsLogic.poi_supplyZoneHigh.At(i) >= rangeMin)
                  opp_ds_count++;
              }
            // Check Bearish Swing POIs (Only Unmitigated ones)
            for(int i=0; i<spLogic.poi_supplyTime.Total(); i++)
              {
               if((datetime)spLogic.poi_supplyTime.At(i) > touchTime)
                  continue;
               if(spLogic.poi_supplyMitigated.At(i) == 1)
                  continue;
               if(spLogic.poi_supplyZoneLow.At(i) <= rangeMax && spLogic.poi_supplyZoneHigh.At(i) >= rangeMin)
                  opp_sp_count++;
              }
            // Check Bearish Order Blocks (Only Unmitigated ones)
            for(int i=0; i<obLogic.poi_supplyTime.Total(); i++)
              {
               if((datetime)obLogic.poi_supplyTime.At(i) > touchTime)
                  continue;
               if(obLogic.poi_supplyMitigated.At(i) == 1)
                  continue;
               datetime zt = (datetime)obLogic.poi_supplyTime.At(i);
               if(obLogic.ob_time_found(&ms.ob_bear_struct_times, zt) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, zt))
                 {
                  if(obLogic.poi_supplyZoneLow.At(i) <= rangeMax && obLogic.poi_supplyZoneHigh.At(i) >= rangeMin)
                     opp_ob_count++;
                 }
              }
           }
         else
           {
            // Check Demand Zones (Only Unmitigated ones)
            for(int i=0; i<dsLogic.poi_demandTime.Total(); i++)
              {
               if((datetime)dsLogic.poi_demandTime.At(i) > touchTime)
                  continue;
               if(dsLogic.poi_demandMitigated.At(i) == 1)
                  continue;
               if(dsLogic.poi_demandZoneLow.At(i) <= rangeMax && dsLogic.poi_demandZoneHigh.At(i) >= rangeMin)
                  opp_ds_count++;
              }
            // Check Bullish Swing POIs (Only Unmitigated ones)
            for(int i=0; i<spLogic.poi_demandTime.Total(); i++)
              {
               if((datetime)spLogic.poi_demandTime.At(i) > touchTime)
                  continue;
               if(spLogic.poi_demandMitigated.At(i) == 1)
                  continue;
               if(spLogic.poi_demandZoneLow.At(i) <= rangeMax && spLogic.poi_demandZoneHigh.At(i) >= rangeMin)
                  opp_sp_count++;
              }
            // Check Bullish Order Blocks (Only Unmitigated ones)
            for(int i=0; i<obLogic.poi_demandTime.Total(); i++)
              {
               if((datetime)obLogic.poi_demandTime.At(i) > touchTime)
                  continue;
               if(obLogic.poi_demandMitigated.At(i) == 1)
                  continue;
               datetime zt = (datetime)obLogic.poi_demandTime.At(i);
               if(obLogic.ob_time_found(&ms.ob_bull_struct_times, zt) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, zt))
                 {
                  if(obLogic.poi_demandZoneLow.At(i) <= rangeMax && obLogic.poi_demandZoneHigh.At(i) >= rangeMin)
                     opp_ob_count++;
                 }
              }
           }
        }

      int total_obstacles = opp_ds_count + opp_sp_count + opp_ob_count;

      if(total_obstacles == 0)
        {
         p9_score = 10;
         res.reasoning += "- ✅ **Obstacles:** Clear path to TP\\n\\n";
        }
      else
        {
         p9_score = -5 * total_obstacles;
         if(p9_score < -25)
            p9_score = -25;

         string oppType1 = isBullishZone ? "Supply Zones" : "Demand Zones";
         string oppType2 = isBullishZone ? "Bearish Swing POIs" : "Bullish Swing POIs";
         string oppType3 = isBullishZone ? "Bearish OBs" : "Bullish OBs";

         string obsStr = "";
         if(opp_ds_count > 0)
            obsStr += IntegerToString(opp_ds_count) + " " + oppType1;
         if(opp_sp_count > 0)
            obsStr += (obsStr != "" ? ", " : "") + IntegerToString(opp_sp_count) + " " + oppType2;
         if(opp_ob_count > 0)
            obsStr += (obsStr != "" ? ", " : "") + IntegerToString(opp_ob_count) + " " + oppType3;

         res.reasoning += "- ⚠️ **Obstacles:** " + obsStr + " detected between Entry & TP\\n\\n";
        }

      // Link internal scores to struct
      res.p1_score = p1_score;
      res.p2_score = p2_score;
      res.p3_score = p3_score;
      res.p4_score = p4_score;
      res.p5_score = p5_score;
      res.p6_score = p6_score;
      res.p7_score = p7_score;
      res.p8_score = p8_score;
      res.p9_score = p9_score;

      // Final Score Calculation
      res.finalScore = p1_score + p2_score + p3_score + p4_score + p5_score + p6_score + p7_score + p8_score + p9_score;
      res.finalScore = (int)MathMax(0, MathMin(100, res.finalScore));

      if(res.finalScore >= 80)
         res.recommendation = "High Probability Setup. Execution is heavily supported by confluences.";
      else
         if(res.finalScore >= 60)
            res.recommendation = "Average Setup. Consider waiting for LTF confirmation.";
         else
            res.recommendation = "Low Probability. Lacks crucial structural & momentum support.";

      return res;
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\poc_analyzer.mqh

// END FILE: Include\Custom\General\poc_analyzer.mqh
