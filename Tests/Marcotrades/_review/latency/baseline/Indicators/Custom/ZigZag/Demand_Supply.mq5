#define MARCO_LOG_PROGRAM "Demand_Supply"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                              Indicators\Custom\ZigZag\DemandSupply.mq5  |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.06"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
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

input group "POI Zones"
input bool   showDemandZones          = true;         // Display Demand Zones
input bool   showSupplyZones          = true;         // Display Supply Zones
input bool   showMitigatedDemandZones = false;        // Display Mitigated Demand Zones
input bool   showMitigatedSupplyZones = false;        // Display Mitigated Supply Zones

input group "Performance"
input int    maxLookbackBars          = 3000;         // Max Historical Bars to Calculate

ZigZag* zigZag = NULL;
CMarketStructure* ms = NULL;
CDemandSupplyLogic* dsLogic = NULL;

CArrayObj poi_demandBoxes;
CArrayObj poi_supplyBoxes;

color POI_DEMAND_COLOR;  
color POI_SUPPLY_COLOR;  
color POI_MITIG_COLOR;   

int OnInit() {
   g_marcoDailyLog.Start();
    Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, showZigZagInput ? showPriceInput : false, showZigZagInput ? showVolInput : false, showZigZagInput ? showChgInput : false, priceDiffInput);
    s.draw = showZigZagInput;
    zigZag = newInstance(s);
    
    ms = new CMarketStructure();
    ms.Init(showBosChochInput, showSwingHLInput);
    
    dsLogic = new CDemandSupplyLogic();
    
    POI_DEMAND_COLOR = ColorToARGB_Custom(clrGreen, 46);
    POI_SUPPLY_COLOR = ColorToARGB_Custom(clrRed, 46);
    POI_MITIG_COLOR  = ColorToARGB_Custom(clrGray, 46);

    poi_demandBoxes.FreeMode(true);
    poi_supplyBoxes.FreeMode(true);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
    if(zigZag != NULL) delete zigZag;
    if(ms != NULL) delete ms;
    if(dsLogic != NULL) delete dsLogic;
    ObjectsDeleteAll(0, "ZZ_Ln_"); ObjectsDeleteAll(0, "ZZ_Lbl_"); ObjectsDeleteAll(0, "ZZ_Proj_");
    ObjectsDeleteAll(0, "POI_");
}

void ResetState() {
    if(ms != NULL) ms.ResetState();
    if(dsLogic != NULL) dsLogic.ResetState();
    poi_demandBoxes.Clear();
    poi_supplyBoxes.Clear();
    ObjectsDeleteAll(0, "POI_");
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
   g_marcoDailyLog.Pulse();
    // FORCE ARRAY ORDERING TO MATCH PINE SCRIPT
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(volume, true);

    if(rates_total < depthInput * 2) return 0;
    if(prev_calculated == 0) ResetState();

    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
    
    for(int i = start; i < rates_total; i++) {
        // Pine Script index 0 is always the latest bar. 
        // With ArraySetAsSeries(true), index 0 IS the latest bar.
        bool is_last = (i == rates_total - 1);
        
        zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
        ms.Update(i, time, high, low, close, zigZag);
        int old_d = dsLogic.poi_demandTime.Total();
        int old_s = dsLogic.poi_supplyTime.Total();

        dsLogic.DetectPOIs(i, time, high, low, zigZag);
        dsLogic.UpdateMitigation(close[i]);

        datetime poi_extend_right = time[i] + 50 * PeriodSeconds();

        // Sync GUI New Boxes
        if (dsLogic.poi_demandTime.Total() > old_d) {
            datetime p_time = (datetime)dsLogic.poi_demandTime.At(dsLogic.poi_demandTime.Total() - 1);
            double z_high = dsLogic.poi_demandZoneHigh.At(dsLogic.poi_demandZoneHigh.Total() - 1);
            double z_low = dsLogic.poi_demandZoneLow.At(dsLogic.poi_demandZoneLow.Total() - 1);
            PineBox* dBox = new PineBox("POI_D_" + IntegerToString(p_time));
            dBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
            poi_demandBoxes.Add(dBox);
        }
        if (dsLogic.poi_supplyTime.Total() > old_s) {
            datetime p_time = (datetime)dsLogic.poi_supplyTime.At(dsLogic.poi_supplyTime.Total() - 1);
            double z_high = dsLogic.poi_supplyZoneHigh.At(dsLogic.poi_supplyZoneHigh.Total() - 1);
            double z_low = dsLogic.poi_supplyZoneLow.At(dsLogic.poi_supplyZoneLow.Total() - 1);
            PineBox* sBox = new PineBox("POI_S_" + IntegerToString(p_time));
            sBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
            poi_supplyBoxes.Add(sBox);
        }

        // Morphing GUI state
        for(int m = 0; m < poi_demandBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_demandBoxes.At(m);
            bool mit = (dsLogic.poi_demandMitigated.At(m) == 1);
            
            if (!mit) b.set_right(poi_extend_right);
            
            if (!mit) {
                b.set_bgcolor(showDemandZones ? POI_DEMAND_COLOR : POI_TRANSPARENT);
                b.set_text_color(showDemandZones ? clrGreen : POI_TRANSPARENT);
                b.set_text(ms.tf_str() + "-DemandZone");
            } else {
                if (showMitigatedDemandZones) { b.set_bgcolor(POI_MITIG_COLOR); b.set_text_color(clrGray); }
                else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
            }
        }

        for(int m = 0; m < poi_supplyBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_supplyBoxes.At(m);
            bool mit = (dsLogic.poi_supplyMitigated.At(m) == 1);
            
            if (!mit) b.set_right(poi_extend_right);

            if (!mit) {
                b.set_bgcolor(showSupplyZones ? POI_SUPPLY_COLOR : POI_TRANSPARENT);
                b.set_text_color(showSupplyZones ? clrRed : POI_TRANSPARENT);
                b.set_text(ms.tf_str() + "-SupplyZone");
            } else {
                if (showMitigatedSupplyZones) { b.set_bgcolor(POI_MITIG_COLOR); b.set_text_color(clrGray); }
                else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); }
            }
        }
    }
    return rates_total;
}

// END FILE: Indicators\Custom\ZigZag\Demand_Supply.mq5

// END FILE: Indicators\Custom\ZigZag\Demand_Supply.mq5
