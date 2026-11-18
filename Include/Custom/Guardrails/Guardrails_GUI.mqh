//+------------------------------------------------------------------+
//|                               Include\ZigZag\Guardrails_GUI.mqh  |
//|             Role: Handles visual elements, dark theme HUD,       |
//|             toggleable Auto 1% state, and post-trade lot sync.   |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "39.00"
#property description "Guardrails Engine - Toggleable Auto Mode & Dynamic Lot HUD"

#include <Custom\Guardrails\Guardrails_Core.mqh>

#define MODAL_PREFIX "RG_Modal_"
#define PANEL_PREFIX "RG_Pnl_"
#define NUM_COLS 8

//+------------------------------------------------------------------+
//| GUI Engine Class                                                 |
//+------------------------------------------------------------------+
class CGuardrailsGUI : public CGuardrailsCore
  {
protected:
   OrderLog          m_history[];
   OrderLog          m_current;
   bool              m_modal_visible;
   int               m_active_tab;

   int               m_modal_x;
   int               m_modal_y;
   int               m_modal_w;
   bool              m_is_dragging;
   int               m_drag_dx;
   int               m_drag_dy;

   int               m_panel_x;
   int               m_panel_y;
   int               m_panel_w;
   int               m_panel_h;
   bool              m_panel_minimized;
   bool              m_panel_is_dragging;
   int               m_panel_drag_dx;
   int               m_panel_drag_dy;

   int               m_colW[NUM_COLS];
   string            m_colTitles[NUM_COLS];

   bool              IsTicketAlreadyHandled(ulong ticket);
   int               GetCompactModalHeight();
   void              ShowModal();
   void              HideModal();
   void              DestroyModal();
   void              CreateBox(string fullObjName, int x, int y, int w, int h, color bg, color border, int zorder=30);
   void              CreateBtn(string fullObjName, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder=100);
   void              CreateEdit(string fullObjName, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder=100);
   void              CreateTxt(string fullObjName, int x, int y, string text, color col, int fontSize=8, bool bold=false, int zorder=35);
   void              CreateTxtCentered(string fullObjName, int centerX, int y, string text, color col, int fontSize=8, bool bold=false, int zorder=35);
   void              RenderModal();
   void              RepositionModal();

   int               CalculateTradesUntilInsufficientBalance(string sym, double &outMinMargin, long &outLeverage);

   void              RenderPanel();
   void              DestroyPanel();
   void              RepositionPanel();
   void              UpdatePanelHUD();
   void              UpdateAutoLotButtonState();
   void              SetPanelLot(double lot);

   virtual void      TriggerGuardrailViolation(ulong ticket, string sym, double volume, double max_allowed, double loss, string violation, string status);
   virtual void      OnPreTradeExecuted(double executedLot);

public:
                     CGuardrailsGUI();
   virtual          ~CGuardrailsGUI();

   void              ProcessChartEvents(const int id, const long &lparam, const double &dparam, const string &sparam);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGuardrailsGUI::CGuardrailsGUI()
  {
   m_modal_visible        = false;
   m_active_tab           = 0;
   m_modal_x              = 150;
   m_modal_y              = 80;
   m_modal_w              = 700;

   m_is_dragging          = false;
   m_drag_dx              = 0;
   m_drag_dy              = 0;

   m_panel_x              = 30;
   m_panel_y              = 50;
   m_panel_w              = 332;
   m_panel_h              = 248;
   m_panel_minimized      = false;
   m_panel_is_dragging    = false;
   m_panel_drag_dx        = 0;
   m_panel_drag_dy        = 0;

   int widths[NUM_COLS] = {65, 90, 85, 75, 75, 75, 125, 80};
   string titles[NUM_COLS] = {"Time", "Ticket", "Asset", "Attempted", "Max Safe", "Loss ($)", "Violation", "Status"};

   for(int i = 0; i < NUM_COLS; i++)
     {
      m_colW[i]      = widths[i];
      m_colTitles[i] = titles[i];
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGuardrailsGUI::~CGuardrailsGUI()
  {
  }

//+------------------------------------------------------------------+
//| Post-Trade Lot Update Hook                                       |
//+------------------------------------------------------------------+
void CGuardrailsGUI::OnPreTradeExecuted(double executedLot)
  {
   SetPanelLot(executedLot);
  }

//+------------------------------------------------------------------+
//| Toggle Button Visual State Renderer                              |
//+------------------------------------------------------------------+
void CGuardrailsGUI::UpdateAutoLotButtonState()
  {
   string btnName = PANEL_PREFIX + "BtnAutoLot";
   if(ObjectFind(0, btnName) < 0)
      return;

   if(m_auto_lot_enabled)
     {
      ObjectSetString(0, btnName, OBJPROP_TEXT, "⚡ AUTO: ON");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'24,120,80');       // Active Emerald Green
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, C'45,190,120');
     }
   else
     {
      ObjectSetString(0, btnName, OBJPROP_TEXT, "⚡ AUTO: OFF");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'42,48,62');        // Inactive Muted Slate
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, C'145,155,172');
      ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, C'60,70,88');
     }
  }

//+------------------------------------------------------------------+
//| Calculate Consecutive Risk SL Trades Until Insufficient Balance  |
//+------------------------------------------------------------------+
int CGuardrailsGUI::CalculateTradesUntilInsufficientBalance(string sym, double &outMinMargin, long &outLeverage)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   outLeverage    = AccountInfoInteger(ACCOUNT_LEVERAGE);
   if(outLeverage <= 0)
      outLeverage = 100;

   if(balance <= 0.0)
     {
      outMinMargin = 0.0;
      return 0;
     }

   double min_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(min_lot <= 0.0)
      min_lot = 0.01;

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(ask <= 0.0)
      ask = SymbolInfoDouble(sym, SYMBOL_BID);

   outMinMargin = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, min_lot, ask, outMinMargin) || outMinMargin <= 0.0)
     {
      double contract_size = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contract_size <= 0.0)
         contract_size = 100000.0;
      outMinMargin = (min_lot * contract_size * ask) / (double)outLeverage;
     }

   if(outMinMargin <= 0.0)
      outMinMargin = 1.0;

   if(balance < outMinMargin)
      return 0;

   double risk_fraction = m_maxRiskPercent / 100.0;
   if(risk_fraction <= 0.0 || risk_fraction >= 1.0)
      return 0;

   int count = 0;
   double temp_balance = balance;

   while(temp_balance >= outMinMargin && count < 100000)
     {
      count++;
      temp_balance -= (temp_balance * risk_fraction);
     }

   return count;
  }

//+------------------------------------------------------------------+
//| Ticket Duplication Check                                         |
//+------------------------------------------------------------------+
bool CGuardrailsGUI::IsTicketAlreadyHandled(ulong ticket)
  {
   if(ticket == 0)
      return false;
   int total = ArraySize(m_history);
   for(int i = 0; i < total; i++)
     {
      if(m_history[i].ticket == ticket)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Guardrail Violation Trigger Hook                                 |
//+------------------------------------------------------------------+
void CGuardrailsGUI::TriggerGuardrailViolation(ulong ticket, string sym, double volume, double max_allowed, double loss, string violation, string status)
  {
   static ulong    last_ticket    = 0;
   static string   last_violation = "";
   static datetime last_time      = 0;

   datetime now = TimeLocal();
   if(ticket != 0 && ticket == last_ticket && violation == last_violation && (now - last_time) < 2)
      return;

   last_ticket    = ticket;
   last_violation = violation;
   last_time      = now;

   int sz = ArraySize(m_history);
   ArrayResize(m_history, sz + 1);
   m_history[sz].time        = TimeCurrent();
   m_history[sz].ticket      = ticket;
   m_history[sz].symbol      = sym;
   m_history[sz].volume      = volume;
   m_history[sz].max_allowed = max_allowed;
   m_history[sz].loss        = loss;
   m_history[sz].violation   = violation;
   m_history[sz].status      = status;

   m_current = m_history[sz];

   ShowModal();
   PlaySound("alert.wav");
  }

//+------------------------------------------------------------------+
//| Render Violation Modal Dialog                                    |
//+------------------------------------------------------------------+
void CGuardrailsGUI::RenderModal()
  {
   if(!m_modal_visible)
      return;
   DestroyModal();

   color col_card_bg    = C'255,255,255';
   color col_border     = C'210,215,225';
   color col_cell_border= C'220,225,235';
   color col_header_bg  = C'210,220,235';
   color col_title      = C'25,35,50';
   color col_tbl_hdr_bg = C'210,220,235';
   color col_tbl_hdr_tc = C'30,45,65';
   color col_row_alt    = C'247,249,252';
   color col_row_white  = C'255,255,255';
   color col_text_dark  = C'40,50,65';

   int compact_h = GetCompactModalHeight();

   CreateBox(MODAL_PREFIX + "MainBG",   m_modal_x, m_modal_y, m_modal_w, compact_h, col_card_bg, col_border, 150);
   CreateBox(MODAL_PREFIX + "HeaderBG", m_modal_x, m_modal_y, m_modal_w, 36, col_header_bg, col_border, 151);

   string shieldIcon = ShortToString(0xD83D) + ShortToString(0xDEE1);
   CreateTxt(MODAL_PREFIX + "Icon", m_modal_x + 14, m_modal_y + 8, shieldIcon, col_title, 11, false, 152);
   ObjectSetString(0, MODAL_PREFIX + "Icon", OBJPROP_FONT, "Segoe UI Emoji");

   CreateTxt(MODAL_PREFIX + "Title", m_modal_x + 36, m_modal_y + 9, "RISK GUARDRAILS NOTIFICATIONS", col_title, 10, true, 152);
   CreateBtn(MODAL_PREFIX + "BtnClose", m_modal_x + m_modal_w - 36, m_modal_y + 5, 28, 25, "\x2715", C'254,226,226', C'185,28,28', C'252,165,165', 200);

   color tab1_bg = (m_active_tab == 0) ? C'37,99,235' : C'241,245,249';
   color tab1_tc = (m_active_tab == 0) ? clrWhite : C'71,85,105';
   color tab2_bg = (m_active_tab == 1) ? C'37,99,235' : C'241,245,249';
   color tab2_tc = (m_active_tab == 1) ? clrWhite : C'71,85,105';

   CreateBtn(MODAL_PREFIX + "TabCurrent", m_modal_x + 15, m_modal_y + 44, 140, 26, "Current Order", tab1_bg, tab1_tc, col_border, 200);
   CreateBtn(MODAL_PREFIX + "TabHistory", m_modal_x + 165, m_modal_y + 44, 140, 26, StringFormat("History (%d)", ArraySize(m_history)), tab2_bg, tab2_tc, col_border, 200);

   int tableTopY = m_modal_y + 78;
   int tableX    = m_modal_x + 15;

   int colX[NUM_COLS];
   colX[0] = tableX;
   for(int c = 1; c < NUM_COLS; c++)
      colX[c] = colX[c - 1] + m_colW[c - 1];

   for(int c = 0; c < NUM_COLS; c++)
     {
      CreateBox(MODAL_PREFIX + StringFormat("HCell_%d", c), colX[c], tableTopY, m_colW[c], 24, col_tbl_hdr_bg, col_cell_border, 152);
      CreateTxt(MODAL_PREFIX + StringFormat("HTxt_%d", c),  colX[c] + 6, tableTopY + 5, m_colTitles[c], col_tbl_hdr_tc, 8, true, 153);
     }

   int rowCount = (m_active_tab == 0) ? 1 : MathMin(5, ArraySize(m_history));
   int startRowY = tableTopY + 24;

   for(int r = 0; r < rowCount; r++)
     {
      OrderLog log = (m_active_tab == 0) ? m_current : m_history[ArraySize(m_history) - 1 - r];
      int curRowY  = startRowY + (r * 26);
      color rowBg  = (r % 2 == 0) ? col_row_white : col_row_alt;

      string ticketStr  = (log.ticket > 0) ? StringFormat("#%d", log.ticket) : "PRE-TRADE";
      string assetStr   = (log.symbol != "") ? log.symbol : _Symbol;
      string maxSafeStr = (log.max_allowed > 0.0) ? StringFormat("%.2f L", log.max_allowed) : "-";
      string lossStr    = (log.loss != 0.0) ? StringFormat("%s$%.2f", (log.loss < 0 ? "-" : "+"), MathAbs(log.loss)) : "$0.00";
      color  lossCol    = (log.loss < 0) ? C'190,25,25' : (log.loss > 0 ? C'22,101,52' : col_text_dark);

      string rowData[NUM_COLS] =
        {
         TimeToString(log.time, TIME_MINUTES|TIME_SECONDS),
         ticketStr,
         assetStr,
         StringFormat("%.2f L", log.volume),
         maxSafeStr,
         lossStr,
         log.violation,
         log.status
        };

      color colColors[NUM_COLS] = {col_text_dark, col_text_dark, C'30,45,65', C'190,25,25', C'22,101,52', lossCol, C'190,25,25', (log.status == "Blocked" ? C'210,105,30' : C'220,38,38')};

      for(int c = 0; c < NUM_COLS; c++)
        {
         CreateBox(MODAL_PREFIX + StringFormat("RCell_%d_%d", r, c), colX[c], curRowY, m_colW[c], 26, rowBg, col_cell_border, 152);
         CreateTxt(MODAL_PREFIX + StringFormat("RTxt_%d_%d", r, c),  colX[c] + 6, curRowY + 6, rowData[c], colColors[c], 8, (c >= 3), 153);
        }
     }

   if(m_active_tab == 1 && ArraySize(m_history) == 0)
     {
      CreateBox(MODAL_PREFIX + "EmptyCell", tableX, startRowY, 670, 30, col_row_white, col_cell_border, 152);
      CreateTxt(MODAL_PREFIX + "EmptyTxt",  tableX + 15, startRowY + 8, "No historical violations recorded yet in this session.", C'120,130,140', 8, false, 153);
     }
  }

//+------------------------------------------------------------------+
//| Reposition Violation Modal                                       |
//+------------------------------------------------------------------+
void CGuardrailsGUI::RepositionModal()
  {
   int compact_h = GetCompactModalHeight();

   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_XDISTANCE, m_modal_x);
   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_YDISTANCE, m_modal_y);
   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_YSIZE, compact_h);

   ObjectSetInteger(0, MODAL_PREFIX + "HeaderBG", OBJPROP_XDISTANCE, m_modal_x);
   ObjectSetInteger(0, MODAL_PREFIX + "HeaderBG", OBJPROP_YDISTANCE, m_modal_y);

   ObjectSetInteger(0, MODAL_PREFIX + "Icon", OBJPROP_XDISTANCE, m_modal_x + 14);
   ObjectSetInteger(0, MODAL_PREFIX + "Icon", OBJPROP_YDISTANCE, m_modal_y + 8);

   ObjectSetInteger(0, MODAL_PREFIX + "Title", OBJPROP_XDISTANCE, m_modal_x + 36);
   ObjectSetInteger(0, MODAL_PREFIX + "Title", OBJPROP_YDISTANCE, m_modal_y + 9);

   ObjectSetInteger(0, MODAL_PREFIX + "BtnClose", OBJPROP_XDISTANCE, m_modal_x + m_modal_w - 36);
   ObjectSetInteger(0, MODAL_PREFIX + "BtnClose", OBJPROP_YDISTANCE, m_modal_y + 5);

   ObjectSetInteger(0, MODAL_PREFIX + "TabCurrent", OBJPROP_XDISTANCE, m_modal_x + 15);
   ObjectSetInteger(0, MODAL_PREFIX + "TabCurrent", OBJPROP_YDISTANCE, m_modal_y + 44);

   ObjectSetInteger(0, MODAL_PREFIX + "TabHistory", OBJPROP_XDISTANCE, m_modal_x + 165);
   ObjectSetInteger(0, MODAL_PREFIX + "TabHistory", OBJPROP_YDISTANCE, m_modal_y + 44);

   int tableTopY = m_modal_y + 78;
   int tableX    = m_modal_x + 15;

   int colX[NUM_COLS];
   colX[0] = tableX;
   for(int c = 1; c < NUM_COLS; c++)
      colX[c] = colX[c - 1] + m_colW[c - 1];

   for(int c = 0; c < NUM_COLS; c++)
     {
      ObjectSetInteger(0, MODAL_PREFIX + StringFormat("HCell_%d", c), OBJPROP_XDISTANCE, colX[c]);
      ObjectSetInteger(0, MODAL_PREFIX + StringFormat("HCell_%d", c), OBJPROP_YDISTANCE, tableTopY);

      ObjectSetInteger(0, MODAL_PREFIX + StringFormat("HTxt_%d", c),  OBJPROP_XDISTANCE, colX[c] + 6);
      ObjectSetInteger(0, MODAL_PREFIX + StringFormat("HTxt_%d", c),  OBJPROP_YDISTANCE, tableTopY + 5);
     }

   int rowCount = (m_active_tab == 0) ? 1 : MathMin(5, ArraySize(m_history));
   int startRowY = tableTopY + 24;

   for(int r = 0; r < rowCount; r++)
     {
      int curRowY = startRowY + (r * 26);
      for(int c = 0; c < NUM_COLS; c++)
        {
         ObjectSetInteger(0, MODAL_PREFIX + StringFormat("RCell_%d_%d", r, c), OBJPROP_XDISTANCE, colX[c]);
         ObjectSetInteger(0, MODAL_PREFIX + StringFormat("RCell_%d_%d", r, c), OBJPROP_YDISTANCE, curRowY);

         ObjectSetInteger(0, MODAL_PREFIX + StringFormat("RTxt_%d_%d", r, c),  OBJPROP_XDISTANCE, colX[c] + 6);
         ObjectSetInteger(0, MODAL_PREFIX + StringFormat("RTxt_%d_%d", r, c),  OBJPROP_YDISTANCE, curRowY + 6);
        }
     }

   if(m_active_tab == 1 && ArraySize(m_history) == 0)
     {
      ObjectSetInteger(0, MODAL_PREFIX + "EmptyCell", OBJPROP_XDISTANCE, tableX);
      ObjectSetInteger(0, MODAL_PREFIX + "EmptyCell", OBJPROP_YDISTANCE, startRowY);

      ObjectSetInteger(0, MODAL_PREFIX + "EmptyTxt",  OBJPROP_XDISTANCE, tableX + 15);
      ObjectSetInteger(0, MODAL_PREFIX + "EmptyTxt",  OBJPROP_YDISTANCE, startRowY + 8);
     }
  }

//+------------------------------------------------------------------+
//| Render Pre-Trade Order Panel                                     |
//+------------------------------------------------------------------+
void CGuardrailsGUI::RenderPanel()
  {
   if(!m_showOrderPanel)
      return;
   DestroyPanel();

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

   color colTimeBoxBG  = C'245,248,252';
   color colTimeBoxBrd = C'205,212,224';
   color colTimeDigits = C'15,20,32';

   int current_h = m_panel_minimized ? 30 : m_panel_h;

   CreateBox(PANEL_PREFIX + "BG",  m_panel_x, m_panel_y, m_panel_w, current_h, colPanelBG, colPanelBrd, 30);
   CreateBox(PANEL_PREFIX + "Hdr", m_panel_x, m_panel_y, m_panel_w, 30, colHeaderBG, colPanelBrd, 31);

   string shieldIcon = ShortToString(0xD83D) + ShortToString(0xDEE1);
   CreateTxt(PANEL_PREFIX + "HdrIcon", m_panel_x + 8, m_panel_y + 6, shieldIcon, colHeaderTxt, 11, false, 32);
   ObjectSetString(0, PANEL_PREFIX + "HdrIcon", OBJPROP_FONT, "Segoe UI Emoji");

   CreateTxt(PANEL_PREFIX + "Title",   m_panel_x + 28, m_panel_y + 8, "GUARDRAIL ORDER PANEL", colHeaderTxt, 8, true, 32);

   int btnMinX = m_panel_x + m_panel_w - 26;
   int boxSS_X = btnMinX - 6 - 24;
   int boxMM_X = boxSS_X - 3 - 24;
   int boxHH_X = boxMM_X - 3 - 24;
   int boxY    = m_panel_y + 4;

   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   CreateBox(PANEL_PREFIX + "BoxHH", boxHH_X, boxY, 24, 22, colTimeBoxBG, colTimeBoxBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "TxtHH", boxHH_X + 12, boxY + 4, StringFormat("%02d", dt.hour), colTimeDigits, 9, true, 33);

   CreateBox(PANEL_PREFIX + "BoxMM", boxMM_X, boxY, 24, 22, colTimeBoxBG, colTimeBoxBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "TxtMM", boxMM_X + 12, boxY + 4, StringFormat("%02d", dt.min), colTimeDigits, 9, true, 33);

   CreateBox(PANEL_PREFIX + "BoxSS", boxSS_X, boxY, 24, 22, colTimeBoxBG, colTimeBoxBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "TxtSS", boxSS_X + 12, boxY + 4, StringFormat("%02d", dt.sec), colTimeDigits, 9, true, 33);

   string minIcon = m_panel_minimized ? "+" : "\x2014";
   CreateBtn(PANEL_PREFIX + "BtnMin", btnMinX, boxY, 22, 22, minIcon, C'48,56,72', colHeaderTxt, C'62,72,92', 100);

   if(m_panel_minimized)
     {
      ChartRedraw(0);
      return;
     }

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
   CreateTxtCentered(PANEL_PREFIX + "C2_Lbl", c2X + (cW/2), r1Y + 5, StringFormat("%g%% RISK", m_maxRiskPercent), colCardLbl, 7, true, 33);
   CreateTxtCentered(PANEL_PREFIX + "C2_Val", c2X + (cW/2), r1Y + 20, "$0.00", colCardVal, 10, true, 33);

   CreateBox(PANEL_PREFIX + "C3_Box", c3X, r1Y, cW, cH, colCardBG, colCardBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "C3_Lbl", c3X + (cW/2), r1Y + 5, "SPREAD", colCardLbl, 7, true, 33);
   CreateTxtCentered(PANEL_PREFIX + "C3_Val", c3X + (cW/2), r1Y + 20, "0 pts", colCardVal, 10, true, 33);

// Row 2: Directional MAX SAFE (BUY | SELL) | TRADES % | MIN MARGIN
   CreateBox(PANEL_PREFIX + "C4_Box", c1X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "C4_Lbl", c1X + (cW/2), r2Y + 5, "MAX (BUY | SELL)", colCardLbl, 7, true, 33);
   CreateTxtCentered(PANEL_PREFIX + "C4_Val", c1X + (cW/2), r2Y + 20, "0.00 | 0.00", colCardVal, 9, true, 33);

   CreateBox(PANEL_PREFIX + "C5_Box", c2X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "C5_Lbl", c2X + (cW/2), r2Y + 5, StringFormat("%g%% TRADES", m_maxRiskPercent), colCardLbl, 7, true, 33);
   CreateTxtCentered(PANEL_PREFIX + "C5_Val", c2X + (cW/2), r2Y + 20, "0 trades", colCardVal, 10, true, 33);

   CreateBox(PANEL_PREFIX + "C6_Box", c3X, r2Y, cW, cH, colCardBG, colCardBrd, 32);
   CreateTxtCentered(PANEL_PREFIX + "C6_Lbl", c3X + (cW/2), r2Y + 5, "MIN MARGIN", colCardLbl, 7, true, 33);
   CreateTxtCentered(PANEL_PREFIX + "C6_Val", c3X + (cW/2), r2Y + 20, "$0.00", colCardVal, 10, true, 33);

// Controls Row
   int lotRowY = m_panel_y + 148;
   int pillW   = 188;
   int autoW   = 112;

   CreateBox(PANEL_PREFIX + "Pill_BG", m_panel_x + 12, lotRowY, pillW, 36, colPillBG, colPillBrd, 32);

   CreateBtn(PANEL_PREFIX + "BtnMinus", m_panel_x + 16, lotRowY + 4, 28, 28, "-", colStepperBtn, clrWhite, colPillBrd, 100);
   CreateEdit(PANEL_PREFIX + "LotDisplay", m_panel_x + 50, lotRowY + 4, 110, 28, StringFormat("%.2f", m_panel_lot), colPillBG, clrWhite, colPillBG, 100);
   CreateBtn(PANEL_PREFIX + "BtnPlus",  m_panel_x + 12 + pillW - 32, lotRowY + 4, 28, 28, "+", colStepperBtn, clrWhite, colPillBrd, 100);

// Toggleable Auto Lot Button
   CreateBtn(PANEL_PREFIX + "BtnAutoLot", m_panel_x + 208, lotRowY, autoW, 36, "⚡ AUTO: OFF", C'42,48,62', C'145,155,172', C'60,70,88', 100);
   UpdateAutoLotButtonState();

   int btnY = m_panel_y + 192;
   int btnW = 149;
   int btnH = 44;

   CreateBtn(PANEL_PREFIX + "BtnBuy",  m_panel_x + 12,  btnY, btnW, btnH, "\x25B2 BUY (Safe)",  C'32,95,78',  C'210,250,235', C'45,125,105', 100);
   CreateBtn(PANEL_PREFIX + "BtnSell", m_panel_x + 171, btnY, btnW, btnH, "\x25BC SELL (Safe)", C'145,50,60', C'255,215,220', C'180,70,80',  100);

   UpdatePanelHUD();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Destroy Pre-Trade Order Panel                                    |
//+------------------------------------------------------------------+
void CGuardrailsGUI::DestroyPanel()
  {
   ObjectsDeleteAll(0, PANEL_PREFIX);
  }

//+------------------------------------------------------------------+
//| Update Panel HUD Values                                          |
//+------------------------------------------------------------------+
void CGuardrailsGUI::UpdatePanelHUD()
  {
   if(!m_showOrderPanel)
      return;

   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   ObjectSetString(0, PANEL_PREFIX + "TxtHH", OBJPROP_TEXT, StringFormat("%02d", dt.hour));
   ObjectSetString(0, PANEL_PREFIX + "TxtMM", OBJPROP_TEXT, StringFormat("%02d", dt.min));
   ObjectSetString(0, PANEL_PREFIX + "TxtSS", OBJPROP_TEXT, StringFormat("%02d", dt.sec));

   if(m_panel_minimized)
      return;

   double balance      = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money   = balance * (m_maxRiskPercent / 100.0);

// Dual directional max safe lot calculation
   double max_safe_buy  = CalculateMaxAllowedLot(_Symbol, 1);
   double max_safe_sell = CalculateMaxAllowedLot(_Symbol, -1);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int spread_pts = (point > 0) ? (int)MathRound((ask - bid) / point) : 0;

   double min_margin = 0.0;
   long leverage = 0;
   int trades_runway = CalculateTradesUntilInsufficientBalance(_Symbol, min_margin, leverage);

   ObjectSetString(0, PANEL_PREFIX + "C1_Val", OBJPROP_TEXT, StringFormat("$%.2f", balance));

   ObjectSetString(0, PANEL_PREFIX + "C2_Lbl", OBJPROP_TEXT, StringFormat("%g%% RISK", m_maxRiskPercent));
   ObjectSetString(0, PANEL_PREFIX + "C2_Val", OBJPROP_TEXT, StringFormat("$%.2f", risk_money));

   ObjectSetString(0, PANEL_PREFIX + "C3_Val", OBJPROP_TEXT, StringFormat("%d pts", spread_pts));

// Shows BUY and SELL max safe lots side by side
   ObjectSetString(0, PANEL_PREFIX + "C4_Val", OBJPROP_TEXT, StringFormat("%.2f | %.2f", max_safe_buy, max_safe_sell));

   ObjectSetString(0, PANEL_PREFIX + "C5_Lbl", OBJPROP_TEXT, StringFormat("%g%% TRADES", m_maxRiskPercent));
   ObjectSetString(0, PANEL_PREFIX + "C5_Val", OBJPROP_TEXT, StringFormat("%d trades", trades_runway));
   ObjectSetInteger(0, PANEL_PREFIX + "C5_Val", OBJPROP_COLOR, (trades_runway > 0) ? C'22,101,52' : C'190,25,25');

   ObjectSetString(0, PANEL_PREFIX + "C6_Lbl", OBJPROP_TEXT, StringFormat("MARGIN (1:%d)", leverage));
   ObjectSetString(0, PANEL_PREFIX + "C6_Val", OBJPROP_TEXT, StringFormat("$%.2f", min_margin));
  }

//+------------------------------------------------------------------+
//| Reposition Order Panel on Drag                                   |
//+------------------------------------------------------------------+
void CGuardrailsGUI::RepositionPanel()
  {
   int current_h = m_panel_minimized ? 30 : m_panel_h;

   ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_XDISTANCE, m_panel_x);
   ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_YDISTANCE, m_panel_y);
   ObjectSetInteger(0, PANEL_PREFIX + "BG", OBJPROP_YSIZE, current_h);

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

   if(m_panel_minimized)
      return;

   int cW  = 98;
   int c1X = m_panel_x + 12;
   int c2X = m_panel_x + 117;
   int c3X = m_panel_x + 222;

   int r1Y = m_panel_y + 38;
   int r2Y = m_panel_y + 92;

// Row 1: C1, C2, C3
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

// Row 2: C4, C5, C6
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

//+------------------------------------------------------------------+
//| Set Lot Size via Stepper or Manual Input                         |
//+------------------------------------------------------------------+
void CGuardrailsGUI::SetPanelLot(double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(step > 0)
      lot = MathFloor(lot / step) * step;

   m_panel_lot = MathMax(minL, MathMin(lot, maxL));

   string lotObj = PANEL_PREFIX + "LotDisplay";
   ObjectSetString(0, lotObj, OBJPROP_TEXT, StringFormat("%.2f", m_panel_lot));

   UpdatePanelHUD();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Calculate Dynamic Modal Height                                   |
//+------------------------------------------------------------------+
int CGuardrailsGUI::GetCompactModalHeight()
  {
   int rowCount = (m_active_tab == 0) ? 1 : MathMax(1, MathMin(5, ArraySize(m_history)));
   return (78 + 24 + (rowCount * 26) + 14);
  }

//+------------------------------------------------------------------+
//| Show Violation Modal                                             |
//+------------------------------------------------------------------+
void CGuardrailsGUI::ShowModal()
  {
   m_active_tab = 0;
   m_modal_visible = true;

   long chart_w = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chart_h = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int  modal_h = GetCompactModalHeight();

   m_modal_x = (int)((chart_w / 2) - (m_modal_w / 2));
   m_modal_y = (int)((chart_h / 2) - (modal_h / 2));

   if(m_modal_x < 5)
      m_modal_x = 5;
   if(m_modal_y < 5)
      m_modal_y = 5;

   RenderModal();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Hide Violation Modal                                             |
//+------------------------------------------------------------------+
void CGuardrailsGUI::HideModal()
  {
   m_modal_visible = false;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
   DestroyModal();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Destroy Violation Modal                                          |
//+------------------------------------------------------------------+
void CGuardrailsGUI::DestroyModal()
  {
   ObjectsDeleteAll(0, MODAL_PREFIX);
  }

//+------------------------------------------------------------------+
//| Helper: Create Rectangle Label                                   |
//+------------------------------------------------------------------+
void CGuardrailsGUI::CreateBox(string fullObjName, int x, int y, int w, int h, color bg, color border, int zorder)
  {
   if(ObjectFind(0, fullObjName) < 0)
      ObjectCreate(0, fullObjName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fullObjName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullObjName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullObjName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, fullObjName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, fullObjName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, fullObjName, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, fullObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_ZORDER, zorder);
  }

//+------------------------------------------------------------------+
//| Helper: Create Button                                            |
//+------------------------------------------------------------------+
void CGuardrailsGUI::CreateBtn(string fullObjName, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder)
  {
   if(ObjectFind(0, fullObjName) < 0)
      ObjectCreate(0, fullObjName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, fullObjName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullObjName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullObjName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, fullObjName, OBJPROP_YSIZE, h);
   ObjectSetString(0, fullObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullObjName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, fullObjName, OBJPROP_COLOR, txtCol);
   ObjectSetInteger(0, fullObjName, OBJPROP_BORDER_COLOR, borderCol);
   ObjectSetInteger(0, fullObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_STATE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, fullObjName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_ZORDER, zorder);
  }

//+------------------------------------------------------------------+
//| Helper: Create Editable Input Box                                |
//+------------------------------------------------------------------+
void CGuardrailsGUI::CreateEdit(string fullObjName, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol, int zorder)
  {
   if(ObjectFind(0, fullObjName) < 0)
      ObjectCreate(0, fullObjName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, fullObjName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullObjName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullObjName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, fullObjName, OBJPROP_YSIZE, h);
   ObjectSetString(0, fullObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullObjName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, fullObjName, OBJPROP_COLOR, txtCol);
   ObjectSetInteger(0, fullObjName, OBJPROP_BORDER_COLOR, borderCol);
   ObjectSetInteger(0, fullObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, fullObjName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, fullObjName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_READONLY, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_ZORDER, zorder);
  }

//+------------------------------------------------------------------+
//| Helper: Create Left-Aligned Text Label                           |
//+------------------------------------------------------------------+
void CGuardrailsGUI::CreateTxt(string fullObjName, int x, int y, string text, color col, int fontSize, bool bold, int zorder)
  {
   if(ObjectFind(0, fullObjName) < 0)
      ObjectCreate(0, fullObjName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fullObjName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullObjName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, fullObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullObjName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, fullObjName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, fullObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_ZORDER, zorder);
   if(bold)
      ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI Semibold");
   else
      ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI");
  }

//+------------------------------------------------------------------+
//| Helper: Create Centered Text Label                               |
//+------------------------------------------------------------------+
void CGuardrailsGUI::CreateTxtCentered(string fullObjName, int centerX, int y, string text, color col, int fontSize, bool bold, int zorder)
  {
   if(ObjectFind(0, fullObjName) < 0)
      ObjectCreate(0, fullObjName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fullObjName, OBJPROP_XDISTANCE, centerX);
   ObjectSetInteger(0, fullObjName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, fullObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullObjName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, fullObjName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, fullObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, fullObjName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullObjName, OBJPROP_ZORDER, zorder);
   if(bold)
      ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI Semibold");
   else
      ObjectSetString(0, fullObjName, OBJPROP_FONT, "Segoe UI");
  }

//+------------------------------------------------------------------+
//| Event Dispatcher (Clicks, Edits, Drag & Drop)                    |
//+------------------------------------------------------------------+
void CGuardrailsGUI::ProcessChartEvents(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      if(sparam == PANEL_PREFIX + "LotDisplay")
        {
         string txt = ObjectGetString(0, sparam, OBJPROP_TEXT);
         double new_lot = StringToDouble(txt);
         SetPanelLot(new_lot);
         return;
        }
     }

   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == PANEL_PREFIX + "BtnBuy")
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ExecutePreTradeBuy();
         ChartRedraw(0);
         return;
        }
      else
         if(sparam == PANEL_PREFIX + "BtnSell")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ExecutePreTradeSell();
            ChartRedraw(0);
            return;
           }
         else
            if(sparam == PANEL_PREFIX + "BtnMinus")
              {
               ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
               double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
               SetPanelLot(m_panel_lot - (step > 0 ? step : 0.01));
               return;
              }
            else
               if(sparam == PANEL_PREFIX + "BtnPlus")
                 {
                  ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                  double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                  SetPanelLot(m_panel_lot + (step > 0 ? step : 0.01));
                  return;
                 }
               else
                  if(sparam == PANEL_PREFIX + "BtnAutoLot")
                    {
                     ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                     // Toggle Auto Mode ON/OFF
                     m_auto_lot_enabled = !m_auto_lot_enabled;
                     UpdateAutoLotButtonState();
                     ChartRedraw(0);
                     return;
                    }
                  else
                     if(sparam == PANEL_PREFIX + "BtnMin")
                       {
                        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                        m_panel_minimized = !m_panel_minimized;
                        RenderPanel();
                        ChartRedraw(0);
                        return;
                       }

      if(sparam == MODAL_PREFIX + "BtnClose")
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         HideModal();
         ChartRedraw(0);
         return;
        }
      else
         if(sparam == MODAL_PREFIX + "TabCurrent")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            m_active_tab = 0;
            RenderModal();
            ChartRedraw(0);
            return;
           }
         else
            if(sparam == MODAL_PREFIX + "TabHistory")
              {
               ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
               m_active_tab = 1;
               RenderModal();
               ChartRedraw(0);
               return;
              }
      return;
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;
      uint mouseFlags = (uint)StringToInteger(sparam);
      bool leftBtnDown = ((mouseFlags & 1) != 0);

      if(leftBtnDown)
        {
         if(m_showOrderPanel && !m_is_dragging)
           {
            if(!m_panel_is_dragging)
              {
               if(mouseX >= m_panel_x && mouseX <= (m_panel_x + m_panel_w) &&
                  mouseY >= m_panel_y && mouseY <= (m_panel_y + 32))
                 {
                  m_panel_is_dragging = true;
                  m_panel_drag_dx = mouseX - m_panel_x;
                  m_panel_drag_dy = mouseY - m_panel_y;
                  ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
                 }
              }
            else
              {
               int newX = MathMax(5, mouseX - m_panel_drag_dx);
               int newY = MathMax(5, mouseY - m_panel_drag_dy);

               if(newX != m_panel_x || newY != m_panel_y)
                 {
                  m_panel_x = newX;
                  m_panel_y = newY;
                  RepositionPanel();
                  ChartRedraw(0);
                 }
               return;
              }
           }

         if(m_modal_visible && !m_panel_is_dragging)
           {
            if(!m_is_dragging)
              {
               if(mouseX >= m_modal_x && mouseX <= (m_modal_x + m_modal_w - 40) &&
                  mouseY >= m_modal_y && mouseY <= (m_modal_y + 36))
                 {
                  m_is_dragging = true;
                  m_drag_dx = mouseX - m_modal_x;
                  m_drag_dy = mouseY - m_modal_y;
                  ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
                 }
              }
            else
              {
               int newX = MathMax(5, mouseX - m_drag_dx);
               int newY = MathMax(5, mouseY - m_drag_dy);

               if(newX != m_modal_x || newY != m_modal_y)
                 {
                  m_modal_x = newX;
                  m_modal_y = newY;
                  RepositionModal();
                  ChartRedraw(0);
                 }
               return;
              }
           }
        }
      else
        {
         if(m_is_dragging || m_panel_is_dragging)
           {
            m_is_dragging = false;
            m_panel_is_dragging = false;
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Guardrails\Guardrails_GUI.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_GUI.mqh
