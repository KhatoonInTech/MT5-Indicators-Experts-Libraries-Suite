//+------------------------------------------------------------------+
//|                            Include\Custom\ZigZag\market_structure.mqh   |
//|                 Market Structure Engine (BOS, CHoCH, Swings)     |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.20"

#ifndef MARKET_STRUCTURE_MQH
#define MARKET_STRUCTURE_MQH

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayDouble.mqh>

// Structural event tracking model
struct StructuralEvent
  {
   datetime          time;
   string            name;
   datetime          lineStartTime;
   datetime          lineEndTime;
  };

//+------------------------------------------------------------------+
//| Market Structure Engine Class                                    |
//+------------------------------------------------------------------+
class CMarketStructure
  {
private:
   // Internal sequence queue to process renaming rules
   StructuralEvent   m_events[5];
   int               m_events_count;

   // Finds pullback swing levels strictly from confirmed pivots inside the range
   void              GetPullbackPivots(ZigZag* zz, datetime targetTime, datetime currentTime, double &pullbackHigh, datetime &pullbackHighTime, double &pullbackLow, datetime &pullbackLowTime)
     {
      pullbackHigh = EMPTY_VALUE;
      pullbackHighTime = 0;
      pullbackLow = EMPTY_VALUE;
      pullbackLowTime = 0;

      if(zz == NULL || zz.pivots.Total() == 0)
         return;

      for(int j = 0; j < zz.pivots.Total(); j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(zz.projection != NULL && p == zz.projection)
            continue;

         if(p.end.time >= targetTime && p.end.time <= currentTime)
           {
            if(p.isHigh)
              {
               if(pullbackHigh == EMPTY_VALUE || p.end.price > pullbackHigh)
                 {
                  pullbackHigh = p.end.price;
                  pullbackHighTime = p.end.time;
                 }
              }
            else
              {
               if(pullbackLow == EMPTY_VALUE || p.end.price < pullbackLow)
                 {
                  pullbackLow = p.end.price;
                  pullbackLowTime = p.end.time;
                 }
              }
           }
        }
     }

   // Finds the highest or lowest confirmed ZigZag pivot within a specified time span
   void              GetExtremePivotInRange(ZigZag* zz, datetime startTime, datetime endTime, bool searchHigh, double &extPrice, datetime &extTime)
     {
      extPrice = EMPTY_VALUE;
      extTime = 0;
      if(zz == NULL || zz.pivots.Total() == 0)
         return;
      bool first = true;
      for(int j = 0; j < zz.pivots.Total(); j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(zz.projection != NULL && p == zz.projection)
            continue;
         if(p.end.time >= startTime && p.end.time <= endTime)
           {
            if(searchHigh && p.isHigh)
              {
               if(first || p.end.price > extPrice)
                 {
                  extPrice = p.end.price;
                  extTime = p.end.time;
                  first = false;
                 }
              }
            else
               if(!searchHigh && !p.isHigh)
                 {
                  if(first || p.end.price < extPrice)
                    {
                     extPrice = p.end.price;
                     extTime = p.end.time;
                     first = false;
                    }
                 }
           }
        }
     }

   // Calculates target low and timestamp rules for Bearish CHoCH (unconditionally locks onto B)
   void              GetBearishChochTarget(ZigZag* zz, datetime chTime, double protPrice, double &targetPrice, datetime &targetTime)
     {
      targetPrice = EMPTY_VALUE;
      targetTime = 0;
      if(zz == NULL || zz.pivots.Total() == 0)
         return;

      int b_idx = -1;
      int limit = zz.pivots.Total() - 1;
      for(int j = 0; j < limit; j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(zz.projection != NULL && p == zz.projection)
            continue;
         if(p.end.time >= chTime && !p.isHigh)
           {
            b_idx = j;
            break;
           }
        }

      if(b_idx == -1)
         return;

      Pivot* pivotB = (Pivot*)zz.pivots.At(b_idx);
      targetPrice = pivotB.end.price;
      targetTime = pivotB.end.time;
     }

   // Calculates target high and timestamp rules for Bullish CHoCH (unconditionally locks onto A)
   void              GetBullishChochTarget(ZigZag* zz, datetime chTime, double protPrice, double &targetPrice, datetime &targetTime)
     {
      targetPrice = EMPTY_VALUE;
      targetTime = 0;
      if(zz == NULL || zz.pivots.Total() == 0)
         return;

      int a_idx = -1;
      int limit = zz.pivots.Total() - 1;
      for(int j = 0; j < limit; j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(zz.projection != NULL && p == zz.projection)
            continue;
         if(p.end.time >= chTime && p.isHigh)
           {
            a_idx = j;
            break;
           }
        }

      if(a_idx == -1)
         return;

      Pivot* pivotA = (Pivot*)zz.pivots.At(a_idx);
      targetPrice = pivotA.end.price;
      targetTime = pivotA.end.time;
     }

   // Filters out popped structural levels from the internal OB structures
   void              CleanupStructuralTimes(ZigZag* zz)
     {
      if(zz == NULL)
         return;

      for(int j = ob_bull_struct_times.Total() - 1; j >= 0; j--)
        {
         datetime t = (datetime)ob_bull_struct_times.At(j);
         bool exists = false;
         for(int p = 0; p < zz.pivots.Total(); p++)
           {
            Pivot* pv = (Pivot*)zz.pivots.At(p);
            if(zz.projection != NULL && pv == zz.projection)
               continue;
            if(pv.end.time == t)
              {
               exists = true;
               break;
              }
           }
         if(!exists)
            ob_bull_struct_times.Delete(j);
        }

      for(int j = ob_bear_struct_times.Total() - 1; j >= 0; j--)
        {
         datetime t = (datetime)ob_bear_struct_times.At(j);
         bool exists = false;
         for(int p = 0; p < zz.pivots.Total(); p++)
           {
            Pivot* pv = (Pivot*)zz.pivots.At(p);
            if(zz.projection != NULL && pv == zz.projection)
               continue;
            if(pv.end.time == t)
              {
               exists = true;
               break;
              }
           }
         if(!exists)
            ob_bear_struct_times.Delete(j);
        }
     }

   void              AddEvent(datetime t, string name, datetime lineStartTime, datetime lineEndTime, double linePrice)
     {
      // Failsafe to prevent zero-distance overlapping events causing mislabeling / queue corruption
      if(m_events_count > 0 && m_events[4].time == t && m_events[4].name == name)
         return;

      for(int j = 0; j < 4; j++)
        {
         m_events[j] = m_events[j+1];
        }
      m_events[4].time = t;
      m_events[4].name = name;
      m_events[4].lineStartTime = lineStartTime;
      m_events[4].lineEndTime = lineEndTime;
      if(m_events_count < 5)
         m_events_count++;

      // Append to full continuous history
      all_event_names.Add(name);
      all_event_times.Add((long)t);
      all_event_origin_times.Add((long)protected_level_time);
      all_event_origin_prices.Add(protected_level_price);
      all_event_prices.Add(linePrice); // Break level before protected_level_price changes.
     }

   void              RegisterSSLSweep(datetime sweepTime, datetime lineStartTime, datetime lineEndTime, datetime confirmingChochTime)
     {
      for(int k = 0; k < swept_ssl_times.Total(); k++)
        {
         if(swept_ssl_times.At(k) == (long)sweepTime)
            return;
        }

      swept_ssl_times.Add((long)sweepTime);
      swept_ssl_start_times.Add((long)lineStartTime);
      swept_ssl_end_times.Add((long)lineEndTime);
      swept_ssl_choch_times.Add((long)confirmingChochTime);
     }

   void              RegisterBSLSweep(datetime sweepTime, datetime lineStartTime, datetime lineEndTime, datetime confirmingChochTime)
     {
      for(int k = 0; k < swept_bsl_times.Total(); k++)
        {
         if(swept_bsl_times.At(k) == (long)sweepTime)
            return;
        }

      swept_bsl_times.Add((long)sweepTime);
      swept_bsl_start_times.Add((long)lineStartTime);
      swept_bsl_end_times.Add((long)lineEndTime);
      swept_bsl_choch_times.Add((long)confirmingChochTime);
     }

   void              UpdateHistoricalEventName(datetime t, string newName)
     {
      for(int k = all_event_times.Total() - 1; k >= 0; k--)
        {
         if(all_event_times.At(k) == (long)t)
           {
            all_event_names.Update(k, newName);
            break;
           }
        }
     }

   void              ProcessRenamingRules()
     {
      if(m_events_count < 3)
         return;

      string cur  = m_events[4].name;
      string prev = m_events[3].name;
      string pri  = m_events[2].name;

      // Rule 1: Failed bullish reversal between bearish structures -> SSL-Swept
      if((pri == "BR-BOS" || pri == "BR-CHoCH") && prev == "BL-CHoCH" && cur == "BR-CHoCH")
        {
         string line_id = "BOSCHoCH_" + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, line_id + "_lbl", OBJPROP_TEXT, tf_str() + "-SSL-Swept");
         m_events[3].name = "SSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "SSL-Swept");
         RegisterSSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);
        }

      // Rule 2: Failed bearish reversal between bullish structures -> BSL-Swept
      if((pri == "BL-BOS" || pri == "BL-CHoCH") && prev == "BR-CHoCH" && cur == "BL-CHoCH")
        {
         string line_id = "BOSCHoCH_" + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, line_id + "_lbl", OBJPROP_TEXT, tf_str() + "-BSL-Swept");
         m_events[3].name = "BSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "BSL-Swept");
         RegisterBSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);
        }

      // Rule 3: BL-CHoCH between BSL-Swept and BR-CHoCH -> SSL-Swept
      if(pri == "BSL-Swept" && prev == "BL-CHoCH" && cur == "BR-CHoCH")
        {
         string id3 = "BOSCHoCH_" + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, id3 + "_lbl", OBJPROP_TEXT, tf_str() + "-SSL-Swept");
         m_events[3].name = "SSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "SSL-Swept");
         RegisterSSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);

         string id4 = "BOSCHoCH_" + IntegerToString(m_events[4].time);
         if(m_showBosChoch) ObjectSetString(0, id4 + "_lbl", OBJPROP_TEXT, tf_str() + "-BR-BOS");
         m_events[4].name = "BR-BOS";
         UpdateHistoricalEventName(m_events[4].time, "BR-BOS");

         string id2 = "BOSCHoCH_" + IntegerToString(m_events[2].time);
         if(m_showBosChoch) ObjectSetString(0, id2 + "_lbl", OBJPROP_TEXT, tf_str() + "-BR-CHoCH");
         if(m_showBosChoch) ObjectSetInteger(0, id2, OBJPROP_COLOR, clrRed);
         if(m_showBosChoch) ObjectSetInteger(0, id2 + "_lbl", OBJPROP_COLOR, clrRed);
         m_events[2].name = "BR-CHoCH";
         UpdateHistoricalEventName(m_events[2].time, "BR-CHoCH");

         for(int k=0; k<swept_bsl_times.Total(); k++)
           {
            if(swept_bsl_times.At(k) == (long)m_events[2].time)
              {
               swept_bsl_times.Delete(k);
               swept_bsl_start_times.Delete(k);
               swept_bsl_end_times.Delete(k);
               swept_bsl_choch_times.Delete(k);
               break;
              }
           }
        }

      // Rule 4: BR-CHoCH between SSL-Swept and BL-CHoCH -> BSL-Swept
      if(pri == "SSL-Swept" && prev == "BR-CHoCH" && cur == "BL-CHoCH")
        {
         string id3 = "BOSCHoCH_" + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, id3 + "_lbl", OBJPROP_TEXT, tf_str() + "-BSL-Swept");
         m_events[3].name = "BSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "BSL-Swept");
         RegisterBSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);

         string id4 = "BOSCHoCH_" + IntegerToString(m_events[4].time);
         if(m_showBosChoch) ObjectSetString(0, id4 + "_lbl", OBJPROP_TEXT, tf_str() + "-BL-BOS");
         m_events[4].name = "BL-BOS";
         UpdateHistoricalEventName(m_events[4].time, "BL-BOS");

         string id2 = "BOSCHoCH_" + IntegerToString(m_events[2].time);
         if(m_showBosChoch) ObjectSetString(0, id2 + "_lbl", OBJPROP_TEXT, tf_str() + "-BL-CHoCH");
         if(m_showBosChoch) ObjectSetInteger(0, id2, OBJPROP_COLOR, clrGreen);
         if(m_showBosChoch) ObjectSetInteger(0, id2 + "_lbl", OBJPROP_COLOR, clrGreen);
         m_events[2].name = "BL-CHoCH";
         UpdateHistoricalEventName(m_events[2].time, "BL-CHoCH");

         for(int k=0; k<swept_ssl_times.Total(); k++)
           {
            if(swept_ssl_times.At(k) == (long)m_events[2].time)
              {
               swept_ssl_times.Delete(k);
               swept_ssl_start_times.Delete(k);
               swept_ssl_end_times.Delete(k);
               swept_ssl_choch_times.Delete(k);
               break;
              }
           }
        }

      ev1_name = m_events[4].name;
      ev2_name = m_events[3].name;
     }

public:
   // --- Settings ---
   datetime          m_drawStartTime;
   bool              m_showBosChoch;
   bool              m_showSwingHL;
   ENUM_TIMEFRAMES   m_tf;

   // --- State Trackers ---
   int               trend;
   double            protected_level_price;
   datetime          protected_level_time;
   double            target_level_price;
   datetime          target_level_time;

   double            abs_high;
   datetime          abs_high_time;
   double            abs_low;
   datetime          abs_low_time;

   datetime          last_processed_pivot_time;
   datetime          last_breakout_time;
   datetime          ob_prev_prot_time;

   string            ev1_name;
   string            ev2_name;
   datetime          ev1_time;
   datetime          ev2_time;

   // --- Dedicated Active Sweep Flag & Properties ---
   bool              new_sweep_confirmed;
   string            confirmed_sweep_type;
   datetime          confirmed_sweep_time;
   double            confirmed_sweep_level;

   // --- Structural Trackers for External Use (POI/OB linking) ---
   CArrayLong        ob_bull_struct_times;
   CArrayLong        ob_bear_struct_times;

   // --- Dedicated Sweep Line Registry ---
   CArrayLong        swept_ssl_times;
   CArrayLong        swept_ssl_start_times;
   CArrayLong        swept_ssl_end_times;
   CArrayLong        swept_ssl_choch_times; // Immutable confirming event, not the older swept line.
   CArrayLong        swept_bsl_times;
   CArrayLong        swept_bsl_start_times;
   CArrayLong        swept_bsl_end_times;
   CArrayLong        swept_bsl_choch_times; // Immutable confirming event, not the older swept line.

   // --- Full Historical Structural Event Registry ---
   CArrayString      all_event_names;
   CArrayLong        all_event_times;
   CArrayDouble      all_event_prices;
   CArrayLong        all_event_origin_times;
   CArrayDouble      all_event_origin_prices;

   // --- Constructor & Destructor ---
                     CMarketStructure()
     {
      m_drawStartTime = 0;
      m_showBosChoch = true;
      m_showSwingHL  = true;
      m_tf           = PERIOD_CURRENT;
      ResetState();
     }

                    ~CMarketStructure()
     {
      ObjectsDeleteAll(0, "BOSCHoCH_");
      ObjectsDeleteAll(0, "SWING_");
     }

   void              Init(bool showBosChoch, bool showSwingHL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
     {
      m_showBosChoch = showBosChoch;
      m_showSwingHL  = showSwingHL;
      m_tf           = tf;
     }

   // --- State Reset ---
   void              ResetState()
     {
      trend = 1;
      protected_level_price = EMPTY_VALUE;
      protected_level_time = 0;
      target_level_price = EMPTY_VALUE;
      target_level_time = 0;

      abs_high = EMPTY_VALUE;
      abs_high_time = 0;
      abs_low = EMPTY_VALUE;
      abs_low_time = 0;

      last_processed_pivot_time = 0;
      last_breakout_time = 0;
      ob_prev_prot_time = 0;

      ev1_name = "";
      ev2_name = "";
      ev1_time = 0;
      ev2_time = 0;

      new_sweep_confirmed   = false;
      confirmed_sweep_type  = "";
      confirmed_sweep_time  = 0;
      confirmed_sweep_level = 0.0;

      m_events_count = 0;
      for(int j = 0; j < 5; j++)
        {
         m_events[j].time = 0;
         m_events[j].name = "";
         m_events[j].lineStartTime = 0;
         m_events[j].lineEndTime = 0;
        }

      all_event_names.Clear();
      all_event_prices.Clear();
      all_event_origin_times.Clear();
      all_event_origin_prices.Clear();
      all_event_times.Clear();

      ob_bull_struct_times.Clear();
      ob_bear_struct_times.Clear();
      swept_ssl_times.Clear();
      swept_ssl_start_times.Clear();
      swept_ssl_end_times.Clear();
      swept_ssl_choch_times.Clear();
      swept_bsl_times.Clear();
      swept_bsl_start_times.Clear();
      swept_bsl_end_times.Clear();
      swept_bsl_choch_times.Clear();

      ObjectsDeleteAll(0, "BOSCHoCH_");
      ObjectsDeleteAll(0, "SWING_");
     }

   // --- Structural Trend Queries ---
   int               GetPrecedingBullishStructureCount(datetime beforeTime)
     {
      int count = 0;
      int total = all_event_times.Total();
      for(int k = total - 1; k >= 0; k--)
        {
         datetime evTime = (datetime)all_event_times.At(k);
         if(evTime >= beforeTime)
            continue; // Skip the candidate event itself and anything after

         string name = all_event_names.At(k);
         // Bullish structures: BL-BOS, BL-CHoCH, BSL-Swept
         if(StringFind(name, "BL-") >= 0 || StringFind(name, "BSL") >= 0)
            count++;
         else
            break; // Stop at first non-bullish structure
        }
      return count;
     }

   int               GetPrecedingBearishStructureCount(datetime beforeTime)
     {
      int count = 0;
      int total = all_event_times.Total();
      for(int k = total - 1; k >= 0; k--)
        {
         datetime evTime = (datetime)all_event_times.At(k);
         if(evTime >= beforeTime)
            continue; // Skip the candidate event itself and anything after

         string name = all_event_names.At(k);
         // Bearish structures: BR-BOS, BR-CHoCH, SSL-Swept
         if(StringFind(name, "BR-") >= 0 || StringFind(name, "SSL") >= 0)
            count++;
         else
            break; // Stop at first non-bearish structure
        }
      return count;
     }

   // --- Helper Functions ---
   string            tf_str(ENUM_TIMEFRAMES current_tf = PERIOD_CURRENT)
     {
      ENUM_TIMEFRAMES tf_to_use = (current_tf != PERIOD_CURRENT) ? current_tf : ((m_tf != PERIOD_CURRENT) ? m_tf : _Period);
      int sec = PeriodSeconds(tf_to_use);
      if(sec <= 0)
         sec = 60;
      int mins = sec / 60;
      if(mins < 60)
         return IntegerToString(mins) + "m";
      else
         if(mins < 1440 && mins % 60 == 0)
            return "H" + IntegerToString(mins / 60);
         else
            if(mins == 1440)
               return "D";
            else
               if(mins == 10080)
                  return "W";
               else
                  if(mins >= 43200)
                     return "M";
      return IntegerToString(mins) + "m";
     }

   // A sweep can produce its LB later, after another structure has printed.
   // Return the event captured at sweep confirmation rather than the latest event.
   datetime          GetSweepConfirmingChochTime(datetime sweepLineTime, bool isSSL)
     {
      if(isSSL)
        {
         for(int k = 0; k < swept_ssl_times.Total(); k++)
            if(swept_ssl_times.At(k) == (long)sweepLineTime && k < swept_ssl_choch_times.Total())
               return (datetime)swept_ssl_choch_times.At(k);
        }
      else
        {
         for(int k = 0; k < swept_bsl_times.Total(); k++)
            if(swept_bsl_times.At(k) == (long)sweepLineTime && k < swept_bsl_choch_times.Total())
               return (datetime)swept_bsl_choch_times.At(k);
        }
      return 0;
     }

   datetime          GetSweepExtremePivotTime(datetime sweepLineTime, bool searchHigh, ZigZag* zz)
     {
      datetime lineStart = 0;
      datetime lineEnd = 0;
      if(searchHigh)
        {
         for(int k = 0; k < swept_ssl_times.Total(); k++)
           {
            if(swept_ssl_times.At(k) == (long)sweepLineTime &&
               k < swept_ssl_start_times.Total() && k < swept_ssl_end_times.Total())
              {
               lineStart = (datetime)swept_ssl_start_times.At(k);
               lineEnd = (datetime)swept_ssl_end_times.At(k);
               break;
              }
           }
        }
      else
        {
         for(int k = 0; k < swept_bsl_times.Total(); k++)
           {
            if(swept_bsl_times.At(k) == (long)sweepLineTime &&
               k < swept_bsl_start_times.Total() && k < swept_bsl_end_times.Total())
              {
               lineStart = (datetime)swept_bsl_start_times.At(k);
               lineEnd = (datetime)swept_bsl_end_times.At(k);
               break;
              }
           }
        }

      // Sweep geometry belongs to this engine, never to objects on an unrelated chart.
      if(lineStart <= 0 || lineEnd <= 0)
         return 0;

      if(zz == NULL || CheckPointer(zz) != POINTER_DYNAMIC)
         return 0;

      int pivotAIndex = -1;
      int pivotBIndex = -1;
      for(int j = 0; j < zz.pivots.Total(); j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || p.end == NULL || CheckPointer(p.end) != POINTER_DYNAMIC)
            continue;

         if(pivotAIndex < 0 && p.end.time == lineStart)
            pivotAIndex = j;
         if(pivotBIndex < 0 && p.start != NULL && CheckPointer(p.start) == POINTER_DYNAMIC)
           {
            datetime segmentStart = (p.start.time < p.end.time ? p.start.time : p.end.time);
            datetime segmentEnd   = (p.start.time > p.end.time ? p.start.time : p.end.time);
            if(lineEnd >= segmentStart && lineEnd <= segmentEnd)
               pivotBIndex = j;
           }
        }

      if(pivotAIndex < 0 || pivotBIndex < 0)
         return 0;

      int firstPivot = MathMin(pivotAIndex, pivotBIndex);
      int lastPivot  = MathMax(pivotAIndex, pivotBIndex);
      double extremePrice = EMPTY_VALUE;
      datetime extremeTime = 0;

      for(int j = firstPivot; j <= lastPivot; j++)
        {
         Pivot* p = (Pivot*)zz.pivots.At(j);
         if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || p.end == NULL || CheckPointer(p.end) != POINTER_DYNAMIC || p.isHigh != searchHigh)
            continue;

         if(extremeTime == 0 || (searchHigh ? p.end.price > extremePrice : p.end.price < extremePrice))
           {
            extremePrice = p.end.price;
            extremeTime = p.end.time;
           }
        }
      return extremeTime;
     }

   color             get_swing_color()
     {
      int mins = PeriodSeconds() / 60;
      if(mins < 1)
         return C'30,30,30';
      else
         if(mins <= 15)
            return C'0,0,139';
         else
            if(mins <= 60)
               return C'139,0,0';
            else
               if(mins < 1440)
                  return C'0,100,0';
               else
                  if(mins == 1440)
                     return C'139,69,19';
      return C'47,79,79';
     }

   // --- Main Engine Update Module ---
   void              Update(int i, const datetime &time[], const double &high[], const double &low[], const double &close[], ZigZag* zigZag)
     {
      new_sweep_confirmed = false; // Reset on every bar

      // --- 1. INITIALIZATION ---
      if(protected_level_price == EMPTY_VALUE && zigZag.pivots.Total() >= 3)
        {
         for(int pidx = 0; pidx <= 2; pidx++)
           {
            Pivot* p = (Pivot*)zigZag.pivots.At(pidx);
            if(p.isHigh && trend == 1)
              {
               target_level_price = p.end.price;
               target_level_time = p.end.time;
              }
            if(!p.isHigh && trend == 1)
              {
               protected_level_price = p.end.price;
               protected_level_time = p.end.time;
              }
           }
        }

      // --- 2. ABSOLUTE HIGH/LOW TRACKING ---
      if(abs_high == EMPTY_VALUE || high[i] > abs_high)
        {
         abs_high = high[i];
         abs_high_time = time[i];
        }
      if(abs_low == EMPTY_VALUE || low[i] < abs_low)
        {
         abs_low = low[i];
         abs_low_time = time[i];
        }

      // --- 3. PROCESS CONFIRMED LOCKED PIVOTS ---
      if(zigZag.pivots.Total() >= 2)
        {
         int target_idx = zigZag.pivots.Total() - 2;
         Pivot* p = (Pivot*)zigZag.pivots.At(target_idx);

         if(p != NULL)
           {
            if(last_processed_pivot_time == 0 || p.end.time != last_processed_pivot_time)
              {
               last_processed_pivot_time = p.end.time;

               if(last_breakout_time == 0 || p.end.time > protected_level_time)
                 {
                  if(p.isHigh && trend == 1)
                    {
                     target_level_price = target_level_price;
                    }
                  else
                     if(!p.isHigh && trend == -1)
                       {
                        target_level_price = target_level_price;
                       }

                  if(p.isHigh && trend == -1)
                    {
                     if((last_breakout_time == 0 || p.end.time <= last_breakout_time) && (protected_level_price == EMPTY_VALUE || p.end.price > protected_level_price))
                       {
                        protected_level_price = p.end.price;
                        protected_level_time  = p.end.time;
                       }
                    }
                  else
                     if(!p.isHigh && trend == 1)
                       {
                        if((last_breakout_time == 0 || p.end.time <= last_breakout_time) && (protected_level_price == EMPTY_VALUE || p.end.price < protected_level_price))
                          {
                           protected_level_price = p.end.price;
                           protected_level_time  = p.end.time;
                          }
                       }
                 }
              }
           }
        }

      // --- CONTINUOUS CHOCH TARGET RESOLVER MODULE ---
      if(trend == 1 && target_level_price == EMPTY_VALUE && last_breakout_time != 0)
        {
         double tempTargetPrice = EMPTY_VALUE;
         datetime tempTargetTime = 0;
         GetBullishChochTarget(zigZag, last_breakout_time, protected_level_price, tempTargetPrice, tempTargetTime);
         if(tempTargetPrice != EMPTY_VALUE)
           {
            target_level_price = tempTargetPrice;
            target_level_time = tempTargetTime;
           }
        }
      if(trend == -1 && target_level_price == EMPTY_VALUE && last_breakout_time != 0)
        {
         double tempTargetPrice = EMPTY_VALUE;
         datetime tempTargetTime = 0;
         GetBearishChochTarget(zigZag, last_breakout_time, protected_level_price, tempTargetPrice, tempTargetTime);
         if(tempTargetPrice != EMPTY_VALUE)
           {
            target_level_price = tempTargetPrice;
            target_level_time = tempTargetTime;
           }
        }

      // --- 4. BREAKOUT LOGIC & SWING EXTREME FILTER ---
      bool isBullishChoch = (trend == -1 && protected_level_price != EMPTY_VALUE && close[i] > protected_level_price);
      bool isBullishBos   = (trend == 1  && target_level_price != EMPTY_VALUE && close[i] > target_level_price);
      bool isBearishChoch = (trend == 1  && protected_level_price != EMPTY_VALUE && close[i] < protected_level_price);
      bool isBearishBos   = (trend == -1 && target_level_price != EMPTY_VALUE && close[i] < target_level_price);

      bool crossUp = isBullishChoch || isBullishBos;
      bool crossDn = isBearishChoch || isBearishBos;
      datetime eventLineStart = 0;
      double eventLinePrice = (isBullishChoch || isBearishChoch) ? protected_level_price : target_level_price;

      if(crossUp && (last_breakout_time == 0 || time[i] > last_breakout_time))
        {
         if(trend == -1) // Bullish CHoCH
           {
            trend = 1;
            ev1_name = "BL-CHoCH";
            ev2_name = "";
            eventLineStart = protected_level_time;
            if(m_showBosChoch && time[i] >= m_drawStartTime)
              {
               datetime midTime = (datetime)MathMax(protected_level_time,m_drawStartTime) + (time[i] - (datetime)MathMax(protected_level_time,m_drawStartTime)) / 2;
               string id = "BOSCHoCH_" + IntegerToString(time[i]);
               Plotter::DrawLine(id, (datetime)MathMax(protected_level_time,m_drawStartTime), protected_level_price, time[i], protected_level_price, clrGreen, STYLE_SOLID, 2, false);
               Plotter::DrawLabel(id+"_lbl", midTime, protected_level_price, tf_str()+"-BL-CHoCH", clrGreen, ANCHOR_LOWER);
              }

            double lowestLinePrice = EMPTY_VALUE;
            datetime lowestLineTime = 0;
            GetExtremePivotInRange(zigZag, protected_level_time, time[i], false, lowestLinePrice, lowestLineTime);

            if(lowestLinePrice != EMPTY_VALUE)
              {
               protected_level_price = lowestLinePrice;
               protected_level_time  = lowestLineTime;
              }

            double tempTargetPrice = EMPTY_VALUE;
            datetime tempTargetTime = 0;
            GetBullishChochTarget(zigZag, time[i], protected_level_price, tempTargetPrice, tempTargetTime);

            target_level_price = tempTargetPrice;
            target_level_time  = tempTargetTime;
           }
         else // Bullish BOS
            if(trend == 1)
              {
               ev1_name = "BL-BOS";
               ev2_name = "";
               eventLineStart = target_level_time;
               if(m_showBosChoch && time[i] >= m_drawStartTime)
                 {
                  datetime midTime = (datetime)MathMax(target_level_time,m_drawStartTime) + (time[i] - (datetime)MathMax(target_level_time,m_drawStartTime)) / 2;
                  string id = "BOSCHoCH_" + IntegerToString(time[i]);
                  Plotter::DrawLine(id, (datetime)MathMax(target_level_time,m_drawStartTime), target_level_price, time[i], target_level_price, clrGreen, STYLE_SOLID, 2, false);
                  Plotter::DrawLabel(id+"_lbl", midTime, target_level_price, tf_str()+"-BL-BOS", clrGreen, ANCHOR_LOWER);
                 }

               double pullback_high = EMPTY_VALUE, pullback_low = EMPTY_VALUE;
               datetime pullback_high_time = 0, pullback_low_time = 0;
               if(target_level_time != 0)
                  GetPullbackPivots(zigZag, target_level_time, time[i], pullback_high, pullback_high_time, pullback_low, pullback_low_time);

               if(pullback_low != EMPTY_VALUE)
                 {
                  protected_level_price = pullback_low;
                  protected_level_time  = pullback_low_time;
                 }

               target_level_price = EMPTY_VALUE;
               target_level_time = 0;
              }

         abs_high = EMPTY_VALUE;
         abs_low = EMPTY_VALUE;
         last_breakout_time = time[i];

         AddEvent(last_breakout_time, ev1_name, eventLineStart, time[i], eventLinePrice);
         ProcessRenamingRules();
        }
      else
         if(crossDn && (last_breakout_time == 0 || time[i] > last_breakout_time))
           {
            if(trend == 1) // Bearish CHoCH
              {
               trend = -1;
               ev1_name = "BR-CHoCH";
               ev2_name = "";
               eventLineStart = protected_level_time;
               if(m_showBosChoch && time[i] >= m_drawStartTime)
                 {
                  datetime midTime = (datetime)MathMax(protected_level_time,m_drawStartTime) + (time[i] - (datetime)MathMax(protected_level_time,m_drawStartTime)) / 2;
                  string id = "BOSCHoCH_" + IntegerToString(time[i]);
                  Plotter::DrawLine(id, (datetime)MathMax(protected_level_time,m_drawStartTime), protected_level_price, time[i], protected_level_price, clrRed, STYLE_SOLID, 2, false);
                  Plotter::DrawLabel(id+"_lbl", midTime, protected_level_price, tf_str()+"-BR-CHoCH", clrRed, ANCHOR_UPPER);
                 }

               double highestLinePrice = EMPTY_VALUE;
               datetime highestLineTime = 0;
               GetExtremePivotInRange(zigZag, protected_level_time, time[i], true, highestLinePrice, highestLineTime);

               if(highestLinePrice != EMPTY_VALUE)
                 {
                  protected_level_price = highestLinePrice;
                  protected_level_time  = highestLineTime;
                 }

               double tempTargetPrice = EMPTY_VALUE;
               datetime tempTargetTime = 0;
               GetBearishChochTarget(zigZag, time[i], protected_level_price, tempTargetPrice, tempTargetTime);

               target_level_price = tempTargetPrice;
               target_level_time  = tempTargetTime;
              }
            else // Bearish BOS
               if(trend == -1)
                 {
                  ev1_name = "BR-BOS";
                  ev2_name = "";
                  eventLineStart = target_level_time;
                  if(m_showBosChoch && time[i] >= m_drawStartTime)
                    {
                     datetime midTime = (datetime)MathMax(target_level_time,m_drawStartTime) + (time[i] - (datetime)MathMax(target_level_time,m_drawStartTime)) / 2;
                     string id = "BOSCHoCH_" + IntegerToString(time[i]);
                     Plotter::DrawLine(id, (datetime)MathMax(target_level_time,m_drawStartTime), target_level_price, time[i], target_level_price, clrRed, STYLE_SOLID, 2, false);
                     Plotter::DrawLabel(id+"_lbl", midTime, target_level_price, tf_str()+"-BR-BOS", clrRed, ANCHOR_UPPER);
                    }

                  double pullback_high = EMPTY_VALUE, pullback_low = EMPTY_VALUE;
                  datetime pullback_high_time = 0, pullback_low_time = 0;
                  if(target_level_time != 0)
                     GetPullbackPivots(zigZag, target_level_time, time[i], pullback_high, pullback_high_time, pullback_low, pullback_low_time);

                  if(pullback_high != EMPTY_VALUE)
                    {
                     protected_level_price = pullback_high;
                     protected_level_time  = pullback_high_time;
                    }

                  target_level_price = EMPTY_VALUE;
                  target_level_time = 0;
                 }

            abs_high = EMPTY_VALUE;
            abs_low = EMPTY_VALUE;
            last_breakout_time = time[i];

            AddEvent(last_breakout_time, ev1_name, eventLineStart, time[i], eventLinePrice);
            ProcessRenamingRules();
           }

      // --- SWING POI STRUCTURAL TRACKING LOGIC ---
      if(protected_level_time != 0 && (ob_prev_prot_time == 0 || protected_level_time != ob_prev_prot_time))
        {
         ob_prev_prot_time = protected_level_time;
         if(trend == 1)
            ob_bull_struct_times.Add((long)protected_level_time);
         else
            if(trend == -1)
               ob_bear_struct_times.Add((long)protected_level_time);
        }

      // --- LATEST SWING HIGH & LOW LINES ---
      if(m_showSwingHL && time[i] >= m_drawStartTime)
        {
         color swing_line_color = get_swing_color();
         double active_swing_high_price = (trend == -1) ? protected_level_price : target_level_price;
         datetime active_swing_high_time  = (trend == -1) ? protected_level_time  : target_level_time;
         double active_swing_low_price  = (trend == 1)  ? protected_level_price : target_level_price;
         datetime active_swing_low_time   = (trend == 1)  ? protected_level_time  : target_level_time;

         if(active_swing_high_price != EMPTY_VALUE && active_swing_high_time != 0)
           {
            string hln = "SWING_HIGH_LINE";
            string hlbl = "SWING_HIGH_LBL";
            datetime mTime = (datetime)MathMax(active_swing_high_time,m_drawStartTime) + (time[i] - (datetime)MathMax(active_swing_high_time,m_drawStartTime))/2;
            Plotter::DrawLine(hln, (datetime)MathMax(active_swing_high_time,m_drawStartTime), active_swing_high_price, time[i], active_swing_high_price, swing_line_color, STYLE_DASH, 1, false);
            Plotter::DrawLabel(hlbl, mTime, active_swing_high_price, " "+tf_str()+"-SWING-HIGH ", swing_line_color, ANCHOR_LOWER);
           }

         if(active_swing_low_price != EMPTY_VALUE && active_swing_low_time != 0)
           {
            string lln = "SWING_LOW_LINE";
            string llbl = "SWING_LOW_LBL";
            datetime mTimeL = (datetime)MathMax(active_swing_low_time,m_drawStartTime) + (time[i] - (datetime)MathMax(active_swing_low_time,m_drawStartTime))/2;
            Plotter::DrawLine(lln, (datetime)MathMax(active_swing_low_time,m_drawStartTime), active_swing_low_price, time[i], active_swing_low_price, swing_line_color, STYLE_DASH, 1, false);
            Plotter::DrawLabel(llbl, mTimeL, active_swing_low_price, " "+tf_str()+"-SWING-LOW ", swing_line_color, ANCHOR_UPPER);
           }
        }

      CleanupStructuralTimes(zigZag);
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\market_structure.mqh
