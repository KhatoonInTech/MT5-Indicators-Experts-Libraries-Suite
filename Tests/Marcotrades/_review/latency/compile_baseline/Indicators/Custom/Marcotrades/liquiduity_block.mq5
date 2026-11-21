#define MARCO_LOG_PROGRAM "liquiduity_block"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                             Indicators\Custom\Marcotrades\liquiduity_block.mq5 |
//|                 Smart Money Concepts: Liquidity Block Visualizer |
//|                 With Interactive Anchor Slider & Manual DateTime |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.26"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\symbol_units.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\history_context.mqh"

enum ENUM_LB_LABEL_POS
  {
   LB_LABEL_RIGHT,
   LB_LABEL_CENTER,
   LB_LABEL_LEFT
  };

enum ENUM_LB_DISPLAY_MODE
  {
   LB_DISPLAY_RAW_PREVENTION_EXITS, // Raw LBs used by entry prevention and position exits
   LB_DISPLAY_ENTRY_SETUP_ONLY,     // Only LBs armed by the entry-trigger policy
   LB_DISPLAY_ALL                   // Raw guardrail LBs plus entry-armed LBs
  };

enum ENUM_LABEL_POS
  {
   LABEL_POS_RIGHT,
   LABEL_POS_CENTER,
   LABEL_POS_LEFT
  };

// =============================================================================
// USER INPUT PARAMETERS
// =============================================================================
input group "=== Interactive Anchor Slider (Previous-Day Context) ==="
input bool              InpUseAnchorSlider          = true;
input datetime          InpAnchorDateTime           = D'2026.11.17 00:00';
input datetime          InpEndTime                  = D'2026.11.17 23:59';; // Calculation End Time (0 for Current Time)
input string            InpAnchorName               = "SMC_Anchor";
input color             InpAnchorColor              = clrDarkTurquoise;
input bool              InpFadeUntilSelected        = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Structural Lines (BOS, CHoCH, Sweeps) ==="
input bool              InpShowStructuralLines      = true;
input bool              InpShowSwingHL              = true;

input group "=== Liquidity Block Triggers ==="
input bool              InpTrackSweepsAnywhere      = true;
input bool              InpTrackPostInducementCHoCH = true;
input bool              InpApplyEntryLBPolicyToPreventionExits = false; // Apply entry-qualified LB rules to prevention and position exits

input group "=== Liquidity Block Display & Visuals ==="
input ENUM_LB_DISPLAY_MODE InpLBDisplayMode          = LB_DISPLAY_ALL;
input bool              InpShowBullishLB            = true;
input bool              InpShowBearishLB            = true;
input bool              InpShowMitigatedLB          = true;
input bool              showfreshLBonly             = true;
input color             InpColorBullishLB           = C'0,220,220';
input color             InpColorBearishLB           = C'255,20,147';
input color             InpColorMitigatedLB         = clrGray;
input color             InpColorLBText              = clrWhite;
input ENUM_LB_LABEL_POS InpLBLabelPos               = LB_LABEL_CENTER;

input group "=== Price Units ==="
input string InpPipSizeOverrides = ""; // Same price-per-pip overrides as the trade engines

input group "=== Inducement Rules ==="
input bool            InpShowUnderlyingInducement = true;
input int             InpMinTouches               = 2;
input double          InpProximityPips            = 1.0;
input bool            InpShowBuyersInducement     = true;
input bool            InpShowSellersInducement    = true;
input bool            InpShowMitigatedInducement  = true;
input bool            InpShowTouchCount           = true;
input bool            InpStrictOriginPivots       = true;

input group "=== Anti-Clustering & Zone Prolongation ==="
input bool            InpMergeClusteredZones      = true;
input double          InpClusterTolerancePips     = 5.0;
input bool            InpMergeExpandBounds        = false;

input group "=== SMC Zone Sources ==="
input bool            InpCheckDemandSupply        = true;
input bool            InpCheckOrderBlocks         = true;
input bool            InpCheckSwingPOIs           = true;
input bool            InpCheckFlipZones           = false;
input bool            InpCheckBreakers            = false;

input group "=== Visual Styles & Palette ==="
input color           InpColorBuyerInducement     = C'30,144,255';
input color           InpColorSellerInducement    = C'255,69,0';
input color           InpColorMitigated           = clrGray;
input color           InpColorText                = clrWhite;
input ENUM_LABEL_POS  InpLabelPosition            = LABEL_POS_CENTER;

input group "=== Structural ZigZag Configuration ==="
input double          InpDeviation                = 0.001;
input int             InpDepth                    = 1;
input color           InpZZColor                  = clrGold;
input bool            InpShowZigZagLines          = true;
input string          InpPriceDiff                = "Absolute";
input int             InpMaxLookbackBars          = 3000;

// =============================================================================
// GLOBAL ENGINES & DATA CONTAINERS
// =============================================================================
ZigZag*               zigZag   = NULL;
CMarketStructure*     ms       = NULL;
CDemandSupplyLogic*   dsLogic  = NULL;
CSwingPOILogic*       spLogic  = NULL;
COrderBlockLogic*     obLogic  = NULL;
CFlipZoneLogic*       fzLogic  = NULL;
CBreakerBlockLogic*   bbLogic  = NULL;
CInducementLogic*     indLogic = NULL;
CLiquidityBlockLogic* lbLogic  = NULL;

string   g_dot_name               = "";
string   g_vline_name             = "";
string   g_badge_name             = "";
datetime g_anchor_time            = 0;
datetime g_last_calculated_anchor = 0;
datetime g_last_interaction_time  = 0;
bool     g_dot_is_large           = true;
bool     g_waiting_history        = false;

struct SIndicatorEntryLBState
  {
   string            id;
   datetime          armedTime;
  };

SIndicatorEntryLBState g_entry_lb_states[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color FadeColorToBG(color baseClr, int fadePercent)
  {
   color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int r1 = (baseClr & 0xFF), g1 = ((baseClr >> 8) & 0xFF), b1 = ((baseClr >> 16) & 0xFF);
   int r2 = (bg & 0xFF),      g2 = ((bg >> 8) & 0xFF),      b2 = ((bg >> 16) & 0xFF);

   int r = r1 + (r2 - r1) * fadePercent / 100;
   int g = g1 + (g2 - g1) * fadePercent / 100;
   int b = b1 + (b2 - b1) * fadePercent / 100;

   return (color)(r | (g << 8) | (b << 16));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipSize()
  {
   return CMarcoSymbolUnits::PipSize(_Symbol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetState()
  {
   if(ms       != NULL && CheckPointer(ms)       == POINTER_DYNAMIC)
      ms.ResetState();
   if(dsLogic  != NULL && CheckPointer(dsLogic)  == POINTER_DYNAMIC)
      dsLogic.ResetState();
   if(spLogic  != NULL && CheckPointer(spLogic)  == POINTER_DYNAMIC)
      spLogic.ResetState();
   if(obLogic  != NULL && CheckPointer(obLogic)  == POINTER_DYNAMIC)
      obLogic.ResetState();
   if(fzLogic  != NULL && CheckPointer(fzLogic)  == POINTER_DYNAMIC)
      fzLogic.ResetState();
   if(bbLogic  != NULL && CheckPointer(bbLogic)  == POINTER_DYNAMIC)
      bbLogic.ResetState();
   if(indLogic != NULL && CheckPointer(indLogic) == POINTER_DYNAMIC)
      indLogic.ResetState();
   if(lbLogic  != NULL && CheckPointer(lbLogic)  == POINTER_DYNAMIC)
      lbLogic.ResetState();

   ArrayResize(g_entry_lb_states,0);

   ObjectsDeleteAll(0, "LB_");
   ObjectsDeleteAll(0, "IND_");
   ObjectsDeleteAll(0, "BOSCHoCH_");
   ObjectsDeleteAll(0, "SWING_");
   ObjectsDeleteAll(0, "ZZ_");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReinitEngines()
  {
   if(CheckPointer(zigZag)   == POINTER_DYNAMIC)
     {
      delete zigZag;
      zigZag   = NULL;
     }
   if(CheckPointer(ms)       == POINTER_DYNAMIC)
     {
      delete ms;
      ms       = NULL;
     }
   if(CheckPointer(dsLogic)  == POINTER_DYNAMIC)
     {
      delete dsLogic;
      dsLogic  = NULL;
     }
   if(CheckPointer(spLogic)  == POINTER_DYNAMIC)
     {
      delete spLogic;
      spLogic  = NULL;
     }
   if(CheckPointer(obLogic)  == POINTER_DYNAMIC)
     {
      delete obLogic;
      obLogic  = NULL;
     }
   if(CheckPointer(fzLogic)  == POINTER_DYNAMIC)
     {
      delete fzLogic;
      fzLogic  = NULL;
     }
   if(CheckPointer(bbLogic)  == POINTER_DYNAMIC)
     {
      delete bbLogic;
      bbLogic  = NULL;
     }
   if(CheckPointer(indLogic) == POINTER_DYNAMIC)
     {
      delete indLogic;
      indLogic = NULL;
     }
   if(CheckPointer(lbLogic)  == POINTER_DYNAMIC)
     {
      delete lbLogic;
      lbLogic  = NULL;
     }

   Settings* s = new Settings(InpDeviation, InpDepth, InpZZColor, true, false, false, false, InpPriceDiff);
   s.draw = InpShowZigZagLines;
   zigZag = newInstance(s);

   ms = new CMarketStructure();
   ms.Init(InpShowStructuralLines, InpShowSwingHL);

   dsLogic  = new CDemandSupplyLogic();
   spLogic  = new CSwingPOILogic();
   obLogic  = new COrderBlockLogic();
   fzLogic  = new CFlipZoneLogic();
   bbLogic  = new CBreakerBlockLogic();

   indLogic = new CInducementLogic();
   indLogic.Init(InpMinTouches, InpProximityPips,
                 InpCheckDemandSupply, InpCheckOrderBlocks,
                 InpCheckSwingPOIs, InpCheckFlipZones,
                 InpCheckBreakers, InpStrictOriginPivots,
                 InpMergeClusteredZones, InpClusterTolerancePips,
                 InpMergeExpandBounds);

   lbLogic = new CLiquidityBlockLogic();
   lbLogic.Init(InpTrackSweepsAnywhere, InpTrackPostInducementCHoCH, SymbolInfoDouble(_Symbol,SYMBOL_POINT));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateAnchorVisuals(bool is_selected)
  {
   if(!InpUseAnchorSlider)
      return;

   color badge_clr = InpAnchorColor;
   color line_clr  = InpAnchorColor;

   if(InpFadeUntilSelected)
     {
      if(!is_selected)
        {
         badge_clr = clrNONE;
         line_clr  = FadeColorToBG(InpAnchorColor, 75);
        }
      else
        {
         badge_clr = InpAnchorColor;
         line_clr  = InpAnchorColor;
        }
     }

   ObjectSetInteger(0, g_badge_name, OBJPROP_COLOR, badge_clr);
   ObjectSetInteger(0, g_vline_name, OBJPROP_COLOR, line_clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAndCreateAnchorObjects()
  {
   if(!InpUseAnchorSlider)
      return;

   string gv_key       = "LB_Anchor_Time_" + IntegerToString(ChartID());
   string gv_input_key = "LB_Anchor_Input_" + IntegerToString(ChartID());

   datetime prev_input = GlobalVariableCheck(gv_input_key) ? (datetime)GlobalVariableGet(gv_input_key) : 0;

   if(InpAnchorDateTime > 0 && InpAnchorDateTime != prev_input)
     {
      g_anchor_time = InpAnchorDateTime;
      GlobalVariableSet(gv_input_key, (double)InpAnchorDateTime);
      GlobalVariableSet(gv_key, (double)g_anchor_time);
     }
   else
      if(GlobalVariableCheck(gv_key))
        {
         g_anchor_time = (datetime)GlobalVariableGet(gv_key);
        }
      else
         if(InpAnchorDateTime > 0)
           {
            g_anchor_time = InpAnchorDateTime;
            GlobalVariableSet(gv_input_key, (double)InpAnchorDateTime);
            GlobalVariableSet(gv_key, (double)g_anchor_time);
           }
         else
           {
            int default_shift = MathMin(80, MathMax(0, Bars(_Symbol, _Period) - 1));
            g_anchor_time = iTime(_Symbol, _Period, default_shift);
            GlobalVariableSet(gv_key, (double)g_anchor_time);
           }

   int shift = iBarShift(_Symbol, _Period, g_anchor_time, false);
   double candle_high = (shift >= 0) ? iHigh(_Symbol, _Period, shift) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pipSize = GetPipSize();
   double badge_price = candle_high + (4.0 * pipSize);

   if(ObjectFind(0, g_dot_name) < 0)
     {
      ObjectCreate(0, g_dot_name, OBJ_ARROW, 0, g_anchor_time, candle_high);
      ObjectSetInteger(0, g_dot_name, OBJPROP_ARROWCODE, 159);
      ObjectSetInteger(0, g_dot_name, OBJPROP_COLOR, InpAnchorColor);
      ObjectSetInteger(0, g_dot_name, OBJPROP_WIDTH, 5);
      ObjectSetInteger(0, g_dot_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, g_dot_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, g_dot_name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, g_dot_name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, g_dot_name, OBJPROP_ZORDER, 100);
      ObjectSetString(0, g_dot_name, OBJPROP_TOOLTIP, "⚓ SMC Anchor Slider: Double-click to show name/badge, drag to any candle!");
     }
   else
     {
      ObjectSetInteger(0, g_dot_name, OBJPROP_TIME, g_anchor_time);
      ObjectSetDouble(0, g_dot_name, OBJPROP_PRICE, candle_high);
     }

   if(ObjectFind(0, g_vline_name) < 0)
     {
      ObjectCreate(0, g_vline_name, OBJ_VLINE, 0, g_anchor_time, 0);
      ObjectSetInteger(0, g_vline_name, OBJPROP_COLOR, InpAnchorColor);
      ObjectSetInteger(0, g_vline_name, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, g_vline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, g_vline_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_vline_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, g_vline_name, OBJPROP_ZORDER, 40);
      ObjectSetString(0, g_vline_name, OBJPROP_TOOLTIP, "SMC Anchor: " + TimeToString(g_anchor_time, TIME_DATE|TIME_MINUTES));
     }
   else
     {
      ObjectSetInteger(0, g_vline_name, OBJPROP_TIME, g_anchor_time);
     }

   if(ObjectFind(0, g_badge_name) < 0)
     {
      ObjectCreate(0, g_badge_name, OBJ_TEXT, 0, g_anchor_time, badge_price);
      ObjectSetInteger(0, g_badge_name, OBJPROP_COLOR, InpFadeUntilSelected ? clrNONE : InpAnchorColor);
      ObjectSetInteger(0, g_badge_name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, g_badge_name, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, g_badge_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, g_badge_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, g_badge_name, OBJPROP_ZORDER, 100);
      ObjectSetString(0, g_badge_name, OBJPROP_TEXT, " ⚓ SMC ANCHOR: " + TimeToString(g_anchor_time, TIME_DATE|TIME_MINUTES) + " ");
     }
   else
     {
      ObjectSetInteger(0, g_badge_name, OBJPROP_TIME, g_anchor_time);
      ObjectSetDouble(0, g_badge_name, OBJPROP_PRICE, badge_price);
      ObjectSetString(0, g_badge_name, OBJPROP_TEXT, " ⚓ SMC ANCHOR: " + TimeToString(g_anchor_time, TIME_DATE|TIME_MINUTES) + " ");
     }

   bool is_sel = (bool)ObjectGetInteger(0, g_dot_name, OBJPROP_SELECTED);
   UpdateAnchorVisuals(is_sel);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   if(InpUseAnchorSlider && InpEndTime>0 && InpAnchorDateTime>=InpEndTime)
     {
      Print("[WINDOW] InpEndTime must be later than InpAnchorDateTime (or 0 for current time).");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!CMarcoSymbolUnits::Configure(InpPipSizeOverrides)) return INIT_PARAMETERS_INCORRECT;
   SMarcoSymbolUnits units;
   if(!CMarcoSymbolUnits::Load(_Symbol,units)) return INIT_PARAMETERS_INCORRECT;
   PrintFormat("[ZONE UNITS] %s pip=%.8f point=%.8f proximity=%.8f cluster=%.8f",
               _Symbol,units.pip,units.point,InpProximityPips*units.pip,InpClusterTolerancePips*units.pip);
   g_dot_name   = InpAnchorName + "_Dot";
   g_vline_name = InpAnchorName + "_VLine";
   g_badge_name = InpAnchorName + "_Badge";
   g_last_interaction_time = TimeLocal();
   g_dot_is_large = true;

   ReinitEngines();
   CheckAndCreateAnchorObjects();

   // A saved slider position can belong to a different end-time window.
   if(InpUseAnchorSlider && InpEndTime>0 && g_anchor_time>=InpEndTime)
     {
      Print("[WINDOW] Saved anchor is at/after InpEndTime. Move the anchor earlier or change the end time.");
      return INIT_PARAMETERS_INCORRECT;
     }

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

// FIX: Reset state BEFORE deleting pointers, then safely nullify
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);

   if(reason == REASON_REMOVE || reason == REASON_PARAMETERS)
     {
      ObjectDelete(0, g_dot_name);
      ObjectDelete(0, g_vline_name);
      ObjectDelete(0, g_badge_name);
      GlobalVariableDel("LB_Anchor_Time_" + IntegerToString(ChartID()));
      GlobalVariableDel("LB_Anchor_Input_" + IntegerToString(ChartID()));
     }

   ResetState();

   if(CheckPointer(zigZag)   == POINTER_DYNAMIC)
     {
      delete zigZag;
      zigZag   = NULL;
     }
   if(CheckPointer(ms)       == POINTER_DYNAMIC)
     {
      delete ms;
      ms       = NULL;
     }
   if(CheckPointer(dsLogic)  == POINTER_DYNAMIC)
     {
      delete dsLogic;
      dsLogic  = NULL;
     }
   if(CheckPointer(spLogic)  == POINTER_DYNAMIC)
     {
      delete spLogic;
      spLogic  = NULL;
     }
   if(CheckPointer(obLogic)  == POINTER_DYNAMIC)
     {
      delete obLogic;
      obLogic  = NULL;
     }
   if(CheckPointer(fzLogic)  == POINTER_DYNAMIC)
     {
      delete fzLogic;
      fzLogic  = NULL;
     }
   if(CheckPointer(bbLogic)  == POINTER_DYNAMIC)
     {
      delete bbLogic;
      bbLogic  = NULL;
     }
   if(CheckPointer(indLogic) == POINTER_DYNAMIC)
     {
      delete indLogic;
      indLogic = NULL;
     }
   if(CheckPointer(lbLogic)  == POINTER_DYNAMIC)
     {
      delete lbLogic;
      lbLogic  = NULL;
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(!InpUseAnchorSlider)
      return;

   if(ObjectFind(0, g_dot_name) >= 0)
     {
      bool is_selected = (bool)ObjectGetInteger(0, g_dot_name, OBJPROP_SELECTED);
      if(is_selected)
         g_last_interaction_time = TimeLocal();

      UpdateAnchorVisuals(is_selected);

      if(TimeLocal() - g_last_interaction_time > 10)
        {
         if(g_dot_is_large)
           {
            ObjectSetInteger(0, g_dot_name, OBJPROP_WIDTH, 2);
            g_dot_is_large = false;
            ChartRedraw(0);
           }
        }
      else
        {
         if(!g_dot_is_large)
           {
            ObjectSetInteger(0, g_dot_name, OBJPROP_WIDTH, 5);
            g_dot_is_large = true;
            ChartRedraw(0);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_marcoDailyLog.Pulse();
   if(!InpUseAnchorSlider)
      return;

   static ulong last_click_tick = 0;

   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_dot_name)
     {
      ulong now_tick = GetTickCount64();
      g_last_interaction_time = TimeLocal();

      if(now_tick - last_click_tick <= 450)
        {
         bool current_sel = (bool)ObjectGetInteger(0, g_dot_name, OBJPROP_SELECTED);
         ObjectSetInteger(0, g_dot_name, OBJPROP_SELECTED, !current_sel);
         UpdateAnchorVisuals(!current_sel);
        }
      else
        {
         bool current_sel = (bool)ObjectGetInteger(0, g_dot_name, OBJPROP_SELECTED);
         UpdateAnchorVisuals(current_sel);
        }

      last_click_tick = now_tick;
      ChartRedraw(0);
      return;
     }

   if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_OBJECT_DRAG)
     {
      if(ObjectFind(0, g_dot_name) >= 0)
        {
         bool is_selected = (bool)ObjectGetInteger(0, g_dot_name, OBJPROP_SELECTED);
         if(is_selected)
           {
            g_last_interaction_time = TimeLocal();
            datetime cur_t = (datetime)ObjectGetInteger(0, g_dot_name, OBJPROP_TIME, 0);
            double   cur_p = ObjectGetDouble(0, g_dot_name, OBJPROP_PRICE, 0);

            datetime old_t = (datetime)ObjectGetInteger(0, g_vline_name, OBJPROP_TIME, 0);
            if(cur_t != old_t && cur_t > 0)
              {
               double pipSize = GetPipSize();
               ObjectSetInteger(0, g_vline_name, OBJPROP_TIME, 0, cur_t);
               ObjectSetInteger(0, g_badge_name, OBJPROP_TIME, cur_t);
               ObjectSetDouble(0, g_badge_name, OBJPROP_PRICE, cur_p + (4.0 * pipSize));
               ObjectSetString(0, g_badge_name, OBJPROP_TEXT, " ⚓ SMC ANCHOR: " + TimeToString(cur_t, TIME_DATE|TIME_MINUTES) + " ");
               UpdateAnchorVisuals(true);
               ChartRedraw(0);
              }
           }
        }
     }

   if(id == CHARTEVENT_OBJECT_DRAG && sparam == g_dot_name)
     {
      g_last_interaction_time = TimeLocal();

      datetime raw_t = (datetime)ObjectGetInteger(0, g_dot_name, OBJPROP_TIME, 0);
      int shift = iBarShift(_Symbol, _Period, raw_t, false);
      datetime snapped_time = iTime(_Symbol, _Period, shift);
      if(InpEndTime>0 && snapped_time>=InpEndTime)
        {
         Print("[WINDOW] Anchor must be earlier than InpEndTime.");
         CheckAndCreateAnchorObjects();
         ChartRedraw(0);
         return;
        }
      double   snapped_high = iHigh(_Symbol, _Period, shift);
      double   pipSize      = GetPipSize();

      ObjectSetInteger(0, g_dot_name, OBJPROP_TIME, snapped_time);
      ObjectSetDouble(0, g_dot_name, OBJPROP_PRICE, snapped_high);
      ObjectSetInteger(0, g_vline_name, OBJPROP_TIME, snapped_time);
      ObjectSetInteger(0, g_badge_name, OBJPROP_TIME, snapped_time);
      ObjectSetDouble(0, g_badge_name, OBJPROP_PRICE, snapped_high + (4.0 * pipSize));
      ObjectSetString(0, g_badge_name, OBJPROP_TEXT, " ⚓ SMC ANCHOR: " + TimeToString(snapped_time, TIME_DATE|TIME_MINUTES) + " ");

      g_anchor_time = snapped_time;
      GlobalVariableSet("LB_Anchor_Time_" + IntegerToString(ChartID()), (double)snapped_time);

      ChartSetSymbolPeriod(0, _Symbol, _Period);
     }

   if(id == CHARTEVENT_CHART_CHANGE)
     {
      CheckAndCreateAnchorObjects();
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Resolve the same previous-trading-day boundary used by the trade engines.
// The chart arrays must contain that history before any engine is rebuilt.
// Count only bars available at the requested endpoint. In lookback mode this
// also anchors the lookback to the historical endpoint, not today's last bar.
int WindowBarCount(const int count,const datetime &times[],const datetime endTime)
  {
   int left=0,right=count;
   while(left<right)
     {
      int mid=left+(right-left)/2;
      if(times[mid]<=endTime) left=mid+1;
      else right=mid;
     }
   return left;
  }

bool ClosedByWindowEnd(const datetime barTime,const datetime endTime,const int seconds)
  {
   return seconds>0 && barTime+seconds<=endTime;
  }

bool ResolveWarmupStart(const int count, const datetime &times[], int &startBar,
                        datetime &contextStart, datetime &historyStart)
  {
   startBar=0;
   contextStart=0;
   historyStart=0;
   if(count<=0) return false;
   contextStart=InpUseAnchorSlider ? g_anchor_time :
                times[MathMax(0,count-MathMax(1,InpMaxLookbackBars))];
   if(contextStart<=0 || contextStart>times[count-1]) return false;
   if(!CMarcoHistoryContext::ResolveStart(_Symbol,contextStart,historyStart)) return false;

   MqlRates warmup[];
   int copied=CopyRates(_Symbol,_Period,historyStart,contextStart,warmup);
   if(copied<=0 || !SeriesInfoInteger(_Symbol,_Period,SERIES_SYNCHRONIZED) ||
      !CMarcoHistoryContext::HasPriorContext(warmup[0].time,contextStart)) return false;
   // CopyRates also requests missing history from the terminal. If the chart
   // has not received it yet, return 0 from OnCalculate and retry on its update.
   for(int i=0;i<count;i++)
     {
      if(times[i]<warmup[0].time) continue;
      if(times[i]!=warmup[0].time) return false;
      startBar=i;
      return count-startBar>=InpDepth*2;
     }
   return false;
  }

int FindEntryLBState(const string id)
  {
   for(int i=0;i<ArraySize(g_entry_lb_states);i++)
      if(g_entry_lb_states[i].id==id) return i;
   return -1;
  }

bool IsEntrySetupLB(const string id)
  {
   int index=FindEntryLBState(id);
   return index>=0 && g_entry_lb_states[index].armedTime>0;
  }

// Latch entry eligibility chronologically, just like the trade engines. This
// prevents a later IND mitigation from retroactively hiding an already armed LB.
void TrackEntrySetupLBs(const datetime cutoff)
  {
   if(lbLogic==NULL || indLogic==NULL || ms==NULL || cutoff<=0) return;
   for(int l=0;l<lbLogic.m_exit_sources.Total();l++)
     {
      CLiquidityBlock* source=(CLiquidityBlock*)lbLogic.m_exit_sources.At(l);
      lbLogic.GuardSourceReady(source,indLogic,ms,cutoff,cutoff+PeriodSeconds(),true);
     }
   for(int l=0;l<lbLogic.m_liquidity_blocks.Total();l++)
     {
      CLiquidityBlock* lb=(CLiquidityBlock*)lbLogic.m_liquidity_blocks.At(l);
      if(lb==NULL || CheckPointer(lb)!=POINTER_DYNAMIC) continue;
      int index=FindEntryLBState(lb.id);
      if(index<0)
        {
         index=ArraySize(g_entry_lb_states);
         ArrayResize(g_entry_lb_states,index+1);
         g_entry_lb_states[index].id=lb.id;
         g_entry_lb_states[index].armedTime=0;
        }
      if(g_entry_lb_states[index].armedTime>0) continue;
      datetime structureTime=lbLogic.EntryTriggerStructureTime(lb.isBullish,lb.triggerType,
                                                                lb.sweepLineTime,indLogic,ms,cutoff);
      if(structureTime>0)
         g_entry_lb_states[index].armedTime=cutoff;
     }
  }

void DeleteLiquidityBlockObjects(CLiquidityBlock* lb)
  {
   if(lb==NULL) return;
   string boxId="LB_"+lb.id;
   ObjectDelete(0,boxId);
   ObjectDelete(0,boxId+"_lbl");
  }

bool ShouldRenderLiquidityBlock(const bool entryEligible,const bool exitOnly)
  {
   if(InpLBDisplayMode==LB_DISPLAY_ENTRY_SETUP_ONLY)
      return entryEligible && !exitOnly;
   bool preventionExitEligible=!InpApplyEntryLBPolicyToPreventionExits || entryEligible;
   if(InpLBDisplayMode==LB_DISPLAY_RAW_PREVENTION_EXITS)
      return preventionExitEligible;
   return preventionExitEligible || (entryEligible && !exitOnly);
  }

void RenderLiquidityBlock(CLiquidityBlock* lb,const datetime extendRight,const string tfStr,
                          const bool entryEligible,const bool exitOnly)
  {
   if(lb==NULL || CheckPointer(lb)!=POINTER_DYNAMIC) return;
   if(!ShouldRenderLiquidityBlock(entryEligible,exitOnly) ||
      (lb.isBullish && !InpShowBullishLB) ||
      (!lb.isBullish && !InpShowBearishLB) ||
      (lb.isMitigated && !InpShowMitigatedLB))
     {
      DeleteLiquidityBlockObjects(lb);
      return;
     }

   string boxId="LB_"+lb.id;
   string lblId=boxId+"_lbl";
   datetime rightEdge=lb.isMitigated ? lb.mitigationTime : extendRight;
   color boxClr=lb.isBullish ? InpColorBullishLB : InpColorBearishLB;
   if(lb.isMitigated) boxClr=InpColorMitigatedLB;
   else if(showfreshLBonly && lb.touchCount>0) boxClr=FadeColorToBG(boxClr,75);

   if(ObjectFind(0,boxId)<0)
     {
      ObjectCreate(0,boxId,OBJ_RECTANGLE,0,lb.createdTime,lb.zoneHigh,rightEdge,lb.zoneLow);
      ObjectSetInteger(0,boxId,OBJPROP_FILL,true);
      ObjectSetInteger(0,boxId,OBJPROP_BACK,true);
      ObjectSetInteger(0,boxId,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectSetInteger(0,boxId,OBJPROP_TIME,0,lb.createdTime);
      ObjectSetDouble(0,boxId,OBJPROP_PRICE,0,lb.zoneHigh);
      ObjectSetInteger(0,boxId,OBJPROP_TIME,1,rightEdge);
      ObjectSetDouble(0,boxId,OBJPROP_PRICE,1,lb.zoneLow);
     }
   ObjectSetInteger(0,boxId,OBJPROP_COLOR,boxClr);

   bool showIndForLB=!exitOnly && InpShowUnderlyingInducement &&
                     (lb.isBullish ? InpShowBuyersInducement : InpShowSellersInducement);
   string labelText=showIndForLB
                    ? lbLogic.GetDisplayNomenclature(lb,tfStr,indLogic,InpShowMitigatedInducement)
                    : lb.GetNomenclature(tfStr);
   if(showfreshLBonly && lb.touchCount>0)
      labelText+=StringFormat("-- %dx",lb.touchCount);

   string role=" [RAW]";
   if(exitOnly) role=" [RAW-GUARD]";
   else if(InpLBDisplayMode==LB_DISPLAY_ENTRY_SETUP_ONLY) role=" [ENTRY]";
   else if(InpLBDisplayMode==LB_DISPLAY_ALL && entryEligible) role="";
   labelText+=role;

   string tooltip=exitOnly
                  ? (entryEligible ? "Structurally qualified guard LB; new entries vetoed by IND overlap" : "Raw LB: structural gate not yet qualified; new entries vetoed by IND overlap")
                  : (entryEligible
                     ? "Entry-armed LB; also available to raw prevention/exit logic"
                     : "Raw LB: entry prevention / intra-position exits; entry gate not armed");
   ObjectSetString(0,boxId,OBJPROP_TOOLTIP,tooltip);

   datetime lblTime=lb.createdTime;
   ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT;
   if(InpLBLabelPos==LB_LABEL_RIGHT)
     { lblTime=rightEdge; anchor=ANCHOR_RIGHT; }
   else if(InpLBLabelPos==LB_LABEL_CENTER)
     { lblTime=lb.createdTime+(datetime)((rightEdge-lb.createdTime)/2); anchor=ANCHOR_CENTER; }
   double midPrice=lb.zoneLow+(lb.zoneHigh-lb.zoneLow)/2.0;

   if(ObjectFind(0,lblId)<0)
     {
      ObjectCreate(0,lblId,OBJ_TEXT,0,lblTime,midPrice);
      ObjectSetInteger(0,lblId,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,lblId,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,lblId,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lblId,OBJPROP_BACK,false);
      ObjectSetInteger(0,lblId,OBJPROP_ZORDER,10);
     }
   else
     {
      ObjectSetInteger(0,lblId,OBJPROP_TIME,lblTime);
      ObjectSetDouble(0,lblId,OBJPROP_PRICE,midPrice);
     }
   ObjectSetString(0,lblId,OBJPROP_TEXT,labelText);
   ObjectSetString(0,lblId,OBJPROP_TOOLTIP,tooltip);
   ObjectSetInteger(0,lblId,OBJPROP_COLOR,InpColorLBText);
   ObjectSetInteger(0,lblId,OBJPROP_ANCHOR,anchor);
  }

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
   if(rates_total < InpDepth * 2)
      return 0;

   // All engines use chronological array indices, including after a history reload.
   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false);
   ArraySetAsSeries(volume,false);
   ArraySetAsSeries(spread,false);

   datetime now=TimeCurrent();
   datetime endTime=(InpEndTime==0 || InpEndTime>now) ? now : InpEndTime;
   int window_count=WindowBarCount(rates_total,time,endTime);
   if(window_count<InpDepth*2) return 0;

   if(InpUseAnchorSlider)
      CheckAndCreateAnchorObjects();
   else
     {
      ObjectDelete(0,g_dot_name);
      ObjectDelete(0,g_vline_name);
      ObjectDelete(0,g_badge_name);
     }

   bool anchor_moved=(InpUseAnchorSlider && g_anchor_time!=g_last_calculated_anchor);
   int start=prev_calculated-1;
   // Midnight is deliberately not a reset condition. Keep swings and structure.
   if(prev_calculated==0 || prev_calculated>rates_total || anchor_moved)
     {
      int start_bar=0;
      datetime contextStart=0,historyStart=0;
      if(!ResolveWarmupStart(window_count,time,start_bar,contextStart,historyStart))
        {
         if(!g_waiting_history)
            PrintFormat("[HISTORY WARMUP] %s %s: waiting for previous-day chart history for %s. Load more chart bars if this persists.",
                        _Symbol,EnumToString(_Period),TimeToString(contextStart,TIME_DATE|TIME_MINUTES));
         g_waiting_history=true;
         if(InpUseAnchorSlider && ObjectFind(0,g_badge_name)>=0)
            ObjectSetString(0,g_badge_name,OBJPROP_TEXT," SMC: waiting for previous-day history ");
         return 0;
        }
      g_waiting_history=false;
      ResetState();
      ReinitEngines();
      zigZag.zoneStartTime=contextStart;
      zigZag.drawStartTime=contextStart;
      ms.m_drawStartTime=contextStart;
      start=start_bar;
      g_last_calculated_anchor=g_anchor_time;
      PrintFormat("[HISTORY WARMUP] %s %s: context from %s; anchor/window from %s. Previous context supplies swings/structure only; zones and drawings start at the window.",
                  _Symbol,EnumToString(_Period),TimeToString(historyStart,TIME_DATE|TIME_MINUTES),
                  TimeToString(contextStart,TIME_DATE|TIME_MINUTES));
     }

   double pipSize = GetPipSize();

   for(int i = start; i < window_count; i++)
     {
      bool is_last = (i == rates_total - 1);
      // Match the trade engines: an unfinished candle must not permanently
      // qualify/reject an IND or commit a provisional BOS/CHoCH to its history.
      if(is_last) continue;
      // Never feed the completed OHLC of a candle that was still open at the
      // historical cutoff into ZigZag, structure, qualification or mitigation.
      if(!ClosedByWindowEnd(time[i],endTime,PeriodSeconds())) break;

      zigZag.update(high[i], low[i], time[i], tick_volume[i], i, true, false);
      ms.Update(i, time, high, low, close, zigZag);

      // Warmup retains swings/structure but does not run any zone engine.
      if(time[i] < zigZag.zoneStartTime) continue;

      dsLogic.DetectPOIs(i, time, high, low, zigZag);
      dsLogic.UpdateMitigation(close[i]);

      spLogic.DetectPOIs(i, time, high, low, zigZag);
      spLogic.UpdateMitigation(close[i]);

      obLogic.DetectPOIs(i, time, high, low, zigZag);
      obLogic.UpdateMitigation(close[i]);

      fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
      fzLogic.UpdateMitigation(close[i]);

      bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);
      bbLogic.UpdateMitigation(high[i], low[i], time[i]);

      indLogic.Process(i, time, open, high, low, close,
                       zigZag, ms, dsLogic, spLogic, obLogic,
                       fzLogic, bbLogic, pipSize);

      lbLogic.Process(i, time, high, low, ms, spLogic, indLogic, zigZag);
      TrackEntrySetupLBs(time[i]);
     }

   datetime extend_right = time[rates_total - 1] + 35 * PeriodSeconds();
   if(InpEndTime>0) extend_right=(datetime)MathMin(extend_right,endTime);
   string tfStr = ms.tf_str();

// Render accepted raw LBs. The dropdown decides whether all raw blocks or only
// the chronologically armed entry subset remains visible.
   for(int l = 0; l < lbLogic.m_liquidity_blocks.Total(); l++)
     {
      CLiquidityBlock* lb = (CLiquidityBlock*)lbLogic.m_liquidity_blocks.At(l);
      if(lb!=NULL && CheckPointer(lb)==POINTER_DYNAMIC)
         RenderLiquidityBlock(lb,extend_right,tfStr,IsEntrySetupLB(lb.id),false);
     }

// Entry-vetoed sources are intentionally absent from the entry-only view but
// are part of the actual raw context consumed by prevention and open-trade exits.
   for(int l=0;l<lbLogic.m_exit_sources.Total();l++)
     {
      CLiquidityBlock* lb=(CLiquidityBlock*)lbLogic.m_exit_sources.At(l);
      if(lb!=NULL && CheckPointer(lb)==POINTER_DYNAMIC)
         RenderLiquidityBlock(lb,extend_right,tfStr,lb.guardQualifiedTime>0,true);
     }

// Render Inducements
   if(InpShowUnderlyingInducement)
     {
      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)indLogic.m_zones.At(z);
         if(zone == NULL || CheckPointer(zone) != POINTER_DYNAMIC || !zone.isInducement)
            continue;

         if(zone.isBullish && !InpShowBuyersInducement)
            continue;
         if(!zone.isBullish && !InpShowSellersInducement)
            continue;
         if(zone.isMitigated && !InpShowMitigatedInducement)
            continue;

         string boxId = "IND_" + zone.id;
         string lblId = boxId + "_lbl";

         // Draw from the source candle; qualification time remains separate for trading eligibility.
         datetime leftEdge=zone.createdTime;
         datetime rightEdge = zone.isMitigated ? zone.mitigationTime : extend_right;
         if(leftEdge<=0 || rightEdge<=leftEdge)
           { ObjectDelete(0,boxId); ObjectDelete(0,lblId); continue; }
         string tooltip="Origin: "+TimeToString(zone.createdTime,TIME_DATE|TIME_MINUTES)+
                        "\nIND known from: "+TimeToString(zone.qualifiedTime,TIME_DATE|TIME_MINUTES)+
                        "\nTouches shown are the latest total, not the count at every historical candle.";
         color boxClr = zone.isBullish ? InpColorBuyerInducement : InpColorSellerInducement;
         if(zone.isMitigated)
            boxClr = InpColorMitigated;

         if(ObjectFind(0, boxId) < 0)
           {
            ObjectCreate(0, boxId, OBJ_RECTANGLE, 0, leftEdge, zone.zoneHigh, rightEdge, zone.zoneLow);
            ObjectSetInteger(0, boxId, OBJPROP_FILL, true);
            ObjectSetInteger(0, boxId, OBJPROP_BACK, true);
            ObjectSetInteger(0, boxId, OBJPROP_SELECTABLE, false);
           }
         else
           {
            ObjectSetInteger(0, boxId, OBJPROP_TIME, 0, leftEdge);
            ObjectSetDouble(0, boxId, OBJPROP_PRICE, 0, zone.zoneHigh);
            ObjectSetInteger(0, boxId, OBJPROP_TIME, 1, rightEdge);
            ObjectSetDouble(0, boxId, OBJPROP_PRICE, 1, zone.zoneLow);
           }
         ObjectSetInteger(0, boxId, OBJPROP_COLOR, boxClr);
         ObjectSetString(0,boxId,OBJPROP_TOOLTIP,tooltip);

         CLiquidityBlock* containingLB = lbLogic.GetContainingLiquidityBlock(zone);
         bool mergeLabel = (containingLB != NULL && CheckPointer(containingLB) == POINTER_DYNAMIC);
         if(mergeLabel && containingLB.isBullish && !InpShowBullishLB)
            mergeLabel = false;
         if(mergeLabel && !containingLB.isBullish && !InpShowBearishLB)
            mergeLabel = false;
         if(mergeLabel && containingLB.isMitigated && !InpShowMitigatedLB)
            mergeLabel = false;
         if(mergeLabel && !ShouldRenderLiquidityBlock(IsEntrySetupLB(containingLB.id),false))
            mergeLabel = false;
         if(mergeLabel)
           {
            ObjectDelete(0, lblId);
            continue;
           }

         string touchSuffix = InpShowTouchCount ? StringFormat("-%d", zone.touchCount) : "";
         string labelText   = tfStr + (zone.isBullish ? "-BL-IND" : "-BR-IND") + touchSuffix;

         datetime lblTime = leftEdge;
         ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT;

         if(InpLabelPosition == LABEL_POS_RIGHT)
           {
            lblTime = rightEdge;
            anchor = ANCHOR_RIGHT;
           }
         else
            if(InpLabelPosition == LABEL_POS_CENTER)
              {
               lblTime = leftEdge + (datetime)((rightEdge - leftEdge) / 2);
               anchor  = ANCHOR_CENTER;
              }

         double midPrice = zone.zoneLow + (zone.zoneHigh - zone.zoneLow) / 2.0;

         if(ObjectFind(0, lblId) < 0)
           {
            ObjectCreate(0, lblId, OBJ_TEXT, 0, lblTime, midPrice);
            ObjectSetInteger(0, lblId, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, lblId, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, lblId, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lblId, OBJPROP_BACK, false);
            ObjectSetInteger(0, lblId, OBJPROP_ZORDER, 10);
           }
         else
           {
            ObjectSetInteger(0, lblId, OBJPROP_TIME, lblTime);
            ObjectSetDouble(0, lblId, OBJPROP_PRICE, midPrice);
           }

         ObjectSetString(0, lblId, OBJPROP_TEXT, labelText);
         ObjectSetString(0,lblId,OBJPROP_TOOLTIP,tooltip);
         ObjectSetInteger(0, lblId, OBJPROP_COLOR, InpColorText);
         ObjectSetInteger(0, lblId, OBJPROP_ANCHOR, anchor);
        }
     }
   else
     {
      ObjectsDeleteAll(0, "IND_");
     }

   ChartRedraw(0);
   return(rates_total);
  }
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\Marcotrades\liquiduity_block.mq5
