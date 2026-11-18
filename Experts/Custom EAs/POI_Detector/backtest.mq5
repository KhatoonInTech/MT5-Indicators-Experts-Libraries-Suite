


//+------------------------------------------------------------------+
//|                                        Experts\ZigZag\backtest.mq5|
//|                         SMC Multi-Symbol Backtest Report Engine  |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.34"

#include <ZigZag\backtest.mqh>

input group "Alert Settings"
input bool   sendTestMockAlertOnStart = false;        
input int    scanSpeedPerSecond       = 3;           

input group "Visual Debugging"
input bool   drawOnAllCharts          = true;        // Draw Zones on Matching Open Charts
input color  successZoneColor         = clrSpringGreen;
input color  failZoneColor            = clrSalmon;

input group "Visual Debugging: Zone Types"
input bool   drawDemandZones          = true;        // Draw Demand Zones
input bool   drawSupplyZones          = true;        // Draw Supply Zones
input bool   drawBullishPOI           = true;        // Draw Bullish Swing POI
input bool   drawBearishPOI           = true;        // Draw Bearish Swing POI
input bool   drawBullishOB            = true;        // Draw Bullish Order Blocks
input bool   drawBearishOB            = true;        // Draw Bearish Order Blocks

input group "--- For Forex Pairs ---"         
input int    fx_maxLookback          = 10000;          
input group "Forex: PERIOD_D1"
input double fx_dev_D1               = 1.0;           
input int    fx_dep_D1               = 15;            
input group "Forex: PERIOD_H4"
input double fx_dev_H4               = 1.0;           
input int    fx_dep_H4               = 15;            
input group "Forex: PERIOD_H1"
input double fx_dev_H1               = 0.5;           
input int    fx_dep_H1               = 15;            
input group "Forex: PERIOD_M15"
input double fx_dev_M15              = 0.5;           
input int    fx_dep_M15              = 5;             

input group "--- For Metals/Crypto Pairs ---"         
input int    mc_maxLookback          = 10000;          
input group "Metals/Crypto: PERIOD_D1"
input double mc_dev_D1               = 5.0;           
input int    mc_dep_D1               = 15;            
input group "Metals/Crypto: PERIOD_H4"
input double mc_dev_H4               = 5.0;           
input int    mc_dep_H4               = 15;            
input group "Metals/Crypto: PERIOD_H1"
input double mc_dev_H1               = 1.0;           
input int    mc_dep_H1               = 15;            
input group "Metals/Crypto: PERIOD_M15"
input double mc_dev_M15              = 1.0;           
input int    mc_dep_M15              = 5;             

string master_report_text = "";

// =========================================================================
// BACKTEST ENGINE HANDLER
// =========================================================================
class CSymbolBacktest {
public:
    string symbol;
    CBacktestInstance* inst_m15;
    CBacktestInstance* inst_h1;
    CBacktestInstance* inst_h4;
    CBacktestInstance* inst_d1;
    
    bool completed_m15, completed_h1, completed_h4, completed_d1;
    bool all_completed_and_sent;

    CSymbolBacktest(string sym, bool isMC, bool drawChart, color cSucc, color cFail,
                    bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO) {
        symbol = sym;
        all_completed_and_sent = false;
        completed_m15 = false; completed_h1 = false; completed_h4 = false; completed_d1 = false;
        
        if (isMC) {
            inst_m15 = new CBacktestInstance(sym, PERIOD_M15, mc_dev_M15, mc_dep_M15, mc_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_h1  = new CBacktestInstance(sym, PERIOD_H1,  mc_dev_H1,  mc_dep_H1,  mc_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_h4  = new CBacktestInstance(sym, PERIOD_H4,  mc_dev_H4,  mc_dep_H4,  mc_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_d1  = new CBacktestInstance(sym, PERIOD_D1,  mc_dev_D1,  mc_dep_D1,  mc_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
        } else {
            inst_m15 = new CBacktestInstance(sym, PERIOD_M15, fx_dev_M15, fx_dep_M15, fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_h1  = new CBacktestInstance(sym, PERIOD_H1,  fx_dev_H1,  fx_dep_H1,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_h4  = new CBacktestInstance(sym, PERIOD_H4,  fx_dev_H4,  fx_dep_H4,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
            inst_d1  = new CBacktestInstance(sym, PERIOD_D1,  fx_dev_D1,  fx_dep_D1,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
        }
    }
    
    ~CSymbolBacktest() {
        if (inst_m15) delete inst_m15; if (inst_h1) delete inst_h1;
        if (inst_h4) delete inst_h4; if (inst_d1) delete inst_d1;
    }

    bool RunAllAndReport() {
        if (all_completed_and_sent) return true;
        
        if (!completed_m15) completed_m15 = inst_m15.RunBacktest();
        if (!completed_h1)  completed_h1  = inst_h1.RunBacktest();
        if (!completed_h4)  completed_h4  = inst_h4.RunBacktest();
        if (!completed_d1)  completed_d1  = inst_d1.RunBacktest();
        
        if (completed_m15 && completed_h1 && completed_h4 && completed_d1) {
            master_report_text += CBacktestReporter::FormatSymbolText(symbol, inst_m15.metrics, inst_h1.metrics, inst_h4.metrics, inst_d1.metrics);
            all_completed_and_sent = true;
            return true;
        }
        return false;
    }
};

class CBacktestEngine {
private:
    CSymbolBacktest*   symbols[];
    int                total_symbols;
    int                current_scan_idx;
    bool               report_published;

    bool IsCryptoOrMetal(string sym) {
        if (StringFind(sym, "BTC") >= 0 || StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0) return true;
        return false;
    }

public:
    CBacktestEngine() {
        total_symbols = 0; current_scan_idx = 0; report_published = false;
    }

    ~CBacktestEngine() {
        for(int i = 0; i < total_symbols; i++) { if(symbols[i]) delete symbols[i]; }
    }

    void Initialize(bool draw, color cSucc, color cFail, 
                    bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO) {
        
        // Exact list provided by user
        string TargetSymbols[] = {
            "BTCUSD", "XAGUSD", "XAUUSD",
            "USDJPY", "EURJPY", "EURUSD", "EURGBP", "GBPJPY", "GBPUSD", 
            "AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD",
            "CADCHF", "CADJPY", "CHFJPY",
            "EURAUD", "EURCAD", "EURCHF", "EURNZD",
            "GBPAUD", "GBPCAD", "GBPCHF", "GBPNZD",
            "NZDCAD", "NZDCHF", "NZDJPY", "NZDUSD",
            "USDCAD", "USDCHF"
        };
        
        total_symbols = ArraySize(TargetSymbols);
        ArrayResize(symbols, total_symbols);

        for(int s = 0; s < total_symbols; s++) {
            SymbolSelect(TargetSymbols[s], true); 
            symbols[s] = new CSymbolBacktest(TargetSymbols[s], IsCryptoOrMetal(TargetSymbols[s]), draw, cSucc, cFail,
                                             drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO);
        }
        
        master_report_text = "=============================================================\n";
        master_report_text += "              SMC MASTER BACKTEST REPORT\n";
        master_report_text += "=============================================================\n";
        master_report_text += "Timestamp          : " + TimeToString(TimeCurrent()) + "\n";
        master_report_text += "Symbols Evaluated  : " + IntegerToString(total_symbols) + "\n";
        master_report_text += "Timeframes Covered : M15, H1, H4, D1\n\n";
        
        master_report_text += "--- INPUT PARAMETERS ---\n";
        master_report_text += "Forex Lookback         : " + IntegerToString(fx_maxLookback) + " Bars\n";
        master_report_text += "Metals/Crypto Lookback : " + IntegerToString(mc_maxLookback) + " Bars\n";
        master_report_text += "M15 Setting (Fx/MC)    : Dev " + DoubleToString(fx_dev_M15,1) + "/" + DoubleToString(mc_dev_M15,1) + ", Depth " + IntegerToString(fx_dep_M15) + "/" + IntegerToString(mc_dep_M15) + "\n";
        master_report_text += "H1 Setting (Fx/MC)     : Dev " + DoubleToString(fx_dev_H1,1) + "/" + DoubleToString(mc_dev_H1,1) + ", Depth " + IntegerToString(fx_dep_H1) + "/" + IntegerToString(mc_dep_H1) + "\n";
        master_report_text += "H4 Setting (Fx/MC)     : Dev " + DoubleToString(fx_dev_H4,1) + "/" + DoubleToString(mc_dev_H4,1) + ", Depth " + IntegerToString(fx_dep_H4) + "/" + IntegerToString(mc_dep_H4) + "\n";
        master_report_text += "D1 Setting (Fx/MC)     : Dev " + DoubleToString(fx_dev_D1,1) + "/" + DoubleToString(mc_dev_D1,1) + ", Depth " + IntegerToString(fx_dep_D1) + "/" + IntegerToString(mc_dep_D1) + "\n";
        master_report_text += "=============================================================\n\n";
    }

    void ProcessBatch() {
        if (report_published) return;
        
        int processed = 0;
        while(processed < scanSpeedPerSecond && current_scan_idx < total_symbols) {
            if (!symbols[current_scan_idx].all_completed_and_sent) {
                Print("Scanning Chart Data for: ", symbols[current_scan_idx].symbol);
                if (!symbols[current_scan_idx].RunAllAndReport()) {
                    Print("History not fully loaded yet for ", symbols[current_scan_idx].symbol, ". Skipped temporarily to load cache.");
                }
            }
            current_scan_idx++;
            processed++;
        }
        
        if (current_scan_idx >= total_symbols) {
            bool all_done = true;
            for(int i = 0; i < total_symbols; i++) {
                if(!symbols[i].all_completed_and_sent) { all_done = false; break; }
            }
            if (!all_done) {
                current_scan_idx = 0; 
            } else {
                int fh = FileOpen("SMC_Master_Report.txt", FILE_WRITE | FILE_TXT | FILE_ANSI);
                if(fh != INVALID_HANDLE) {
                    FileWriteString(fh, master_report_text);
                    FileClose(fh);
                    Print("?? Saved Report locally to MQL5/Files/SMC_Master_Report.txt");
                }
                
                string download_link = CBacktestReporter::UploadReportToCatbox(master_report_text);
                Print("?? Report Uploaded to: ", download_link);
                
                string input_params_text = 
                   "                  { \"title\": \"Forex Lookback:\", \"value\": \"" + IntegerToString(fx_maxLookback) + " Bars\" },\n" +
                   "                  { \"title\": \"Metals/Crypto Lookback:\", \"value\": \"" + IntegerToString(mc_maxLookback) + " Bars\" },\n" +
                   "                  { \"title\": \"M15 Setting (Fx/MC):\", \"value\": \"Dev " + DoubleToString(fx_dev_M15,1) + "/" + DoubleToString(mc_dev_M15,1) + ", Depth " + IntegerToString(fx_dep_M15) + "/" + IntegerToString(mc_dep_M15) + "\" },\n" +
                   "                  { \"title\": \"H1 Setting (Fx/MC):\", \"value\": \"Dev " + DoubleToString(fx_dev_H1,1) + "/" + DoubleToString(mc_dev_H1,1) + ", Depth " + IntegerToString(fx_dep_H1) + "/" + IntegerToString(mc_dep_H1) + "\" },\n" +
                   "                  { \"title\": \"H4 Setting (Fx/MC):\", \"value\": \"Dev " + DoubleToString(fx_dev_H4,1) + "/" + DoubleToString(mc_dev_H4,1) + ", Depth " + IntegerToString(fx_dep_H4) + "/" + IntegerToString(mc_dep_H4) + "\" },\n" +
                   "                  { \"title\": \"D1 Setting (Fx/MC):\", \"value\": \"Dev " + DoubleToString(fx_dev_D1,1) + "/" + DoubleToString(mc_dev_D1,1) + ", Depth " + IntegerToString(fx_dep_D1) + "/" + IntegerToString(mc_dep_D1) + "\" }\n";
                   
                CBacktestReporter::SendMasterTeamsAlert(download_link, input_params_text);
                
                Print("?? Backtest Finished! Report sent to MS Teams.");
                report_published = true;
                EventKillTimer();
            }
        }
    }
};

CBacktestEngine* engine = NULL;

int OnInit() {
    Print("?? Initializing SMC Master Backtest Generator...");
    engine = new CBacktestEngine();
    engine.Initialize(drawOnAllCharts, successZoneColor, failZoneColor,
                      drawDemandZones, drawSupplyZones, drawBullishPOI, drawBearishPOI, drawBullishOB, drawBearishOB);
    EventSetTimer(1); 
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    EventKillTimer();
    if(engine) delete engine;
    
    // --- Scans ALL charts and cleans up our backtest drawings! ---
    long currChart = ChartFirst(); 
    while(currChart >= 0) {
        ObjectsDeleteAll(currChart, "BT_");
        ChartRedraw(currChart);
        currChart = ChartNext(currChart);
    }
}

void OnTimer() {
    if(engine) engine.ProcessBatch();
}