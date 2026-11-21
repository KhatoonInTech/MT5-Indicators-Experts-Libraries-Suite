//+------------------------------------------------------------------+
//|                                        Include\Custom\ZigZag\ZigZag.mqh |
//|                                     Converted from TradingView v9|
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.05"

#include <Arrays\ArrayObj.mqh>
//+------------------------------------------------------------------+
//| Clean symbol utility (strips trailing 'm' for exness cent)       |
//+------------------------------------------------------------------+
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

#ifndef CMARKETMETRICS_DEF
#define CMARKETMETRICS_DEF

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMarketMetrics : public CObject
  {
public:
   double            currentBid;
   double            currentAsk;
   double            zoneHigh;
   double            zoneLow;
   long              zoneAgeSeconds;
   bool              isMitigated;
   int               trendContext; // 1 = Bullish, -1 = Bearish
   datetime          lastBosChochTime;
   long              currentTickVolume;
   long              currentRealVolume;
   double            cumulativeVolume;
   double            lastReversalPrice;
   double            lastReversalPriceChange;

                     CMarketMetrics()
     {
      currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      long tick_vol_arr[], real_vol_arr[];
      if(CopyTickVolume(_Symbol, _Period, 0, 1, tick_vol_arr) > 0)
         currentTickVolume = tick_vol_arr[0];
      else
         currentTickVolume = 0;
      if(CopyRealVolume(_Symbol, _Period, 0, 1, real_vol_arr) > 0)
         currentRealVolume = real_vol_arr[0];
      else
         currentRealVolume = 0;

      zoneHigh = 0.0;
      zoneLow = 0.0;
      zoneAgeSeconds = 0;
      isMitigated = false;
      trendContext = 0;
      lastBosChochTime = 0;
      cumulativeVolume = 0.0;
      lastReversalPrice = 0.0;
      lastReversalPriceChange = 0.0;
     }
  };
#endif

int math_sign(double val) { return (val > 0) ? 1 : ((val < 0) ? -1 : 0); }
double nz(double val, double alt = 0.0) { return (val == EMPTY_VALUE || val == NULL) ? alt : val; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class PineArrayDouble : public CObject
  {
private:
   double            m_data[];
public:
                     PineArrayDouble() {}
                    ~PineArrayDouble() { ArrayFree(m_data); }

   int               size() { return ArraySize(m_data); }

   void              unshift(double val)
     {
      int s = ArraySize(m_data);
      ArrayResize(m_data, s + 1, 20000);
      for(int i = s; i > 0; i--)
         m_data[i] = m_data[i - 1];
      m_data[0] = val;
     }

   void              set(int index, double val)
     {
      if(index >= 0 && index < ArraySize(m_data))
         m_data[index] = val;
     }

   double            get(int index)
     {
      if(index >= 0 && index < ArraySize(m_data))
         return m_data[index];
      return EMPTY_VALUE;
     }

   PineArrayDouble*  slice(int start, int end)
     {
      PineArrayDouble* res = new PineArrayDouble();
      int len = end - start;
      int max_len = ArraySize(m_data) - start;
      if(len > max_len)
         len = max_len;
      if(len > 0 && start >= 0)
        {
         ArrayResize(res.m_data, len);
         for(int i = 0; i < len; i++)
            res.m_data[i] = m_data[start + i];
        }
      return res;
     }

   double            max()
     {
      if(ArraySize(m_data) == 0)
         return EMPTY_VALUE;
      int idx = ArrayMaximum(m_data);
      return m_data[idx];
     }

   double            min()
     {
      if(ArraySize(m_data) == 0)
         return EMPTY_VALUE;
      int idx = ArrayMinimum(m_data);
      return m_data[idx];
     }

   int               indexof(double val)
     {
      for(int i = 0; i < ArraySize(m_data); i++)
        {
         if(m_data[i] == val)
            return i;
        }
      return -1;
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class PineArrayLong : public CObject
  {
private:
   long              m_data[];
public:
   int               size() { return ArraySize(m_data); }
   void              unshift(long val)
     {
      int s = ArraySize(m_data);
      ArrayResize(m_data, s + 1, 20000);
      for(int i = s; i > 0; i--)
         m_data[i] = m_data[i - 1];
      m_data[0] = val;
     }
   void              set(int index, long val)
     {
      if(index >= 0 && index < ArraySize(m_data))
         m_data[index] = val;
     }
   long              get(int index)
     {
      if(index >= 0 && index < ArraySize(m_data))
         return m_data[index];
      return 0;
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class chart_point : public CObject
  {
public:
   datetime          time;
   int               index;
   double            price;

                     chart_point(datetime t, int idx, double p) { time = t; index = idx; price = p; }
                     chart_point() { time = 0; index = 0; price = 0.0; }

   static chart_point* now(double p, datetime t = 0, int idx = 0)
     {
      return new chart_point(t == 0 ? TimeCurrent() : t, idx, p);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Settings
  {
public:
   double            devThreshold;
   int               depth;
   color             lineColor;
   bool              projectionPivots;
   bool              displayReversalPrice;
   bool              displayCumulativeVolume;
   bool              displayReversalPriceChange;
   string            differencePriceMode;
   bool              draw;
   bool              allowZigZagOnOneBar;

                     Settings()
     {
      devThreshold               = 5.0;
      depth                      = 10;
      lineColor                  = clrBlue;
      projectionPivots           = true;
      displayReversalPrice       = true;
      displayCumulativeVolume    = true;
      displayReversalPriceChange = true;
      differencePriceMode        = "Absolute";
      draw                       = true;
      allowZigZagOnOneBar        = true;
     }

                     Settings(double _devThreshold, int _depth, color _lineColor, bool _projectionPivots, bool _displayReversalPrice, bool _displayCumulativeVolume, bool _displayReversalPriceChange, string _differencePriceMode)
     {
      devThreshold = _devThreshold;
      depth = _depth;
      lineColor = _lineColor;
      projectionPivots = _projectionPivots;
      displayReversalPrice = _displayReversalPrice;
      displayCumulativeVolume = _displayCumulativeVolume;
      displayReversalPriceChange = _displayReversalPriceChange;
      differencePriceMode = _differencePriceMode;
      draw = true;
      allowZigZagOnOneBar = true;
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Pivot : public CObject
  {
public:
   string            ln;
   string            lb;
   bool              isHigh;
   double            vol;
   chart_point*      start;
   chart_point*      end;

                     Pivot(string _ln, string _lb, bool _isHigh, double _vol, chart_point* _start, chart_point* _end)
     {
      ln = _ln;
      lb = _lb;
      isHigh = _isHigh;
      vol = _vol;
      start = _start;
      end = _end;
     }

                    ~Pivot()
     {
      if(CheckPointer(start) == POINTER_DYNAMIC)
         delete start;
      if(CheckPointer(end) == POINTER_DYNAMIC)
         delete end;
      if(ln != "" && StringFind(ln, "ZZ_Proj") < 0)
         ObjectDelete(0, ln);
      if(lb != "" && StringFind(lb, "ZZ_Proj") < 0)
         ObjectDelete(0, lb);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ZigZag
  {
public:
   Settings*         settings;
   datetime          zoneStartTime; // Earlier pivots supply structure only, never zone origins.
   datetime          drawStartTime; // No historical warmup drawings.
   CArrayObj*        pivots;
   double            sumVol;
   double            sumVol_bar_start;
   Pivot*            projection;

   PineArrayDouble*  highs;
   PineArrayDouble*  lows;
   PineArrayLong*    times;
   PineArrayDouble*  cVols;
   int               maxSize;
   Pivot*            removed;
   chart_point*      prevProjection;
   double            cum_vol_tracker;
   int               last_bar_index;
   long              pivot_id_counter;

                     ZigZag(Settings* _settings)
     {
      settings = _settings;
      zoneStartTime = 0;
      drawStartTime = 0;
      pivots   = new CArrayObj();
      pivots.FreeMode(true);
      sumVol   = 0;
      sumVol_bar_start = 0;
      projection = NULL;

      highs = new PineArrayDouble();
      lows = new PineArrayDouble();
      times = new PineArrayLong();
      cVols = new PineArrayDouble();
      maxSize = 0;
      removed = NULL;
      prevProjection = NULL;
      cum_vol_tracker = 0;
      last_bar_index = -1;
      pivot_id_counter = 0;
     }

                    ~ZigZag()
     {
      delete settings;

      // Safely delete dynamic projection pivot from within the pivots container first
      if(projection != NULL)
        {
         popLastPivot();
         projection = NULL;
        }

      delete pivots;
      delete highs;
      delete lows;
      delete times;
      delete cVols;
      if(removed != NULL)
         delete removed;
      if(prevProjection != NULL)
         delete prevProjection;
     }

   void              resetSumVol()
     {
      sumVol = 0;
      sumVol_bar_start = 0;
     }

   double            calcDev(double start, double end)
     {
      if(settings != NULL && settings.differencePriceMode == "Absolute")
         return (end - start);

      return 100.0 * (end - start) / MathAbs(start);
     }

   chart_point*      findPivotPoint(PineArrayDouble* source, PineArrayLong* t_array, int bar_index, int depth, bool isHigh)
     {
      double pivotPrice = nz(source.get(depth));
      if(depth == 0)
        {
         return new chart_point((datetime)t_array.get(0), bar_index, pivotPrice);
        }
      else
         if(source.size() >= 2 * depth + 1)
           {
            bool isFound = true;
            for(int i = 0; i <= depth - 1; i++)
              {
               if((isHigh && source.get(i) > pivotPrice) || (!isHigh && source.get(i) < pivotPrice))
                 {
                  isFound = false;
                  break;
                 }
              }
            if(isFound)
              {
               for(int i = depth + 1; i <= 2 * depth; i++)
                 {
                  if((isHigh && source.get(i) >= pivotPrice) || (!isHigh && source.get(i) <= pivotPrice))
                    {
                     isFound = false;
                     break;
                    }
                 }
              }
            if(isFound)
              {
               return new chart_point((datetime)t_array.get(depth), bar_index - depth, pivotPrice);
              }
           }
      return NULL;
     }

   string            priceRotationDiff(double start, double end)
     {
      double diff = end - start;
      string sign = math_sign(diff) > 0 ? "+" : "";
      string diffStr = "";
      if(settings.differencePriceMode == "Absolute")
        {
         diffStr = DoubleToString(diff, _Digits);
        }
      else
        {
         diffStr = DoubleToString(diff * 100.0 / start, 2) + "%";
        }
      return "(" + sign + diffStr + ")";
     }

   string            priceRotationAggregate(double start, double end, double vol)
     {
      string result = "";
      if(settings.displayReversalPrice)
         result += DoubleToString(end, _Digits) + " ";
      if(settings.displayReversalPriceChange)
         result += priceRotationDiff(start, end) + " ";
      if(settings.displayCumulativeVolume)
         result += "\n" + DoubleToString(vol, 2);
      return result;
     }

   string            makePivotLabel(bool isHigh, chart_point* point, bool isProjection = false)
     {
      if(!settings.draw)
         return "";
      if(settings.displayReversalPrice || settings.displayReversalPriceChange || settings.displayCumulativeVolume)
        {
         string lb_name = isProjection ? "ZZ_Proj_Lbl" : "ZZ_Lbl_" + IntegerToString(point.index) + "_" + IntegerToString(pivot_id_counter);
         if(ObjectFind(0, lb_name) < 0)
           {
            ObjectCreate(0, lb_name, OBJ_TEXT, 0, point.time, point.price);
           }
         else
           {
            ObjectSetInteger(0, lb_name, OBJPROP_TIME, point.time);
            ObjectSetDouble(0, lb_name, OBJPROP_PRICE, point.price);
           }
         ObjectSetInteger(0, lb_name, OBJPROP_COLOR, isHigh ? clrGreen : clrRed);
         ObjectSetInteger(0, lb_name, OBJPROP_ANCHOR, isHigh ? ANCHOR_BOTTOM : ANCHOR_TOP);
         return lb_name;
        }
      return "";
     }

   void              updatePivot(Pivot* this_pivot, chart_point* end, double vol)
     {
      if(this_pivot.end != NULL && this_pivot.end != end)
         delete this_pivot.end;
      this_pivot.end = new chart_point(end.time, end.index, end.price);
      this_pivot.vol = vol;

      if(this_pivot.lb != "")
        {
         ObjectSetInteger(0, this_pivot.lb, OBJPROP_TIME, this_pivot.end.time);
         ObjectSetDouble(0, this_pivot.lb, OBJPROP_PRICE, this_pivot.end.price);
         ObjectSetString(0, this_pivot.lb, OBJPROP_TEXT, priceRotationAggregate(this_pivot.start.price, this_pivot.end.price, this_pivot.vol));
        }
      if(this_pivot.ln != "")
        {
         ObjectSetInteger(0, this_pivot.ln, OBJPROP_TIME, 1, this_pivot.end.time);
         ObjectSetDouble(0, this_pivot.ln, OBJPROP_PRICE, 1, this_pivot.end.price);
        }
     }

   Pivot*            newPivot(chart_point* start, chart_point* end, double vol, bool isHigh, bool isProjection = false)
     {
      string ln_name = "";
      string lb_name = "";
      pivot_id_counter++;

      if(settings.draw && start.time >= drawStartTime)
        {
         ln_name = isProjection ? "ZZ_Proj_Ln" : "ZZ_Ln_" + IntegerToString(start.index) + "_" + IntegerToString(end.index) + "_" + IntegerToString(pivot_id_counter);
         if(ObjectFind(0, ln_name) < 0)
           {
            ObjectCreate(0, ln_name, OBJ_TREND, 0, start.time, start.price, end.time, end.price);
           }
         else
           {
            ObjectSetInteger(0, ln_name, OBJPROP_TIME, 0, start.time);
            ObjectSetDouble(0, ln_name, OBJPROP_PRICE, 0, start.price);
            ObjectSetInteger(0, ln_name, OBJPROP_TIME, 1, end.time);
            ObjectSetDouble(0, ln_name, OBJPROP_PRICE, 1, end.price);
           }
         ObjectSetInteger(0, ln_name, OBJPROP_COLOR, settings.lineColor);
         ObjectSetInteger(0, ln_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, ln_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, ln_name, OBJPROP_STYLE, isProjection ? STYLE_DASH : STYLE_SOLID);

         lb_name = makePivotLabel(isHigh, end, isProjection);
        }

      Pivot* p = new Pivot(ln_name, lb_name, isHigh, vol, new chart_point(start.time, start.index, start.price), new chart_point(end.time, end.index, end.price));
      updatePivot(p, end, vol);
      return p;
     }

   bool              isMorePrice(Pivot* this_pivot, chart_point* point)
     {
      int m = this_pivot.isHigh ? 1 : -1;
      return (point.price * m > this_pivot.end.price * m);
     }

   Pivot*            lastPivot()
     {
      if(pivots.Total() > 0)
         return (Pivot*)pivots.At(pivots.Total() - 1);
      return NULL;
     }

   double            updateLastPivot(chart_point* point)
     {
      Pivot* lastPivot_obj = lastPivot();
      if(pivots.Total() == 1)
        {
         lastPivot_obj.start.time = point.time;
         lastPivot_obj.start.index = point.index;
         lastPivot_obj.start.price = point.price;
         if(settings.draw && lastPivot_obj.ln != "" && StringFind(lastPivot_obj.ln, "ZZ_Proj") < 0)
           {
            ObjectSetInteger(0, lastPivot_obj.ln, OBJPROP_TIME, 0, point.time);
            ObjectSetDouble(0, lastPivot_obj.ln, OBJPROP_PRICE, 0, point.price);
           }
        }
      updatePivot(lastPivot_obj, point, lastPivot_obj.vol + sumVol);
      resetSumVol();
      return 0.0;
     }

   double            newPivotFound(Pivot* _new)
     {
      pivots.Add(_new);
      resetSumVol();
      return 0.0;
     }

   bool              newPivotPointFound(bool isHigh, chart_point* point)
     {
      bool result = false;
      Pivot* lastPivot_obj = lastPivot();
      if(lastPivot_obj != NULL)
        {
         if(lastPivot_obj.isHigh == isHigh)
           {
            if(isMorePrice(lastPivot_obj, point))
              {
               updateLastPivot(point);
               result = true;
              }
           }
         else
           {
            double dev = calcDev(lastPivot_obj.end.price, point.price);
            if((!lastPivot_obj.isHigh && dev >= settings.devThreshold) ||
               (lastPivot_obj.isHigh && dev <= -1 * settings.devThreshold))
              {
               newPivotFound(newPivot(lastPivot_obj.end, point, sumVol, isHigh));
               result = true;
              }
           }
        }
      else
        {
         newPivotFound(newPivot(point, point, sumVol, isHigh));
         result = true;
        }
      return result;
     }

   bool              tryFindPivot(PineArrayDouble* source, bool isHigh, int depth, int current_bar_index, bool registerPivot = true)
     {
      chart_point* point = findPivotPoint(source, times, current_bar_index, depth, isHigh);
      bool result = false;
      if(point != NULL && registerPivot)
        {
         result = newPivotPointFound(isHigh, point);
        }
      if(point != NULL && !result)
         delete point;
      return result;
     }

   void              popLastPivot()
     {
      if(pivots.Total() > 0)
        {
         int last_idx = pivots.Total() - 1;
         pivots.Delete(last_idx);
        }
     }

   chart_point*      findProjectionPivot(bool isHigh, int depth, chart_point* lastPivotEnd, double devThreshold_val, PineArrayDouble* prices, PineArrayLong* t_array, int bar_index)
     {
      chart_point* result = NULL;
      int n = prices.size();
      if(n > 0)
        {
         int slice_len = bar_index - lastPivotEnd.index;
         if(slice_len <= 0)
            return NULL;

         PineArrayDouble* slice = prices.slice(0, slice_len);
         double extreme = isHigh ? slice.max() : slice.min();
         int ind = slice.indexof(extreme);
         delete slice;

         int dir = isHigh ? 1 : -1;
         bool valid = (ind + depth < n) && (dir * calcDev(lastPivotEnd.price, extreme) >= devThreshold_val);

         if(valid)
           {
            for(int i = 1; i <= depth; i++)
              {
               int lIndex = ind + i;
               if(lIndex >= n)
                  continue;
               double v = prices.get(lIndex);
               if((isHigh && v >= extreme) || (!isHigh && v <= extreme))
                 {
                  valid = false;
                  break;
                 }
              }
           }
         if(valid)
           {
            result = new chart_point((datetime)t_array.get(ind), bar_index - ind, extreme);
           }
         else
           {
            for(int i = bar_index; i >= lastPivotEnd.index + 1; i--)
              {
               if(i == bar_index - ind)
                  continue;
               int pIndex = bar_index - i;
               if(pIndex < 0 || pIndex >= n || pIndex + depth >= n)
                  continue;

               double candidate = prices.get(pIndex);
               if(dir * calcDev(lastPivotEnd.price, candidate) < devThreshold_val)
                  continue;

               bool okRight = true;
               if(pIndex > 0)
                 {
                  for(int j = 1; j <= MathMin(depth, pIndex); j++)
                    {
                     int rIndex = pIndex - j;
                     double v = prices.get(rIndex);
                     if((isHigh && v > candidate) || (!isHigh && v < candidate))
                       {
                        okRight = false;
                        break;
                       }
                    }
                 }
               if(!okRight)
                  continue;

               bool okLeft = true;
               for(int j = 1; j <= depth; j++)
                 {
                  int lIndex = pIndex + j;
                  if(lIndex >= n)
                     continue;
                  double v = prices.get(lIndex);
                  if((isHigh && v >= candidate) || (!isHigh && v <= candidate))
                    {
                     okLeft = false;
                     break;
                    }
                 }
               if(!okLeft)
                  continue;

               if(result == NULL || (isHigh && result.price < candidate) || (!isHigh && result.price > candidate))
                 {
                  if(result != NULL)
                     delete result;
                  result = new chart_point((datetime)t_array.get(pIndex), i, candidate);
                  if(candidate == extreme)
                     break;
                 }
              }
           }
        }

      if(result == NULL && settings.projectionPivots && n > 0 && bar_index > lastPivotEnd.index)
        {
         int slice_len = bar_index - lastPivotEnd.index;
         PineArrayDouble* slice = prices.slice(0, slice_len);
         double extreme = isHigh ? slice.max() : slice.min();
         int ind = slice.indexof(extreme);
         delete slice;

         int dir = isHigh ? 1 : -1;
         if(dir * calcDev(lastPivotEnd.price, extreme) >= devThreshold_val)
           {
            result = new chart_point((datetime)t_array.get(ind), bar_index - ind, extreme);
           }
        }

      return result;
     }

   void              updateProjectionPivot(chart_point* projectionPoint, bool isHigh, double projVol)
     {
      if(settings.projectionPivots)
        {
         Pivot* last = lastPivot();
         projection = newPivot(last.end, projectionPoint, projVol, isHigh, true);
         pivots.Add(projection);
        }
     }

   bool              update(double high, double low, datetime time, long volume, int bar_index, bool is_history, bool is_last)
     {
      if(bar_index == last_bar_index)
        {
         highs.set(0, high);
         lows.set(0, low);
         times.set(0, (long)time);
         cum_vol_tracker = (cVols.size() > 1 ? cVols.get(1) : 0) + (double)volume;
         cVols.set(0, cum_vol_tracker);
         sumVol = sumVol_bar_start + (double)volume;
        }
      else
        {
         highs.unshift(high);
         lows.unshift(low);
         times.unshift((long)time);
         cum_vol_tracker += (double)volume;
         cVols.unshift(cum_vol_tracker);
         sumVol_bar_start = sumVol;
         sumVol = sumVol_bar_start + (double)volume;
         last_bar_index = bar_index;
        }
      // Dynamic minimum depth assignment to protect standard charts from noise
      int min_depth = 2;

      if(settings.differencePriceMode == "Absolute")
        {
         if(settings.devThreshold < 2.0)
            min_depth = 1;
        }
      else // "Percent" mode
        {
         if(settings.devThreshold < 0.2)
            min_depth = 1;
        }

      int depth = MathMax(min_depth, (int)MathFloor(settings.depth / 2.0));


      bool had_projection = false;
      if(projection != NULL)
        {
         popLastPivot();
         projection = NULL;
         had_projection = true;
        }

      int size = pivots.Total();
      maxSize = MathMax(maxSize, size);

      bool newHigh = tryFindPivot(highs, true, depth, bar_index);
      bool newLow  = tryFindPivot(lows, false, depth, bar_index, settings.allowZigZagOnOneBar || !newHigh);
      bool invalidated = false;
      double threshold = settings.devThreshold;

      // Restrict all calculation of projection pivots strictly to the last bar (live ticks)
      if(settings.projectionPivots && is_last)
        {
         if(!(newHigh || newLow))
           {
            Pivot* last = lastPivot();
            if(last != NULL && prevProjection == NULL)
              {
               double extreme;
               if(last.isHigh)
                 {
                  PineArrayDouble* slice = highs.slice(0, bar_index - last.end.index);
                  extreme = is_history ? slice.max() : high;
                  delete slice;
                 }
               else
                 {
                  PineArrayDouble* slice = lows.slice(0, bar_index - last.end.index);
                  extreme = is_history ? slice.min() : low;
                  delete slice;
                 }

               chart_point* cp_now = chart_point::now(extreme, time, bar_index);
               if(size == maxSize && isMorePrice(last, cp_now))
                 {
                  sumVol += last.vol;
                  sumVol_bar_start += last.vol;

                  if(removed != NULL)
                     delete removed;
                  removed = new Pivot(last.ln, last.lb, last.isHigh, last.vol, new chart_point(last.start.time, last.start.index, last.start.price), new chart_point(last.end.time, last.end.index, last.end.price));

                  popLastPivot();
                  invalidated = true;
                  last = lastPivot();
                 }
               delete cp_now;
              }

            if(last != NULL)
              {
               bool nextIsHigh = !last.isHigh;
               chart_point* projectionPoint = findProjectionPivot(nextIsHigh, depth, last.end, threshold, nextIsHigh ? highs : lows, times, bar_index);

               if(projectionPoint != NULL)
                 {
                  int startOff  = bar_index - last.end.index;
                  int endOff    = bar_index - projectionPoint.index;
                  double projVol = cVols.get(endOff) - cVols.get(startOff);
                  updateProjectionPivot(projectionPoint, nextIsHigh, projVol);
                 }

               if(removed != NULL)
                 {
                  bool checkHigh = !removed.isHigh;
                  chart_point* revProjection = findProjectionPivot(checkHigh, depth, removed.end, threshold, checkHigh ? highs : lows, times, bar_index);

                  if(revProjection != NULL && projectionPoint != NULL && projectionPoint.index < revProjection.index)
                    {
                     delete revProjection;
                     revProjection = NULL;
                    }

                  if(revProjection != NULL)
                    {
                     if(projection != NULL)
                       {
                        popLastPivot();
                        projection = NULL;
                       }

                     Pivot* rev = newPivot(removed.start, removed.end, removed.vol, removed.isHigh);
                     sumVol -= rev.vol;
                     sumVol_bar_start -= rev.vol;

                     if(rev.isHigh)
                        newHigh = true;
                     else
                        newLow = true;

                     pivots.Add(rev);
                     delete removed;
                     removed = NULL;

                     int startOff  = bar_index - rev.end.index;
                     int endOff    = bar_index - revProjection.index;
                     double projVol = cVols.get(endOff) - cVols.get(startOff);
                     updateProjectionPivot(revProjection, checkHigh, projVol);
                    }
                 }

               if(prevProjection != NULL)
                  delete prevProjection;
               if(projectionPoint != NULL)
                 {
                  prevProjection = new chart_point(projectionPoint.time, projectionPoint.index, projectionPoint.price);
                  delete projectionPoint;
                 }
               else
                 {
                  prevProjection = NULL;
                 }
              }
           }
         else
           {
            if(prevProjection != NULL)
              {
               delete prevProjection;
               prevProjection = NULL;
              }
            if(removed != NULL)
              {
               delete removed;
               removed = NULL;
              }
           }
        }

      if(had_projection && projection == NULL)
        {
         ObjectDelete(0, "ZZ_Proj_Ln");
         ObjectDelete(0, "ZZ_Proj_Lbl");
        }

      return (invalidated || newHigh || newLow);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ZigZag* newInstance(Settings* custom_settings = NULL)
  {
   if(custom_settings == NULL)
     {
      return new ZigZag(new Settings());
     }
   else
     {
      return new ZigZag(custom_settings);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMarketMetrics* GetZigZagMetrics(ZigZag* zz)
  {
   CMarketMetrics* metrics = new CMarketMetrics();
   if(zz != NULL && zz.pivots.Total() > 0)
     {
      Pivot* last = zz.lastPivot();
      if(last != NULL)
        {
         metrics.lastReversalPrice = last.end.price;
         metrics.lastReversalPriceChange = last.end.price - last.start.price;
         metrics.cumulativeVolume = last.vol;
        }
     }
   return metrics;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\ZigZag.mqh
