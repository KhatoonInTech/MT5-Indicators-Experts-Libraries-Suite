#define MARCO_LOG_PROGRAM "bar_replay"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                        Indicators\Custom\ZigZag\bar_replay.mq5|
//|                         SMC Interactive Bar Replay Tool          |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.04"
#property indicator_chart_window
#property indicator_buffers 8  // 4 for Bullish Plot, 4 for Bearish Plot
#property indicator_plots   2  // Split to render wicks & borders independently

// --- Plot 1: Bullish Candles ---
#property indicator_label1  "Bull Open;Bull High;Bull Low;Bull Close"
#property indicator_type1   DRAW_CANDLES
#property indicator_color1  C'15,175,89', C'15,175,89', clrNONE // Hardcoded Bullish Palette

// --- Plot 2: Bearish Candles ---
#property indicator_label2  "Bear Open;Bear High;Bear Low;Bear Close"
#property indicator_type2   DRAW_CANDLES
#property indicator_color2  C'255,98,81', clrNONE, C'255,98,81' // Hardcoded Bearish Palette

#include <Custom\General\bar_replay.mqh>

// --- Input Parameters ---
input group "Replay Timeline Settings"
input datetime InputFromDate = D'2026.06.29 00:00'; // Playback Start Time
input datetime InputToDate   = D'2026.07.02 23:59'; // Playback End Time (0 for Unbounded)
input int      InputSpeedMS  = 1000;                // Playback Interval (Milliseconds)

// --- Global Classes & Buffers ---
CBarReplay replay;

double BullOpen[];
double BullHigh[];
double BullLow[];
double BullClose[];

double BearOpen[];
double BearHigh[];
double BearLow[];
double BearClose[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
// Set local indicator buffer arrays for Bullish Plot (0-3)
   SetIndexBuffer(0, BullOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, BullHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, BullLow,   INDICATOR_DATA);
   SetIndexBuffer(3, BullClose, INDICATOR_DATA);

// Set local indicator buffer arrays for Bearish Plot (4-7)
   SetIndexBuffer(4, BearOpen,  INDICATOR_DATA);
   SetIndexBuffer(5, BearHigh,  INDICATOR_DATA);
   SetIndexBuffer(6, BearLow,   INDICATOR_DATA);
   SetIndexBuffer(7, BearClose, INDICATOR_DATA);

   color bullColor = C'15,175,89';
   color bearColor = C'255,98,81';

// Configure Plot 1 Colors (Matches user Bull color)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, bullColor); // Borders and wicks
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, bullColor); // Body
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrNONE);

// Configure Plot 2 Colors (Matches user Bear color)
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, bearColor); // Borders and wicks
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, clrNONE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 2, bearColor); // Body

// Init Bar Replay Model
   if(!replay.Init(InputFromDate, InputToDate, InputSpeedMS))
     {
      return(INIT_FAILED);
     }

   if(replay.GetState() == 2)
     {
      EventSetMillisecondTimer(InputSpeedMS);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   replay.Deinit(reason);
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
   if(rates_total <= 0)
      return 0;

   datetime replay_time = replay.GetCurrentTime();
   int state = replay.GetState();

// Fill data up to the replay marker
// Note: Always loop the entire array to allow historical calculations
// to be properly evaluated on step changes when offline.
   for(int i = 0; i < rates_total; i++)
     {
      bool show_bar = (state == 0) || (time[i] <= replay_time);

      if(show_bar)
        {
         bool is_bull = (close[i] >= open[i]);

         if(is_bull)
           {
            // Populate Bull plot buffers
            BullOpen[i]  = open[i];
            BullHigh[i]  = high[i];
            BullLow[i]   = low[i];
            BullClose[i] = close[i];

            // Empty Bear plot buffers
            BearOpen[i]  = EMPTY_VALUE;
            BearHigh[i]  = EMPTY_VALUE;
            BearLow[i]   = EMPTY_VALUE;
            BearClose[i] = EMPTY_VALUE;
           }
         else
           {
            // Empty Bull plot buffers
            BullOpen[i]  = EMPTY_VALUE;
            BullHigh[i]  = EMPTY_VALUE;
            BullLow[i]   = EMPTY_VALUE;
            BullClose[i] = EMPTY_VALUE;

            // Populate Bear plot buffers
            BearOpen[i]  = open[i];
            BearHigh[i]  = high[i];
            BearLow[i]   = low[i];
            BearClose[i] = close[i];
           }
        }
      else
        {
         // Wipe future bars in both plots
         BullOpen[i]  = EMPTY_VALUE;
         BullHigh[i]  = EMPTY_VALUE;
         BullLow[i]   = EMPTY_VALUE;
         BullClose[i] = EMPTY_VALUE;

         BearOpen[i]  = EMPTY_VALUE;
         BearHigh[i]  = EMPTY_VALUE;
         BearLow[i]   = EMPTY_VALUE;
         BearClose[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Timer step iteration                                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(replay.GetState() == 2)
     {
      if(!replay.StepForward())
        {
         EventKillTimer();
        }
     }
  }

//+------------------------------------------------------------------+
//| UI Interactions and Commands                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == "Replay_Btn_Play")
        {
         int state = replay.GetState();
         if(state == 2) // Playing -> Pause State transition
           {
            replay.SetState(1);
            EventKillTimer();
           }
         else // Paused/Stopped -> Play State transition
           {
            replay.SetState(2);
            int speed = (int)GlobalVariableGet("Replay_Speed_" + IntegerToString(ChartID()));
            if(speed <= 0)
               speed = 1000;
            EventSetMillisecondTimer(speed);
           }
         replay.UpdateUI();
         replay.ForceRecalculate(); // Force redraw on state toggle
         ObjectSetInteger(0, "Replay_Btn_Play", OBJPROP_STATE, false);
         ChartRedraw(0);
        }
      else
         if(sparam == "Replay_Btn_Step")
           {
            replay.StepForward();
            ObjectSetInteger(0, "Replay_Btn_Step", OBJPROP_STATE, false);
            ChartRedraw(0);
           }
         else
            if(sparam == "Replay_Btn_Stop")
              {
               replay.ResetReplay();
               ObjectSetInteger(0, "Replay_Btn_Stop", OBJPROP_STATE, false);
               ChartRedraw(0);
              }
     }
  }
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\General\bar_replay.mq5

// END FILE: Indicators\Custom\General\bar_replay.mq5
