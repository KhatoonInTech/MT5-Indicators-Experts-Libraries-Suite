//+------------------------------------------------------------------+
//|         Include\Guardrails\Guardrails_Core_Execution.mqh         |
//|             Role: Handles pre-trade Buy/Sell validation and      |
//|             automatic continuation trade execution.              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Execute Auto Trade Continuation                                  |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecuteAutoTrade(string sym, int direction)
  {
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double zBoundary = 0.0;
   string zName = "";
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   if(direction == 1)
     {
      if(!GetNearestBullishBoundary(sym, ask, zBoundary, zName))
         zBoundary = ask - (100 * point * 10);
      double sl = NormalizeDouble(zBoundary, digits);
      double lot = CalculateMaxAllowedLot(sym, 1);

      double req_margin = 0.0;
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(OrderCalcMargin(ORDER_TYPE_BUY, sym, lot, ask, req_margin) && req_margin > free_margin)
        {
         PrintFormat("🛑 AUTO BUY BLOCKED: Not enough free margin! Req: $%.2f | Free: $%.2f", req_margin, free_margin);
         return;
        }
      m_trade.SetAsyncMode(false);
      m_trade.Buy(lot, sym, ask, sl, 0.0, "Guardrail Safe Auto");
      PrintFormat("🚀 AUTO TRADE EXECUTED: BUY %.2f L on %s at %.5f (SL: %.5f)", lot, sym, ask, sl);
     }
   else
      if(direction == -1)
        {
         if(!GetNearestBearishBoundary(sym, bid, zBoundary, zName))
            zBoundary = bid + (100 * point * 10);
         double sl = NormalizeDouble(zBoundary, digits);
         double lot = CalculateMaxAllowedLot(sym, -1);

         double req_margin = 0.0;
         double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(OrderCalcMargin(ORDER_TYPE_SELL, sym, lot, bid, req_margin) && req_margin > free_margin)
           {
            PrintFormat("🛑 AUTO SELL BLOCKED: Not enough free margin! Req: $%.2f | Free: $%.2f", req_margin, free_margin);
            return;
           }
         m_trade.SetAsyncMode(false);
         m_trade.Sell(lot, sym, bid, sl, 0.0, "Guardrail Safe Auto");
         PrintFormat("🚀 AUTO TRADE EXECUTED: SELL %.2f L on %s at %.5f (SL: %.5f)", lot, sym, bid, sl);
        }
  }

//+------------------------------------------------------------------+
//| Pre-Trade Buy                                                    |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecutePreTradeBuy()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockLongsInBearish && IsInBearishZone(ask, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, false);
      Print("🛑 BUY BLOCKED: Price is currently inside a Bearish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBullishBoundary(_Symbol, ask, zBoundary, zName))
      zBoundary = ask - (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_buy = CalculateMaxAllowedLot(_Symbol, 1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_buy : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_buy)
     {
      double oversize = lot_to_trade - max_safe_buy;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 BUY BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_buy));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot_to_trade, ask, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 BUY BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Buy(lot_to_trade, _Symbol, ask, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

//+------------------------------------------------------------------+
//| Pre-Trade Sell                                                   |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecutePreTradeSell()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockShortsInBullish && IsInBullishZone(bid, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, true);
      Print("🛑 SELL BLOCKED: Price is currently inside a Bullish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBearishBoundary(_Symbol, bid, zBoundary, zName))
      zBoundary = bid + (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_sell = CalculateMaxAllowedLot(_Symbol, -1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_sell : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_sell)
     {
      double oversize = lot_to_trade - max_safe_sell;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 SELL BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_sell));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lot_to_trade, bid, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 SELL BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Sell(lot_to_trade, _Symbol, bid, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Execution.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Execution.mqh
