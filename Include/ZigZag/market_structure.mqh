//+------------------------------------------------------------------+
//|                            Include\ZigZag\market_structure.mqh   |
//|                 Market Structure Engine (BOS, CHoCH, Swings)     |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.01"

#include <ZigZag\ZigZag.mqh>
#include <ZigZag\mql_plotting.mqh>   // <--- Using Plotting Utility
#include <Arrays\ArrayLong.mqh>

class CMarketStructure {
public:
    // --- Settings ---
    bool m_showBosChoch;
    bool m_showSwingHL;

    // --- State Trackers ---
    int      trend; 
    double   protected_level_price;
    datetime protected_level_time;
    double   target_level_price;
    datetime target_level_time;

    double   abs_high;
    datetime abs_high_time;
    double   abs_low;
    datetime abs_low_time;

    datetime last_processed_pivot_time;
    datetime last_breakout_time;
    datetime ob_prev_prot_time;

    // --- Structural Trackers for External Use (POI/OB linking) ---
    CArrayLong ob_bull_struct_times;
    CArrayLong ob_bear_struct_times;

    // --- Constructor & Destructor ---
    CMarketStructure() {
        m_showBosChoch = true;
        m_showSwingHL = true;
        ResetState();
    }
    
    ~CMarketStructure() {
        ObjectsDeleteAll(0, "BOSCHoCH_"); 
        ObjectsDeleteAll(0, "SWING_");
    }

    // --- Initialization ---
    void Init(bool showBosChoch, bool showSwingHL) {
        m_showBosChoch = showBosChoch;
        m_showSwingHL = showSwingHL;
    }

    // --- State Reset ---
    void ResetState() {
        trend = 1; 
        protected_level_price = EMPTY_VALUE; protected_level_time = 0; 
        target_level_price = EMPTY_VALUE; target_level_time = 0;
        
        abs_high = EMPTY_VALUE; abs_high_time = 0; 
        abs_low = EMPTY_VALUE; abs_low_time = 0;
        
        last_processed_pivot_time = 0; 
        last_breakout_time = 0; 
        ob_prev_prot_time = 0;
        
        ob_bull_struct_times.Clear(); 
        ob_bear_struct_times.Clear(); 
        
        ObjectsDeleteAll(0, "BOSCHoCH_"); 
        ObjectsDeleteAll(0, "SWING_");
    }

    // --- Helper Functions (Kept exact names for external POI modules) ---
    string tf_str() { 
        int mins = PeriodSeconds() / 60;
        if (mins < 60) return IntegerToString(mins) + "m";
        else if (mins < 1440 && mins % 60 == 0) return "H" + IntegerToString(mins / 60);
        else if (mins == 1440) return "D";
        else if (mins == 10080) return "W";
        else if (mins >= 43200) return "M";
        return IntegerToString(mins) + "m";
    }

    color get_swing_color() {
        int mins = PeriodSeconds() / 60;
        if(mins < 1) return C'30,30,30';
        else if(mins <= 15) return C'0,0,139';
        else if(mins <= 60) return C'139,0,0';
        else if(mins < 1440) return C'0,100,0';
        else if(mins == 1440) return C'139,69,19';
        return C'47,79,79';
    }

    // --- Main Engine Update Module ---
    void Update(int i, const datetime &time[], const double &high[], const double &low[], const double &close[], ZigZag* zigZag) {
        // --- 1. INITIALIZATION ---
        if (protected_level_price == EMPTY_VALUE && zigZag.pivots.Total() >= 3) {
            for (int pidx = 0; pidx <= 2; pidx++) {
                Pivot* p = (Pivot*)zigZag.pivots.At(pidx);
                if (p.isHigh && trend == 1) { target_level_price = p.end.price; target_level_time = p.end.time; }
                if (!p.isHigh && trend == 1) { protected_level_price = p.end.price; protected_level_time = p.end.time; }
            }
        }

        if (abs_high == EMPTY_VALUE || high[i] > abs_high) { abs_high = high[i]; abs_high_time = time[i]; }
        if (abs_low == EMPTY_VALUE || low[i] < abs_low) { abs_low = low[i]; abs_low_time = time[i]; }

        if (zigZag.pivots.Total() >= 2) {
            Pivot* p = (Pivot*)zigZag.pivots.At(zigZag.pivots.Total() - 2);
            if (last_processed_pivot_time == 0 || p.end.time != last_processed_pivot_time) {
                last_processed_pivot_time = p.end.time;
                if (p.isHigh && trend == 1) {
                    if (target_level_price == EMPTY_VALUE || p.end.price > target_level_price) {
                        target_level_price = p.end.price; target_level_time = p.end.time;
                    }
                } else if (!p.isHigh && trend == -1) {
                    if (target_level_price == EMPTY_VALUE || p.end.price < target_level_price) {
                        target_level_price = p.end.price; target_level_time = p.end.time;
                    }
                }
            }
        }

        // --- BREAKOUT LOGIC ---
        bool crossUp = (trend == -1 && protected_level_price != EMPTY_VALUE && close[i] > protected_level_price) || 
                       (trend == 1 && target_level_price != EMPTY_VALUE && close[i] > target_level_price);
        bool crossDn = (trend == 1 && protected_level_price != EMPTY_VALUE && close[i] < protected_level_price) || 
                       (trend == -1 && target_level_price != EMPTY_VALUE && close[i] < target_level_price);

        double safe_high_price = abs_high; datetime safe_high_time = abs_high_time;
        double safe_low_price  = abs_low;  datetime safe_low_time  = abs_low_time;

        if (crossUp && (last_breakout_time == 0 || time[i] > last_breakout_time)) {
            if (trend == -1) {
                trend = 1;
                if(m_showBosChoch) {
                    datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
                    string id = "BOSCHoCH_" + IntegerToString(time[i]);
                    Plotter::DrawLine(id, protected_level_time, protected_level_price, time[i], protected_level_price, clrGreen, STYLE_SOLID, 2, false);
                    Plotter::DrawLabel(id+"_lbl", midTime, protected_level_price, tf_str()+"-BL-CHoCH", clrGreen, ANCHOR_LOWER);
                }
                protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_low_price;
                protected_level_time  = (target_level_time != 0) ? target_level_time : safe_low_time;

            } else if (trend == 1) {
                if(m_showBosChoch) {
                    datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                    string id = "BOSCHoCH_" + IntegerToString(time[i]);
                    Plotter::DrawLine(id, target_level_time, target_level_price, time[i], target_level_price, clrGreen, STYLE_SOLID, 2, false);
                    Plotter::DrawLabel(id+"_lbl", midTime, target_level_price, tf_str()+"-BL-BOS", clrGreen, ANCHOR_LOWER);
                }
                double pullback_low = EMPTY_VALUE; datetime pullback_low_time = 0;
                if (target_level_time != 0) {
                    for (int j = i; j >= 0 && j >= i - 2000; j--) {
                        if (time[j] < target_level_time) break;
                        if (pullback_low == EMPTY_VALUE || low[j] < pullback_low) { pullback_low = low[j]; pullback_low_time = time[j]; }
                    }
                }
                protected_level_price = (pullback_low != EMPTY_VALUE) ? pullback_low : safe_low_price;
                protected_level_time  = (pullback_low_time != 0) ? pullback_low_time : safe_low_time;
            }
            target_level_price = EMPTY_VALUE; target_level_time = 0; abs_high = EMPTY_VALUE; abs_low = EMPTY_VALUE; last_breakout_time = time[i];

        } else if (crossDn && (last_breakout_time == 0 || time[i] > last_breakout_time)) {
            if (trend == 1) {
                trend = -1;
                if(m_showBosChoch) {
                    datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
                    string id = "BOSCHoCH_" + IntegerToString(time[i]);
                    Plotter::DrawLine(id, protected_level_time, protected_level_price, time[i], protected_level_price, clrRed, STYLE_SOLID, 2, false);
                    Plotter::DrawLabel(id+"_lbl", midTime, protected_level_price, tf_str()+"-BR-CHoCH", clrRed, ANCHOR_UPPER);
                }
                protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_high_price;
                protected_level_time  = (target_level_time != 0) ? target_level_time : safe_high_time;

            } else if (trend == -1) {
                if(m_showBosChoch) {
                    datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                    string id = "BOSCHoCH_" + IntegerToString(time[i]);
                    Plotter::DrawLine(id, target_level_time, target_level_price, time[i], target_level_price, clrRed, STYLE_SOLID, 2, false);
                    Plotter::DrawLabel(id+"_lbl", midTime, target_level_price, tf_str()+"-BR-BOS", clrRed, ANCHOR_UPPER);
                }
                double pullback_high = EMPTY_VALUE; datetime pullback_high_time = 0;
                if (target_level_time != 0) {
                    for (int j = i; j >= 0 && j >= i - 2000; j--) {
                        if (time[j] < target_level_time) break;
                        if (pullback_high == EMPTY_VALUE || high[j] > pullback_high) { pullback_high = high[j]; pullback_high_time = time[j]; }
                    }
                }
                protected_level_price = (pullback_high != EMPTY_VALUE) ? pullback_high : safe_high_price;
                protected_level_time  = (pullback_high_time != 0) ? pullback_high_time : safe_high_time;
            }
            target_level_price = EMPTY_VALUE; target_level_time = 0; abs_high = EMPTY_VALUE; abs_low = EMPTY_VALUE; last_breakout_time = time[i];
        }

        // --- SWING POI STRUCTURAL TRACKING LOGIC ---
        if (protected_level_time != 0 && (ob_prev_prot_time == 0 || protected_level_time != ob_prev_prot_time)) {
            ob_prev_prot_time = protected_level_time;
            if (trend == 1) ob_bull_struct_times.Add((long)protected_level_time);
            else if (trend == -1) ob_bear_struct_times.Add((long)protected_level_time);
        }

        // --- LATEST SWING HIGH & LOW LINES ---
        if (m_showSwingHL) {
            color swing_line_color = get_swing_color();
            double active_swing_high_price = (trend == -1) ? protected_level_price : safe_high_price;
            datetime active_swing_high_time  = (trend == -1) ? protected_level_time  : safe_high_time;
            double active_swing_low_price  = (trend == 1)  ? protected_level_price : safe_low_price;
            datetime active_swing_low_time   = (trend == 1)  ? protected_level_time  : safe_low_time;

            if (active_swing_high_price != EMPTY_VALUE && active_swing_high_time != 0) {
                string hln = "SWING_HIGH_LINE"; string hlbl = "SWING_HIGH_LBL";
                datetime mTime = active_swing_high_time + (time[i] - active_swing_high_time)/2;
                Plotter::DrawLine(hln, active_swing_high_time, active_swing_high_price, time[i], active_swing_high_price, swing_line_color, STYLE_DASH, 1, false);
                Plotter::DrawLabel(hlbl, mTime, active_swing_high_price, " "+tf_str()+"-SWING-HIGH ", swing_line_color, ANCHOR_LOWER);
            }

            if (active_swing_low_price != EMPTY_VALUE && active_swing_low_time != 0) {
                string lln = "SWING_LOW_LINE"; string llbl = "SWING_LOW_LBL";
                datetime mTimeL = active_swing_low_time + (time[i] - active_swing_low_time)/2;
                Plotter::DrawLine(lln, active_swing_low_time, active_swing_low_price, time[i], active_swing_low_price, swing_line_color, STYLE_DASH, 1, false);
                Plotter::DrawLabel(llbl, mTimeL, active_swing_low_price, " "+tf_str()+"-SWING-LOW ", swing_line_color, ANCHOR_UPPER);
            }
        }
    }
};

CMarketMetrics* GetMarketStructureMetrics(CMarketStructure* ms) {
    CMarketMetrics* metrics = new CMarketMetrics();
    if (ms != NULL) {
        metrics.trendContext = ms.trend;
        metrics.lastBosChochTime = ms.last_breakout_time;
    }
    return metrics;
}