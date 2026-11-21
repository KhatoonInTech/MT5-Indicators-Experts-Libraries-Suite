#define MARCO_LOG_PROGRAM "Anchored_VWAP"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                                Anchored_VWAP.mq5 |
//|                                  Exact TradingView Replica       |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "1.00"
#property description "Interactive Anchored VWAP with Standard Deviation Bands"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   7

//--- Visual Plots
#property indicator_label1  "Anchored VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "VWAP Upper 1"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_SOLID

#property indicator_label3  "VWAP Lower 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLimeGreen
#property indicator_style3  STYLE_SOLID

#property indicator_label4  "VWAP Upper 2"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOlive
#property indicator_style4  STYLE_SOLID

#property indicator_label5  "VWAP Lower 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOlive
#property indicator_style5  STYLE_SOLID

#property indicator_label6  "VWAP Upper 3"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrTeal
#property indicator_style6  STYLE_SOLID

#property indicator_label7  "VWAP Lower 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrTeal
#property indicator_style7  STYLE_SOLID

// Include Core Logic
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\Anchored_VWAP.mqh"

//--- Input Parameters
input group "=== BANDS SETTINGS ==="
input ENUM_BANDS_MODE    InpBandsMode = BANDS_STDDEV;  // Bands Calculation Mode
input bool               InpShowB1    = false;         // Show Bands Multiplier #1
input double             InpMult1     = 1.0;           // Bands Multiplier #1
input bool               InpShowB2    = false;         // Show Bands Multiplier #2
input double             InpMult2     = 2.0;           // Bands Multiplier #2
input bool               InpShowB3    = false;         // Show Bands Multiplier #3
input double             InpMult3     = 3.0;           // Bands Multiplier #3

input group "=== SOURCE SETTINGS ==="
input ENUM_APPLIED_PRICE InpSource    = PRICE_TYPICAL; // Source (Default: hlc3)
input ENUM_VOL_TYPE      InpVolType   = VOL_TICK;      // Volume Type (Forex=Tick)
input string             InpDotName   = "TV_Anchor";   // Anchor Name

//--- Indicator Buffers
double VWAPBuffer[];
double Up1Buffer[];
double Dn1Buffer[];
double Up2Buffer[];
double Dn2Buffer[];
double Up3Buffer[];
double Dn3Buffer[];

//--- Memory Buffers
double CumVolBuffer[];
double CumPVBuffer[];
double CumP2VBuffer[];

//--- Instance
CAnchoredVWAP VWAP;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
// VWAP and Bands
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, Up1Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, Dn1Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, Up2Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, Dn2Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, Up3Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, Dn3Buffer, INDICATOR_DATA);

// Memory Calculation Buffers
   SetIndexBuffer(7, CumVolBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, CumPVBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, CumP2VBuffer, INDICATOR_CALCULATIONS);

// Set Empty Values
   for(int i = 0; i < 7; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   VWAP.Init(InpDotName, InpBandsMode, InpSource, InpVolType,
             InpShowB1, InpMult1, InpShowB2, InpMult2, InpShowB3, InpMult3);

// Enable real-time mouse tracking to render axis coordinates during dragging
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

// Set 1 second timer for the dot shrinking effect
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   VWAP.Deinit(); // Cleanly removes Dot and Axes projection lines
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   VWAP.OnTimer();
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   VWAP.OnChartEvent(id, lparam, dparam, sparam);

   if(id == CHARTEVENT_OBJECT_DRAG && sparam == InpDotName)
     {
      // Force recalculation when dragged
      ChartSetSymbolPeriod(0, _Symbol, _Period);
     }
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   g_marcoDailyLog.Pulse();
   return VWAP.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume,
                         VWAPBuffer, Up1Buffer, Dn1Buffer, Up2Buffer, Dn2Buffer, Up3Buffer, Dn3Buffer,
                         CumVolBuffer, CumPVBuffer, CumP2VBuffer, _Symbol, _Period);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\General\Anchored_VWAP.mq5

// END FILE: Indicators\Custom\General\Anchored_VWAP.mq5
