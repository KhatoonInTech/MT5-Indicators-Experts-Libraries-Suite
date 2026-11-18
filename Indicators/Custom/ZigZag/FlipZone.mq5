#define MARCO_LOG_PROGRAM "FlipZone"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                  Indicators\Custom\ZigZag\FlipZone.mq5  |
//|                 Smart Money Concepts: Flip Zones                 |
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
#include <Custom\ZigZag\flipzone.mqh>
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

input group "Flip Zone UI Settings"
input bool   showDemandFlipZones      = true;         // Display DEMAND Flip Zones (Go LONG)
input bool   showSupplyFlipZones      = true;         // Display SUPPLY Flip Zones (Go SHORT)
input bool   showMitigatedFlipZones   = false;        // Display historically mitigated zones

input group "System Performance"
input int    maxLookbackBars          = 3000;         // Max historical bars to scan

// --- Engines & Logic Classes ---
ZigZag*             zigZag = NULL;
CMarketStructure*   ms = NULL;
CDemandSupplyLogic* dsLogic = NULL;
CFlipZoneLogic*     fzLogic = NULL;

CArrayObj fz_Boxes; // Collection array holding raw PineBox graphic instances

color FLIP_DEMAND_COLOR;
color FLIP_SUPPLY_COLOR;
color FLIP_MITIG_COLOR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
// Instantiate parameters and engines
   Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, false, false, false, priceDiffInput);
   s.draw = showZigZagLines;
   zigZag = newInstance(s);

   ms = new CMarketStructure();
   ms.Init(showBosChoch, showSwingHL);

   dsLogic = new CDemandSupplyLogic();
   fzLogic = new CFlipZoneLogic();

// Configure ARGB translucent color layers
   FLIP_DEMAND_COLOR = ColorToARGB_Custom(clrGreen, 46); // Light green background
   FLIP_SUPPLY_COLOR = ColorToARGB_Custom(clrRed, 46);   // Light red background
   FLIP_MITIG_COLOR  = ColorToARGB_Custom(clrGray, 46);  // Dead neutral grey

   fz_Boxes.FreeMode(true);
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
   if(fzLogic != NULL)
      delete fzLogic;

   ObjectsDeleteAll(0, "ZZ_Ln_");
   ObjectsDeleteAll(0, "ZZ_Lbl_");
   ObjectsDeleteAll(0, "ZZ_Proj_");
   ObjectsDeleteAll(0, "FLIP_");
  }

//+------------------------------------------------------------------+
//| Force clean wipe on calculations reset                           |
//+------------------------------------------------------------------+
void ResetState()
  {
   if(ms != NULL)
      ms.ResetState();
   if(dsLogic != NULL)
      dsLogic.ResetState();
   if(fzLogic != NULL)
      fzLogic.ResetState();
   fz_Boxes.Clear();
   ObjectsDeleteAll(0, "FLIP_");
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

      // Update core data flows
      zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
      ms.Update(i, time, high, low, close, zigZag);

      dsLogic.DetectPOIs(i, time, high, low, zigZag);
      dsLogic.UpdateMitigation(close[i]);

      int old_fz_count = fzLogic.fz_time.Total();

      // Update calculations for Flip Zones
      fzLogic.DetectFlipZones(i, time, high, low, close, zigZag, ms, dsLogic);
      fzLogic.UpdateMitigation(close[i]);

      datetime fz_extend_right = time[i] + 50 * PeriodSeconds();

      // --- RENDER FRESH FLIP ZONES ---
      if(fzLogic.fz_time.Total() > old_fz_count)
        {
         datetime p_time = (datetime)fzLogic.fz_time.At(fzLogic.fz_time.Total() - 1);
         double z_high   = fzLogic.fz_zoneHigh.At(fzLogic.fz_zoneHigh.Total() - 1);
         double z_low    = fzLogic.fz_zoneLow.At(fzLogic.fz_zoneLow.Total() - 1);
         int z_type      = fzLogic.fz_type.At(fzLogic.fz_type.Total() - 1);

         string prefix = (z_type == 1) ? "FLIP_D_" : "FLIP_S_";
         PineBox* fBox = new PineBox(prefix + IntegerToString(p_time));
         fBox.set_bounds(p_time, z_high, fz_extend_right, z_low);
         fBox.set_bgcolor(POI_TRANSPARENT);
         fBox.set_text_color(POI_TRANSPARENT);
         fBox.set_text("");
         fz_Boxes.Add(fBox);
        }

      // --- DYNAMIC GRAPHICAL UPDATES ---
      for(int m = 0; m < fz_Boxes.Total(); m++)
        {
         PineBox* b = (PineBox*)fz_Boxes.At(m);
         bool mit   = (fzLogic.fz_mitigated.At(m) == 1);
         int z_type = fzLogic.fz_type.At(m);

         // Keep stretching fresh zones horizontally to current bar
         if(!mit)
            b.set_right(fz_extend_right);

         // Display DEMAND Flip Zones (BULLISH)
         if(z_type == 1)
           {
            if(!mit)
              {
               b.set_bgcolor(showDemandFlipZones ? FLIP_DEMAND_COLOR : POI_TRANSPARENT);
               b.set_text_color(showDemandFlipZones ? clrGreen : POI_TRANSPARENT);
               b.set_text(ms.tf_str() + " DEMAND FLIP (LONG SETUP)");
              }
            else
              {
               if(showMitigatedFlipZones)
                 {
                  b.set_bgcolor(FLIP_MITIG_COLOR);
                  b.set_text_color(clrGray);
                  b.set_text(ms.tf_str() + " DEMAND FLIP [MITIGATED]");
                 }
               else
                 {
                  b.set_bgcolor(POI_TRANSPARENT);
                  b.set_text_color(POI_TRANSPARENT);
                  b.set_text("");
                 }
              }
           }
         // Display SUPPLY Flip Zones (BEARISH)
         else
            if(z_type == -1)
              {
               if(!mit)
                 {
                  b.set_bgcolor(showSupplyFlipZones ? FLIP_SUPPLY_COLOR : POI_TRANSPARENT);
                  b.set_text_color(showSupplyFlipZones ? clrRed : POI_TRANSPARENT);
                  b.set_text(ms.tf_str() + " SUPPLY FLIP (SHORT SETUP)");
                 }
               else
                 {
                  if(showMitigatedFlipZones)
                    {
                     b.set_bgcolor(FLIP_MITIG_COLOR);
                     b.set_text_color(clrGray);
                     b.set_text(ms.tf_str() + " SUPPLY FLIP [MITIGATED]");
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

// END FILE: Indicators\Custom\ZigZag\FlipZone.mq5

// END FILE: Indicators\Custom\ZigZag\FlipZone.mq5
