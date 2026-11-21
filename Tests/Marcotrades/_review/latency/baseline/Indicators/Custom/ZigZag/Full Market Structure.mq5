#define MARCO_LOG_PROGRAM "Full Market Structure"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                              ZigZag_SMC_BOS.mq5  |
//|                    100% Exact Translation from Pine Script v6    |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.03"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\ZigZag\ZigZag.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayObj.mqh>

// =============================================================================
// USER INPUTS 
// =============================================================================
input group "Visibility"
input bool   showZigZagInput          = false;        // Show Zig Zag Lines

input group "Zig Zag Settings"
input double deviationInput           = 0.15;         // Price deviation for reversals (%)
input int    depthInput               = 5;            // Pivot legs
input color  lineColorInput           = clrBlue;      // Line color
input bool   extendInput              = true;         // Extend to last bar
input bool   showPriceInput           = true;         // Display reversal price
input bool   showVolInput             = true;         // Display cumulative volume
input bool   showChgInput             = true;         // Display reversal price change
input string priceDiffInput           = "Absolute";   // Difference Mode (Absolute/Percent)

input group "POI Zones"
input bool   showDemandZones          = true;         // Display Demand Zones
input bool   showSupplyZones          = true;         // Display Supply Zones
input bool   showMitigatedDemandZones = false;        // Display Mitigated Demand Zones
input bool   showMitigatedSupplyZones = false;        // Display Mitigated Supply Zones

input group "Order Blocks"
input bool   showBullishOB            = true;         // Display Bullish Order Blocks
input bool   showBearishOB            = true;         // Display Bearish Order Blocks
input bool   showMitigatedBullishOB   = false;        // Display Mitigated Bullish Order Blocks
input bool   showMitigatedBearishOB   = false;        // Display Mitigated Bearish Order Blocks

input group "Swing POIs"
input bool   showBullishPOI           = true;         // Display Unmitigated Bullish POI
input bool   showBearishPOI           = true;         // Display Unmitigated Bearish POI
input bool   showMitigatedBullishPOI  = false;        // Display Mitigated Bullish POI
input bool   showMitigatedBearishPOI  = false;        // Display Mitigated Bearish POI

// =============================================================================
// GLOBALS & STATE TRACKERS
// =============================================================================
ZigZag* zigZag = NULL;

int trend = 1; 
double protected_level_price = EMPTY_VALUE;
datetime protected_level_time = 0;
double target_level_price = EMPTY_VALUE;
datetime target_level_time = 0;

double abs_high = EMPTY_VALUE;
datetime abs_high_time = 0;
double abs_low = EMPTY_VALUE;
datetime abs_low_time = 0;

datetime last_processed_pivot_time = 0;
datetime last_breakout_time = 0;

datetime poi_last_pivot_time = 0;
datetime ob_prev_prot_time = 0;

// =============================================================================
// HELPER CLASSES & ARRAYS
// =============================================================================
color ColorToARGB_Custom(color c, uchar alpha) { return (color)((alpha << 24) | c); }
color POI_TRANSPARENT = clrNONE;

class PineBox : public CObject {
public:
    string id;
    datetime left; double top; datetime right; double bottom;
    string text;
    color text_col;

    PineBox(string _id) { 
        id = _id; text = ""; text_col = clrWhite; 
    }
    ~PineBox() { 
        ObjectDelete(0, id); ObjectDelete(0, id + "_lbl"); 
    }

    void set_bounds(datetime l, double t, datetime r, double b) {
        left = l; top = t; right = r; bottom = b;
        if(ObjectFind(0, id) < 0) {
            ObjectCreate(0, id, OBJ_RECTANGLE, 0, left, top, right, bottom);
            ObjectSetInteger(0, id, OBJPROP_FILL, true);
        } else {
            ObjectSetInteger(0, id, OBJPROP_TIME, 0, left);
            ObjectSetDouble(0, id, OBJPROP_PRICE, 0, top);
            ObjectSetInteger(0, id, OBJPROP_TIME, 1, right);
            ObjectSetDouble(0, id, OBJPROP_PRICE, 1, bottom);
        }
        update_text_pos();
    }
    
    void set_right(datetime r) {
        right = r;
        ObjectSetInteger(0, id, OBJPROP_TIME, 1, right);
        update_text_pos();
    }

    void update_text_pos() {
        if(text != "") {
            datetime midTime = left + (right - left) / 2;
            double midPrice = bottom + (top - bottom) / 2;
            if(ObjectFind(0, id + "_lbl") < 0) {
                ObjectCreate(0, id + "_lbl", OBJ_TEXT, 0, midTime, midPrice);
                ObjectSetInteger(0, id + "_lbl", OBJPROP_ANCHOR, ANCHOR_CENTER);
                ObjectSetInteger(0, id + "_lbl", OBJPROP_FONTSIZE, 8);
            } else {
                ObjectSetInteger(0, id + "_lbl", OBJPROP_TIME, midTime);
                ObjectSetDouble(0, id + "_lbl", OBJPROP_PRICE, midPrice);
            }
            if(text_col == clrNONE) { ObjectSetString(0, id + "_lbl", OBJPROP_TEXT, " "); } 
            else { ObjectSetString(0, id + "_lbl", OBJPROP_TEXT, text); ObjectSetInteger(0, id + "_lbl", OBJPROP_COLOR, text_col); }
        }
    }

    void set_bgcolor(color c, uchar alpha=255) {
        if(c == clrNONE) { 
            ObjectSetInteger(0, id, OBJPROP_COLOR, clrNONE); ObjectSetInteger(0, id, OBJPROP_BACK, false); 
        } else { 
            ObjectSetInteger(0, id, OBJPROP_COLOR, ColorToARGB_Custom(c, alpha)); ObjectSetInteger(0, id, OBJPROP_BACK, true); 
        }
    }
    
    void set_text(string t) { text = t; update_text_pos(); }
    void set_text_color(color c) { text_col = c; update_text_pos(); }
};

CArrayObj    poi_demandBoxes;
CArrayDouble poi_demandZoneLow;
CArrayDouble poi_demandZoneHigh;
CArrayInt    poi_demandMitigated;

CArrayObj    poi_supplyBoxes;
CArrayDouble poi_supplyZoneLow;
CArrayDouble poi_supplyZoneHigh;
CArrayInt    poi_supplyMitigated;

CArrayLong ob_bull_struct_times;
CArrayLong ob_bear_struct_times;
CArrayLong ob_bull_valid_times;
CArrayLong ob_bear_valid_times;

// --- Colors ---
color POI_DEMAND_COLOR;  color POI_DEMAND_BORDER;
color POI_SUPPLY_COLOR;  color POI_SUPPLY_BORDER;
color POI_MITIG_COLOR;   color POI_MITIG_BORDER;

color OB_BULL_FILL;      color OB_BULL_BORDER;   color OB_BULL_TEXT;
color OB_BEAR_FILL;      color OB_BEAR_BORDER;   color OB_BEAR_TEXT;
color OB_MITIG_FILL;     color OB_MITIG_BORDER;

color POI_SWING_BULL_FILL;   color POI_SWING_BULL_BORDER;   color POI_SWING_BULL_TEXT;
color POI_SWING_BEAR_FILL;   color POI_SWING_BEAR_BORDER;   color POI_SWING_BEAR_TEXT;
color POI_SWING_MITIG_FILL;  color POI_SWING_MITIG_BORDER;

// =============================================================================
// INITIALIZATION
// =============================================================================
int OnInit() {
   g_marcoDailyLog.Start();
    Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, showZigZagInput ? showPriceInput : false, showZigZagInput ? showVolInput : false, showZigZagInput ? showChgInput : false, priceDiffInput);
    s.draw = showZigZagInput;
    zigZag = newInstance(s);
    
    POI_DEMAND_COLOR = ColorToARGB_Custom(clrGreen, 46);
    POI_SUPPLY_COLOR = ColorToARGB_Custom(clrRed, 46);
    POI_MITIG_COLOR  = ColorToARGB_Custom(clrGray, 46);
    OB_BULL_FILL     = ColorToARGB_Custom(C'10,123,167', 51);
    OB_BULL_TEXT     = C'10,123,167';
    OB_BEAR_FILL     = ColorToARGB_Custom(C'173,86,145', 51);
    OB_BEAR_TEXT     = C'173,86,145';
    OB_MITIG_FILL    = ColorToARGB_Custom(clrGray, 46);
    POI_SWING_BULL_FILL = ColorToARGB_Custom(C'0,100,0', 51);
    POI_SWING_BULL_TEXT = C'0,100,0';
    POI_SWING_BEAR_FILL = ColorToARGB_Custom(C'128,0,0', 51);
    POI_SWING_BEAR_TEXT = C'128,0,0';
    POI_SWING_MITIG_FILL = ColorToARGB_Custom(clrGray, 46);

    poi_demandBoxes.FreeMode(true);
    poi_supplyBoxes.FreeMode(true);

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
    if(zigZag != NULL) delete zigZag;
    ObjectsDeleteAll(0, "ZZ_Ln_"); ObjectsDeleteAll(0, "ZZ_Lbl_"); ObjectsDeleteAll(0, "ZZ_Proj_");
    ObjectsDeleteAll(0, "BOSCHoCH_"); ObjectsDeleteAll(0, "SWING_"); ObjectsDeleteAll(0, "POI_");
}

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

bool ob_time_found(CArrayLong* arr, datetime t) {
    for(int j=0; j<arr.Total(); j++) if((datetime)arr.At(j) == t) return true;
    return false;
}

// Order Block Exact 6-Step Validation Engine
bool CheckBullishOB(datetime pivot_time, int current_i, const datetime &time[], const double &high[], const double &low[]) {
    double ob_pc_high = EMPTY_VALUE, ob_pc_low = EMPTY_VALUE;
    double ob_pm1_high = EMPTY_VALUE, ob_pm1_low = EMPTY_VALUE;
    double ob_pp1_high = EMPTY_VALUE, ob_pp1_low = EMPTY_VALUE;
    double ob_pp2_high = EMPTY_VALUE, ob_pp2_low = EMPTY_VALUE;
    
    for(int j = current_i; j >= 0; j--) {
        if(time[j] == pivot_time) {
            ob_pc_high = high[j]; ob_pc_low = low[j];
            if (j - 1 >= 0) { ob_pm1_high = high[j - 1]; ob_pm1_low = low[j - 1]; } // older bar
            if (j + 1 <= current_i) { ob_pp1_high = high[j + 1]; ob_pp1_low = low[j + 1]; } // newer bar
            if (j + 2 <= current_i) { ob_pp2_high = high[j + 2]; ob_pp2_low = low[j + 2]; } // newer bar 2
            break;
        }
        if(time[j] < pivot_time) break; 
    }
    
    if (ob_pc_high == EMPTY_VALUE || ob_pm1_high == EMPTY_VALUE || ob_pp1_high == EMPTY_VALUE || ob_pp2_high == EMPTY_VALUE) return false;
    return (ob_pc_low < ob_pm1_low && ob_pc_low < ob_pp1_low && ob_pc_high < ob_pp1_high && ob_pp1_high < ob_pp2_high && ob_pc_high < ob_pp2_low);
}

bool CheckBearishOB(datetime pivot_time, int current_i, const datetime &time[], const double &high[], const double &low[]) {
    double ob_pc_high = EMPTY_VALUE, ob_pc_low = EMPTY_VALUE;
    double ob_pm1_high = EMPTY_VALUE, ob_pm1_low = EMPTY_VALUE;
    double ob_pp1_high = EMPTY_VALUE, ob_pp1_low = EMPTY_VALUE;
    double ob_pp2_high = EMPTY_VALUE, ob_pp2_low = EMPTY_VALUE;
    
    for(int j = current_i; j >= 0; j--) {
        if(time[j] == pivot_time) {
            ob_pc_high = high[j]; ob_pc_low = low[j];
            if (j - 1 >= 0) { ob_pm1_high = high[j - 1]; ob_pm1_low = low[j - 1]; } 
            if (j + 1 <= current_i) { ob_pp1_high = high[j + 1]; ob_pp1_low = low[j + 1]; } 
            if (j + 2 <= current_i) { ob_pp2_high = high[j + 2]; ob_pp2_low = low[j + 2]; } 
            break;
        }
        if(time[j] < pivot_time) break; 
    }
    
    if (ob_pc_high == EMPTY_VALUE || ob_pm1_high == EMPTY_VALUE || ob_pp1_high == EMPTY_VALUE || ob_pp2_high == EMPTY_VALUE) return false;
    return (ob_pc_high > ob_pm1_high && ob_pc_high > ob_pp1_high && ob_pc_low > ob_pp1_low && ob_pp1_low > ob_pp2_low && ob_pc_low > ob_pp2_high);
}

void ResetState() {
    trend = 1; protected_level_price = EMPTY_VALUE; protected_level_time = 0; target_level_price = EMPTY_VALUE; target_level_time = 0;
    abs_high = EMPTY_VALUE; abs_high_time = 0; abs_low = EMPTY_VALUE; abs_low_time = 0;
    last_processed_pivot_time = 0; last_breakout_time = 0; poi_last_pivot_time = 0; ob_prev_prot_time = 0;
    
    poi_demandBoxes.Clear(); poi_demandZoneLow.Clear(); poi_demandZoneHigh.Clear(); poi_demandMitigated.Clear();
    poi_supplyBoxes.Clear(); poi_supplyZoneLow.Clear(); poi_supplyZoneHigh.Clear(); poi_supplyMitigated.Clear();
    ob_bull_struct_times.Clear(); ob_bear_struct_times.Clear(); ob_bull_valid_times.Clear(); ob_bear_valid_times.Clear();
    
    ObjectsDeleteAll(0, "BOSCHoCH_"); ObjectsDeleteAll(0, "SWING_"); ObjectsDeleteAll(0, "POI_");
}

// =============================================================================
// MAIN CALCULATION
// =============================================================================
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
   g_marcoDailyLog.Pulse();
    if(rates_total < depthInput * 2) return 0;
    if(prev_calculated == 0) ResetState();

    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
    
    for(int i = start; i < rates_total; i++) {
        bool is_last = (i == rates_total - 1);
        zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);

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
                datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
                string id = "BOSCHoCH_" + IntegerToString(time[i]);
                ObjectCreate(0, id, OBJ_TREND, 0, protected_level_time, protected_level_price, time[i], protected_level_price);
                ObjectSetInteger(0, id, OBJPROP_COLOR, clrGreen); ObjectSetInteger(0, id, OBJPROP_WIDTH, 2); ObjectSetInteger(0, id, OBJPROP_RAY_RIGHT, false);
                
                ObjectCreate(0, id+"_lbl", OBJ_TEXT, 0, midTime, protected_level_price);
                ObjectSetInteger(0, id+"_lbl", OBJPROP_ANCHOR, ANCHOR_LOWER); 
                ObjectSetString(0, id+"_lbl", OBJPROP_TEXT, tf_str()+"-BL-CHoCH"); ObjectSetInteger(0, id+"_lbl", OBJPROP_COLOR, clrGreen);

                protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_low_price;
                protected_level_time  = (target_level_time != 0) ? target_level_time : safe_low_time;

            } else if (trend == 1) {
                datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                string id = "BOSCHoCH_" + IntegerToString(time[i]);
                ObjectCreate(0, id, OBJ_TREND, 0, target_level_time, target_level_price, time[i], target_level_price);
                ObjectSetInteger(0, id, OBJPROP_COLOR, clrGreen); ObjectSetInteger(0, id, OBJPROP_WIDTH, 2); ObjectSetInteger(0, id, OBJPROP_RAY_RIGHT, false);
                
                ObjectCreate(0, id+"_lbl", OBJ_TEXT, 0, midTime, target_level_price);
                ObjectSetInteger(0, id+"_lbl", OBJPROP_ANCHOR, ANCHOR_LOWER);
                ObjectSetString(0, id+"_lbl", OBJPROP_TEXT, tf_str()+"-BL-BOS"); ObjectSetInteger(0, id+"_lbl", OBJPROP_COLOR, clrGreen);

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
                datetime midTime = protected_level_time + (time[i] - protected_level_time) / 2;
                string id = "BOSCHoCH_" + IntegerToString(time[i]);
                ObjectCreate(0, id, OBJ_TREND, 0, protected_level_time, protected_level_price, time[i], protected_level_price);
                ObjectSetInteger(0, id, OBJPROP_COLOR, clrRed); ObjectSetInteger(0, id, OBJPROP_WIDTH, 2); ObjectSetInteger(0, id, OBJPROP_RAY_RIGHT, false);
                
                ObjectCreate(0, id+"_lbl", OBJ_TEXT, 0, midTime, protected_level_price);
                ObjectSetInteger(0, id+"_lbl", OBJPROP_ANCHOR, ANCHOR_UPPER); 
                ObjectSetString(0, id+"_lbl", OBJPROP_TEXT, tf_str()+"-BR-CHoCH"); ObjectSetInteger(0, id+"_lbl", OBJPROP_COLOR, clrRed);

                protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_high_price;
                protected_level_time  = (target_level_time != 0) ? target_level_time : safe_high_time;

            } else if (trend == -1) {
                datetime midTime = target_level_time + (time[i] - target_level_time) / 2;
                string id = "BOSCHoCH_" + IntegerToString(time[i]);
                ObjectCreate(0, id, OBJ_TREND, 0, target_level_time, target_level_price, time[i], target_level_price);
                ObjectSetInteger(0, id, OBJPROP_COLOR, clrRed); ObjectSetInteger(0, id, OBJPROP_WIDTH, 2); ObjectSetInteger(0, id, OBJPROP_RAY_RIGHT, false);
                
                ObjectCreate(0, id+"_lbl", OBJ_TEXT, 0, midTime, target_level_price);
                ObjectSetInteger(0, id+"_lbl", OBJPROP_ANCHOR, ANCHOR_UPPER);
                ObjectSetString(0, id+"_lbl", OBJPROP_TEXT, tf_str()+"-BR-BOS"); ObjectSetInteger(0, id+"_lbl", OBJPROP_COLOR, clrRed);

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
        color swing_line_color = get_swing_color();
        double active_swing_high_price = (trend == -1) ? protected_level_price : safe_high_price;
        datetime active_swing_high_time  = (trend == -1) ? protected_level_time  : safe_high_time;
        double active_swing_low_price  = (trend == 1)  ? protected_level_price : safe_low_price;
        datetime active_swing_low_time   = (trend == 1)  ? protected_level_time  : safe_low_time;

        if (active_swing_high_price != EMPTY_VALUE && active_swing_high_time != 0) {
            string hln = "SWING_HIGH_LINE"; string hlbl = "SWING_HIGH_LBL";
            if(ObjectFind(0, hln)<0) ObjectCreate(0, hln, OBJ_TREND, 0, active_swing_high_time, active_swing_high_price, time[i], active_swing_high_price);
            else { ObjectSetInteger(0, hln, OBJPROP_TIME, 0, active_swing_high_time); ObjectSetDouble(0, hln, OBJPROP_PRICE, 0, active_swing_high_price); ObjectSetInteger(0, hln, OBJPROP_TIME, 1, time[i]); ObjectSetDouble(0, hln, OBJPROP_PRICE, 1, active_swing_high_price); }
            ObjectSetInteger(0, hln, OBJPROP_COLOR, swing_line_color); ObjectSetInteger(0, hln, OBJPROP_STYLE, STYLE_DASH); ObjectSetInteger(0, hln, OBJPROP_RAY_RIGHT, false);
            
            datetime mTime = active_swing_high_time + (time[i] - active_swing_high_time)/2;
            if(ObjectFind(0, hlbl)<0) ObjectCreate(0, hlbl, OBJ_TEXT, 0, mTime, active_swing_high_price);
            else { ObjectSetInteger(0, hlbl, OBJPROP_TIME, mTime); ObjectSetDouble(0, hlbl, OBJPROP_PRICE, active_swing_high_price); }
            ObjectSetString(0, hlbl, OBJPROP_TEXT, " "+tf_str()+"-SWING-HIGH "); ObjectSetInteger(0, hlbl, OBJPROP_COLOR, swing_line_color); ObjectSetInteger(0, hlbl, OBJPROP_ANCHOR, ANCHOR_LOWER);
        }

        if (active_swing_low_price != EMPTY_VALUE && active_swing_low_time != 0) {
            string lln = "SWING_LOW_LINE"; string llbl = "SWING_LOW_LBL";
            if(ObjectFind(0, lln)<0) ObjectCreate(0, lln, OBJ_TREND, 0, active_swing_low_time, active_swing_low_price, time[i], active_swing_low_price);
            else { ObjectSetInteger(0, lln, OBJPROP_TIME, 0, active_swing_low_time); ObjectSetDouble(0, lln, OBJPROP_PRICE, 0, active_swing_low_price); ObjectSetInteger(0, lln, OBJPROP_TIME, 1, time[i]); ObjectSetDouble(0, lln, OBJPROP_PRICE, 1, active_swing_low_price); }
            ObjectSetInteger(0, lln, OBJPROP_COLOR, swing_line_color); ObjectSetInteger(0, lln, OBJPROP_STYLE, STYLE_DASH); ObjectSetInteger(0, lln, OBJPROP_RAY_RIGHT, false);
            
            datetime mTimeL = active_swing_low_time + (time[i] - active_swing_low_time)/2;
            if(ObjectFind(0, llbl)<0) ObjectCreate(0, llbl, OBJ_TEXT, 0, mTimeL, active_swing_low_price);
            else { ObjectSetInteger(0, llbl, OBJPROP_TIME, mTimeL); ObjectSetDouble(0, llbl, OBJPROP_PRICE, active_swing_low_price); }
            ObjectSetString(0, llbl, OBJPROP_TEXT, " "+tf_str()+"-SWING-LOW "); ObjectSetInteger(0, llbl, OBJPROP_COLOR, swing_line_color); ObjectSetInteger(0, llbl, OBJPROP_ANCHOR, ANCHOR_UPPER);
        }

        // --- POI DETECTOR MODULE ---
        datetime poi_extend_right = time[i] + 50 * PeriodSeconds();

        if (zigZag.pivots.Total() >= 2) {
            Pivot* zp = (Pivot*)zigZag.pivots.At(zigZag.pivots.Total() - 2);
            if (poi_last_pivot_time == 0 || zp.end.time != poi_last_pivot_time) {
                poi_last_pivot_time = zp.end.time;

                double zc_high = EMPTY_VALUE; double zc_low = EMPTY_VALUE;
                int lookback = (int)MathMin(i, 500);
                for (int k = 0; k <= lookback; k++) {
                    int j = i - k;
                    if (time[j] == zp.end.time) { zc_high = high[j]; zc_low = low[j]; break; }
                    if (time[j] < zp.end.time) break;
                }

                if (zc_high != EMPTY_VALUE && zc_low != EMPTY_VALUE) {
                    if (!zp.isHigh) {
                        PineBox* dBox = new PineBox("POI_D_" + IntegerToString(zp.end.time));
                        dBox.set_bounds(zp.end.time, zc_high, poi_extend_right, zc_low);
                        dBox.set_bgcolor(showDemandZones ? POI_DEMAND_COLOR : POI_TRANSPARENT);
                        dBox.set_text_color(showDemandZones ? clrGreen : POI_TRANSPARENT);
                        dBox.set_text(tf_str() + "-DemandZone");

                        poi_demandBoxes.Add(dBox);
                        poi_demandZoneLow.Add(zc_low);
                        poi_demandZoneHigh.Add(zc_high);
                        poi_demandMitigated.Add(0);
                    } else {
                        PineBox* sBox = new PineBox("POI_S_" + IntegerToString(zp.end.time));
                        sBox.set_bounds(zp.end.time, zc_high, poi_extend_right, zc_low);
                        sBox.set_bgcolor(showSupplyZones ? POI_SUPPLY_COLOR : POI_TRANSPARENT);
                        sBox.set_text_color(showSupplyZones ? clrRed : POI_TRANSPARENT);
                        sBox.set_text(tf_str() + "-SupplyZone");

                        poi_supplyBoxes.Add(sBox);
                        poi_supplyZoneLow.Add(zc_low);
                        poi_supplyZoneHigh.Add(zc_high);
                        poi_supplyMitigated.Add(0);
                    }
                }
            }
        }

        // --- MORPHING MODULE: ORDER BLOCKS & SWING POI ---
        for(int m = 0; m < poi_demandBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_demandBoxes.At(m);
            bool mit = (poi_demandMitigated.At(m) == 1);
            double zl = poi_demandZoneLow.At(m);
            datetime box_time = b.left;

            // Continual checking secures exact Order Blocks immediately as the Structure becomes valid
            bool is_bull_poi = ob_time_found(&ob_bull_struct_times, box_time);
            bool is_bull_ob  = false;

            if (is_bull_poi) {
                if (ob_time_found(&ob_bull_valid_times, box_time)) {
                    is_bull_ob = true;
                } else if (CheckBullishOB(box_time, i, time, high, low)) {
                    ob_bull_valid_times.Add((long)box_time);
                    is_bull_ob = true;
                }
            }

            if (!mit) {
                b.set_right(poi_extend_right);
                if (close[i] < zl) {
                    poi_demandMitigated.Update(m, 1);
                    mit = true;
                }
            }

            if (is_bull_ob) {
                if (!mit) {
                    if (showBullishOB) {
                        b.set_bgcolor(OB_BULL_FILL); b.set_text_color(OB_BULL_TEXT);
                        b.set_text(tf_str() + " BULLISH ORDER-BLOCK");
                    } else if (showBullishPOI) {
                        b.set_bgcolor(POI_SWING_BULL_FILL); b.set_text_color(POI_SWING_BULL_TEXT);
                        b.set_text(tf_str() + " BULLISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                } else {
                    if (showMitigatedBullishOB) {
                        b.set_bgcolor(OB_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BULLISH ORDER-BLOCK");
                    } else if (showMitigatedBullishPOI) {
                        b.set_bgcolor(POI_SWING_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BULLISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            } else if (is_bull_poi) {
                if (!mit) {
                    if (showBullishPOI) {
                        b.set_bgcolor(POI_SWING_BULL_FILL); b.set_text_color(POI_SWING_BULL_TEXT);
                        b.set_text(tf_str() + " BULLISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                } else {
                    if (showMitigatedBullishPOI) {
                        b.set_bgcolor(POI_SWING_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BULLISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            } else {
                if (!mit) {
                    b.set_bgcolor(showDemandZones ? POI_DEMAND_COLOR : POI_TRANSPARENT);
                    b.set_text_color(showDemandZones ? clrGreen : POI_TRANSPARENT);
                    b.set_text(tf_str() + "-DemandZone");
                } else {
                    if (showMitigatedDemandZones) { b.set_bgcolor(POI_MITIG_COLOR); b.set_text_color(clrGray); }
                    else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            }
        }

        for(int m = 0; m < poi_supplyBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_supplyBoxes.At(m);
            bool mit = (poi_supplyMitigated.At(m) == 1);
            double zh = poi_supplyZoneHigh.At(m);
            datetime box_time = b.left;

            bool is_bear_poi = ob_time_found(&ob_bear_struct_times, box_time);
            bool is_bear_ob  = false;

            if (is_bear_poi) {
                if (ob_time_found(&ob_bear_valid_times, box_time)) {
                    is_bear_ob = true;
                } else if (CheckBearishOB(box_time, i, time, high, low)) {
                    ob_bear_valid_times.Add((long)box_time);
                    is_bear_ob = true;
                }
            }

            if (!mit) {
                b.set_right(poi_extend_right);
                if (close[i] > zh) {
                    poi_supplyMitigated.Update(m, 1);
                    mit = true;
                }
            }

            if (is_bear_ob) {
                if (!mit) {
                    if (showBearishOB) {
                        b.set_bgcolor(OB_BEAR_FILL); b.set_text_color(OB_BEAR_TEXT);
                        b.set_text(tf_str() + " BEARISH ORDER-BLOCK");
                    } else if (showBearishPOI) {
                        b.set_bgcolor(POI_SWING_BEAR_FILL); b.set_text_color(POI_SWING_BEAR_TEXT);
                        b.set_text(tf_str() + " BEARISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                } else {
                    if (showMitigatedBearishOB) {
                        b.set_bgcolor(OB_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BEARISH ORDER-BLOCK");
                    } else if (showMitigatedBearishPOI) {
                        b.set_bgcolor(POI_SWING_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BEARISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            } else if (is_bear_poi) {
                if (!mit) {
                    if (showBearishPOI) {
                        b.set_bgcolor(POI_SWING_BEAR_FILL); b.set_text_color(POI_SWING_BEAR_TEXT);
                        b.set_text(tf_str() + " BEARISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                } else {
                    if (showMitigatedBearishPOI) {
                        b.set_bgcolor(POI_SWING_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(tf_str() + " BEARISH POI");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            } else {
                if (!mit) {
                    b.set_bgcolor(showSupplyZones ? POI_SUPPLY_COLOR : POI_TRANSPARENT);
                    b.set_text_color(showSupplyZones ? clrRed : POI_TRANSPARENT);
                    b.set_text(tf_str() + "-SupplyZone");
                } else {
                    if (showMitigatedSupplyZones) { b.set_bgcolor(POI_MITIG_COLOR); b.set_text_color(clrGray); }
                    else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
                }
            }
        }
    }
    
    return rates_total;
}

// END FILE: Indicators\Custom\ZigZag\Full Market Structure.mq5

// END FILE: Indicators\Custom\ZigZag\Full Market Structure.mq5
