//+------------------------------------------------------------------+
//|                                     Include\ZigZag\backtest.mqh  |
//|                    SMC Historical Zone Backtest & Metrics Engine |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.39"

#include <Arrays\ArrayInt.mqh>
#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\ZigZag\order_blocks.mqh>
#include <Custom\ZigZag\flipzone.mqh>
#include <Custom\ZigZag\breaker_blocks.mqh>
#include <Custom\General\teams_alert.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Custom\ZigZag\entry_model.mqh>

// --- Helper: Find ANY open chart matching Symbol and Timeframe ---
long FindChartID(string sym, ENUM_TIMEFRAMES tf)
  {
   long currChart = ChartFirst();
   while(currChart >= 0)
     {
      if(ChartSymbol(currChart) == sym && ChartPeriod(currChart) == tf)
        {
         return currChart;
        }
      currChart = ChartNext(currChart);
     }
   return -1;
  }

// --- Backtest Result Evaluator ---
int EvaluateZone(string sym, string zoneLabel, bool isBullish, double zHigh, double zLow, datetime zTime, double pipSize,
                 const datetime &time[], const double &open[], const double &high[],
                 const double &low[], const double &close[], int rates_total,
                 ZigZag* zigZag, CMarketStructure* ms,
                 CDemandSupplyLogic* dsLogic, CSwingPOILogic* spLogic, COrderBlockLogic* obLogic,
                 ENUM_TIMEFRAMES tf,
                 CPoCAnalyzer* pocEngine, PoCResult &outPoC,
                 bool drawVisuals, color colSuccess, color colFail)
  {
   double sl, tp;
   CEntryModel::CalculateBacktestSetup(isBullish, zHigh, zLow, pipSize, 2.0, sl, tp);

   int touchIdx = -1;
   int startIdx = -1;

   for(int i = 0; i < rates_total; i++)
     {
      if(time[i] == zTime)
        {
         startIdx = i;
         break;
        }
     }

   if(startIdx == -1)
      return 0;

   bool hasLeftZone = false;

// --- 1. FIND THE TOUCH ENTRY ---
   for(int i = startIdx + 1; i < rates_total; i++)
     {
      if(isBullish)
        {
         if(!hasLeftZone && close[i] > zHigh)
            hasLeftZone = true;
         if(hasLeftZone && low[i] <= zHigh)
           {
            int pivotCount = 0;
            for(int p = 0; p < zigZag.pivots.Total(); p++)
              {
               Pivot* pv = (Pivot*)zigZag.pivots.At(p);
               if(pv.end.time > zTime && pv.end.time < time[i])
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
         if(!hasLeftZone && close[i] < zLow)
            hasLeftZone = true;
         if(hasLeftZone && high[i] >= zLow)
           {
            int pivotCount = 0;
            for(int p = 0; p < zigZag.pivots.Total(); p++)
              {
               Pivot* pv = (Pivot*)zigZag.pivots.At(p);
               if(pv.end.time > zTime && pv.end.time < time[i])
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

   double dummyLivePrice = isBullish ? zHigh : zLow;
   outPoC = pocEngine.EvaluateZone(isBullish, zTime, zHigh, zLow, touchIdx,
                                   time, open, high, low, close,
                                   zigZag, ms, dsLogic, spLogic, obLogic, dummyLivePrice, pipSize, tf);

// Evaluate outcome with 1-Minute confirmation
   double m1_entry = 0.0, m1_sl = 0.0, m1_tp = 0.0;
   datetime m1_touchTime = 0;
   int result = CEntryModel::EvaluateM1ConfirmedBacktest(sym, isBullish, time[touchIdx], zHigh, zLow, pipSize, m1_entry, m1_sl, m1_tp, m1_touchTime, tf);

// --- 3. VISUALIZATION DRAWING LOGIC ---
   if(drawVisuals)
     {
      long targetChart = FindChartID(sym, tf);

      if(targetChart >= 0)
        {
         string boxName = "BT_" + zoneLabel + "_" + IntegerToString(zTime);
         StringReplace(boxName, " ", "_");

         color fillCol = clrGray;
         string txt = zoneLabel + " (PENDING)";

         double finalDrawSL = sl;
         double finalDrawTP = tp;
         datetime finalDrawTouch = time[touchIdx];

         if(result == 1)
           {
            fillCol = colSuccess;
            txt = zoneLabel + " (CONFIRMED WIN)";
            finalDrawSL = m1_sl;
            finalDrawTP = m1_tp;
            finalDrawTouch = m1_touchTime;
           }
         else
            if(result == -1)
              {
               fillCol = colFail;
               txt = zoneLabel + " (CONFIRMED LOSS)";
               finalDrawSL = m1_sl;
               finalDrawTP = m1_tp;
               finalDrawTouch = m1_touchTime;
              }

         ObjectCreate(targetChart, boxName, OBJ_RECTANGLE, 0, zTime, zHigh, TimeCurrent(), zLow);
         ObjectSetInteger(targetChart, boxName, OBJPROP_COLOR, ColorToARGB_Custom(fillCol, 40));
         ObjectSetInteger(targetChart, boxName, OBJPROP_FILL, true);
         ObjectSetInteger(targetChart, boxName, OBJPROP_BACK, true);

         string entryLine = boxName + "_entry";
         ObjectCreate(targetChart, entryLine, OBJ_VLINE, 0, finalDrawTouch, 0);
         ObjectSetInteger(targetChart, entryLine, OBJPROP_COLOR, fillCol);
         ObjectSetInteger(targetChart, entryLine, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(targetChart, entryLine, OBJPROP_BACK, true);

         string tpLine = boxName + "_tp";
         ObjectCreate(targetChart, tpLine, OBJ_TREND, 0, finalDrawTouch, finalDrawTP, TimeCurrent(), finalDrawTP);
         ObjectSetInteger(targetChart, tpLine, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(targetChart, tpLine, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(targetChart, tpLine, OBJPROP_RAY_RIGHT, false);

         string slLine = boxName + "_sl";
         ObjectCreate(targetChart, slLine, OBJ_TREND, 0, finalDrawTouch, finalDrawSL, TimeCurrent(), finalDrawSL);
         ObjectSetInteger(targetChart, slLine, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(targetChart, slLine, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(targetChart, slLine, OBJPROP_RAY_RIGHT, false);

         string lblName = boxName + "_lbl";
         datetime midTime = zTime + (TimeCurrent() - zTime) / 2;
         double midPrice = zLow + (zHigh - zLow) / 2.0;
         ObjectCreate(targetChart, lblName, OBJ_TEXT, 0, midTime, midPrice);
         ObjectSetString(targetChart, lblName, OBJPROP_TEXT, txt);
         ObjectSetInteger(targetChart, lblName, OBJPROP_COLOR, fillCol);
         ObjectSetInteger(targetChart, lblName, OBJPROP_ANCHOR, ANCHOR_CENTER);

         ChartRedraw(targetChart);
        }
     }

   return result;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CBacktestInstance
  {
public:
   string             symbol;
   ENUM_TIMEFRAMES    tf;
   int                m_maxLookback;
   double             m_deviation;
   int                m_depth;

   bool               m_draw;
   color             m_colSuccess;
   color             m_colFail;

   bool               m_drawDemand;
   bool               m_drawSupply;
   bool               m_drawBullPOI;
   bool               m_drawBearPOI;
   bool               m_drawBullOB;
   bool               m_drawBearOB;
   bool               m_drawDemandFlip;
   bool               m_drawSupplyFlip;
   bool               m_drawBullBreaker;
   bool               m_drawBearBreaker;

   ZigZag*            zigZag;
   CMarketStructure*  ms;
   CDemandSupplyLogic* dsLogic;
   CSwingPOILogic*    spLogic;
   COrderBlockLogic*  obLogic;
   CFlipZoneLogic*    fzLogic;
   CBreakerBlockLogic* bbLogic;
   CPoCAnalyzer*      pocEngine;

   BacktestMetrics    metrics;

                     CBacktestInstance(string _symbol, ENUM_TIMEFRAMES _tf, double devInput, int depInput, int maxLB,
                     bool draw, color cSucc, color cFail,
                     bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO,
                     bool drwDemFlip, bool drwSupFlip,
                     bool drwBullBreaker, bool drwBearBreaker)
     {
      symbol = _symbol;
      tf = _tf;
      m_maxLookback = maxLB;
      m_deviation = devInput;
      m_depth = depInput;
      m_draw = draw;
      m_colSuccess = cSucc;
      m_colFail = cFail;
      m_drawDemand = drwDem;
      m_drawSupply = drwSup;
      m_drawBullPOI = drwBullP;
      m_drawBearPOI = drwBearP;
      m_drawBullOB = drwBullO;
      m_drawBearOB = drwBearO;
      m_drawDemandFlip = drwDemFlip;
      m_drawSupplyFlip = drwSupFlip;
      m_drawBullBreaker = drwBullBreaker;
      m_drawBearBreaker = drwBearBreaker;

      Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
      s.draw = false;
      zigZag = newInstance(s);

      ms = new CMarketStructure();
      ms.Init(false, false);
      dsLogic = new CDemandSupplyLogic();
      spLogic = new CSwingPOILogic();
      obLogic = new COrderBlockLogic();
      fzLogic = new CFlipZoneLogic();
      bbLogic = new CBreakerBlockLogic();
      pocEngine = new CPoCAnalyzer();
      metrics.Init();
     }

                    ~CBacktestInstance()
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
      if(CheckPointer(pocEngine) == POINTER_DYNAMIC)
         delete pocEngine;
     }

   bool              RunBacktest()
     {
      int rates_total = Bars(symbol, tf);
      if(rates_total < m_depth * 2)
         return false;

      int start_bar = MathMax(0, rates_total - m_maxLookback);
      int to_copy = rates_total - start_bar;
      if(to_copy <= 0)
         return false;

      double open[], high[], low[], close[];
      datetime time[];
      long vol[];

      if(CopyTime(symbol, tf, 0, to_copy, time) < to_copy)
         return false;
      if(CopyOpen(symbol, tf, 0, to_copy, open) < to_copy)
         return false;
      if(CopyHigh(symbol, tf, 0, to_copy, high) < to_copy)
         return false;
      if(CopyLow(symbol, tf, 0, to_copy, low) < to_copy)
         return false;
      if(CopyClose(symbol, tf, 0, to_copy, close) < to_copy)
         return false;
      if(CopyTickVolume(symbol, tf, 0, to_copy, vol) < to_copy)
         return false;

      for(int i = 0; i < to_copy; i++)
        {
         bool is_last = (i == to_copy - 1);
         int bar_index = start_bar + i;

         zigZag.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
         ms.Update(i, time, high, low, close, zigZag);

         dsLogic.DetectPOIs(i, time, high, low, zigZag);
         spLogic.DetectPOIs(i, time, high, low, zigZag);
         obLogic.DetectPOIs(i, time, high, low, zigZag);

         fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
         bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);

         if(obLogic.poi_demandTime.Total() > 0)
           {
            datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
            if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz))
              {
               if(obLogic.CheckBullishOB(tz, i, time, high, low))
                  obLogic.ob_bull_valid_times.Add((long)tz);
              }
           }
         if(obLogic.poi_supplyTime.Total() > 0)
           {
            datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
            if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz))
              {
               if(obLogic.CheckBearishOB(tz, i, time, high, low))
                  obLogic.ob_bear_valid_times.Add((long)tz);
              }
           }
        }

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
      PoCResult poc;

      for(int i=0; i<dsLogic.poi_demandTime.Total(); i++)
        {
         bool d = m_draw && m_drawDemand;
         int res = EvaluateZone(symbol, "Demand", true, dsLogic.poi_demandZoneHigh.At(i), dsLogic.poi_demandZoneLow.At(i), (datetime)dsLogic.poi_demandTime.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
         if(res == 1)
            metrics.demand.RecordSuccess(poc);
         else
            if(res == -1)
               metrics.demand.RecordFail(poc);
            else
               metrics.demand.RecordPending();
        }
      for(int i=0; i<dsLogic.poi_supplyTime.Total(); i++)
        {
         bool d = m_draw && m_drawSupply;
         int res = EvaluateZone(symbol, "Supply", false, dsLogic.poi_supplyZoneHigh.At(i), dsLogic.poi_supplyZoneLow.At(i), (datetime)dsLogic.poi_supplyTime.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
         if(res == 1)
            metrics.supply.RecordSuccess(poc);
         else
            if(res == -1)
               metrics.supply.RecordFail(poc);
            else
               metrics.supply.RecordPending();
        }
      for(int i=0; i<spLogic.poi_demandTime.Total(); i++)
        {
         datetime zTime = (datetime)spLogic.poi_demandTime.At(i);
         if(spLogic.ob_time_found(&ms.ob_bull_struct_times, zTime))
           {
            bool d = m_draw && m_drawBullPOI;
            int res = EvaluateZone(symbol, "Bull POI", true, spLogic.poi_demandZoneHigh.At(i), spLogic.poi_demandZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1)
               metrics.bullPOI.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bullPOI.RecordFail(poc);
               else
                  metrics.bullPOI.RecordPending();
           }
        }
      for(int i=0; i<spLogic.poi_supplyTime.Total(); i++)
        {
         datetime zTime = (datetime)spLogic.poi_supplyTime.At(i);
         if(spLogic.ob_time_found(&ms.ob_bear_struct_times, zTime))
           {
            bool d = m_draw && m_drawBearPOI;
            int res = EvaluateZone(symbol, "Bear POI", false, spLogic.poi_supplyZoneHigh.At(i), spLogic.poi_supplyZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1)
               metrics.bearPOI.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bearPOI.RecordFail(poc);
               else
                  metrics.bearPOI.RecordPending();
           }
        }
      for(int i=0; i<obLogic.poi_demandTime.Total(); i++)
        {
         datetime zTime = (datetime)obLogic.poi_demandTime.At(i);
         if(obLogic.ob_time_found(&ms.ob_bull_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, zTime))
           {
            bool d = m_draw && m_drawBullOB;
            int res = EvaluateZone(symbol, "Bull OB", true, obLogic.poi_demandZoneHigh.At(i), obLogic.poi_demandZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1)
               metrics.bullOB.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bullOB.RecordFail(poc);
               else
                  metrics.bullOB.RecordPending();
           }
        }
      for(int i=0; i<obLogic.poi_supplyTime.Total(); i++)
        {
         datetime zTime = (datetime)obLogic.poi_supplyTime.At(i);
         if(obLogic.ob_time_found(&ms.ob_bear_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, zTime))
           {
            bool d = m_draw && m_drawBearOB;
            int res = EvaluateZone(symbol, "Bear OB", false, obLogic.poi_supplyZoneHigh.At(i), obLogic.poi_supplyZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1)
               metrics.bearOB.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bearOB.RecordFail(poc);
               else
                  metrics.bearOB.RecordPending();
           }
        }

      // --- EVALUATE DEMAND & SUPPLY FLIP ZONES ---
      for(int i=0; i<fzLogic.fz_time.Total(); i++)
        {
         bool isDemand = (fzLogic.fz_type.At(i) == 1);
         bool d = m_draw && (isDemand ? m_drawDemandFlip : m_drawSupplyFlip);
         string label = isDemand ? "Demand Flip" : "Supply Flip";
         int res = EvaluateZone(symbol, label, isDemand, fzLogic.fz_zoneHigh.At(i), fzLogic.fz_zoneLow.At(i), (datetime)fzLogic.fz_time.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);

         if(isDemand)
           {
            if(res == 1)
               metrics.demandFlip.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.demandFlip.RecordFail(poc);
               else
                  metrics.demandFlip.RecordPending();
           }
         else
           {
            if(res == 1)
               metrics.supplyFlip.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.supplyFlip.RecordFail(poc);
               else
                  metrics.supplyFlip.RecordPending();
           }
        }

      // --- EVALUATE DEMAND & SUPPLY BREAKER BLOCKS ---
      for(int i=0; i<bbLogic.bb_time.Total(); i++)
        {
         bool isBullish = (bbLogic.bb_type.At(i) == 1);
         bool d = m_draw && (isBullish ? m_drawBullBreaker : m_drawBearBreaker);
         string label = isBullish ? "Bullish Breaker" : "Bearish Breaker";
         int res = EvaluateZone(symbol, label, isBullish, bbLogic.bb_zoneHigh.At(i), bbLogic.bb_zoneLow.At(i), (datetime)bbLogic.bb_time.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, dsLogic, spLogic, obLogic, tf, pocEngine, poc, d, m_colSuccess, m_colFail);

         if(isBullish)
           {
            if(res == 1)
               metrics.bullBreaker.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bullBreaker.RecordFail(poc);
               else
                  metrics.bullBreaker.RecordPending();
           }
         else
           {
            if(res == 1)
               metrics.bearBreaker.RecordSuccess(poc);
            else
               if(res == -1)
                  metrics.bearBreaker.RecordFail(poc);
               else
                  metrics.bearBreaker.RecordPending();
           }
        }

      return true;
     }
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\backtest.mqh

// END FILE: Include\Custom\ZigZag\backtest.mqh
