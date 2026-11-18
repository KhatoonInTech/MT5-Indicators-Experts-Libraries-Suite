//+------------------------------------------------------------------+
//|                                        Include\ZigZag\bar_replay.mqh|
//|                         SMC Bar Replay Logic Library             |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.05"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CBarReplay
  {
private:
   long              m_chart_id;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_period;

   // Helper to emulate MQL4 iBarShift natively in MQL5
   int               iBarShift(string symbol, ENUM_TIMEFRAMES timeframe, datetime time, bool exact = false)
     {
      datetime t_arr[];
      if(CopyTime(symbol, timeframe, 0, 1, t_arr) <= 0)
         return -1;

      datetime newest_time = t_arr[0];
      if(time > newest_time)
         return exact ? -1 : 0;

      int count = Bars(symbol, timeframe, time, newest_time);
      if(count <= 0)
         return -1;

      if(exact)
        {
         datetime check_time[];
         if(CopyTime(symbol, timeframe, count - 1, 1, check_time) > 0)
           {
            if(check_time[0] != time)
               return -1;
           }
        }
      return count - 1;
     }

   datetime          GetNextBarTime(datetime current_time)
     {
      int idx = iBarShift(m_symbol, m_period, current_time, true);
      if(idx == -1)
        {
         idx = iBarShift(m_symbol, m_period, current_time, false);
        }
      if(idx > 0)
        {
         datetime t[];
         if(CopyTime(m_symbol, m_period, idx - 1, 1, t) > 0)
           {
            return t[0];
           }
        }
      return 0;
     }

   void              HideDefaultChart()
     {
      string col_bg_key = "Replay_ColBG_" + IntegerToString(m_chart_id);
      if(!GlobalVariableCheck(col_bg_key))
        {
         GlobalVariableSet(col_bg_key, (double)ChartGetInteger(m_chart_id, CHART_COLOR_BACKGROUND));
         GlobalVariableSet("Replay_ChartMode_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_MODE));
         GlobalVariableSet("Replay_ColLine_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_COLOR_CHART_LINE));

         GlobalVariableSet("Replay_ColUp_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_COLOR_CANDLE_BULL));
         GlobalVariableSet("Replay_ColDn_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_COLOR_CANDLE_BEAR));
         GlobalVariableSet("Replay_ColCrUp_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_COLOR_CHART_UP));
         GlobalVariableSet("Replay_ColCrDn_" + IntegerToString(m_chart_id), (double)ChartGetInteger(m_chart_id, CHART_COLOR_CHART_DOWN));
        }

      // Force background chart mode to Line Chart
      ChartSetInteger(m_chart_id, CHART_MODE, CHART_LINE);

      // Blend line color directly into background to hide it completely
      color bg_color = (color)ChartGetInteger(m_chart_id, CHART_COLOR_BACKGROUND);
      ChartSetInteger(m_chart_id, CHART_COLOR_CHART_LINE, bg_color);

      ChartRedraw(m_chart_id);
     }

   void              RestoreDefaultChart()
     {
      string col_bg_key = "Replay_ColBG_" + IntegerToString(m_chart_id);
      if(GlobalVariableCheck(col_bg_key))
        {
         ChartSetInteger(m_chart_id, CHART_COLOR_BACKGROUND, (long)GlobalVariableGet(col_bg_key));
         ChartSetInteger(m_chart_id, CHART_MODE, (long)GlobalVariableGet("Replay_ChartMode_" + IntegerToString(m_chart_id)));
         ChartSetInteger(m_chart_id, CHART_COLOR_CHART_LINE, (long)GlobalVariableGet("Replay_ColLine_" + IntegerToString(m_chart_id)));

         ChartSetInteger(m_chart_id, CHART_COLOR_CANDLE_BULL, (long)GlobalVariableGet("Replay_ColUp_" + IntegerToString(m_chart_id)));
         ChartSetInteger(m_chart_id, CHART_COLOR_CANDLE_BEAR, (long)GlobalVariableGet("Replay_ColDn_" + IntegerToString(m_chart_id)));
         ChartSetInteger(m_chart_id, CHART_COLOR_CHART_UP, (long)GlobalVariableGet("Replay_ColCrUp_" + IntegerToString(m_chart_id)));
         ChartSetInteger(m_chart_id, CHART_COLOR_CHART_DOWN, (long)GlobalVariableGet("Replay_ColCrDn_" + IntegerToString(m_chart_id)));

         GlobalVariableDel(col_bg_key);
         GlobalVariableDel("Replay_ChartMode_" + IntegerToString(m_chart_id));
         GlobalVariableDel("Replay_ColLine_" + IntegerToString(m_chart_id));
         GlobalVariableDel("Replay_ColUp_" + IntegerToString(m_chart_id));
         GlobalVariableDel("Replay_ColDn_" + IntegerToString(m_chart_id));
         GlobalVariableDel("Replay_ColCrUp_" + IntegerToString(m_chart_id));
         GlobalVariableDel("Replay_ColCrDn_" + IntegerToString(m_chart_id));
        }
      ChartRedraw(m_chart_id);
     }

   void              CreateButton(string name, string text, int x, int y, int w, int h)
     {
      if(ObjectFind(m_chart_id, name) < 0)
        {
         ObjectCreate(m_chart_id, name, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, w);
         ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, h);
         ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, clrWhite);

         // Custom colors from your chart settings (Grid & Background colors)
         ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, C'43,48,64');       // Grid Color
         ObjectSetInteger(m_chart_id, name, OBJPROP_BORDER_COLOR, C'28,31,45');   // Background Color

         ObjectSetString(m_chart_id, name, OBJPROP_FONT, "Segoe UI");
         ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
        }
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
     }

   void              CreateUI()
     {
      int x_offset = 20;
      int y_offset = 140;
      int btn_width = 85;
      int btn_height = 25;
      int spacing = 6;

      CreateButton("Replay_Btn_Play", "▶ Play", x_offset, y_offset, btn_width, btn_height);
      CreateButton("Replay_Btn_Step", "⏭ Step", x_offset + btn_width + spacing, y_offset, btn_width, btn_height);
      CreateButton("Replay_Btn_Stop", "⏹ Reset", x_offset + (btn_width + spacing) * 2, y_offset, btn_width, btn_height);

      string lbl_name = "Replay_Label_Status";
      if(ObjectFind(m_chart_id, lbl_name) < 0)
        {
         ObjectCreate(m_chart_id, lbl_name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chart_id, lbl_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(m_chart_id, lbl_name, OBJPROP_XDISTANCE, x_offset);
         ObjectSetInteger(m_chart_id, lbl_name, OBJPROP_YDISTANCE, y_offset - 22);
         ObjectSetInteger(m_chart_id, lbl_name, OBJPROP_COLOR, C'15,175,89'); // Matches user Bullish palette
         ObjectSetString(m_chart_id, lbl_name, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(m_chart_id, lbl_name, OBJPROP_FONTSIZE, 10);
        }
      UpdateUI();
     }

   void              DeleteUI()
     {
      ObjectDelete(m_chart_id, "Replay_Btn_Play");
      ObjectDelete(m_chart_id, "Replay_Btn_Step");
      ObjectDelete(m_chart_id, "Replay_Btn_Stop");
      ObjectDelete(m_chart_id, "Replay_Label_Status");
      ChartRedraw(m_chart_id);
     }

   void              DeleteGlobals()
     {
      GlobalVariableDel("Replay_Time_" + IntegerToString(m_chart_id));
      GlobalVariableDel("Replay_State_" + IntegerToString(m_chart_id));
      GlobalVariableDel("Replay_From_" + IntegerToString(m_chart_id));
      GlobalVariableDel("Replay_To_" + IntegerToString(m_chart_id));
      GlobalVariableDel("Replay_Speed_" + IntegerToString(m_chart_id));
     }

public:
   // Simulates a virtual tick change to recalculate indicators offline (on weekends)
   void              ForceRecalculate()
     {
      bool autoscroll = (bool)ChartGetInteger(m_chart_id, CHART_AUTOSCROLL);
      ChartSetInteger(m_chart_id, CHART_AUTOSCROLL, !autoscroll);
      ChartSetInteger(m_chart_id, CHART_AUTOSCROLL, autoscroll);

      bool shift = (bool)ChartGetInteger(m_chart_id, CHART_SHIFT);
      ChartSetInteger(m_chart_id, CHART_SHIFT, !shift);
      ChartSetInteger(m_chart_id, CHART_SHIFT, shift);

      ChartRedraw(m_chart_id);
     }

                     CBarReplay()
     {
      m_chart_id = ChartID();
      m_symbol   = _Symbol;
      m_period   = _Period;
     }

                    ~CBarReplay() {}

   bool              Init(datetime from_date, datetime to_date, int speed_ms)
     {
      m_chart_id = ChartID();
      m_symbol   = _Symbol;
      m_period   = _Period;

      string time_key = "Replay_Time_" + IntegerToString(m_chart_id);
      string state_key = "Replay_State_" + IntegerToString(m_chart_id);

      // If this is the initial launch on the chart, setup variables
      if(!GlobalVariableCheck(time_key))
        {
         GlobalVariableSet(time_key, (double)from_date);
         GlobalVariableSet(state_key, 1.0); // 1 = Paused on start
         GlobalVariableSet("Replay_From_" + IntegerToString(m_chart_id), (double)from_date);
         GlobalVariableSet("Replay_To_" + IntegerToString(m_chart_id), (double)to_date);
         GlobalVariableSet("Replay_Speed_" + IntegerToString(m_chart_id), (double)speed_ms);
        }
      else
        {
         // Preserve current replay time, update other dynamic input settings
         GlobalVariableSet("Replay_From_" + IntegerToString(m_chart_id), (double)from_date);
         GlobalVariableSet("Replay_To_" + IntegerToString(m_chart_id), (double)to_date);
         GlobalVariableSet("Replay_Speed_" + IntegerToString(m_chart_id), (double)speed_ms);
        }

      HideDefaultChart();
      CreateUI();
      return true;
     }

   void              Deinit(const int reason)
     {
      // Clean up fully only if the indicator is explicitly removed from chart
      if(reason == REASON_REMOVE || reason == REASON_PROGRAM)
        {
         RestoreDefaultChart();
         DeleteUI();
         DeleteGlobals();
        }
      else
        {
         // On timeframe change or parameter edits, clean visual overlay objects to redraw cleanly
         DeleteUI();
        }
     }

   int               GetState()
     {
      string key = "Replay_State_" + IntegerToString(m_chart_id);
      if(!GlobalVariableCheck(key))
         return 0;
      return (int)GlobalVariableGet(key);
     }

   void              SetState(int state)
     {
      GlobalVariableSet("Replay_State_" + IntegerToString(m_chart_id), (double)state);
     }

   datetime          GetCurrentTime()
     {
      string key = "Replay_Time_" + IntegerToString(m_chart_id);
      if(!GlobalVariableCheck(key))
         return 0;
      return (datetime)GlobalVariableGet(key);
     }

   void              SetCurrentTime(datetime t)
     {
      GlobalVariableSet("Replay_Time_" + IntegerToString(m_chart_id), (double)t);
     }

   bool              StepForward()
     {
      datetime cur_time = GetCurrentTime();
      datetime next_time = GetNextBarTime(cur_time);
      datetime to_time = (datetime)GlobalVariableGet("Replay_To_" + IntegerToString(m_chart_id));

      if(next_time > 0 && (to_time == 0 || next_time <= to_time))
        {
         SetCurrentTime(next_time);
         UpdateUI();
         ForceRecalculate();
         return true;
        }
      else
        {
         SetState(1); // Auto-pause at the end of data range
         UpdateUI();
         ForceRecalculate();
         return false;
        }
     }

   void              ResetReplay()
     {
      datetime from_time = (datetime)GlobalVariableGet("Replay_From_" + IntegerToString(m_chart_id));
      SetCurrentTime(from_time);
      SetState(1); // Reset to Paused state
      UpdateUI();
      ForceRecalculate();
     }

   void              UpdateUI()
     {
      int state = GetState();
      datetime cur_time = GetCurrentTime();

      string play_btn_text = (state == 2) ? "⏸ Pause" : "▶ Play";
      ObjectSetString(m_chart_id, "Replay_Btn_Play", OBJPROP_TEXT, play_btn_text);
      ObjectSetInteger(m_chart_id, "Replay_Btn_Play", OBJPROP_STATE, (state == 2));

      string status_txt = "";
      if(state == 0)
         status_txt = "Replay Status: Reset/Stopped";
      else
         if(state == 1)
            status_txt = "Replay Status [Paused]: " + TimeToString(cur_time, TIME_DATE|TIME_MINUTES);
         else
            if(state == 2)
               status_txt = "Replay Status [Playing]: " + TimeToString(cur_time, TIME_DATE|TIME_MINUTES);

      ObjectSetString(m_chart_id, "Replay_Label_Status", OBJPROP_TEXT, status_txt);
      ChartRedraw(m_chart_id);
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\bar_replay.mqh

// END FILE: Include\Custom\General\bar_replay.mqh
