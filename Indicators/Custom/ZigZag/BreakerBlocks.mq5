#define MARCO_LOG_PROGRAM "BreakerBlocks"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                              Indicators\Custom\ZigZag\BreakerBlocks.mq5 |
//|                 Smart Money Concepts: Breaker Blocks             |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\ZigZag\order_blocks.mqh>
#include <Custom\ZigZag\flipzone.mqh>
#include <Custom\ZigZag\breaker_blocks.mqh>
#include <Arrays\ArrayObj.mqh>

input group "Visibility Settings"
input bool   showZigZagLines          = true;         // Display standard Zig Zag lines
input bool   showBosChoch             = true;         // Display Structural breaks
input bool   showSwingHL              = true;         // Display latest Swing High/Low lines

input group "Structural Calculations"
input double deviationInput           = 1.0;          // Deviation threshold for pivots (%)
input int    depthInput               = 15;           // Lookback depth for structural swings
input color  lineColorInput           = clrGold;      // Zig Zag line color
input bool   extendInput              = true;         // Extrapolate projections to last bar
input string priceDiffInput           = "Percent";    // Diff Mode (Absolute/Percent)

input group "Breaker Blocks Settings"
input bool   showBullishBreakerBlock          = true;  // Display Unmitigated Bullish Breaker Blocks
input bool   showBearishBreakerBlock           = true;  // Display Unmitigated Bearish Breaker Blocks
input bool   showMitigatedBullishBreakerBlock  = false; // Display Mitigated Bullish Breaker Blocks
input bool   showMitigatedBearishBreakerBlock  = false; // Display Mitigated Bearish Breaker Blocks

input group "System Performance"
input int    maxLookbackBars          = 3000;         // Max historical bars to scan

// --- Engines & Logic Classes ---
ZigZag*             zigZag = NULL;
CMarketStructure*   ms = NULL;
CDemandSupplyLogic* dsLogic = NULL;
CSwingPOILogic*    spLogic = NULL;
COrderBlockLogic*  obLogic = NULL;
CFlipZoneLogic*     fzLogic = NULL;
CBreakerBlockLogic* bbLogic = NULL;

CArrayObj bb_Boxes; // Array holding PineBox visual objects

color BB_BULL_COLOR;
color BB_BEAR_COLOR;
color BB_MITIG_COLOR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, false, false, false, priceDiffInput);
   s.draw = showZigZagLines;
   zigZag = newInstance(s);

   ms = new CMarketStructure();
   ms.Init(showBosChoch, showSwingHL);

   dsLogic = new CDemandSupplyLogic();
   spLogic = new CSwingPOILogic();
   obLogic = new COrderBlockLogic();
   fzLogic = new CFlipZoneLogic();
   bbLogic = new CBreakerBlockLogic();

// Translucent configuration ARGB colors
   BB_BULL_COLOR  = ColorToARGB_Custom(clrGreen, 46);
   BB_BEAR_COLOR  = ColorToARGB_Custom(clrRed, 46);
   BB_MITIG_COLOR = ColorToARGB_Custom(clrGray, 46);

   bb_Boxes.FreeMode(true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   if(zigZag != NULL)
      delete zigZag;
   if(ms != NULL)
      delete ms;
   if(dsLogic != NULL)
      delete dsLogic;
   if(spLogic != NULL)
      delete spLogic;
   if(obLogic != NULL)
      delete obLogic;
   if(fzLogic != NULL)
      delete fzLogic;
   if(bbLogic != NULL)
      delete bbLogic;

   ObjectsDeleteAll(0, "ZZ_Ln_");
   ObjectsDeleteAll(0, "ZZ_Lbl_");
   ObjectsDeleteAll(0, "ZZ_Proj_");
   ObjectsDeleteAll(0, "BB_");
  }

//+------------------------------------------------------------------+
//| Calculations Reset                                               |
//+------------------------------------------------------------------+
void ResetState()
  {
   if(ms != NULL)
      ms.ResetState();
   if(dsLogic != NULL)
      dsLogic.ResetState();
   if(spLogic != NULL)
      spLogic.ResetState();
   if(obLogic != NULL)
      obLogic.ResetState();
   if(fzLogic != NULL)
      fzLogic.ResetState();
   if(bbLogic != NULL)
      bbLogic.ResetState();
   bb_Boxes.Clear();
   ObjectsDeleteAll(0, "BB_");
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
   if(rates_total < depthInput * 2)
      return 0;
   if(prev_calculated == 0)
      ResetState();

   int start_bar = 0;
   if(rates_total > maxLookbackBars)
      start_bar = rates_total - maxLookbackBars;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : start_bar;

   for(int i = start; i < rates_total; i++)
     {
      bool is_last = (i == rates_total - 1);

      // Sourcing historical feeds
      zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
      ms.Update(i, time, high, low, close, zigZag);

      dsLogic.DetectPOIs(i, time, high, low, zigZag);
      dsLogic.UpdateMitigation(close[i]);

      spLogic.DetectPOIs(i, time, high, low, zigZag);
      spLogic.UpdateMitigation(close[i]);

      obLogic.DetectPOIs(i, time, high, low, zigZag);
      obLogic.UpdateMitigation(close[i]);

      fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
      fzLogic.UpdateMitigation(close[i]);

      // MQL5 specific processing loop for nested structural OB validation
      if(obLogic.poi_demandTime.Total() > 0)
        {
         datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
         if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz))
           {
            if(obLogic.CheckBullishOB(tz, i, time, high, low))
               obLogic.ob_bull_valid_times.Add((long)tz);
           }
        }
      if(obLogic.poi_supplyTime.Total() > 0)
        {
         datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
         if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz))
           {
            if(obLogic.CheckBearishOB(tz, i, time, high, low))
               obLogic.ob_bear_valid_times.Add((long)tz);
           }
        }

      int old_bb_count = bbLogic.bb_time.Total();

      // Calculation and extreme limits mitigation process for Breakers
      bbLogic.DetectBreakers(zigZag, dsLogic, spLogic, obLogic, fzLogic);
      bbLogic.UpdateMitigation(high[i], low[i], time[i]);

      datetime bb_extend_right = time[i] + 50 * PeriodSeconds();

      // --- INSTANTIATE DETECTED BREAKER BLOCKS ---
      if(bbLogic.bb_time.Total() > old_bb_count)
        {
         datetime p_time = (datetime)bbLogic.bb_time.At(bbLogic.bb_time.Total() - 1);
         double z_high   = bbLogic.bb_zoneHigh.At(bbLogic.bb_zoneHigh.Total() - 1);
         double z_low    = bbLogic.bb_zoneLow.At(bbLogic.bb_zoneLow.Total() - 1);
         int z_type      = bbLogic.bb_type.At(bbLogic.bb_type.Total() - 1);

         string prefix = (z_type == 1) ? "BB_BULL_" : "BB_BEAR_";
         PineBox* fBox = new PineBox(prefix + IntegerToString(p_time));
         fBox.set_bounds(p_time, z_high, bb_extend_right, z_low);
         fBox.set_bgcolor(POI_TRANSPARENT);
         fBox.set_text_color(POI_TRANSPARENT);
         fBox.set_text("");
         bb_Boxes.Add(fBox);
        }

      // --- DYNAMIC GRAPHICAL RENDERING ---
      for(int m = 0; m < bb_Boxes.Total(); m++)
        {
         PineBox* b = (PineBox*)bb_Boxes.At(m);
         bool mit   = (bbLogic.bb_mitigated.At(m) == 1);
         int z_type = bbLogic.bb_type.At(m);
         datetime mit_time = (datetime)bbLogic.bb_mitigation_time.At(m);

         // Stretch the box horizontally, or freeze the right-edge exactly at the mitigation time
         if(!mit)
            b.set_right(bb_extend_right);
         else
            b.set_right(mit_time);

         // Display Bullish Breaker Block
         if(z_type == 1)
           {
            if(!mit)
              {
               b.set_bgcolor(showBullishBreakerBlock ? BB_BULL_COLOR : POI_TRANSPARENT);
               b.set_text_color(showBullishBreakerBlock ? clrGreen : POI_TRANSPARENT);
               b.set_text(ms.tf_str() + "-Bullish-Breaker-Block");
              }
            else
              {
               if(showMitigatedBullishBreakerBlock)
                 {
                  b.set_bgcolor(BB_MITIG_COLOR);
                  b.set_text_color(clrGray);
                  b.set_text(ms.tf_str() + "-Bullish-Breaker-Block");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
           }
         // Display Bearish Breaker Block
         else
            if(z_type == -1)
              {
               if(!mit)
                 {
                  b.set_bgcolor(showBearishBreakerBlock ? BB_BEAR_COLOR : POI_TRANSPARENT);
                  b.set_text_color(showBearishBreakerBlock ? clrRed : POI_TRANSPARENT);
                  b.set_text(ms.tf_str() + "-Bearish-Breaker-Block");
                 }
               else
                 {
                  if(showMitigatedBearishBreakerBlock)
                    {
                     b.set_bgcolor(BB_MITIG_COLOR);
                     b.set_text_color(clrGray);
                     b.set_text(ms.tf_str() + "-Bearish-Breaker-Block");
                    }
                  else
                    {
                     b.set_bgcolor(POI_TRANSPARENT);
                     b.set_text_color(POI_TRANSPARENT);
                     b.set_text("");
                    }
                 }
              }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\ZigZag\BreakerBlocks.mq5

// END FILE: Indicators\Custom\ZigZag\BreakerBlocks.mq5
