//+------------------------------------------------------------------+
//|                              Indicators\ZigZag\OrderBlocks.mq5   |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.06"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <ZigZag\ZigZag.mqh>
#include <ZigZag\market_structure.mqh>
#include <ZigZag\mql_plotting.mqh>
#include <ZigZag\order_blocks.mqh>
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
input bool   showPriceInput           = true;         // Display reversal price
input bool   showVolInput             = true;         // Display cumulative volume
input bool   showChgInput             = true;         // Display reversal price change
input string priceDiffInput           = "Percent";   // Difference Mode (Absolute/Percent)

input group "Order Blocks"
input bool   showBullishOB            = true;         // Display Bullish Order Blocks
input bool   showBearishOB            = true;         // Display Bearish Order Blocks
input bool   showMitigatedBullishOB   = false;        // Display Mitigated Bullish Order Blocks
input bool   showMitigatedBearishOB   = false;        // Display Mitigated Bearish Order Blocks

input group "Performance"
input int    maxLookbackBars          = 3000;         // Max Historical Bars to Calculate

ZigZag* zigZag = NULL;
CMarketStructure* ms = NULL;
COrderBlockLogic* obLogic = NULL;

CArrayObj poi_demandBoxes;
CArrayObj poi_supplyBoxes;

color OB_BULL_FILL;      color OB_BULL_TEXT;
color OB_BEAR_FILL;      color OB_BEAR_TEXT;
color OB_MITIG_FILL;     

int OnInit() {
    Settings* s = new Settings(deviationInput, depthInput, lineColorInput, extendInput, showZigZagInput ? showPriceInput : false, showZigZagInput ? showVolInput : false, showZigZagInput ? showChgInput : false, priceDiffInput);
    s.draw = showZigZagInput;
    zigZag = newInstance(s);
    
    ms = new CMarketStructure();
    ms.Init(showBosChochInput, showSwingHLInput);
    
    obLogic = new COrderBlockLogic();
    
    OB_BULL_FILL     = ColorToARGB_Custom(C'10,123,167', 51);
    OB_BULL_TEXT     = C'10,123,167';
    OB_BEAR_FILL     = ColorToARGB_Custom(C'173,86,145', 51);
    OB_BEAR_TEXT     = C'173,86,145';
    OB_MITIG_FILL    = ColorToARGB_Custom(clrGray, 46);

    poi_demandBoxes.FreeMode(true);
    poi_supplyBoxes.FreeMode(true);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    if(zigZag != NULL) delete zigZag;
    if(ms != NULL) delete ms;
    if(obLogic != NULL) delete obLogic;
    ObjectsDeleteAll(0, "ZZ_Ln_"); ObjectsDeleteAll(0, "ZZ_Lbl_"); ObjectsDeleteAll(0, "ZZ_Proj_");
    ObjectsDeleteAll(0, "POI_");
}

void ResetState() {
    if(ms != NULL) ms.ResetState();
    if(obLogic != NULL) obLogic.ResetState();
    poi_demandBoxes.Clear();
    poi_supplyBoxes.Clear();
    ObjectsDeleteAll(0, "POI_");
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
    if(rates_total < depthInput * 2) return 0;
    if(prev_calculated == 0) ResetState();

    // Ensure we don't calculate further back than maxLookbackBars OnCalculate()
    int start_bar = 0;
    if(rates_total > maxLookbackBars) start_bar = rates_total - maxLookbackBars;

    int start = (prev_calculated > 0) ? prev_calculated - 1 : start_bar;
    
    for(int i = start; i < rates_total; i++) {
        bool is_last = (i == rates_total - 1);
        
        zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
        ms.Update(i, time, high, low, close, zigZag);

        int old_d = obLogic.poi_demandTime.Total();
        int old_s = obLogic.poi_supplyTime.Total();

        obLogic.DetectPOIs(i, time, high, low, zigZag);
        obLogic.UpdateMitigation(close[i]);

        datetime poi_extend_right = time[i] + 50 * PeriodSeconds();

        if (obLogic.poi_demandTime.Total() > old_d) {
            datetime p_time = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
            double z_high = obLogic.poi_demandZoneHigh.At(obLogic.poi_demandZoneHigh.Total() - 1);
            double z_low = obLogic.poi_demandZoneLow.At(obLogic.poi_demandZoneLow.Total() - 1);
            PineBox* dBox = new PineBox("POI_D_" + IntegerToString(p_time));
            dBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
            dBox.set_bgcolor(POI_TRANSPARENT); dBox.set_text_color(POI_TRANSPARENT); dBox.set_text("");
            poi_demandBoxes.Add(dBox);
        }
        if (obLogic.poi_supplyTime.Total() > old_s) {
            datetime p_time = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
            double z_high = obLogic.poi_supplyZoneHigh.At(obLogic.poi_supplyZoneHigh.Total() - 1);
            double z_low = obLogic.poi_supplyZoneLow.At(obLogic.poi_supplyZoneLow.Total() - 1);
            PineBox* sBox = new PineBox("POI_S_" + IntegerToString(p_time));
            sBox.set_bounds(p_time, z_high, poi_extend_right, z_low);
            sBox.set_bgcolor(POI_TRANSPARENT); sBox.set_text_color(POI_TRANSPARENT); sBox.set_text("");
            poi_supplyBoxes.Add(sBox);
        }

        for(int m = 0; m < poi_demandBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_demandBoxes.At(m);
            bool mit = (obLogic.poi_demandMitigated.At(m) == 1);
            datetime box_time = b.left;

            if (!mit) b.set_right(poi_extend_right);
            
            bool is_bull_poi = obLogic.ob_time_found(&ms.ob_bull_struct_times, box_time);
            bool is_bull_ob  = false;

            if (is_bull_poi) {
                if (obLogic.ob_time_found(&obLogic.ob_bull_valid_times, box_time)) {
                    is_bull_ob = true;
                } else if (obLogic.CheckBullishOB(box_time, i, time, high, low)) {
                    obLogic.ob_bull_valid_times.Add((long)box_time);
                    is_bull_ob = true;
                }
            }

            if (is_bull_ob) {
                if (!mit) {
                    if (showBullishOB) {
                        b.set_bgcolor(OB_BULL_FILL); b.set_text_color(OB_BULL_TEXT);
                        b.set_text(ms.tf_str() + " BULLISH ORDER-BLOCK");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
                } else {
                    if (showMitigatedBullishOB) {
                        b.set_bgcolor(OB_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(ms.tf_str() + " BULLISH ORDER-BLOCK");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
                }
            } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
        }

        for(int m = 0; m < poi_supplyBoxes.Total(); m++) {
            PineBox* b = (PineBox*)poi_supplyBoxes.At(m);
            bool mit = (obLogic.poi_supplyMitigated.At(m) == 1);
            datetime box_time = b.left;

            if (!mit) b.set_right(poi_extend_right);
            
            bool is_bear_poi = obLogic.ob_time_found(&ms.ob_bear_struct_times, box_time);
            bool is_bear_ob  = false;

            if (is_bear_poi) {
                if (obLogic.ob_time_found(&obLogic.ob_bear_valid_times, box_time)) {
                    is_bear_ob = true;
                } else if (obLogic.CheckBearishOB(box_time, i, time, high, low)) {
                    obLogic.ob_bear_valid_times.Add((long)box_time);
                    is_bear_ob = true;
                }
            }

            if (is_bear_ob) {
                if (!mit) {
                    if (showBearishOB) {
                        b.set_bgcolor(OB_BEAR_FILL); b.set_text_color(OB_BEAR_TEXT);
                        b.set_text(ms.tf_str() + " BEARISH ORDER-BLOCK");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
                } else {
                    if (showMitigatedBearishOB) {
                        b.set_bgcolor(OB_MITIG_FILL); b.set_text_color(clrGray);
                        b.set_text(ms.tf_str() + " BEARISH ORDER-BLOCK");
                    } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
                }
            } else { b.set_bgcolor(POI_TRANSPARENT); b.set_text_color(POI_TRANSPARENT); b.set_text(""); }
        }
    }
    return rates_total;
}
