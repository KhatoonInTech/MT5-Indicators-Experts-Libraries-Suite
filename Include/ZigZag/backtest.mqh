//+------------------------------------------------------------------+
//|                                     Include\ZigZag\backtest.mqh  |
//|                    SMC Historical Zone Backtest & Metrics Engine |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.35"

#include <Arrays\ArrayInt.mqh>
#include <ZigZag\ZigZag.mqh>
#include <ZigZag\market_structure.mqh>
#include <ZigZag\demand_supply.mqh>
#include <ZigZag\swing_pois.mqh>
#include <ZigZag\order_blocks.mqh>
#include <ZigZag\poc_analyzer.mqh>
#include <ZigZag\teams_alert.mqh>
#include <ZigZag\mql_plotting.mqh>

// --- Helper: Find ANY open chart matching Symbol and Timeframe ---
long FindChartID(string sym, ENUM_TIMEFRAMES tf) {
    long currChart = ChartFirst();
    while(currChart >= 0) {
        if(ChartSymbol(currChart) == sym && ChartPeriod(currChart) == tf) {
            return currChart;
        }
        currChart = ChartNext(currChart);
    }
    return -1; // No open chart found for this symbol/tf combination
}

// --- Backtest Result Evaluator ---
int EvaluateZone(string sym, string zoneLabel, bool isBullish, double zHigh, double zLow, datetime zTime, double pipSize, 
                 const datetime &time[], const double &open[], const double &high[], 
                 const double &low[], const double &close[], int rates_total,
                 ZigZag* zigZag, CMarketStructure* ms, ENUM_TIMEFRAMES tf, 
                 CPoCAnalyzer* pocEngine, PoCResult &outPoC,
                 bool drawVisuals, color colSuccess, color colFail) 
{
    double zWidth = zHigh - zLow;
    double sl, tp;
    
    if (isBullish) {
        sl = zLow - (2.0 * pipSize);
        tp = zHigh + 2.0 * (zWidth + 2.0 * pipSize);
    } else {
        sl = zHigh + (2.0 * pipSize);
        tp = zLow - 2.0 * (zWidth + 2.0 * pipSize);
    }
    
    int touchIdx = -1;
    int startIdx = -1;
    
    for(int i = 0; i < rates_total; i++) {
        if(time[i] == zTime) { startIdx = i; break; }
    }
    
    if (startIdx == -1) return 0; 
    
    bool hasLeftZone = false;
    
    // --- 1. FIND THE TOUCH ENTRY ---
    for(int i = startIdx + 1; i < rates_total; i++) {
        if (isBullish) {
            if (!hasLeftZone && close[i] > zHigh) hasLeftZone = true;
            
            // Touch occurs
            if (hasLeftZone && low[i] <= zHigh) { 
                // Ensure at least 1 ZigZag peak occurred between creation and touch
                int pivotCount = 0;
                for(int p = 0; p < zigZag.pivots.Total(); p++) {
                    Pivot* pv = (Pivot*)zigZag.pivots.At(p);
                    if(pv.end.time > zTime && pv.end.time < time[i]) pivotCount++;
                }
                
                // Only valid if a new swing peak was formed
                if(pivotCount >= 1) {
                    touchIdx = i; 
                    break; 
                }
            }
        } else {
            if (!hasLeftZone && close[i] < zLow) hasLeftZone = true;
            
            // Touch occurs
            if (hasLeftZone && high[i] >= zLow) { 
                // Ensure at least 1 ZigZag peak occurred between creation and touch
                int pivotCount = 0;
                for(int p = 0; p < zigZag.pivots.Total(); p++) {
                    Pivot* pv = (Pivot*)zigZag.pivots.At(p);
                    if(pv.end.time > zTime && pv.end.time < time[i]) pivotCount++;
                }
                
                // Only valid if a new swing peak was formed
                if(pivotCount >= 1) {
                    touchIdx = i; 
                    break; 
                }
            }
        }
    }
    
    if (touchIdx == -1) return 0; // Never returned to retest the zone properly
    
    double dummyLivePrice = isBullish ? zHigh : zLow; 
    outPoC = pocEngine.EvaluateZone(isBullish, zTime, zHigh, zLow, touchIdx, 
                                    time, open, high, low, close, 
                                    zigZag, ms, dummyLivePrice, pipSize, tf);
    
    int result = 0;
    int endIdx = rates_total - 1;

    // --- 2. EVALUATE TRADE OUTCOME FROM ENTRY ---
    for(int i = touchIdx; i < rates_total; i++) {
        if (isBullish) {
            if (low[i] <= sl) { result = -1; endIdx = i; break; }
            if (high[i] >= tp) { result = 1; endIdx = i; break; }
        } else {
            if (high[i] >= sl) { result = -1; endIdx = i; break; }
            if (low[i] <= tp) { result = 1; endIdx = i; break; }
        }
    }

    // --- 3. VISUALIZATION DRAWING LOGIC ---
    if (drawVisuals) {
        long targetChart = FindChartID(sym, tf);
        
        if(targetChart >= 0) {
            string boxName = "BT_" + zoneLabel + "_" + IntegerToString(zTime);
            StringReplace(boxName, " ", "_");
            
            color fillCol = clrGray; 
            string txt = zoneLabel + " (PENDING)";
            
            if (result == 1) { fillCol = colSuccess; txt = zoneLabel + " (WIN)"; }
            else if (result == -1) { fillCol = colFail; txt = zoneLabel + " (LOSS)"; }

            // 1. Zone Box (Lifespan from creation to Trade close)
            ObjectCreate(targetChart, boxName, OBJ_RECTANGLE, 0, zTime, zHigh, time[endIdx], zLow);
            ObjectSetInteger(targetChart, boxName, OBJPROP_COLOR, ColorToARGB_Custom(fillCol, 40));
            ObjectSetInteger(targetChart, boxName, OBJPROP_FILL, true);
            ObjectSetInteger(targetChart, boxName, OBJPROP_BACK, true);
            
            // 2. Vertical Line exactly on the Entry Touch Bar
            string entryLine = boxName + "_entry";
            ObjectCreate(targetChart, entryLine, OBJ_VLINE, 0, time[touchIdx], 0);
            ObjectSetInteger(targetChart, entryLine, OBJPROP_COLOR, fillCol);
            ObjectSetInteger(targetChart, entryLine, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(targetChart, entryLine, OBJPROP_BACK, true);

            // 3. Take Profit Target Line (Dotted Green)
            string tpLine = boxName + "_tp";
            ObjectCreate(targetChart, tpLine, OBJ_TREND, 0, time[touchIdx], tp, time[endIdx], tp);
            ObjectSetInteger(targetChart, tpLine, OBJPROP_COLOR, clrLimeGreen);
            ObjectSetInteger(targetChart, tpLine, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(targetChart, tpLine, OBJPROP_RAY_RIGHT, false);
            
            // 4. Stop Loss Line (Dotted Red)
            string slLine = boxName + "_sl";
            ObjectCreate(targetChart, slLine, OBJ_TREND, 0, time[touchIdx], sl, time[endIdx], sl);
            ObjectSetInteger(targetChart, slLine, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(targetChart, slLine, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(targetChart, slLine, OBJPROP_RAY_RIGHT, false);

            // 5. Text Label
            string lblName = boxName + "_lbl";
            datetime midTime = zTime + (time[endIdx] - zTime) / 2;
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

class CBacktestInstance {
public:
    string             symbol;
    ENUM_TIMEFRAMES    tf;
    int                m_maxLookback;
    double             m_deviation;  
    int                m_depth;
    
    bool               m_draw;
    color              m_colSuccess;
    color              m_colFail;
    
    // Selective plotting flags
    bool               m_drawDemand;
    bool               m_drawSupply;
    bool               m_drawBullPOI;
    bool               m_drawBearPOI;
    bool               m_drawBullOB;
    bool               m_drawBearOB;
    
    ZigZag*            zigZag;
    CMarketStructure*  ms;
    CDemandSupplyLogic* dsLogic;
    CSwingPOILogic*    spLogic;
    COrderBlockLogic*  obLogic;
    CPoCAnalyzer*      pocEngine;
    
    BacktestMetrics    metrics;
    
    CBacktestInstance(string _symbol, ENUM_TIMEFRAMES _tf, double devInput, int depInput, int maxLB, 
                      bool draw, color cSucc, color cFail,
                      bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO) 
    {
        symbol = _symbol; tf = _tf; m_maxLookback = maxLB; m_deviation = devInput; m_depth = depInput;
        m_draw = draw; m_colSuccess = cSucc; m_colFail = cFail;
        m_drawDemand = drwDem; m_drawSupply = drwSup; 
        m_drawBullPOI = drwBullP; m_drawBearPOI = drwBearP;
        m_drawBullOB = drwBullO; m_drawBearOB = drwBearO;
        
        Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
        s.draw = false; 
        zigZag = newInstance(s);
        
        ms = new CMarketStructure(); ms.Init(false, false);
        dsLogic = new CDemandSupplyLogic(); spLogic = new CSwingPOILogic();
        obLogic = new COrderBlockLogic(); pocEngine = new CPoCAnalyzer();
        metrics.Init();
    }
    
    ~CBacktestInstance() {
        if(zigZag) delete zigZag; if(ms) delete ms;
        if(dsLogic) delete dsLogic; if(spLogic) delete spLogic;
        if(obLogic) delete obLogic; if(pocEngine) delete pocEngine;
    }

    bool RunBacktest() {
        int rates_total = Bars(symbol, tf);
        if(rates_total < m_depth * 2) return false;

        int start_bar = MathMax(0, rates_total - m_maxLookback);
        int to_copy = rates_total - start_bar;
        if(to_copy <= 0) return false;
        
        double open[], high[], low[], close[]; datetime time[]; long vol[];
        
        if(CopyTime(symbol, tf, 0, to_copy, time) < to_copy) return false;
        if(CopyOpen(symbol, tf, 0, to_copy, open) < to_copy) return false;
        if(CopyHigh(symbol, tf, 0, to_copy, high) < to_copy) return false;
        if(CopyLow(symbol, tf, 0, to_copy, low) < to_copy) return false;
        if(CopyClose(symbol, tf, 0, to_copy, close) < to_copy) return false;
        if(CopyTickVolume(symbol, tf, 0, to_copy, vol) < to_copy) return false;
        
        for(int i = 0; i < to_copy; i++) {
            bool is_last = (i == to_copy - 1);
            int bar_index = start_bar + i;
            
            zigZag.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
            ms.Update(i, time, high, low, close, zigZag);
            
            dsLogic.DetectPOIs(i, time, high, low, zigZag);
            spLogic.DetectPOIs(i, time, high, low, zigZag);
            obLogic.DetectPOIs(i, time, high, low, zigZag);
            
            if(obLogic.poi_demandTime.Total() > 0) {
                datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
                if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz)) {
                    if (obLogic.CheckBullishOB(tz, i, time, high, low)) obLogic.ob_bull_valid_times.Add((long)tz);
                }
            }
            if(obLogic.poi_supplyTime.Total() > 0) {
                datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
                if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz)) {
                    if (obLogic.CheckBearishOB(tz, i, time, high, low)) obLogic.ob_bear_valid_times.Add((long)tz);
                }
            }
        }
        
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
        PoCResult poc;
        
        for(int i=0; i<dsLogic.poi_demandTime.Total(); i++) {
            bool d = m_draw && m_drawDemand;
            int res = EvaluateZone(symbol, "Demand", true, dsLogic.poi_demandZoneHigh.At(i), dsLogic.poi_demandZoneLow.At(i), (datetime)dsLogic.poi_demandTime.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1) metrics.demand.RecordSuccess(poc); else if(res == -1) metrics.demand.RecordFail(poc); else metrics.demand.RecordPending();
        }
        for(int i=0; i<dsLogic.poi_supplyTime.Total(); i++) {
            bool d = m_draw && m_drawSupply;
            int res = EvaluateZone(symbol, "Supply", false, dsLogic.poi_supplyZoneHigh.At(i), dsLogic.poi_supplyZoneLow.At(i), (datetime)dsLogic.poi_supplyTime.At(i), pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
            if(res == 1) metrics.supply.RecordSuccess(poc); else if(res == -1) metrics.supply.RecordFail(poc); else metrics.supply.RecordPending();
        }
        for(int i=0; i<spLogic.poi_demandTime.Total(); i++) {
            datetime zTime = (datetime)spLogic.poi_demandTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bull_struct_times, zTime)) {
                bool d = m_draw && m_drawBullPOI;
                int res = EvaluateZone(symbol, "Bull POI", true, spLogic.poi_demandZoneHigh.At(i), spLogic.poi_demandZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
                if(res == 1) metrics.bullPOI.RecordSuccess(poc); else if(res == -1) metrics.bullPOI.RecordFail(poc); else metrics.bullPOI.RecordPending();
            }
        }
        for(int i=0; i<spLogic.poi_supplyTime.Total(); i++) {
            datetime zTime = (datetime)spLogic.poi_supplyTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bear_struct_times, zTime)) {
                bool d = m_draw && m_drawBearPOI;
                int res = EvaluateZone(symbol, "Bear POI", false, spLogic.poi_supplyZoneHigh.At(i), spLogic.poi_supplyZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
                if(res == 1) metrics.bearPOI.RecordSuccess(poc); else if(res == -1) metrics.bearPOI.RecordFail(poc); else metrics.bearPOI.RecordPending();
            }
        }
        for(int i=0; i<obLogic.poi_demandTime.Total(); i++) {
            datetime zTime = (datetime)obLogic.poi_demandTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bull_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, zTime)) {
                bool d = m_draw && m_drawBullOB;
                int res = EvaluateZone(symbol, "Bull OB", true, obLogic.poi_demandZoneHigh.At(i), obLogic.poi_demandZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
                if(res == 1) metrics.bullOB.RecordSuccess(poc); else if(res == -1) metrics.bullOB.RecordFail(poc); else metrics.bullOB.RecordPending();
            }
        }
        for(int i=0; i<obLogic.poi_supplyTime.Total(); i++) {
            datetime zTime = (datetime)obLogic.poi_supplyTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bear_struct_times, zTime) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, zTime)) {
                bool d = m_draw && m_drawBearOB;
                int res = EvaluateZone(symbol, "Bear OB", false, obLogic.poi_supplyZoneHigh.At(i), obLogic.poi_supplyZoneLow.At(i), zTime, pipSize, time, open, high, low, close, to_copy, zigZag, ms, tf, pocEngine, poc, d, m_colSuccess, m_colFail);
                if(res == 1) metrics.bearOB.RecordSuccess(poc); else if(res == -1) metrics.bearOB.RecordFail(poc); else metrics.bearOB.RecordPending();
            }
        }
        
        return true; 
    }
};