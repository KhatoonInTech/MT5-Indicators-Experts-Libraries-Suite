#define MARCO_LOG_PROGRAM "bestest"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                        Experts\ZigZag\bestest.mq5|
//|                    SMC ZigZag Combo Optimization Backtest Engine  |
//|                    v4.09 — Single-Chart Consolidated Event Sweep  |
//+------------------------------------------------------------------+
#property copyright "TradingView / Converted to MQL5"
#property version   "4.09"
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\bestest.mqh"

input group "Target Optimization Settings"
input string InputSymbol        = "EURUSDm";    // Target Symbol to Optimize
input int    max_look_bars      = 50000;        // Max Lookback Bars to test
input int    scanSpeedPerSecond = 20;           // Optimization tasks evaluated per timer tick
input int    MinTrades          = 5;            // Min Trades required to qualify a combo

input group "Sweep Grid Customization"
input bool   SweepAllDepths       = true;         // Sweep all depths (3 to 20)? If false, use FixedDepth
input int    FixedDepth           = 7;            // Fixed depth to use if SweepAllDepths is false

input group "PERIOD_M1 Confirmation Settings"
input double m1_dev                  = 0.10;         // Confirmation M1 Deviation
input int    m1_dep                  = 10;          // Confirmation M1 Depth

string master_report_csv = "";
int total_qualifying_rows = 0;

// =========================================================================
// COMBO TASK  — holds one (depth, deviation) pair and its instance
// =========================================================================
class CBestestTask
  {
public:
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   double            deviation;
   int               depth;
   bool              completed;
   BacktestMetricsLite metrics;
   CBestestInstance* instance;

                     CBestestTask(string sym, ENUM_TIMEFRAMES t, double devVal, int depVal)
     {
      symbol    = sym;
      tf        = t;
      deviation = devVal;
      depth     = depVal;
      completed = false;
      instance  = new CBestestInstance(sym, t, devVal, depVal, 0,
                                       false, clrNONE, clrNONE,
                                       false, false, false, false, false, false);
     }

                    ~CBestestTask() { if(instance) delete instance; }

   bool              Run(CSymbolTFCache* cache,
                         bool skipDem, bool skipSup,
                         bool skipBP, bool skipBrP,
                         bool skipBO, bool skipBrO,
                         bool skipDemF, bool skipSupF,
                         bool skipBullB, bool skipBearB)
     {
      if(completed)
         return true;
      completed = instance.RunBacktestFromCache(cache, skipDem, skipSup, skipBP, skipBrP, skipBO, skipBrO, skipDemF, skipSupF, skipBullB, skipBearB);
      if(completed)
         metrics = instance.metrics;
      return completed;
     }
  };

// =========================================================================
// SYMBOL/TF SLOT  — represents one timeframe's cache & test queue
// =========================================================================
class CSymbolTFSlot
  {
public:
   CSymbolTFCache*   cache;
   CBestestTask*     tasks[];
   int               task_count;
   int               task_idx;
   bool              cache_loaded;
   bool              all_done;


   // Per-zone perfect setup locks
   bool              perfect_demand;
   bool              perfect_supply;
   bool              perfect_bullPOI;
   bool              perfect_bearPOI;
   bool              perfect_bullOB;
   bool              perfect_bearOB;
   bool              perfect_demandFlip;
   bool              perfect_supplyFlip;
   bool              perfect_bullBreaker;
   bool              perfect_bearBreaker;

                     CSymbolTFSlot()
     {
      cache           = new CSymbolTFCache();
      task_count      = 0;
      task_idx        = 0;
      cache_loaded    = false;
      all_done        = false;

      perfect_demand  = false;
      perfect_supply  = false;
      perfect_bullPOI = false;
      perfect_bearPOI = false;
      perfect_bullOB  = false;
      perfect_bearOB  = false;
      perfect_demandFlip  = false;
      perfect_supplyFlip  = false;
      perfect_bullBreaker = false;
      perfect_bearBreaker = false;
     }


                    ~CSymbolTFSlot()
     {
      if(cache)
         delete cache;
      for(int i = 0; i < task_count; i++)
         if(tasks[i])
            delete tasks[i];
     }

   void              Init(string sym, ENUM_TIMEFRAMES t, double &devs[], int &deps[], int maxLB)
     {
      int nd = ArraySize(devs);
      int np = ArraySize(deps);
      task_count = nd * np;
      ArrayResize(tasks, task_count);

      int idx = 0;
      bool reverse_order = (t == PERIOD_H1 || t == PERIOD_H4 || t == PERIOD_D1);

      if(reverse_order)
        {
         for(int d = nd - 1; d >= 0; d--)
           {
            for(int p = np - 1; p >= 0; p--)
              {
               tasks[idx++] = new CBestestTask(sym, t, devs[d], deps[p]);
              }
           }
        }
      else
        {
         for(int d = 0; d < nd; d++)
           {
            for(int p = 0; p < np; p++)
              {
               tasks[idx++] = new CBestestTask(sym, t, devs[d], deps[p]);
              }
           }
        }

      cache_loaded = cache.Load(sym, t, maxLB);
      if(!cache_loaded)
         PrintFormat("⚠️ Cache load failed: %s %s", sym, EnumToString(t));
     }

   bool              ProcessBatch(int batchSize, string &csv_out)
     {
      if(all_done)
         return true;
      if(!cache_loaded)
        {
         all_done = true;
         return true;
        }

      int processed = 0;
      while(processed < batchSize && task_idx < task_count)
        {
         CBestestTask* task = tasks[task_idx];
         if(!task.completed)
           {
            task.Run(cache,
                     perfect_demand, perfect_supply,
                     perfect_bullPOI, perfect_bearPOI,
                     perfect_bullOB, perfect_bearOB,
                     perfect_demandFlip, perfect_supplyFlip,
                     perfect_bullBreaker, perfect_bearBreaker);

            if(task.completed)
              {
               csv_out += FormatCSV(task);

               if(perfect_demand  && perfect_supply  &&
                  perfect_bullPOI && perfect_bearPOI &&
                  perfect_bullOB  && perfect_bearOB  &&
                  perfect_demandFlip && perfect_supplyFlip &&
                  perfect_bullBreaker && perfect_bearBreaker)
                 {
                  PrintFormat("🔥 ALL ZONE TYPES found perfect 100%% setups on %s! Stopping loop.",
                              EnumToString(task.tf));
                  all_done = true;
                  return true;
                 }
              }
           }
         task_idx++;
         processed++;
        }

      if(task_idx >= task_count)
         all_done = true;

      return all_done;
     }


private:
   string            FormatRow(CBestestTask* task, string zoneName, ZoneStatsLite &metric, bool &perfect_flag)
     {
      if(perfect_flag)
         return "";

      int total = metric.success + metric.fail;
      if(total < MinTrades)
         return "";

      double successRate = metric.Ratio();
      double failureRate = ((double)metric.fail / total) * 100.0;

      if(successRate == 100.0 && failureRate == 0.0)
        {
         perfect_flag = true;
         PrintFormat("🎯 Perfect %s parameters found on %s! (Depth: %d, Dev: %.2f) — Zone locked.",
                     zoneName, EnumToString(task.tf), task.depth, task.deviation);
        }

      total_qualifying_rows++;
      string cleanSym = CleanSymbol(task.symbol);
      return cleanSym                           + "," +
             EnumToString(task.tf)              + "," +
             IntegerToString(task.depth)        + "," +
             DoubleToString(task.deviation, 2)  + "," +
             zoneName                           + "," +
             IntegerToString(metric.success)    + "," +
             IntegerToString(metric.fail)       + "," +
             DoubleToString(successRate, 2)     + "\n";
     }

   string            FormatCSV(CBestestTask* task)
     {
      string r = "";
      r += FormatRow(task, "Demand Zones",       task.metrics.demand,  perfect_demand);
      r += FormatRow(task, "Supply Zones",        task.metrics.supply,  perfect_supply);
      r += FormatRow(task, "Bullish Swing POI",   task.metrics.bullPOI, perfect_bullPOI);
      r += FormatRow(task, "Bearish Swing POI",   task.metrics.bearPOI, perfect_bearPOI);
      r += FormatRow(task, "Bullish OrderBlock",  task.metrics.bullOB,  perfect_bullOB);
      r += FormatRow(task, "Bearish OrderBlock",  task.metrics.bearOB,  perfect_bearOB);
      r += FormatRow(task, "Demand Flip Zone",    task.metrics.demandFlip, perfect_demandFlip);
      r += FormatRow(task, "Supply Flip Zone",    task.metrics.supplyFlip, perfect_supplyFlip);
      r += FormatRow(task, "Bullish Breaker",     task.metrics.bullBreaker, perfect_bullBreaker);
      r += FormatRow(task, "Bearish Breaker",      task.metrics.bearBreaker, perfect_bearBreaker);
      return r;
     }
  };

// =========================================================================
// ENGINE  — orchestrates sequential execution over M15 -> H1 -> H4 -> D1
// =========================================================================
class CBestestEngine
  {
private:
   CSymbolTFSlot*    slots[];
   int               total_slots;
   int               current_slot;
   bool              report_published;
   bool              waiting_for_python;

public:
                     CBestestEngine()
     {
      total_slots        = 0;
      current_slot       = 0;
      report_published   = false;
      waiting_for_python = false;
     }

                    ~CBestestEngine()
     {
      for(int i = 0; i < total_slots; i++)
         if(slots[i])
            delete slots[i];
     }

   void              Initialize()
     {
      double devs[] =
        {
         0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5,
         0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0,
         1.2,  1.4, 1.5,  1.6, 1.8,  2.0, 2.2,  2.4, 2.5,  2.6,
         2.8,  3.0, 3.5,  4.0, 4.5,  5.0, 6.0,  7.0, 8.0,  10.0
        };

      int deps[];
      if(SweepAllDepths)
        {
         ArrayResize(deps, 18);
         for(int i = 0; i < 18; i++)
            deps[i] = 3 + i;
        }
      else
        {
         ArrayResize(deps, 1);
         deps[0] = FixedDepth;
        }

      ENUM_TIMEFRAMES TFs[] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };

      int nt = ArraySize(TFs);
      total_slots = nt;
      ArrayResize(slots, total_slots);

      SymbolSelect(InputSymbol, true);
      total_qualifying_rows = 0;

      for(int t = 0; t < nt; t++)
        {
         slots[t] = new CSymbolTFSlot();
         slots[t].Init(InputSymbol, TFs[t], devs, deps, max_look_bars);
        }

      master_report_csv = "Symbol,TF,depth,deviation,Zone,Successes,Failure,Success Rate\n";

      int combos_per_slot = ArraySize(devs) * ArraySize(deps);
      PrintFormat("🚀 Sequential Engine Initialized — Symbol: %s | %d Timeframes × %d combos = %d total tasks",
                  InputSymbol, total_slots, combos_per_slot, total_slots * combos_per_slot);
     }

   void              ProcessBatch()
     {
      if(waiting_for_python)
        {
         if(FileIsExist("py_log_done.txt"))
           {
            Sleep(100);
            int fh = FileOpen("py_log_done.txt", FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ, '\t', CP_UTF8);
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
               PrintFormat("🎉 Consolidated Multi-Timeframe Sweep complete for %s!", InputSymbol);
               waiting_for_python = false;
               EventKillTimer();
              }
           }
         return;
        }

      if(report_published)
         return;

      if(current_slot < total_slots)
        {
         CSymbolTFSlot* slot = slots[current_slot];

         if(slot.task_idx == 0 && !slot.all_done)
            PrintFormat("📊 [Slot %d/%d] %s %s — sweeping %d combos...",
                        current_slot + 1, total_slots,
                        CleanSymbol(slot.cache.symbol), EnumToString(slot.cache.tf),
                        slot.task_count);

         bool done = slot.ProcessBatch(scanSpeedPerSecond, master_report_csv);

         if(done)
           {
            PrintFormat("✅ [Slot %d/%d] %s %s — done. Current Qualifying Setups: %d",
                        current_slot + 1, total_slots,
                        CleanSymbol(slot.cache.symbol), EnumToString(slot.cache.tf),
                        total_qualifying_rows);
            current_slot++;
           }
        }

      if(current_slot >= total_slots && !report_published)
        {
         int fh = FileOpen("SMC_Master_Report.csv", FILE_WRITE | FILE_CSV | FILE_ANSI);
         if(fh != INVALID_HANDLE)
           {
            FileWriteString(fh, master_report_csv);
            FileClose(fh);
            PrintFormat("💾 SMC_Master_Report.csv saved. Total high probability setups written: %d", total_qualifying_rows);
           }

         if(total_qualifying_rows == 0)
           {
            Print("⚠️ Note: No parameter combinations met the criteria.");
           }

         FileDelete("py_log_temp.txt");
         FileDelete("py_log_done.txt");

         Print("⚙️ Launching format_and_upload.py...");
         string data_path  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
         string py_command = "/c python format_and_upload.py";
         ShellExecuteW(0, "open", "cmd.exe", py_command, data_path, 0);

         report_published   = true;
         waiting_for_python = true;
        }
     }
  };

CBestestEngine* engine = NULL;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   PrintFormat("🚀 Initializing Sequential Optimization Sweep for %s...", InputSymbol);

// Allocate single dynamic sweep parameter to static confirmations
   CLTFConfirmationEngine::m_fx_dev_m1 = m1_dev;
   CLTFConfirmationEngine::m_fx_dep_m1 = m1_dep;
   CLTFConfirmationEngine::m_mc_dev_m1 = m1_dev;
   CLTFConfirmationEngine::m_mc_dep_m1 = m1_dep;
   CLTFConfirmationEngine::m_fx_maxLookback = max_look_bars;
   CLTFConfirmationEngine::m_mc_maxLookback = max_look_bars;

   engine = new CBestestEngine();
   engine.Initialize();
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
//+------------------------------------------------------------------+

// END FILE: Experts\Custom EAs\Backtesting\bestest.mq5

// END FILE: Experts\Custom EAs\Backtesting\bestest.mq5
