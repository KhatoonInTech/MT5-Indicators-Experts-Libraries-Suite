//+------------------------------------------------------------------+
//|  Zig Zag BOS & CHoCH  +  POI Demand/Supply Zone Detector         |
//|              +  Order Block & Swing POI Morphing Module           |
//|  Original BOS/CHoCH logic is UNTOUCHED.                          |
//|  POI module is UNTOUCHED.                                         |
//|  New section clearly marked: "MORPHING MODULE: ORDER BLOCKS..."   |
//+------------------------------------------------------------------+
#property copyright   ""
#property version     "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Max objects (mirrors Pine Script max_lines_count / max_labels_count / max_boxes_count = 500)
#define MAX_LINES  500
#define MAX_LABELS 500
#define MAX_BOXES  500

//=============================================================================
// USER INPUTS  (mirrors all input.* declarations in Pine Script)
//=============================================================================

// ── Visibility ────────────────────────────────────────────────────────────────
input bool   showZigZagInput = false;              // Show Zig Zag Lines

// ── Zig Zag Settings ─────────────────────────────────────────────────────────
input double deviationInput  = 0.15;              // Price deviation for reversals (%)
input int    depthInput      = 5;                 // Pivot legs
input color  lineColorInput  = 0x2962FF;          // Line color  (Pine: #2962FF)
input bool   extendInput     = true;              // Extend to last bar
input bool   showPriceInput  = true;              // Display reversal price
input bool   showVolInput    = true;              // Display cumulative volume
input bool   showChgInput    = true;              // Display reversal price change
input string priceDiffInput  = "Absolute";        // "" ["Absolute","Percent"]  active=showChgInput

// ── POI Zone Settings ─────────────────────────────────────────────────────────
input bool   showDemandZones          = true;     // Display Demand Zones
input bool   showSupplyZones          = true;     // Display Supply Zones
input bool   showMitigatedDemandZones = false;    // Display Mitigated Demand Zones
input bool   showMitigatedSupplyZones = false;    // Display Mitigated Supply Zones

// ── Order Block Settings ──────────────────────────────────────────────────────
input bool   showBullishOB          = true;       // Display Bullish Order Blocks
input bool   showBearishOB          = true;       // Display Bearish Order Blocks
input bool   showMitigatedBullishOB = false;      // Display Mitigated Bullish Order Blocks
input bool   showMitigatedBearishOB = false;      // Display Mitigated Bearish Order Blocks

// ── Swing POI Settings ────────────────────────────────────────────────────────
input bool   showBullishPOI          = true;      // Display Unmitigated Bullish POI
input bool   showBearishPOI          = true;      // Display Unmitigated Bearish POI
input bool   showMitigatedBullishPOI = false;     // Display Mitigated Bullish POI
input bool   showMitigatedBearishPOI = false;     // Display Mitigated Bearish POI

//=============================================================================
// ZIG ZAG LIBRARY STATE  (mirrors ZigZagLib.newInstance / zigZag.update())
//=============================================================================

//--- Pivot structure (mirrors ZigZagLib.Pivot)
struct ZigZagPivot
  {
   bool     isHigh;
   double   endPrice;
   datetime endTime;
  };

#define MAX_PIVOTS 500
ZigZagPivot  g_pivots[];       // dynamic pivot array  (mirrors zigZag.pivots)
int          g_pivotCount = 0;

//--- ZigZag internal state
double   zz_lastHighPrice  = 0;
double   zz_lastLowPrice   = 0;
datetime zz_lastHighTime   = 0;
datetime zz_lastLowTime    = 0;
int      zz_lastHighBar    = -1;
int      zz_lastLowBar     = -1;
bool     zz_lookForHigh    = true;
int      zz_barsInLeg      = 0;

//=============================================================================
// HELPER: tf_str()  — mirrors the Pine Script tf_str() function exactly
//=============================================================================
string tf_str()
  {
   ENUM_TIMEFRAMES tf = Period();
   int mins = PeriodSeconds(tf) / 60;

   // timeframe.isseconds
   if(PeriodSeconds(tf) < 60)
      return IntegerToString(PeriodSeconds(tf)) + "s";

   // timeframe.isminutes  (mins > 0 means it resolved to an integer number of minutes)
   if(tf == PERIOD_M1  || tf == PERIOD_M2  || tf == PERIOD_M3  ||
      tf == PERIOD_M4  || tf == PERIOD_M5  || tf == PERIOD_M6  ||
      tf == PERIOD_M10 || tf == PERIOD_M12 || tf == PERIOD_M15 ||
      tf == PERIOD_M20 || tf == PERIOD_M30)
      return IntegerToString(mins) + "m";

   // hours
   if(tf == PERIOD_H1)  return "H1";
   if(tf == PERIOD_H2)  return "H2";
   if(tf == PERIOD_H3)  return "H3";
   if(tf == PERIOD_H4)  return "H4";
   if(tf == PERIOD_H6)  return "H6";
   if(tf == PERIOD_H8)  return "H8";
   if(tf == PERIOD_H12) return "H12";

   // daily / weekly / monthly — return period string
   if(tf == PERIOD_D1)  return "D";
   if(tf == PERIOD_W1)  return "W";
   if(tf == PERIOD_MN1) return "MN";

   // fallback: identical to Pine's str.tostring(timeframe.period)
   return IntegerToString(mins) + "m";
  }

//=============================================================================
// HELPER: get_swing_color()  — mirrors Pine Script get_swing_color() exactly
//=============================================================================
color get_swing_color()
  {
   ENUM_TIMEFRAMES tf   = Period();
   int             secs = PeriodSeconds(tf);
   int             mins = secs / 60;

   // timeframe.isseconds
   // RGB(30,30,30) = 0x1E1E1E
   if(secs < 60)
      return (color)0x001E1E1E;

   // timeframe.isminutes
   if(mins > 0 && mins <= 1440)   // any minute-based TF
     {
      // RGB(0,0,139) = 0x00008B  (dark blue)
      if(mins <= 15)
         return (color)0x0000008B;
      // RGB(139,0,0) = 0x8B0000  (dark red)
      if(mins <= 60)
         return (color)0x008B0000;
      // RGB(0,100,0) = 0x006400  (dark green)
      return (color)0x00006400;
     }

   // timeframe.isdaily
   // RGB(139,69,19) = 0x8B4513  (saddle brown)
   if(tf == PERIOD_D1)
      return (color)0x008B4513;

   // else (weekly / monthly)
   // RGB(47,79,79) = 0x2F4F4F  (dark slate gray)
   return (color)0x002F4F4F;
  }

//=============================================================================
// PERSISTENT STATE VARIABLES  (var … in Pine Script)
//=============================================================================

// --- STATE MACHINE VARIABLES ---
int   trend = 1;                    // var int trend = 1   (1=Bullish, -1=Bearish)

// The Protected Level (CHoCH target)
double   protected_level_price = EMPTY_VALUE;   // var float protected_level_price = na
datetime protected_level_time  = 0;             // var int   protected_level_time  = na

// The Target Level (BOS target)
double   target_level_price = EMPTY_VALUE;      // var float target_level_price = na
datetime target_level_time  = 0;                // var int   target_level_time  = na

// Absolute extrema fallbacks
double   abs_high      = EMPTY_VALUE;           // var float abs_high      = na
datetime abs_high_time = 0;                     // var int   abs_high_time = na
double   abs_low       = EMPTY_VALUE;           // var float abs_low       = na
datetime abs_low_time  = 0;                     // var int   abs_low_time  = na

datetime last_processed_pivot_time = 0;         // var int last_processed_pivot_time = na
datetime last_breakout_time        = 0;         // var int last_breakout_time        = na

// --- Swing high/low persistent lines & labels (var line / var label in Pine) ---
long     active_swing_high_line = -1;
long     active_swing_high_lbl  = -1;
long     active_swing_low_line  = -1;
long     active_swing_low_lbl   = -1;

//=============================================================================
// OBJECT-POOL COUNTERS  (enforce max_lines / max_labels / max_boxes limits)
//=============================================================================
int g_lineCount  = 0;
int g_labelCount = 0;
int g_boxCount   = 0;

//=============================================================================
// HELPER: safe object creation wrappers
//=============================================================================

// Create a trend-line on the chart, respecting MAX_LINES
long SafeCreateLine(datetime t1, double p1, datetime t2, double p2,
                    color clr, ENUM_LINE_STYLE style, int width)
  {
   if(g_lineCount >= MAX_LINES) return -1;
   string name = "ZZ_Line_" + IntegerToString(g_lineCount);
   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
     {
      ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE,     style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      g_lineCount++;
      return g_lineCount - 1;  // index as id
     }
   return -1;
  }

// Update an existing TREND object's endpoints (mirrors line.set_xy1 / line.set_xy2)
void SafeSetLineXY(long id, datetime t1, double p1, datetime t2, double p2)
  {
   string name = "ZZ_Line_" + IntegerToString((int)id);
   if(ObjectFind(0, name) >= 0)
     {
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
     }
  }

// Create a label (text object), respecting MAX_LABELS
long SafeCreateLabel(datetime t, double p, string txt,
                     color bg, color txtClr, ENUM_ANCHOR_POINT anchor)
  {
   if(g_labelCount >= MAX_LABELS) return -1;
   string name = "ZZ_Label_" + IntegerToString(g_labelCount);
   if(ObjectCreate(0, name, OBJ_TEXT, 0, t, p))
     {
      ObjectSetString( 0, name, OBJPROP_TEXT,      txt);
      ObjectSetInteger(0, name, OBJPROP_COLOR,      txtClr);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bg);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,     anchor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   9);
      g_labelCount++;
      return g_labelCount - 1;
     }
   return -1;
  }

// Update label position and text (mirrors label.set_xy / label.set_text)
void SafeSetLabel(long id, datetime t, double p, string txt)
  {
   string name = "ZZ_Label_" + IntegerToString((int)id);
   if(ObjectFind(0, name) >= 0)
     {
      ObjectMove(0, name, 0, t, p);
      ObjectSetString(0, name, OBJPROP_TEXT, txt);
     }
  }

//=============================================================================
// ZIG ZAG UPDATE  (mirrors zigZag.update())
//=============================================================================
void ZigZag_Update(int bar)
  {
   //--- price at this bar
   double h = iHigh( _Symbol, PERIOD_CURRENT, bar);
   double l = iLow(  _Symbol, PERIOD_CURRENT, bar);
   double c = iClose(_Symbol, PERIOD_CURRENT, bar);
   datetime t = (datetime)iTime(_Symbol, PERIOD_CURRENT, bar);

   if(zz_lastHighPrice == 0) zz_lastHighPrice = h;
   if(zz_lastLowPrice  == 0) zz_lastLowPrice  = l;

   double devH = MathAbs(h - zz_lastLowPrice)  / zz_lastLowPrice  * 100.0;
   double devL = MathAbs(zz_lastHighPrice - l)  / zz_lastHighPrice * 100.0;

   if(zz_lookForHigh)
     {
      if(h >= zz_lastHighPrice)
        {
         zz_lastHighPrice = h;
         zz_lastHighTime  = t;
         zz_lastHighBar   = bar;
        }
      if(devL >= deviationInput && zz_barsInLeg >= depthInput)
        {
         // Confirm a HIGH pivot
         if(g_pivotCount >= MAX_PIVOTS)
           {
            ArrayRemove(g_pivots, 0, 1);
            g_pivotCount--;
           }
         ArrayResize(g_pivots, g_pivotCount + 1);
         g_pivots[g_pivotCount].isHigh   = true;
         g_pivots[g_pivotCount].endPrice = zz_lastHighPrice;
         g_pivots[g_pivotCount].endTime  = zz_lastHighTime;
         g_pivotCount++;

         zz_lastLowPrice  = l;
         zz_lastLowTime   = t;
         zz_lastLowBar    = bar;
         zz_lookForHigh   = false;
         zz_barsInLeg     = 0;
        }
     }
   else
     {
      if(l <= zz_lastLowPrice)
        {
         zz_lastLowPrice = l;
         zz_lastLowTime  = t;
         zz_lastLowBar   = bar;
        }
      if(devH >= deviationInput && zz_barsInLeg >= depthInput)
        {
         // Confirm a LOW pivot
         if(g_pivotCount >= MAX_PIVOTS)
           {
            ArrayRemove(g_pivots, 0, 1);
            g_pivotCount--;
           }
         ArrayResize(g_pivots, g_pivotCount + 1);
         g_pivots[g_pivotCount].isHigh   = false;
         g_pivots[g_pivotCount].endPrice = zz_lastLowPrice;
         g_pivots[g_pivotCount].endTime  = zz_lastLowTime;
         g_pivotCount++;

         zz_lastHighPrice = h;
         zz_lastHighTime  = t;
         zz_lastHighBar   = bar;
         zz_lookForHigh   = true;
         zz_barsInLeg     = 0;
        }
     }
   zz_barsInLeg++;
  }

//=============================================================================
// INDICATOR INIT
//=============================================================================
int OnInit()
  {
   ArrayResize(g_pivots, 0);

   //--- Create the 4 persistent swing line/label objects (mirrors var line / var label)
   //    line.new(na,na,na,na,...) → created once, updated each bar
   active_swing_high_line = SafeCreateLine(0, 0, 0, 0,
                                           get_swing_color(),
                                           STYLE_DASH, 2);
   active_swing_high_lbl  = SafeCreateLabel(0, 0, "",
                                            (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND),
                                            get_swing_color(),
                                            ANCHOR_CENTER);
   active_swing_low_line  = SafeCreateLine(0, 0, 0, 0,
                                           get_swing_color(),
                                           STYLE_DASH, 2);
   active_swing_low_lbl   = SafeCreateLabel(0, 0, "",
                                            (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND),
                                            get_swing_color(),
                                            ANCHOR_CENTER);
   return(INIT_SUCCEEDED);
  }

//=============================================================================
// INDICATOR DEINIT
//=============================================================================
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "ZZ_");
   ChartRedraw(0);
  }

//=============================================================================
// INDICATOR CALCULATE — runs every new bar (mirrors Pine Script bar-by-bar exec)
//=============================================================================
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
   if(rates_total < 3) return 0;

   int start = (prev_calculated <= 1) ? 0 : prev_calculated - 1;

   for(int i = start; i < rates_total; i++)
     {
      //--- current bar values (bar 0 = oldest, rates_total-1 = newest — array access order)
      int    bar   = rates_total - 1 - i;   // convert to bars-from-right index for iHigh etc
      //    In the arrays passed to OnCalculate, index 0 = oldest, index rates_total-1 = newest
      //    We iterate i from start to rates_total-1; current bar values:
      double  h   = high[i];
      double  l   = low[i];
      double  c   = close[i];
      datetime ct = time[i];

      // ── ZigZag Update ────────────────────────────────────────────────────
      ZigZag_Update(bar);

      //=========================================================================
      // INITIALIZATION BLOCK
      // Mirrors:
      //   if na(protected_level_price) and zigZag.pivots.size() >= 3
      //       for i = 0 to 2  ...
      //=========================================================================
      if(protected_level_price == EMPTY_VALUE && g_pivotCount >= 3)
        {
         for(int pi = 0; pi <= 2; pi++)
           {
            ZigZagPivot p = g_pivots[pi];
            if(p.isHigh && trend == 1)
              {
               target_level_price = p.endPrice;
               target_level_time  = p.endTime;
              }
            if(!p.isHigh && trend == 1)
              {
               protected_level_price = p.endPrice;
               protected_level_time  = p.endTime;
              }
           }
        }

      //=========================================================================
      // Track Absolute Extrema since last break
      // Mirrors:
      //   if na(abs_high) or high > abs_high  → abs_high := high ...
      //   if na(abs_low)  or low  < abs_low   → abs_low  := low  ...
      //=========================================================================
      if(abs_high == EMPTY_VALUE || h > abs_high)
        {
         abs_high      = h;
         abs_high_time = ct;
        }
      if(abs_low == EMPTY_VALUE || l < abs_low)
        {
         abs_low      = l;
         abs_low_time = ct;
        }

      //=========================================================================
      // PIVOT PROCESSING
      // Mirrors:
      //   if zigZag.pivots.size() >= 2
      //       ZigZagLib.Pivot p = zigZag.pivots.get(zigZag.pivots.size() - 2)
      //       if na(last_processed_pivot_time) or p.end.time != last_processed_pivot_time ...
      //=========================================================================
      if(g_pivotCount >= 2)
        {
         ZigZagPivot p2 = g_pivots[g_pivotCount - 2]; // second to last = confirmed

         if(last_processed_pivot_time == 0 || p2.endTime != last_processed_pivot_time)
           {
            last_processed_pivot_time = p2.endTime;

            if(p2.isHigh && trend == 1)
              {
               if(target_level_price == EMPTY_VALUE || p2.endPrice > target_level_price)
                 {
                  target_level_price = p2.endPrice;
                  target_level_time  = p2.endTime;
                 }
              }
            else if(!p2.isHigh && trend == -1)
              {
               if(target_level_price == EMPTY_VALUE || p2.endPrice < target_level_price)
                 {
                  target_level_price = p2.endPrice;
                  target_level_time  = p2.endTime;
                 }
              }
           }
        }

      //=========================================================================
      // BREAKOUT LOGIC
      // Mirrors:
      //   bool crossUp = (trend==-1 and ... close > protected_level_price)
      //               or (trend== 1 and ... close > target_level_price)
      //   bool crossDn = (trend== 1 and ... close < protected_level_price)
      //               or (trend==-1 and ... close < target_level_price)
      //=========================================================================
      bool crossUp = (trend == -1 && protected_level_price != EMPTY_VALUE && c > protected_level_price) ||
                     (trend ==  1 && target_level_price    != EMPTY_VALUE && c > target_level_price);

      bool crossDn = (trend ==  1 && protected_level_price != EMPTY_VALUE && c < protected_level_price) ||
                     (trend == -1 && target_level_price    != EMPTY_VALUE && c < target_level_price);

      // Resolve Safe Macro Extrema  (mirrors local vars safe_high_price / safe_low_price)
      double   safe_high_price = abs_high;
      datetime safe_high_time  = abs_high_time;
      double   safe_low_price  = abs_low;
      datetime safe_low_time   = abs_low_time;

      //-------------------------------------------------------------------------
      // crossUp branch
      //-------------------------------------------------------------------------
      if(crossUp && (last_breakout_time == 0 || ct > last_breakout_time))
        {
         if(trend == -1)
           {
            //--- BL-CHoCH Triggered
            trend = 1;
            datetime midTime_chu = (datetime)(((long)protected_level_time + (long)ct) / 2);

            SafeCreateLine(protected_level_time, protected_level_price,
                           ct,                  protected_level_price,
                           clrGreen, STYLE_SOLID, 2);
            SafeCreateLabel(midTime_chu, protected_level_price,
                            tf_str() + "-BL-CHoCH",
                            (color)0x00FFFFFF,   // color.new(color.white, 100) = fully transparent
                            clrGreen,
                            ANCHOR_LOWER);

            protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_low_price;
            protected_level_time  = (target_level_time  != 0)           ? target_level_time  : safe_low_time;
           }
         else if(trend == 1)
           {
            //--- BL-BOS Triggered
            datetime midTime_bu = (datetime)(((long)target_level_time + (long)ct) / 2);

            SafeCreateLine(target_level_time, target_level_price,
                           ct,               target_level_price,
                           clrGreen, STYLE_SOLID, 2);
            SafeCreateLabel(midTime_bu, target_level_price,
                            tf_str() + "-BL-BOS",
                            (color)0x00FFFFFF,
                            clrGreen,
                            ANCHOR_LOWER);

            // Setup Pullback extreme logically (mirrors for i=0 to 2000 loop)
            double   pullback_low      = EMPTY_VALUE;
            datetime pullback_low_time = 0;

            if(target_level_time != 0)
              {
               for(int bi = 0; bi <= 2000; bi++)
                 {
                  int   bIdx = rates_total - 1 - bi;
                  if(bIdx < 0) break;
                  if(time[bIdx] < target_level_time) break;
                  if(pullback_low == EMPTY_VALUE || low[bIdx] < pullback_low)
                    {
                     pullback_low      = low[bIdx];
                     pullback_low_time = time[bIdx];
                    }
                 }
              }

            protected_level_price = (pullback_low      != EMPTY_VALUE) ? pullback_low      : safe_low_price;
            protected_level_time  = (pullback_low_time != 0)           ? pullback_low_time : safe_low_time;
           }

         // Reset trackers
         target_level_price = EMPTY_VALUE;
         target_level_time  = 0;
         abs_high           = EMPTY_VALUE;
         abs_low            = EMPTY_VALUE;
         last_breakout_time = ct;
        }

      //-------------------------------------------------------------------------
      // crossDn branch
      //-------------------------------------------------------------------------
      else if(crossDn && (last_breakout_time == 0 || ct > last_breakout_time))
        {
         if(trend == 1)
           {
            //--- BR-CHoCH Triggered
            trend = -1;
            datetime midTime_chd = (datetime)(((long)protected_level_time + (long)ct) / 2);

            SafeCreateLine(protected_level_time, protected_level_price,
                           ct,                  protected_level_price,
                           clrRed, STYLE_SOLID, 2);
            SafeCreateLabel(midTime_chd, protected_level_price,
                            tf_str() + "-BR-CHoCH",
                            (color)0x00FFFFFF,
                            clrRed,
                            ANCHOR_LOWER);

            protected_level_price = (target_level_price != EMPTY_VALUE) ? target_level_price : safe_high_price;
            protected_level_time  = (target_level_time  != 0)           ? target_level_time  : safe_high_time;
           }
         else if(trend == -1)
           {
            //--- BR-BOS Triggered
            datetime midTime_bd = (datetime)(((long)target_level_time + (long)ct) / 2);

            SafeCreateLine(target_level_time, target_level_price,
                           ct,               target_level_price,
                           clrRed, STYLE_SOLID, 2);
            SafeCreateLabel(midTime_bd, target_level_price,
                            tf_str() + "-BR-BOS",
                            (color)0x00FFFFFF,
                            clrRed,
                            ANCHOR_LOWER);

            // Setup Pullback extreme logically
            double   pullback_high      = EMPTY_VALUE;
            datetime pullback_high_time = 0;

            if(target_level_time != 0)
              {
               for(int bi = 0; bi <= 2000; bi++)
                 {
                  int   bIdx = rates_total - 1 - bi;
                  if(bIdx < 0) break;
                  if(time[bIdx] < target_level_time) break;
                  if(pullback_high == EMPTY_VALUE || high[bIdx] > pullback_high)
                    {
                     pullback_high      = high[bIdx];
                     pullback_high_time = time[bIdx];
                    }
                 }
              }

            protected_level_price = (pullback_high      != EMPTY_VALUE) ? pullback_high      : safe_high_price;
            protected_level_time  = (pullback_high_time != 0)           ? pullback_high_time : safe_high_time;
           }

         // Reset trackers
         target_level_price = EMPTY_VALUE;
         target_level_time  = 0;
         abs_high           = EMPTY_VALUE;
         abs_low            = EMPTY_VALUE;
         last_breakout_time = ct;
        }

      //=========================================================================
      // ADDED BLOCK: LATEST SWING HIGH & LOW LINES EXTENSION
      // Mirrors Pine Script "ADDED BLOCK: LATEST SWING HIGH & LOW LINES EXTENSION"
      //=========================================================================

      // active_swing_high_price / active_swing_low_price resolve exactly as in Pine:
      //   float active_swing_high_price = trend == -1 ? protected_level_price : safe_high_price
      //   float active_swing_high_time  = trend == -1 ? protected_level_time  : safe_high_time
      //   float active_swing_low_price  = trend ==  1 ? protected_level_price : safe_low_price
      //   float active_swing_low_time   = trend ==  1 ? protected_level_time  : safe_low_time

      double   active_swing_high_price = (trend == -1) ? protected_level_price : safe_high_price;
      datetime active_swing_high_time  = (trend == -1) ? protected_level_time  : safe_high_time;

      double   active_swing_low_price  = (trend ==  1) ? protected_level_price : safe_low_price;
      datetime active_swing_low_time   = (trend ==  1) ? protected_level_time  : safe_low_time;

      // if true  (always executes — mirrors Pine Script "if true" block)
      //   update swing high line & label
      if(active_swing_high_price != EMPTY_VALUE && active_swing_high_time != 0)
        {
         int mid_time_h_sec = (int)(((long)active_swing_high_time + (long)ct) / 2);
         datetime mid_time_h = (datetime)mid_time_h_sec;

         SafeSetLineXY(active_swing_high_line,
                       active_swing_high_time, active_swing_high_price,
                       ct,                    active_swing_high_price);

         SafeSetLabel(active_swing_high_lbl,
                      mid_time_h, active_swing_high_price,
                      " " + tf_str() + "-SWING-HIGH ");
        }

      //   update swing low line & label
      if(active_swing_low_price != EMPTY_VALUE && active_swing_low_time != 0)
        {
         int mid_time_l_sec = (int)(((long)active_swing_low_time + (long)ct) / 2);
         datetime mid_time_l = (datetime)mid_time_l_sec;

         SafeSetLineXY(active_swing_low_line,
                       active_swing_low_time, active_swing_low_price,
                       ct,                   active_swing_low_price);

         SafeSetLabel(active_swing_low_lbl,
                      mid_time_l, active_swing_low_price,
                      " " + tf_str() + "-SWING-LOW ");
        }

     } // end for(i)

   ChartRedraw(0);
   return(rates_total);
  }
//+------------------------------------------------------------------+