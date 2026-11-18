#define MARCO_LOG_PROGRAM "SwingPOIs"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                 Indicators\Custom\ZigZag\SwingPOIs.mq5  |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.06"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Arrays\ArrayObj.mqh>

input group "Visibility"
input bool   showZigZagInput          = true;        // Show Zig Zag Lines
input bool   showBosChochInput        = true;         // Show BOS & CHoCH
input bool   showSwingHLInput         = true;         // Show Latest Swing H/L

input group "Zig Zag Settings"
input double deviationInput           = 1;         // Price deviation for reversals (%)
input int    depthInput               = 15;            // Pivot legs
input color  lineColorInput           = clrGold;      // Line color
input bool   extendInput              = true;         // Extend to last bar
input bool   showPriceInput           = false;         // Display reversal price
input bool   showVolInput             = false;         // Display cumulative volume
input bool   showChgInput             = false;         // Display reversal price change
input string priceDiffInput           = "Percent";   // Difference Mode (Absolute/Percent)

input group "Swing POIs"
input bool   showBullishPOI           = false;         // Display Unmitigated Bullish POI
input bool   showBearishPOI           = false;         // Display Unmitigated Bearish POI
input bool   showMitigatedBullishPOI  = false;        // Display Mitigated Bullish POI
input bool   showMitigatedBearishPOI  = false;        // Display Mitigated Bearish POI

input group "Performance"
input int    maxLookbackBars          = 3000;         // Max Historical Bars to Calculate

ZigZag* zigZag = NULL;
CMarketStructure* ms = NULL;
CSwingPOILogic* spLogic = NULL;

CArrayObj poi_demandBoxes;
CArrayObj poi_supplyBoxes;

color POI_SWING_BULL_FILL;
color POI_SWING_BULL_TEXT;
color POI_SWING_BEAR_FILL;
color POI_SWING_BEAR_TEXT;
color POI_SWING_MITIG_FILL;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, showZigZagInput ? showPriceInput : false, showZigZagInput ? showVolInput : false, showZigZagInput ? showChgInput : false, priceDiffInput);
   s.draw = showZigZagInput;
   zigZag = newInstance(s);

   ms = new CMarketStructure();
   ms.Init(showBosChochInput, showSwingHLInput);

   spLogic = new CSwingPOILogic();

   POI_SWING_BULL_FILL = ColorToARGB_Custom(C'0,100,0', 51);
   POI_SWING_BULL_TEXT = C'0,100,0';
   POI_SWING_BEAR_FILL = ColorToARGB_Custom(C'128,0,0', 51);
   POI_SWING_BEAR_TEXT = C'128,0,0';
   POI_SWING_MITIG_FILL = ColorToARGB_Custom(clrGray, 46);

   poi_demandBoxes.FreeMode(true);
   poi_supplyBoxes.FreeMode(true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   if(zigZag != NULL)
      delete zigZag;
   if(ms != NULL)
      delete ms;
   if(spLogic != NULL)
      delete spLogic;
   ObjectsDeleteAll(0, "ZZ_Ln_");
   ObjectsDeleteAll(0, "ZZ_Lbl_");
   ObjectsDeleteAll(0, "ZZ_Proj_");
   ObjectsDeleteAll(0, "POI_");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetState()
  {
   if(ms != NULL)
      ms.ResetState();
   if(spLogic != NULL)
      spLogic.ResetState();
   poi_demandBoxes.Clear();
   poi_supplyBoxes.Clear();
   ObjectsDeleteAll(0, "POI_");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   g_marcoDailyLog.Pulse();
   if(rates_total < depthInput * 2)
      return 0;
   if(prev_calculated == 0)
      ResetState();

// Ensure we don't calculate further back than maxLookbackBars OnCalculate()
   int start_bar = 0;
   if(rates_total > maxLookbackBars)
      start_bar = rates_total - maxLookbackBars;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : start_bar;

   for(int i = start; i < rates_total; i++)
     {
      bool is_last = (i == rates_total - 1);

      zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
      ms.Update(i, time, high, low, close, zigZag);

      int old_d = spLogic.poi_demandTime.Total();
      int old_s = spLogic.poi_supplyTime.Total();

      spLogic.DetectPOIs(i, time, high, low, zigZag);
      spLogic.UpdateMitigation(close[i]);

      datetime poi_extend_right = time[i] + 50 * PeriodSeconds();

      if(spLogic.poi_demandTime.Total() > old_d)
        {
         datetime p_time = (datetime)spLogic.poi_demandTime.At(spLogic.poi_demandTime.Total() - 1);
         double z_high = spLogic.poi_demandZoneHigh.At(spLogic.poi_demandZoneHigh.Total() - 1);
         double z_low = spLogic.poi_demandZoneLow.At(spLogic.poi_demandZoneLow.Total() - 1);
         PineBox* dBox = new PineBox("POI_D_" + IntegerToString(p_time));
         dBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
         dBox.set_bgcolor(POI_TRANSPARENT);
         dBox.set_text_color(POI_TRANSPARENT);
         dBox.set_text("");
         poi_demandBoxes.Add(dBox);
        }
      if(spLogic.poi_supplyTime.Total() > old_s)
        {
         datetime p_time = (datetime)spLogic.poi_supplyTime.At(spLogic.poi_supplyTime.Total() - 1);
         double z_high = spLogic.poi_supplyZoneHigh.At(spLogic.poi_supplyZoneHigh.Total() - 1);
         double z_low = spLogic.poi_supplyZoneLow.At(spLogic.poi_supplyZoneLow.Total() - 1);
         PineBox* sBox = new PineBox("POI_S_" + IntegerToString(p_time));
         sBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
         sBox.set_bgcolor(POI_TRANSPARENT);
         sBox.set_text_color(POI_TRANSPARENT);
         sBox.set_text("");
         poi_supplyBoxes.Add(sBox);
        }

      for(int m = 0; m < poi_demandBoxes.Total(); m++)
        {
         PineBox* b = (PineBox*)poi_demandBoxes.At(m);
         bool mit = (spLogic.poi_demandMitigated.At(m) == 1);
         datetime box_time = b.left;

         if(!mit)
            b.set_right(poi_extend_right);
         bool is_bull_poi = spLogic.ob_time_found(&ms.ob_bull_struct_times, box_time);

         if(is_bull_poi)
           {
            if(!mit)
              {
               if(showBullishPOI)
                 {
                  b.set_bgcolor(POI_SWING_BULL_FILL);
                  b.set_text_color(POI_SWING_BULL_TEXT);
                  b.set_text(ms.tf_str() + " BULLISH POI");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
            else
              {
               if(showMitigatedBullishPOI)
                 {
                  b.set_bgcolor(POI_SWING_MITIG_FILL);
                  b.set_text_color(clrGray);
                  b.set_text(ms.tf_str() + " BULLISH POI");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
           }
         else
           {
            b.set_bgcolor(POI_TRANSPARENT);
            b.set_text_color(POI_TRANSPARENT);
            b.set_text("");
           }
        }

      for(int m = 0; m < poi_supplyBoxes.Total(); m++)
        {
         PineBox* b = (PineBox*)poi_supplyBoxes.At(m);
         bool mit = (spLogic.poi_supplyMitigated.At(m) == 1);
         datetime box_time = b.left;

         if(!mit)
            b.set_right(poi_extend_right);
         bool is_bear_poi = spLogic.ob_time_found(&ms.ob_bear_struct_times, box_time);

         if(is_bear_poi)
           {
            if(!mit)
              {
               if(showBearishPOI)
                 {
                  b.set_bgcolor(POI_SWING_BEAR_FILL);
                  b.set_text_color(POI_SWING_BEAR_TEXT);
                  b.set_text(ms.tf_str() + " BEARISH POI");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
            else
              {
               if(showMitigatedBearishPOI)
                 {
                  b.set_bgcolor(POI_SWING_MITIG_FILL);
                  b.set_text_color(clrGray);
                  b.set_text(ms.tf_str() + " BEARISH POI");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
           }
         else
           {
            b.set_bgcolor(POI_TRANSPARENT);
            b.set_text_color(POI_TRANSPARENT);
            b.set_text("");
           }
        }
     }
     
   return rates_total;
  }
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\ZigZag\SwingPOIs.mq5

// END FILE: Indicators\Custom\ZigZag\SwingPOIs.mq5
