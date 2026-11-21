//+------------------------------------------------------------------+
//|           Include\Guardrails\Guardrails_Core_Risk.mqh            |
//|             Role: Handles tick values, structural lot sizing,    |
//|             loss calculation, and emergency risk cuts.           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Universal Broker-Proof Tick Value Resolver                       |
//+------------------------------------------------------------------+
double CGuardrailsCore::GetSymbolTickValue(string sym)
  {
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(tv <= 0.0)
      tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0)
      tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_PROFIT);

   if(tv <= 0.0)
     {
      double bid     = SymbolInfoDouble(sym, SYMBOL_BID);
      double tick_sz = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tick_sz <= 0.0)
         tick_sz = SymbolInfoDouble(sym, SYMBOL_POINT);

      if(bid > 0.0 && tick_sz > 0.0)
        {
         double profit = 0.0;
         if(OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, bid, bid + tick_sz, profit))
            tv = MathAbs(profit);
        }
     }

   if(tv <= 0.0)
     {
      double contract_sz = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      double tick_sz     = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tick_sz <= 0.0)
         tick_sz = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(contract_sz > 0.0 && tick_sz > 0.0)
         tv = contract_sz * tick_sz;
     }

   return (tv > 0.0) ? tv : 1.0;
  }

//+------------------------------------------------------------------+
//| Calculate Max Safe Lot Size from Structural Zone Distance & Margin|
//+------------------------------------------------------------------+
double CGuardrailsCore::CalculateMaxAllowedLot(string sym, int direction, double custom_price, datetime at_time)
  {
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free_margin <= 0.0)
      free_margin = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0 || free_margin <= 0.0)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   double max_risk_money = balance * (m_maxRiskPercent / 100.0);

   double ask       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_BID);
   double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = point;
   double tick_val  = GetSymbolTickValue(sym);

   double price_distance = 0.0;
   string zName          = "";
   double zBoundary      = 0.0;

   if(direction == -1)
     {
      if(GetNearestBearishBoundary(sym, bid, zBoundary, zName, at_time))
         price_distance = MathAbs(zBoundary - bid);
     }
   else
      if(direction == 1)
        {
         if(GetNearestBullishBoundary(sym, ask, zBoundary, zName, at_time))
            price_distance = MathAbs(ask - zBoundary);
        }
      else
        {
         double buy_dist = 0.0, sell_dist = 0.0;
         if(GetNearestBearishBoundary(sym, bid, zBoundary, zName, at_time))
            sell_dist = MathAbs(zBoundary - bid);
         if(GetNearestBullishBoundary(sym, ask, zBoundary, zName, at_time))
            buy_dist = MathAbs(ask - zBoundary);

         if(buy_dist > 0.0 && sell_dist > 0.0)
            price_distance = MathMin(buy_dist, sell_dist);
         else
            price_distance = MathMax(buy_dist, sell_dist);
        }

   if(price_distance <= 0.0)
      price_distance = 100.0 * point * 10;

   if(!m_excludeSpread)
     {
      long sp_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
      price_distance += (sp_pts * point);
     }

   double loss_per_lot = (price_distance / tick_size) * tick_val;
   double max_lot_by_risk = (loss_per_lot > 0.0) ? (max_risk_money / loss_per_lot) : 0.01;

   double margin_1_lot = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ask, margin_1_lot) || margin_1_lot <= 0.0)
     {
      long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(lev <= 0)
         lev = 100;
      double csz = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      margin_1_lot = (1.0 * csz * ask) / (double)lev;
     }

   double max_lot_by_margin = max_lot_by_risk;
   if(margin_1_lot > 0.0)
      max_lot_by_margin = (free_margin * 0.90) / margin_1_lot;

   double max_lot = MathMin(max_lot_by_risk, max_lot_by_margin);

   double lot_step       = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double min_lot        = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot_broker = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);

   if(lot_step > 0.0)
      max_lot = MathFloor(max_lot / lot_step) * lot_step;

   max_lot = MathMax(min_lot, MathMin(max_lot, max_lot_broker));
   int lot_digits = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step > 0.0 ? lot_step : 0.01)));

   return NormalizeDouble(max_lot, lot_digits);
  }

//+------------------------------------------------------------------+
//| Calculate Current Loss on Position                               |
//+------------------------------------------------------------------+
double CGuardrailsCore::CalculateCurrentLoss(double volume, string sym)
  {
   double cur_loss = m_position.Profit() + m_position.Swap();
   if(cur_loss >= 0.0)
     {
      double tick_sz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double pt       = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(tick_sz <= 0.0)
         tick_sz = pt;
      double tick_val = GetSymbolTickValue(sym);
      long   sp_pts   = SymbolInfoInteger(sym, SYMBOL_SPREAD);
      if(sp_pts <= 0)
        {
         double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
         double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         if(pt > 0 && ask > bid)
            sp_pts = (long)MathRound((ask - bid) / pt);
        }
      if(tick_sz > 0 && pt > 0)
         cur_loss = -((sp_pts * pt / tick_sz) * tick_val * volume);
     }
   return cur_loss;
  }

//+------------------------------------------------------------------+
//| Circuit Breaker Loss Cut                                         |
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckEmergencyLossCut(string sym)
  {
   ulong ticket = m_position.Ticket();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_risk_money = balance * (m_maxRiskPercent / 100.0);
   double volume = m_position.Volume();

   double current_profit = m_position.Profit() + m_position.Swap();

   if(current_profit <= -max_risk_money)
     {
      m_trade.SetAsyncMode(true);
      m_trade.PositionClose(ticket);
      TriggerGuardrailViolation(ticket, sym, volume, volume, current_profit, "1% Circuit Cut", "Emergency");
     }
  }

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Risk.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Risk.mqh
