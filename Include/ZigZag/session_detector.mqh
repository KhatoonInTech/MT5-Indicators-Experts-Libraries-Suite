//+------------------------------------------------------------------+
//|                               Include\ZigZag\session_detector.mqh|
//|                       Centralized Session Detection & Plotting   |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.00"

#ifndef SESSION_DETECTOR_MQH
#define SESSION_DETECTOR_MQH

#include <ZigZag\mql_plotting.mqh>

class CSessionDetector {
private:
    // Settings
    bool   m_showLon;
    bool   m_showNY;
    bool   m_showDaySep;
    bool   m_useLabels;
    string m_lonTime;
    string m_nyTime;

    // Dynamic Tracking Objects
    PineBox* m_lonBoxes[];
    PineBox* m_nyBoxes[];

    // Internal helper to parse session string (HHMM-HHMM)
    bool IsInSession(datetime time, string session) {
        int start = (int)StringToInteger(StringSubstr(session, 0, 4));
        int end   = (int)StringToInteger(StringSubstr(session, 5, 4));
        
        MqlDateTime dt;
        TimeToStruct(time, dt);
        int current = dt.hour * 100 + dt.min;
        
        if(start < end) return (current >= start && current < end);
        return (current >= start || current < end);
    }

public:
    CSessionDetector() {}
    
    ~CSessionDetector() {
        Cleanup();
    }

    // Initialize the library with user inputs
    void Init(bool showLon, bool showNY, bool showDaySep, bool useLabels, string lonTime, string nyTime) {
        m_showLon    = showLon;
        m_showNY     = showNY;
        m_showDaySep = showDaySep;
        m_useLabels  = useLabels;
        m_lonTime    = lonTime;
        m_nyTime     = nyTime;
    }

    // Safely free memory from dynamic box objects
    void Cleanup() {
        for(int i = 0; i < ArraySize(m_lonBoxes); i++) {
            if(CheckPointer(m_lonBoxes[i]) != POINTER_INVALID) delete m_lonBoxes[i];
        }
        for(int i = 0; i < ArraySize(m_nyBoxes); i++) {
            if(CheckPointer(m_nyBoxes[i]) != POINTER_INVALID) delete m_nyBoxes[i];
        }
        ArrayResize(m_lonBoxes, 0);
        ArrayResize(m_nyBoxes, 0);
    }

    // Main processing loop per bar
    void ProcessBar(datetime t_current, datetime t_prev, double high, double low, double point_val, int period_seconds) {
        // 1. Detect New Day
        bool newDay = false;
        if(t_prev > 0) {
            MqlDateTime dt, dt_prev;
            TimeToStruct(t_current, dt);
            TimeToStruct(t_prev, dt_prev);
            newDay = (dt.day != dt_prev.day);
        }

        // 2. Session Calculation
        bool inLondon      = IsInSession(t_current, m_lonTime);
        bool inNY          = IsInSession(t_current, m_nyTime);
        
        bool inLondon_prev = (t_prev > 0) ? IsInSession(t_prev, m_lonTime) : false;
        bool inNY_prev     = (t_prev > 0) ? IsInSession(t_prev, m_nyTime) : false;

        bool isLonStart    = inLondon && !inLondon_prev;
        bool isNYStart     = inNY && !inNY_prev;

        // --- DRAWING ---
        
        // 1. Day Separator Lines
        if(newDay && m_showDaySep) {
            Plotter::DrawLine("DaySep_" + TimeToString(t_current), 
                              t_current, high + 1000 * point_val, 
                              t_current, low - 1000 * point_val, 
                              clrGray, STYLE_SOLID, 1, false);
        }

        // 2. Background Highlights (London)
        if(m_showLon) {
            if(isLonStart) {
                string boxName = "LonBG_" + TimeToString(t_current);
                int size = ArraySize(m_lonBoxes);
                bool exists = (size > 0 && m_lonBoxes[size-1].id == boxName);
                
                if(!exists) {
                    PineBox* b = new PineBox(boxName);
                    b.set_bounds(t_current, 100000.0, t_current + period_seconds, 0.0);
                    b.set_bgcolor(clrDeepSkyBlue, 50);
                    
                    ArrayResize(m_lonBoxes, size + 1);
                    m_lonBoxes[size] = b;
                } else {
                    m_lonBoxes[size-1].set_right(t_current + period_seconds);
                }
            } else if (inLondon) {
                int size = ArraySize(m_lonBoxes);
                if(size > 0) m_lonBoxes[size-1].set_right(t_current + period_seconds);
            }
        }

        // 2. Background Highlights (NY)
        if(m_showNY) {
            if(isNYStart) {
                string boxName = "NYBG_" + TimeToString(t_current);
                int size = ArraySize(m_nyBoxes);
                bool exists = (size > 0 && m_nyBoxes[size-1].id == boxName);
                
                if(!exists) {
                    PineBox* b = new PineBox(boxName);
                    b.set_bounds(t_current, 100000.0, t_current + period_seconds, 0.0);
                    b.set_bgcolor(clrOrange, 50);
                    
                    ArrayResize(m_nyBoxes, size + 1);
                    m_nyBoxes[size] = b;
                } else {
                    m_nyBoxes[size-1].set_right(t_current + period_seconds);
                }
            } else if (inNY) {
                int size = ArraySize(m_nyBoxes);
                if(size > 0) m_nyBoxes[size-1].set_right(t_current + period_seconds);
            }
        }

        // 3. Labels
        if(m_useLabels && m_showLon && isLonStart) {
            Plotter::DrawLabel("LonLbl_" + TimeToString(t_current), 
                               t_current, high, "LONDON", 
                               clrNavy, ANCHOR_LOWER, 8);
        }

        if(m_useLabels && m_showNY && isNYStart) {
            Plotter::DrawLabel("NYLbl_" + TimeToString(t_current), 
                               t_current, high, "NEW YORK", 
                               clrDarkOrange, ANCHOR_LOWER, 8);
        }
    }
};

#endif

