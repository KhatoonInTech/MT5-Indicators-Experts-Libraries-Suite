#define MARCO_LOG_PROGRAM "Test_MarketStructure"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                        Test_MarketStructure.mq5  |
//|               Minimal Indicator to test the 3 core libraries     |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Custom\ZigZag\market_structure.mqh>

// =============================================================================
// USER INPUTS 
// =============================================================================
input group "Visibility"
input bool   showZigZagInput          = true;         // Show Zig Zag Lines
input bool   showBosChochInput        = true;         // Show BOS & CHoCH
input bool   showSwingHLInput         = true;         // Show Latest Swing H/L

input group "Zig Zag Settings"
input double deviationInput           = 1;         // Price deviation for reversals (%)
input int    depthInput               = 15;            // Pivot legs
input color  lineColorInput           = clrGold;      // Line color
input bool   extendInput              = true;         // Extend to last bar
input bool   showPriceInput           = true;         // Display reversal price
input bool   showVolInput             = true;         // Display cumulative volume
input bool   showChgInput             = true;         // Display reversal price change
input string priceDiffInput           = "Percent";   // Difference Mode (Absolute/Percent)
input group "Performance"
input int maxLookbackBars = 3000; // Max Historical Bars to Calculate
// =============================================================================
// GLOBALS & POINTERS
// =============================================================================
ZigZag* zigZag = NULL;
CMarketStructure* mkStruct = NULL;

// =============================================================================
// INITIALIZATION
// =============================================================================
int OnInit() {
   g_marcoDailyLog.Start();
    // 1. Initialize ZigZag Engine
    Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, 
                               showZigZagInput ? showPriceInput : false, 
                               showZigZagInput ? showVolInput : false, 
                               showZigZagInput ? showChgInput : false, 
                               priceDiffInput);
    s.draw = showZigZagInput;
    zigZag = newInstance(s);
    
    // 2. Initialize Market Structure Engine (which uses mql_plotting.mqh internally)
    mkStruct = new CMarketStructure();
    mkStruct.Init(showBosChochInput, showSwingHLInput);

    return(INIT_SUCCEEDED);
}

// =============================================================================
// DEINITIALIZATION
// =============================================================================
void OnDeinit(const int reason) {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
    // Calling delete triggers the destructors which clean up objects gracefully
    if(zigZag != NULL) delete zigZag;
    if(mkStruct != NULL) delete mkStruct;
    
    // Clean up base ZigZag UI components
    ObjectsDeleteAll(0, "ZZ_Ln_"); 
    ObjectsDeleteAll(0, "ZZ_Lbl_"); 
    ObjectsDeleteAll(0, "ZZ_Proj_");
}

// =============================================================================
// MAIN CALCULATION
// =============================================================================
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], 
                const double &open[], const double &high[], const double &low[], 
                const double &close[], const long &tick_volume[], const long &volume[], 
                const int &spread[]) {
   g_marcoDailyLog.Pulse();
                    
    if(rates_total < depthInput * 2) return 0;
    
    if(prev_calculated == 0) {
        if(mkStruct != NULL) mkStruct.ResetState();
    }

    // Ensure we don't calculate further back than maxLookbackBars
    int start_bar = 0;
    if(rates_total > maxLookbackBars) start_bar = rates_total - maxLookbackBars;

    int start = (prev_calculated > 0) ? prev_calculated - 1 : start_bar;
    for(int i = start; i < rates_total; i++) {
        bool is_last = (i == rates_total - 1);
        
        // 1. Update core ZigZag Engine
        zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);

        // 2. Update Market Structure Engine 
        // This calculates BOS/CHoCH/Swings and uses mql_plotting.mqh to draw them
        mkStruct.Update(i, time, high, low, close, zigZag);
    }
    
    return rates_total;
}

// END FILE: Indicators\Custom\ZigZag\Test_MarketStructure.mq5

// END FILE: Indicators\Custom\ZigZag\Test_MarketStructure.mq5
