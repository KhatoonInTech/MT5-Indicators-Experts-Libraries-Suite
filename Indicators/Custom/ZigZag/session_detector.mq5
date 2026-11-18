//+------------------------------------------------------------------+
//|                           Indicators\ZigZag\session_detector.mq5 |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <ZigZag\session_detector.mqh>

// --- SETTINGS / INPUTS ---
input group "Visibility Settings"
input bool   showLon    = true;  // Show London Session
input bool   showNY     = true;  // Show NY Session
input bool   showDaySep = true;  // Show Day Separator Line
input bool   useLabels  = true;  // Show Session Labels

input group "Session Time (UTC+2/3 Typical)"
input string lonTime = "0800-1200"; // London Session Time
input string nyTime  = "1200-1600"; // NY Session Time

// --- GLOBALS ---
CSessionDetector detector;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // Pass user inputs to the library
    detector.Init(showLon, showNY, showDaySep, useLabels, lonTime, nyTime);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Triggers cleanup in the library
    detector.Cleanup();
     // Add these lines to force-delete the leftover tags:
    ObjectsDeleteAll(0, "NYLbl"); 
    ObjectsDeleteAll(0, "LonLbl");
    ObjectsDeleteAll(0, "DaySep_");
    
    ChartRedraw(0); // Refreshes the chart to clear the ghost images

}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    int limit = (prev_calculated == 0) ? 0 : prev_calculated - 1;
    int period_seconds = PeriodSeconds();

    for(int i = limit; i < rates_total; i++) {
        datetime t_prev = (i > 0) ? time[i-1] : 0;
        
        // Let the library process logic and rendering
        detector.ProcessBar(time[i], t_prev, high[i], low[i], _Point, period_seconds);
    }

    return(rates_total);
}