#define MARCO_LOG_PROGRAM "ZigZag"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                                       Custom\ZigZag\.mq5 |
//|                                 Copyright 2026, MetaTrader User  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Include the custom library we created
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"

//--- Input parameters
input double   deviationInput = 5.0;   // Price deviation for reversals (%)
input int      depthInput     = 10;    // Pivot legs
input color    lineColorInput = clrWhiteSmoke; // Line color
input bool     extendInput    = true;  // Extend to last bar
input bool     showPriceInput = true;  // Display reversal price
input bool     showVolInput   = true;  // Display cumulative volume
input bool     showChgInput   = true;  // Display reversal price change
input string   priceDiffInput = "Absolute"; // Difference Mode (Absolute/Percent)

//--- Global pointer for the ZigZag object 
ZigZag* zigZag = NULL;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   g_marcoDailyLog.Start();
    Settings* s = new Settings(
        deviationInput, 
        depthInput, 
        lineColorInput, 
        extendInput, 
        showPriceInput, 
        showVolInput, 
        showChgInput, 
        priceDiffInput
    );
    
    zigZag = newInstance(s);
    
    ObjectsDeleteAll(0, "ZZ_Ln_");
    ObjectsDeleteAll(0, "ZZ_Lbl_");
    ObjectsDeleteAll(0, "ZZ_Proj_");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
    if(zigZag != NULL) 
    {
        delete zigZag;
    }
    ObjectsDeleteAll(0, "ZZ_Ln_");
    ObjectsDeleteAll(0, "ZZ_Lbl_");
    ObjectsDeleteAll(0, "ZZ_Proj_");
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
   g_marcoDailyLog.Pulse();
    if(rates_total < depthInput * 2) return 0;

    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
    
    for(int i = start; i < rates_total; i++)
    {
        bool is_last = (i == rates_total - 1);
        
        zigZag.update(
            high[i], 
            low[i], 
            time[i], 
            volume[i], 
            i, 
            !is_last,   // TRUE for history, FALSE for the last real-time bar
            is_last
        );
    }
   
    return(rates_total);
} 

// END FILE: Indicators\Custom\ZigZag\ZigZag.mq5

// END FILE: Indicators\Custom\ZigZag\ZigZag.mq5
