#define MARCO_LOG_PROGRAM "backtest"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                        Experts\ZigZag\backtest.mq5|
//|                         SMC Multi-Symbol Backtest Report Engine  |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "1.37"
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import
#include <Custom\ZigZag\backtest.mqh>

input group "Alert Settings"
input bool   sendTestMockAlertOnStart = false;
input int    scanSpeedPerSecond       = 3;

input group "Visual Debugging"
input bool   drawOnAllCharts          = false;        // Draw Zones on Matching Open Charts
input color  successZoneColor         = clrSpringGreen;
input color  failZoneColor            = clrSalmon;

input group "Visual Debugging: Zone Types"
input bool   drawDemandZones          = false;        // Draw Demand Zones
input bool   drawSupplyZones          = false;        // Draw Supply Zones
input bool   drawBullishPOI           = false;        // Draw Bullish Swing POI
input bool   drawBearishPOI           = false;        // Draw Bearish Swing POI
input bool   drawBullishOB            = false;        // Draw Bullish Order Blocks
input bool   drawBearishOB            = false;        // Draw Bearish Order Blocks
input bool   drawDemandFlip           = false;        // Draw Demand Flip Zones
input bool   drawSupplyFlip           = false;        // Draw Supply Flip Zones
input bool   drawBullishBreaker       = true;        // Draw Bullish Breaker Blocks
input bool   drawBearishBreaker        = true;        // Draw Bearish Breaker Blocks

input group "--- For Forex Pairs ---"
input int    fx_maxLookback          = 5000;
input group "Forex: PERIOD_D1"
input double fx_dev_D1               = 2.20;
input int    fx_dep_D1               = 17;
input group "Forex: PERIOD_H4"
input double fx_dev_H4               = 0.80;
input int    fx_dep_H4               = 17;
input group "Forex: PERIOD_H1"
input double fx_dev_H1               = 0.20;
input int    fx_dep_H1               = 19;
input group "Forex: PERIOD_M15"
input double fx_dev_M15              = 0.15;
input int    fx_dep_M15              = 16;
input group "Forex: PERIOD_M1 (Confirmation)"
input double fx_dev_M1               = 0.10;
input int    fx_dep_M1               = 10;

input group "--- For Metals Pairs ---"
input int    met_maxLookback          = 10000;
input group "Metals: PERIOD_D1"
input double met_dev_D1               = 5.0;
input int    met_dep_D1               = 15;
input group "Metals: PERIOD_H4"
input double met_dev_H4               = 5.0;
input int    met_dep_H4               = 15;
input group "Metals: PERIOD_H1"
input double met_dev_H1               = 1.0;
input int    met_dep_H1               = 15;
input group "Metals: PERIOD_M15"
input double met_dev_M15              = 1.0;
input int    met_dep_M15              = 5;
input group "Metals: PERIOD_M1 (Confirmation)"
input double met_dev_M1               = 0.50;
input int    met_dep_M1               = 10;

input group "--- For Crypto Pairs ---"
input int    cry_maxLookback          = 10000;
input group "Crypto: PERIOD_D1"
input double cry_dev_D1               = 5.0;
input int    cry_dep_D1               = 15;
input group "Crypto: PERIOD_H4"
input double cry_dev_H4               = 5.0;
input int    cry_dep_H4               = 15;
input group "Crypto: PERIOD_H1"
input double cry_dev_H1               = 2.66;
input int    cry_dep_H1               = 11;
input group "Crypto: PERIOD_M15"
input double cry_dev_M15              = 2.66;
input int    cry_dep_M15              = 12;
input group "Crypto: PERIOD_M1 (Confirmation)"
input double cry_dev_M1               = 0.50;
input int    cry_dep_M1               = 10;

string master_report_csv = "";

// =========================================================================
// BACKTEST ENGINE HANDLER
// =========================================================================
class CSymbolBacktest
  {
public:
   string            symbol;
   CBacktestInstance* inst_m15;
   CBacktestInstance* inst_h1;
   CBacktestInstance* inst_h4;
   CBacktestInstance* inst_d1;

   bool              completed_m15, completed_h1, completed_h4, completed_d1;
   bool              all_completed_and_sent;

                     CSymbolBacktest(string sym, bool isMetal, bool isCrypto, bool drawChart, color cSucc, color cFail,
                   bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO,
                   bool drwDemF, bool drwSupF, bool drwBullB, bool drwBearB)
     {
      symbol = sym;
      all_completed_and_sent = false;
      completed_m15 = false;
      completed_h1 = false;
      completed_h4 = false;
      completed_d1 = false;

      if(isMetal)
        {
         inst_m15 = new CBacktestInstance(sym, PERIOD_M15, met_dev_M15, met_dep_M15, met_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
         inst_h1  = new CBacktestInstance(sym, PERIOD_H1,  met_dev_H1,  met_dep_H1,  met_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
         inst_h4  = new CBacktestInstance(sym, PERIOD_H4,  met_dev_H4,  met_dep_H4,  met_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
         inst_d1  = new CBacktestInstance(sym, PERIOD_D1,  met_dev_D1,  met_dep_D1,  met_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
        }
      else
         if(isCrypto)
           {
            inst_m15 = new CBacktestInstance(sym, PERIOD_M15, cry_dev_M15, cry_dep_M15, cry_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_h1  = new CBacktestInstance(sym, PERIOD_H1,  cry_dev_H1,  cry_dep_H1,  cry_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_h4  = new CBacktestInstance(sym, PERIOD_H4,  cry_dev_H4,  cry_dep_H4,  cry_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_d1  = new CBacktestInstance(sym, PERIOD_D1,  cry_dev_D1,  cry_dep_D1,  cry_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
           }
         else
           {
            inst_m15 = new CBacktestInstance(sym, PERIOD_M15, fx_dev_M15, fx_dep_M15, fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_h1  = new CBacktestInstance(sym, PERIOD_H1,  fx_dev_H1,  fx_dep_H1,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_h4  = new CBacktestInstance(sym, PERIOD_H4,  fx_dev_H4,  fx_dep_H4,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
            inst_d1  = new CBacktestInstance(sym, PERIOD_D1,  fx_dev_D1,  fx_dep_D1,  fx_maxLookback, drawChart, cSucc, cFail, drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
           }
     }

                    ~CSymbolBacktest()
     {
      if(inst_m15)
         delete inst_m15;
      if(inst_h1)
         delete inst_h1;
      if(inst_h4)
         delete inst_h4;
      if(inst_d1)
         delete inst_d1;
     }

   bool              RunAllAndReport()
     {
      if(all_completed_and_sent)
         return true;

      if(!completed_m15)
         completed_m15 = inst_m15.RunBacktest();
      if(!completed_h1)
         completed_h1  = inst_h1.RunBacktest();
      if(!completed_h4)
         completed_h4  = inst_h4.RunBacktest();
      if(!completed_d1)
         completed_d1  = inst_d1.RunBacktest();

      if(completed_m15 && completed_h1 && completed_h4 && completed_d1)
        {
         master_report_csv += CBacktestReporter::FormatSymbolCSV(symbol, inst_m15.metrics, inst_h1.metrics, inst_h4.metrics, inst_d1.metrics);
         all_completed_and_sent = true;
         return true;
        }
      return false;
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CBacktestEngine
  {
private:
   CSymbolBacktest*   symbols[];
   int                total_symbols;
   int                current_scan_idx;
   bool               report_published;
   bool               waiting_for_python;

   bool              IsCrypto(string sym)
     {
      return (StringFind(sym, "BTC") >= 0);
     }

   bool              IsMetal(string sym)
     {
      return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0);
     }

public:
                     CBacktestEngine()
     {
      total_symbols = 0;
      current_scan_idx = 0;
      report_published = false;
      waiting_for_python = false;
     }

                    ~CBacktestEngine()
     {
      for(int i = 0; i < total_symbols; i++)
        {
         if(symbols[i])
            delete symbols[i];
        }
     }

   void              Initialize(bool draw, color cSucc, color cFail,
                                bool drwDem, bool drwSup, bool drwBullP, bool drwBearP, bool drwBullO, bool drwBearO,
                                bool drwDemF, bool drwSupF, bool drwBullB, bool drwBearB)
     {
      string TargetSymbols[] =
        {
         "BTCUSDm"
        };

      total_symbols = ArraySize(TargetSymbols);
      ArrayResize(symbols, total_symbols);

      for(int s = 0; s < total_symbols; s++)
        {
         SymbolSelect(TargetSymbols[s], true);
         symbols[s] = new CSymbolBacktest(TargetSymbols[s], IsMetal(TargetSymbols[s]), IsCrypto(TargetSymbols[s]), draw, cSucc, cFail,
                                          drwDem, drwSup, drwBullP, drwBearP, drwBullO, drwBearO, drwDemF, drwSupF, drwBullB, drwBearB);
        }

      // Build Exact CSV Headers
      master_report_csv = "Symbol,TF,Zone,Successes,Failure,Success Rate,Mean Success,Mean Fail,Success Scores,Failed Scores";
      for(int i=1; i<=9; i++)
         master_report_csv += ",Mean POC_" + IntegerToString(i) + "_Success,Mean POC_" + IntegerToString(i) + "_Fail";
      for(int i=1; i<=9; i++)
         master_report_csv += ",POC_" + IntegerToString(i) + "_success,POC_" + IntegerToString(i) + "_fail";
      master_report_csv += "\n";
     }

   void              ProcessBatch()
     {
      if(waiting_for_python)
        {
         if(FileIsExist("py_log_done.txt"))
           {
            Sleep(100);

            int fh = FileOpen("py_log_done.txt", FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE, '\t', CP_UTF8);
            if(fh != INVALID_HANDLE)
              {
               while(!FileIsEnding(fh))
                 {
                  string line = FileReadString(fh);
                  if(line != "")
                    {
                     Print("🐍 Python: ", line);
                     
                     // Detect and explicitly print any upload link found in the Python logs
                     if(StringFind(line, "http://") >= 0 || StringFind(line, "https://") >= 0)
                       {
                        Print("🔗 Excel Report Link: ", line);
                       }
                    }
                 }
               FileClose(fh);
               FileDelete("py_log_done.txt");

               Print("🎉 Backtest Engine Fully Finished!");
               waiting_for_python = false;
               EventKillTimer();
              }
           }
         return;
        }

      if(report_published)
         return;

      int processed = 0;
      while(processed < scanSpeedPerSecond && current_scan_idx < total_symbols)
        {
         if(!symbols[current_scan_idx].all_completed_and_sent)
           {
            Print("Scanning Chart Data for: ", symbols[current_scan_idx].symbol);
            if(!symbols[current_scan_idx].RunAllAndReport())
              {
               Print("History not fully loaded yet for ", symbols[current_scan_idx].symbol, ". Skipped temporarily to load cache.");
              }
           }
         current_scan_idx++;
         processed++;
        }

      if(current_scan_idx >= total_symbols)
        {
         bool all_done = true;
         for(int i = 0; i < total_symbols; i++)
           {
            if(!symbols[i].all_completed_and_sent)
              {
               all_done = false;
               break;
              }
           }
         if(!all_done)
           {
            current_scan_idx = 0;
           }
         else
           {
            int fh = FileOpen("SMC_Master_Report.csv", FILE_WRITE | FILE_CSV | FILE_ANSI);
            if(fh != INVALID_HANDLE)
              {
               FileWriteString(fh, master_report_csv);
               FileClose(fh);
               Print("💾 Saved Base Data locally to MQL5/Files/SMC_Master_Report.csv");
              }

            FileDelete("py_log_temp.txt");
            FileDelete("py_log_done.txt");

            Print("⚙️ Launching Python silently in the background...");
            string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
            string python_command = "/c python format_and_upload.py";

            ShellExecuteW(0, "open", "cmd.exe", python_command, terminal_data_path, 0);

            report_published = true;
            waiting_for_python = true;
           }
        }
     }

  };
CBacktestEngine* engine = NULL;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   Print("🚀 Initializing SMC Master Backtest Generator...");

// Allocate dynamic inputs to state variables
   CLTFConfirmationEngine::m_fx_dev_m1 = fx_dev_M1;
   CLTFConfirmationEngine::m_fx_dep_m1 = fx_dep_M1;
   CLTFConfirmationEngine::m_mc_dev_m1 = cry_dev_M1;
   CLTFConfirmationEngine::m_mc_dep_m1 = cry_dep_M1;
   CLTFConfirmationEngine::m_fx_maxLookback = fx_maxLookback;
   CLTFConfirmationEngine::m_mc_maxLookback = cry_maxLookback;

   engine = new CBacktestEngine();
   engine.Initialize(drawOnAllCharts, successZoneColor, failZoneColor,
                     drawDemandZones, drawSupplyZones, drawBullishPOI, drawBearishPOI, drawBullishOB, drawBearishOB,
                     drawDemandFlip, drawSupplyFlip, drawBullishBreaker, drawBearishBreaker);
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   if(engine)
      delete engine;

   long currChart = ChartFirst();
   while(currChart >= 0)
     {
      ObjectsDeleteAll(currChart, "BT_");
      ChartRedraw(currChart);
      currChart = ChartNext(currChart);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(engine)
      engine.ProcessBatch();
  }
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Backtesting\backtest.mq5

// END FILE: Experts\Custom EAs\Backtesting\backtest.mq5
