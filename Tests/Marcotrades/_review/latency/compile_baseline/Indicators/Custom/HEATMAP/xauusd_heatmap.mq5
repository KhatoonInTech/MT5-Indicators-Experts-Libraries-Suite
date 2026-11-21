#define MARCO_LOG_PROGRAM "xauusd_heatmap"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                     xauusd_heatmap.mq5           |
//|                        Copyright 2026, Industrial MQL5 Architect |
//|                                          Main Indicator File     |
//+------------------------------------------------------------------+
#property copyright "AI Collaborator"
#property version   "2.10"
#property indicator_chart_window
#property indicator_plots 0

// --- INCLUDE THE LOGIC CORE ---
// Ensure the path matches exactly where you saved File 1
#include <General\xauusd_heatmap.mqh>

// --- USER INPUTS ---
input group "Visual Settings"
input color    InpColorHot       = clrOrangeRed; // Whale Wall Color
input color    InpColorCold      = clrNavy;      // Retail Order Color
input int      InpUpdateSpeed    = 100;          // Refresh ms (Lower = Smoother, Higher = Fast CPU)

input group "Data Logic"
input int      InpWhaleThreshold = 50;           // Lots required to be a "Whale"
input bool     InpDetectSpoof    = true;         // Enable Spoof Detection Logic

// --- GLOBAL ENGINE INSTANCE ---
CHeatmapEngine ExtHeatmap;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization Function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   g_marcoDailyLog.Start();
   if(!ExtHeatmap.Initialize(_Symbol, InpColorHot, InpColorCold, InpWhaleThreshold, InpUpdateSpeed, InpDetectSpoof))
   {
      return(INIT_FAILED);
   }
   
   // ADD THIS: Force updates every 100ms even if broker is silent
   EventSetMillisecondTimer(100); 
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization Function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   ExtHeatmap.Deinit();
}

//+------------------------------------------------------------------+
//| Book Event: The Heartbeat of the Heatmap                         |
//+------------------------------------------------------------------+
void OnMarketBookEvent(const string &symbol)
{
   if(symbol == _Symbol)
   {
      ExtHeatmap.OnBookEvent();
   }
}

//+------------------------------------------------------------------+
//| Chart Event: Handle Resizing                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   g_marcoDailyLog.Pulse();
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ExtHeatmap.OnChartResize();
   }
}

//+------------------------------------------------------------------+
//| Main Iteration (Required for Indicators)                         |
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
   // Keep alive
   return(rates_total);
}

// END FILE: Indicators\Custom\HEATMAP\xauusd_heatmap.mq5

// END FILE: Indicators\Custom\HEATMAP\xauusd_heatmap.mq5
