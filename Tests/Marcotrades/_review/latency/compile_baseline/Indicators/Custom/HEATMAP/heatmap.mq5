#define MARCO_LOG_PROGRAM "heatmap"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\daily_log.mqh"
//+------------------------------------------------------------------+
//|                                                 OandaHeatmap.mq5 |
//|                                  Copyright 2026, AI Quant Studio |
//+------------------------------------------------------------------+
#property copyright "AI Quant Studio"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Inputs
input string   InpInstrument      = "XAUUSD";      // Instrument (e.g., XAUUSD, EURUSD)
input string   InpBookType        = "ORDER";       // Book Type (ORDER or POSITION)
input int      InpRefreshMinutes  = 15;            // Update Interval (Minutes)
input double   InpMinPercent      = 0.05;          // Minimum Heat Threshold (%)
input int      InpBarExtend       = 30;            // Heatmap Width (Bars into Future)

//--- Structures
struct HeatBucket
  {
   double            price;
   double            longPct;
   double            shortPct;
   double            totalPct;
  };

//--- Global Variables
datetime g_last_fetch = 0;
string   g_obj_prefix = "OANDA_HEAT_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_marcoDailyLog.Start();
   EventSetTimer(60); // Check every minute
   FetchAndRenderHeatmap();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   ClearHeatmap();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Timer event to auto-refresh orderbook                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_marcoDailyLog.Pulse();
   if(TimeCurrent() - g_last_fetch >= (InpRefreshMinutes * 60))
     {
      FetchAndRenderHeatmap();
     }
  }

//+------------------------------------------------------------------+
//| Main Iteration Function                                          |
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
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Fetch GraphQL Data & Paint Heatmap                               |
//+------------------------------------------------------------------+
void FetchAndRenderHeatmap()
  {
   string url = "https://labs-api.oanda.com/graphql";
   string headers = "Content-Type: application/json\r\n" +
                    "Origin: https://www.oanda.com\r\n" +
                    "Referer: https://www.oanda.com/\r\n" +
                    "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n";

   string query = "query GetOrderPositionBook($instrument: String!, $bookType: BookType!, $recentHours: Int) {"
                  " orderPositionBook(instrument: $instrument, bookType: $bookType, recentHours: $recentHours) {"
                  "   bucketWidth price time buckets { price longCountPercent shortCountPercent }"
                  " }"
                  "}";

// Construct JSON payload
   string payload = StringFormat("{\"operationName\":\"GetOrderPositionBook\","
                                 "\"variables\":{\"instrument\":\"%s\",\"bookType\":\"%s\",\"recentHours\":1},"
                                 "\"query\":\"%s\"}", InpInstrument, InpBookType, query);

   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post_data, ArraySize(post_data) - 1); // remove null terminator

   ResetLastError();
   int res = WebRequest("POST", url, headers, 10000, post_data, result_data, result_headers);

   if(res == 200)
     {
      string response = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
      g_last_fetch = TimeCurrent();
      ParseAndDraw(response);
     }
   else
     {
      PrintFormat("❌ WebRequest Failed (Error: %d, HTTP: %d). Ensure URL is added in MT5 Options.", GetLastError(), res);
     }
  }

//+------------------------------------------------------------------+
//| Simple JSON Bucket Parser & Visualizer                           |
//+------------------------------------------------------------------+
void ParseAndDraw(string &json)
  {
   ClearHeatmap();

   HeatBucket buckets[];
   int bucketCount = 0;
   double maxIntensity = 0.0001;

// Simple string-based extraction for MQL5 (standalone)
   int searchPos = 0;
   while((searchPos = StringFind(json, "{\"price\":", searchPos)) != -1)
     {
      int endPos = StringFind(json, "}", searchPos);
      if(endPos == -1)
         break;

      string block = StringSubstr(json, searchPos, endPos - searchPos + 1);

      double bPrice = ExtractJsonDouble(block, "\"price\":");
      double bLong  = ExtractJsonDouble(block, "\"longCountPercent\":");
      double bShort = ExtractJsonDouble(block, "\"shortCountPercent\":");
      double bTotal = bLong + bShort;

      if(bTotal >= InpMinPercent)
        {
         ArrayResize(buckets, bucketCount + 1);
         buckets[bucketCount].price    = bPrice;
         buckets[bucketCount].longPct  = bLong;
         buckets[bucketCount].shortPct = bShort;
         buckets[bucketCount].totalPct = bTotal;

         if(bTotal > maxIntensity)
            maxIntensity = bTotal;
         bucketCount++;
        }
      searchPos = endPos + 1;
     }

   PrintFormat("🔥 Rendered %d Heatmap Liquidity Blocks (Max Intensity: %.2f%%)", bucketCount, maxIntensity);

// Determine chart boundaries
   datetime time_start = TimeCurrent();
   datetime time_end   = time_start + (PeriodSeconds() * InpBarExtend);

// Draw Heatmap Blocks
   for(int i = 0; i < bucketCount; i++)
     {
      double intensityNorm = buckets[i].totalPct / maxIntensity; // 0.0 to 1.0
      color heatColor = GetHeatColor(intensityNorm, buckets[i].longPct > buckets[i].shortPct);

      string objName = g_obj_prefix + IntegerToString(i);
      double pTop    = buckets[i].price + (Point() * 5);
      double pBottom = buckets[i].price - (Point() * 5);

      if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time_start, pTop, time_end, pBottom))
        {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, heatColor);
         ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, heatColor);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                         StringFormat("Price: %.2f | Longs: %.2f%% | Shorts: %.2f%% | Total: %.2f%%",
                                      buckets[i].price, buckets[i].longPct, buckets[i].shortPct, buckets[i].totalPct));
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Generate Bookmap-Style Heatmap Colors                            |
//+------------------------------------------------------------------+
color GetHeatColor(double normValue, bool isLongDominant)
  {
// Bookmap Color Scale: Low Liquidity (Dark/Cool) -> High Liquidity (Hot/Yellow/Orange/Red)
   if(normValue < 0.15)
      return C'20,25,45';       // Cold Dark Navy
   if(normValue < 0.35)
      return C'0,100,180';      // Deep Blue
   if(normValue < 0.55)
      return C'0,200,200';      // Cyan / Aqua
   if(normValue < 0.75)
      return C'255,215,0';      // Bright Gold / Yellow (High Liquidity)
   if(normValue < 0.90)
      return C'255,100,0';      // Orange (Major Order Block)
   return C'255,20,50';                           // Ultra Heat (Giant Liquidity Wall)
  }

//+------------------------------------------------------------------+
//| Extract double field value from string segment                   |
//+------------------------------------------------------------------+
double ExtractJsonDouble(string &src, string key)
  {
   int kPos = StringFind(src, key);
   if(kPos == -1)
      return 0.0;
   int start = kPos + StringLen(key);
   int comma = StringFind(src, ",", start);
   int brace = StringFind(src, "}", start);
   int end = (comma != -1 && comma < brace) ? comma : brace;
   if(end == -1)
      return 0.0;
   return StringToDouble(StringSubstr(src, start, end - start));
  }

//+------------------------------------------------------------------+
//| Cleanup Chart Objects                                            |
//+------------------------------------------------------------------+
void ClearHeatmap()
  {
   ObjectsDeleteAll(0, g_obj_prefix);
  }
//+------------------------------------------------------------------+

// END FILE: Indicators\Custom\HEATMAP\heatmap.mq5

// END FILE: Indicators\Custom\HEATMAP\heatmap.mq5
