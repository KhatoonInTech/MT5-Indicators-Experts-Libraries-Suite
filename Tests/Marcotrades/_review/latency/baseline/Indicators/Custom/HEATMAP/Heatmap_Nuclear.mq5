#define MARCO_LOG_PROGRAM "Heatmap_Nuclear"
#include <Custom\General\daily_log.mqh>
//+------------------------------------------------------------------+
//|                                         Heatmap_Nuclear.mq5      |
//|                        Copyright 2026, Industrial MQL5 Architect |
//|                                  SINGLE FILE - DIAGNOSTIC MODE   |
//+------------------------------------------------------------------+
#property copyright "AI Collaborator"
#property version   "3.00"
#property indicator_chart_window
#property indicator_plots 0

#include <Canvas\Canvas.mqh>

// --- INPUTS ---
input int      InpWhaleThreshold = 1;        // Whale Threshold (Keep at 1 to see everything)
input color    InpColorHot       = clrRed;   // Color for Liquidity Lines
input bool     InpForceSim       = true;     // Auto-Switch to Fake Data if Broker is empty

// --- GLOBALS ---
CCanvas        Canvas;
MqlBookInfo    Book[];
int            ChartWidth;
int            ChartHeight;
bool           IsBrokerDataDead = true;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_marcoDailyLog.Start();
   // 1. Setup Broker Data Connection
   if(!MarketBookAdd(_Symbol)) Print("Error: Broker rejected MarketBookAdd");
   
   // 2. Setup Canvas (The Drawing Board)
   ChartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   ChartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // Create the invisible layer we draw on
   if(!Canvas.CreateBitmapLabel("HeatmapCanvas", 0, 0, ChartWidth, ChartHeight, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      Print("Error: Could not create Canvas!");
      return(INIT_FAILED);
   }
      
   // 3. Force Updates (Heartbeat every 100ms)
   // This ensures the screen draws even if the market is quiet
   EventSetMillisecondTimer(100);
   
   Print(">>> HEATMAP NUCLEAR ENGINE STARTED <<<");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)reason);
   MarketBookRelease(_Symbol);
   Canvas.Destroy();
   EventKillTimer();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   g_marcoDailyLog.Pulse();
   // Handle resizing the window
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      ChartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      Canvas.Resize(ChartWidth, ChartHeight);
   }
}

void OnMarketBookEvent(const string &symbol)
{
   if(symbol == _Symbol) DrawEngine();
}

void OnTimer()
{
   g_marcoDailyLog.Pulse();
   DrawEngine(); // Force draw loop
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   g_marcoDailyLog.Pulse();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| THE DRAWING CORE                                                 |
//+------------------------------------------------------------------+
void DrawEngine()
{
   Canvas.Erase(0x00000000); // Clear screen transparency

   // 1. GET DATA
   bool success = MarketBookGet(_Symbol, Book);
   int total = ArraySize(Book);
   
   // 2. DECIDE: REAL MODE or SIMULATION MODE
   if(success && total > 0)
   {
      // --- REAL MODE (BROKER IS WORKING) ---
      IsBrokerDataDead = false;
      double max_price = ChartGetDouble(0, CHART_PRICE_MAX);
      double min_price = ChartGetDouble(0, CHART_PRICE_MIN);
      double range = max_price - min_price;
      
      for(int i=0; i<total; i++)
      {
         // MQL5 Enum Check: Only show Sell/Buy Limit orders
         if((Book[i].type != BOOK_TYPE_SELL) && (Book[i].type != BOOK_TYPE_BUY)) continue;
         
         double price = Book[i].price;
         long vol = Book[i].volume;
         
         if(price > max_price || price < min_price) continue;
         
         // Calculate Position
         int y = (int)((max_price - price) / range * ChartHeight);
         
         // Draw Real Line
         uint argb = ColorToARGB(InpColorHot, 255);
         Canvas.FillRectangle(0, y, ChartWidth, y+2, argb);
         Canvas.TextOut(ChartWidth-100, y-5, IntegerToString(vol), clrWhite);
      }
      // Status Status
      Canvas.TextOut(20, 20, "✅ LIVE BROKER DATA ACTIVE", clrLime);
   }
   else if(InpForceSim)
   {
      // --- SIMULATION MODE (BROKER IS DEAD) ---
      // If we are here, it PROVES the code works but your broker account is bad.
      IsBrokerDataDead = true;
      Canvas.TextOut(20, 20, "⚠️ NO BROKER DATA RECEIVED - DRAWING FAKE TEST LINES ⚠️", clrYellow);
      Canvas.TextOut(20, 40, "SOLUTION: Open 'Raw Spread' Demo on IC Markets Website", clrWhite);
      
      // Draw 5 Fake Lines in the middle of the screen
      for(int i=0; i<5; i++)
      {
         int y = ChartHeight/2 + (i*40) - 100;
         uint argb = ColorToARGB(clrYellow, 200);
         Canvas.FillRectangle(0, y, ChartWidth, y+4, argb);
         Canvas.TextOut(ChartWidth-150, y-5, "FAKE 500", clrYellow);
      }
   }
   
   Canvas.Update();
}

// END FILE: Indicators\Custom\HEATMAP\Heatmap_Nuclear.mq5

// END FILE: Indicators\Custom\HEATMAP\Heatmap_Nuclear.mq5
