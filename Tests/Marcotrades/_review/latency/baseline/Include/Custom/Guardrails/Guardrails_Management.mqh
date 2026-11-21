//+------------------------------------------------------------------+
//|                      Include\ZigZag\Guardrails_Management.mqh    | 
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "13.00"
#property description "Unified Guardrails Engine - Full Buy Protection in Demand Zone"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define MODAL_PREFIX "RG_Modal_"
#define NUM_COLS 7

// Data struct for historical violations
struct OrderLog
  {
   datetime          time;
   ulong             ticket;
   double            volume;
   double            max_allowed;
   double            loss;
   string            violation;
   string            status;
  };

//+------------------------------------------------------------------+
//| Master Protection Class                                          |
//+------------------------------------------------------------------+
class CGuardrailsProtection
  {
private:
   // User Configurations
   double            m_demandTop;
   double            m_demandBottom;
   bool              m_blockShorts;
   ulong             m_magicNumber;
   bool              m_enforceMaxLot;
   double            m_maxSpreadShare;
   bool              m_showHUD;
   bool              m_excludeSpread;
   double            m_maxRiskPercent;
   bool              m_emergencyCircuitBreaker;
   bool              m_autoBreakeven;
   int               m_breakevenBuffer;

   // Trade Engine Objects
   CTrade            m_trade;
   CPositionInfo     m_position;

   // Pop-Up Modal State
   OrderLog          m_history[];
   OrderLog          m_current;
   bool              m_modal_visible;
   int               m_active_tab;

   // Coordinates & Dragging
   int               m_modal_x;
   int               m_modal_y;
   int               m_modal_w;
   bool              m_is_dragging;
   int               m_drag_dx;
   int               m_drag_dy;

   // Grid Column Definitions
   int               m_colW[NUM_COLS];
   string            m_colTitles[NUM_COLS];

   // Internal Helpers
   bool              IsInDemandZone(double price);
   double            CalculateMaxAllowedLot();
   bool              CheckOptionB_LotGatekeeper(ulong ticket, double volume);
   void              AttachOptionC_RiskSL();
   void              CheckEmergencyLossCut();
   void              CheckAndSetBreakevenSL();
   void              CheckAndCloseShorts();
   void              CheckAndCancelPendingShorts();
   void              DrawDemandZone();
   void              UpdateChartHUD();

   // Central Trigger for ANY Guardrail Violation
   void              TriggerGuardrailViolation(ulong ticket, double volume, double max_allowed, double loss, string violation, string status);

   // GUI Builders
   int               GetCompactModalHeight();
   void              ShowModal();
   void              HideModal();
   void              DestroyModal();
   void              CreateBox(string name, int x, int y, int w, int h, color bg, color border);
   void              CreateBtn(string name, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol);
   void              CreateTxt(string name, int x, int y, string text, color col, int fontSize=8, bool bold=false);
   void              RenderModal();
   void              RepositionModal();

public:
                     CGuardrailsProtection();
                    ~CGuardrailsProtection();

   int               OnInit(double demandTop, double demandBottom, bool blockShorts, ulong magic,
                         bool enforceMaxLot, double maxSpreadShare, bool showHUD,
                         bool excludeSpread, double maxRiskPercent, bool circuitBreaker,
                         bool autoBreakeven, int breakevenBuffer);
   void              OnDeinit(const int reason);
   void              OnTick();
   void              OnTrade();
   void              OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   void              OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   void              RunMasterShield();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGuardrailsProtection::CGuardrailsProtection()
  {
   m_modal_visible = false;
   m_active_tab    = 0;
   m_modal_x       = 180;
   m_modal_y       = 80;
   m_modal_w       = 555;
   m_is_dragging   = false;
   m_drag_dx       = 0;
   m_drag_dy       = 0;

   int widths[NUM_COLS] = {60, 85, 68, 68, 68, 108, 68};
   string titles[NUM_COLS] = {"Time", "Ticket", "Attempted", "Max Safe", "Loss ($)", "Violation", "Status"};

   for(int i = 0; i < NUM_COLS; i++)
     {
      m_colW[i]      = widths[i];
      m_colTitles[i] = titles[i];
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGuardrailsProtection::~CGuardrailsProtection()
  {
  }

//+------------------------------------------------------------------+
//| Engine Initializer                                               |
//+------------------------------------------------------------------+
int CGuardrailsProtection::OnInit(double demandTop, double demandBottom, bool blockShorts, ulong magic,
                                  bool enforceMaxLot, double maxSpreadShare, bool showHUD,
                                  bool excludeSpread, double maxRiskPercent, bool circuitBreaker,
                                  bool autoBreakeven, int breakevenBuffer)
  {
   m_demandTop              = demandTop;
   m_demandBottom           = demandBottom;
   m_blockShorts            = blockShorts;
   m_magicNumber            = magic;
   m_enforceMaxLot          = enforceMaxLot;
   m_maxSpreadShare         = maxSpreadShare;
   m_showHUD                = showHUD;
   m_excludeSpread          = excludeSpread;
   m_maxRiskPercent         = maxRiskPercent;
   m_emergencyCircuitBreaker= circuitBreaker;
   m_autoBreakeven          = autoBreakeven;
   m_breakevenBuffer        = breakevenBuffer;

   if(m_demandTop <= m_demandBottom && m_demandTop != 0.0)
     {
      Alert("Error: Demand Zone Top must be greater than Demand Zone Bottom!");
      return(INIT_PARAMETERS_INCORRECT);
     }

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   DrawDemandZone();
   UpdateChartHUD();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Engine Cleanup                                                   |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnDeinit(const int reason)
  {
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
   ObjectDelete(0, "DemandZoneRect");
   Comment("");
   DestroyModal();
  }

//+------------------------------------------------------------------+
//| CENTRAL POP-UP TRIGGER (With Anti-Spam Cooldown Lock)            |
//+------------------------------------------------------------------+
void CGuardrailsProtection::TriggerGuardrailViolation(ulong ticket, double volume, double max_allowed, double loss, string violation, string status)
  {
   static ulong    last_ticket    = 0;
   static string   last_violation = "";
   static datetime last_time      = 0;

   datetime now = TimeLocal();
   if(ticket == last_ticket && violation == last_violation && (now - last_time) < 2)
      return;

   last_ticket    = ticket;
   last_violation = violation;
   last_time      = now;

   int sz = ArraySize(m_history);
   ArrayResize(m_history, sz + 1);
   m_history[sz].time        = TimeCurrent();
   m_history[sz].ticket      = ticket;
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
//| Trade Transaction Event: Detects 1% SL Hit & Breakeven SL Hit   |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong deal_ticket = trans.deal;
      if(HistoryDealSelect(deal_ticket))
        {
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) == _Symbol)
           {
            ulong magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
            if(m_magicNumber == 0 || magic == m_magicNumber)
              {
               long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
               if(deal_entry == DEAL_ENTRY_OUT)
                 {
                  long deal_reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
                  if(deal_reason == DEAL_REASON_SL)
                    {
                     ulong  pos_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
                     double vol    = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
                     double pnl    = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                                     HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                                     HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

                     double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
                     double half_pct = balance * 0.005;

                     if(pnl >= -half_pct)
                       {
                        TriggerGuardrailViolation(pos_id, vol, vol, pnl, "Breakeven Hit", "BE Closed");
                       }
                     else
                       {
                        TriggerGuardrailViolation(pos_id, vol, vol, pnl, "1% SL Hit", "1% SL Cut");
                       }
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Tick / Trade Event Handlers                                      |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTick()
  {
   RunMasterShield();
   UpdateChartHUD();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTrade()
  {
   RunMasterShield();
   UpdateChartHUD();
  }

//+------------------------------------------------------------------+
//| Chart Event Dispatcher (Clicks & Dragging)                       |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == MODAL_PREFIX + "BtnClose")
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         HideModal();
        }
      else
         if(sparam == MODAL_PREFIX + "TabCurrent")
           {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            m_active_tab = 0;
            RenderModal();
           }
         else
            if(sparam == MODAL_PREFIX + "TabHistory")
              {
               ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
               m_active_tab = 1;
               RenderModal();
              }
      ChartRedraw(0);
      return;
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      if(!m_modal_visible)
         return;

      int mouseX = (int)lparam;
      int mouseY = (int)dparam;
      uint mouseFlags = (uint)StringToInteger(sparam);
      bool leftBtnDown = ((mouseFlags & 1) != 0);

      if(leftBtnDown)
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
            int newX = mouseX - m_drag_dx;
            int newY = mouseY - m_drag_dy;

            newX = MathMax(5, newX);
            newY = MathMax(5, newY);

            if(newX != m_modal_x || newY != m_modal_y)
              {
               m_modal_x = newX;
               m_modal_y = newY;
               RepositionModal();
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

//+------------------------------------------------------------------+
//| MASTER PROTECTION ENGINE (PROTECTS BUYS INSIDE DEMAND ZONE)      |
//+------------------------------------------------------------------+
void CGuardrailsProtection::RunMasterShield()
  {
// 1. Demand Zone: Check and kill any forbidden SHORTS
   if(m_blockShorts && m_demandTop > 0 && m_demandBottom > 0)
     {
      CheckAndCloseShorts();
      CheckAndCancelPendingShorts();
     }

// 2. Full Protection Engine: Protects ALL active trades (INCLUDING BUYS IN DEMAND ZONE!)
   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol)
           {
            if(m_magicNumber == 0 || m_position.Magic() == m_magicNumber)
              {
               double open_price = m_position.PriceOpen();

               // If it is a forbidden short inside demand zone, it's already handled above
               if(m_position.PositionType() == POSITION_TYPE_SELL && IsInDemandZone(open_price) && m_blockShorts)
                  continue;

               // --- FULL PROTECTION APPLIED TO ALL TRADES (INCLUDING BUY IN DEMAND ZONE) ---

               // Step A: Option B Lot Size Gatekeeper
               if(m_enforceMaxLot)
                 {
                  if(!CheckOptionB_LotGatekeeper(m_position.Ticket(), m_position.Volume()))
                     continue;
                 }

               // Step B: Emergency 1% Circuit Breaker
               if(m_emergencyCircuitBreaker)
                  CheckEmergencyLossCut();

               // Step C: Option C 1% Hard SL (Attached immediately upon entry!)
               if(m_position.StopLoss() == 0.0)
                  AttachOptionC_RiskSL();

               // Step D: Auto-Breakeven (Rolls SL to Entry Price when in profit)
               if(m_autoBreakeven)
                  CheckAndSetBreakevenSL();
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculations & Protections                                       |
//+------------------------------------------------------------------+
bool CGuardrailsProtection::IsInDemandZone(double price)
  {
   if(m_demandTop == 0.0 || m_demandBottom == 0.0)
      return false;
   return (price <= m_demandTop && price >= m_demandBottom);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CGuardrailsProtection::CalculateMaxAllowedLot()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_risk_money = balance * (m_maxRiskPercent / 100.0);

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(tick_size <= 0 || point <= 0 || tick_value <= 0 || spread_pts <= 0)
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double point_val_per_lot = tick_value / (tick_size / point);
   double spread_cost_per_lot = spread_pts * point_val_per_lot;

   double max_tolerated_spread_cost = max_risk_money * (m_maxSpreadShare / 100.0);
   double max_lot = max_tolerated_spread_cost / spread_cost_per_lot;

   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot_broker = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lot_step > 0)
      max_lot = MathFloor(max_lot / lot_step) * lot_step;

   max_lot = MathMax(min_lot, MathMin(max_lot, max_lot_broker));
   return NormalizeDouble(max_lot, 2);
  }

// Guardrail: Option B Lot Gatekeeper
bool CGuardrailsProtection::CheckOptionB_LotGatekeeper(ulong ticket, double volume)
  {
   double max_safe_lot = CalculateMaxAllowedLot();

   if(volume > max_safe_lot)
     {
      double cur_loss = m_position.Profit() + m_position.Swap();
      if(cur_loss >= 0.0)
        {
         double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
         double pt       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         long   sp_pts   = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(tick_sz > 0 && pt > 0)
            cur_loss = -((sp_pts * pt / tick_sz) * tick_val * volume);
        }

      m_trade.SetAsyncMode(true);
      m_trade.PositionClose(ticket);

      double oversize = volume - max_safe_lot;
      TriggerGuardrailViolation(ticket, volume, max_safe_lot, cur_loss,
                                StringFormat("+%.2f L Over", oversize), "Killed");

      return false;
     }
   return true;
  }

// Guardrail: Demand Zone Short Blocker (Market Position)
void CGuardrailsProtection::CheckAndCloseShorts()
  {
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.PositionType() == POSITION_TYPE_SELL && m_position.Symbol() == _Symbol)
           {
            if(m_magicNumber == 0 || m_position.Magic() == m_magicNumber)
              {
               if(IsInDemandZone(m_position.PriceOpen()))
                 {
                  ulong ticket = m_position.Ticket();
                  double vol   = m_position.Volume();
                  double cur_loss = m_position.Profit() + m_position.Swap();

                  if(cur_loss >= 0.0)
                    {
                     double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                     double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
                     double pt       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                     long   sp_pts   = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
                     if(tick_sz > 0 && pt > 0)
                        cur_loss = -((sp_pts * pt / tick_sz) * tick_val * vol);
                    }

                  m_trade.SetAsyncMode(true);
                  m_trade.PositionClose(ticket);

                  TriggerGuardrailViolation(ticket, vol, 0.0, cur_loss, "Short in Demand", "Killed");
                 }
              }
           }
        }
     }
  }

// Guardrail: Demand Zone Pending Short Blocker
void CGuardrailsProtection::CheckAndCancelPendingShorts()
  {
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
        {
         long type = OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP)
           {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol)
              {
               ulong magic = OrderGetInteger(ORDER_MAGIC);
               if(m_magicNumber == 0 || magic == m_magicNumber)
                 {
                  if(IsInDemandZone(OrderGetDouble(ORDER_PRICE_OPEN)))
                    {
                     double vol = OrderGetDouble(ORDER_VOLUME_INITIAL);
                     m_trade.SetAsyncMode(true);
                     m_trade.OrderDelete(ticket);

                     TriggerGuardrailViolation(ticket, vol, 0.0, 0.0, "Pending in Demand", "Deleted");
                    }
                 }
              }
           }
        }
     }
  }

// Guardrail: Emergency Circuit Breaker (Max Risk Cut)
void CGuardrailsProtection::CheckEmergencyLossCut()
  {
   ulong ticket = m_position.Ticket();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_risk_money = balance * (m_maxRiskPercent / 100.0);
   double volume = m_position.Volume();

   if(m_excludeSpread)
     {
      double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      long   spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

      double spread_cost = (spread_pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / tick_size) * tick_value * volume;
      max_risk_money += spread_cost;
     }

   double current_profit = m_position.Profit() + m_position.Swap();

   if(current_profit <= -max_risk_money)
     {
      m_trade.SetAsyncMode(true);
      m_trade.PositionClose(ticket);

      TriggerGuardrailViolation(ticket, volume, volume, current_profit, "1% Circuit Cut", "Emergency");
     }
  }

// Attach 1% Hard SL (Applies to Buys in Demand Zone too!)
void CGuardrailsProtection::AttachOptionC_RiskSL()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_risk_money = balance * (m_maxRiskPercent / 100.0);
   double volume = m_position.Volume();

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);

   if(tick_size <= 0 || tick_value <= 0 || volume <= 0)
      return;

   double price_distance = (max_risk_money / (volume * tick_value)) * tick_size;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double open_price = m_position.PriceOpen();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_dist = stops_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double target_sl = 0.0;

   if(m_position.PositionType() == POSITION_TYPE_BUY)
     {
      if(m_excludeSpread)
         target_sl = NormalizeDouble(bid - price_distance, digits);
      else
         target_sl = NormalizeDouble(open_price - price_distance, digits);

      if((bid - target_sl) >= min_dist)
        {
         m_trade.SetAsyncMode(false);
         if(m_trade.PositionModify(m_position.Ticket(), target_sl, m_position.TakeProfit()))
            Print("🛡️ [1% SL SHIELD]: Attached 1% SL to BUY #", m_position.Ticket(), " at ", target_sl);
        }
     }
   else
      if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
         if(m_excludeSpread)
            target_sl = NormalizeDouble(ask + price_distance, digits);
         else
            target_sl = NormalizeDouble(open_price + price_distance, digits);

         if((target_sl - ask) >= min_dist)
           {
            m_trade.SetAsyncMode(false);
            if(m_trade.PositionModify(m_position.Ticket(), target_sl, m_position.TakeProfit()))
               Print("🛡️ [1% SL SHIELD]: Attached 1% SL to SELL #", m_position.Ticket(), " at ", target_sl);
           }
        }
  }

// Auto-Breakeven Transition (Applies to Buys in Demand Zone too!)
void CGuardrailsProtection::CheckAndSetBreakevenSL()
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_dist = stops_level * point;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double open_price = m_position.PriceOpen();
   double current_sl = m_position.StopLoss();
   double current_tp = m_position.TakeProfit();

   if(m_position.PositionType() == POSITION_TYPE_BUY)
     {
      double target_sl = NormalizeDouble(open_price + (m_breakevenBuffer * point), digits);

      if(current_sl < target_sl)
        {
         if(bid >= target_sl + min_stop_dist)
           {
            m_trade.SetAsyncMode(false);
            if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
               Print("🎯 AUTO-SL: Shifted SL to BREAKEVEN for BUY #", m_position.Ticket(), " at: ", target_sl);
           }
        }
     }
   else
      if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
         double target_sl = NormalizeDouble(open_price - (m_breakevenBuffer * point), digits);

         if(current_sl == 0.0 || current_sl > target_sl)
           {
            if(ask <= target_sl - min_stop_dist)
              {
               m_trade.SetAsyncMode(false);
               if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
                  Print("🎯 AUTO-SL: Shifted SL to BREAKEVEN for SELL #", m_position.Ticket(), " at: ", target_sl);
              }
           }
        }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::UpdateChartHUD()
  {
   if(!m_showHUD)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (m_maxRiskPercent / 100.0);
   double max_safe_lot = CalculateMaxAllowedLot();
   long   spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   string hud = StringFormat(
                   "╔══════════════════════════════════════════╗\n"
                   "   GUARDRAIS PROTECTION ENGINE v13.00\n"
                   "   Balance: $%.2f  |  1%% Risk: $%.2f\n"
                   "   Current Spread: %d points\n"
                   "   ────────────────────────────────────────\n"
                   "   [OPTION B] Max Safe Lot: %.2f Lots\n"
                   "   [OPTION C] Spread Excluded: %s\n"
                   "╚══════════════════════════════════════════╝",
                   balance, risk_money, spread_pts, max_safe_lot,
                   m_excludeSpread ? "ENABLED (1% Pure Move)" : "DISABLED"
                );

   Comment(hud);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::DrawDemandZone()
  {
   if(m_demandTop == 0.0 || m_demandBottom == 0.0)
      return;
   string obj_name = "DemandZoneRect";
   datetime time1 = TimeCurrent() - (86400 * 10);
   datetime time2 = TimeCurrent() + (86400 * 365);

   ObjectDelete(0, obj_name);
   ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time1, m_demandTop, time2, m_demandBottom);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrMediumSeaGreen);
   ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
   ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, "Protected Demand Zone (No Shorts allowed)");
  }

//+------------------------------------------------------------------+
//| GUI Helpers                                                      |
//+------------------------------------------------------------------+
int CGuardrailsProtection::GetCompactModalHeight()
  {
   int rowCount = (m_active_tab == 0) ? 1 : MathMax(1, MathMin(5, ArraySize(m_history)));
   return (78 + 24 + (rowCount * 26) + 14);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::ShowModal()
  {
   m_active_tab = 0;
   m_modal_visible = true;
   RenderModal();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::HideModal()
  {
   m_modal_visible = false;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
   DestroyModal();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::DestroyModal()
  {
   ObjectsDeleteAll(0, MODAL_PREFIX);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::CreateBox(string name, int x, int y, int w, int h, color bg, color border)
  {
   string obj = MODAL_PREFIX + name;
   if(ObjectFind(0, obj) < 0)
      ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::CreateBtn(string name, int x, int y, int w, int h, string text, color bg, color txtCol, color borderCol)
  {
   string obj = MODAL_PREFIX + name;
   if(ObjectFind(0, obj) < 0)
      ObjectCreate(0, obj, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, txtCol);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_COLOR, borderCol);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_STATE, false);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, obj, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::CreateTxt(string name, int x, int y, string text, color col, int fontSize=8, bool bold=false)
  {
   string obj = MODAL_PREFIX + name;
   if(ObjectFind(0, obj) < 0)
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, col);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   if(bold)
      ObjectSetString(0, obj, OBJPROP_FONT, "Arial Bold");
   else
      ObjectSetString(0, obj, OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::RenderModal()
  {
   if(!m_modal_visible)
      return;
   DestroyModal();

   color col_card_bg    = C'255,255,255';
   color col_border     = C'210,215,225';
   color col_cell_border= C'220,225,235';
   color col_header_bg  = C'243,245,249';
   color col_title      = C'25,35,50';
   color col_tbl_hdr_bg = C'232,238,247';
   color col_tbl_hdr_tc = C'30,45,65';
   color col_row_alt    = C'247,249,252';
   color col_row_white  = C'255,255,255';
   color col_text_dark  = C'40,50,65';

   int compact_h = GetCompactModalHeight();

   CreateBox("MainBG", m_modal_x, m_modal_y, m_modal_w, compact_h, col_card_bg, col_border);
   CreateBox("HeaderBG", m_modal_x, m_modal_y, m_modal_w, 36, col_header_bg, col_border);

   CreateTxt("Title", m_modal_x + 16, m_modal_y + 9, "⚠️ RISK GUARD NOTIFICATION [DRAG HERE]", col_title, 10, true);
   CreateBtn("BtnClose", m_modal_x + m_modal_w - 36, m_modal_y + 5, 28, 25, "✖", C'254,226,226', C'185,28,28', C'252,165,165');

// Navigation Tabs
   color tab1_bg = (m_active_tab == 0) ? C'37,99,235' : C'241,245,249';
   color tab1_tc = (m_active_tab == 0) ? clrWhite : C'71,85,105';
   color tab2_bg = (m_active_tab == 1) ? C'37,99,235' : C'241,245,249';
   color tab2_tc = (m_active_tab == 1) ? clrWhite : C'71,85,105';

   CreateBtn("TabCurrent", m_modal_x + 15, m_modal_y + 44, 140, 26, "[ Current Order ]", tab1_bg, tab1_tc, col_border);
   CreateBtn("TabHistory", m_modal_x + 165, m_modal_y + 44, 140, 26, StringFormat("[ History (%d) ]", ArraySize(m_history)), tab2_bg, tab2_tc, col_border);

   int tableTopY = m_modal_y + 78;
   int tableX    = m_modal_x + 15;

   int colX[NUM_COLS];
   colX[0] = tableX;
   for(int c = 1; c < NUM_COLS; c++)
      colX[c] = colX[c - 1] + m_colW[c - 1];

// 1. Draw Bordered Table Header
   for(int c = 0; c < NUM_COLS; c++)
     {
      CreateBox(StringFormat("HCell_%d", c), colX[c], tableTopY, m_colW[c], 24, col_tbl_hdr_bg, col_cell_border);
      CreateTxt(StringFormat("HTxt_%d", c),  colX[c] + 6, tableTopY + 5, m_colTitles[c], col_tbl_hdr_tc, 8, true);
     }

// 2. Draw Bordered Data Rows
   int rowCount = (m_active_tab == 0) ? 1 : MathMin(5, ArraySize(m_history));
   int startRowY = tableTopY + 24;

   for(int r = 0; r < rowCount; r++)
     {
      OrderLog log = (m_active_tab == 0) ? m_current : m_history[ArraySize(m_history) - 1 - r];
      int curRowY  = startRowY + (r * 26);
      color rowBg  = (r % 2 == 0) ? col_row_white : col_row_alt;

      string maxSafeStr = (log.max_allowed > 0.0) ? StringFormat("%.2f L", log.max_allowed) : "-";
      string lossStr    = (log.loss != 0.0) ? StringFormat("%s$%.2f", (log.loss < 0 ? "-" : "+"), MathAbs(log.loss)) : "$0.00";
      color  lossCol    = (log.loss < 0) ? C'190,25,25' : (log.loss > 0 ? C'22,101,52' : col_text_dark);

      string rowData[NUM_COLS] =
        {
         TimeToString(log.time, TIME_MINUTES|TIME_SECONDS),
         StringFormat("#%d", log.ticket),
         StringFormat("%.2f L", log.volume),
         maxSafeStr,
         lossStr,
         log.violation,
         log.status
        };

      color colColors[NUM_COLS] = {col_text_dark, col_text_dark, C'190,25,25', C'22,101,52', lossCol, C'190,25,25', C'220,38,38'};

      for(int c = 0; c < NUM_COLS; c++)
        {
         CreateBox(StringFormat("RCell_%d_%d", r, c), colX[c], curRowY, m_colW[c], 26, rowBg, col_cell_border);
         CreateTxt(StringFormat("RTxt_%d_%d", r, c),  colX[c] + 6, curRowY + 6, rowData[c], colColors[c], 8, (c >= 2));
        }
     }

   if(m_active_tab == 1 && ArraySize(m_history) == 0)
     {
      CreateBox("EmptyCell", tableX, startRowY, 525, 30, col_row_white, col_cell_border);
      CreateTxt("EmptyTxt",  tableX + 15, startRowY + 8, "No historical violations recorded yet in this session.", C'120,130,140');
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsProtection::RepositionModal()
  {
   int compact_h = GetCompactModalHeight();

   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_XDISTANCE, m_modal_x);
   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_YDISTANCE, m_modal_y);
   ObjectSetInteger(0, MODAL_PREFIX + "MainBG", OBJPROP_YSIZE, compact_h);

   ObjectSetInteger(0, MODAL_PREFIX + "HeaderBG", OBJPROP_XDISTANCE, m_modal_x);
   ObjectSetInteger(0, MODAL_PREFIX + "HeaderBG", OBJPROP_YDISTANCE, m_modal_y);

   ObjectSetInteger(0, MODAL_PREFIX + "Title", OBJPROP_XDISTANCE, m_modal_x + 16);
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

// END FILE: Include\Custom\Guardrails\Guardrails_Management.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Management.mqh
