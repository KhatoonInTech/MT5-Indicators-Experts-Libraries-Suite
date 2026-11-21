//+------------------------------------------------------------------+
//|        Include\Guardrails\Guardrails_Core_Management.mqh         |
//|             Role: Handles trade auditing, breakeven, persistent  |
//|             Profit Guard, and master shield management.          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Audited Registry Checks                                          |
//+------------------------------------------------------------------+
bool CGuardrailsCore::IsTicketAudited(ulong ticket)
  {
   string gv_name = "RG_Audited_" + IntegerToString(ticket);
   if(GlobalVariableCheck(gv_name))
      return true;

   int sz = ArraySize(m_audited_tickets);
   for(int i = 0; i < sz; i++)
     {
      if(m_audited_tickets[i] == ticket)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsCore::MarkTicketAudited(ulong ticket)
  {
   string gv_name = "RG_Audited_" + IntegerToString(ticket);
   GlobalVariableSet(gv_name, 1.0);

   int sz = ArraySize(m_audited_tickets);
   ArrayResize(m_audited_tickets, sz + 1);
   m_audited_tickets[sz] = ticket;
  }

//+------------------------------------------------------------------+
//| Audit External / Mobile Trades at Historical Entry Coordinates   |
//+------------------------------------------------------------------+
void CGuardrailsCore::AuditRunningPositions()
  {
   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         ulong ticket = m_position.Ticket();
         string pos_sym = m_position.Symbol();

         if(!m_manageAllSymbols && pos_sym != _Symbol)
            continue;

         if(m_magicNumber != 0 && m_position.Magic() != m_magicNumber)
            continue;

         if(IsTicketAudited(ticket))
            continue;

         string comment = m_position.Comment();
         if(StringFind(comment, "Guardrail Safe") >= 0)
           {
            MarkTicketAudited(ticket);
            continue;
           }

         datetime           open_time  = (datetime)m_position.Time();
         double             open_price = m_position.PriceOpen();
         double             volume     = m_position.Volume();
         ENUM_POSITION_TYPE pos_type   = m_position.PositionType();
         int                dir        = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;

         string   zDetail = "";
         double   zLow = 0.0, zHigh = 0.0;
         datetime zTime = 0;

         if(pos_type == POSITION_TYPE_BUY && m_blockLongsInBearish)
           {
            if(IsInBearishZone(open_price, zDetail, zLow, zHigh, zTime, open_time))
              {
               double cur_loss = CalculateCurrentLoss(volume, pos_sym);
               m_trade.SetAsyncMode(false);
               m_trade.PositionClose(ticket);
               TriggerGuardrailViolation(ticket, pos_sym, volume, 0.0, cur_loss, zDetail, "Killed (Zone)");
               HighlightViolatedZone(zDetail, zLow, zHigh, zTime, false);
               PrintFormat("🚨 EXTERNAL BUY KILLED: Position #%d opened on Mobile inside %s (%.5f - %.5f)!",
                           ticket, zDetail, zLow, zHigh);
               continue;
              }
           }
         else
            if(pos_type == POSITION_TYPE_SELL && m_blockShortsInBullish)
              {
               if(IsInBullishZone(open_price, zDetail, zLow, zHigh, zTime, open_time))
                 {
                  double cur_loss = CalculateCurrentLoss(volume, pos_sym);
                  m_trade.SetAsyncMode(false);
                  m_trade.PositionClose(ticket);
                  TriggerGuardrailViolation(ticket, pos_sym, volume, 0.0, cur_loss, zDetail, "Killed (Zone)");
                  HighlightViolatedZone(zDetail, zLow, zHigh, zTime, true);
                  PrintFormat("🚨 EXTERNAL SELL KILLED: Position #%d opened on Mobile inside %s (%.5f - %.5f)!",
                              ticket, zDetail, zLow, zHigh);
                  continue;
                 }
              }

         if(m_enforceMaxLot)
           {
            double max_safe_at_entry = CalculateMaxAllowedLot(pos_sym, dir, open_price, open_time);
            if(volume > (max_safe_at_entry + 0.009))
              {
               double cur_loss = CalculateCurrentLoss(volume, pos_sym);
               m_trade.SetAsyncMode(false);
               m_trade.PositionClose(ticket);
               double oversize = volume - max_safe_at_entry;
               TriggerGuardrailViolation(ticket, pos_sym, volume, max_safe_at_entry, cur_loss,
                                         StringFormat("+%.2f L Over", oversize), "Killed (Oversized)");
               PrintFormat("🚨 EXTERNAL TRADE KILLED: Position #%d opened on Mobile with %.2f L exceeds 1%% limit (%.2f L)!",
                           ticket, volume, max_safe_at_entry);
               continue;
              }
           }

         MarkTicketAudited(ticket);
         PrintFormat("✅ EXTERNAL TRADE APPROVED: Position #%d (%s %.2f L at %.5f) verified compliant with entry risk.",
                     ticket, (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), volume, open_price);
        }
     }
  }

//+------------------------------------------------------------------+
//| Save Profit Tracker to Persistent GlobalVariables                |
//+------------------------------------------------------------------+
void CGuardrailsCore::SaveProfitTrackerToGV(const SPositionProfitTracker &tracker)
  {
   string pfx = "RG_PG_" + IntegerToString(tracker.ticket) + "_";
   GlobalVariableSet(pfx + "peak", tracker.peak_profit);
   GlobalVariableSet(pfx + "pk_prc", tracker.peak_price);
   GlobalVariableSet(pfx + "armed", tracker.activated ? 1.0 : 0.0);
   GlobalVariableSet(pfx + "bar", (double)tracker.last_processed_bar);
   GlobalVariableSet(pfx + "has_part", tracker.has_partial_closed ? 1.0 : 0.0);
   GlobalVariableSet(pfx + "net_full", tracker.net_profit_full);
   GlobalVariableSet(pfx + "gross_full", tracker.gross_profit_full);
   GlobalVariableSet(pfx + "net_rem", tracker.net_profit_remain);
   GlobalVariableSet(pfx + "gross_rem", tracker.gross_profit_remain);
   GlobalVariableSet(pfx + "part_cnt", (double)tracker.partial_close_count);
   GlobalVariableSet(pfx + "fpk_prc", tracker.first_peak_price);
   GlobalVariableSet(pfx + "auto_trg", tracker.auto_trade_triggered ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| Load Profit Tracker from Persistent GlobalVariables              |
//+------------------------------------------------------------------+
bool CGuardrailsCore::LoadProfitTrackerFromGV(ulong ticket, SPositionProfitTracker &tracker)
  {
   string pfx = "RG_PG_" + IntegerToString(ticket) + "_";
   if(!GlobalVariableCheck(pfx + "peak"))
      return false;

   tracker.peak_profit         = GlobalVariableGet(pfx + "peak");
   tracker.peak_price          = GlobalVariableGet(pfx + "pk_prc");
   tracker.activated           = (GlobalVariableGet(pfx + "armed") > 0.5);
   tracker.last_processed_bar  = (datetime)GlobalVariableGet(pfx + "bar");
   tracker.has_partial_closed  = (GlobalVariableGet(pfx + "has_part") > 0.5);
   tracker.net_profit_full     = GlobalVariableGet(pfx + "net_full");
   tracker.gross_profit_full   = GlobalVariableGet(pfx + "gross_full");
   tracker.net_profit_remain   = GlobalVariableGet(pfx + "net_rem");
   tracker.gross_profit_remain = GlobalVariableGet(pfx + "gross_rem");
   tracker.partial_close_count = (int)GlobalVariableGet(pfx + "part_cnt");
   tracker.first_peak_price    = GlobalVariableGet(pfx + "fpk_prc");
   tracker.auto_trade_triggered= (GlobalVariableGet(pfx + "auto_trg") > 0.5);
   return true;
  }

//+------------------------------------------------------------------+
//| Delete Persistent GlobalVariables on Position Closure            |
//+------------------------------------------------------------------+
void CGuardrailsCore::DeleteProfitTrackerGV(ulong ticket)
  {
   string pfx = "RG_PG_" + IntegerToString(ticket) + "_";
   GlobalVariableDel(pfx + "peak");
   GlobalVariableDel(pfx + "pk_prc");
   GlobalVariableDel(pfx + "armed");
   GlobalVariableDel(pfx + "bar");
   GlobalVariableDel(pfx + "has_part");
   GlobalVariableDel(pfx + "net_full");
   GlobalVariableDel(pfx + "gross_full");
   GlobalVariableDel(pfx + "net_rem");
   GlobalVariableDel(pfx + "gross_rem");
   GlobalVariableDel(pfx + "part_cnt");
   GlobalVariableDel(pfx + "fpk_prc");
   GlobalVariableDel(pfx + "auto_trg");
   GlobalVariableDel("RG_Audited_" + IntegerToString(ticket));
  }

//+------------------------------------------------------------------+
//| Reconstruct Tracker from Trade Deal History & Chart Coordinates  |
//+------------------------------------------------------------------+
bool CGuardrailsCore::ReconstructTrackerFromChartHistory(ulong ticket, string sym, SPositionProfitTracker &tracker)
  {
   if(!m_position.SelectByTicket(ticket))
      return false;

   datetime           pos_open_time = (datetime)m_position.Time();
   double             open_price    = m_position.PriceOpen();
   double             current_vol   = m_position.Volume();
   ENUM_POSITION_TYPE pos_type      = m_position.PositionType();
   long               pos_id        = m_position.Identifier();

   double balance          = AccountInfoDouble(ACCOUNT_BALANCE);
   double activation_money = balance * (m_tpActivationPercent / 100.0);

   HistorySelect(pos_open_time - 10, TimeCurrent() + 60);
   int deals_total = HistoryDealsTotal();

   double   initial_volume = 0.0;
   int      exit_deals     = 0;
   datetime last_exit_time = 0;

   for(int d = 0; d < deals_total; d++)
     {
      ulong d_ticket = HistoryDealGetTicket(d);
      if(d_ticket > 0 && HistoryDealGetInteger(d_ticket, DEAL_POSITION_ID) == pos_id)
        {
         long d_entry = HistoryDealGetInteger(d_ticket, DEAL_ENTRY);
         double d_vol = HistoryDealGetDouble(d_ticket, DEAL_VOLUME);

         if(d_entry == DEAL_ENTRY_IN)
           {
            initial_volume += d_vol;
           }
         else
            if(d_entry == DEAL_ENTRY_OUT || d_entry == DEAL_ENTRY_INOUT)
              {
               exit_deals++;
               last_exit_time = (datetime)HistoryDealGetInteger(d_ticket, DEAL_TIME);
              }
        }
     }

   if(initial_volume <= 0.0)
      initial_volume = current_vol;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(sym, _Period, pos_open_time, TimeCurrent(), rates);
   if(copied < 2)
     {
      SaveProfitTrackerToGV(tracker);
      return true;
     }

   for(int c = 0; c < copied - 1; c++)
     {
      datetime bar_time  = rates[c].time;
      double   bar_open  = rates[c].open;
      double   bar_close = rates[c].close;

      if(bar_time + PeriodSeconds(_Period) <= pos_open_time)
         continue;

      double vol_at_bar = (last_exit_time > 0 && bar_time < last_exit_time) ? initial_volume : current_vol;

      double profit_at_close = 0.0;
      OrderCalcProfit(pos_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                      sym, vol_at_bar, open_price, bar_close, profit_at_close);

      if(!tracker.has_partial_closed)
        {
         if(!tracker.activated)
           {
            if(profit_at_close >= activation_money)
              {
               tracker.activated   = true;
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }
           }
         else
           {
            if(profit_at_close > tracker.peak_profit)
              {
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }

            bool is_opposing = (pos_type == POSITION_TYPE_BUY) ? (bar_close < bar_open) : (bar_close > bar_open);
            if(is_opposing && tracker.peak_profit > 0.0)
              {
               double giveback = ((tracker.peak_profit - profit_at_close) / tracker.peak_profit) * 100.0;
               if(giveback >= m_maxProfitGivebackPercent)
                 {
                  if(tracker.partial_close_count == 0)
                     tracker.first_peak_price = tracker.peak_price;

                  tracker.has_partial_closed  = true;
                  tracker.partial_close_count++;
                  tracker.net_profit_full     = tracker.peak_profit;
                  tracker.gross_profit_full   = profit_at_close;
                  tracker.net_profit_remain   = tracker.net_profit_full * (current_vol / vol_at_bar);
                  tracker.gross_profit_remain = tracker.gross_profit_full * (current_vol / vol_at_bar);
                  tracker.peak_profit         = tracker.gross_profit_remain;
                  tracker.peak_price          = bar_close;
                  tracker.activated           = m_advancedProfitSaving;
                 }
              }
           }
        }
      else
        {
         if(!tracker.activated)
           {
            if(m_advancedProfitSaving || profit_at_close > tracker.net_profit_remain)
              {
               tracker.activated   = true;
               tracker.peak_profit = MathMax(tracker.gross_profit_remain, profit_at_close);
               tracker.peak_price  = bar_close;
              }
           }
         else
           {
            if(profit_at_close > tracker.peak_profit)
              {
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }

            bool is_opposing = (pos_type == POSITION_TYPE_BUY) ? (bar_close < bar_open) : (bar_close > bar_open);
            if(is_opposing && tracker.peak_profit > 0.0)
              {
               double giveback = ((tracker.peak_profit - profit_at_close) / tracker.peak_profit) * 100.0;
               if(giveback >= m_maxProfitGivebackPercent)
                 {
                  tracker.partial_close_count++;
                  tracker.net_profit_full     = tracker.peak_profit;
                  tracker.gross_profit_full   = profit_at_close;
                  tracker.net_profit_remain   = tracker.net_profit_full * (current_vol / vol_at_bar);
                  tracker.gross_profit_remain = tracker.gross_profit_full * (current_vol / vol_at_bar);
                  tracker.peak_profit         = tracker.gross_profit_remain;
                  tracker.peak_price          = bar_close;
                  tracker.activated           = m_advancedProfitSaving;
                 }
              }
           }
        }

      // Auto-Trade Continuation Check
      if(m_autoTradeContinuation && tracker.has_partial_closed && !tracker.auto_trade_triggered && tracker.first_peak_price > 0.0)
        {
         if(pos_type == POSITION_TYPE_BUY && bar_close > tracker.first_peak_price)
            tracker.auto_trade_triggered = true;
         else
            if(pos_type == POSITION_TYPE_SELL && bar_close < tracker.first_peak_price)
               tracker.auto_trade_triggered = true;
        }

      tracker.last_processed_bar = bar_time;
     }

   SaveProfitTrackerToGV(tracker);
   PrintFormat("🔄 RESTORED TRADE HISTORY: %s #%d | Peak: $%.2f | Armed: %s | Partials: %d | NetRemain: $%.2f",
               sym, ticket, tracker.peak_profit, tracker.activated ? "YES" : "NO", tracker.partial_close_count, tracker.net_profit_remain);
   return true;
  }

//+------------------------------------------------------------------+
//| Get or Create Profit Tracker (Persistent State Resolver)         |
//+------------------------------------------------------------------+
int CGuardrailsCore::GetOrCreateProfitTracker(ulong ticket, string sym)
  {
   int total = ArraySize(m_profitTrackers);
   for(int i = 0; i < total; i++)
     {
      if(m_profitTrackers[i].ticket == ticket)
         return i;
     }

   ArrayResize(m_profitTrackers, total + 1);
   m_profitTrackers[total].ticket              = ticket;
   m_profitTrackers[total].symbol              = sym;
   m_profitTrackers[total].peak_profit         = 0.0;
   m_profitTrackers[total].peak_price          = 0.0;
   m_profitTrackers[total].activated           = false;
   m_profitTrackers[total].last_processed_bar  = 0;
   m_profitTrackers[total].has_partial_closed  = false;
   m_profitTrackers[total].net_profit_full     = 0.0;
   m_profitTrackers[total].gross_profit_full   = 0.0;
   m_profitTrackers[total].net_profit_remain   = 0.0;
   m_profitTrackers[total].gross_profit_remain = 0.0;
   m_profitTrackers[total].partial_close_count = 0;
   m_profitTrackers[total].first_peak_price    = 0.0;
   m_profitTrackers[total].auto_trade_triggered= false;

   if(!LoadProfitTrackerFromGV(ticket, m_profitTrackers[total]))
     {
      ReconstructTrackerFromChartHistory(ticket, sym, m_profitTrackers[total]);
     }

   return total;
  }

//+------------------------------------------------------------------+
//| Clean Closed Trackers and Delete Stored GlobalVariables          |
//+------------------------------------------------------------------+
void CGuardrailsCore::CleanProfitTrackers()
  {
   int total = ArraySize(m_profitTrackers);
   for(int i = total - 1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(m_profitTrackers[i].ticket))
        {
         DeleteProfitTrackerGV(m_profitTrackers[i].ticket);
         for(int j = i; j < total - 1; j++)
            m_profitTrackers[j] = m_profitTrackers[j + 1];
         total--;
         ArrayResize(m_profitTrackers, total);
        }
     }

   int a_sz = ArraySize(m_audited_tickets);
   for(int i = a_sz - 1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(m_audited_tickets[i]))
        {
         GlobalVariableDel("RG_Audited_" + IntegerToString(m_audited_tickets[i]));
         for(int j = i; j < a_sz - 1; j++)
            m_audited_tickets[j] = m_audited_tickets[j + 1];
         a_sz--;
         ArrayResize(m_audited_tickets, a_sz);
        }
     }
  }

//+------------------------------------------------------------------+
//| Auto-Breakeven: Candle-Close in Desired Dir + 10x Spread Distance|
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckAndSetBreakevenSL(string sym)
  {
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   long stops_level = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_dist = stops_level * point;

   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double open_price = m_position.PriceOpen();
   double current_sl = m_position.StopLoss();
   double current_tp = m_position.TakeProfit();

   datetime pos_open_time    = (datetime)m_position.Time();
   datetime current_bar_time = iTime(sym, _Period, 0);

   if(m_waitCandleCloseForBE && pos_open_time >= current_bar_time)
      return;

   double closed_price = iClose(sym, _Period, 1);
   double open_price_1 = iOpen(sym, _Period, 1);
   if(closed_price == 0.0 || open_price_1 == 0.0)
      return;

   long spread_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spread_pts <= 0)
     {
      if(point > 0.0 && ask > bid)
         spread_pts = (long)MathRound((ask - bid) / point);
      else
         spread_pts = 10;
     }
   double spread_distance = spread_pts * point;
   double min_be_distance = m_beSpreadMultiplier * spread_distance;

   if(m_position.PositionType() == POSITION_TYPE_BUY)
     {
      bool candle_in_desired_dir = (closed_price > open_price_1);
      bool reached_10x_spread    = (closed_price >= (open_price + min_be_distance));

      if(candle_in_desired_dir && reached_10x_spread)
        {
         double target_sl = NormalizeDouble(open_price + (m_breakevenBuffer * point), digits);
         if(current_sl < target_sl && bid >= target_sl + min_stop_dist)
           {
            m_trade.SetAsyncMode(false);
            if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
               Print("🛡️ AUTO-SL: Shifted SL to BREAKEVEN for ", sym, " BUY #", m_position.Ticket(), " at: ", target_sl);
           }
        }
     }
   else
      if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
         bool candle_in_desired_dir = (closed_price < open_price_1);
         bool reached_10x_spread    = (closed_price <= (open_price - min_be_distance));

         if(candle_in_desired_dir && reached_10x_spread)
           {
            double target_sl = NormalizeDouble(open_price - (m_breakevenBuffer * point), digits);
            if((current_sl == 0.0 || current_sl > target_sl) && ask <= target_sl - min_stop_dist)
              {
               m_trade.SetAsyncMode(false);
               if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
                  Print("🛡️ AUTO-SL: Shifted SL to BREAKEVEN for ", sym, " SELL #", m_position.Ticket(), " at: ", target_sl);
              }
           }
        }
  }

//+------------------------------------------------------------------+
//| DYNAMIC TAKE PROFIT: Advanced Recursive Profit Protection Engine |
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckProfitProtectionGuard()
  {
   if(!m_enableProfitGuard)
      return;

   CleanProfitTrackers();

   int total = PositionsTotal();
   if(total == 0)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double activation_money = balance * (m_tpActivationPercent / 100.0);

   for(int i = total - 1; i >= 0; i--)
     {
      if(!m_position.SelectByIndex(i))
         continue;

      string pos_sym = m_position.Symbol();

      if(!m_manageAllSymbols && pos_sym != _Symbol)
         continue;

      if(m_magicNumber != 0 && m_position.Magic() != m_magicNumber)
         continue;

      ulong              ticket      = m_position.Ticket();
      double             open_price  = m_position.PriceOpen();
      double             current_sl  = m_position.StopLoss();
      double             volume      = m_position.Volume();
      ENUM_POSITION_TYPE pos_type    = m_position.PositionType();
      datetime           pos_time    = (datetime)m_position.Time();

      datetime bar_time_1 = iTime(pos_sym, _Period, 1);
      double   open_1     = iOpen(pos_sym, _Period, 1);
      double   close_1    = iClose(pos_sym, _Period, 1);

      if(bar_time_1 == 0 || open_1 == 0.0 || close_1 == 0.0)
         continue;

      if(bar_time_1 + PeriodSeconds(_Period) <= pos_time)
         continue;

      bool is_at_be = false;
      if(pos_type == POSITION_TYPE_BUY)
         is_at_be = (current_sl >= open_price && current_sl > 0.0);
      else
         if(pos_type == POSITION_TYPE_SELL)
            is_at_be = (current_sl <= open_price && current_sl > 0.0);

      if(!is_at_be)
         continue;

      int t_idx = GetOrCreateProfitTracker(ticket, pos_sym);

      if(m_profitTrackers[t_idx].last_processed_bar == bar_time_1)
         continue;

      double profit_at_close = 0.0;
      if(!OrderCalcProfit(pos_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                          pos_sym, volume, open_price, close_1, profit_at_close))
        {
         profit_at_close = m_position.Profit();
        }
      profit_at_close += (m_position.Swap() + m_position.Commission());

      // -------------------------------------------------------------
      // STAGE 0: Fresh position before any partial close has occurred
      // -------------------------------------------------------------
      if(!m_profitTrackers[t_idx].has_partial_closed)
        {
         if(!m_profitTrackers[t_idx].activated)
           {
            if(profit_at_close >= activation_money)
              {
               m_profitTrackers[t_idx].activated   = true;
               m_profitTrackers[t_idx].peak_profit = profit_at_close;
               m_profitTrackers[t_idx].peak_price  = close_1;
               SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
               PrintFormat("🎯 PROFIT GUARD ARMED: %s #%d closed candle with $%.2f profit (>= 1%% balance: $%.2f).",
                           pos_sym, ticket, profit_at_close, activation_money);
              }
           }
        }
      // -------------------------------------------------------------
      // STAGE 1+: Recursive Scale-Out Mode (Advanced Profit Saving)
      // -------------------------------------------------------------
      else
        {
         if(!m_profitTrackers[t_idx].activated)
           {
            if(m_advancedProfitSaving)
              {
               m_profitTrackers[t_idx].activated   = true;
               m_profitTrackers[t_idx].peak_profit = MathMax(m_profitTrackers[t_idx].gross_profit_remain, profit_at_close);
               m_profitTrackers[t_idx].peak_price  = close_1;
               SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
              }
            else
              {
               if(profit_at_close > m_profitTrackers[t_idx].net_profit_remain)
                 {
                  m_profitTrackers[t_idx].activated   = true;
                  m_profitTrackers[t_idx].peak_profit = profit_at_close;
                  m_profitTrackers[t_idx].peak_price  = close_1;
                  SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
                  PrintFormat("🎯 PROFIT GUARD RE-ARMED: %s #%d remaining profit ($%.2f) > net_profit_remain ($%.2f).",
                              pos_sym, ticket, profit_at_close, m_profitTrackers[t_idx].net_profit_remain);
                 }
              }
           }
        }

      // Track new peak profit
      if(m_profitTrackers[t_idx].activated && profit_at_close > m_profitTrackers[t_idx].peak_profit)
        {
         m_profitTrackers[t_idx].peak_profit = profit_at_close;
         m_profitTrackers[t_idx].peak_price  = close_1;
         SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
        }

      // Check for opposing candle close
      bool is_opposing_candle = false;
      if(pos_type == POSITION_TYPE_BUY)
         is_opposing_candle = (close_1 < open_1);
      else
         if(pos_type == POSITION_TYPE_SELL)
            is_opposing_candle = (close_1 > open_1);

      if(is_opposing_candle && m_profitTrackers[t_idx].peak_profit > 0.0)
        {
         double profit_erased = m_profitTrackers[t_idx].peak_profit - profit_at_close;
         double giveback_pct  = (profit_erased / m_profitTrackers[t_idx].peak_profit) * 100.0;

         if(giveback_pct >= m_maxProfitGivebackPercent)
           {
            double lot_step   = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_STEP);
            double min_lot    = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_MIN);
            double max_lot    = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_MAX);
            if(lot_step <= 0.0)
               lot_step = 0.01;
            if(min_lot <= 0.0)
               min_lot  = 0.01;
            int lot_digits    = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step)));

            double close_vol = NormalizeDouble(volume * (m_partialClosePercent / 100.0), lot_digits);
            if(lot_step > 0.0)
               close_vol = MathFloor(close_vol / lot_step) * lot_step;
            close_vol = NormalizeDouble(close_vol, lot_digits);

            double remain_vol = NormalizeDouble(volume - close_vol, lot_digits);

            bool allow_partial = (close_vol >= min_lot && remain_vol >= min_lot && close_vol <= max_lot);

            if(!allow_partial)
              {
               PrintFormat("🛑 PROFIT GUARD: Broker limits do not allow partial close of %.2f L on %s #%d. Closing full position!",
                           close_vol, pos_sym, ticket);

               m_trade.SetAsyncMode(false);
               if(m_trade.PositionClose(ticket))
                 {
                  DeleteProfitTrackerGV(ticket);
                  string vi_msg = StringFormat("-%.0f%% Giveback", giveback_pct);
                  TriggerGuardrailViolation(ticket, pos_sym, volume, CalculateMaxAllowedLot(pos_sym, 0),
                                            profit_at_close, vi_msg, "Full TP Close");
                 }
              }
            else
              {
               m_trade.SetAsyncMode(false);
               if(m_trade.PositionClosePartial(ticket, close_vol))
                 {
                  double remain_ratio = remain_vol / volume;

                  if(m_profitTrackers[t_idx].partial_close_count == 0)
                     m_profitTrackers[t_idx].first_peak_price = m_profitTrackers[t_idx].peak_price;

                  m_profitTrackers[t_idx].net_profit_full     = m_profitTrackers[t_idx].peak_profit;
                  m_profitTrackers[t_idx].gross_profit_full   = profit_at_close;
                  m_profitTrackers[t_idx].net_profit_remain   = m_profitTrackers[t_idx].net_profit_full * remain_ratio;
                  m_profitTrackers[t_idx].gross_profit_remain = m_profitTrackers[t_idx].gross_profit_full * remain_ratio;
                  m_profitTrackers[t_idx].has_partial_closed  = true;
                  m_profitTrackers[t_idx].partial_close_count++;

                  m_profitTrackers[t_idx].peak_profit = m_profitTrackers[t_idx].gross_profit_remain;
                  m_profitTrackers[t_idx].peak_price  = close_1;
                  m_profitTrackers[t_idx].activated   = m_advancedProfitSaving;

                  SaveProfitTrackerToGV(m_profitTrackers[t_idx]);

                  PrintFormat("🎯 PARTIAL CLOSE #%d SUCCESS: %s #%d | Closed: %.2f L (%.0f%%), Remaining: %.2f L",
                              m_profitTrackers[t_idx].partial_close_count, pos_sym, ticket, close_vol, m_partialClosePercent, remain_vol);
                  PrintFormat("   -> net_profit_full   = $%.4f", m_profitTrackers[t_idx].net_profit_full);
                  PrintFormat("   -> gross_profit_full = $%.4f", m_profitTrackers[t_idx].gross_profit_full);
                  PrintFormat("   -> net_profit_remain = $%.4f", m_profitTrackers[t_idx].net_profit_remain);
                  PrintFormat("   -> gross_profit_rem  = $%.4f", m_profitTrackers[t_idx].gross_profit_remain);

                  double realized_profit = profit_at_close * (close_vol / volume);
                  string vi_msg = StringFormat("-%.0f%% Retrace", giveback_pct);
                  TriggerGuardrailViolation(ticket, pos_sym, close_vol, CalculateMaxAllowedLot(pos_sym, 0),
                                            realized_profit, vi_msg, StringFormat("Partial %.0f%%", m_partialClosePercent));
                 }
              }
           }
        }

      // -------------------------------------------------------------
      // AUTO-TRADE CONTINUATION CHECK
      // -------------------------------------------------------------
      if(m_autoTradeContinuation && m_profitTrackers[t_idx].has_partial_closed && !m_profitTrackers[t_idx].auto_trade_triggered && m_profitTrackers[t_idx].first_peak_price > 0.0)
        {
         bool trigger_auto = false;
         if(pos_type == POSITION_TYPE_BUY && close_1 > m_profitTrackers[t_idx].first_peak_price)
            trigger_auto = true;
         else
            if(pos_type == POSITION_TYPE_SELL && close_1 < m_profitTrackers[t_idx].first_peak_price)
               trigger_auto = true;

         if(trigger_auto)
           {
            m_profitTrackers[t_idx].auto_trade_triggered = true;
            SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
            ExecuteAutoTrade(pos_sym, (pos_type == POSITION_TYPE_BUY) ? 1 : -1);
           }
        }

      m_profitTrackers[t_idx].last_processed_bar = bar_time_1;
     }
  }

//+------------------------------------------------------------------+
//| MASTER SHIELD LOOP (Safe Running Mode + External Trade Auditor)  |
//+------------------------------------------------------------------+
void CGuardrailsCore::RunMasterShield()
  {
   UpdateSMCZones();

// Audit unverified / mobile trades once against entry coordinates
   AuditRunningPositions();

// Dynamic TP Partial Close Guardrail
   CheckProfitProtectionGuard();

   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         string pos_sym = m_position.Symbol();

         if(!m_manageAllSymbols && pos_sym != _Symbol)
            continue;

         if(m_magicNumber == 0 || m_position.Magic() == m_magicNumber)
           {
            if(m_emergencyCircuitBreaker)
               CheckEmergencyLossCut(pos_sym);

            if(m_autoBreakeven)
               CheckAndSetBreakevenSL(pos_sym);
           }
        }
     }
  }

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Management.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Management.mqh
