//+------------------------------------------------------------------+
//|                                Include\ZigZag\zone_mitigation.mqh|
//|      SMC Multi-Symbol Wick Touch Alert Engine based on zigzag/HL |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.13"

#include <Arrays\ArrayString.mqh>
#include <ZigZag\ZigZag.mqh>
#include <ZigZag\market_structure.mqh>
#include <ZigZag\demand_supply.mqh>
#include <ZigZag\swing_pois.mqh>
#include <ZigZag\order_blocks.mqh>
#include <ZigZag\teams_alert.mqh> 
#include <ZigZag\poc_analyzer.mqh> 

string zm_WebhookURL = TEAMS_URL; 
// =============================================================================
// GLOBAL DAILY ALERTS TRACKER (Enhanced for immediate file creation)
// =============================================================================
CArrayString g_daily_alerts;
string       g_daily_alerts_date = "";

void LoadDailyAlerts() {
    g_daily_alerts_date = TimeToString(TimeCurrent(), TIME_DATE);
    StringReplace(g_daily_alerts_date, ".", "-");
    string fileName = g_daily_alerts_date + "_mitigation_alert.csv"; // Specific Naming
    
    g_daily_alerts.Clear();
    if(!FileIsExist(fileName)) {
        int c_fh = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
        if(c_fh != INVALID_HANDLE) { Print("?? Created: ", fileName); FileClose(c_fh); }
    }

    int fh = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
    if(fh != INVALID_HANDLE) {
        while(!FileIsEnding(fh)) {
            string line = FileReadString(fh);
            if(line == "") continue;
            string parts[]; int cnt = StringSplit(line, ',', parts);
            if(cnt >= 9) g_daily_alerts.Add(parts[8]); 
        }
        FileClose(fh);
    }
}

bool CheckAndRegisterDailyAlert(string fullKey, string symbol, string tfStr, string obType, string dir, double entry, double sl, double tp) {
    string today = TimeToString(TimeCurrent(), TIME_DATE);
    StringReplace(today, ".", "-");
    if(today != g_daily_alerts_date) LoadDailyAlerts();

    for(int i = 0; i < g_daily_alerts.Total(); i++) {
        if(g_daily_alerts.At(i) == fullKey) return true;
    }

    g_daily_alerts.Add(fullKey);
    string fileName = g_daily_alerts_date + "_mitigation_alert.csv";
    int fh = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
    if(fh != INVALID_HANDLE) {
        FileSeek(fh, 0, SEEK_END);
        string line = IntegerToString(TimeCurrent()) + "," + symbol + "," + tfStr + "," + obType + "," + dir + "," +
                      DoubleToString(entry, 5) + "," + DoubleToString(sl, 5) + "," + DoubleToString(tp, 5) + "," + fullKey;
        FileWriteString(fh, line + "\n");
        FileClose(fh);
        Print("?? MITIGATION LOGGED: ", symbol);
    }
    return false;
}

class SMCScannerConfig {
public:
    int    scanSpeedPerSecond;

    bool   alertDemandZones;
    bool   alertSupplyZones;
    bool   alertMitigDemandZones;
    bool   alertMitigSupplyZones;

    bool   alertBullishOB;
    bool   alertBearishOB;
    bool   alertMitigBullishOB;
    bool   alertMitigBearishOB;

    bool   alertBullishPOI;
    bool   alertBearishPOI;
    bool   alertMitigBullishPOI;
    bool   alertMitigBearishPOI;

    int    fx_maxLookback;
    double fx_dev_D1;  int fx_dep_D1;
    double fx_dev_H4;  int fx_dep_H4;
    double fx_dev_H1;  int fx_dep_H1;
    double fx_dev_M15; int fx_dep_M15;

    int    mc_maxLookback;
    double mc_dev_D1;  int mc_dep_D1;
    double mc_dev_H4;  int mc_dep_H4;
    double mc_dev_H1;  int mc_dep_H1;
    double mc_dev_M15; int mc_dep_M15;
    
    SMCScannerConfig() {} 
};

class CScannerInstance {
private:
    SMCScannerConfig*  m_cfg;
    
public:
    string             symbol;
    ENUM_TIMEFRAMES    tf;
    int                prev_calculated;
    bool               is_first_scan_complete;
    
    int                m_maxLookback;
    double             m_deviation;  
    int                m_depth;
    
    ZigZag*            zigZag;
    CMarketStructure*  ms;
    CDemandSupplyLogic* dsLogic;
    CSwingPOILogic*    spLogic;
    COrderBlockLogic*  obLogic;
    
    CArrayString       alerted_keys; 

    CScannerInstance(string _symbol, ENUM_TIMEFRAMES _tf, double devInput, int depInput, int maxLB, SMCScannerConfig* config) {
        symbol = _symbol;
        tf = _tf;
        m_maxLookback = maxLB;
        m_deviation = devInput;
        m_depth = depInput;
        m_cfg = config;
        
        prev_calculated = 0;
        is_first_scan_complete = false;
        
        Settings* s = new Settings(devInput, depInput, clrNONE, true, false, false, false, "Percent");
        s.draw = false; 
        zigZag = newInstance(s);
        
        ms = new CMarketStructure();
        ms.Init(false, false);
        
        dsLogic = new CDemandSupplyLogic();
        spLogic = new CSwingPOILogic();
        obLogic = new COrderBlockLogic();
    }
    
    ~CScannerInstance() {
        if(zigZag) delete zigZag;
        if(ms) delete ms;
        if(dsLogic) delete dsLogic;
        if(spLogic) delete spLogic;
        if(obLogic) delete obLogic;
    }

    string GetZoneKey(bool isDemand, bool isMitigated, double zHigh, double zLow) {
        return StringFormat("%s_%s_%.5f_%.5f", isDemand ? "D" : "S", isMitigated ? "M" : "F", zHigh, zLow);
    }

    bool IsAlertedKey(string key) {
        for(int i = 0; i < alerted_keys.Total(); i++) {
            if(alerted_keys.At(i) == key) return true;
        }
        return false;
    }

    void ProcessData() {
        int rates_total = Bars(symbol, tf);
        if(rates_total < m_depth * 2) return;

        int start_bar = MathMax(0, rates_total - m_maxLookback);
        int to_copy = rates_total - start_bar;
        
        double high[], low[], close[]; datetime time[]; long vol[];
        
        if(CopyTime(symbol, tf, 0, to_copy, time) <= 0) return;
        if(CopyHigh(symbol, tf, 0, to_copy, high) <= 0) return;
        if(CopyLow(symbol, tf, 0, to_copy, low) <= 0) return;
        if(CopyClose(symbol, tf, 0, to_copy, close) <= 0) return;
        if(CopyTickVolume(symbol, tf, 0, to_copy, vol) <= 0) return;
        
        int start = (prev_calculated == 0) ? 0 : prev_calculated - start_bar - 1;
        if(start < 0) start = 0;
        
        for(int i = start; i < to_copy; i++) {
            bool is_last = (i == to_copy - 1);
            int bar_index = start_bar + i;
            
            zigZag.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
            ms.Update(i, time, high, low, close, zigZag);
            
            dsLogic.DetectPOIs(i, time, high, low, zigZag);
            dsLogic.UpdateMitigation(close[i]);
            
            spLogic.DetectPOIs(i, time, high, low, zigZag);
            spLogic.UpdateMitigation(close[i]);
            
            obLogic.DetectPOIs(i, time, high, low, zigZag);
            obLogic.UpdateMitigation(close[i]);
            
            if(obLogic.poi_demandTime.Total() > 0) {
                datetime tz = (datetime)obLogic.poi_demandTime.At(obLogic.poi_demandTime.Total() - 1);
                if(obLogic.ob_time_found(&ms.ob_bull_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bull_valid_times, tz)) {
                    if (obLogic.CheckBullishOB(tz, i, time, high, low)) obLogic.ob_bull_valid_times.Add((long)tz);
                }
            }
            if(obLogic.poi_supplyTime.Total() > 0) {
                datetime tz = (datetime)obLogic.poi_supplyTime.At(obLogic.poi_supplyTime.Total() - 1);
                if(obLogic.ob_time_found(&ms.ob_bear_struct_times, tz) && !obLogic.ob_time_found(&obLogic.ob_bear_valid_times, tz)) {
                    if (obLogic.CheckBearishOB(tz, i, time, high, low)) obLogic.ob_bear_valid_times.Add((long)tz);
                }
            }
        }
        prev_calculated = rates_total;
    }

    void FireZoneAlert(string zoneLabel, bool isDemand, int index, int listType) {
        OBAnalysis oa;
        oa.zoneLabel = zoneLabel;
        long zTime = 0;

        if(listType == 1) { 
            oa.zoneHigh = isDemand ? dsLogic.poi_demandZoneHigh.At(index) : dsLogic.poi_supplyZoneHigh.At(index);
            oa.zoneLow  = isDemand ? dsLogic.poi_demandZoneLow.At(index)  : dsLogic.poi_supplyZoneLow.At(index);
            zTime       = isDemand ? dsLogic.poi_demandTime.At(index)     : dsLogic.poi_supplyTime.At(index);
            oa.isFresh  = isDemand ? (dsLogic.poi_demandMitigated.At(index) == 0) : (dsLogic.poi_supplyMitigated.At(index) == 0);
        } else if(listType == 2) { 
            oa.zoneHigh = isDemand ? spLogic.poi_demandZoneHigh.At(index) : spLogic.poi_supplyZoneHigh.At(index);
            oa.zoneLow  = isDemand ? spLogic.poi_demandZoneLow.At(index)  : spLogic.poi_supplyZoneLow.At(index);
            zTime       = isDemand ? spLogic.poi_demandTime.At(index)     : spLogic.poi_supplyTime.At(index);
            oa.isFresh  = isDemand ? (spLogic.poi_demandMitigated.At(index) == 0) : (spLogic.poi_supplyMitigated.At(index) == 0);
        } else if(listType == 3) { 
            oa.zoneHigh = isDemand ? obLogic.poi_demandZoneHigh.At(index) : obLogic.poi_supplyZoneHigh.At(index);
            oa.zoneLow  = isDemand ? obLogic.poi_demandZoneLow.At(index)  : obLogic.poi_supplyZoneLow.At(index);
            zTime       = isDemand ? obLogic.poi_demandTime.At(index)     : obLogic.poi_supplyTime.At(index);
            oa.isFresh  = isDemand ? (obLogic.poi_demandMitigated.At(index) == 0) : (obLogic.poi_supplyMitigated.At(index) == 0);
        }

        oa.zoneCreatedTime = zTime;
        oa.isPreviouslyMitigated = !oa.isFresh;
        oa.touchCount = oa.isFresh ? 0 : 1;

        oa.maxLookbackBars = m_maxLookback;
        oa.deviationInput  = m_deviation;
        oa.depthInput      = m_depth;

        oa.trendBias = (ms.trend == 1) ? "BULLISH" : "BEARISH";
        oa.marketStructureType = (ms.trend == 1) ? "Higher Highs & Higher Lows" : "Lower Highs & Lower Lows";
        oa.bosDetected = true;
        oa.chochDetected = false;
        oa.lastBosTime = ms.last_breakout_time;
        oa.lastBosType = "Structural Break";

        long vol[]; CopyTickVolume(symbol, tf, 0, 1, vol);
        oa.tickVolume = (ArraySize(vol) > 0) ? vol[0] : 0;
        oa.realVolume = 0;
        oa.cumulativeVolume = (long)zigZag.cVols.get(0);

        Pivot* lastP = zigZag.lastPivot();
        if(lastP != NULL && lastP.start != NULL && lastP.end != NULL) {
            oa.zzReversalPrice = lastP.end.price;
            oa.zzPriorReversalPrice = lastP.start.price;
            oa.zzPriceChange = lastP.end.price - lastP.start.price;
            oa.zzDirection = (oa.zzPriceChange > 0) ? "UP" : "DOWN";
        } else {
            oa.zzReversalPrice = 0; oa.zzPriorReversalPrice = 0; oa.zzPriceChange = 0; oa.zzDirection = "UNKNOWN";
        }

        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
        
        double liveBid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double liveAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double livePrice = isDemand ? liveAsk : liveBid;

        double entryPrice = livePrice;
        oa.slPrice = isDemand ? (oa.zoneLow - (3.0 * pipSize)) : (oa.zoneHigh + (3.0 * pipSize));
        double riskPrice = MathAbs(entryPrice - oa.slPrice);
        double rewardPrice = riskPrice * 2.0;
        oa.tpPrice = isDemand ? (entryPrice + rewardPrice) : (entryPrice - rewardPrice);

        double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        if(tickSize <= 0) tickSize = point; 
        
        oa.estLoss   = (riskPrice / tickSize) * tickValue;
        oa.estProfit = (rewardPrice / tickSize) * tickValue;

        datetime arr_time[];
        double   arr_open[], arr_high[], arr_low[], arr_close[];
        int      lookback_bars = 15; 
        
        CopyTime(symbol, tf, 0, lookback_bars, arr_time);
        CopyOpen(symbol, tf, 0, lookback_bars, arr_open);
        CopyHigh(symbol, tf, 0, lookback_bars, arr_high);
        CopyLow(symbol, tf, 0, lookback_bars, arr_low);
        CopyClose(symbol, tf, 0, lookback_bars, arr_close);
        
        int touch_index = ArraySize(arr_time) - 1; 
        if(touch_index < 0) touch_index = 0;

        CPoCAnalyzer pocEngine;
        PoCResult pocRes = pocEngine.EvaluateZone(
            isDemand, (datetime)zTime, oa.zoneHigh, oa.zoneLow, 
            touch_index, arr_time, arr_open, arr_high, arr_low, arr_close, 
            zigZag, ms, livePrice, pipSize, tf, "0800-1200", "1200-1600"
        );
        
        oa.setupQuality   = pocRes.finalScore;
        oa.reasoning      = pocRes.reasoning; 
        oa.recommendation = pocRes.recommendation;

        string obType = isDemand ? "BULLISH" : "BEARISH";
        string tfStr = StringSubstr(EnumToString(tf), 7);
        
        Print("+++ ?? Queuing Webhook Alert: ", symbol, " ", tfStr, " ", obType, " | Score: ", oa.setupQuality);
        SendOBAlert(symbol, tf, obType, oa, zm_WebhookURL);
    }

    void EvaluateWickTouches() {
        double curHigh[], curLow[];
        if(CopyHigh(symbol, tf, 0, 1, curHigh) <= 0) return;
        if(CopyLow(symbol, tf, 0, 1, curLow) <= 0) return;
        
        double h = curHigh[0];
        double l = curLow[0];

        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;
        
        double liveBid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double liveAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);

        bool alertedBullishThisScan = false;
        bool alertedBearishThisScan = false;

        // 1. ORDER BLOCKS
        for(int i = 0; i < obLogic.poi_demandTime.Total(); i++) {
            bool isMitigated = (obLogic.poi_demandMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigBullishOB) continue;
            if (!isMitigated && !m_cfg.alertBullishOB) continue;

            long zTime = obLogic.poi_demandTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bull_struct_times, (datetime)zTime) && obLogic.ob_time_found(&obLogic.ob_bull_valid_times, (datetime)zTime)) {
                double zHigh = obLogic.poi_demandZoneHigh.At(i);
                double zLow = obLogic.poi_demandZoneLow.At(i);
                string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);
                
                if (IsAlertedKey(localKey)) continue;

                if (l <= zHigh && h >= zLow) {
                    if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                    alerted_keys.Add(localKey); 
                    
                    if (is_first_scan_complete && !alertedBullishThisScan) {
                        string fullKey = StringFormat("%s_%s_ORDER-BLOCK_BULL_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                        double sl = zLow - 3.0 * pipSize;
                        double risk = MathAbs(liveAsk - sl);
                        double tp = liveAsk + 2.0 * risk;
                        
                        if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "ORDER-BLOCK", "BULLISH", liveAsk, sl, tp)) {
                            Print("scan complete ; all alert already fired");
                        } else {
                            FireZoneAlert("ORDER-BLOCK", true, i, 3);
                        }
                        alertedBullishThisScan = true;
                    }
                }
            }
        }
        for(int i = 0; i < obLogic.poi_supplyTime.Total(); i++) {
            bool isMitigated = (obLogic.poi_supplyMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigBearishOB) continue;
            if (!isMitigated && !m_cfg.alertBearishOB) continue;

            long zTime = obLogic.poi_supplyTime.At(i);
            if(obLogic.ob_time_found(&ms.ob_bear_struct_times, (datetime)zTime) && obLogic.ob_time_found(&obLogic.ob_bear_valid_times, (datetime)zTime)) {
                double zHigh = obLogic.poi_supplyZoneHigh.At(i);
                double zLow = obLogic.poi_supplyZoneLow.At(i);
                string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);
                
                if (IsAlertedKey(localKey)) continue;

                if (h >= zLow && l <= zHigh) {
                    if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                    alerted_keys.Add(localKey);
                    
                    if (is_first_scan_complete && !alertedBearishThisScan) {
                        string fullKey = StringFormat("%s_%s_ORDER-BLOCK_BEAR_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                        double sl = zHigh + 3.0 * pipSize;
                        double risk = MathAbs(sl - liveBid);
                        double tp = liveBid - 2.0 * risk;
                        
                        if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "ORDER-BLOCK", "BEARISH", liveBid, sl, tp)) {
                            Print("scan complete ; all alert already fired");
                        } else {
                            FireZoneAlert("ORDER-BLOCK", false, i, 3);
                        }
                        alertedBearishThisScan = true;
                    }
                }
            }
        }

        // 2. SWING POIs
        for(int i = 0; i < spLogic.poi_demandTime.Total(); i++) {
            bool isMitigated = (spLogic.poi_demandMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigBullishPOI) continue;
            if (!isMitigated && !m_cfg.alertBullishPOI) continue;

            long zTime = spLogic.poi_demandTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bull_struct_times, (datetime)zTime)) {
                double zHigh = spLogic.poi_demandZoneHigh.At(i);
                double zLow = spLogic.poi_demandZoneLow.At(i);
                string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);
                
                if (IsAlertedKey(localKey)) continue;

                if(l <= zHigh && h >= zLow) {
                    if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                    alerted_keys.Add(localKey);
                    
                    if (is_first_scan_complete && !alertedBullishThisScan) {
                        string fullKey = StringFormat("%s_%s_SWING_POI_BULL_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                        double sl = zLow - 3.0 * pipSize;
                        double risk = MathAbs(liveAsk - sl);
                        double tp = liveAsk + 2.0 * risk;
                        
                        if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "SWING POI", "BULLISH", liveAsk, sl, tp)) {
                            Print("scan complete ; all alert already fired");
                        } else {
                            FireZoneAlert("SWING POI", true, i, 2);
                        }
                        alertedBullishThisScan = true;
                    }
                }
            }
        }
        for(int i = 0; i < spLogic.poi_supplyTime.Total(); i++) {
            bool isMitigated = (spLogic.poi_supplyMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigBearishPOI) continue;
            if (!isMitigated && !m_cfg.alertBearishPOI) continue;

            long zTime = spLogic.poi_supplyTime.At(i);
            if(spLogic.ob_time_found(&ms.ob_bear_struct_times, (datetime)zTime)) {
                double zHigh = spLogic.poi_supplyZoneHigh.At(i);
                double zLow = spLogic.poi_supplyZoneLow.At(i);
                string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);
                
                if (IsAlertedKey(localKey)) continue;

                if(h >= zLow && l <= zHigh) {
                    if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                    alerted_keys.Add(localKey);
                    
                    if (is_first_scan_complete && !alertedBearishThisScan) {
                        string fullKey = StringFormat("%s_%s_SWING_POI_BEAR_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                        double sl = zHigh + 3.0 * pipSize;
                        double risk = MathAbs(sl - liveBid);
                        double tp = liveBid - 2.0 * risk;
                        
                        if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "SWING POI", "BEARISH", liveBid, sl, tp)) {
                            Print("scan complete ; all alert already fired");
                        } else {
                            FireZoneAlert("SWING POI", false, i, 2);
                        }
                        alertedBearishThisScan = true;
                    }
                }
            }
        }

        // 3. DEMAND / SUPPLY ZONES
        for(int i = 0; i < dsLogic.poi_demandTime.Total(); i++) {
            bool isMitigated = (dsLogic.poi_demandMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigDemandZones) continue;
            if (!isMitigated && !m_cfg.alertDemandZones) continue;

            double zHigh = dsLogic.poi_demandZoneHigh.At(i);
            double zLow = dsLogic.poi_demandZoneLow.At(i);
            string localKey = GetZoneKey(true, isMitigated, zHigh, zLow);
            
            if (IsAlertedKey(localKey)) continue;

            if(l <= zHigh && h >= zLow) {
                if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                alerted_keys.Add(localKey);
                
                if (is_first_scan_complete && !alertedBullishThisScan) {
                    string fullKey = StringFormat("%s_%s_DEMAND_ZONE_BULL_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                    double sl = zLow - 3.0 * pipSize;
                    double risk = MathAbs(liveAsk - sl);
                    double tp = liveAsk + 2.0 * risk;
                        
                    if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "DEMAND ZONE", "BULLISH", liveAsk, sl, tp)) {
                        Print("scan complete ; all alert already fired");
                    } else {
                        FireZoneAlert("DEMAND ZONE", true, i, 1);
                    }
                    alertedBullishThisScan = true;
                }
            }
        }
        for(int i = 0; i < dsLogic.poi_supplyTime.Total(); i++) {
            bool isMitigated = (dsLogic.poi_supplyMitigated.At(i) == 1);
            if (isMitigated && !m_cfg.alertMitigSupplyZones) continue;
            if (!isMitigated && !m_cfg.alertSupplyZones) continue;

            double zHigh = dsLogic.poi_supplyZoneHigh.At(i);
            double zLow = dsLogic.poi_supplyZoneLow.At(i);
            string localKey = GetZoneKey(false, isMitigated, zHigh, zLow);
            
            if (IsAlertedKey(localKey)) continue;

            if(h >= zLow && l <= zHigh) {
                if(alerted_keys.Total() > 500) alerted_keys.Delete(0);
                alerted_keys.Add(localKey);
                
                if (is_first_scan_complete && !alertedBearishThisScan) {
                    string fullKey = StringFormat("%s_%s_SUPPLY_ZONE_BEAR_%s_%.5f_%.5f", symbol, EnumToString(tf), isMitigated ? "M" : "F", zHigh, zLow);
                    double sl = zHigh + 3.0 * pipSize;
                    double risk = MathAbs(sl - liveBid);
                    double tp = liveBid - 2.0 * risk;
                        
                    if(CheckAndRegisterDailyAlert(fullKey, symbol, StringSubstr(EnumToString(tf),7), "SUPPLY ZONE", "BEARISH", liveBid, sl, tp)) {
                        Print("scan complete ; all alert already fired");
                    } else {
                        FireZoneAlert("SUPPLY ZONE", false, i, 1);
                    }
                    alertedBearishThisScan = true;
                }
            }
        }
        
        is_first_scan_complete = true;
    }
};

class CZoneMitigationEngine {
private:
    CScannerInstance* instances[];
    int               total_instances;
    int               current_scan_idx;
    SMCScannerConfig* m_cfg;
    bool              all_synced; // Track if initial heavy load is done

    bool IsCryptoOrMetal(string sym) {
        if (StringFind(sym, "BTC") >= 0 || StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0) return true;
        return false;
    }

public:
    CZoneMitigationEngine() {
        total_instances = 0;
        current_scan_idx = 0;
        all_synced = false;
    }

    ~CZoneMitigationEngine() {
        for(int i = 0; i < total_instances; i++) {
            if(CheckPointer(instances[i]) == POINTER_DYNAMIC) delete instances[i];
        }
    }

    void Initialize(SMCScannerConfig* config) {
        // 1. Process previous days (Send reports to Teams)
        CDailyReporter::ProcessPendingReports(); 
        
        // 2. Prepare today's file immediately
        LoadDailyAlerts();
        
        m_cfg = config;
        
        string TargetSymbols[] = {
            "AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD",
            "CADCHF", "CADJPY", "CHFJPY",
            "EURAUD", "EURCAD", "EURCHF", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
            "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD",
            "NZDCAD", "NZDCHF", "NZDJPY", "NZDUSD",
            "USDCAD", "USDCHF", "USDJPY",
            "BTCUSD", "XAGUSD", "XAUUSD"
        };
        
        ENUM_TIMEFRAMES TargetTFs[] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };

        int symCount = ArraySize(TargetSymbols);
        int tfCount  = ArraySize(TargetTFs);
        total_instances = symCount * tfCount;
        ArrayResize(instances, total_instances);

        int idx = 0;
        for(int s = 0; s < symCount; s++) {
            SymbolSelect(TargetSymbols[s], true); 
            bool isMC = IsCryptoOrMetal(TargetSymbols[s]);
            for(int t = 0; t < tfCount; t++) {
                ENUM_TIMEFRAMES tf = TargetTFs[t];
                double dev = 1.0; int dep = 15;
                int maxLB = isMC ? m_cfg.mc_maxLookback : m_cfg.fx_maxLookback;
                
                if (isMC) {
                    if (tf == PERIOD_D1)       { dev = m_cfg.mc_dev_D1;  dep = m_cfg.mc_dep_D1;  }
                    else if (tf == PERIOD_H4)  { dev = m_cfg.mc_dev_H4;  dep = m_cfg.mc_dep_H4;  }
                    else if (tf == PERIOD_H1)  { dev = m_cfg.mc_dev_H1;  dep = m_cfg.mc_dep_H1;  }
                    else if (tf == PERIOD_M15) { dev = m_cfg.mc_dev_M15; dep = m_cfg.mc_dep_M15; }
                } else {
                    if (tf == PERIOD_D1)       { dev = m_cfg.fx_dev_D1;  dep = m_cfg.fx_dep_D1;  }
                    else if (tf == PERIOD_H4)  { dev = m_cfg.fx_dev_H4;  dep = m_cfg.fx_dep_H4;  }
                    else if (tf == PERIOD_H1)  { dev = m_cfg.fx_dev_H1;  dep = m_cfg.fx_dep_H1;  }
                    else if (tf == PERIOD_M15) { dev = m_cfg.fx_dev_M15; dep = m_cfg.fx_dep_M15; }
                }
                instances[idx] = new CScannerInstance(TargetSymbols[s], tf, dev, dep, maxLB, m_cfg);
                idx++;
            }
        }
        Print("?? Engine initialized with ", total_instances, " chart instances. Starting history sync...");
    }

    void ProcessBatch() {
        int processed = 0;
        while(processed < m_cfg.scanSpeedPerSecond && total_instances > 0) {
            // Check if this instance is being synced for the first time
            bool wasSynced = instances[current_scan_idx].is_first_scan_complete;
            
            instances[current_scan_idx].ProcessData();
            instances[current_scan_idx].EvaluateWickTouches();
            
            // Progress Logging
            if(!wasSynced && instances[current_scan_idx].is_first_scan_complete) {
                string tfStr = StringSubstr(EnumToString(instances[current_scan_idx].tf), 7);
                PrintFormat("[%d/%d] ?? Synced: %s, %s", current_scan_idx + 1, total_instances, instances[current_scan_idx].symbol, tfStr);
            }

            current_scan_idx++;
            
            // Check if we just finished a full loop of all symbols
            if(current_scan_idx >= total_instances) {
                current_scan_idx = 0; 
                if(!all_synced) {
                    all_synced = true;
                    Print("? ALL CHARTS FULLY SYNCED. Engine is now monitoring live price movements.");
                }
            }
            processed++;
        }
    }
};