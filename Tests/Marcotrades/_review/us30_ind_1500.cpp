
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cfloat>
#include <ctime>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>
#include <set>
using string=std::string;using datetime=long long;using color=int;using ENUM_TIMEFRAMES=int;using uint=unsigned int;
const double EMPTY_VALUE=DBL_MAX;const double _Point=.1;const int _Digits=1;const int _Period=1;const string _Symbol="US30c";
struct CObject {virtual ~CObject()=default;};
template<class T> struct MArray {MArray* operator->(){return this;} std::vector<T> v;
 int Total(){return int(v.size());}T At(int i){return i>=0&&i<Total()?v[i]:T{};}
 bool Add(T x){v.push_back(x);return true;}void Clear(){v.clear();}
 bool Update(int i,T x){if(i<0||i>=Total())return false;v[i]=x;return true;}
 bool Delete(int i){if(i<0||i>=Total())return false;v.erase(v.begin()+i);return true;}
 int Search(T x){auto p=std::find(v.begin(),v.end(),x);return p==v.end()?-1:int(p-v.begin());}
};
using CArrayLong=MArray<long>;using CArrayInt=MArray<int>;using CArrayDouble=MArray<double>;using CArrayString=MArray<string>;
struct CArrayObj:MArray<CObject*> {bool owns=true;void FreeMode(bool x){owns=x;}
 void Clear(){if(owns)for(auto x:v)delete x;v.clear();}
 bool Delete(int i){if(i<0||i>=Total())return false;if(owns)delete v[i];v.erase(v.begin()+i);return true;}
 CObject* Detach(int i){if(i<0||i>=Total())return nullptr;auto p=v[i];v.erase(v.begin()+i);return p;}
 ~CArrayObj(){Clear();}
};
template<class T> int CheckPointer(T*p){return p?1:0;}
template<class T> T* GetPointer(T&x){return &x;}
template<class T> void ArrayFree(std::vector<T>&v){v.clear();}
template<class T> int ArrayMaximum(const std::vector<T>&v){return v.empty()?-1:int(std::max_element(v.begin(),v.end())-v.begin());}
template<class T> int ArrayMinimum(const std::vector<T>&v){return v.empty()?-1:int(std::min_element(v.begin(),v.end())-v.begin());}
template<class T> int ArraySize(const std::vector<T>&v){return int(v.size());}
template<class T> int ArrayResize(std::vector<T>&v,int n,int=0){v.resize(n);return n;}
template<class T,class V> void ArrayInitialize(std::vector<T>&v,V x){std::fill(v.begin(),v.end(),x);}
double MathMax(double a,double b){return std::max(a,b);}double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}double MathFloor(double a){return std::floor(a);}
double MathCeil(double a){return std::ceil(a);}bool MathIsValidNumber(double a){return std::isfinite(a);}
template<class T>void ZeroMemory(T&v){v=T{};}
double NormalizeDouble(double a,int d){double k=std::pow(10.,d);return std::round(a*k)/k;}
int StringLen(string s){return int(s.size());}int StringFind(string s,string q){auto p=s.find(q);return p==string::npos?-1:int(p);}
string StringSubstr(string s,int p,int n=2147483647){return s.substr(p,n);}
string IntegerToString(long long x){return std::to_string(x);}string DoubleToString(double x,int d){std::ostringstream s;s<<std::fixed<<std::setprecision(d)<<x;return s.str();}
string TimeToString(datetime t,int=0){time_t n=t;char b[30];std::strftime(b,sizeof(b),"%Y.%m.%d %H:%M",std::gmtime(&n));return b;}
string EnumToString(int tf){return std::to_string(tf);}int PeriodSeconds(int tf){return tf*60;}datetime TimeCurrent(){return 1794528000;}
template<class...A>void Print(A...){}template<class...A>void PrintFormat(A...){}
template<class...A>int ObjectFind(A...){return -1;}template<class...A>bool ObjectDelete(A...){return true;}
template<class...A>void ObjectsDeleteAll(A...){}template<class...A>void ObjectSetString(A...){}
template<class...A>void ObjectSetInteger(A...){}template<class...A>void ObjectSetDouble(A...){}
template<class...A>void ObjectMove(A...){}template<class...A>void ObjectCreate(A...){}
template<class...A>double SymbolInfoDouble(A...){return 0;}
template<class...A>int CopyTickVolume(A...){return 0;}template<class...A>int CopyRealVolume(A...){return 0;}
template<class...A>double ObjectGetDouble(A...){return 0;}
struct Plotter {template<class...A>static void DrawLine(A...){}template<class...A>static void DrawLabel(A...){}
 template<class...A>static void DrawBox(A...){} };

enum {ANCHOR_BOTTOM=0,ANCHOR_LOWER=0,ANCHOR_TOP=0,ANCHOR_UPPER=0,OBJPROP_ANCHOR=0,OBJPROP_COLOR=0,OBJPROP_PRICE=0,OBJPROP_RAY_RIGHT=0,OBJPROP_STYLE=0,OBJPROP_TEXT=0,OBJPROP_TIME=0,OBJPROP_WIDTH=0,OBJ_TEXT=0,OBJ_TREND=0,PERIOD_CURRENT=0,PERIOD_M1=1,POINTER_DYNAMIC=1,STYLE_DASH=0,STYLE_SOLID=0,SYMBOL_ASK=0,SYMBOL_BID=0,TIME_DATE=0,TIME_SECONDS=0,TRADE_RETCODE_DONE=0,TRADE_RETCODE_DONE_PARTIAL=0,TRADE_RETCODE_PLACED=0,TRADE_RETCODE_TIMEOUT=0,clrBlue=0,clrGreen=0,clrRed=0};
//+------------------------------------------------------------------+
//|                                        Include\Custom\ZigZag\ZigZag.mqh |
//|                                     Converted from TradingView v9|
//+------------------------------------------------------------------+




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
  { public: CMarketMetrics* operator->(){return this;} const CMarketMetrics* operator->()const{return this;}
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

      std::vector<long> tick_vol_arr, real_vol_arr;
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
  { public: PineArrayDouble* operator->(){return this;} const PineArrayDouble* operator->()const{return this;}
public:
   std::vector<double> m_data;
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
         ArrayResize(res->m_data, len);
         for(int i = 0; i < len; i++)
            res->m_data[i] = m_data[start + i];
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
  { public: PineArrayLong* operator->(){return this;} const PineArrayLong* operator->()const{return this;}
public:
   std::vector<long> m_data;
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
  { public: chart_point* operator->(){return this;} const chart_point* operator->()const{return this;}
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
  { public: Settings* operator->(){return this;} const Settings* operator->()const{return this;}
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
  { public: Pivot* operator->(){return this;} const Pivot* operator->()const{return this;}
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
  { public: ZigZag* operator->(){return this;} const ZigZag* operator->()const{return this;}
public:
   Settings*         settings;
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
      pivots   = new CArrayObj();
      pivots->FreeMode(true);
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
      if(settings != NULL && settings->differencePriceMode == "Absolute")
         return (end - start);

      return 100.0 * (end - start) / MathAbs(start);
     }

   chart_point*      findPivotPoint(PineArrayDouble* source, PineArrayLong* t_array, int bar_index, int depth, bool isHigh)
     {
      double pivotPrice = nz(source->get(depth));
      if(depth == 0)
        {
         return new chart_point((datetime)t_array->get(0), bar_index, pivotPrice);
        }
      else
         if(source->size() >= 2 * depth + 1)
           {
            bool isFound = true;
            for(int i = 0; i <= depth - 1; i++)
              {
               if((isHigh && source->get(i) > pivotPrice) || (!isHigh && source->get(i) < pivotPrice))
                 {
                  isFound = false;
                  break;
                 }
              }
            if(isFound)
              {
               for(int i = depth + 1; i <= 2 * depth; i++)
                 {
                  if((isHigh && source->get(i) >= pivotPrice) || (!isHigh && source->get(i) <= pivotPrice))
                    {
                     isFound = false;
                     break;
                    }
                 }
              }
            if(isFound)
              {
               return new chart_point((datetime)t_array->get(depth), bar_index - depth, pivotPrice);
              }
           }
      return NULL;
     }

   string            priceRotationDiff(double start, double end)
     {
      double diff = end - start;
      string sign = math_sign(diff) > 0 ? "+" : "";
      string diffStr = "";
      if(settings->differencePriceMode == "Absolute")
        {
         diffStr = DoubleToString(diff, _Digits);
        }
      else
        {
         diffStr = DoubleToString(diff * 100.0 / start, 2) + "%";
        }
      return string("(") + sign + diffStr + ")";
     }

   string            priceRotationAggregate(double start, double end, double vol)
     {
      string result = "";
      if(settings->displayReversalPrice)
         result += DoubleToString(end, _Digits) + " ";
      if(settings->displayReversalPriceChange)
         result += priceRotationDiff(start, end) + " ";
      if(settings->displayCumulativeVolume)
         result += string("\n") + DoubleToString(vol, 2);
      return result;
     }

   string            makePivotLabel(bool isHigh, chart_point* point, bool isProjection = false)
     {
      if(!settings->draw)
         return "";
      if(settings->displayReversalPrice || settings->displayReversalPriceChange || settings->displayCumulativeVolume)
        {
         string lb_name = isProjection ? "ZZ_Proj_Lbl" : string("ZZ_Lbl_") + IntegerToString(point->index) + string("_") + IntegerToString(pivot_id_counter);
         if(ObjectFind(0, lb_name) < 0)
           {
            ObjectCreate(0, lb_name, OBJ_TEXT, 0, point->time, point->price);
           }
         else
           {
            ObjectSetInteger(0, lb_name, OBJPROP_TIME, point->time);
            ObjectSetDouble(0, lb_name, OBJPROP_PRICE, point->price);
           }
         ObjectSetInteger(0, lb_name, OBJPROP_COLOR, isHigh ? clrGreen : clrRed);
         ObjectSetInteger(0, lb_name, OBJPROP_ANCHOR, isHigh ? ANCHOR_BOTTOM : ANCHOR_TOP);
         return lb_name;
        }
      return "";
     }

   void              updatePivot(Pivot* this_pivot, chart_point* end, double vol)
     {
      if(this_pivot->end != NULL && this_pivot->end != end)
         delete this_pivot->end;
      this_pivot->end = new chart_point(end->time, end->index, end->price);
      this_pivot->vol = vol;

      if(this_pivot->lb != "")
        {
         ObjectSetInteger(0, this_pivot->lb, OBJPROP_TIME, this_pivot->end->time);
         ObjectSetDouble(0, this_pivot->lb, OBJPROP_PRICE, this_pivot->end->price);
         ObjectSetString(0, this_pivot->lb, OBJPROP_TEXT, priceRotationAggregate(this_pivot->start->price, this_pivot->end->price, this_pivot->vol));
        }
      if(this_pivot->ln != "")
        {
         ObjectSetInteger(0, this_pivot->ln, OBJPROP_TIME, 1, this_pivot->end->time);
         ObjectSetDouble(0, this_pivot->ln, OBJPROP_PRICE, 1, this_pivot->end->price);
        }
     }

   Pivot*            newPivot(chart_point* start, chart_point* end, double vol, bool isHigh, bool isProjection = false)
     {
      string ln_name = "";
      string lb_name = "";
      pivot_id_counter++;

      if(settings->draw)
        {
         ln_name = isProjection ? "ZZ_Proj_Ln" : string("ZZ_Ln_") + IntegerToString(start->index) + string("_") + IntegerToString(end->index) + string("_") + IntegerToString(pivot_id_counter);
         if(ObjectFind(0, ln_name) < 0)
           {
            ObjectCreate(0, ln_name, OBJ_TREND, 0, start->time, start->price, end->time, end->price);
           }
         else
           {
            ObjectSetInteger(0, ln_name, OBJPROP_TIME, 0, start->time);
            ObjectSetDouble(0, ln_name, OBJPROP_PRICE, 0, start->price);
            ObjectSetInteger(0, ln_name, OBJPROP_TIME, 1, end->time);
            ObjectSetDouble(0, ln_name, OBJPROP_PRICE, 1, end->price);
           }
         ObjectSetInteger(0, ln_name, OBJPROP_COLOR, settings->lineColor);
         ObjectSetInteger(0, ln_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, ln_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, ln_name, OBJPROP_STYLE, isProjection ? STYLE_DASH : STYLE_SOLID);

         lb_name = makePivotLabel(isHigh, end, isProjection);
        }

      Pivot* p = new Pivot(ln_name, lb_name, isHigh, vol, new chart_point(start->time, start->index, start->price), new chart_point(end->time, end->index, end->price));
      updatePivot(p, end, vol);
      return p;
     }

   bool              isMorePrice(Pivot* this_pivot, chart_point* point)
     {
      int m = this_pivot->isHigh ? 1 : -1;
      return (point->price * m > this_pivot->end->price * m);
     }

   Pivot*            lastPivot()
     {
      if(pivots->Total() > 0)
         return (Pivot*)pivots->At(pivots->Total() - 1);
      return NULL;
     }

   double            updateLastPivot(chart_point* point)
     {
      Pivot* lastPivot_obj = lastPivot();
      if(pivots->Total() == 1)
        {
         lastPivot_obj->start->time = point->time;
         lastPivot_obj->start->index = point->index;
         lastPivot_obj->start->price = point->price;
         if(settings->draw && lastPivot_obj->ln != "" && StringFind(lastPivot_obj->ln, "ZZ_Proj") < 0)
           {
            ObjectSetInteger(0, lastPivot_obj->ln, OBJPROP_TIME, 0, point->time);
            ObjectSetDouble(0, lastPivot_obj->ln, OBJPROP_PRICE, 0, point->price);
           }
        }
      updatePivot(lastPivot_obj, point, lastPivot_obj->vol + sumVol);
      resetSumVol();
      return 0.0;
     }

   double            newPivotFound(Pivot* _new)
     {
      pivots->Add(_new);
      resetSumVol();
      return 0.0;
     }

   bool              newPivotPointFound(bool isHigh, chart_point* point)
     {
      bool result = false;
      Pivot* lastPivot_obj = lastPivot();
      if(lastPivot_obj != NULL)
        {
         if(lastPivot_obj->isHigh == isHigh)
           {
            if(isMorePrice(lastPivot_obj, point))
              {
               updateLastPivot(point);
               result = true;
              }
           }
         else
           {
            double dev = calcDev(lastPivot_obj->end->price, point->price);
            if((!lastPivot_obj->isHigh && dev >= settings->devThreshold) ||
               (lastPivot_obj->isHigh && dev <= -1 * settings->devThreshold))
              {
               newPivotFound(newPivot(lastPivot_obj->end, point, sumVol, isHigh));
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
      if(pivots->Total() > 0)
        {
         int last_idx = pivots->Total() - 1;
         pivots->Delete(last_idx);
        }
     }

   chart_point*      findProjectionPivot(bool isHigh, int depth, chart_point* lastPivotEnd, double devThreshold_val, PineArrayDouble* prices, PineArrayLong* t_array, int bar_index)
     {
      chart_point* result = NULL;
      int n = prices->size();
      if(n > 0)
        {
         int slice_len = bar_index - lastPivotEnd->index;
         if(slice_len <= 0)
            return NULL;

         PineArrayDouble* slice = prices->slice(0, slice_len);
         double extreme = isHigh ? slice->max() : slice->min();
         int ind = slice->indexof(extreme);
         delete slice;

         int dir = isHigh ? 1 : -1;
         bool valid = (ind + depth < n) && (dir * calcDev(lastPivotEnd->price, extreme) >= devThreshold_val);

         if(valid)
           {
            for(int i = 1; i <= depth; i++)
              {
               int lIndex = ind + i;
               if(lIndex >= n)
                  continue;
               double v = prices->get(lIndex);
               if((isHigh && v >= extreme) || (!isHigh && v <= extreme))
                 {
                  valid = false;
                  break;
                 }
              }
           }
         if(valid)
           {
            result = new chart_point((datetime)t_array->get(ind), bar_index - ind, extreme);
           }
         else
           {
            for(int i = bar_index; i >= lastPivotEnd->index + 1; i--)
              {
               if(i == bar_index - ind)
                  continue;
               int pIndex = bar_index - i;
               if(pIndex < 0 || pIndex >= n || pIndex + depth >= n)
                  continue;

               double candidate = prices->get(pIndex);
               if(dir * calcDev(lastPivotEnd->price, candidate) < devThreshold_val)
                  continue;

               bool okRight = true;
               if(pIndex > 0)
                 {
                  for(int j = 1; j <= MathMin(depth, pIndex); j++)
                    {
                     int rIndex = pIndex - j;
                     double v = prices->get(rIndex);
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
                  double v = prices->get(lIndex);
                  if((isHigh && v >= candidate) || (!isHigh && v <= candidate))
                    {
                     okLeft = false;
                     break;
                    }
                 }
               if(!okLeft)
                  continue;

               if(result == NULL || (isHigh && result->price < candidate) || (!isHigh && result->price > candidate))
                 {
                  if(result != NULL)
                     delete result;
                  result = new chart_point((datetime)t_array->get(pIndex), i, candidate);
                  if(candidate == extreme)
                     break;
                 }
              }
           }
        }

      if(result == NULL && settings->projectionPivots && n > 0 && bar_index > lastPivotEnd->index)
        {
         int slice_len = bar_index - lastPivotEnd->index;
         PineArrayDouble* slice = prices->slice(0, slice_len);
         double extreme = isHigh ? slice->max() : slice->min();
         int ind = slice->indexof(extreme);
         delete slice;

         int dir = isHigh ? 1 : -1;
         if(dir * calcDev(lastPivotEnd->price, extreme) >= devThreshold_val)
           {
            result = new chart_point((datetime)t_array->get(ind), bar_index - ind, extreme);
           }
        }

      return result;
     }

   void              updateProjectionPivot(chart_point* projectionPoint, bool isHigh, double projVol)
     {
      if(settings->projectionPivots)
        {
         Pivot* last = lastPivot();
         projection = newPivot(last->end, projectionPoint, projVol, isHigh, true);
         pivots->Add(projection);
        }
     }

   bool              update(double high, double low, datetime time, long volume, int bar_index, bool is_history, bool is_last)
     {
      if(bar_index == last_bar_index)
        {
         highs->set(0, high);
         lows->set(0, low);
         times->set(0, (long)time);
         cum_vol_tracker = (cVols->size() > 1 ? cVols->get(1) : 0) + (double)volume;
         cVols->set(0, cum_vol_tracker);
         sumVol = sumVol_bar_start + (double)volume;
        }
      else
        {
         highs->unshift(high);
         lows->unshift(low);
         times->unshift((long)time);
         cum_vol_tracker += (double)volume;
         cVols->unshift(cum_vol_tracker);
         sumVol_bar_start = sumVol;
         sumVol = sumVol_bar_start + (double)volume;
         last_bar_index = bar_index;
        }
      // Dynamic minimum depth assignment to protect standard charts from noise
      int min_depth = 2;

      if(settings->differencePriceMode == "Absolute")
        {
         if(settings->devThreshold < 2.0)
            min_depth = 1;
        }
      else // "Percent" mode
        {
         if(settings->devThreshold < 0.2)
            min_depth = 1;
        }

      int depth = MathMax(min_depth, (int)MathFloor(settings->depth / 2.0));


      bool had_projection = false;
      if(projection != NULL)
        {
         popLastPivot();
         projection = NULL;
         had_projection = true;
        }

      int size = pivots->Total();
      maxSize = MathMax(maxSize, size);

      bool newHigh = tryFindPivot(highs, true, depth, bar_index);
      bool newLow  = tryFindPivot(lows, false, depth, bar_index, settings->allowZigZagOnOneBar || !newHigh);
      bool invalidated = false;
      double threshold = settings->devThreshold;

      // Restrict all calculation of projection pivots strictly to the last bar (live ticks)
      if(settings->projectionPivots && is_last)
        {
         if(!(newHigh || newLow))
           {
            Pivot* last = lastPivot();
            if(last != NULL && prevProjection == NULL)
              {
               double extreme;
               if(last->isHigh)
                 {
                  PineArrayDouble* slice = highs->slice(0, bar_index - last->end->index);
                  extreme = is_history ? slice->max() : high;
                  delete slice;
                 }
               else
                 {
                  PineArrayDouble* slice = lows->slice(0, bar_index - last->end->index);
                  extreme = is_history ? slice->min() : low;
                  delete slice;
                 }

               chart_point* cp_now = chart_point::now(extreme, time, bar_index);
               if(size == maxSize && isMorePrice(last, cp_now))
                 {
                  sumVol += last->vol;
                  sumVol_bar_start += last->vol;

                  if(removed != NULL)
                     delete removed;
                  removed = new Pivot(last->ln, last->lb, last->isHigh, last->vol, new chart_point(last->start->time, last->start->index, last->start->price), new chart_point(last->end->time, last->end->index, last->end->price));

                  popLastPivot();
                  invalidated = true;
                  last = lastPivot();
                 }
               delete cp_now;
              }

            if(last != NULL)
              {
               bool nextIsHigh = !last->isHigh;
               chart_point* projectionPoint = findProjectionPivot(nextIsHigh, depth, last->end, threshold, nextIsHigh ? highs : lows, times, bar_index);

               if(projectionPoint != NULL)
                 {
                  int startOff  = bar_index - last->end->index;
                  int endOff    = bar_index - projectionPoint->index;
                  double projVol = cVols->get(endOff) - cVols->get(startOff);
                  updateProjectionPivot(projectionPoint, nextIsHigh, projVol);
                 }

               if(removed != NULL)
                 {
                  bool checkHigh = !removed->isHigh;
                  chart_point* revProjection = findProjectionPivot(checkHigh, depth, removed->end, threshold, checkHigh ? highs : lows, times, bar_index);

                  if(revProjection != NULL && projectionPoint != NULL && projectionPoint->index < revProjection->index)
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

                     Pivot* rev = newPivot(removed->start, removed->end, removed->vol, removed->isHigh);
                     sumVol -= rev->vol;
                     sumVol_bar_start -= rev->vol;

                     if(rev->isHigh)
                        newHigh = true;
                     else
                        newLow = true;

                     pivots->Add(rev);
                     delete removed;
                     removed = NULL;

                     int startOff  = bar_index - rev->end->index;
                     int endOff    = bar_index - revProjection->index;
                     double projVol = cVols->get(endOff) - cVols->get(startOff);
                     updateProjectionPivot(revProjection, checkHigh, projVol);
                    }
                 }

               if(prevProjection != NULL)
                  delete prevProjection;
               if(projectionPoint != NULL)
                 {
                  prevProjection = new chart_point(projectionPoint->time, projectionPoint->index, projectionPoint->price);
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
   if(zz != NULL && zz->pivots->Total() > 0)
     {
      Pivot* last = zz->lastPivot();
      if(last != NULL)
        {
         metrics->lastReversalPrice = last->end->price;
         metrics->lastReversalPriceChange = last->end->price - last->start->price;
         metrics->cumulativeVolume = last->vol;
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

//+------------------------------------------------------------------+
//|                            Include\Custom\ZigZag\market_structure.mqh   |
//|                 Market Structure Engine (BOS, CHoCH, Swings)     |
//+------------------------------------------------------------------+



#ifndef MARKET_STRUCTURE_MQH
#define MARKET_STRUCTURE_MQH







// Structural event tracking model
struct StructuralEvent
  { public: StructuralEvent* operator->(){return this;} const StructuralEvent* operator->()const{return this;}
   datetime          time;
   string            name;
   datetime          lineStartTime;
   datetime          lineEndTime;
  };

//+------------------------------------------------------------------+
//| Market Structure Engine Class                                    |
//+------------------------------------------------------------------+
class CMarketStructure
  { public: CMarketStructure* operator->(){return this;} const CMarketStructure* operator->()const{return this;}
public:
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

      if(zz == NULL || zz->pivots->Total() == 0)
         return;

      for(int j = 0; j < zz->pivots->Total(); j++)
        {
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(zz->projection != NULL && p == zz->projection)
            continue;

         if(p->end->time >= targetTime && p->end->time <= currentTime)
           {
            if(p->isHigh)
              {
               if(pullbackHigh == EMPTY_VALUE || p->end->price > pullbackHigh)
                 {
                  pullbackHigh = p->end->price;
                  pullbackHighTime = p->end->time;
                 }
              }
            else
              {
               if(pullbackLow == EMPTY_VALUE || p->end->price < pullbackLow)
                 {
                  pullbackLow = p->end->price;
                  pullbackLowTime = p->end->time;
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
      if(zz == NULL || zz->pivots->Total() == 0)
         return;
      bool first = true;
      for(int j = 0; j < zz->pivots->Total(); j++)
        {
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(zz->projection != NULL && p == zz->projection)
            continue;
         if(p->end->time >= startTime && p->end->time <= endTime)
           {
            if(searchHigh && p->isHigh)
              {
               if(first || p->end->price > extPrice)
                 {
                  extPrice = p->end->price;
                  extTime = p->end->time;
                  first = false;
                 }
              }
            else
               if(!searchHigh && !p->isHigh)
                 {
                  if(first || p->end->price < extPrice)
                    {
                     extPrice = p->end->price;
                     extTime = p->end->time;
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
      if(zz == NULL || zz->pivots->Total() == 0)
         return;

      int b_idx = -1;
      int limit = zz->pivots->Total() - 1;
      for(int j = 0; j < limit; j++)
        {
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(zz->projection != NULL && p == zz->projection)
            continue;
         if(p->end->time >= chTime && !p->isHigh)
           {
            b_idx = j;
            break;
           }
        }

      if(b_idx == -1)
         return;

      Pivot* pivotB = (Pivot*)zz->pivots->At(b_idx);
      targetPrice = pivotB->end->price;
      targetTime = pivotB->end->time;
     }

   // Calculates target high and timestamp rules for Bullish CHoCH (unconditionally locks onto A)
   void              GetBullishChochTarget(ZigZag* zz, datetime chTime, double protPrice, double &targetPrice, datetime &targetTime)
     {
      targetPrice = EMPTY_VALUE;
      targetTime = 0;
      if(zz == NULL || zz->pivots->Total() == 0)
         return;

      int a_idx = -1;
      int limit = zz->pivots->Total() - 1;
      for(int j = 0; j < limit; j++)
        {
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(zz->projection != NULL && p == zz->projection)
            continue;
         if(p->end->time >= chTime && p->isHigh)
           {
            a_idx = j;
            break;
           }
        }

      if(a_idx == -1)
         return;

      Pivot* pivotA = (Pivot*)zz->pivots->At(a_idx);
      targetPrice = pivotA->end->price;
      targetTime = pivotA->end->time;
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
         for(int p = 0; p < zz->pivots->Total(); p++)
           {
            Pivot* pv = (Pivot*)zz->pivots->At(p);
            if(zz->projection != NULL && pv == zz->projection)
               continue;
            if(pv->end->time == t)
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
         for(int p = 0; p < zz->pivots->Total(); p++)
           {
            Pivot* pv = (Pivot*)zz->pivots->At(p);
            if(zz->projection != NULL && pv == zz->projection)
               continue;
            if(pv->end->time == t)
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
         string line_id = string("BOSCHoCH_") + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, line_id + "_lbl", OBJPROP_TEXT, tf_str() + "-SSL-Swept");
         m_events[3].name = "SSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "SSL-Swept");
         RegisterSSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);
        }

      // Rule 2: Failed bearish reversal between bullish structures -> BSL-Swept
      if((pri == "BL-BOS" || pri == "BL-CHoCH") && prev == "BR-CHoCH" && cur == "BL-CHoCH")
        {
         string line_id = string("BOSCHoCH_") + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, line_id + "_lbl", OBJPROP_TEXT, tf_str() + "-BSL-Swept");
         m_events[3].name = "BSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "BSL-Swept");
         RegisterBSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);
        }

      // Rule 3: BL-CHoCH between BSL-Swept and BR-CHoCH -> SSL-Swept
      if(pri == "BSL-Swept" && prev == "BL-CHoCH" && cur == "BR-CHoCH")
        {
         string id3 = string("BOSCHoCH_") + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, id3 + "_lbl", OBJPROP_TEXT, tf_str() + "-SSL-Swept");
         m_events[3].name = "SSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "SSL-Swept");
         RegisterSSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);

         string id4 = string("BOSCHoCH_") + IntegerToString(m_events[4].time);
         if(m_showBosChoch) ObjectSetString(0, id4 + "_lbl", OBJPROP_TEXT, tf_str() + "-BR-BOS");
         m_events[4].name = "BR-BOS";
         UpdateHistoricalEventName(m_events[4].time, "BR-BOS");

         string id2 = string("BOSCHoCH_") + IntegerToString(m_events[2].time);
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
         string id3 = string("BOSCHoCH_") + IntegerToString(m_events[3].time);
         if(m_showBosChoch) ObjectSetString(0, id3 + "_lbl", OBJPROP_TEXT, tf_str() + "-BSL-Swept");
         m_events[3].name = "BSL-Swept";
         UpdateHistoricalEventName(m_events[3].time, "BSL-Swept");
         RegisterBSLSweep(m_events[3].time, m_events[3].lineStartTime, m_events[3].lineEndTime, m_events[4].time);

         string id4 = string("BOSCHoCH_") + IntegerToString(m_events[4].time);
         if(m_showBosChoch) ObjectSetString(0, id4 + "_lbl", OBJPROP_TEXT, tf_str() + "-BL-BOS");
         m_events[4].name = "BL-BOS";
         UpdateHistoricalEventName(m_events[4].time, "BL-BOS");

         string id2 = string("BOSCHoCH_") + IntegerToString(m_events[2].time);
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
            return string("H") + IntegerToString(mins / 60);
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
      for(int j = 0; j < zz->pivots->Total(); j++)
        {
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || p->end == NULL || CheckPointer(p->end) != POINTER_DYNAMIC)
            continue;

         if(pivotAIndex < 0 && p->end->time == lineStart)
            pivotAIndex = j;
         if(pivotBIndex < 0 && p->start != NULL && CheckPointer(p->start) == POINTER_DYNAMIC)
           {
            datetime segmentStart = (p->start->time < p->end->time ? p->start->time : p->end->time);
            datetime segmentEnd   = (p->start->time > p->end->time ? p->start->time : p->end->time);
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
         Pivot* p = (Pivot*)zz->pivots->At(j);
         if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || p->end == NULL || CheckPointer(p->end) != POINTER_DYNAMIC || p->isHigh != searchHigh)
            continue;

         if(extremeTime == 0 || (searchHigh ? p->end->price > extremePrice : p->end->price < extremePrice))
           {
            extremePrice = p->end->price;
            extremeTime = p->end->time;
           }
        }
      return extremeTime;
     }

   color             get_swing_color()
     {
      int mins = PeriodSeconds(_Period) / 60;
      if(mins < 1)
         return 0;
      else
         if(mins <= 15)
            return 0;
         else
            if(mins <= 60)
               return 0;
            else
               if(mins < 1440)
                  return 0;
               else
                  if(mins == 1440)
                     return 0;
      return 0;
     }

   // --- Main Engine Update Module ---
   void              Update(int i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, const std::vector<double> &close, ZigZag* zigZag)
     {
      new_sweep_confirmed = false; // Reset on every bar

      // --- 1. INITIALIZATION ---
      if(protected_level_price == EMPTY_VALUE && zigZag->pivots->Total() >= 3)
        {
         for(int pidx = 0; pidx <= 2; pidx++)
           {
            Pivot* p = (Pivot*)zigZag->pivots->At(pidx);
            if(p->isHigh && trend == 1)
              {
               target_level_price = p->end->price;
               target_level_time = p->end->time;
              }
            if(!p->isHigh && trend == 1)
              {
               protected_level_price = p->end->price;
               protected_level_time = p->end->time;
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
      if(zigZag->pivots->Total() >= 2)
        {
         int target_idx = zigZag->pivots->Total() - 2;
         Pivot* p = (Pivot*)zigZag->pivots->At(target_idx);

         if(p != NULL)
           {
            if(last_processed_pivot_time == 0 || p->end->time != last_processed_pivot_time)
              {
               last_processed_pivot_time = p->end->time;

               if(last_breakout_time == 0 || p->end->time > protected_level_time)
                 {
                  if(p->isHigh && trend == 1)
                    {
                     target_level_price = target_level_price;
                    }
                  else
                     if(!p->isHigh && trend == -1)
                       {
                        target_level_price = target_level_price;
                       }

                  if(p->isHigh && trend == -1)
                    {
                     if((last_breakout_time == 0 || p->end->time <= last_breakout_time) && (protected_level_price == EMPTY_VALUE || p->end->price > protected_level_price))
                       {
                        protected_level_price = p->end->price;
                        protected_level_time  = p->end->time;
                       }
                    }
                  else
                     if(!p->isHigh && trend == 1)
                       {
                        if((last_breakout_time == 0 || p->end->time <= last_breakout_time) && (protected_level_price == EMPTY_VALUE || p->end->price < protected_level_price))
                          {
                           protected_level_price = p->end->price;
                           protected_level_time  = p->end->time;
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
            if(m_showBosChoch)
              {
               datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
               string id = string("BOSCHoCH_") + IntegerToString(time[i]);
               Plotter::DrawLine(id, protected_level_time, protected_level_price, time[i], protected_level_price, clrGreen, STYLE_SOLID, 2, false);
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
               if(m_showBosChoch)
                 {
                  datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                  string id = string("BOSCHoCH_") + IntegerToString(time[i]);
                  Plotter::DrawLine(id, target_level_time, target_level_price, time[i], target_level_price, clrGreen, STYLE_SOLID, 2, false);
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
               if(m_showBosChoch)
                 {
                  datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
                  string id = string("BOSCHoCH_") + IntegerToString(time[i]);
                  Plotter::DrawLine(id, protected_level_time, protected_level_price, time[i], protected_level_price, clrRed, STYLE_SOLID, 2, false);
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
                  if(m_showBosChoch)
                    {
                     datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                     string id = string("BOSCHoCH_") + IntegerToString(time[i]);
                     Plotter::DrawLine(id, target_level_time, target_level_price, time[i], target_level_price, clrRed, STYLE_SOLID, 2, false);
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
      if(m_showSwingHL)
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
            datetime mTime = active_swing_high_time + (time[i] - active_swing_high_time)/2;
            Plotter::DrawLine(hln, active_swing_high_time, active_swing_high_price, time[i], active_swing_high_price, swing_line_color, STYLE_DASH, 1, false);
            Plotter::DrawLabel(hlbl, mTime, active_swing_high_price, string(" ") +tf_str()+"-SWING-HIGH ", swing_line_color, ANCHOR_LOWER);
           }

         if(active_swing_low_price != EMPTY_VALUE && active_swing_low_time != 0)
           {
            string lln = "SWING_LOW_LINE";
            string llbl = "SWING_LOW_LBL";
            datetime mTimeL = active_swing_low_time + (time[i] - active_swing_low_time)/2;
            Plotter::DrawLine(lln, active_swing_low_time, active_swing_low_price, time[i], active_swing_low_price, swing_line_color, STYLE_DASH, 1, false);
            Plotter::DrawLabel(llbl, mTimeL, active_swing_low_price, string(" ") +tf_str()+"-SWING-LOW ", swing_line_color, ANCHOR_UPPER);
           }
        }

      CleanupStructuralTimes(zigZag);
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\market_structure.mqh

//+------------------------------------------------------------------+
//|                               Include\Custom\ZigZag\demand_supply.mqh   |
//|                 Demand & Supply Zone Navigation Logic            |
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDemandSupplyLogic
  { public: CDemandSupplyLogic* operator->(){return this;} const CDemandSupplyLogic* operator->()const{return this;}
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

                     CDemandSupplyLogic() { poi_last_pivot_time = 0; }

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
     }

   void              DetectPOIs(int i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, ZigZag* zigZag)
     {
      if(zigZag->pivots->Total() >= 2)
        {
         Pivot* zp = (Pivot*)zigZag->pivots->At(zigZag->pivots->Total() - 2);
         if(poi_last_pivot_time == 0 || zp->end->time != poi_last_pivot_time)
           {
            poi_last_pivot_time = zp->end->time;

            double zc_high = EMPTY_VALUE;
            double zc_low = EMPTY_VALUE;
            int lookback = (int)MathMin(i, 500);
            for(int k = 0; k <= lookback; k++)
              {
               int j = i - k;
               if(time[j] == zp->end->time)
                 {
                  zc_high = high[j];
                  zc_low = low[j];
                  break;
                 }
               if(time[j] < zp->end->time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               if(!zp->isHigh)
                 {
                  poi_demandTime.Add((long)zp->end->time);
                  poi_demandZoneLow.Add(zc_low);
                  poi_demandZoneHigh.Add(zc_high);
                  poi_demandMitigated.Add(0);
                 }
               else
                 {
                  poi_supplyTime.Add((long)zp->end->time);
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
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMarketMetrics* GetDemandSupplyZoneMetrics(CDemandSupplyLogic* logic, bool isDemand, int index)
  {
   CMarketMetrics* metrics = new CMarketMetrics();
   datetime currentTime = TimeCurrent();
   if(isDemand && logic != NULL && index >= 0 && index < logic->poi_demandTime.Total())
     {
      metrics->zoneLow = logic->poi_demandZoneLow.At(index);
      metrics->zoneHigh = logic->poi_demandZoneHigh.At(index);
      metrics->isMitigated = (logic->poi_demandMitigated.At(index) == 1);
      metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_demandTime.At(index));
     }
   else
      if(!isDemand && logic != NULL && index >= 0 && index < logic->poi_supplyTime.Total())
        {
         metrics->zoneLow = logic->poi_supplyZoneLow.At(index);
         metrics->zoneHigh = logic->poi_supplyZoneHigh.At(index);
         metrics->isMitigated = (logic->poi_supplyMitigated.At(index) == 1);
         metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_supplyTime.At(index));
        }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\demand_supply.mqh

// END FILE: Include\Custom\ZigZag\demand_supply.mqh

//+------------------------------------------------------------------+
//|                                 Include\Custom\ZigZag\swing_pois.mqh    |
//|                    Swing POIs Navigation Engine                  |
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSwingPOILogic
  { public: CSwingPOILogic* operator->(){return this;} const CSwingPOILogic* operator->()const{return this;}
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

                     CSwingPOILogic() { poi_last_pivot_time = 0; }

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
     }

   bool              ob_time_found(CArrayLong* arr, datetime t)
     {
      for(int j=0; j<arr->Total(); j++)
         if((datetime)arr->At(j) == t)
            return true;
      return false;
     }

   void              DetectPOIs(int i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, ZigZag* zigZag)
     {
      if(zigZag->pivots->Total() >= 2)
        {
         Pivot* zp = (Pivot*)zigZag->pivots->At(zigZag->pivots->Total() - 2);
         if(poi_last_pivot_time == 0 || zp->end->time != poi_last_pivot_time)
           {
            poi_last_pivot_time = zp->end->time;

            double zc_high = EMPTY_VALUE;
            double zc_low = EMPTY_VALUE;
            int lookback = (int)MathMin(i, 500);
            for(int k = 0; k <= lookback; k++)
              {
               int j = i - k;
               if(time[j] == zp->end->time)
                 {
                  zc_high = high[j];
                  zc_low = low[j];
                  break;
                 }
               if(time[j] < zp->end->time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               if(!zp->isHigh)
                 {
                  poi_demandTime.Add((long)zp->end->time);
                  poi_demandZoneLow.Add(zc_low);
                  poi_demandZoneHigh.Add(zc_high);
                  poi_demandMitigated.Add(0);
                 }
               else
                 {
                  poi_supplyTime.Add((long)zp->end->time);
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
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMarketMetrics* GetSwingPOIZoneMetrics(CSwingPOILogic* logic, bool isDemand, int index)
  {
   CMarketMetrics* metrics = new CMarketMetrics();
   datetime currentTime = TimeCurrent();
   if(isDemand && logic != NULL && index >= 0 && index < logic->poi_demandTime.Total())
     {
      metrics->zoneLow = logic->poi_demandZoneLow.At(index);
      metrics->zoneHigh = logic->poi_demandZoneHigh.At(index);
      metrics->isMitigated = (logic->poi_demandMitigated.At(index) == 1);
      metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_demandTime.At(index));
     }
   else
      if(!isDemand && logic != NULL && index >= 0 && index < logic->poi_supplyTime.Total())
        {
         metrics->zoneLow = logic->poi_supplyZoneLow.At(index);
         metrics->zoneHigh = logic->poi_supplyZoneHigh.At(index);
         metrics->isMitigated = (logic->poi_supplyMitigated.At(index) == 1);
         metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_supplyTime.At(index));
        }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\swing_pois.mqh

// END FILE: Include\Custom\ZigZag\swing_pois.mqh

//+------------------------------------------------------------------+
//|                               Include\Custom\ZigZag\order_blocks.mqh    |
//|                 Order Blocks 6-Step Validation Engine            |
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class COrderBlockLogic
  { public: COrderBlockLogic* operator->(){return this;} const COrderBlockLogic* operator->()const{return this;}
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
      for(int j=0; j<arr->Total(); j++)
         if((datetime)arr->At(j) == t)
            return true;
      return false;
     }

   void              DetectPOIs(int i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, ZigZag* zigZag)
     {
      if(zigZag->pivots->Total() >= 2)
        {
         Pivot* zp = (Pivot*)zigZag->pivots->At(zigZag->pivots->Total() - 2);
         if(poi_last_pivot_time == 0 || zp->end->time != poi_last_pivot_time)
           {
            poi_last_pivot_time = zp->end->time;

            double zc_high = EMPTY_VALUE;
            double zc_low = EMPTY_VALUE;
            int lookback = (int)MathMin(i, 500);
            for(int k = 0; k <= lookback; k++)
              {
               int j = i - k;
               if(time[j] == zp->end->time)
                 {
                  zc_high = high[j];
                  zc_low = low[j];
                  break;
                 }
               if(time[j] < zp->end->time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               if(!zp->isHigh)
                 {
                  poi_demandTime.Add((long)zp->end->time);
                  poi_demandZoneLow.Add(zc_low);
                  poi_demandZoneHigh.Add(zc_high);
                  poi_demandMitigated.Add(0);
                 }
               else
                 {
                  poi_supplyTime.Add((long)zp->end->time);
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

   bool              CheckBullishOB(datetime pivot_time, int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low)
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

   bool              CheckBearishOB(datetime pivot_time, int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low)
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
   if(isDemand && logic != NULL && index >= 0 && index < logic->poi_demandTime.Total())
     {
      metrics->zoneLow = logic->poi_demandZoneLow.At(index);
      metrics->zoneHigh = logic->poi_demandZoneHigh.At(index);
      metrics->isMitigated = (logic->poi_demandMitigated.At(index) == 1);
      metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_demandTime.At(index));
     }
   else
      if(!isDemand && logic != NULL && index >= 0 && index < logic->poi_supplyTime.Total())
        {
         metrics->zoneLow = logic->poi_supplyZoneLow.At(index);
         metrics->zoneHigh = logic->poi_supplyZoneHigh.At(index);
         metrics->isMitigated = (logic->poi_supplyMitigated.At(index) == 1);
         metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->poi_supplyTime.At(index));
        }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\order_blocks.mqh

// END FILE: Include\Custom\ZigZag\order_blocks.mqh

//+------------------------------------------------------------------+
//|                                   Include\Custom\ZigZag\flipzone.mqh    |
//|                 Demand & Supply Flip Zone Engine                 |
//+------------------------------------------------------------------+










// =============================================================================
// FLIP ZONE DECOUPLED LOGIC CLASS
// =============================================================================
class CFlipZoneLogic
  { public: CFlipZoneLogic* operator->(){return this;} const CFlipZoneLogic* operator->()const{return this;}
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
   void              DetectFlipZones(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, const std::vector<double> &close, ZigZag* zigZag, CMarketStructure* ms, CDemandSupplyLogic* dsLogic)
     {
      // TRIGGER: Only process when a fresh Market Shift (BOS or CHoCH) occurs [2593]
      if(ms->last_breakout_time <= fz_last_breakout_time || ms->last_breakout_time == 0)
         return;

      bool found_flip = false;
      double zc_high = EMPTY_VALUE;
      double zc_low  = EMPTY_VALUE;
      int type_val = 0;
      long p_time = 0;

      // -----------------------------------------------------------------------
      // CASE A: DEMAND FLIP ZONE (Bearish to Bullish Market Shift) [2593]
      // -----------------------------------------------------------------------
      if(ms->trend == 1)
        {
         Pivot* last_low_p = NULL;
         int sz = zigZag->pivots->Total();
         if(sz > 0)
           {
            // Loop backward from the end of the pivots array to find the last low pivot [2593]
            for(int k = sz - 1; k >= 0; k--)
              {
               Pivot* p = (Pivot*)zigZag->pivots->At(k);
               if(p != NULL && !p->isHigh && StringFind(p->ln, "ZZ_Proj") < 0)
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
               if(time[idx] == last_low_p->end->time)
                 {
                  zc_high = high[idx];
                  zc_low  = low[idx];
                  break;
                 }
               if(time[idx] < last_low_p->end->time)
                  break;
              }

            if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
              {
               found_flip = true;
               type_val = 1; // Demand Flip (Long Zone)
               p_time = last_low_p->end->time;
              }
           }
        }
      // -----------------------------------------------------------------------
      // CASE B: SUPPLY FLIP ZONE (Bullish to Bearish Market Shift) [2593]
      // -----------------------------------------------------------------------
      else
         if(ms->trend == -1)
           {
            Pivot* last_high_p = NULL;
            int sz = zigZag->pivots->Total();
            if(sz > 0)
              {
               // Loop backward from the end of the pivots array to find the last high pivot [2593]
               for(int k = sz - 1; k >= 0; k--)
                 {
                  Pivot* p = (Pivot*)zigZag->pivots->At(k);
                  if(p != NULL && p->isHigh && StringFind(p->ln, "ZZ_Proj") < 0)
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
                  if(time[idx] == last_high_p->end->time)
                    {
                     zc_high = high[idx];
                     zc_low  = low[idx];
                     break;
                    }
                  if(time[idx] < last_high_p->end->time)
                     break;
                 }

               if(zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE)
                 {
                  found_flip = true;
                  type_val = -1; // Supply Flip (Short Zone)
                  p_time = last_high_p->end->time;
                 }
              }
           }

      if(found_flip)
        {
         fz_time.Add((long)p_time);
         fz_zoneLow.Add(zc_low);
         fz_zoneHigh.Add(zc_high);
         fz_type.Add(type_val);
         fz_mitigated.Add(0);

         // Lock current breakout sequence to prevent double-logging
         fz_last_breakout_time = ms->last_breakout_time;
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

//+------------------------------------------------------------------+
//|                                Include\Custom\Custom\ZigZag\breaker_blocks.mqh |
//|                     SMC Breaker Block Calculation Engine         |
//+------------------------------------------------------------------+













// =============================================================================
// BREAKER BLOCK ENGINE LOGIC CLASS
// =============================================================================
class CBreakerBlockLogic
  { public: CBreakerBlockLogic* operator->(){return this;} const CBreakerBlockLogic* operator->()const{return this;}
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
      if(zigZag == NULL || zigZag->pivots->Total() < 2)
         return;

      int sz = zigZag->pivots->Total();
      // Inspect the last 2 confirmed pivots (excluding any active updating projection)
      int start_idx = MathMax(0, sz - 3);
      int end_idx = sz - 2;

      for(int idx = start_idx; idx <= end_idx; idx++)
        {
         Pivot* p = (Pivot*)zigZag->pivots->At(idx);
         if(p == NULL || (zigZag->projection != NULL && p == zigZag->projection))
            continue;

         datetime p_time = p->end->time;
         double p_price = p->end->price;

         if(p->isHigh) // High Pivot breaks Bearish zones -> creates a Bullish Breaker Block
           {
            // 1. Check Supply Zones
            if(dsLogic != NULL)
              {
               for(int i = 0; i < dsLogic->poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)dsLogic->poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = dsLogic->poi_supplyZoneHigh.At(i);
                     double zLow  = dsLogic->poi_supplyZoneLow.At(i);
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
               for(int i = 0; i < spLogic->poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)spLogic->poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = spLogic->poi_supplyZoneHigh.At(i);
                     double zLow  = spLogic->poi_supplyZoneLow.At(i);
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
               for(int i = 0; i < obLogic->poi_supplyTime.Total(); i++)
                 {
                  datetime zTime = (datetime)obLogic->poi_supplyTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                    {
                     double zHigh = obLogic->poi_supplyZoneHigh.At(i);
                     double zLow  = obLogic->poi_supplyZoneLow.At(i);
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
               for(int i = 0; i < fzLogic->fz_time.Total(); i++)
                 {
                  if(fzLogic->fz_type.At(i) == -1) // Supply Flip
                    {
                     datetime zTime = (datetime)fzLogic->fz_time.At(i);
                     if(p_time > zTime && !IsProcessed(processed_failed_bear_times, zTime))
                       {
                        double zHigh = fzLogic->fz_zoneHigh.At(i);
                        double zLow  = fzLogic->fz_zoneLow.At(i);
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
               for(int i = 0; i < dsLogic->poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)dsLogic->poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = dsLogic->poi_demandZoneHigh.At(i);
                     double zLow  = dsLogic->poi_demandZoneLow.At(i);
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
               for(int i = 0; i < spLogic->poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)spLogic->poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = spLogic->poi_demandZoneHigh.At(i);
                     double zLow  = spLogic->poi_demandZoneLow.At(i);
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
               for(int i = 0; i < obLogic->poi_demandTime.Total(); i++)
                 {
                  datetime zTime = (datetime)obLogic->poi_demandTime.At(i);
                  if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                    {
                     double zHigh = obLogic->poi_demandZoneHigh.At(i);
                     double zLow  = obLogic->poi_demandZoneLow.At(i);
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
               for(int i = 0; i < fzLogic->fz_time.Total(); i++)
                 {
                  if(fzLogic->fz_type.At(i) == 1) // Demand Flip
                    {
                     datetime zTime = (datetime)fzLogic->fz_time.At(i);
                     if(p_time > zTime && !IsProcessed(processed_failed_bull_times, zTime))
                       {
                        double zHigh = fzLogic->fz_zoneHigh.At(i);
                        double zLow  = fzLogic->fz_zoneLow.At(i);
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

public:
   bool              IsProcessed(CArrayLong &arr, datetime t)
     {
      for(int j = 0; j < arr->Total(); j++)
        {
         if(arr->At(j) == (long)t)
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
   if(logic != NULL && index >= 0 && index < logic->bb_time.Total())
     {
      metrics->zoneLow = logic->bb_zoneLow.At(index);
      metrics->zoneHigh = logic->bb_zoneHigh.At(index);
      metrics->isMitigated = (logic->bb_mitigated.At(index) == 1);
      metrics->zoneAgeSeconds = (long)(currentTime - (datetime)logic->bb_time.At(index));
     }
   return metrics;
  }
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\breaker_blocks.mqh

// END FILE: Include\Custom\ZigZag\breaker_blocks.mqh

// Shared rejection policy. Data collection, detection and order submission stay with callers.
#ifndef MARCO_TRADE_REJECTION_MQH
#define MARCO_TRADE_REJECTION_MQH

enum ENUM_TRADE_REJECTION_ACTION { TRADE_ALLOW, TRADE_SKIP_NOW, TRADE_RETIRE_ZONE };
enum ENUM_TRADE_REJECTION_REASON
  {
   REJECT_NONE, REJECT_USED, REJECT_SESSION, REJECT_UNCONFIRMED,
   REJECT_PRECONF_TOUCH, REJECT_BOUNDARY, REJECT_MULTIPLE_PIVOTS, REJECT_EXPIRED,
   REJECT_OPPOSING_ORIGIN, REJECT_OPPOSING_CHOCH_LB, REJECT_OVERLAP,
   REJECT_SL, REJECT_NO_TP, REJECT_RR, REJECT_EXECUTION, REJECT_FORMATION
  };

struct STradeRejection
  { public: STradeRejection* operator->(){return this;} const STradeRejection* operator->()const{return this;}
   ENUM_TRADE_REJECTION_ACTION action;
   ENUM_TRADE_REJECTION_REASON reason;
   ENUM_TIMEFRAMES sourceTF;
   string opposingId;
   datetime eventTime;
  };

class CTradeRejection
  { public: CTradeRejection* operator->(){return this;} const CTradeRejection* operator->()const{return this;}
public:
   static STradeRejection Decision(ENUM_TRADE_REJECTION_ACTION action, ENUM_TRADE_REJECTION_REASON reason)
     {
      STradeRejection result;
      result->action = action; result->reason = reason;
      result->sourceTF = PERIOD_CURRENT; result->opposingId = ""; result->eventTime = 0;
      return result;
     }
   static bool Used(int touches, bool mitigated) { return touches > 0 || mitigated; }
   static void Consume(int &touches, int count = 1) { touches = MathMax(touches, count); }
   static void Mitigate(bool &mitigated, datetime &at, datetime now) { mitigated = true; at = now; }
   static void Retire(int &touches, bool &mitigated, datetime &at, datetime now)
     {
      if(Used(touches, mitigated)) return;
      touches++;
      Mitigate(mitigated, at, now);
     }
   static bool OutsideSession(datetime origin, datetime created, datetime confirmed, datetime start)
     { return origin < start || created < start || confirmed < start; }
   static bool Unconfirmed(datetime confirmedBar, int seconds, datetime now)
     { return now < confirmedBar + seconds; }
   static bool PreConfirmation(bool risky, int priceTouches, int pivotTouches, bool broken)
     { return broken || (!risky && (priceTouches > 0 || pivotTouches > 0)); }
   static bool BoundaryBroken(bool bull, double low, double high, double zLow, double zHigh, double buffer)
     { return bull ? low < zLow - buffer : high > zHigh + buffer; }
   static bool Intersects(double low, double high, double zLow, double zHigh)
     { return low <= zHigh && high >= zLow; }
   static bool NearEntry(bool bull, double low, double high, double zLow, double zHigh, double pip, int digits)
     { return bull ? low <= NormalizeDouble(zHigh + pip, digits) && high >= zLow :
                    high >= NormalizeDouble(zLow - pip, digits) && low <= zHigh; }
   static bool DirectEntry(bool bull, double bid, double ask, double zLow, double zHigh, double buffer)
     { return bull ? ask <= zHigh && bid >= zLow - buffer : bid >= zLow && ask <= zHigh + buffer; }
   static bool MultiplePivots(int count) { return count > 1; }
   static bool NeedsPivot(int count) { return count != 1; }
   static bool Expired(datetime now, datetime confirmation, int seconds)
     { return now > confirmation + seconds; }
   static bool M1Expired(datetime lastClosedBar, datetime confirmation)
     { return lastClosedBar > confirmation - PeriodSeconds(PERIOD_M1); }
   static bool M1Pivot(bool bull, bool high, datetime pivot, double price, datetime touch,
                       datetime available, datetime now, double zLow, double zHigh)
     { return high != bull && pivot >= touch - touch % 60 && price >= zLow && price <= zHigh && available > touch && available <= now; }
   static bool OriginInside(datetime origin, double price, datetime created, datetime mitigation,
                            int seconds, double zLow, double zHigh, double buffer)
     {
      bool validTime = origin >= created && (mitigation == 0 || origin <= mitigation + seconds);
      return (validTime || origin == created) && price >= zLow - buffer && price <= zHigh + buffer;
     }
   static bool Overlap(bool allowed, double tpDistance, double covered)
     { return !allowed || tpDistance <= 0.0 || covered < 0.5 * tpDistance; }
   static bool InvalidSL(bool bull, double entry, double sl)
     { return bull ? sl >= entry : sl <= entry; }
   static bool StopTooClose(double risk, double minimum) { return risk <= minimum || risk <= 0.0; }
   static bool NoTP(double tp) { return tp == 0.0; }
   static bool LowRR(bool enabled, bool structural, double rr, double minimum)
     { return enabled && structural && rr < minimum; }
   static bool SizingInputs(double free, double risk, double step, double minimum, double maximum)
     { return free > 0 && risk > 0 && step > 0 && minimum > 0 && maximum >= minimum; }
   static bool MarginFits(double needed, double free) { return needed <= free * 0.90; }
   static bool CheckPassed(bool checked, uint code)
     { return checked && (code == 0 || code == TRADE_RETCODE_DONE); }
   static bool ReserveFits(double remaining, double free) { return remaining + 1e-8 >= free * 0.10; }
   static bool ExecutionAllowed(bool terminal, bool program, bool account, bool expert, datetime now, datetime next)
     { return terminal && program && account && expert && now >= next; }
   static bool ConsumeOrderResult(uint code)
     { return code == TRADE_RETCODE_PLACED || code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL || code == TRADE_RETCODE_TIMEOUT; }
   static bool WrongOrigin(bool strict, bool bull, bool pivotHigh) { return strict && bull == pivotHigh; }
   static bool ActiveInducementOverlap(bool bull, double low, double high, datetime origin,
                                       bool indBull, double indLow, double indHigh, datetime formed, datetime mitigated)
     { return bull == indBull && formed <= origin && (mitigated == 0 || mitigated >= origin) && Intersects(low, high, indLow, indHigh); }
   static bool Clustered(double low, double high, double otherLow, double otherHigh, double tolerance)
     { return Intersects(low, high, otherLow - tolerance, otherHigh + tolerance); }
   static bool SameLB(bool bull, datetime origin, double low, double high, bool otherBull,
                      datetime otherOrigin, double otherLow, double otherHigh, double tolerance)
     { return bull == otherBull && (origin == otherOrigin || (MathAbs(low-otherLow) <= tolerance && MathAbs(high-otherHigh) <= tolerance)); }
   static int RequiredStructures(int minutes) { return minutes <= 5 ? 5 : 3; }
  };

// Immutable versions preserve the information available during chronological catch-up.
struct SRejectionEvent
  { public: SRejectionEvent* operator->(){return this;} const SRejectionEvent* operator->()const{return this;}
   string name;
   datetime time, available, originTime, until;
   double originPrice, linePrice;
  };
struct SRejectionLB
  { public: SRejectionLB* operator->(){return this;} const SRejectionLB* operator->()const{return this;}
   string id;
   bool bull, seen, exitOnly;
   double low, high;
   datetime created, mitigation, choch, available, until;
  };

class CTradeRejectionHistory
  { public: CTradeRejectionHistory* operator->(){return this;} const CTradeRejectionHistory* operator->()const{return this;}
public:
   std::vector<SRejectionEvent> events;
   std::vector<SRejectionLB> zones;
   STradeRejection AllowWithTrace(string reason, bool diagnostics)
     {
      if(diagnostics) Print("[CHOCH AUDIT] decision=ALLOW reason=", reason);
      return CTradeRejection::Decision(TRADE_ALLOW, REJECT_NONE);
     }
public:
   void Reset() { ArrayResize(events, 0); ArrayResize(zones, 0); }
   void Observe(string name, datetime time, datetime available, datetime originTime, double originPrice, double linePrice = 0.0)
     {
      if(time == 0 || name == "") return;
      int n = ArraySize(events);
      // A previous event may be reclassified after a newer event is recorded.
      // Keep its source and an availability-bounded version; do not reorder the market.
      for(int i=n-1;i>=0;i--)
         if(events[i].time==time)
           {
            if(events[i].name==name) return;
            originTime=events[i].originTime;
            originPrice=events[i].originPrice;
            events[i].until=available;
            break;
           }
      ArrayResize(events, n+1);
      events[n].name=name; events[n].time=time; events[n].available=available;
      events[n].originTime=originTime; events[n].originPrice=originPrice;
      events[n].linePrice=linePrice; events[n].until=0;
     }
   int EventCount() { return ArraySize(events); }
   bool EventAt(int index, datetime now, SRejectionEvent &event)
     {
      if(index<0 || index>=ArraySize(events) || events[index].available>now ||
         (events[index].until>0 && now>=events[index].until)) return false;
      event=events[index]; return true;
     }
   bool Latest(datetime now, SRejectionEvent &event)
     {
      bool found=false;
      for(int i=ArraySize(events)-1;i>=0;i--)
        {
         SRejectionEvent candidate;
         if(!EventAt(i,now,candidate)) continue;
         if(!found || candidate.time>event.time) { event=candidate; found=true; }
        }
      return found;
     }
   int ZoneCount() { return ArraySize(zones); }
   bool ZoneAt(int index, SRejectionLB &zone)
     {
      if(index<0 || index>=ArraySize(zones)) return false;
      zone=zones[index]; return true;
     }
   void BeginZones()
     {
      for(int i=0; i<ArraySize(zones); i++) zones[i].seen=false;
     }
   void Zone(string id, bool bull, double low, double high, datetime created,
             datetime mitigation, datetime choch, datetime now, bool exitOnly = false)
     {
      for(int i=ArraySize(zones)-1; i>=0; i--)
        {
         if(zones[i].id != id || zones[i].until != 0) continue;
         zones[i].seen=true;
         if(zones[i].bull==bull && zones[i].low==low && zones[i].high==high &&
            zones[i].created==created && zones[i].mitigation==mitigation && zones[i].choch==choch && zones[i].exitOnly==exitOnly) return;
         zones[i].until=now;
         break;
        }
      int n=ArraySize(zones); ArrayResize(zones,n+1);
      zones[n].exitOnly=exitOnly;
      zones[n].id=id; zones[n].bull=bull; zones[n].low=low; zones[n].high=high;
      zones[n].created=created; zones[n].mitigation=mitigation; zones[n].choch=choch;
      zones[n].available=now; zones[n].until=0; zones[n].seen=true;
     }
   void EndZones(datetime now)
     {
      for(int i=0; i<ArraySize(zones); i++)
         if(zones[i].until==0 && !zones[i].seen) zones[i].until=now;
     }
   STradeRejection OpposingChoch(bool candidateBull, datetime legOrigin, datetime legEnd,
                                datetime touch, datetime now, ENUM_TIMEFRAMES tf, double buffer, bool diagnostics = false)
     {
      STradeRejection result=CTradeRejection::Decision(TRADE_ALLOW, REJECT_NONE);
      if(diagnostics)
         PrintFormat("[CHOCH AUDIT] source=%s target=%s at=%s touch=%s leg_origin=%s leg_end=%s",
                     EnumToString(tf), candidateBull ? "BL-LB" : "BR-LB", TimeToString(now, TIME_DATE|TIME_SECONDS),
                     TimeToString(touch, TIME_DATE|TIME_SECONDS), TimeToString(legOrigin, TIME_DATE|TIME_SECONDS),
                     TimeToString(legEnd, TIME_DATE|TIME_SECONDS));
      if(touch==0) return AllowWithTrace("NO_RECORDED_TOUCH", diagnostics);
      if(now<touch) return AllowWithTrace("TOUCH_NOT_YET_AVAILABLE", diagnostics);
      if(legOrigin==0) return AllowWithTrace("NO_MATCHING_INCOMING_LEG", diagnostics);
      if(legOrigin>touch) return AllowWithTrace("LEG_STARTED_AFTER_RECORDED_TOUCH", diagnostics);
      SRejectionEvent ev;
      if(!Latest(now,ev)) return AllowWithTrace("NO_AVAILABLE_STRUCTURE", diagnostics);
      if(diagnostics)
         PrintFormat("[CHOCH AUDIT] latest=%s event=%s available=%s source_pivot=%s source_price=%.8f",
                     ev.name, TimeToString(ev.time, TIME_DATE|TIME_SECONDS), TimeToString(ev.available, TIME_DATE|TIME_SECONDS),
                     TimeToString(ev.originTime, TIME_DATE|TIME_SECONDS), ev.originPrice);
      if(ev.name != (candidateBull ? "BR-CHoCH" : "BL-CHoCH"))
         return AllowWithTrace("LATEST_STRUCTURE_IS_NOT_OPPOSING_CHOCH", diagnostics);
      // The latest CHoCH remains the structural context across intervening pullbacks.
      // Its source pivot may precede the final touching leg; the CHoCH need not occur inside that leg.
      // A later structure is already excluded by selecting only the latest available event above.
      if(ev.originTime==0) return AllowWithTrace("NO_CHOCH_SOURCE_PIVOT", diagnostics);
      if(ev.originTime>legOrigin) return AllowWithTrace("CHOCH_SOURCE_AFTER_INCOMING_LEG_ORIGIN", diagnostics);
      if(legEnd>0 && ev.time>legEnd) return AllowWithTrace("CHOCH_AFTER_TOUCHING_LEG_ENDED", diagnostics);
      int knownOpposing = 0;
      for(int b=ArraySize(zones)-1;b>=0;b--)
        {
         SRejectionLB lb=zones[b];
         if(lb->exitOnly || lb->bull==candidateBull || lb->available>now || (lb->until>0 && now>=lb->until)) continue;
         knownOpposing++;
         bool produced=lb->choch==ev.time;
         bool stemmed=false;
         if(!produced)
            for(int v=b; v>=0; v--)
              {
               SRejectionLB source=zones[v];
               if(source->id!=lb->id || source->available>ev.available ||
                  (source->until>0 && ev.available>=source->until)) continue;
               stemmed=CTradeRejection::OriginInside(ev.originTime, ev.originPrice, source->created,
                         source->mitigation, PeriodSeconds(tf), source->low, source->high, buffer);
               break;
              }
         if(diagnostics)
            PrintFormat("[CHOCH AUDIT] opposing=%s created=%s available=%s zone=[%.8f,%.8f] causal_choch=%s produced=%s stemmed=%s",
                        lb->id, TimeToString(lb->created, TIME_DATE|TIME_SECONDS), TimeToString(lb->available, TIME_DATE|TIME_SECONDS),
                        lb->low, lb->high, TimeToString(lb->choch, TIME_DATE|TIME_SECONDS), produced ? "true" : "false", stemmed ? "true" : "false");
         if(!produced && !stemmed) continue;
         result->action=TRADE_RETIRE_ZONE; result->reason=REJECT_OPPOSING_CHOCH_LB;
         result->sourceTF=tf; result->opposingId=lb->id; result->eventTime=ev.time;
         if(diagnostics) Print("[CHOCH AUDIT] decision=REJECT reason=OPPOSING_CHOCH_LB");
         return result;
        }
      if(diagnostics) PrintFormat("[CHOCH AUDIT] known_opposing_LBs=%d", knownOpposing);
      return AllowWithTrace("NO_AVAILABLE_OPPOSING_LB_LINKED_TO_CHOCH", diagnostics);
     }
  };
#endif

//+------------------------------------------------------------------+
//|                                Include\Custom\Marcotrades\Inducements.mqh |
//|                 Smart Money Concepts: Inducement Detection Engine|
//|                 Identifies Buyers' & Sellers' Inducement Zones   |
//+------------------------------------------------------------------+



#ifndef MARCOTRADES_INDUCEMENTS_MQH
#define MARCOTRADES_INDUCEMENTS_MQH
















//+------------------------------------------------------------------+
//| Inducement Zone Model                                            |
//+------------------------------------------------------------------+
class CInducementZone : public CObject
  { public: CInducementZone* operator->(){return this;} const CInducementZone* operator->()const{return this;}
public:
   string            id;                 // Unique zone identifier
   string            sourceType;         // "Demand", "Supply", "Order Block", "Swing POI", "Flip", "Breaker"
   bool              isBullish;          // true = Bullish (Buyers' Inducement), false = Bearish (Sellers' Inducement)
   double            zoneHigh;           // Zone upper boundary
   double            zoneLow;            // Zone lower boundary
   datetime          createdTime;        // Time of origin candle / pivot
   int               createdBarIndex;    // Historical bar index where zone formed

   // Touch Analytics
   int               touchCount;         // Number of qualifying non-mitigating touches
   CArrayLong        touchTimes;         // Timestamps of confirmed ZigZag pivots that tested the zone
   datetime          lastTouchTime;      // Last touch timestamp

   // Inducement State
   bool              isInducement;       // true if touchCount >= InpMinTouches
   datetime          qualifiedTime;      // First bar-close time when IND qualification was actually known->
   datetime          inducementTime;     // Timestamp when zone qualified as inducement

   // Mitigation State
   bool              isMitigated;        // true if a candle breached opposite boundary
   datetime          mitigationTime;     // Timestamp when mitigation occurred
   int               mitigationBarIndex; // Bar index of mitigation candle

                     CInducementZone()
     {
      id                 = "";
      sourceType         = "";
      isBullish          = true;
      zoneHigh           = 0.0;
      zoneLow            = 0.0;
      createdTime        = 0;
      createdBarIndex    = 0;
      touchCount         = 0;
      lastTouchTime      = 0;
      isInducement       = false;
      inducementTime     = 0;
      qualifiedTime      = 0;
      isMitigated        = false;
      mitigationTime     = 0;
      mitigationBarIndex = 0;
     }

   bool              HasPivotTouched(datetime p_time)
     {
      for(int i = 0; i < touchTimes.Total(); i++)
        {
         if((datetime)touchTimes.At(i) == p_time)
            return true;
        }
      return false;
     }
  };

//+------------------------------------------------------------------+
//| Core Inducement Logic Engine                                     |
//+------------------------------------------------------------------+
class CInducementLogic
  { public: CInducementLogic* operator->(){return this;} const CInducementLogic* operator->()const{return this;}
public:
   int               m_minTouches;
   double            m_proximityPips;
   bool              m_checkDS;
   bool              m_checkOB;
   bool              m_checkSP;
   bool              m_checkFZ;
   bool              m_checkBB;
   bool              m_strictOriginPivots;

   // Anti-Clustering & Consolidation Controls
   bool              m_mergeClustered;
   double            m_clusterTolerancePips;
   bool              m_expandBounds;

   CArrayString      m_registered_keys;
   datetime          m_last_evaluated_pivot_time;

   int               FindBarIndexByTime(datetime targetTime, const std::vector<datetime> &time, int rates_total)
     {
      int left = 0;
      int right = rates_total - 1;
      while(left <= right)
        {
         int mid = left + (right - left) / 2;
         if(time[mid] == targetTime)
            return mid;
         if(time[mid] < targetTime)
            left = mid + 1;
         else
            right = mid - 1;
        }
      return -1;
     }

public:
   CArrayObj         m_zones;            // Collection of all tracked zones

                     CInducementLogic()
     {
      m_minTouches                = 3;
      m_proximityPips             = 1.0;
      m_checkDS                   = true;
      m_checkOB                   = true;
      m_checkSP                   = true;
      m_checkFZ                   = false;
      m_checkBB                   = false;
      m_strictOriginPivots        = true;
      m_mergeClustered            = true;
      m_clusterTolerancePips      = 10.0;
      m_expandBounds              = false;
      m_last_evaluated_pivot_time = 0;
      m_zones.FreeMode(true);
     }

                    ~CInducementLogic()
     {
      Cleanup();
     }

   void              Init(int minTouches, double proximityPips, bool checkDS, bool checkOB, bool checkSP,
                          bool checkFZ, bool checkBB, bool strictOrigin,
                          bool mergeClustered, double clusterTolerancePips, bool expandBounds)
     {
      m_minTouches           = minTouches;
      m_proximityPips        = proximityPips;
      m_checkDS              = checkDS;
      m_checkOB              = checkOB;
      m_checkSP              = checkSP;
      m_checkFZ              = checkFZ;
      m_checkBB              = checkBB;
      m_strictOriginPivots   = strictOrigin;
      m_mergeClustered       = mergeClustered;
      m_clusterTolerancePips = clusterTolerancePips;
      m_expandBounds         = expandBounds;
     }

   void              ResetState()
     {
      m_zones.Clear();
      m_registered_keys.Clear();
      m_last_evaluated_pivot_time = 0;
     }

   void              Cleanup()
     {
      ResetState();
     }

   bool              IsKeyRegistered(string key)
     {
      for(int i = 0; i < m_registered_keys.Total(); i++)
        {
         if(m_registered_keys.At(i) == key)
            return true;
        }
      return false;
     }

   // Registers zone with strict origin polarity and cluster suppression
   void              RegisterZone(string sType, bool isBull, double zHigh, double zLow, datetime zTime, int barIdx, ZigZag* zz, double pipSize)
     {
      // 1. STRICT ORIGIN VALIDATION
      // Buyers' Inducement MUST strictly originate from a ZigZag Pivot LOW.
      // Sellers' Inducement MUST strictly originate from a ZigZag Pivot HIGH.
      if(m_strictOriginPivots && zz != NULL)
        {
         for(int p = 0; p < zz->pivots->Total(); p++)
           {
            Pivot* pv = (Pivot*)zz->pivots->At(p);
            if(pv != NULL && pv->end->time == zTime)
              {
               if(CTradeRejection::WrongOrigin(m_strictOriginPivots, isBull, pv->isHigh))
                  return;
               break;
              }
           }
        }

      string key = sType + string("_") + (isBull ? "BULL_" : "BEAR_") + IntegerToString((long)zTime);
      if(IsKeyRegistered(key))
         return;

      double clusterTol = m_clusterTolerancePips * pipSize;

      // 2. ANTI-CLUSTERING & ZONE PROLONGATION
      // If an unmitigated zone of the same direction already exists in this price territory,
      // prolong that single master zone instead of spawning duplicate stacked boxes.
      if(m_mergeClustered)
        {
         for(int i = 0; i < m_zones.Total(); i++)
           {
            CInducementZone* existing = (CInducementZone*)m_zones.At(i);
            if(existing == NULL || existing->isMitigated || existing->isBullish != isBull)
               continue;

            // Check if candidate zone overlaps or sits within cluster tolerance of the active zone
            bool isClustered = CTradeRejection::Clustered(zLow, zHigh, existing->zoneLow, existing->zoneHigh, clusterTol);

            if(isClustered)
              {
               if(isBull&&TimeToString(zTime)>="2026.11.12 15:00"&&TimeToString(zTime)<="2026.11.12 15:25")
                std::cout<<"CLUSTER candidate="<<sType<<" origin="<<TimeToString(zTime)<<" bounds="<<zLow<<","<<zHigh<<" master="<<existing->id<<" bounds="<<existing->zoneLow<<","<<existing->zoneHigh<<" tol="<<clusterTol<<" expand="<<m_expandBounds<<"\n";

               // Prolong master zone; optionally widen bounds to envelop the cluster
               if(m_expandBounds)
                 {
                  existing->zoneHigh = MathMax(existing->zoneHigh, zHigh);
                  existing->zoneLow  = MathMin(existing->zoneLow, zLow);
                 }
               m_registered_keys.Add(key); // Suppress candidate zone
               return;
              }
           }
        }

      // 3. REGISTER NEW MASTER ZONE
      CInducementZone* zone = new CInducementZone();
      zone->id              = key;
      zone->sourceType      = sType;
      zone->isBullish       = isBull;
      zone->zoneHigh        = zHigh;
      zone->zoneLow         = zLow;
      zone->createdTime     = zTime;
      zone->createdBarIndex = barIdx;

      m_zones.Add(zone);
      m_registered_keys.Add(key);
     }

   // --- STEP 1: HARVEST DETECTED SMC ZONES ---
   void              HarvestZones(int current_i, const std::vector<datetime> &time,
                                  CDemandSupplyLogic* ds, CSwingPOILogic* sp,
                                  COrderBlockLogic* ob, CFlipZoneLogic* fz,
                                  CBreakerBlockLogic* bb, CMarketStructure* ms,
                                  ZigZag* zz, double pipSize)
     {
      // 1. Order Blocks
      if(m_checkOB && ob != NULL)
        {
         for(int i = 0; i < ob->poi_demandTime.Total(); i++)
           {
            datetime zt = (datetime)ob->poi_demandTime.At(i);
            if(ob->ob_time_found(&ms->ob_bull_struct_times, zt) && ob->ob_time_found(&ob->ob_bull_valid_times, zt))
               RegisterZone("Order Block", true, ob->poi_demandZoneHigh.At(i), ob->poi_demandZoneLow.At(i), zt, current_i, zz, pipSize);
           }
         for(int i = 0; i < ob->poi_supplyTime.Total(); i++)
           {
            datetime zt = (datetime)ob->poi_supplyTime.At(i);
            if(ob->ob_time_found(&ms->ob_bear_struct_times, zt) && ob->ob_time_found(&ob->ob_bear_valid_times, zt))
               RegisterZone("Order Block", false, ob->poi_supplyZoneHigh.At(i), ob->poi_supplyZoneLow.At(i), zt, current_i, zz, pipSize);
           }
        }

      // 2. Swing POIs
      if(m_checkSP && sp != NULL)
        {
         for(int i = 0; i < sp->poi_demandTime.Total(); i++)
           {
            datetime zt = (datetime)sp->poi_demandTime.At(i);
            if(sp->ob_time_found(&ms->ob_bull_struct_times, zt))
               RegisterZone("Swing POI", true, sp->poi_demandZoneHigh.At(i), sp->poi_demandZoneLow.At(i), zt, current_i, zz, pipSize);
           }
         for(int i = 0; i < sp->poi_supplyTime.Total(); i++)
           {
            datetime zt = (datetime)sp->poi_supplyTime.At(i);
            if(sp->ob_time_found(&ms->ob_bear_struct_times, zt))
               RegisterZone("Swing POI", false, sp->poi_supplyZoneHigh.At(i), sp->poi_supplyZoneLow.At(i), zt, current_i, zz, pipSize);
           }
        }

      // 3. Demand / Supply Zones
      if(m_checkDS && ds != NULL)
        {
         for(int i = 0; i < ds->poi_demandTime.Total(); i++)
            RegisterZone("Demand / Supply", true, ds->poi_demandZoneHigh.At(i), ds->poi_demandZoneLow.At(i), (datetime)ds->poi_demandTime.At(i), current_i, zz, pipSize);
         for(int i = 0; i < ds->poi_supplyTime.Total(); i++)
            RegisterZone("Demand / Supply", false, ds->poi_supplyZoneHigh.At(i), ds->poi_supplyZoneLow.At(i), (datetime)ds->poi_supplyTime.At(i), current_i, zz, pipSize);
        }

      // 4. Flip Zones
      if(m_checkFZ && fz != NULL)
        {
         for(int i = 0; i < fz->fz_time.Total(); i++)
           {
            bool isDemFlip = (fz->fz_type.At(i) == 1);
            RegisterZone("Flip Zone", isDemFlip, fz->fz_zoneHigh.At(i), fz->fz_zoneLow.At(i), (datetime)fz->fz_time.At(i), current_i, zz, pipSize);
           }
        }

      // 5. Breaker Blocks
      if(m_checkBB && bb != NULL)
        {
         for(int i = 0; i < bb->bb_time.Total(); i++)
           {
            bool isBullBreaker = (bb->bb_type.At(i) == 1);
            RegisterZone("Breaker Block", isBullBreaker, bb->bb_zoneHigh.At(i), bb->bb_zoneLow.At(i), (datetime)bb->bb_time.At(i), current_i, zz, pipSize);
           }
        }
     }

   // --- STEP 2: MITIGATION EVALUATION ---
   void              UpdateMitigations(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low)
     {
      for(int z = 0; z < m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)m_zones.At(z);
         if(zone == NULL || zone->isMitigated)
            continue;

         if(time[current_i] <= zone->createdTime)
            continue;

         if(zone->isBullish)
           {
            // Bullish Zone: Mitigated when candle low trades below zone->low
            if(low[current_i] < zone->zoneLow)
              {
               zone->isMitigated        = true;
               zone->mitigationTime     = time[current_i];
               zone->mitigationBarIndex = current_i;
              }
           }
         else
           {
            // Bearish Zone: Mitigated when candle high trades above zone->high
            if(high[current_i] > zone->zoneHigh)
              {
               zone->isMitigated        = true;
               zone->mitigationTime     = time[current_i];
               zone->mitigationBarIndex = current_i;
              }
           }
        }
     }

   // --- STEP 3: INDUCEMENT TOUCH EVALUATION ---
   void              UpdateTouches(int current_i, const std::vector<datetime> &time, const std::vector<double> &open,
                                   const std::vector<double> &high, const std::vector<double> &low, const std::vector<double> &close,
                                   ZigZag* zz, double pipSize)
     {
      if(zz == NULL || zz->pivots->Total() < 2)
         return;

      int p_total = zz->pivots->Total();
      double prox = m_proximityPips * pipSize;

      for(int z = 0; z < m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)m_zones.At(z);
         if(zone == NULL)
            continue;

         datetime cutoffTime = zone->isMitigated ? zone->mitigationTime : time[current_i];

         for(int p_idx = 0; p_idx <= p_total - 2; p_idx++)
           {
            Pivot* p = (Pivot*)zz->pivots->At(p_idx);
            if(p == NULL || (zz->projection != NULL && p == zz->projection))
               continue;

            datetime p_time = p->end->time;

            if(p_time <= zone->createdTime || p_time > cutoffTime)
               continue;

            if(zone->HasPivotTouched(p_time))
               continue;

            int p_bar = p->end->index;
            if(p_bar < 0 || p_bar >= ArraySize(time) || time[p_bar] != p_time)
               p_bar = FindBarIndexByTime(p_time, time, current_i + 1);

            if(p_bar < 0)
               continue;

            double c_open  = open[p_bar];
            double c_high  = high[p_bar];
            double c_low   = low[p_bar];
            double c_close = close[p_bar];
            double p_price = p->end->price;

            // -------------------------------------------------------------
            // BULLISH ZONE (Buyers' Inducement Candidate)
            // -------------------------------------------------------------
            if(zone->isBullish)
              {
               if(!p->isHigh)
                 {
                  if(c_low >= zone->zoneLow)
                    {
                     double touchCeiling = zone->zoneHigh + prox;
                     bool pivot_in_zone = (p_price <= touchCeiling && p_price >= zone->zoneLow);
                     bool low_in_zone   = (c_low <= touchCeiling && c_low >= zone->zoneLow);
                     bool close_in_zone = (c_close <= touchCeiling && c_close >= zone->zoneLow);
                     bool body_in_zone  = (MathMin(c_open, c_close) <= touchCeiling && MathMax(c_open, c_close) >= zone->zoneLow);

                     if(pivot_in_zone || low_in_zone || close_in_zone || body_in_zone)
                       {
                        zone->touchTimes.Add((long)p_time);
                        zone->touchCount++;
                        zone->lastTouchTime = p_time;

                        if(zone->touchCount >= m_minTouches)
                          {
                           zone->isInducement = true;
                           if(zone->inducementTime == 0)
                              zone->inducementTime = p_time;
                          }
                       }
                    }
                 }
              }
            // -------------------------------------------------------------
            // BEARISH ZONE (Sellers' Inducement Candidate)
            // -------------------------------------------------------------
            else
              {
               if(p->isHigh)
                 {
                  if(c_high <= zone->zoneHigh)
                    {
                     double touchFloor = zone->zoneLow - prox;
                     bool pivot_in_zone = (p_price >= touchFloor && p_price <= zone->zoneHigh);
                     bool high_in_zone  = (c_high >= touchFloor && c_high <= zone->zoneHigh);
                     bool close_in_zone = (c_close >= touchFloor && c_close <= zone->zoneHigh);
                     bool body_in_zone  = (MathMax(c_open, c_close) >= touchFloor && MathMin(c_open, c_close) <= zone->zoneHigh);

                     if(pivot_in_zone || high_in_zone || close_in_zone || body_in_zone)
                       {
                        zone->touchTimes.Add((long)p_time);
                        zone->touchCount++;
                        zone->lastTouchTime = p_time;

                        if(zone->touchCount >= m_minTouches)
                          {
                           zone->isInducement = true;
                           if(zone->inducementTime == 0)
                              zone->inducementTime = p_time;
                          }
                       }
                    }
                 }
              }
           }
        }
     }

   // --- STEP 4: COORDINATED PROCESSING BATCH ---
   void              Process(int current_i, const std::vector<datetime> &time, const std::vector<double> &open,
                             const std::vector<double> &high, const std::vector<double> &low, const std::vector<double> &close,
                             ZigZag* zz, CMarketStructure* ms, CDemandSupplyLogic* ds,
                             CSwingPOILogic* sp, COrderBlockLogic* ob, CFlipZoneLogic* fz,
                             CBreakerBlockLogic* bb, double pipSize)
     {
      HarvestZones(current_i, time, ds, sp, ob, fz, bb, ms, zz, pipSize);
      UpdateMitigations(current_i, time, high, low);
      UpdateTouches(current_i, time, open, high, low, close, zz, pipSize);
      ENUM_TIMEFRAMES tf=(ms!=NULL && ms->m_tf!=PERIOD_CURRENT) ? ms->m_tf : (ENUM_TIMEFRAMES)_Period;
      datetime knownAt=time[current_i]+PeriodSeconds(tf);
      for(int z=0;z<m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)m_zones.At(z);
         if(zone!=NULL && zone->isInducement && zone->qualifiedTime==0) zone->qualifiedTime=knownAt;
        }
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\Inducements.mqh
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\Inducements.mqh

//+------------------------------------------------------------------+
//|                             Include\Custom\Marcotrades\liquidity_blocks.mqh |
//|                 Smart Money Concepts: Liquidity Block Engine     |
//|                 - TF-BL-LB-BSL (Bullish LB at Pivot Low of BSL-Swept) |
//|                 - TF-BR-LB-SSL (Bearish LB at Pivot High of SSL-Swept)|
//|                 - TF-BL-LB-IND (Buyers' Inducement Swept CHoCH/BOS)   |
//|                 - TF-BR-LB-IND (Sellers' Inducement Swept CHoCH/BOS)  |
//|                 - STRICT 5+ STRUCTURE CONFIRMATION (CHoCH -> BOS)     |
//+------------------------------------------------------------------+



#ifndef MARCOTRADES_LIQUIDITY_BLOCK_MQH
#define MARCOTRADES_LIQUIDITY_BLOCK_MQH













enum ENUM_LB_TRIGGER
  {
   LB_TRIGGER_BL_BSL,    // TF-BL-LB-BSL
   LB_TRIGGER_BR_SSL,    // TF-BR-LB-SSL
   LB_TRIGGER_BL_IND,    // TF-BL-LB-IND
   LB_TRIGGER_BR_IND,    // TF-BR-LB-IND
   LB_TRIGGER_BL_IND_BSL,// TF-BL-LB-IND-BSL
   LB_TRIGGER_BR_IND_SSL // TF-BR-LB-IND-SSL
  };

//+------------------------------------------------------------------+
//| Liquidity Block Object Model                                     |
//+------------------------------------------------------------------+
class CLiquidityBlock : public CObject
  { public: CLiquidityBlock* operator->(){return this;} const CLiquidityBlock* operator->()const{return this;}
public:
   string            id;
   bool              isBullish;
   ENUM_LB_TRIGGER   triggerType;
   double            zoneHigh;
   double            zoneLow;
   datetime          createdTime;
   int               createdBarIndex;
   datetime          sweepLineTime;
   datetime          inducementOriginTime;
   datetime          causalChochTime; // Event which initiated this LB, distinct from its origin candle.

   bool              isMitigated;
   datetime          mitigationTime;
   int               mitigationBarIndex;

   int               touchCount;
   CArrayLong        touchTimes;

                     CLiquidityBlock()
     {
      id                   = "";
      isBullish            = true;
      triggerType          = LB_TRIGGER_BL_BSL;
      zoneHigh             = 0.0;
      zoneLow              = 0.0;
      createdTime          = 0;
      createdBarIndex      = 0;
      sweepLineTime        = 0;
      inducementOriginTime = 0;
      causalChochTime = 0;
      isMitigated          = false;
      mitigationTime       = 0;
      mitigationBarIndex   = 0;
      touchCount           = 0;
     }

                    ~CLiquidityBlock()
     {
      if(id != "")
        {
         ObjectDelete(0, string("LB_") + id);
         ObjectDelete(0, string("LB_") + id + "_lbl");
        }
     }

   bool              HasPivotTouched(datetime p_time)
     {
      for(int i = 0; i < touchTimes.Total(); i++)
        {
         if((datetime)touchTimes.At(i) == p_time)
            return true;
        }
      return false;
     }

   string            GetNomenclature(string tfStr)
     {
      switch(triggerType)
        {
         case LB_TRIGGER_BL_IND:
            return tfStr + "-BL-LB-IND";
         case LB_TRIGGER_BR_IND:
            return tfStr + "-BR-LB-IND";
         case LB_TRIGGER_BL_IND_BSL:
            return tfStr + "-BL-LB-IND-BSL";
         case LB_TRIGGER_BR_IND_SSL:
            return tfStr + "-BR-LB-IND-SSL";
         case LB_TRIGGER_BL_BSL:
            return tfStr + "-BL-LB-BSL";
         case LB_TRIGGER_BR_SSL:
            return tfStr + "-BR-LB-SSL";
        }
      return tfStr + "-LB";
     }
  };

struct SInducementMitigationTracker
  { public: SInducementMitigationTracker* operator->(){return this;} const SInducementMitigationTracker* operator->()const{return this;}
   string            inducementId;
   bool              isBullishInducement;
   double            inducementLevel;
   datetime          mitigationTime;
   datetime          inducementOriginTime;
   bool              chochCaptured;

   // Two-Step Confirmation State Tracker for 5+ prevailing structures
   bool              waitingForBOS;
   datetime          chochTime;
   datetime          pendingProtTime;
   double            pendingZHigh;
   double            pendingZLow;
  };

//+------------------------------------------------------------------+
//| Core Liquidity Block Logic Engine                                |
//+------------------------------------------------------------------+
class CLiquidityBlockLogic
  { public: CLiquidityBlockLogic* operator->(){return this;} const CLiquidityBlockLogic* operator->()const{return this;}
public:
   double            m_symbolPoint;
   bool              m_trackSweepsAnywhere;
   bool              m_trackPostInducementCHoCH;

   CArrayString      m_registered_lb_keys;
   datetime          m_last_breakout_evaluated;
   long              m_last_swept_event_id;

   std::vector<SInducementMitigationTracker> m_mitig_trackers;

   int               GetRequiredStructureCount(CMarketStructure* ms)
     {
      ENUM_TIMEFRAMES tf = (ms != NULL && ms->m_tf != PERIOD_CURRENT) ? ms->m_tf : _Period;
      int mins = PeriodSeconds(tf) / 60;

      // LTF: M5, M3, M1 (<= 5 minutes) -> requires min 5 structures
      return CTradeRejection::RequiredStructures(mins);
     }
   int               FindBarIndexByTime(datetime targetTime, const std::vector<datetime> &time, int rates_total)
     {
      int left = 0;
      int right = rates_total - 1;
      while(left <= right)
        {
         int mid = left + (right - left) / 2;
         if(time[mid] == targetTime)
            return mid;
         if(time[mid] < targetTime)
            left = mid + 1;
         else
            right = mid - 1;
        }
      return -1;
     }

public:
   CArrayObj         m_liquidity_blocks;
   CArrayObj         m_exit_sources; // Structurally valid sources vetoed for new entries by IND overlap.

                     CLiquidityBlockLogic()
     {
      m_symbolPoint = _Point; // Default for legacy single-chart callers.
      m_last_swept_event_id      = 0;
      m_trackSweepsAnywhere       = true;
      m_trackPostInducementCHoCH = true;
      m_last_breakout_evaluated  = 0;
      m_liquidity_blocks.FreeMode(true);
      m_exit_sources.FreeMode(true);
     }

                    ~CLiquidityBlockLogic()
     {
      Cleanup();
     }

   void              Init(bool trackSweepsAnywhere = true, bool trackPostInducementCHoCH = true, double symbolPoint = 0.0)
     {
      m_symbolPoint = symbolPoint > 0.0 ? symbolPoint : _Point;
      m_trackSweepsAnywhere       = trackSweepsAnywhere;
      m_trackPostInducementCHoCH = trackPostInducementCHoCH;
     }

   void              ResetState()
     {
      m_liquidity_blocks.Clear();
      m_exit_sources.Clear();
      m_registered_lb_keys.Clear();
      ArrayResize(m_mitig_trackers, 0);
      m_last_breakout_evaluated = 0;
      m_last_swept_event_id = 0;
     }

   void              Cleanup()
     {
      ResetState();
     }

   bool              IsLBRegistered(string key)
     {
      for(int i = 0; i < m_registered_lb_keys.Total(); i++)
        {
         if(m_registered_lb_keys.At(i) == key)
            return true;
        }
      return false;
     }

   CLiquidityBlock*  GetContainingLiquidityBlock(CInducementZone* ind)
     {
      if(ind == NULL || CheckPointer(ind) != POINTER_DYNAMIC || !ind->isInducement)
         return NULL;

      CLiquidityBlock* best = NULL;
      double bestHeight = DBL_MAX;
      datetime indCreatedTime = (ind->inducementTime > 0 ? ind->inducementTime : ind->createdTime);
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb->isBullish != ind->isBullish)
            continue;
         if(indCreatedTime < lb->createdTime)
            continue;
         if(lb->isMitigated && lb->mitigationTime > 0 && indCreatedTime > lb->mitigationTime)
            continue;
         if(ind->zoneLow < lb->zoneLow || ind->zoneHigh > lb->zoneHigh)
            continue;

         double height = lb->zoneHigh - lb->zoneLow;
         if(best == NULL || height < bestHeight)
           {
            best = lb;
            bestHeight = height;
           }
        }
      return best;
     }

   string            GetDisplayNomenclature(CLiquidityBlock* lb, string tfStr, CInducementLogic* indLogic, bool includeMitigatedInducements)
     {
      string text = lb->GetNomenclature(tfStr);
      if(indLogic == NULL || CheckPointer(indLogic) != POINTER_DYNAMIC)
         return text;

      for(int z = 0; z < indLogic->m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic->m_zones.At(z);
         if(ind != NULL && ind->isMitigated && !includeMitigatedInducements)
            continue;
         if(GetContainingLiquidityBlock(ind) == lb)
            return text + (lb->isBullish ? " & BL-IND" : " & BR-IND");
        }
      return text;
     }

   void RecordExitSource(bool bull, ENUM_LB_TRIGGER trigger, double high, double low,
                         datetime origin, int bar, datetime sweep, datetime cause)
     {
      if(cause<=0) return; // A source must have an explicit confirmed CHoCH link.
      string id=string("EXIT_ONLY_LB_") +(bull ? "BULL_" : "BEAR_")+IntegerToString((long)origin)+string("_") +IntegerToString((long)cause);
      for(int i=0;i<m_exit_sources.Total();i++)
        {
         CLiquidityBlock* known=(CLiquidityBlock*)m_exit_sources.At(i);
         if(known!=NULL && known->id==id) return;
        }
      CLiquidityBlock* source=new CLiquidityBlock();
      source->id=id; source->isBullish=bull; source->triggerType=trigger;
      source->zoneHigh=high; source->zoneLow=low; source->createdTime=origin;
      source->createdBarIndex=bar; source->sweepLineTime=sweep; source->causalChochTime=cause;
      m_exit_sources.Add(source);
     }

   void RefreshExitSources(CMarketStructure* structure, datetime now, double high, double low)
     {
      if(structure==NULL) return;
      for(int i=m_exit_sources.Total()-1;i>=0;i--)
        {
         CLiquidityBlock* source=(CLiquidityBlock*)m_exit_sources.At(i);
         if(source==NULL) continue;
         bool valid=false;
         for(int e=structure->all_event_times.Total()-1;e>=0;e--)
            if((datetime)structure->all_event_times.At(e)==source->causalChochTime)
              {
               valid=structure->all_event_names.At(e)==(source->isBullish ? "BL-CHoCH" : "BR-CHoCH");
               break;
              }
         if(!valid) { m_exit_sources.Delete(i); continue; }
         if(!source->isMitigated && now>source->createdTime &&
            CTradeRejection::BoundaryBroken(source->isBullish,low,high,source->zoneLow,source->zoneHigh,0.0))
           { source->isMitigated=true; source->mitigationTime=now; }
        }
     }

   // Register Liquidity Block with active Inducement overlap filter
   void              RegisterLiquidityBlock(bool isBull, ENUM_LB_TRIGGER trigger, double zHigh, double zLow, datetime zTime, int barIdx, datetime sweepLineTime, CInducementLogic* indLogic, datetime indOriginTime = 0, datetime causalChoch = 0)
     {
      // OVERLAP FILTER:
      // A BR-LB (SSL/IND) is invalid if its pivot candle originates / lies in the premises of an active BR-IND
      // A BL-LB (BSL/IND) is invalid if its pivot candle originates / lies in the premises of an active BL-IND
      if(indLogic != NULL)
        {
         for(int z = 0; z < indLogic->m_zones.Total(); z++)
           {
            CInducementZone* iz = (CInducementZone*)indLogic->m_zones.At(z);
            if(iz == NULL || !iz->isInducement)
               continue;

            datetime indTime = (iz->inducementTime > 0 ? iz->inducementTime : iz->createdTime);
            if(CTradeRejection::ActiveInducementOverlap(isBull, zLow, zHigh, zTime,
                  iz->isBullish, iz->zoneLow, iz->zoneHigh, indTime, iz->mitigationTime))
              {
               // Reject new entries here, but retain the structure for protecting an existing opposite trade.
               RecordExitSource(isBull,trigger,zHigh,zLow,zTime,barIdx,sweepLineTime,causalChoch);
               return;
              }
           }
        }

      // Check if already registered
      double zoneTolerance = MathMax(m_symbolPoint, 1e-10);
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* exist = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(exist != NULL && CheckPointer(exist) == POINTER_DYNAMIC && CTradeRejection::SameLB(isBull, zTime, zLow, zHigh, exist->isBullish, exist->createdTime, exist->zoneLow, exist->zoneHigh, zoneTolerance))
           {
            if(exist->triggerType != LB_TRIGGER_BL_IND_BSL && exist->triggerType != LB_TRIGGER_BR_IND_SSL)
              {
               if((exist->triggerType == LB_TRIGGER_BL_BSL && trigger == LB_TRIGGER_BL_IND) ||
                  (exist->triggerType == LB_TRIGGER_BL_IND && trigger == LB_TRIGGER_BL_BSL))
                  exist->triggerType = LB_TRIGGER_BL_IND_BSL;
               else
                  if((exist->triggerType == LB_TRIGGER_BR_SSL && trigger == LB_TRIGGER_BR_IND) ||
                     (exist->triggerType == LB_TRIGGER_BR_IND && trigger == LB_TRIGGER_BR_SSL))
                     exist->triggerType = LB_TRIGGER_BR_IND_SSL;
                  else
                     if(trigger == LB_TRIGGER_BL_IND || trigger == LB_TRIGGER_BR_IND)
                        exist->triggerType = trigger;
              }

            if(causalChoch > 0) exist->causalChochTime = causalChoch;
            if(sweepLineTime > 0 && exist->sweepLineTime == 0)
               exist->sweepLineTime = sweepLineTime;

            if(indOriginTime > 0 && exist->inducementOriginTime == 0)
               exist->inducementOriginTime = indOriginTime;

            return;
           }
        }

      string key = string("LB_") + (isBull ? "BULL_" : "BEAR_") + IntegerToString((long)zTime);
      if(IsLBRegistered(key))
         return;

      CLiquidityBlock* lb = new CLiquidityBlock();
      lb->id                   = key;
      lb->isBullish            = isBull;
      lb->triggerType          = trigger;
      lb->zoneHigh             = zHigh;
      lb->zoneLow              = zLow;
      lb->createdTime          = zTime;
      lb->createdBarIndex      = barIdx;
      lb->sweepLineTime        = sweepLineTime;
      lb->inducementOriginTime = indOriginTime;
      lb->causalChochTime = causalChoch;

      m_liquidity_blocks.Add(lb);
      m_registered_lb_keys.Add(key);
     }

   bool              ResolveSwingPOIBounds(datetime protTime, bool isBullish, CSwingPOILogic* sp,
                                           const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low,
                                           int rates_total, double &outHigh, double &outLow)
     {
      outHigh = 0.0;
      outLow  = 0.0;

      if(sp != NULL && CheckPointer(sp) == POINTER_DYNAMIC)
        {
         if(isBullish)
           {
            for(int k = 0; k < sp->poi_demandTime.Total(); k++)
              {
               if((datetime)sp->poi_demandTime.At(k) == protTime)
                 {
                  outHigh = sp->poi_demandZoneHigh.At(k);
                  outLow  = sp->poi_demandZoneLow.At(k);
                  return true;
                 }
              }
           }
         else
           {
            for(int k = 0; k < sp->poi_supplyTime.Total(); k++)
              {
               if((datetime)sp->poi_supplyTime.At(k) == protTime)
                 {
                  outHigh = sp->poi_supplyZoneHigh.At(k);
                  outLow  = sp->poi_supplyZoneLow.At(k);
                  return true;
                 }
              }
           }
        }

      int idx = FindBarIndexByTime(protTime, time, rates_total);
      if(idx >= 0 && idx < rates_total)
        {
         outHigh = high[idx];
         outLow  = low[idx];
         return true;
        }

      return false;
     }

   void              ProcessSweptAnywhere(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low,
                                          CMarketStructure* ms, CSwingPOILogic* sp, ZigZag* zz, CInducementLogic* indLogic)
     {
      if(!m_trackSweepsAnywhere || ms == NULL || CheckPointer(ms) != POINTER_DYNAMIC)
         return;

      // 1. Scrub phantom BR-LB-IND if its origin line was retroactively renamed to BSL-Swept
      for(int s = 0; s < ms->swept_bsl_times.Total(); s++)
        {
         datetime sweptTime = (datetime)ms->swept_bsl_times.At(s);
         for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
            if(lb != NULL && lb->triggerType == LB_TRIGGER_BR_IND && lb->sweepLineTime == sweptTime)
              {
               m_liquidity_blocks.Delete(i);
              }
           }
        }

      // 2. Scrub phantom BL-LB-IND if its origin line was retroactively renamed to SSL-Swept
      for(int s = 0; s < ms->swept_ssl_times.Total(); s++)
        {
         datetime sweptTime = (datetime)ms->swept_ssl_times.At(s);
         for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
            if(lb != NULL && lb->triggerType == LB_TRIGGER_BL_IND && lb->sweepLineTime == sweptTime)
              {
               m_liquidity_blocks.Delete(i);
              }
           }
        }

      for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC)
            continue;

         if((lb->triggerType == LB_TRIGGER_BL_BSL || lb->triggerType == LB_TRIGGER_BL_IND_BSL) && lb->sweepLineTime > 0)
           {
            bool found = false;
            for(int j = 0; j < ms->swept_bsl_times.Total(); j++)
              {
               if(ms->swept_bsl_times.At(j) == (long)lb->sweepLineTime)
                 {
                  found = true;
                  break;
                 }
              }
            if(!found)
              {
               string sweep_key = string("LB_SWEEP_BSL_") + IntegerToString(lb->sweepLineTime);
               for(int k = m_registered_lb_keys.Total() - 1; k >= 0; k--)
                 {
                  if(m_registered_lb_keys.At(k) == sweep_key || m_registered_lb_keys.At(k) == lb->id)
                     m_registered_lb_keys.Delete(k);
                 }
               m_liquidity_blocks.Delete(i);
              }
           }
         else
            if((lb->triggerType == LB_TRIGGER_BR_SSL || lb->triggerType == LB_TRIGGER_BR_IND_SSL) && lb->sweepLineTime > 0)
              {
               bool found = false;
               for(int j = 0; j < ms->swept_ssl_times.Total(); j++)
                 {
                  if(ms->swept_ssl_times.At(j) == (long)lb->sweepLineTime)
                    {
                     found = true;
                     break;
                    }
                 }
              }
        }

      for(int s = 0; s < ms->swept_bsl_times.Total(); s++)
        {
         datetime sweepLineTime = (datetime)ms->swept_bsl_times.At(s);
         string   key           = string("LB_SWEEP_BSL_") + IntegerToString(sweepLineTime);

         if(IsLBRegistered(key))
            continue;

         datetime pivotLowTime = 0;

         if(zz != NULL && CheckPointer(zz) == POINTER_DYNAMIC)
            pivotLowTime = ms->GetSweepExtremePivotTime(sweepLineTime, false, zz);

         if(pivotLowTime > 0)
           {
            double zHigh = 0.0, zLow = 0.0;
            if(ResolveSwingPOIBounds(pivotLowTime, true, sp, time, high, low, current_i + 1, zHigh, zLow))
              {
               RegisterLiquidityBlock(true, LB_TRIGGER_BL_BSL, zHigh, zLow, pivotLowTime, current_i, sweepLineTime, indLogic, 0,
                                      ms->GetSweepConfirmingChochTime(sweepLineTime, false));
               m_registered_lb_keys.Add(key);
              }
           }
        }

      for(int s = 0; s < ms->swept_ssl_times.Total(); s++)
        {
         datetime sweepLineTime = (datetime)ms->swept_ssl_times.At(s);
         string   key           = string("LB_SWEEP_SSL_") + IntegerToString(sweepLineTime);

         if(IsLBRegistered(key))
            continue;

         datetime pivotHighTime = 0;

         if(zz != NULL && CheckPointer(zz) == POINTER_DYNAMIC)
            pivotHighTime = ms->GetSweepExtremePivotTime(sweepLineTime, true, zz);

         if(pivotHighTime > 0)
           {
            double zHigh = 0.0, zLow = 0.0;
            if(ResolveSwingPOIBounds(pivotHighTime, false, sp, time, high, low, current_i + 1, zHigh, zLow))
              {
               RegisterLiquidityBlock(false, LB_TRIGGER_BR_SSL, zHigh, zLow, pivotHighTime, current_i, sweepLineTime, indLogic, 0,
                                      ms->GetSweepConfirmingChochTime(sweepLineTime, true));
               m_registered_lb_keys.Add(key);
              }
           }
        }
     }

   void              SyncInducementMitigations(CInducementLogic* indLogic)
     {
      if(!m_trackPostInducementCHoCH || indLogic == NULL || CheckPointer(indLogic) != POINTER_DYNAMIC)
         return;

      for(int z = 0; z < indLogic->m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic->m_zones.At(z);
         if(ind == NULL || CheckPointer(ind) != POINTER_DYNAMIC || !ind->isInducement || !ind->isMitigated || ind->mitigationTime == 0)
            continue;

         bool alreadyTracked = false;
         for(int t = 0; t < ArraySize(m_mitig_trackers); t++)
           {
            if(m_mitig_trackers[t].inducementId == ind->id)
              {
               alreadyTracked = true;
               break;
              }
           }

         if(!alreadyTracked)
           {
            int sz = ArraySize(m_mitig_trackers);
            ArrayResize(m_mitig_trackers, sz + 1);
            m_mitig_trackers[sz].inducementId         = ind->id;
            m_mitig_trackers[sz].isBullishInducement  = ind->isBullish;
            m_mitig_trackers[sz].inducementLevel      = ind->isBullish ? ind->zoneLow : ind->zoneHigh;
            m_mitig_trackers[sz].mitigationTime       = ind->mitigationTime;
            m_mitig_trackers[sz].inducementOriginTime = ind->createdTime;
            m_mitig_trackers[sz].chochCaptured        = false;
            m_mitig_trackers[sz].waitingForBOS        = false;
            m_mitig_trackers[sz].chochTime            = 0;
            m_mitig_trackers[sz].pendingProtTime      = 0;
            m_mitig_trackers[sz].pendingZHigh         = 0.0;
            m_mitig_trackers[sz].pendingZLow          = 0.0;
           }
        }
     }

   //+------------------------------------------------------------------+
   //| Strict 3+ Structure Confirmation (CHoCH -> BOS) Implementation   |
   //+------------------------------------------------------------------+
   //+------------------------------------------------------------------+
   //| Adaptive Structure Confirmation (HTF: 3+ | LTF: 5+)              |
   //+------------------------------------------------------------------+
   void              ProcessPostInducementCHoCH(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low,
         CMarketStructure* ms, CSwingPOILogic* sp, CInducementLogic* indLogic)
     {
      if(!m_trackPostInducementCHoCH || ms == NULL || CheckPointer(ms) != POINTER_DYNAMIC)
         return;

      if(ms->last_breakout_time == 0)
         return;

      datetime boTime = ms->last_breakout_time;
      int minReq = GetRequiredStructureCount(ms); // 3 for HTF (H4, H1, M15, M10) | 5 for LTF (M5, M3, M1)

      for(int t = 0; t < ArraySize(m_mitig_trackers); t++)
        {
         if(m_mitig_trackers[t].chochCaptured)
            continue;

         if(boTime < m_mitig_trackers[t].mitigationTime)
            continue;

         // -----------------------------------------------------------------
         // CASE A: Post Buyers' Inducement Mitigation -> Candidate BL-LB-IND
         // -----------------------------------------------------------------
         if(m_mitig_trackers[t].isBullishInducement)
           {
            // If waiting for BL-BOS (because preceding structures met threshold)
            if(m_mitig_trackers[t].waitingForBOS)
              {
               if(ms->trend == 1 && (ms->ev1_name == "BL-BOS" || ms->ev2_name == "BL-BOS"))
                 {
                  RegisterLiquidityBlock(true, LB_TRIGGER_BL_IND, m_mitig_trackers[t].pendingZHigh, m_mitig_trackers[t].pendingZLow,
                                         m_mitig_trackers[t].pendingProtTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, m_mitig_trackers[t].chochTime);
                  m_mitig_trackers[t].chochCaptured = true;
                  m_mitig_trackers[t].waitingForBOS = false;
                 }
               else
                  if(ms->trend == -1 && (ms->ev1_name == "BR-CHoCH" || ms->ev1_name == "BR-BOS" || ms->ev1_name == "SSL-Swept"))
                    {
                     m_mitig_trackers[t].waitingForBOS = false; // Invalidated
                    }
               continue;
              }

            if(ms->trend == 1 && (ms->ev1_name == "BL-CHoCH" || ms->ev2_name == "BL-CHoCH" || ms->ev1_name == "BL-BOS" || ms->ev2_name == "BL-BOS"))
              {
               datetime protTime = ms->protected_level_time;
               if(protTime >= m_mitig_trackers[t].mitigationTime || ms->protected_level_price <= m_mitig_trackers[t].inducementLevel)
                 {
                  double zHigh = 0.0, zLow = 0.0;
                  if(ResolveSwingPOIBounds(protTime, true, sp, time, high, low, current_i + 1, zHigh, zLow))
                    {
                     int bearCount = ms->GetPrecedingBearishStructureCount(boTime);
                     if(bearCount >= minReq)
                       {
                        // Exceeded threshold: Wait for tf-BL-CHoCH -> tf-BL-BOS
                        m_mitig_trackers[t].waitingForBOS   = true;
                        m_mitig_trackers[t].chochTime       = boTime;
                        m_mitig_trackers[t].pendingProtTime = protTime;
                        m_mitig_trackers[t].pendingZHigh    = zHigh;
                        m_mitig_trackers[t].pendingZLow     = zLow;
                       }
                     else
                       {
                        RegisterLiquidityBlock(true, LB_TRIGGER_BL_IND, zHigh, zLow, protTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, ms->ev1_name == "BL-CHoCH" ? boTime : 0);
                        m_mitig_trackers[t].chochCaptured = true;
                       }
                    }
                 }
              }
           }
         // -----------------------------------------------------------------
         // CASE B: Post Sellers' Inducement Mitigation -> Candidate BR-LB-IND
         // -----------------------------------------------------------------
         else
           {
            // If waiting for BR-BOS (because preceding structures met threshold)
            if(m_mitig_trackers[t].waitingForBOS)
              {
               if(ms->trend == -1 && (ms->ev1_name == "BR-BOS" || ms->ev2_name == "BR-BOS"))
                 {
                  RegisterLiquidityBlock(false, LB_TRIGGER_BR_IND, m_mitig_trackers[t].pendingZHigh, m_mitig_trackers[t].pendingZLow,
                                         m_mitig_trackers[t].pendingProtTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, m_mitig_trackers[t].chochTime);
                  m_mitig_trackers[t].chochCaptured = true;
                  m_mitig_trackers[t].waitingForBOS = false;
                 }
               else
                  if(ms->trend == 1 && (ms->ev1_name == "BL-CHoCH" || ms->ev1_name == "BL-BOS" || ms->ev1_name == "BSL-Swept"))
                    {
                     m_mitig_trackers[t].waitingForBOS = false; // Invalidated
                    }
               continue;
              }

            if(ms->trend == -1 && (ms->ev1_name == "BR-CHoCH" || ms->ev2_name == "BR-CHoCH" || ms->ev1_name == "BR-BOS" || ms->ev2_name == "BR-BOS"))
              {
               datetime protTime = ms->protected_level_time;
               if(protTime >= m_mitig_trackers[t].mitigationTime || ms->protected_level_price >= m_mitig_trackers[t].inducementLevel)
                 {
                  double zHigh = 0.0, zLow = 0.0;
                  if(ResolveSwingPOIBounds(protTime, false, sp, time, high, low, current_i + 1, zHigh, zLow))
                    {
                     int bullCount = ms->GetPrecedingBullishStructureCount(boTime);
                     if(bullCount >= minReq)
                       {
                        // Exceeded threshold: Wait for tf-BR-CHoCH -> tf-BR-BOS
                        m_mitig_trackers[t].waitingForBOS   = true;
                        m_mitig_trackers[t].chochTime       = boTime;
                        m_mitig_trackers[t].pendingProtTime = protTime;
                        m_mitig_trackers[t].pendingZHigh    = zHigh;
                        m_mitig_trackers[t].pendingZLow     = zLow;
                       }
                     else
                       {
                        RegisterLiquidityBlock(false, LB_TRIGGER_BR_IND, zHigh, zLow, protTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, ms->ev1_name == "BR-CHoCH" ? boTime : 0);
                        m_mitig_trackers[t].chochCaptured = true;
                       }
                    }
                 }
              }
           }
        }
     }
   void              UpdateLBMitigations(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low)
     {
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb->isMitigated)
            continue;

         if(time[current_i] <= lb->createdTime)
            continue;

         if(lb->isBullish)
           {
            if(CTradeRejection::BoundaryBroken(true, low[current_i], high[current_i], lb->zoneLow, lb->zoneHigh, 0.0))
              {
               lb->isMitigated        = true;
               lb->mitigationTime     = time[current_i];
               lb->mitigationBarIndex = current_i;
              }
           }
         else
           {
            if(CTradeRejection::BoundaryBroken(false, low[current_i], high[current_i], lb->zoneLow, lb->zoneHigh, 0.0))
              {
               lb->isMitigated        = true;
               lb->mitigationTime     = time[current_i];
               lb->mitigationBarIndex = current_i;
              }
           }
        }
     }

   void              UpdateLBTouches(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low, ZigZag* zz)
     {
      if(zz == NULL || CheckPointer(zz) != POINTER_DYNAMIC || zz->pivots->Total() < 2)
         return;
      int p_total = zz->pivots->Total();

      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb->isMitigated)
            continue;

         datetime cutoffTime = time[current_i];

         for(int p_idx = 0; p_idx <= p_total - 2; p_idx++)
           {
            Pivot* p = (Pivot*)zz->pivots->At(p_idx);
            if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || (zz->projection != NULL && p == zz->projection))
               continue;
            if(p->end == NULL || CheckPointer(p->end) != POINTER_DYNAMIC)
               continue;

            datetime p_time = p->end->time;
            if(p_time <= lb->createdTime || p_time > cutoffTime)
               continue;
            if(lb->HasPivotTouched(p_time))
               continue;

            double p_price = p->end->price;

            if(lb->isBullish)
              {
               if(!p->isHigh && p_price <= lb->zoneHigh && p_price >= lb->zoneLow)
                 {
                  lb->touchTimes.Add((long)p_time);
                  lb->touchCount++;
                 }
              }
            else
              {
               if(p->isHigh && p_price >= lb->zoneLow && p_price <= lb->zoneHigh)
                 {
                  lb->touchTimes.Add((long)p_time);
                  lb->touchCount++;
                 }
              }
           }
        }
     }

   void              Process(int current_i, const std::vector<datetime> &time, const std::vector<double> &high, const std::vector<double> &low,
                             CMarketStructure* ms, CSwingPOILogic* sp, CInducementLogic* indLogic, ZigZag* zz = NULL)
     {
      ProcessSweptAnywhere(current_i, time, high, low, ms, sp, zz, indLogic);
      SyncInducementMitigations(indLogic);
      ProcessPostInducementCHoCH(current_i, time, high, low, ms, sp, indLogic);
      UpdateLBMitigations(current_i, time, high, low);
      UpdateLBTouches(current_i, time, high, low, zz);
      RefreshExitSources(ms,time[current_i],high[current_i],low[current_i]);

      if(ms != NULL && CheckPointer(ms) == POINTER_DYNAMIC)
         m_last_breakout_evaluated = ms->last_breakout_time;
     }
  };

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_blocks.mqh

// Shared M1 inducement entry wait policy. No orders and no future candle data.
#ifndef MARCO_M1_IND_ENTRY_MQH
#define MARCO_M1_IND_ENTRY_MQH

enum ENUM_MARCO_IND_ENTRY_FILTER
  {
   IND_ENTRY_OFF = 0,        // Off
   IND_ENTRY_PIVOT = 1,      // Confirmation pivot inside M1 IND
   IND_ENTRY_PRICE = 2,      // Executable entry price inside M1 IND
   IND_ENTRY_EITHER = 3      // Pivot OR entry price inside M1 IND
  };

struct SMarcoIndWait
  { public: SMarcoIndWait* operator->(){return this;} const SMarcoIndWait* operator->()const{return this;}
   bool waiting;
   datetime since, rejectedPivot, rejectedAvailable;
   double low, high;
  };

struct SMarcoEntryInd
  { public: SMarcoEntryInd* operator->(){return this;} const SMarcoEntryInd* operator->()const{return this;}
   string id;
   bool bull, seen;
   double low, high;
   datetime available, until;
  };
struct SMarcoEntryChoch
  { public: SMarcoEntryChoch* operator->(){return this;} const SMarcoEntryChoch* operator->()const{return this;}
   bool bull;
   datetime time, available;
  };

class CMarcoIndEntryFilter
  { public: CMarcoIndEntryFilter* operator->(){return this;} const CMarcoIndEntryFilter* operator->()const{return this;}
public:
   static ENUM_MARCO_IND_ENTRY_FILTER mode;
   std::vector<SMarcoEntryInd> zones;
   std::vector<SMarcoEntryChoch> events;
public:
   double lastLow, lastHigh;
   datetime knownThrough;
   CMarcoIndEntryFilter() { lastLow=0; lastHigh=0; knownThrough=0; }
   static void Configure(ENUM_MARCO_IND_ENTRY_FILTER selected) { mode=selected; }
   static bool Enabled() { return mode!=IND_ENTRY_OFF; }
   static bool CheckPivot() { return mode==IND_ENTRY_PIVOT || mode==IND_ENTRY_EITHER; }
   static bool CheckPrice() { return mode==IND_ENTRY_PRICE || mode==IND_ENTRY_EITHER; }
   static void Reset(SMarcoIndWait &state)
     {
      state.waiting=false; state.since=0; state.rejectedPivot=0;
      state.rejectedAvailable=0; state.low=0; state.high=0;
     }

   void Begin(double low, double high)
     {
      lastLow=low; lastHigh=high;
      for(int i=0;i<ArraySize(zones);i++) zones[i].seen=false;
     }
   // Version bounds as they become known, so catch-up never uses future zones.
   void Zone(string id, bool bull, double low, double high, datetime available)
     {
      if(!Enabled()) return;
      for(int i=ArraySize(zones)-1;i>=0;i--)
         if(zones[i].id==id && zones[i].until==0)
           {
            if(zones[i].bull==bull && zones[i].low==low && zones[i].high==high)
              { zones[i].seen=true; return; }
            zones[i].until=available;
            break;
           }
      int n=ArraySize(zones); ArrayResize(zones,n+1);
      zones[n].id=id; zones[n].bull=bull; zones[n].low=low; zones[n].high=high;
      zones[n].available=available; zones[n].until=0; zones[n].seen=true;
     }
   void End(datetime available)
     {
      knownThrough=available;
      for(int i=0;i<ArraySize(zones);i++)
         if(!zones[i].seen && zones[i].until==0) zones[i].until=available;
     }
   void Observe(string name, datetime time, datetime available)
     {
      if(!Enabled() || time==0 || StringFind(name,"CHoCH")<0) return;
      bool bull=StringFind(name,"BL-")>=0;
      if(!bull && StringFind(name,"BR-")<0) return;
      for(int i=ArraySize(events)-1;i>=0;i--)
         if(events[i].time==time && events[i].bull==bull) return;
      int n=ArraySize(events); ArrayResize(events,n+1);
      events[n].bull=bull; events[n].time=time; events[n].available=available;
     }
   bool Inside(bool bull, double price, datetime at, double &low, double &high, string &id)
     {
      bool found=false; low=0; high=0; id="";
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].bull!=bull || zones[i].available>at ||
            (zones[i].until>0 && at>=zones[i].until) ||
            price<zones[i].low || price>zones[i].high) continue;
         if(!found) { low=zones[i].low; high=zones[i].high; id=zones[i].id; }
         else { low=MathMin(low,zones[i].low); high=MathMax(high,zones[i].high); }
         found=true;
        }
      return found;
     }
   void Audit(string symbol, ENUM_TIMEFRAMES tf, bool bull, datetime now, double price)
     {
      if(!CheckPrice()) return;
      int active=0, nearest=-1, ended=-1;
      double distance=0.0;
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].bull!=bull || zones[i].available>now) continue;
         if(zones[i].until>0 && now>=zones[i].until)
           {
            if(price>=zones[i].low && price<=zones[i].high &&
               (ended<0 || zones[i].until>zones[ended].until)) ended=i;
            continue;
           }
         active++;
         double gap=MathMax(zones[i].low-price,MathMax(price-zones[i].high,0.0));
         if(nearest<0 || gap<distance) { nearest=i; distance=gap; }
        }
      PrintFormat("[M1 IND CHECK] %s %s at=%s %s entry=%.8f known_through=%s active=%d nearest=%s bounds=[%.8f,%.8f] inside=%s",
                  symbol,EnumToString(tf),TimeToString(now,TIME_DATE|TIME_SECONDS),bull ? "BUY" : "SELL",price,
                  TimeToString(knownThrough,TIME_DATE|TIME_SECONDS),active,nearest<0 ? "none" : zones[nearest].id,
                  nearest<0 ? 0.0 : zones[nearest].low,nearest<0 ? 0.0 : zones[nearest].high,
                  nearest>=0 && distance==0.0 ? "yes" : "no");
      if(ended>=0)
         PrintFormat("[M1 IND CHECK] historical overlapping IND=%s bounds=[%.8f,%.8f] stopped being active at=%s; not an active entry blocker.",
                     zones[ended].id,zones[ended].low,zones[ended].high,TimeToString(zones[ended].until,TIME_DATE|TIME_SECONDS));
     }
   static void Wait(SMarcoIndWait &state, datetime pivot, datetime available,
                    datetime now, double low, double high)
     {
      if(state.waiting) { low=MathMin(low,state.low); high=MathMax(high,state.high); }
      state.waiting=true; state.since=now; state.rejectedPivot=pivot;
      state.rejectedAvailable=available; state.low=low; state.high=high;
     }
   bool SkipPivot(SMarcoIndWait &state, bool bull, datetime pivot, double price,
                  datetime available, string &id)
     {
      double low=0,high=0;
      // Was the pivot formed inside an IND known at that candle's close?
      // Do not erase that fact if the IND is swept before pivot confirmation.
      datetime formed=pivot+PeriodSeconds(PERIOD_M1);
      if(formed>available) formed=available;
      if(!CheckPivot() || !Inside(bull,price,formed,low,high,id)) return false;
      Wait(state,pivot,available,available,low,high);
      return true;
     }
   bool SkipPrice(SMarcoIndWait &state, bool bull, datetime pivot, datetime available,
                  datetime now, double price, string &id)
     {
      double low=0,high=0;
      if(!CheckPrice() || !Inside(bull,price,now,low,high,id)) return false;
      Wait(state,pivot,available,now,low,high);
      return true;
     }
   bool Ready(const SMarcoIndWait &state, bool bull, datetime pivot, double price,
              datetime available, double setupLow, double setupHigh)
     {
      if(!Enabled() || !state.waiting) return true;
      if(pivot<=state.rejectedPivot || available<=state.rejectedAvailable || pivot<state.since) return false;
      // The original blocking IND remains the threshold even after it is swept.
      if(bull ? (price>=state.low || price<=setupLow) : (price<=state.high || price>=setupHigh)) return false;
      for(int i=ArraySize(events)-1;i>=0;i--)
         if(events[i].bull==bull && events[i].available>state.since && events[i].available<=pivot)
            return true;
      return false;
     }
   static bool Broken(const SMarcoIndWait &state, bool bull, double low, double high,
                      double setupLow, double setupHigh)
     {
      return Enabled() && state.waiting && (bull ? low<setupLow : high>setupHigh);
     }
  };
ENUM_MARCO_IND_ENTRY_FILTER CMarcoIndEntryFilter::mode=IND_ENTRY_OFF;
#endif

// Shared partial-exit policy with durable target extensions. Kind: 0=LB, 1=IND, 2=RR, 3=RR+1.
#ifndef MARCO_STAGED_TP_MQH
#define MARCO_STAGED_TP_MQH
struct SMarcoTPPlan
  { public: SMarcoTPPlan* operator->(){return this;} const SMarcoTPPlan* operator->()const{return this;}
   int count, direction;
   double entry, initialSL, remaining, realizedR;
   bool breakeven;
   int kind[3];
   double price[3], fraction[3], closed[3], exitPrice[3];
   datetime exitTime[3], vicinityTime[3];
   // Index 0 = one-time half exit; index 1 = emergency full exit.
   double structureClosed[2], structurePrice[2];
   datetime structureTime[2];
   double protectedSL; // Profit-side stop requested by a same-direction LB.
   int extensionCount;
   datetime extensionTime;
  };

// Kept outside the fixed-size plan so indicator cache records remain serializable.
struct SMarcoExtensionState
  { public: SMarcoExtensionState* operator->(){return this;} const SMarcoExtensionState* operator->()const{return this;}
   string seen; // Delimited timeframe + LB ID keys, retained for the life of the trade.
  };

class CMarcoStagedTP
  { public: CMarcoStagedTP* operator->(){return this;} const CMarcoStagedTP* operator->()const{return this;}
public:
   static string Name(int kind)
     { return kind == 0 ? "LB" : (kind == 1 ? "IND" : (kind == 2 ? "RR" : "RR+1")); }

   static bool ValidTarget(int direction, double entry, double price)
     { return MathIsValidNumber(price) && price > 0.0 && direction * (price-entry) > 0.0; }

   static void Add(SMarcoTPPlan &plan, int kind, double price, double fraction)
     {
      int i = plan.count++;
      plan.kind[i] = kind;
      plan.price[i] = price;
      plan.fraction[i] = fraction;
     }

   static bool Build(SMarcoTPPlan &plan, bool buy, double entry, double sl,
                     double lb, double ind, double rr, int priority,
                     double spreadAdjustment, double tickSize, int digits)
     {
      ZeroMemory(plan);
      plan.direction = buy ? 1 : -1;
      plan.entry = entry;
      plan.initialSL = sl;
      plan.remaining = 1.0;
      double risk = plan.direction * (entry-sl);
      if(!MathIsValidNumber(risk) || risk <= 0 || !MathIsValidNumber(rr) || rr <= 0 ||
         !MathIsValidNumber(tickSize) || tickSize <= 0 || spreadAdjustment < 0 ||
         !MathIsValidNumber(spreadAdjustment) || priority < 0 || priority > 2) return false;
      bool hasLB = ValidTarget(plan.direction, entry, lb);
      bool hasIND = ValidTarget(plan.direction, entry, ind);
      int structural = (hasLB ? 1 : 0) + (hasIND ? 1 : 0);
      double fallback = entry + plan.direction * rr * risk;
      if(structural == 2)
        {
         Add(plan, 0, lb, priority == 0 ? 0.50 : 0.25);
         Add(plan, 1, ind, priority == 1 ? 0.50 : 0.25);
         Add(plan, 2, fallback, priority == 2 ? 0.50 : 0.25);
        }
      else if(structural == 1)
        {
         Add(plan, hasLB ? 0 : 1, hasLB ? lb : ind, priority == 2 ? 0.25 : 0.75);
         Add(plan, 2, fallback, priority == 2 ? 0.75 : 0.25);
        }
      else
        {
         Add(plan, 2, fallback, 0.75);
         Add(plan, 3, entry + plan.direction * (rr+1.0) * risk, 0.25);
        }
      for(int i=0; i<plan.count; i++)
        {
         double adjusted = plan.price[i] - plan.direction * spreadAdjustment;
         // Round towards entry, preserving the existing spread-adjustment option.
         double units = adjusted / tickSize;
         plan.price[i] = NormalizeDouble((buy ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize, digits);
         // Do not silently turn an invalid adjusted TP into a different target.
         if(!ValidTarget(plan.direction, entry, plan.price[i])) return false;
        }
      return true;
     }

   static int Next(const SMarcoTPPlan &plan)
     {
      int next = -1;
      for(int i=0; i<plan.count; i++)
         if(plan.closed[i]+1e-9 < plan.fraction[i] &&
            (next < 0 || plan.direction*(plan.price[i]-plan.price[next]) < 0)) next=i;
      return next;
     }

   static double Farthest(const SMarcoTPPlan &plan)
     {
      double price = plan.price[0];
      for(int i=1; i<plan.count; i++)
         if(plan.direction*(plan.price[i]-price)>0) price=plan.price[i];
      return price;
     }

   static int LastPending(const SMarcoTPPlan &plan)
     {
      int last=-1;
      for(int i=0;i<plan.count;i++)
         if(plan.closed[i]+1e-9<plan.fraction[i] &&
            (last<0 || plan.direction*(plan.price[i]-plan.price[last])>0)) last=i;
      return last;
     }

   static double Stop(const SMarcoTPPlan &plan)
     {
      double stop=plan.breakeven ? plan.entry : plan.initialSL;
      if(plan.protectedSL>0 && plan.direction*(plan.protectedSL-stop)>0) stop=plan.protectedSL;
      return stop;
     }

   static void TightenStop(SMarcoTPPlan &plan, double candidate)
     {
      // Never cross to the loss side of entry, or loosen an already tighter stop.
      if(candidate<=0 || plan.direction*(candidate-plan.entry)<0) candidate=plan.entry;
      plan.breakeven=true;
      if(plan.protectedSL<=0 || plan.direction*(candidate-plan.protectedSL)>0) plan.protectedSL=candidate;
     }

   static bool Extend(SMarcoTPPlan &plan, int count, double rr, double tick, int digits, datetime now)
     {
      int last=LastPending(plan);
      if(last<0 || count<=0 || plan.remaining<=1e-9 || rr<=0 || tick<=0) return false;
      double distance=count*rr*MathAbs(plan.entry-plan.initialSL);
      double raw=plan.price[last]+plan.direction*distance;
      if(!MathIsValidNumber(raw) || !MathIsValidNumber(distance) || distance<=0 || raw<=0) return false;
      double units=raw/tick;
      double target=NormalizeDouble((plan.direction==1 ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*tick,digits);
      if(target<=0 || plan.direction*(target-plan.price[last])<=0) return false;
      plan.price[last]=target;
      plan.vicinityTime[last]=0; // A near-touch of the old TP cannot close the extended target.
      plan.extensionCount+=count; plan.extensionTime=now;
      return true;
     }

   static int Primary(const SMarcoTPPlan &plan)
     {
      int p=0;
      for(int i=1; i<plan.count; i++) if(plan.fraction[i]>plan.fraction[p]) p=i;
      return p;
     }

   static void RebaseFill(SMarcoTPPlan &plan, double fill, double rr, double adjustment, double tickSize, int digits)
     {
      plan.entry=fill;
      double risk=MathAbs(fill-plan.initialSL);
      // Zones and allocations stay frozen; RR distances use the actual filled entry.
      for(int i=0;i<plan.count;i++)
         if(plan.kind[i]>=2)
           {
            double multiple=rr+(plan.kind[i]==3 ? 1.0 : 0.0);
            double units=(fill+plan.direction*(multiple*risk-adjustment))/tickSize;
            plan.price[i]=NormalizeDouble((plan.direction==1 ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize,digits);
           }
     }

   static double Lots(double maximum, double step, double minimum)
     {
      if(step<=0 || minimum<=0 || maximum<=0) return 0;
      double lots=NormalizeDouble(MathFloor(maximum/(4.0*step)+1e-8)*4.0*step,8);
      return lots/4.0+1e-9 >= minimum ? lots : 0.0;
     }

   // A stage closes a share of ORIGINAL volume, never a share of the remainder.
   static double Exit(SMarcoTPPlan &plan, int stage, double fraction, double price, datetime time)
     {
      fraction = MathMin(fraction, plan.remaining);
      if(stage>=0) fraction=MathMin(fraction, plan.fraction[stage]-plan.closed[stage]);
      if(fraction<=1e-9) return 0;
      double reward=fraction*plan.direction*(price-plan.entry)/MathAbs(plan.entry-plan.initialSL);
      plan.realizedR+=reward;
      plan.remaining=MathMax(0.0,plan.remaining-fraction);
      if(stage>=0)
        {
         plan.exitPrice[stage]=(plan.exitPrice[stage]*plan.closed[stage]+price*fraction)/(plan.closed[stage]+fraction);
         plan.closed[stage]+=fraction;
         plan.exitTime[stage]=time;
         plan.breakeven=true;
        }
      return reward;
     }

   // Half of currently open volume, rounded down to a broker-valid lot amount.
   static double HalfLots(double remainingLots, double step, double minimum)
     {
      if(step<=0 || minimum<=0) return 0;
      double lots=NormalizeDouble(MathFloor(remainingLots*0.5/step+1e-8)*step,8);
      return lots+1e-9>=minimum && remainingLots-lots+1e-9>=minimum ? lots : 0.0;
     }

   static void StructureExit(SMarcoTPPlan &plan, bool full, double fraction, double price,
                             datetime time, double originalLots, double step, double minimum)
     {
      double before=plan.remaining;
      fraction=MathMin(fraction,before);
      if(fraction<=1e-9) return;
      int index=full ? 1 : 0;
      double prior=plan.structureClosed[index];
      plan.structurePrice[index]=(plan.structurePrice[index]*prior+price*fraction)/(prior+fraction);
      plan.structureClosed[index]+=fraction; plan.structureTime[index]=time;
      Exit(plan,-1,fraction,price,time);
      if(!full) plan.breakeven=true;
      // Reduce outstanding allocations proportionally, respecting broker volume steps.
      // Any indivisible residue stays at the farthest still-outstanding target.
      int last=-1; double allocated=0;
      for(int i=0;i<plan.count;i++)
        {
         double pending=plan.fraction[i]-plan.closed[i];
         if(pending<=1e-9) continue;
         if(last<0 || plan.direction*(plan.price[i]-plan.price[last])>0) last=i;
         double lots=NormalizeDouble(MathFloor(pending*plan.remaining/before*originalLots/step+1e-8)*step,8);
         if(lots+1e-9<minimum) lots=0;
         plan.fraction[i]=plan.closed[i]+lots/originalLots;
         allocated+=lots/originalLots;
        }
      if(last>=0) plan.fraction[last]+=MathMax(0.0,plan.remaining-allocated);
     }

   // OHLC fallback: bullish candle O-L-H-C; bearish candle O-H-L-C.
   // This is a deterministic simulation assumption, not reconstructed tick history.
   static void Bar(SMarcoTPPlan &plan, datetime time, double open, double high, double low, double close,
                   bool vicinity, double distance, bool rejection, datetime rejectionStart,
                   double &lastExit)
     {
      double path[4]; path[0]=open; path[1]=close>=open ? low : high;
      path[2]=close>=open ? high : low; path[3]=close;
      double stop=Stop(plan);
      if(plan.direction*(open-stop)<=0)
        { Exit(plan,-1,plan.remaining,open,time); lastExit=open; return; }
      for(int leg=0; leg<4 && plan.remaining>1e-9; leg++)
        {
         double end=path[leg];
         stop=Stop(plan);
         if(plan.direction*(end-stop)<=0)
           { Exit(plan,-1,plan.remaining,stop,time); lastExit=stop; return; }
         int stage=Next(plan);
         while(stage>=0 && plan.direction*(end-plan.price[stage])>=0)
           {
            double fill=leg==0 ? open : plan.price[stage];
            Exit(plan,stage,plan.fraction[stage]-plan.closed[stage],fill,time);
            lastExit=fill;
            stage=Next(plan);
           }
         if(vicinity && stage>=0 && plan.vicinityTime[stage]==0 &&
            plan.direction*(end-plan.price[stage])>=-distance) plan.vicinityTime[stage]=time;
        }
      if(vicinity && rejection && plan.direction*(close-plan.entry)>0)
         for(int i=0; i<plan.count; i++)
            if(plan.vicinityTime[i]>0 &&
               plan.closed[i]+1e-9<plan.fraction[i])
              {
               Exit(plan,i,plan.fraction[i]-plan.closed[i],close,time);
               lastExit=close;
              }
     }
  };
#endif

#ifndef MARCO_STRUCTURE_EXIT_MQH
#define MARCO_STRUCTURE_EXIT_MQH



// Actions: 0=none, 1=half the remaining position + BE, 2=all remaining volume.
struct SMarcoStructureExit
  { public: SMarcoStructureExit* operator->(){return this;} const SMarcoStructureExit* operator->()const{return this;}
   int action;
   ENUM_TIMEFRAMES tf;
   datetime eventTime;
   string lbId;
   double level;
  };

class CMarcoStructureExit
  { public: CMarcoStructureExit* operator->(){return this;} const CMarcoStructureExit* operator->()const{return this;}
public:
   static bool Inside(double price, double a, double b)
     { return price>=MathMin(a,b) && price<=MathMax(a,b); }
   static bool Overlaps(double low, double high, double a, double b)
     { return high>=MathMin(a,b) && low<=MathMax(a,b); }

   static SMarcoStructureExit Evaluate(CTradeRejectionHistory &history, const SMarcoTPPlan &plan,
                                       datetime opened, datetime now, ENUM_TIMEFRAMES tf)
     {
      SMarcoStructureExit result; result->action=0; result->tf=tf;
      result->eventTime=0; result->lbId=""; result->level=0;
      if(plan.remaining<=1e-9) return result;
      // Check every still-valid post-entry CHoCH. A later BOS must not hide an
      // exit while its source LB is awaiting recognition or live bars catch up.
      for(int e=history.EventCount()-1;e>=0;e--)
        {
         SRejectionEvent event;
         if(!history.EventAt(e,now,event) || event.time<opened || event.available<=opened ||
            event.name!=(plan.direction==1 ? "BR-CHoCH" : "BL-CHoCH") || event.linePrice<=0)
            continue;
         for(int b=history.ZoneCount()-1;b>=0;b--)
           {
            SRejectionLB lb; if(!history.ZoneAt(b,lb)) continue;
            if(lb->bull!=(plan.direction==-1) || lb->available>now || (lb->until>0 && now>=lb->until)) continue;
            // Require the CHoCH's source in this LB, or an explicit causal CHoCH link.
            bool linked=lb->choch==event.time;
            datetime firstAvailable=lb->available;
            for(int v=b;v>=0;v--)
              {
               SRejectionLB source; if(!history.ZoneAt(v,source) || source->id!=lb->id) continue;
               firstAvailable=MathMin(firstAvailable,source->available);
               if(source->available>event.available || (source->until>0 && event.available>=source->until)) continue;
               if(CTradeRejection::OriginInside(event.originTime,event.originPrice,source->created,
                                               source->mitigation,PeriodSeconds(tf),source->low,source->high,0.0)) linked=true;
              }
            if(!linked) continue;
            int action=0;
            // SL-side overlap also qualifies; full exit wins if the LB spans both regions.
            if(Inside(event.linePrice,plan.entry,plan.initialSL) ||
               Overlaps(lb->low,lb->high,plan.entry,plan.initialSL)) action=2;
            else if(plan.structureTime[0]==0 && lb->created>opened && firstAvailable>opened &&
                    Overlaps(lb->low,lb->high,plan.entry,CMarcoStagedTP::Farthest(plan))) action=1;
            if(action<=result->action) continue;
            result->action=action; result->eventTime=event.time; result->lbId=lb->id; result->level=event.linePrice;
           }
        }
      return result;
     }
  };
#endif

class CMarcoM1LBContext
  { public: CMarcoM1LBContext* operator->(){return this;} const CMarcoM1LBContext* operator->()const{return this;}
public:
   CMarketStructure* ms;
   CDemandSupplyLogic* ds;
   CSwingPOILogic* sp;
   COrderBlockLogic* ob;
   CFlipZoneLogic* fz;
   CBreakerBlockLogic* bb;
   CInducementLogic* ind;
   CLiquidityBlockLogic* lbs;
   std::vector<datetime> times;
   std::vector<double> opens, highs, lows, closes;
   std::vector<string> knownIds;
   std::vector<datetime> availableTimes;

   int KnownIndex(string id)
     {
      for(int i = 0; i < ArraySize(knownIds); i++)
         if(knownIds[i] == id)
            return i;
      return -1;
     }

public:
   CTradeRejectionHistory rejectionHistory;
   CMarcoIndEntryFilter indEntry;
   CMarcoM1LBContext()
     {
      ms = new CMarketStructure();
      ms->Init(false, false, PERIOD_M1);
      ds = new CDemandSupplyLogic();
      sp = new CSwingPOILogic();
      ob = new COrderBlockLogic();
      fz = new CFlipZoneLogic();
      bb = new CBreakerBlockLogic();
      ind = new CInducementLogic();
      lbs = new CLiquidityBlockLogic();
     }

   ~CMarcoM1LBContext()
     {
      delete lbs;
      delete ind;
      delete bb;
      delete fz;
      delete ob;
      delete sp;
      delete ds;
      delete ms;
     }

   void Init(bool sweeps, bool postInd, int minTouches, double proximity,
             bool strictOrigin, bool mergeClusters, double tolerance, bool expandBounds,
             bool checkDS, bool checkOB, bool checkSP, bool checkFZ, bool checkBB, double symbolPoint)
     {
      ind->Init(minTouches, proximity, checkDS, checkOB, checkSP, checkFZ, checkBB,
               strictOrigin, mergeClusters, tolerance, expandBounds);
      lbs->Init(sweeps, postInd, symbolPoint);
     }

   void Update(datetime barTime, double open, double high, double low, double close,
               ZigZag* zz, double pipSize)
     {
      int i = ArraySize(times);
      if(zz == NULL || (i > 0 && barTime <= times[i - 1]))
         return;
      ArrayResize(times, i + 1, 2048);
      ArrayResize(opens, i + 1, 2048);
      ArrayResize(highs, i + 1, 2048);
      ArrayResize(lows, i + 1, 2048);
      ArrayResize(closes, i + 1, 2048);
      times[i] = barTime;
      opens[i] = open;
      highs[i] = high;
      lows[i] = low;
      closes[i] = close;
      ms->Update(i, times, highs, lows, closes, zz);
      ds->DetectPOIs(i, times, highs, lows, zz);
      ds->UpdateMitigation(close);
      sp->DetectPOIs(i, times, highs, lows, zz);
      sp->UpdateMitigation(close);
      ob->DetectPOIs(i, times, highs, lows, zz);
      ob->UpdateMitigation(close);
      fz->DetectFlipZones(i, times, highs, lows, closes, zz, ms, ds);
      fz->UpdateMitigation(close);
      bb->DetectBreakers(zz, ds, sp, ob, fz);
      bb->UpdateMitigation(high, low, barTime);
      ind->Process(i, times, opens, highs, lows, closes, zz, ms, ds, sp, ob, fz, bb, pipSize);
      lbs->Process(i, times, highs, lows, ms, sp, ind, zz);
      datetime available = barTime + PeriodSeconds(PERIOD_M1);
      indEntry.Begin(low,high);
      for(int z=0;z<ind->m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)ind->m_zones.At(z);
         if(zone!=NULL && zone->isInducement && !zone->isMitigated)
            indEntry.Zone(zone->id,zone->isBullish,zone->zoneLow,zone->zoneHigh,available);
        }
      indEntry.End(available);
      int eventCount = ms->all_event_names.Total();
      if(eventCount>0)
         indEntry.Observe(ms->all_event_names.At(eventCount-1),(datetime)ms->all_event_times.At(eventCount-1),available);
      // Renaming can change either of the previous two events as well as the newest one.
      for(int e=MathMax(0,eventCount-3);e<eventCount;e++)
         rejectionHistory.Observe(ms->all_event_names.At(e), (datetime)ms->all_event_times.At(e),
                                  available, (datetime)ms->all_event_origin_times.At(e), ms->all_event_origin_prices.At(e),
                                  ms->all_event_prices.At(e));
      rejectionHistory.BeginZones();
      // Entry-vetoed sources are exclusively available to opposing-structure exits.
      for(int b=0;b<lbs->m_exit_sources.Total();b++)
        {
         CLiquidityBlock* source=(CLiquidityBlock*)lbs->m_exit_sources.At(b);
         if(source!=NULL)
            rejectionHistory.Zone(source->id,source->isBullish,source->zoneLow,source->zoneHigh,source->createdTime,
                         source->mitigationTime,source->causalChochTime,available,true);
        }
      for(int b = 0; b < lbs->m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs->m_liquidity_blocks.At(b);
         if(lb != NULL)
            rejectionHistory.Zone(lb->id, lb->isBullish, lb->zoneLow, lb->zoneHigh, lb->createdTime,
                                  lb->mitigationTime, lb->causalChochTime, available);
        }
      rejectionHistory.EndZones(available);
      // A zone's origin can predate its confirmation. Never backdate its availability.
      for(int b = 0; b < lbs->m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs->m_liquidity_blocks.At(b);
         if(lb == NULL || KnownIndex(lb->id) >= 0)
            continue;
         int n = ArraySize(knownIds);
         ArrayResize(knownIds, n + 1);
         ArrayResize(availableTimes, n + 1);
         knownIds[n] = lb->id;
         availableTimes[n] = barTime + PeriodSeconds(PERIOD_M1);
        }
     }

   bool FindOpposingOrigin(bool candidateIsBull, datetime originTime, double originPrice,
                           datetime now, double buffer, string &opposingId)
     {
      opposingId = "";
      for(int b = 0; b < lbs->m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs->m_liquidity_blocks.At(b);
         if(lb == NULL || lb->isBullish == candidateIsBull)
            continue;
         int known = KnownIndex(lb->id);
         if(known < 0 || availableTimes[known] > now)
            continue;
         // Match the existing origin rule, using M1 for the mitigation candle.
         if(CTradeRejection::OriginInside(originTime, originPrice, lb->createdTime, lb->mitigationTime,
                                           PeriodSeconds(PERIOD_M1), lb->zoneLow, lb->zoneHigh, buffer))
           {
            opposingId = lb->id;
            return true;
           }
        }
      return false;
     }
  };

int main(int argc,char**argv){
 CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);
 Settings* settings=new Settings(.001,1,0,false,false,false,false,"Absolute");settings->draw=false;
 ZigZag* zz=newInstance(settings);CMarcoM1LBContext ctx;
 ctx.Init(true,true,2,1,true,true,10,false,true,true,true,false,false,.1);
 SMarcoTPPlan plan;assert(CMarcoStagedTP::Build(plan,true,52412.8,52353.5,52528.5,52472.3,1,2,0,.1,1));
 datetime opened=1794513780,firstExit=0;bool checkedEntry=false,checkedQualification=false;
 std::ifstream f(argv[1]);string line;std::getline(f,line);int i=0;
 while(std::getline(f,line)){
  std::replace(line.begin(),line.end(),',',' ');std::istringstream s(line);
  datetime t;double o,h,l,c;long volume,real;int spread;s>>t>>o>>h>>l>>c>>volume>>spread>>real;
  zz->update(h,l,t,volume,i++,true,false);ctx.Update(t,o,h,l,c,zz,1.0);
  string stamp=TimeToString(t+60);
  for(int j=0;j<ctx.ind->m_zones.Total();j++){
   auto z=(CInducementZone*)ctx.ind->m_zones.At(j);
   if(z->id!="Swing POI_BULL_1794497100")continue;
   if(stamp=="2026.11.12 20:03"){
    assert(!z->isInducement&&z->touchCount==0&&z->qualifiedTime==0);checkedEntry=true;
    double low,high;string id;assert(!ctx.indEntry.Inside(true,52412.8,t+60,low,high,id));
    std::cout<<"VERIFIED entry zone was not IND at "<<stamp<<"\n";
   }
   if(stamp=="2026.11.12 20:10"){
    assert(z->isInducement&&z->touchCount==2&&z->qualifiedTime==t+60);checkedQualification=true;
    double low,high;string id;assert(ctx.indEntry.Inside(true,52412.8,t+60,low,high,id));
    std::cout<<"VERIFIED IND first available at "<<stamp<<"\n";
   }
  }
  if(t+60>opened&&!firstExit){
   auto exit=CMarcoStructureExit::Evaluate(ctx.rejectionHistory,plan,opened,t+60,1);
   if(exit.action){
    firstExit=t+60;
    assert(exit.action==2&&stamp=="2026.11.12 20:33"&&TimeToString(exit.eventTime)=="2026.11.12 20:32");
    assert(exit.lbId.find("EXIT_ONLY_LB_")==0);
    for(int j=0;j<ctx.lbs->m_liquidity_blocks.Total();j++){
     auto lb=(CLiquidityBlock*)ctx.lbs->m_liquidity_blocks.At(j);
     assert(lb->isBullish||lb->createdTime!=1794514860); // Still rejected for new entries.
    }
    std::cout<<"VERIFIED FULL EXIT known="<<stamp<<" CHoCH="<<TimeToString(exit.eventTime)<<" level="<<exit.level<<" source="<<exit.lbId<<"\n";
   }
  }
  if(firstExit&&t==firstExit){
   assert(std::abs(o-52386.5)<.00001);
   std::cout<<"VERIFIED next-open bid="<<o<<" gross R="<<(o-plan.entry)/(plan.entry-plan.initialSL)<<"\n";
  }
  if(stamp>="2026.11.12 14:40" && stamp<="2026.11.12 15:45"){
   std::cout<<"BAR "<<stamp<<" OHLC "<<o<<" "<<h<<" "<<l<<" "<<c<<" pivots="<<zz->pivots->Total()<<"\n";
   for(int j=0;j<ctx.ind->m_zones.Total();j++){
    auto z=(CInducementZone*)ctx.ind->m_zones.At(j);
    if(z->isBullish&&z->zoneLow<52435&&z->zoneHigh>52370)
     std::cout<<" IND "<<z->id<<" "<<z->zoneLow<<" "<<z->zoneHigh<<" origin="<<TimeToString(z->createdTime)<<" known="<<TimeToString(z->qualifiedTime)<<" touches="<<z->touchCount<<" qualified="<<z->isInducement<<" dead="<<z->isMitigated<<" death="<<TimeToString(z->mitigationTime)<<"\n";
   }
   for(int k=0;k<zz->pivots->Total();k++){
    auto p=(Pivot*)zz->pivots->At(k);
    if(!p->isHigh&&TimeToString(p->end->time)>="2026.11.12 14:40")
     std::cout<<" PIVOT "<<TimeToString(p->end->time)<<" price="<<p->end->price<<" last="<<(k==zz->pivots->Total()-1)<<"\n";
   }
   SRejectionEvent e;if(ctx.rejectionHistory.Latest(t+60,e))std::cout<<" STRUCT "<<e.name<<" at="<<TimeToString(e.time)<<" line="<<e.linePrice<<" origin="<<TimeToString(e.originTime)<<" price="<<e.originPrice<<"\n";
   for(int j=0;j<ctx.lbs->m_liquidity_blocks.Total();j++){
    auto z=(CLiquidityBlock*)ctx.lbs->m_liquidity_blocks.At(j);
    if(z->zoneHigh>52350&&z->zoneLow<52480)std::cout<<" LB "<<z->id<<" "<<z->zoneLow<<" "<<z->zoneHigh<<" cause="<<TimeToString(z->causalChochTime)<<"\n";
   }
  }
 }
 assert(checkedEntry&&checkedQualification&&firstExit);delete zz;
}
