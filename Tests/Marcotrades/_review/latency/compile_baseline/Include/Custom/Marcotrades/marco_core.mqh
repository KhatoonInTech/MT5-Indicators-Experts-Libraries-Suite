//+------------------------------------------------------------------+
//|                               Include\Custom\Marcotrades\marco_core.mqh |
//|           Marco (Inter Equity) ZigZag-Driven Liquidity Engine    |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect / Inter Equity System"
#property version   "4.10"

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mql_plotting.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core.mqh"

enum ENUM_MARCO_STATE
  {
   MDV_STATE_IDLE,
   MDV_STATE_EL_FORMED,
   MDV_STATE_SWEEP_CONFIRMED,
   MDV_STATE_MSS_COMPLETE
  };

struct SMarcoSignal
  {
   int               direction;          // 1 = BUY, -1 = SELL
   ENUM_MARCO_STATE  state;
   double            el_price;
   datetime          el_time;
   double            sweep_price;
   datetime          sweep_time;
   double            lb_high;
   double            lb_low;
   double            lb_mid;
   double            entry_price;
   double            sl_price;
   double            tp1_internal;
   double            tp2_major;
  };

//+------------------------------------------------------------------+
//| CMarcoCoreLogic Engine Class                                     |
//+------------------------------------------------------------------+
class CMarcoCoreLogic
  {
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_period;
   ENUM_ASSET_TYPE      m_assetCategory;
   SZigZagParams        m_zzParams;

   bool                 m_drawZigZag;
   bool                 m_drawMarketStructure;
   bool                 m_showEngineeredLQ;
   bool                 m_showTraps;
   bool                 m_showLiquidityBlocks;
   bool                 m_showTargetEye;

   double               m_activeDev;
   int                  m_activeDep;
   int                  m_activeLookback;

   color                m_col_trap_bg;
   color                m_col_trap_border;
   color                m_col_lb_bull_bg;
   color                m_col_lb_bear_bg;
   color                m_col_lb_border;
   color                m_col_el_line;

   ZigZag*              m_zigZag;
   CMarketStructure*    m_ms;

   int                  m_last_pivot_count;
   datetime             m_last_processed_bar;

   SMarcoSignal         m_active_buy;
   SMarcoSignal         m_active_sell;

   ENUM_ASSET_TYPE   DetectAssetType(string sym)
     {
      string upper = sym;
      StringToUpper(upper);
      if(StringFind(upper, "XAU") >= 0 || StringFind(upper, "GOLD") >= 0 ||
         StringFind(upper, "XAG") >= 0 || StringFind(upper, "SILVER") >= 0)
         return ASSET_TYPE_METALS;

      if(StringFind(upper, "BTC") >= 0 || StringFind(upper, "ETH") >= 0 ||
         StringFind(upper, "CRYPTO") >= 0)
         return ASSET_TYPE_CRYPTO;

      return ASSET_TYPE_FOREX;
     }

   void              ResolveZigZagParams(double &outDev, int &outDep, int &outLookback)
     {
      ENUM_ASSET_TYPE asset = (m_assetCategory == ASSET_TYPE_AUTO) ? DetectAssetType(m_symbol) : m_assetCategory;

      if(asset == ASSET_TYPE_METALS)
        {
         outLookback = m_zzParams.met_maxLookback;
         switch(m_period)
           {
            case PERIOD_D1:
               outDev = m_zzParams.met_dev_D1;
               outDep = m_zzParams.met_dep_D1;
               break;
            case PERIOD_H4:
               outDev = m_zzParams.met_dev_H4;
               outDep = m_zzParams.met_dep_H4;
               break;
            case PERIOD_H1:
               outDev = m_zzParams.met_dev_H1;
               outDep = m_zzParams.met_dep_H1;
               break;
            case PERIOD_M15:
               outDev = m_zzParams.met_dev_M15;
               outDep = m_zzParams.met_dep_M15;
               break;
            default:
               outDev = m_zzParams.met_dev_M1;
               outDep = m_zzParams.met_dep_M1;
               break;
           }
        }
      else
         if(asset == ASSET_TYPE_CRYPTO)
           {
            outLookback = m_zzParams.cry_maxLookback;
            switch(m_period)
              {
               case PERIOD_D1:
                  outDev = m_zzParams.cry_dev_D1;
                  outDep = m_zzParams.cry_dep_D1;
                  break;
               case PERIOD_H4:
                  outDev = m_zzParams.cry_dev_H4;
                  outDep = m_zzParams.cry_dep_H4;
                  break;
               case PERIOD_H1:
                  outDev = m_zzParams.cry_dev_H1;
                  outDep = m_zzParams.cry_dep_H1;
                  break;
               case PERIOD_M15:
                  outDev = m_zzParams.cry_dev_M15;
                  outDep = m_zzParams.cry_dep_M15;
                  break;
               default:
                  outDev = m_zzParams.cry_dev_M1;
                  outDep = m_zzParams.cry_dep_M1;
                  break;
              }
           }
         else
           {
            outLookback = m_zzParams.fx_maxLookback;
            switch(m_period)
              {
               case PERIOD_D1:
                  outDev = m_zzParams.fx_dev_D1;
                  outDep = m_zzParams.fx_dep_D1;
                  break;
               case PERIOD_H4:
                  outDev = m_zzParams.fx_dev_H4;
                  outDep = m_zzParams.fx_dep_H4;
                  break;
               case PERIOD_H1:
                  outDev = m_zzParams.fx_dev_H1;
                  outDep = m_zzParams.fx_dep_H1;
                  break;
               case PERIOD_M15:
                  outDev = m_zzParams.fx_dev_M15;
                  outDep = m_zzParams.fx_dep_M15;
                  break;
               default:
                  outDev = m_zzParams.fx_dev_M1;
                  outDep = m_zzParams.fx_dep_M1;
                  break;
              }
           }
     }

   double            GetPipSize()
     {
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      return (digits == 3 || digits == 5) ? pt * 10.0 : pt;
     }

   void              ResetSignals()
     {
      m_active_buy.direction   = 0;
      m_active_buy.state       = MDV_STATE_IDLE;
      m_active_sell.direction  = 0;
      m_active_sell.state      = MDV_STATE_IDLE;
     }

   void              DrawPersistentBox(string name, datetime t1, double pTop, datetime t2, double pBot, color bgClr, color borderClr)
     {
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, pTop, t2, pBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, borderClr);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
      else
        {
         ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, name, OBJPROP_PRICE, 0, pTop);
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, name, OBJPROP_PRICE, 1, pBot);
        }
     }

   void              DrawPersistentLabel(string name, datetime t, double p, string text, color clr, ENUM_ANCHOR_POINT anchor, int fontSize)
     {
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
         ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
        }
      ObjectSetInteger(0, name, OBJPROP_TIME, t);
      ObjectSetDouble(0, name, OBJPROP_PRICE, p);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
     }

public:
                     CMarcoCoreLogic()
     {
      m_zigZag             = NULL;
      m_ms                 = NULL;
      m_last_pivot_count   = 0;
      m_last_processed_bar = 0;
      ResetSignals();
     }

                    ~CMarcoCoreLogic()
     {
      Cleanup();
     }

   void              Cleanup()
     {
      if(CheckPointer(m_zigZag) == POINTER_DYNAMIC)
         delete m_zigZag;
      if(CheckPointer(m_ms) == POINTER_DYNAMIC)
         delete m_ms;
      ObjectsDeleteAll(0, "MIE_");
     }

   void              Init(string sym, ENUM_TIMEFRAMES tf, ENUM_ASSET_TYPE assetCat, const SZigZagParams &params,
             bool drawZZ = true, color zzColor = clrGold, bool extendZZ = true,
             bool drawMS = true, bool showEL = true, bool showTraps = true,
             bool showLBs = true, bool showTarget = true)
     {
      m_symbol              = sym;
      m_period              = tf;
      m_assetCategory       = assetCat;
      m_zzParams            = params;
      m_drawZigZag          = drawZZ;
      m_drawMarketStructure = drawMS;
      m_showEngineeredLQ    = showEL;
      m_showTraps           = showTraps;
      m_showLiquidityBlocks = showLBs;
      m_showTargetEye       = showTarget;

      // Authentic colors matching Marco's PDF
      m_col_trap_bg     = ColorToARGB_Custom(C'255,192,203', 55); // Soft Translucent Pink
      m_col_trap_border = ColorToARGB_Custom(C'220,90,110', 120);
      m_col_lb_bull_bg  = ColorToARGB_Custom(C'176,196,222', 75); // Translucent Blue
      m_col_lb_bear_bg  = ColorToARGB_Custom(C'160,170,185', 75); // Translucent Slate
      m_col_lb_border   = ColorToARGB_Custom(C'70,130,180', 160);
      m_col_el_line     = clrOrange;

      ResolveZigZagParams(m_activeDev, m_activeDep, m_activeLookback);

      if(CheckPointer(m_zigZag) == POINTER_DYNAMIC)
         delete m_zigZag;
      Settings* s = new Settings(m_activeDev, m_activeDep, zzColor, extendZZ, false, false, false, "Percent");
      s.draw = m_drawZigZag;
      m_zigZag = newInstance(s);

      if(CheckPointer(m_ms) == POINTER_DYNAMIC)
         delete m_ms;
      m_ms = new CMarketStructure();
      m_ms.Init(m_drawMarketStructure, m_drawMarketStructure);

      m_last_pivot_count = 0;
      ResetSignals();
     }

   //+---------------------------------------------------------------+
   //| Core Pivot-Driven Processing: Zero Flickering, Persistent GUI |
   //+---------------------------------------------------------------+
   void              UpdatePivots(int rates_total, const datetime &time[], const double &open[],
                     const double &high[], const double &low[], const double &close[],
                     const long &volume[], bool &buySignal, bool &sellSignal,
                     SMarcoSignal &outBuy, SMarcoSignal &outSell)
     {
      buySignal  = false;
      sellSignal = false;
      if(rates_total < m_activeDep * 2)
         return;

      int start_bar = MathMax(0, rates_total - m_activeLookback);

      // 1. Process ZigZag and Market Structure incrementally
      for(int i = start_bar; i < rates_total; i++)
        {
         bool is_last = (i == rates_total - 1);
         m_zigZag.update(high[i], low[i], time[i], volume[i], i, !is_last, is_last);
         m_ms.Update(i, time, high, low, close, m_zigZag);
        }

      int p_count = m_zigZag.pivots.Total();
      datetime live_extend = time[rates_total - 1] + (PeriodSeconds(m_period) * 15);
      double pipSize = GetPipSize();

      // Smoothly adjust active Liquidity Block right boundary on live ticks without flicker
      if(ObjectFind(0, "MIE_Active_LB") >= 0)
        {
         ObjectSetInteger(0, "MIE_Active_LB", OBJPROP_TIME, 1, live_extend);
        }

      // Check structural levels only when a ZigZag pivot confirms
      if(p_count == m_last_pivot_count && p_count > 0)
         return;
      m_last_pivot_count = p_count;

      if(p_count < 4)
         return;

      // -------------------------------------------------------------
      // 2. ENGINEERED LIQUIDITY (EQH / EQL)
      // -------------------------------------------------------------
      if(m_showEngineeredLQ)
        {
         bool el_found = false;
         for(int j = p_count - 2; j >= MathMax(0, p_count - 6); j--)
           {
            Pivot* p1 = (Pivot*)m_zigZag.pivots.At(j);
            if(p1 == NULL || (m_zigZag.projection != NULL && p1 == m_zigZag.projection))
               continue;

            for(int k = j - 1; k >= MathMax(0, j - 4); k--)
              {
               Pivot* p2 = (Pivot*)m_zigZag.pivots.At(k);
               if(p2 == NULL || (m_zigZag.projection != NULL && p2 == m_zigZag.projection))
                  continue;

               if(p1.isHigh == p2.isHigh)
                 {
                  double diffPips = MathAbs(p1.end.price - p2.end.price) / pipSize;
                  if(diffPips <= 2.5) // 2.5 pips tolerance for equal highs/lows
                    {
                     double elPrice = p1.isHigh ? MathMax(p1.end.price, p2.end.price) : MathMin(p1.end.price, p2.end.price);
                     string tag     = p1.isHigh ? "EQH" : "EQL";

                     Plotter::DrawLine("MIE_EL_Line", p2.end.time, elPrice, live_extend, elPrice, m_col_el_line, STYLE_DASH, 1, false);

                     datetime midT = p2.end.time + (datetime)((time[rates_total - 1] - p2.end.time) / 2);
                     DrawPersistentLabel("MIE_EL_Lbl", midT, elPrice, "Engineered LQ (" + tag + ") 💵", m_col_el_line,
                                         p1.isHigh ? ANCHOR_LOWER : ANCHOR_UPPER, 9);
                     el_found = true;
                     break;
                    }
                 }
              }
            if(el_found)
               break;
           }
        }

      // -------------------------------------------------------------
      // 3. DETECT MARCO'S INDUCEMENT, SWEEPS, TRAPS & LIQUIDITY BLOCKS
      // -------------------------------------------------------------
      Pivot* p_latest = (Pivot*)m_zigZag.pivots.At(p_count - 2);
      Pivot* p_inter  = (Pivot*)m_zigZag.pivots.At(p_count - 3);
      Pivot* p_prev   = (Pivot*)m_zigZag.pivots.At(p_count - 4);

      if(p_latest == NULL || p_inter == NULL || p_prev == NULL)
         return;

      // --- BEARISH MODEL: Price sweeps prior High Pivot ---
      if(p_latest.isHigh && p_prev.isHigh && (p_latest.end.price > p_prev.end.price))
        {
         // 1. Sweep Confirmation Checkmark (✓)
         DrawPersistentLabel("MIE_Sweep_Marker", p_latest.end.time, p_latest.end.price, "✓", clrLimeGreen, ANCHOR_LOWER, 12);

         // 2. Inducement Tag
         DrawPersistentLabel("MIE_Inducement_Lbl", p_latest.end.time, p_latest.end.price + (3 * pipSize),
                             "Buyers Induced", clrDarkRed, ANCHOR_LOWER, 8);

         // 3. Single Active Bearish Liquidity Block (LB) Box
         if(m_showLiquidityBlocks)
           {
            double lbTop = p_latest.end.price;
            double lbBot = p_latest.end.price - (4 * pipSize);
            DrawPersistentBox("MIE_Active_LB", p_latest.end.time, lbTop, live_extend, lbBot, m_col_lb_bear_bg, m_col_lb_border);
            DrawPersistentLabel("MIE_Active_LB_Lbl", p_latest.end.time, lbBot, "Liquidity Block (LB)", clrNavy, ANCHOR_UPPER, 8);
           }

         // 4. Compact Pink Trap Box at intermediate low
         if(m_showTraps && !p_inter.isHigh)
           {
            double trapTop = p_inter.end.price + (3 * pipSize);
            double trapBot = p_inter.end.price;
            DrawPersistentBox("MIE_Active_Trap", p_inter.end.time, trapTop, p_latest.end.time, trapBot, m_col_trap_bg, m_col_trap_border);
            datetime midTrap = p_inter.end.time + (datetime)((p_latest.end.time - p_inter.end.time) / 2);
            DrawPersistentLabel("MIE_Active_Trap_Lbl", midTrap, (trapTop + trapBot) / 2.0, "❌ Buyers Trapped", C'200,40,40', ANCHOR_CENTER, 8);
           }

         // Signal Package
         m_active_sell.direction   = -1;
         m_active_sell.state       = MDV_STATE_SWEEP_CONFIRMED;
         m_active_sell.sweep_price = p_latest.end.price;
         m_active_sell.sweep_time  = p_latest.end.time;
         m_active_sell.lb_high     = p_latest.end.price;
         m_active_sell.lb_low      = p_latest.end.price - (4 * pipSize);
         m_active_sell.entry_price = p_latest.end.price - (2 * pipSize);
         m_active_sell.sl_price    = p_latest.end.price + (2 * pipSize);
         m_active_sell.tp1_internal= p_inter.end.price;
         m_active_sell.tp2_major   = p_inter.end.price - (MathAbs(m_active_sell.sl_price - m_active_sell.entry_price) * 3.0);

         sellSignal = true;
         outSell    = m_active_sell;
        }

      // --- BULLISH MODEL: Price sweeps prior Low Pivot ---
      if(!p_latest.isHigh && !p_prev.isHigh && (p_latest.end.price < p_prev.end.price))
        {
         // 1. Sweep Confirmation Checkmark (✓)
         DrawPersistentLabel("MIE_Sweep_Marker", p_latest.end.time, p_latest.end.price, "✓", clrLimeGreen, ANCHOR_UPPER, 12);

         // 2. Inducement Tag
         DrawPersistentLabel("MIE_Inducement_Lbl", p_latest.end.time, p_latest.end.price - (3 * pipSize),
                             "Sellers Induced", clrSeaGreen, ANCHOR_UPPER, 8);

         // 3. Single Active Bullish Liquidity Block (LB) Box
         if(m_showLiquidityBlocks)
           {
            double lbBot = p_latest.end.price;
            double lbTop = lbBot + (4 * pipSize);
            DrawPersistentBox("MIE_Active_LB", p_latest.end.time, lbTop, live_extend, lbBot, m_col_lb_bull_bg, m_col_lb_border);
            DrawPersistentLabel("MIE_Active_LB_Lbl", p_latest.end.time, lbTop, "Liquidity Block (LB)", clrNavy, ANCHOR_LOWER, 8);
           }

         // 4. Compact Pink Trap Box at intermediate high
         if(m_showTraps && p_inter.isHigh)
           {
            double trapTop = p_inter.end.price;
            double trapBot = p_inter.end.price - (3 * pipSize);
            DrawPersistentBox("MIE_Active_Trap", p_inter.end.time, trapTop, p_latest.end.time, trapBot, m_col_trap_bg, m_col_trap_border);
            datetime midTrap = p_inter.end.time + (datetime)((p_latest.end.time - p_inter.end.time) / 2);
            DrawPersistentLabel("MIE_Active_Trap_Lbl", midTrap, (trapTop + trapBot) / 2.0, "❌ Sellers Trapped", C'200,40,40', ANCHOR_CENTER, 8);
           }

         // Signal Package
         m_active_buy.direction   = 1;
         m_active_buy.state       = MDV_STATE_SWEEP_CONFIRMED;
         m_active_buy.sweep_price = p_latest.end.price;
         m_active_buy.sweep_time  = p_latest.end.time;
         m_active_buy.lb_low      = p_latest.end.price;
         m_active_buy.lb_high     = p_latest.end.price + (4 * pipSize);
         m_active_buy.entry_price = p_latest.end.price + (2 * pipSize);
         m_active_buy.sl_price    = p_latest.end.price - (2 * pipSize);
         m_active_buy.tp1_internal= p_inter.end.price;
         m_active_buy.tp2_major   = p_inter.end.price + (MathAbs(m_active_buy.entry_price - m_active_buy.sl_price) * 3.0);

         buySignal = true;
         outBuy    = m_active_buy;
        }

      // -------------------------------------------------------------
      // 4. TARGET LIQUIDITY POOL ("Keep An Eye Here!! 👁️")
      // -------------------------------------------------------------
      if(m_showTargetEye)
        {
         Pivot* majorHigh = NULL;
         Pivot* majorLow  = NULL;
         for(int p = p_count - 1; p >= 0; p--)
           {
            Pivot* cur = (Pivot*)m_zigZag.pivots.At(p);
            if(cur == NULL || (m_zigZag.projection != NULL && cur == m_zigZag.projection))
               continue;
            if(cur.isHigh && majorHigh == NULL)
               majorHigh = cur;
            if(!cur.isHigh && majorLow == NULL)
               majorLow  = cur;
            if(majorHigh != NULL && majorLow != NULL)
               break;
           }

         if(majorHigh != NULL)
           {
            Plotter::DrawLine("MIE_Target_High", majorHigh.end.time, majorHigh.end.price, live_extend, majorHigh.end.price, clrBlack, STYLE_DOT, 1, false);
            DrawPersistentLabel("MIE_Target_High_lbl", live_extend, majorHigh.end.price, "Keep An Eye Here!! 👁️", clrBlack, ANCHOR_LEFT_LOWER, 9);
           }
         if(majorLow != NULL)
           {
            Plotter::DrawLine("MIE_Target_Low", majorLow.end.time, majorLow.end.price, live_extend, majorLow.end.price, clrBlack, STYLE_DOT, 1, false);
            DrawPersistentLabel("MIE_Target_Low_lbl", live_extend, majorLow.end.price, "Keep An Eye Here!! 👁️", clrBlack, ANCHOR_LEFT_UPPER, 9);
           }
        }
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\marco_core.mqh

// END FILE: Include\Custom\Marcotrades\marco_core.mqh
