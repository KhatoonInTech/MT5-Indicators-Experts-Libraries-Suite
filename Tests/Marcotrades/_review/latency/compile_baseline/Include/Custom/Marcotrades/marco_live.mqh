//+------------------------------------------------------------------+
//|                                                   marco_live.mqh |
//|                 Live Automated Execution & Order Panel Engine    |
//|                 Guardrails Spread & Sizing + M1 Inducement TP    |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "2.00"
#property strict

#ifndef MARCO_LIVE_MQH
#define MARCO_LIVE_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Arrays\ArrayString.mqh>

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\Inducements.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"

#define PANEL_PREFIX "RG_Pnl_"

// =============================================================================
// GUARDRAILS SYSTEM SPREAD RESOLVER
// =============================================================================
long GetGuardrailsSpread(string sym)
  {
   long spread_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   double point    = SymbolInfoDouble(sym, SYMBOL_POINT);
   double ask      = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(sym, SYMBOL_BID);

// Fallback calculation matching Guardrails_Core_Management.mqh & Guardrails_Core_Risk.mqh
   if(spread_pts <= 0)
     {
      if(point > 0.0 && ask > bid)
         spread_pts = (long)MathRound((ask - bid) / point);
      else
         spread_pts = 10;
     }
   return spread_pts;
  }

// =============================================================================
// GUARDRAILS SYSTEM LOT SIZER (max_lot_by_risk)
// =============================================================================
double CalculateGuardrailsMaxLot(string sym, double riskPercent, double riskDistance)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   double max_risk_money = balance * (riskPercent / 100.0);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0)
      tick_size = point;

   double tick_val = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tick_val <= 0)
      tick_val = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(tick_val <= 0)
      tick_val = 1.0;

   double loss_per_lot = (riskDistance / tick_size) * tick_val;
   double max_lot = (loss_per_lot > 0) ? (max_risk_money / loss_per_lot) : 0.01;

// Margin Limit Validation
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double margin_1_lot = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ask, margin_1_lot) && margin_1_lot > 0)
     {
      double max_by_margin = (free_margin * 0.90) / margin_1_lot;
      max_lot = MathMin(max_lot, max_by_margin);
     }

   double lot_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double min_lot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot_broker = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   if(lot_step <= 0)
      lot_step = 0.01;
   if(min_lot <= 0)
      min_lot = 0.01;
   if(max_lot_broker <= 0)
      max_lot_broker = 100.0;

   max_lot = MathFloor(max_lot / lot_step) * lot_step;
   max_lot = MathMax(min_lot, MathMin(max_lot, max_lot_broker));

   int lot_digits = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step)));
   return NormalizeDouble(max_lot, lot_digits);
  }

//+------------------------------------------------------------------+
//| Universal Pip Size Helper                                        |
//+------------------------------------------------------------------+
double GetSymbolPipSize(string sym)
  {
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
   return (digits == 3 || digits == 5) ? pt * 10.0 : pt;
  }

// =============================================================================
// INTERACTIVE GUARDRAILS CUSTOM ORDER PANEL
// =============================================================================
class CMarcoCustomPanel
  {
private:
   int               m_panel_x;
   int               m_panel_y;
   int               m_panel_w;
   int               m_panel_h;
   bool              m_minimized;
   bool              m_is_dragging;
   int               m_drag_dx;
   int               m_drag_dy;
   double            m_lot;
   bool              m_auto_mode;

   void              CreateBox(string name, int x, int y, int w, int h, color bg, color border, int zorder=30)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
     }

   void              CreateBtn(string name, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder=100)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, txtCol);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderCol);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
     }

   void              CreateEdit(string name, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder=100)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, txtCol);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderCol);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_READONLY, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
     }

   void              CreateTxt(string name, int x, int y, string text, color col, int fontSize=8, bool bold=false, int zorder=35)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
      ObjectSetString(0, name, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
     }

   void              CreateTxtCentered(string name, int centerX, int y, string text, color col, int fontSize=8, bool bold=false, int zorder=35)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, centerX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
      ObjectSetString(0, name, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
     }

public:
                     CMarcoCustomPanel()
     {
      m_panel_x     = 30;
      m_panel_y     = 50;
      m_panel_w     = 332;
      m_panel_h     = 248;
      m_minimized   = false;
      m_is_dragging = false;
      m_drag_dx     = 0;
      m_drag_dy     = 0;
      m_lot         = 0.10;
      m_auto_mode   = true;
     }

                    ~CMarcoCustomPanel() { Destroy(); }

   void              Destroy()
     {
      ObjectsDeleteAll(0, PANEL_PREFIX);
     }

   bool              IsAutoTradingEnabled() { return m_auto_mode; }
   double            GetCurrentLot()      { return m_lot; }

   void              SetLot(double lot)
     {
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      if(step > 0)
         lot = MathFloor(lot / step) * step;
      m_lot = MathMax(minL, MathMin(lot, maxL));
      ObjectSetString(0, PANEL_PREFIX + "LotDisplay", OBJPROP_TEXT, StringFormat("%.2f", m_lot));
     }

   void              Render(double riskPercent)
     {
      Destroy();
      ChartSetInteger(0, CHART_FOREGROUND, false);

      color colPanelBG    = C'26,30,40';
      color colPanelBrd   = C'46,52,66';
      color colHeaderBG   = C'34,40,52';
      color colHeaderTxt  = C'215,225,240';
      color colCardBG     = C'245,248,252';
      color colCardBrd    = C'205,212,224';
      color colCardLbl    = C'110,122,140';
      color colCardVal    = C'12,18,28';
      color colPillBG     = C'36,42,54';
      color colPillBrd    = C'50,58,74';
      color colStepperBtn = C'52,60,76';

      int cur_h = m_minimized ? 30 : m_panel_h;

      CreateBox(PANEL_PREFIX + "BG",  m_panel_x, m_panel_y, m_panel_w, cur_h, colPanelBG, colPanelBrd, 30);
      CreateBox(PANEL_PREFIX + "Hdr", m_panel_x, m_panel_y, m_panel_w, 30, colHeaderBG, colPanelBrd, 31);

      string shieldIcon = ShortToString(0xD83D) + ShortToString(0xDEE1);
      CreateTxt(PANEL_PREFIX + "HdrIcon", m_panel_x + 8, m_panel_y + 6, shieldIcon, colHeaderTxt, 11, false, 32);
      ObjectSetString(0, PANEL_PREFIX + "HdrIcon", OBJPROP_FONT, "Segoe UI Emoji");
      CreateTxt(PANEL_PREFIX + "Title",   m_panel_x + 28, m_panel_y + 8, "MARCO SMC LIVE PANEL", colHeaderTxt, 8, true, 32);

      int btnMinX = m_panel_x + m_panel_w - 26;
      int boxSS_X = btnMinX - 6 - 24;
      int boxMM_X = boxSS_X - 3 - 24;
      int boxHH_X = boxMM_X - 3 - 24;
      int boxY    = m_panel_y + 4;

      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      CreateBox(PANEL_PREFIX + "BoxHH", boxHH_X, boxY, 24, 22, C'245,248,252', C'205,212,224', 32);
      CreateTxtCentered(PANEL_PREFIX + "TxtHH", boxHH_X + 12, boxY + 4, StringFormat("%02d", dt.hour), C'15,20,32', 9, true, 33);
      CreateBox(PANEL_PREFIX + "BoxMM", boxMM_X, boxY, 24, 22, C'245,248,252', C'205,212,224', 32);
      CreateTxtCentered(PANEL_PREFIX + "TxtMM", boxMM_X + 12, boxY + 4, StringFormat("%02d", dt.min), C'15,20,32', 9, true, 33);
      CreateBox(PANEL_PREFIX + "BoxSS", boxSS_X, boxY, 24, 22, C'245,248,252', C'205,212,224', 32);
      CreateTxtCentered(PANEL_PREFIX + "TxtSS", boxSS_X + 12, boxY + 4, StringFormat("%02d", dt.sec), C'15,20,32', 9, true, 33);

      CreateBtn(PANEL_PREFIX + "BtnMin", btnMinX, boxY, 22, 22, m_minimized ? "+" : "\x2014", C'48,56,72', colHeaderTxt, C'62,72,92', 100);

      if(m_minimized)
         return;

      int cW  = 98;
      int cH  = 48;
      int c1X = m_panel_x + 12;
      int c2X = m_panel_x + 117;
      int c3X = m_panel_x + 222;
      int r1Y = m_panel_y + 38;
      int r2Y = m_panel_y + 92;

      // Row 1: BALANCE | RISK % | SPREAD
      CreateBox(PANEL_PREFIX + "C1_Box", c1X, r1Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C1_Lbl", c1X + (cW/2), r1Y + 5, "BALANCE", colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C1_Val", c1X + (cW/2), r1Y + 20, "$0.00", colCardVal, 10, true, 33);

      CreateBox(PANEL_PREFIX + "C2_Box", c2X, r1Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C2_Lbl", c2X + (cW/2), r1Y + 5, StringFormat("%g%% RISK", riskPercent), colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C2_Val", c2X + (cW/2), r1Y + 20, "$0.00", colCardVal, 10, true, 33);

      CreateBox(PANEL_PREFIX + "C3_Box", c3X, r1Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C3_Lbl", c3X + (cW/2), r1Y + 5, "SPREAD (GUARD)", colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C3_Val", c3X + (cW/2), r1Y + 20, "0 pts", colCardVal, 10, true, 33);

      // Row 2: MAX SAFE (BUY|SELL) | TRADES % | MIN MARGIN
      CreateBox(PANEL_PREFIX + "C4_Box", c1X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C4_Lbl", c1X + (cW/2), r2Y + 5, "SAFE LOT", colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C4_Val", c1X + (cW/2), r2Y + 20, "0.00", colCardVal, 9, true, 33);

      CreateBox(PANEL_PREFIX + "C5_Box", c2X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C5_Lbl", c2X + (cW/2), r2Y + 5, "RUNWAY", colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C5_Val", c2X + (cW/2), r2Y + 20, "0 trades", colCardVal, 10, true, 33);

      CreateBox(PANEL_PREFIX + "C6_Box", c3X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
      CreateTxtCentered(PANEL_PREFIX + "C6_Lbl", c3X + (cW/2), r2Y + 5, "MARGIN", colCardLbl, 7, true, 33);
      CreateTxtCentered(PANEL_PREFIX + "C6_Val", c3X + (cW/2), r2Y + 20, "$0.00", colCardVal, 10, true, 33);

      // Row 3: Steppers & Auto Toggle
      int lotRowY = m_panel_y + 148;
      int pillW   = 188;
      int autoW = 112;

      CreateBox(PANEL_PREFIX + "Pill_BG", m_panel_x + 12, lotRowY, pillW, 36, colPillBG, colPillBrd, 32);
      CreateBtn(PANEL_PREFIX + "BtnMinus", m_panel_x + 16, lotRowY + 4, 28, 28, "-", colStepperBtn, clrWhite, colPillBrd, 100);
      CreateEdit(PANEL_PREFIX + "LotDisplay", m_panel_x + 50, lotRowY + 4, 110, 28, StringFormat("%.2f", m_lot), colPillBG, clrWhite, colPillBG, 100);
      CreateBtn(PANEL_PREFIX + "BtnPlus",  m_panel_x + 12 + pillW - 32, lotRowY + 4, 28, 28, "+", colStepperBtn, clrWhite, colPillBrd, 100);

      CreateBtn(PANEL_PREFIX + "BtnAutoLot", m_panel_x + 208, lotRowY, autoW, 36, m_auto_mode ? "⚡ AUTO: ON" : "⚡ AUTO: OFF",
                m_auto_mode ? C'24,120,80' : C'42,48,62', m_auto_mode ? clrWhite : C'145,155,172', m_auto_mode ? C'45,190,120' : C'60,70,88', 100);

      // Row 4: Action Execution Buttons
      int btnY = m_panel_y + 192;
      int btnW = 149;
      int btnH = 44;
      CreateBtn(PANEL_PREFIX + "BtnBuy",  m_panel_x + 12,  btnY, btnW, btnH, "\x25B2 BUY (Safe)",  C'32,95,78',  C'210,250,235', C'45,125,105', 100);
      CreateBtn(PANEL_PREFIX + "BtnSell", m_panel_x + 171, btnY, btnW, btnH, "\x25BC SELL (Safe)", C'145,50,60', C'255,215,220', C'180,70,80',  100);

      UpdateHUD(_Symbol, riskPercent);
      ChartRedraw(0);
     }

   void              UpdateHUD(string sym, double riskPercent)
     {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      ObjectSetString(0, PANEL_PREFIX + "TxtHH", OBJPROP_TEXT, StringFormat("%02d", dt.hour));
      ObjectSetString(0, PANEL_PREFIX + "TxtMM", OBJPROP_TEXT, StringFormat("%02d", dt.min));
      ObjectSetString(0, PANEL_PREFIX + "TxtSS", OBJPROP_TEXT, StringFormat("%02d", dt.sec));

      if(m_minimized)
         return;

      double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_money = balance * (riskPercent / 100.0);
      long   spread_pts = GetGuardrailsSpread(sym);

      double pipSize = GetSymbolPipSize(sym);
      double safe_lot = CalculateGuardrailsMaxLot(sym, riskPercent, 20.0 * pipSize);

      ObjectSetString(0, PANEL_PREFIX + "C1_Val", OBJPROP_TEXT, StringFormat("$%.2f", balance));
      ObjectSetString(0, PANEL_PREFIX + "C2_Val", OBJPROP_TEXT, StringFormat("$%.2f", risk_money));
      ObjectSetString(0, PANEL_PREFIX + "C3_Val", OBJPROP_TEXT, StringFormat("%d pts", spread_pts));
      ObjectSetString(0, PANEL_PREFIX + "C4_Val", OBJPROP_TEXT, StringFormat("%.2f L", safe_lot));

      long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(lev <= 0)
         lev = 100;
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double marginReq = 0.0;
      OrderCalcMargin(ORDER_TYPE_BUY, sym, minLot, ask, marginReq);

      int runway = (risk_money > 0) ? (int)(balance / (risk_money)) : 0;
      ObjectSetString(0, PANEL_PREFIX + "C5_Val", OBJPROP_TEXT, StringFormat("%d trades", runway));
      ObjectSetString(0, PANEL_PREFIX + "C6_Val", OBJPROP_TEXT, StringFormat("$%.2f", marginReq));
      ObjectSetString(0, PANEL_PREFIX + "C6_Lbl", OBJPROP_TEXT, StringFormat("MARGIN (1:%d)", lev));
     }

   void              Reposition()
     {
      int cur_h = m_minimized ? 30 : m_panel_h;
      ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_YSIZE, cur_h);

      ObjectSetInteger(0, PANEL_PREFIX + "Hdr", OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, PANEL_PREFIX + "Hdr", OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, PANEL_PREFIX + "HdrIcon", OBJPROP_XDISTANCE, m_panel_x + 8);
      ObjectSetInteger(0, PANEL_PREFIX + "HdrIcon", OBJPROP_YDISTANCE, m_panel_y + 6);
      ObjectSetInteger(0, PANEL_PREFIX + "Title", OBJPROP_XDISTANCE, m_panel_x + 28);
      ObjectSetInteger(0, PANEL_PREFIX + "Title", OBJPROP_YDISTANCE, m_panel_y + 8);

      int btnMinX = m_panel_x + m_panel_w - 26;
      int boxSS_X = btnMinX - 6 - 24;
      int boxMM_X = boxSS_X - 3 - 24;
      int boxHH_X = boxMM_X - 3 - 24;
      int boxY    = m_panel_y + 4;

      ObjectSetInteger(0, PANEL_PREFIX + "BoxHH", OBJPROP_XDISTANCE, boxHH_X);
      ObjectSetInteger(0, PANEL_PREFIX + "BoxHH", OBJPROP_YDISTANCE, boxY);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtHH", OBJPROP_XDISTANCE, boxHH_X + 12);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtHH", OBJPROP_YDISTANCE, boxY + 4);

      ObjectSetInteger(0, PANEL_PREFIX + "BoxMM", OBJPROP_XDISTANCE, boxMM_X);
      ObjectSetInteger(0, PANEL_PREFIX + "BoxMM", OBJPROP_YDISTANCE, boxY);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtMM", OBJPROP_XDISTANCE, boxMM_X + 12);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtMM", OBJPROP_YDISTANCE, boxY + 4);

      ObjectSetInteger(0, PANEL_PREFIX + "BoxSS", OBJPROP_XDISTANCE, boxSS_X);
      ObjectSetInteger(0, PANEL_PREFIX + "BoxSS", OBJPROP_YDISTANCE, boxY);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtSS", OBJPROP_XDISTANCE, boxSS_X + 12);
      ObjectSetInteger(0, PANEL_PREFIX + "TxtSS", OBJPROP_YDISTANCE, boxY + 4);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnMin", OBJPROP_XDISTANCE, btnMinX);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnMin", OBJPROP_YDISTANCE, boxY);

      if(m_minimized)
         return;

      int cW  = 98;
      int c1X = m_panel_x + 12;
      int c2X = m_panel_x + 117;
      int c3X = m_panel_x + 222;
      int r1Y = m_panel_y + 38;
      int r2Y = m_panel_y + 92;

      ObjectSetInteger(0, PANEL_PREFIX + "C1_Box", OBJPROP_XDISTANCE, c1X);
      ObjectSetInteger(0, PANEL_PREFIX + "C1_Box", OBJPROP_YDISTANCE, r1Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C1_Lbl", OBJPROP_XDISTANCE, c1X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C1_Lbl", OBJPROP_YDISTANCE, r1Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C1_Val", OBJPROP_XDISTANCE, c1X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C1_Val", OBJPROP_YDISTANCE, r1Y + 20);

      ObjectSetInteger(0, PANEL_PREFIX + "C2_Box", OBJPROP_XDISTANCE, c2X);
      ObjectSetInteger(0, PANEL_PREFIX + "C2_Box", OBJPROP_YDISTANCE, r1Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C2_Lbl", OBJPROP_XDISTANCE, c2X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C2_Lbl", OBJPROP_YDISTANCE, r1Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C2_Val", OBJPROP_XDISTANCE, c2X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C2_Val", OBJPROP_YDISTANCE, r1Y + 20);

      ObjectSetInteger(0, PANEL_PREFIX + "C3_Box", OBJPROP_XDISTANCE, c3X);
      ObjectSetInteger(0, PANEL_PREFIX + "C3_Box", OBJPROP_YDISTANCE, r1Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C3_Lbl", OBJPROP_XDISTANCE, c3X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C3_Lbl", OBJPROP_YDISTANCE, r1Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C3_Val", OBJPROP_XDISTANCE, c3X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C3_Val", OBJPROP_YDISTANCE, r1Y + 20);

      ObjectSetInteger(0, PANEL_PREFIX + "C4_Box", OBJPROP_XDISTANCE, c1X);
      ObjectSetInteger(0, PANEL_PREFIX + "C4_Box", OBJPROP_YDISTANCE, r2Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C4_Lbl", OBJPROP_XDISTANCE, c1X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C4_Lbl", OBJPROP_YDISTANCE, r2Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C4_Val", OBJPROP_XDISTANCE, c1X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C4_Val", OBJPROP_YDISTANCE, r2Y + 20);

      ObjectSetInteger(0, PANEL_PREFIX + "C5_Box", OBJPROP_XDISTANCE, c2X);
      ObjectSetInteger(0, PANEL_PREFIX + "C5_Box", OBJPROP_YDISTANCE, r2Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C5_Lbl", OBJPROP_XDISTANCE, c2X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C5_Lbl", OBJPROP_YDISTANCE, r2Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C5_Val", OBJPROP_XDISTANCE, c2X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C5_Val", OBJPROP_YDISTANCE, r2Y + 20);

      ObjectSetInteger(0, PANEL_PREFIX + "C6_Box", OBJPROP_XDISTANCE, c3X);
      ObjectSetInteger(0, PANEL_PREFIX + "C6_Box", OBJPROP_YDISTANCE, r2Y);
      ObjectSetInteger(0, PANEL_PREFIX + "C6_Lbl", OBJPROP_XDISTANCE, c3X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C6_Lbl", OBJPROP_YDISTANCE, r2Y + 5);
      ObjectSetInteger(0, PANEL_PREFIX + "C6_Val", OBJPROP_XDISTANCE, c3X + (cW/2));
      ObjectSetInteger(0, PANEL_PREFIX + "C6_Val", OBJPROP_YDISTANCE, r2Y + 20);

      int lotRowY = m_panel_y + 148;
      int pillW   = 188;
      ObjectSetInteger(0, PANEL_PREFIX + "Pill_BG", OBJPROP_XDISTANCE, m_panel_x + 12);
      ObjectSetInteger(0, PANEL_PREFIX + "Pill_BG", OBJPROP_YDISTANCE, lotRowY);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnMinus", OBJPROP_XDISTANCE, m_panel_x + 16);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnMinus", OBJPROP_YDISTANCE, lotRowY + 4);
      ObjectSetInteger(0, PANEL_PREFIX + "LotDisplay", OBJPROP_XDISTANCE, m_panel_x + 50);
      ObjectSetInteger(0, PANEL_PREFIX + "LotDisplay", OBJPROP_YDISTANCE, lotRowY + 4);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnPlus", OBJPROP_XDISTANCE, m_panel_x + 12 + pillW - 32);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnPlus", OBJPROP_YDISTANCE, lotRowY + 4);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnAutoLot", OBJPROP_XDISTANCE, m_panel_x + 208);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnAutoLot", OBJPROP_YDISTANCE, lotRowY);

      int btnY = m_panel_y + 192;
      ObjectSetInteger(0, PANEL_PREFIX + "BtnBuy",  OBJPROP_XDISTANCE, m_panel_x + 12);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnBuy",  OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnSell", OBJPROP_XDISTANCE, m_panel_x + 171);
      ObjectSetInteger(0, PANEL_PREFIX + "BtnSell", OBJPROP_YDISTANCE, btnY);
     }

   void              OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam, CTrade &trade, double riskPercent, ulong magic)
     {
      if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == PANEL_PREFIX + "LotDisplay")
        {
         SetLot(StringToDouble(ObjectGetString(0, sparam, OBJPROP_TEXT)));
         return;
        }

      if(id == CHARTEVENT_OBJECT_CLICK)
        {
         if(sparam == PANEL_PREFIX + "BtnMinus")
           {
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            SetLot(m_lot - (step > 0 ? step : 0.01));
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
           }
         if(sparam == PANEL_PREFIX + "BtnPlus")
           {
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            SetLot(m_lot + (step > 0 ? step : 0.01));
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
           }
         if(sparam == PANEL_PREFIX + "BtnAutoLot")
           {
            m_auto_mode = !m_auto_mode;
            ObjectSetString(0, sparam, OBJPROP_TEXT, m_auto_mode ? "⚡ AUTO: ON" : "⚡ AUTO: OFF");
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, m_auto_mode ? C'24,120,80' : C'42,48,62');
            ObjectSetInteger(0, sparam, OBJPROP_COLOR, m_auto_mode ? clrWhite : C'145,155,172');
            ObjectSetInteger(0, sparam, OBJPROP_BORDER_COLOR, m_auto_mode ? C'45,190,120' : C'60,70,88');
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw(0);
            return;
           }
         if(sparam == PANEL_PREFIX + "BtnMin")
           {
            m_minimized = !m_minimized;
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            Render(riskPercent);
            return;
           }
         if(sparam == PANEL_PREFIX + "BtnBuy")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double pip = GetSymbolPipSize(_Symbol);
            double sl = ask - (30.0 * pip);
            double tp = ask + (60.0 * pip);
            trade.SetExpertMagicNumber(magic);
            trade.Buy(m_lot, _Symbol, ask, sl, tp, "Guardrails Manual Buy");
            return;
           }
         if(sparam == PANEL_PREFIX + "BtnSell")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double pip = GetSymbolPipSize(_Symbol);
            double sl = bid + (30.0 * pip);
            double tp = bid - (60.0 * pip);
            trade.SetExpertMagicNumber(magic);
            trade.Sell(m_lot, _Symbol, bid, sl, tp, "Guardrails Manual Sell");
            return;
           }
        }

      if(id == CHARTEVENT_MOUSE_MOVE)
        {
         int mouseX = (int)lparam;
         int mouseY = (int)dparam;
         uint mouseFlags = (uint)StringToInteger(sparam);
         bool leftBtnDown = ((mouseFlags & 1) != 0);

         if(leftBtnDown)
           {
            if(!m_is_dragging)
              {
               if(mouseX >= m_panel_x && mouseX <= (m_panel_x + m_panel_w) &&
                  mouseY >= m_panel_y && mouseY <= (m_panel_y + 32))
                 {
                  m_is_dragging = true;
                  m_drag_dx = mouseX - m_panel_x;
                  m_drag_dy = mouseY - m_panel_y;
                  ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
                 }
              }
            else
              {
               int newX = MathMax(5, mouseX - m_drag_dx);
               int newY = MathMax(5, mouseY - m_drag_dy);
               if(newX != m_panel_x || newY != m_panel_y)
                 {
                  m_panel_x = newX;
                  m_panel_y = newY;
                  Reposition();
                  ChartRedraw(0);
                 }
              }
           }
         else
           {
            if(m_is_dragging)
              {
               m_is_dragging = false;
               ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
              }
           }
        }
     }
  };

// =============================================================================
// LIVE TRADING INSTANCE (Per Symbol & Timeframe Scenario)
// =============================================================================
class CMarcoLiveInstance
  {
public:
   string                  m_symbol;
   ENUM_TIMEFRAMES         m_tradeTF;
   ENUM_TIMEFRAMES         m_tpTF;
   ulong                   m_magic;
   double                  m_riskPercent;
   double                  m_slBufferPips;

   int                     m_zzDepth;
   double                  m_zzDev;
   int                     m_backtestDays;

   // Trade TF Engines
   ZigZag*                 zzTrade;
   CMarketStructure*       msTrade;
   CDemandSupplyLogic*     dsTrade;
   CSwingPOILogic*         spTrade;
   COrderBlockLogic*       obTrade;
   CFlipZoneLogic*         fzTrade;
   CBreakerBlockLogic*     bbTrade;
   CInducementLogic*       indTrade;
   CLiquidityBlockLogic*   lbTrade;

   // M1 TP Inducement Engine
   ZigZag*                 zzM1;
   CMarketStructure*       msM1;
   CDemandSupplyLogic*     dsM1;
   CSwingPOILogic*         spM1;
   COrderBlockLogic*       obM1;
   CFlipZoneLogic*         fzM1;
   CBreakerBlockLogic*     bbM1;
   CInducementLogic*       indM1;

   CArrayString            m_traded_lb_keys;

                     CMarcoLiveInstance()
     {
      zzTrade = NULL;
      msTrade = NULL;
      dsTrade = NULL;
      spTrade = NULL;
      obTrade = NULL;
      fzTrade = NULL;
      bbTrade = NULL;
      indTrade = NULL;
      lbTrade = NULL;
      zzM1 = NULL;
      msM1 = NULL;
      dsM1 = NULL;
      spM1 = NULL;
      obM1 = NULL;
      fzM1 = NULL;
      bbM1 = NULL;
      indM1 = NULL;
     }

                    ~CMarcoLiveInstance()
     {
      DestroyEngines();
     }

   void              DestroyEngines()
     {
      if(CheckPointer(zzTrade) == POINTER_DYNAMIC)
         delete zzTrade;
      if(CheckPointer(msTrade) == POINTER_DYNAMIC)
         delete msTrade;
      if(CheckPointer(dsTrade) == POINTER_DYNAMIC)
         delete dsTrade;
      if(CheckPointer(spTrade) == POINTER_DYNAMIC)
         delete spTrade;
      if(CheckPointer(obTrade) == POINTER_DYNAMIC)
         delete obTrade;
      if(CheckPointer(fzTrade) == POINTER_DYNAMIC)
         delete fzTrade;
      if(CheckPointer(bbTrade) == POINTER_DYNAMIC)
         delete bbTrade;
      if(CheckPointer(indTrade) == POINTER_DYNAMIC)
         delete indTrade;
      if(CheckPointer(lbTrade) == POINTER_DYNAMIC)
         delete lbTrade;

      if(CheckPointer(zzM1) == POINTER_DYNAMIC)
         delete zzM1;
      if(CheckPointer(msM1) == POINTER_DYNAMIC)
         delete msM1;
      if(CheckPointer(dsM1) == POINTER_DYNAMIC)
         delete dsM1;
      if(CheckPointer(spM1) == POINTER_DYNAMIC)
         delete spM1;
      if(CheckPointer(obM1) == POINTER_DYNAMIC)
         delete obM1;
      if(CheckPointer(fzM1) == POINTER_DYNAMIC)
         delete fzM1;
      if(CheckPointer(bbM1) == POINTER_DYNAMIC)
         delete bbM1;
      if(CheckPointer(indM1) == POINTER_DYNAMIC)
         delete indM1;
     }

   void              Init(string sym, ENUM_TIMEFRAMES tradeTF, ENUM_TIMEFRAMES tpTF, ulong magic,
             double riskPct, double slPips, int zzDep, double zzDev, int btDays,
             bool trackSweepsAnywhere, bool trackPostIndCHoCH,
             int minTouches, double proxPips, bool strictOrigin,
             bool mergeClustered, double clusterTol, bool expandBounds)
     {
      m_symbol       = sym;
      m_tradeTF      = tradeTF;
      m_tpTF         = tpTF;
      m_magic        = magic;
      m_riskPercent  = riskPct;
      m_slBufferPips = slPips;
      m_zzDepth      = zzDep;
      m_zzDev        = zzDev;
      m_backtestDays = btDays;

      DestroyEngines();

      // 1. Initialize Trade TF Engine
      Settings* sTrade = new Settings(m_zzDev, m_zzDepth, clrNONE, true, false, false, false, "Percent");
      sTrade.draw = false;
      zzTrade  = newInstance(sTrade);
      msTrade  = new CMarketStructure();
      msTrade.Init(false, false);
      dsTrade  = new CDemandSupplyLogic();
      spTrade  = new CSwingPOILogic();
      obTrade  = new COrderBlockLogic();
      fzTrade  = new CFlipZoneLogic();
      bbTrade  = new CBreakerBlockLogic();
      indTrade = new CInducementLogic();
      indTrade.Init(minTouches, proxPips, true, true, true, false, false, strictOrigin, mergeClustered, clusterTol, expandBounds);
      lbTrade  = new CLiquidityBlockLogic();
      lbTrade.Init(trackSweepsAnywhere, trackPostIndCHoCH);

      // 2. Initialize M1 TP Inducement Engine
      Settings* sM1 = new Settings(m_zzDev, m_zzDepth, clrNONE, true, false, false, false, "Percent");
      sM1.draw = false;
      zzM1  = newInstance(sM1);
      msM1  = new CMarketStructure();
      msM1.Init(false, false);
      dsM1  = new CDemandSupplyLogic();
      spM1  = new CSwingPOILogic();
      obM1  = new COrderBlockLogic();
      fzM1  = new CFlipZoneLogic();
      bbM1  = new CBreakerBlockLogic();
      indM1 = new CInducementLogic();
      indM1.Init(minTouches, proxPips, true, true, true, false, false, strictOrigin, mergeClustered, clusterTol, expandBounds);
     }

   bool              HasAlreadyTraded(string key)
     {
      for(int i = 0; i < m_traded_lb_keys.Total(); i++)
        {
         if(m_traded_lb_keys.At(i) == key)
            return true;
        }
      return false;
     }

   // Update indicators on TradeTF and M1
   void              UpdateEngines()
     {
      double pipSize = GetSymbolPipSize(m_symbol);
      datetime endTime = TimeCurrent();
      datetime startTime = endTime - (m_backtestDays * 86400);

      // 1. Synchronize Trade TF
      datetime time[];
      double open[], high[], low[], close[];
      long vol[];
      int htf_copy = CopyTime(m_symbol, m_tradeTF, startTime, endTime, time);
      if(htf_copy > m_zzDepth * 2)
        {
         if(CopyOpen(m_symbol, m_tradeTF, startTime, endTime, open) > 0 &&
            CopyHigh(m_symbol, m_tradeTF, startTime, endTime, high) > 0 &&
            CopyLow(m_symbol, m_tradeTF, startTime, endTime, low) > 0 &&
            CopyClose(m_symbol, m_tradeTF, startTime, endTime, close) > 0 &&
            CopyTickVolume(m_symbol, m_tradeTF, startTime, endTime, vol) > 0)
           {
            for(int i = 0; i < htf_copy; i++)
              {
               bool is_last = (i == htf_copy - 1);
               zzTrade.update(high[i], low[i], time[i], vol[i], i, !is_last, is_last);
               msTrade.Update(i, time, high, low, close, zzTrade);
               dsTrade.DetectPOIs(i, time, high, low, zzTrade);
               dsTrade.UpdateMitigation(close[i]);
               spTrade.DetectPOIs(i, time, high, low, zzTrade);
               spTrade.UpdateMitigation(close[i]);
               obTrade.DetectPOIs(i, time, high, low, zzTrade);
               obTrade.UpdateMitigation(close[i]);
               fzTrade.DetectFlipZones(i, time, high, low, close, zzTrade, msTrade, dsTrade);
               fzTrade.UpdateMitigation(close[i]);
               bbTrade.DetectBreakers(zzTrade, dsTrade, spTrade, obTrade, fzTrade);
               bbTrade.UpdateMitigation(high[i], low[i], time[i]);
               indTrade.Process(i, time, open, high, low, close, zzTrade, msTrade, dsTrade, spTrade, obTrade, fzTrade, bbTrade, pipSize);
               lbTrade.Process(i, time, high, low, msTrade, spTrade, indTrade, zzTrade);
              }
           }
        }

      // 2. Synchronize M1 TP Engine
      int m1_copy = CopyTime(m_symbol, m_tpTF, startTime, endTime, time);
      if(m1_copy > m_zzDepth * 2)
        {
         if(CopyOpen(m_symbol, m_tpTF, startTime, endTime, open) > 0 &&
            CopyHigh(m_symbol, m_tpTF, startTime, endTime, high) > 0 &&
            CopyLow(m_symbol, m_tpTF, startTime, endTime, low) > 0 &&
            CopyClose(m_symbol, m_tpTF, startTime, endTime, close) > 0 &&
            CopyTickVolume(m_symbol, m_tpTF, startTime, endTime, vol) > 0)
           {
            for(int i = 0; i < m1_copy; i++)
              {
               bool is_last = (i == m1_copy - 1);
               zzM1.update(high[i], low[i], time[i], vol[i], i, !is_last, is_last);
               msM1.Update(i, time, high, low, close, zzM1);
               dsM1.DetectPOIs(i, time, high, low, zzM1);
               dsM1.UpdateMitigation(close[i]);
               spM1.DetectPOIs(i, time, high, low, zzM1);
               spM1.UpdateMitigation(close[i]);
               obM1.DetectPOIs(i, time, high, low, zzM1);
               obM1.UpdateMitigation(close[i]);
               fzM1.DetectFlipZones(i, time, high, low, close, zzM1, msM1, dsM1);
               fzM1.UpdateMitigation(close[i]);
               bbM1.DetectBreakers(zzM1, dsM1, spM1, obM1, fzM1);
               bbM1.UpdateMitigation(high[i], low[i], time[i]);
               indM1.Process(i, time, open, high, low, close, zzM1, msM1, dsM1, spM1, obM1, fzM1, bbM1, pipSize);
              }
           }
        }
     }

   // Scans live tick against LBs and sends order on first touch
   void              CheckAndExecute(CTrade &trade, int maxSpreadPoints, int maxOpenPositionsPerSymbol)
     {
      double bid   = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits   = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      if(bid <= 0 || ask <= 0 || point <= 0)
         return;

      // Exact Guardrails Spread Resolution
      long spread_pts = GetGuardrailsSpread(m_symbol);
      if(maxSpreadPoints > 0 && spread_pts > maxSpreadPoints)
         return;

      // Count active positions for this symbol and magic number
      int openPosCount = 0;
      for(int p = PositionsTotal() - 1; p >= 0; p--)
        {
         ulong ticket = PositionGetTicket(p);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
            openPosCount++;
        }
      if(openPosCount >= maxOpenPositionsPerSymbol)
         return;

      double pipSize = GetSymbolPipSize(m_symbol);

      // Check all active Liquidity Blocks from Trade TF
      for(int k = 0; k < lbTrade.m_liquidity_blocks.Total(); k++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbTrade.m_liquidity_blocks.At(k);
         if(lb == NULL || lb.isMitigated)
            continue;

         string lbKey = m_symbol + "_" + EnumToString(m_tradeTF) + "_" + lb.id;
         if(HasAlreadyTraded(lbKey))
            continue;

         bool triggerLong  = false;
         bool triggerShort = false;

         // Long trigger: First touch of BL-LB-BSL or BL-LB-IND
         if(lb.isBullish && (lb.triggerType == LB_TRIGGER_BL_BSL || lb.triggerType == LB_TRIGGER_BL_IND))
           {
            if(ask <= lb.zoneHigh && ask >= (lb.zoneLow - 2.0 * pipSize))
               triggerLong = true;
           }

         // Short trigger: First touch of BR-LB-IND or BR-LB-SSL
         if(!lb.isBullish && (lb.triggerType == LB_TRIGGER_BR_IND || lb.triggerType == LB_TRIGGER_BR_SSL))
           {
            if(bid >= lb.zoneLow && bid <= (lb.zoneHigh + 2.0 * pipSize))
               triggerShort = true;
           }

         // --- EXECUTE LONG ---
         if(triggerLong)
           {
            double entryPrice = ask;
            double sl = NormalizeDouble(lb.zoneLow - (m_slBufferPips * pipSize), digits);
            double riskDist = entryPrice - sl;
            if(riskDist <= 0)
               continue;

            // Opposing 1m-BR-IND zone.high as TP
            double tp = 0.0;
            double bestDist = DBL_MAX;

            for(int z = 0; z < indM1.m_zones.Total(); z++)
              {
               CInducementZone* ind = (CInducementZone*)indM1.m_zones.At(z);
               if(ind != NULL && ind.isInducement && !ind.isMitigated && !ind.isBullish)
                 {
                  if(ind.zoneHigh > entryPrice && (ind.zoneHigh - entryPrice) < bestDist)
                    {
                     bestDist = ind.zoneHigh - entryPrice;
                     tp = ind.zoneHigh;
                    }
                 }
              }

            // Fallback TP to 2.0R if no opposing M1 Inducement active
            if(tp == 0.0)
               tp = entryPrice + (2.0 * riskDist);

            tp = NormalizeDouble(tp, digits);
            double lots = CalculateGuardrailsMaxLot(m_symbol, m_riskPercent, riskDist);

            string comment = StringFormat("MIE_%s_%s", StringSubstr(EnumToString(m_tradeTF), 7), lb.GetNomenclature(msTrade.tf_str()));
            trade.SetExpertMagicNumber(m_magic);

            if(trade.Buy(lots, m_symbol, entryPrice, sl, tp, comment))
              {
               PrintFormat("🚀 [LIVE BUY EXECUTED] %s %s | Lots: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f | Setup: %s | Spread: %d pts",
                           m_symbol, EnumToString(m_tradeTF), lots, entryPrice, sl, tp, lb.GetNomenclature(msTrade.tf_str()), spread_pts);
               m_traded_lb_keys.Add(lbKey);
               lb.touchCount++;
               break;
              }
           }

         // --- EXECUTE SHORT ---
         if(triggerShort)
           {
            double entryPrice = bid;
            double sl = NormalizeDouble(lb.zoneHigh + (m_slBufferPips * pipSize), digits);
            double riskDist = sl - entryPrice;
            if(riskDist <= 0)
               continue;

            // Opposing 1m-BL-IND zone.low as TP
            double tp = 0.0;
            double bestDist = DBL_MAX;

            for(int z = 0; z < indM1.m_zones.Total(); z++)
              {
               CInducementZone* ind = (CInducementZone*)indM1.m_zones.At(z);
               if(ind != NULL && ind.isInducement && !ind.isMitigated && ind.isBullish)
                 {
                  if(ind.zoneLow < entryPrice && (entryPrice - ind.zoneLow) < bestDist)
                    {
                     bestDist = entryPrice - ind.zoneLow;
                     tp = ind.zoneLow;
                    }
                 }
              }

            // Fallback TP to 2.0R if no opposing M1 Inducement active
            if(tp == 0.0)
               tp = entryPrice - (2.0 * riskDist);

            tp = NormalizeDouble(tp, digits);
            double lots = CalculateGuardrailsMaxLot(m_symbol, m_riskPercent, riskDist);

            string comment = StringFormat("MIE_%s_%s", StringSubstr(EnumToString(m_tradeTF), 7), lb.GetNomenclature(msTrade.tf_str()));
            trade.SetExpertMagicNumber(m_magic);

            if(trade.Sell(lots, m_symbol, entryPrice, sl, tp, comment))
              {
               PrintFormat("🚀 [LIVE SELL EXECUTED] %s %s | Lots: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f | Setup: %s | Spread: %d pts",
                           m_symbol, EnumToString(m_tradeTF), lots, entryPrice, sl, tp, lb.GetNomenclature(msTrade.tf_str()), spread_pts);
               m_traded_lb_keys.Add(lbKey);
               lb.touchCount++;
               break;
              }
           }
        }
     }
  };

// =============================================================================
// MASTER MULTI-SYMBOL LIVE SCANNER ENGINE
// =============================================================================
class CMarcoLiveEngine
  {
private:
   CMarcoLiveInstance* instances[];
   int                 total_instances;
   CTrade              m_trade;

public:
                     CMarcoLiveEngine() { total_instances = 0; }
                    ~CMarcoLiveEngine()
     {
      for(int i = 0; i < total_instances; i++)
        {
         if(CheckPointer(instances[i]) == POINTER_DYNAMIC)
            delete instances[i];
        }
     }

   void              Initialize(string &symbols[], ENUM_TIMEFRAMES &tfs[], ENUM_TIMEFRAMES tpTF, ulong magic,
                   double riskPct, double slPips, int zzDep, double zzDev, int btDays,
                   bool trackSweepsAnywhere, bool trackPostIndCHoCH,
                   int minTouches, double proxPips, bool strictOrigin,
                   bool mergeClustered, double clusterTol, bool expandBounds)
     {
      int symCount = ArraySize(symbols);
      int tfCount  = ArraySize(tfs);

      total_instances = symCount * tfCount;
      ArrayResize(instances, total_instances);

      int idx = 0;
      for(int s = 0; s < symCount; s++)
        {
         SymbolSelect(symbols[s], true);
         for(int t = 0; t < tfCount; t++)
           {
            instances[idx] = new CMarcoLiveInstance();
            instances[idx].Init(symbols[s], tfs[t], tpTF, magic, riskPct, slPips, zzDep, zzDev, btDays,
                                trackSweepsAnywhere, trackPostIndCHoCH,
                                minTouches, proxPips, strictOrigin, mergeClustered, clusterTol, expandBounds);
            idx++;
           }
        }

      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(_Symbol);

      PrintFormat("✅ Marcotrades Live Engine started. Monitoring %d Symbol-Timeframe scenarios.", total_instances);
     }

   void              OnTick(int maxSpreadPoints, int maxOpenPositionsPerSymbol)
     {
      for(int i = 0; i < total_instances; i++)
        {
         instances[i].UpdateEngines();
         instances[i].CheckAndExecute(m_trade, maxSpreadPoints, maxOpenPositionsPerSymbol);
        }
     }
  };

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\marco_live.mqh

// END FILE: Include\Custom\Marcotrades\marco_live.mqh
