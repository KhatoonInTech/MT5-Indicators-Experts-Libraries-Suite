//+------------------------------------------------------------------+
//|                                           xauusd_heatmap.mqh     |
//|                        Copyright 2026, Industrial MQL5 Architect |
//|                                          DIAGNOSTIC MODE         |
//+------------------------------------------------------------------+
#property copyright "AI Collaborator"
#property strict

#include <Canvas\Canvas.mqh>

struct LiquidityLevel { double price; long volume; long prev_volume; };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CHeatmapEngine
  {
private:
   CCanvas           m_canvas;
   MqlBookInfo       m_book[];
   int               m_width;
   int               m_height;
   string            m_symbol;
   ulong             m_last_update;
   color             m_color_hot;
   color             m_color_cold;
   int               m_whale_threshold;

public:
                     CHeatmapEngine() : m_last_update(0) {}
                    ~CHeatmapEngine() { Deinit(); }

   bool              Initialize(string symbol, color cHot, color cCold, int whaleThresh, int speed, bool spoof)
     {
      m_symbol = symbol;
      m_color_hot = cHot;
      m_color_cold = cCold;
      m_whale_threshold = whaleThresh;

      if(!MarketBookAdd(m_symbol))
        {
         Print("DEBUG: MarketBookAdd Failed!");
         return(false);
        }

      m_width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      m_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      if(!m_canvas.CreateBitmapLabel("HeatmapCanvas", 0, 0, m_width, m_height, COLOR_FORMAT_ARGB_NORMALIZE))
        {
         Print("DEBUG: Canvas Create Failed!");
         return(false);
        }

      Print("DEBUG: Engine Initialized. Waiting for data...");
      return(true);
     }

   void              Deinit() { MarketBookRelease(m_symbol); m_canvas.Destroy(); }

   void              OnChartResize()
     {
      m_width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      m_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      m_canvas.Resize(m_width, m_height);
     }

   void              OnBookEvent()
     {
      if(!MarketBookGet(m_symbol, m_book))
         return;
      DrawHeatmap();
     }

   void              DrawHeatmap()
     {
      m_canvas.Erase(0x00000000);

      // 1. DIAGNOSTIC RED BOX (Top Left)
      // If you see this Red Square, the graphics are working perfectly.
      m_canvas.FillRectangle(20, 20, 60, 60, ColorToARGB(clrRed, 255));
      m_canvas.TextOut(70, 30, "GRAPHICS OK", clrRed);

      int total = ArraySize(m_book);

      // 2. DIAGNOSTIC PRINT TO LOGS
      // Check the "Experts" tab to see this message
      static ulong last_print = 0;
      if(GetTickCount() - last_print > 2000) // Print every 2 seconds
        {
         Print("DEBUG: Book Size = ", total, " | Symbol = ", m_symbol);
         if(total > 0)
            Print("DEBUG: Top Order Price = ", m_book[0].price, " Vol = ", m_book[0].volume);
         last_print = GetTickCount();
        }

      if(total == 0)
        {
         m_canvas.TextOut(70, 50, "WAITING FOR BROKER DATA...", clrWhite);
         m_canvas.Update();
         return;
        }

      double max_price = ChartGetDouble(0, CHART_PRICE_MAX);
      double min_price = ChartGetDouble(0, CHART_PRICE_MIN);
      double range = max_price - min_price;

      for(int i=0; i<total; i++)
        {
         // FILTER: Standard MQL5 Types
         if(m_book[i].type != BOOK_TYPE_SELL && m_book[i].type != BOOK_TYPE_BUY)
            continue;

         double price = m_book[i].price;
         long   vol   = m_book[i].volume;

         if(price > max_price || price < min_price)
            continue;

         int y = (int)((max_price - price) / range * m_height);

         // FORCE VISIBILITY: Ignore threshold, max opacity
         uint argb = ColorToARGB(m_color_hot, 255);

         m_canvas.FillRectangle(0, y, m_width, y+1, argb);
         m_canvas.TextOut(m_width - 80, y-5, IntegerToString(vol), clrWhite);
        }
      m_canvas.Update();
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\xauusd_heatmap.mqh

// END FILE: Include\Custom\General\xauusd_heatmap.mqh
