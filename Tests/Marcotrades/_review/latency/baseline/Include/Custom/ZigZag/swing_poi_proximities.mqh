//+------------------------------------------------------------------+
//|                             Include\Custom\ZigZag\swing_poi_proximities.mqh |
//|                         Swing POI Proximity Monitor and Alert EA  |
//+------------------------------------------------------------------+
#ifndef SWING_POI_PROXIMITIES_MQH
#define SWING_POI_PROXIMITIES_MQH

// =========================================================================
// SAFE STANDALONE CLEAN SYMBOL PREPROCESSOR GUARD
// =========================================================================
#ifndef CLEAN_SYMBOL_FN
#define CLEAN_SYMBOL_FN
string CleanSymbol(string sym)
  {
   int len = StringLen(sym);
   if(len > 1 && StringSubstr(sym, len - 1, 1) == "m")
     {
      return StringSubstr(sym, 0, len - 1);
     }
   return sym;
  }
#endif

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\General\teams_alert.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSwingPOIProximityScanner
  {
public:
   // Static Forex Settings
   static int        fx_maxLookback;
   static double     fx_dev_D1;
   static int        fx_dep_D1;
   static double     fx_dev_H4;
   static int        fx_dep_H4;
   static double     fx_dev_H1;
   static int        fx_dep_H1;
   static double     fx_dev_M15;
   static int        fx_dep_M15;

   // Static Metals Settings
   static int        met_maxLookback;
   static double     met_dev_D1;
   static int        met_dep_D1;
   static double     met_dev_H4;
   static int        met_dep_H4;
   static double     met_dev_H1;
   static int        met_dep_H1;
   static double     met_dev_M15;
   static int        met_dep_M15;

   // Static Crypto Settings
   static int        cry_maxLookback;
   static double     cry_dev_D1;
   static int        cry_dep_D1;
   static double     cry_dev_H4;
   static int        cry_dep_H4;
   static double     cry_dev_H1;
   static int        cry_dep_H1;
   static double     cry_dev_M15;
   static int        cry_dep_M15;

   static void       RunSwingPOIScan(double maxPips);
   static void       Process(double maxPips);

private:
   static bool       IsCrypto(string sym)
     {
      return (StringFind(sym, "BTC") >= 0);
     }

   static bool       IsMetal(string sym)
     {
      return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0);
     }
  };

// Initialize Forex Static Members
int    CSwingPOIProximityScanner::fx_maxLookback = 3000;
double CSwingPOIProximityScanner::fx_dev_D1      = 1.0;
int    CSwingPOIProximityScanner::fx_dep_D1      = 15;
double CSwingPOIProximityScanner::fx_dev_H4      = 0.5;
int    CSwingPOIProximityScanner::fx_dep_H4      = 2;
double CSwingPOIProximityScanner::fx_dev_H1      = 0.5;
int    CSwingPOIProximityScanner::fx_dep_H1      = 15;
double CSwingPOIProximityScanner::fx_dev_M15     = 0.5;
int    CSwingPOIProximityScanner::fx_dep_M15     = 5;

// Initialize Metals Static Members
int    CSwingPOIProximityScanner::met_maxLookback = 5000;
double CSwingPOIProximityScanner::met_dev_D1      = 5.0;
int    CSwingPOIProximityScanner::met_dep_D1      = 15;
double CSwingPOIProximityScanner::met_dev_H4      = 5.0;
int    CSwingPOIProximityScanner::met_dep_H4      = 15;
double CSwingPOIProximityScanner::met_dev_H1      = 2.66;
int    CSwingPOIProximityScanner::met_dep_H1      = 11;
double CSwingPOIProximityScanner::met_dev_M15     = 2.66;
int    CSwingPOIProximityScanner::met_dep_M15     = 12;

// Initialize Crypto Static Members
int    CSwingPOIProximityScanner::cry_maxLookback = 5000;
double CSwingPOIProximityScanner::cry_dev_D1      = 5.0;
int    CSwingPOIProximityScanner::cry_dep_D1      = 15;
double CSwingPOIProximityScanner::cry_dev_H4      = 5.0;
int    CSwingPOIProximityScanner::cry_dep_H4      = 15;
double CSwingPOIProximityScanner::cry_dev_H1      = 2.66;
int    CSwingPOIProximityScanner::cry_dep_H1      = 11;
double CSwingPOIProximityScanner::cry_dev_M15     = 2.66;
int    CSwingPOIProximityScanner::cry_dep_M15     = 12;

//+------------------------------------------------------------------+
//| Cyclic Process Sweep Execution                                   |
//+------------------------------------------------------------------+
void CSwingPOIProximityScanner::Process(double maxPips)
  {
   static datetime last_scan_time = 0;
   if(TimeCurrent() - last_scan_time >= 3600)
     {
      RunSwingPOIScan(maxPips);
      last_scan_time = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Core Multi-Symbol POI Proximity Sweep Engine                     |
//+------------------------------------------------------------------+
void CSwingPOIProximityScanner::RunSwingPOIScan(double maxPips)
  {
   Print("🚀 Starting Swing POI Proximity Sweep...");

   string TargetSymbols[] =
     {
      "BTCUSDm", "XAGUSDm", "XAUUSDm",
      "AUDCADm", "AUDCHFm", "AUDJPYm", "AUDNZDm", "AUDUSDm",
      "CADCHFm", "CADJPYm", "CHFJPYm",
      "EURAUDm", "EURCADm", "EURCHFm", "EURGBPm", "EURJPYm", "EURNZDm", "EURUSDm",
      "GBPAUDm", "GBPCADm", "GBPCHFm", "GBPJPYm", "GBPNZDm", "GBPUSDm",
      "NZDCADm", "NZDCHFm", "NZDJPYm", "NZDUSDm",
      "USDCADm", "USDCHFm", "USDJPYm"
     };

   ENUM_TIMEFRAMES TargetTFs[] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };

   int total_near_pois = 0;
   string csv_report = "Symbol,Timeframe,ZoneType,Price,ZoneHigh,ZoneLow,DistancePips,Direction\r\n";

   int symCount = ArraySize(TargetSymbols);
   int tfCount  = ArraySize(TargetTFs);

   for(int s = 0; s < symCount; s++)
     {
      string sym = TargetSymbols[s];
      if(!SymbolSelect(sym, true))
         continue;

      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(bid <= 0 || ask <= 0)
         continue;

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

      bool isMet = IsMetal(sym);
      bool isCry = IsCrypto(sym);

      for(int t = 0; t < tfCount; t++)
        {
         ENUM_TIMEFRAMES tf = TargetTFs[t];

         double dev = 1.0;
         int dep = 15;
         int maxLB = isMet ? met_maxLookback : (isCry ? cry_maxLookback : fx_maxLookback);

         if(isMet)
           {
            if(tf == PERIOD_D1)
              {
               dev = met_dev_D1;
               dep = met_dep_D1;
              }
            else
               if(tf == PERIOD_H4)
                 {
                  dev = met_dev_H4;
                  dep = met_dep_H4;
                 }
               else
                  if(tf == PERIOD_H1)
                    {
                     dev = met_dev_H1;
                     dep = met_dep_H1;
                    }
                  else
                     if(tf == PERIOD_M15)
                       {
                        dev = met_dev_M15;
                        dep = met_dep_M15;
                       }
           }
         else
            if(isCry)
              {
               if(tf == PERIOD_D1)
                 {
                  dev = cry_dev_D1;
                  dep = cry_dep_D1;
                 }
               else
                  if(tf == PERIOD_H4)
                    {
                     dev = cry_dev_H4;
                     dep = cry_dep_H4;
                    }
                  else
                     if(tf == PERIOD_H1)
                       {
                        dev = cry_dev_H1;
                        dep = cry_dep_H1;
                       }
                     else
                        if(tf == PERIOD_M15)
                          {
                           dev = cry_dev_M15;
                           dep = cry_dep_M15;
                          }
              }
            else
              {
               if(tf == PERIOD_D1)
                 {
                  dev = fx_dev_D1;
                  dep = fx_dep_D1;
                 }
               else
                  if(tf == PERIOD_H4)
                    {
                     dev = fx_dev_H4;
                     dep = fx_dep_H4;
                    }
                  else
                     if(tf == PERIOD_H1)
                       {
                        dev = fx_dev_H1;
                        dep = fx_dep_H1;
                       }
                     else
                        if(tf == PERIOD_M15)
                          {
                           dev = fx_dev_M15;
                           dep = fx_dep_M15;
                          }
              }

         int rates_total = Bars(sym, tf);
         if(rates_total < dep * 2)
            continue;

         int start_bar = MathMax(0, rates_total - maxLB);
         int to_copy = rates_total - start_bar;

         double high[], low[], close[];
         datetime time[];
         long vol[];

         if(CopyTime(sym, tf, 0, to_copy, time) <= 0)
            continue;
         if(CopyHigh(sym, tf, 0, to_copy, high) <= 0)
            continue;
         if(CopyLow(sym, tf, 0, to_copy, low) <= 0)
            continue;
         if(CopyClose(sym, tf, 0, to_copy, close) <= 0)
            continue;
         if(CopyTickVolume(sym, tf, 0, to_copy, vol) <= 0)
            continue;

         // Initialize Indicator Calculations
         Settings* settings = new Settings(dev, dep, clrNONE, true, false, false, false, "Percent");
         settings.draw = false;
         ZigZag* zz = newInstance(settings);

         CMarketStructure* ms = new CMarketStructure();
         ms.Init(false, false);

         CSwingPOILogic* sp = new CSwingPOILogic();

         for(int i = 0; i < to_copy; i++)
           {
            bool is_last = (i == to_copy - 1);
            int bar_index = start_bar + i;

            // Explicit type casting applied to volume parameters to eliminate data loss warnings
            zz.update(high[i], low[i], time[i], vol[i], bar_index, !is_last, is_last);
            ms.Update(i, time, high, low, close, zz);
            sp.DetectPOIs(i, time, high, low, zz);
            sp.UpdateMitigation(close[i]);
           }

         // Analyze Bullish Swing POI Proximities
         for(int i = 0; i < sp.poi_demandTime.Total(); i++)
           {
            if(sp.poi_demandMitigated.At(i) == 1)
               continue;

            double zHigh = sp.poi_demandZoneHigh.At(i);
            double zLow  = sp.poi_demandZoneLow.At(i);
            double distance = (bid - zHigh) / pipSize;

            if(bid > zHigh && distance <= maxPips)
              {
               total_near_pois++;
               csv_report += CleanSymbol(sym) + "," + StringSubstr(EnumToString(tf), 7) + ",Bullish POI," +
                             DoubleToString(bid, digits) + "," + DoubleToString(zHigh, digits) + "," +
                             DoubleToString(zLow, digits) + "," + DoubleToString(distance, 1) + ",Bullish\r\n";
              }
           }

         // Analyze Bearish Swing POI Proximities
         for(int i = 0; i < sp.poi_supplyTime.Total(); i++)
           {
            if(sp.poi_supplyMitigated.At(i) == 1)
               continue;

            double zHigh = sp.poi_supplyZoneHigh.At(i);
            double zLow  = sp.poi_supplyZoneLow.At(i);
            double distance = (zLow - ask) / pipSize;

            if(ask < zLow && distance <= maxPips)
              {
               total_near_pois++;
               csv_report += CleanSymbol(sym) + "," + StringSubstr(EnumToString(tf), 7) + ",Bearish POI," +
                             DoubleToString(ask, digits) + "," + DoubleToString(zHigh, digits) + "," +
                             DoubleToString(zLow, digits) + "," + DoubleToString(distance, 1) + ",Bearish\r\n";
              }
           }

         delete zz;
         delete ms;
         delete sp;
        }

      // PRINT TO CONSOLE UPON THE COMPLETION OF EVERY SYMBOL SWEPT
      PrintFormat("🔍 [Swing POI Proximity] Finished scanning symbol: %s (Processed with clean name: %s)", sym, CleanSymbol(sym));
     }

   if(total_near_pois > 0)
     {
      string fileName = "SMC_Swing_POI_Proximity_Report.csv";
      int fh = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
      if(fh != INVALID_HANDLE)
        {
         FileWriteString(fh, csv_report);
         FileClose(fh);
         PrintFormat("💾 Proximity results saved locally: %s. Pushing to MS Teams and Dashboard...", fileName);
        }

      string link = CBacktestReporter::UploadFileToCatbox(csv_report, "SMC_Swing_POI_Proximity_Report.csv");
      SendSwingPOIBatchTeamsAlert(total_near_pois, maxPips, link);
      CDashboardAPI::SendSwingPOIBatch("SMC_Swing_POI_Proximity_Report.csv", csv_report);
     }
   else
     {
      Print("ℹ️ Proximity Scan Complete: No symbols currently within criteria boundary limit.");
     }
  }

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\swing_poi_proximities.mqh

// END FILE: Include\Custom\ZigZag\swing_poi_proximities.mqh
