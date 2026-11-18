#define MARCO_LOG_PROGRAM "OandaHeatmapEA"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                           OandaBookmapPro.mq5    |
//|                    With Spoofing Detection & Lot Sizing Engine   |
//|                                  Copyright 2026, AI Quant Studio |
//+------------------------------------------------------------------+
#property copyright "AI Quant Studio"
#property link      "https://www.mql5.com"
#property version   "3.00"

#include <Canvas\Canvas.mqh>

//--- Inputs
input group "=== Data Settings ==="
input string   InpInstrument      = "XAUUSD";      // Symbol (XAUUSD, EURUSD, etc.)
input string   InpBookType        = "ORDER";       // Book Type (ORDER or POSITION)
input int      InpRefreshSec      = 30;            // Refresh Interval (Seconds)

input group "=== Lot & Contract Sizing ==="
input double   InpTotalBookLots   = 10000.0;       // Estimated Total Broker Book (Lots)
input double   InpContractSize    = 100.0;         // Contract Size (100 for Gold, 100k for FX)

input group "=== Spoofing / Liquidity-Pulling Detection ==="
input bool     InpEnableSpoofAlert= true;          // Enable Spoofing Detection
input double   InpSpoofMinPct     = 0.15;          // Minimum Size to Monitor for Spoof (%)
input double   InpSpoofDropRatio  = 0.60;          // % Drop to Trigger Spoof (0.60 = 60% pulled)

input group "=== Bookmap Visual Settings ==="
input uchar    InpCanvasAlpha     = 150;           // Heatmap Transparency (0-255)
input double   InpContrastBoost   = 2.0;           // Color Contrast Boost (1.0 - 5.0)
input bool     InpShowDOM         = true;          // Show Bookmap DOM Column
input int      InpDOMWidth        = 180;           // DOM Column Width (Pixels)

//--- Structures
struct HeatBucket
{
   double price;
   double longPct;
   double shortPct;
   double totalPct;
   double estLots;
   double estDollarVal;
};

struct SpoofRecord
{
   double   price;
   datetime time;
   double   pulledLots;
   double   dropPct;
};

//--- Globals
CCanvas      g_canvas;
string       g_canvas_name   = "Bookmap_Heatmap_Canvas";
HeatBucket   g_buckets[];
HeatBucket   g_prev_buckets[];
int          g_bucket_count  = 0;
int          g_prev_count    = 0;
double       g_max_pct       = 0.001;
double       g_bucket_width  = 0.5;
datetime     g_last_fetch    = 0;
SpoofRecord  g_spoofs[];
int          g_spoof_count   = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_marcoDailyLog.Start();
   ChartSetInteger(0, CHART_FOREGROUND, true);
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, true);

   InitCanvas();
   EventSetTimer(5);
   FetchOandaData();
   RenderBookmap();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   EventKillTimer();
   g_canvas.Destroy();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Timer Event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_marcoDailyLog.Pulse();
   if(TimeCurrent() - g_last_fetch >= InpRefreshSec)
   {
      FetchOandaData();
      RenderBookmap();
   }
}

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   g_marcoDailyLog.Pulse();
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      InitCanvas();
      RenderBookmap();
   }
}

//+------------------------------------------------------------------+
//| Initialize Canvas Bitmap                                         |
//+------------------------------------------------------------------+
void InitCanvas()
{
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(w <= 0 || h <= 0) return;

   g_canvas.Destroy();
   g_canvas.CreateBitmapLabel(0, 0, g_canvas_name, 0, 0, w, h, COLOR_FORMAT_ARGB_NORMALIZE);
}

//+------------------------------------------------------------------+
//| Fetch GraphQL Order Book                                         |
//+------------------------------------------------------------------+
void FetchOandaData()
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

   string payload = StringFormat("{\"operationName\":\"GetOrderPositionBook\","
                                 "\"variables\":{\"instrument\":\"%s\",\"bookType\":\"%s\",\"recentHours\":1},"
                                 "\"query\":\"%s\"}", InpInstrument, InpBookType, query);

   char post_data[], result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post_data, ArraySize(post_data) - 1);

   ResetLastError();
   int res = WebRequest("POST", url, headers, 8000, post_data, result_data, result_headers);

   if(res == 200)
   {
      string response = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
      g_last_fetch = TimeCurrent();

      // Archive previous snapshot for Spoofing Diff
      ArchivePreviousSnapshot();
      ParseBuckets(response);

      if(InpEnableSpoofAlert && g_prev_count > 0)
      {
         DetectSpoofing();
      }
   }
}

//+------------------------------------------------------------------+
//| Archive previous state for delta comparison                      |
//+------------------------------------------------------------------+
void ArchivePreviousSnapshot()
{
   g_prev_count = g_bucket_count;
   ArrayResize(g_prev_buckets, g_prev_count);
   for(int i = 0; i < g_prev_count; i++)
   {
      g_prev_buckets[i] = g_buckets[i];
   }
}

//+------------------------------------------------------------------+
//| Parse JSON & Calculate Lots / Dollar Values                      |
//+------------------------------------------------------------------+
void ParseBuckets(string &json)
{
   g_bucket_count = 0;
   g_max_pct = 0.001;

   int bwPos = StringFind(json, "\"bucketWidth\":");
   if(bwPos != -1)
   {
      g_bucket_width = ExtractDouble(json, "\"bucketWidth\":");
      if(g_bucket_width <= 0) g_bucket_width = 0.5;
   }

   int searchPos = 0;
   while((searchPos = StringFind(json, "{\"price\":", searchPos)) != -1)
   {
      int endPos = StringFind(json, "}", searchPos);
      if(endPos == -1) break;

      string block = StringSubstr(json, searchPos, endPos - searchPos + 1);

      double bPrice = ExtractDouble(block, "\"price\":");
      double bLong  = ExtractDouble(block, "\"longCountPercent\":");
      double bShort = ExtractDouble(block, "\"shortCountPercent\":");
      double bTotal = bLong + bShort;

      ArrayResize(g_buckets, g_bucket_count + 1);
      g_buckets[g_bucket_count].price        = bPrice;
      g_buckets[g_bucket_count].longPct      = bLong;
      g_buckets[g_bucket_count].shortPct     = bShort;
      g_buckets[g_bucket_count].totalPct     = bTotal;

      // Mathematical Lot & Dollar Sizing
      double estLots = (bTotal / 100.0) * InpTotalBookLots;
      g_buckets[g_bucket_count].estLots      = estLots;
      g_buckets[g_bucket_count].estDollarVal = estLots * InpContractSize * bPrice;

      if(bTotal > g_max_pct) g_max_pct = bTotal;
      g_bucket_count++;

      searchPos = endPos + 1;
   }
}

//+------------------------------------------------------------------+
//| Spoofing & Fake Liquidity Detection Algorithm                    |
//+------------------------------------------------------------------+
void DetectSpoofing()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, _Period, 0, 3, rates);

   for(int i = 0; i < g_prev_count; i++)
   {
      double prevPrice = g_prev_buckets[i].price;
      double prevPct   = g_prev_buckets[i].totalPct;

      if(prevPct < InpSpoofMinPct) continue;

      // Find matching price in current snapshot
      int currIdx = -1;
      for(int j = 0; j < g_bucket_count; j++)
      {
         if(MathAbs(g_buckets[j].price - prevPrice) < 0.001)
         {
            currIdx = j;
            break;
         }
      }

      double currPct = (currIdx != -1) ? g_buckets[currIdx].totalPct : 0.0;
      double dropRatio = (prevPct - currPct) / prevPct;

      // Check if huge liquidity vanished
      if(dropRatio >= InpSpoofDropRatio)
      {
         // Verify price NEVER actually traded through this level (cancelled, not filled)
         bool wasExecuted = false;
         for(int r = 0; r < ArraySize(rates); r++)
         {
            if(rates[r].low <= prevPrice && rates[r].high >= prevPrice)
            {
               wasExecuted = true;
               break;
            }
         }

         if(!wasExecuted)
         {
            double pulledLots = ((prevPct - currPct) / 100.0) * InpTotalBookLots;
            
            ArrayResize(g_spoofs, g_spoof_count + 1);
            g_spoofs[g_spoof_count].price      = prevPrice;
            g_spoofs[g_spoof_count].time       = TimeCurrent();
            g_spoofs[g_spoof_count].pulledLots = pulledLots;
            g_spoofs[g_spoof_count].dropPct    = dropRatio * 100.0;
            g_spoof_count++;

            PrintFormat("⚠️ [SPOOF DETECTED] Price: %.2f | Pulled: %.1f Lots (-%.0f%%) without execution!", 
                        prevPrice, pulledLots, dropRatio * 100.0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Render Bookmap Canvas with Lots & Spoof Overlays                 |
//+------------------------------------------------------------------+
void RenderBookmap()
{
   int width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(width <= 0 || height <= 0 || g_bucket_count == 0) return;

   g_canvas.Erase(0x00000000);

   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   if(priceMax <= priceMin) return;

   int heatmapWidth = InpShowDOM ? (width - InpDOMWidth) : width;

   // 1. RENDER BACKGROUND HEAT BANDS
   for(int i = 0; i < g_bucket_count; i++)
   {
      double pTop = g_buckets[i].price + (g_bucket_width / 2.0);
      double pBot = g_buckets[i].price - (g_bucket_width / 2.0);

      if(pTop < priceMin || pBot > priceMax) continue;

      int yTop = PriceToY(pTop, priceMin, priceMax, height);
      int yBot = PriceToY(pBot, priceMin, priceMax, height);

      double norm = MathMin(1.0, (g_buckets[i].totalPct / g_max_pct) * InpContrastBoost);
      uint argbColor = GetBookmapColor(norm, InpCanvasAlpha);

      for(int y = yTop; y <= yBot; y++)
      {
         if(y >= 0 && y < height)
         {
            g_canvas.LineHorizontal(0, heatmapWidth, y, argbColor);
         }
      }
   }

   // 2. RENDER ACTIVE SPOOF WARNINGS ON CHART
   for(int s = MathMax(0, g_spoof_count - 5); s < g_spoof_count; s++)
   {
      if(g_spoofs[s].price >= priceMin && g_spoofs[s].price <= priceMax)
      {
         int spoofY = PriceToY(g_spoofs[s].price, priceMin, priceMax, height);
         
         // Draw dashed spoof marker
         g_canvas.LineHorizontal(0, heatmapWidth, spoofY, ((uint)255 << 24) | ((uint)255 << 16) | ((uint)50 << 8) | 50);
         g_canvas.FontSet("Trebuchet MS", 9, FW_BOLD);
         g_canvas.TextOut(15, spoofY - 14, 
            StringFormat("⚠️ FAKE LIQUIDITY / SPOOF: -%.1f Lots (Pulled)", g_spoofs[s].pulledLots), 
            ((uint)255 << 24) | ((uint)255 << 16) | ((uint)215 << 8) | 0);
      }
   }

   // 3. RENDER DOM COLUMN WITH DETAILED LOT SIZES
   if(InpShowDOM)
   {
      uint domBg   = ((uint)235 << 24) | ((uint)14 << 16) | ((uint)18 << 8) | (uint)26;
      uint domLine = ((uint)255 << 24) | ((uint)45 << 16) | ((uint)55 << 8) | (uint)75;

      g_canvas.FillRectangle(heatmapWidth, 0, width, height, domBg);
      g_canvas.LineVertical(heatmapWidth, 0, height, domLine);

      for(int i = 0; i < g_bucket_count; i++)
      {
         if(g_buckets[i].price < priceMin || g_buckets[i].price > priceMax) continue;

         int yCenter = PriceToY(g_buckets[i].price, priceMin, priceMax, height);
         int barLen = (int)((g_buckets[i].totalPct / g_max_pct) * (InpDOMWidth - 75));

         if(barLen > 2 && yCenter >= 2 && yCenter < height - 2)
         {
            double norm = MathMin(1.0, (g_buckets[i].totalPct / g_max_pct) * InpContrastBoost);
            uint barColor = GetBookmapColor(norm, 240);

            g_canvas.FillRectangle(heatmapWidth + 2, yCenter - 2, heatmapWidth + 2 + barLen, yCenter + 2, barColor);
            
            // Print exact Lot count on major walls
            if(g_buckets[i].estLots >= 10.0)
            {
               g_canvas.FontSet("Calibri", 8, FW_NORMAL);
               g_canvas.TextOut(heatmapWidth + barLen + 6, yCenter - 5, 
                  StringFormat("%.0fL", g_buckets[i].estLots), 
                  ((uint)200 << 24) | ((uint)200 << 16) | ((uint)220 << 8) | 255);
            }
         }
      }

      uint goldClr = ((uint)255 << 24) | ((uint)255 << 16) | ((uint)215 << 8) | (uint)0;
      uint cyanClr = ((uint)255 << 24) | ((uint)0 << 16) | ((uint)255 << 8) | (uint)255;

      g_canvas.FontSet("Trebuchet MS", 10, FW_BOLD);
      g_canvas.TextOut(heatmapWidth + 8, 8, "BOOKMAP DOM", goldClr);
      g_canvas.TextOut(heatmapWidth + 8, 24, StringFormat("MAX: %.0f Lots", (g_max_pct/100.0)*InpTotalBookLots), cyanClr);
   }

   g_canvas.Update();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Bookmap Color Palette                                            |
//+------------------------------------------------------------------+
uint GetBookmapColor(double norm, uchar alpha)
{
   uchar r = 0, g = 0, b = 0;
   if(norm < 0.20)
   {
      double t = norm / 0.20;
      r = (uchar)(10 + 10 * t); g = (uchar)(25 + 45 * t); b = (uchar)(60 + 90 * t);
   }
   else if(norm < 0.45)
   {
      double t = (norm - 0.20) / 0.25;
      r = 0; g = (uchar)(70 + 130 * t); b = (uchar)(150 + 80 * t);
   }
   else if(norm < 0.70)
   {
      double t = (norm - 0.45) / 0.25;
      r = (uchar)(255 * t); g = (uchar)(200 + 40 * t); b = 0;
   }
   else if(norm < 0.88)
   {
      double t = (norm - 0.70) / 0.18;
      r = 255; g = (uchar)(240 - 120 * t); b = 0;
   }
   else
   {
      double t = (norm - 0.88) / 0.12;
      r = 255; g = (uchar)(120 * (1.0 - t)); b = (uchar)(60 * t);
   }
   return (((uint)alpha) << 24) | (((uint)r) << 16) | (((uint)g) << 8) | ((uint)b);
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
int PriceToY(double price, double minPrice, double maxPrice, int height)
{
   if(maxPrice <= minPrice) return 0;
   return (int)((maxPrice - price) / (maxPrice - minPrice) * height);
}

double ExtractDouble(string &src, string key)
{
   int kPos = StringFind(src, key);
   if(kPos == -1) return 0.0;
   int start = kPos + StringLen(key);
   int comma = StringFind(src, ",", start);
   int brace = StringFind(src, "}", start);
   int end = (comma != -1 && comma < brace) ? comma : brace;
   if(end == -1) return 0.0;
   return StringToDouble(StringSubstr(src, start, end - start));
}

// END FILE: Experts\Custom EAs\Alerting System\OandaHeatmapEA.mq5

// END FILE: Experts\Custom EAs\Alerting System\OandaHeatmapEA.mq5
