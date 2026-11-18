//+------------------------------------------------------------------+
//|                               Include\ZigZag\mql_plotting.mqh    |
//|                       Centralized Plotting & Drawing Library     |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.00"

#include <Object.mqh>
#include <ZigZag\ZigZag.mqh>

// --- Helper for Alpha/Transparency Colors ---
color ColorToARGB_Custom(color c, uchar alpha) { return (color)((alpha << 24) | c); }
color POI_TRANSPARENT = clrNONE;

// =============================================================================
// PLOTTER UTILITY (Lines & Text Labels)
// =============================================================================
class Plotter {
public:
    // Draws or updates a Trendline
    static void DrawLine(string id, datetime t1, double p1, datetime t2, double p2, color clr, int style = STYLE_SOLID, int width = 1, bool rayRight = false) {
        if(ObjectFind(0, id) < 0) {
            ObjectCreate(0, id, OBJ_TREND, 0, t1, p1, t2, p2);
        } else {
            ObjectSetInteger(0, id, OBJPROP_TIME, 0, t1);
            ObjectSetDouble(0, id, OBJPROP_PRICE, 0, p1);
            ObjectSetInteger(0, id, OBJPROP_TIME, 1, t2);
            ObjectSetDouble(0, id, OBJPROP_PRICE, 1, p2);
        }
        ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, id, OBJPROP_STYLE, style);
        ObjectSetInteger(0, id, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, id, OBJPROP_RAY_RIGHT, rayRight);
    }

    // Draws or updates a Text Label
    static void DrawLabel(string id, datetime t, double p, string text, color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LOWER, int fontSize = 8) {
        if(ObjectFind(0, id) < 0) {
            ObjectCreate(0, id, OBJ_TEXT, 0, t, p);
        } else {
            ObjectSetInteger(0, id, OBJPROP_TIME, t);
            ObjectSetDouble(0, id, OBJPROP_PRICE, p);
        }
        ObjectSetString(0, id, OBJPROP_TEXT, text);
        ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, id, OBJPROP_ANCHOR, anchor);
        ObjectSetInteger(0, id, OBJPROP_FONTSIZE, fontSize);
    }
};

// =============================================================================
// PINEBOX CLASS (Rectangles with Center Text)
// =============================================================================
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
            Plotter::DrawLabel(id + "_lbl", midTime, midPrice, text, text_col, ANCHOR_CENTER, 8);
            if(text_col == clrNONE) ObjectSetString(0, id + "_lbl", OBJPROP_TEXT, " ");
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

CMarketMetrics* GetPlottingMetrics() {
    // Plotting isolated component; returns standard populated defaults (bid, ask, vol)
    return new CMarketMetrics();
}
