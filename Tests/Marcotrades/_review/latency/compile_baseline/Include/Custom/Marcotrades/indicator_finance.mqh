// Indicator-safe simulation estimates. No orders, EA services or network calls.
// Formulas: https://www.mql5.com/en/book/automation/symbols/symbols_margin
// Profit/margin can differ from broker-side tiered/custom calculations.
#ifndef MARCO_INDICATOR_FINANCE_MQH
#define MARCO_INDICATOR_FINANCE_MQH

class CMarcoIndicatorFinance
  {
private:
   string m_symbol;
   bool m_ready;
   ENUM_SYMBOL_CALC_MODE m_mode;
   double m_contract, m_tickSize, m_tickProfit, m_tickLoss;
   double m_buyRate, m_sellRate, m_initial, m_leverage;
   double m_marginBuyConversion, m_marginSellConversion;

   bool Fail(string message)
     {
      error = message;
      return false;
     }

   bool Positive(double value) { return MathIsValidNumber(value) && value > 0.0; }

   // Use metadata rather than symbol-name substrings so broker suffixes work.
   bool Exchange(const string from, const string to, bool cost, double &rate)
     {
      if(from == to) { rate = 1.0; return true; }
      for(int pass = 0; pass < 2; pass++)
        {
         bool selected = pass == 0;
         for(int i = 0; i < SymbolsTotal(selected); i++)
           {
            string symbol = SymbolName(i, selected);
            string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
            string quote = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
            bool direct = base == from && quote == to;
            bool inverse = base == to && quote == from;
            if(!direct && !inverse) continue;
            ENUM_SYMBOL_CALC_MODE mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
            if(mode != SYMBOL_CALC_MODE_FOREX && mode != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE) continue;
            if(!SymbolSelect(symbol, true)) continue;
            MqlTick tick;
            if(!SymbolInfoTick(symbol, tick) || !Positive(tick.bid) || !Positive(tick.ask)) continue;
            rate = direct ? (cost ? tick.ask : tick.bid) : 1.0 / (cost ? tick.bid : tick.ask);
            return Positive(rate);
           }
        }
      return false;
     }

   bool MarginConversion(bool buy, double &rate)
     {
      string margin = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_MARGIN);
      string account = AccountInfoString(ACCOUNT_CURRENCY);
      if(margin == "" || account == "") return false;
      if(Exchange(margin, account, buy, rate)) return true;
      // Tick values are already in deposit currency. For linear instruments
      // this also handles cent accounts without guessing currency multipliers.
      if(m_mode == SYMBOL_CALC_MODE_FUTURES || m_mode == SYMBOL_CALC_MODE_EXCH_FUTURES) return false;
      double profitRate = (buy ? m_tickLoss : m_tickProfit) / (m_tickSize * m_contract);
      if(!Positive(profitRate)) return false;
      if(margin == SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT))
        {
         rate = profitRate;
         return true;
        }
      if(margin == SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE))
        {
         MqlTick tick;
         if(!SymbolInfoTick(m_symbol, tick)) return false;
         rate = (buy ? tick.ask : tick.bid) * profitRate;
         return Positive(rate);
        }
      return false;
     }

public:
   string error;
   CMarcoIndicatorFinance() { m_ready = false; error = ""; }

   bool Prepare(string symbol)
     {
      m_ready = false;
      error = "";
      m_symbol = symbol;
      m_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
      switch(m_mode)
        {
         case SYMBOL_CALC_MODE_FOREX:
         case SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE:
         case SYMBOL_CALC_MODE_CFD:
         case SYMBOL_CALC_MODE_CFDLEVERAGE:
         case SYMBOL_CALC_MODE_CFDINDEX:
         case SYMBOL_CALC_MODE_EXCH_STOCKS:
         case SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX:
         case SYMBOL_CALC_MODE_FUTURES:
         case SYMBOL_CALC_MODE_EXCH_FUTURES: break;
         default: return Fail("Unsupported indicator calculation mode: " + EnumToString(m_mode));
        }
      m_contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      m_tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      m_tickProfit = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
      m_tickLoss = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      m_initial = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
      m_leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(!Positive(m_contract) || !Positive(m_tickSize)) return Fail("Contract size/tick size unavailable");
      // When profit currency equals deposit currency, exact linear tick value
      // follows from contract size; otherwise use broker conversion-aware values.
      bool futures = m_mode == SYMBOL_CALC_MODE_FUTURES || m_mode == SYMBOL_CALC_MODE_EXCH_FUTURES;
      if(!futures && SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT) == AccountInfoString(ACCOUNT_CURRENCY))
         m_tickProfit = m_tickLoss = m_contract * m_tickSize;
      if(!Positive(m_tickProfit) || !Positive(m_tickLoss)) return Fail("Deposit-currency tick values unavailable");
      double maintenance = 0.0;
      if(!SymbolInfoMarginRate(symbol, ORDER_TYPE_BUY, m_buyRate, maintenance) ||
         !SymbolInfoMarginRate(symbol, ORDER_TYPE_SELL, m_sellRate, maintenance) ||
         !MathIsValidNumber(m_buyRate) || !MathIsValidNumber(m_sellRate) || m_buyRate < 0 || m_sellRate < 0)
         return Fail("Broker margin rates unavailable");
      if((m_mode == SYMBOL_CALC_MODE_FOREX || m_mode == SYMBOL_CALC_MODE_CFDLEVERAGE) && !Positive(m_leverage))
         return Fail("Account leverage unavailable");
      if(futures && !Positive(m_initial)) return Fail("Initial futures margin unavailable");
      if(!MarginConversion(true, m_marginBuyConversion) || !MarginConversion(false, m_marginSellConversion))
         return Fail("Margin currency conversion unavailable");
      m_ready = true;
      return true;
     }

   bool Profit(ENUM_ORDER_TYPE side, string symbol, double volume, double opened, double closed, double &profit)
     {
      profit = 0.0;
      if(!m_ready || symbol != m_symbol || (side != ORDER_TYPE_BUY && side != ORDER_TYPE_SELL) ||
         !Positive(volume) || !MathIsValidNumber(opened) || !MathIsValidNumber(closed))
         return Fail("Invalid indicator profit calculation inputs");
      double change = (closed - opened) * (side == ORDER_TYPE_BUY ? 1.0 : -1.0);
      profit = change / m_tickSize * volume * (change >= 0 ? m_tickProfit : m_tickLoss);
      if(!MathIsValidNumber(profit)) return Fail("Invalid indicator profit estimate");
      return true;
     }

   bool Margin(ENUM_ORDER_TYPE side, string symbol, double volume, double price, double &margin)
     {
      margin = 0.0;
      if(!m_ready || symbol != m_symbol || (side != ORDER_TYPE_BUY && side != ORDER_TYPE_SELL) ||
         !Positive(volume) || !Positive(price)) return Fail("Invalid indicator margin calculation inputs");
      double base = 0.0;
      if(m_initial > 0)
        {
         base = volume * m_initial;
         if(m_mode == SYMBOL_CALC_MODE_FOREX || m_mode == SYMBOL_CALC_MODE_CFDLEVERAGE) base /= m_leverage;
        }
      else switch(m_mode)
        {
         case SYMBOL_CALC_MODE_FOREX: base = volume * m_contract / m_leverage; break;
         case SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE: base = volume * m_contract; break;
         case SYMBOL_CALC_MODE_CFD: base = volume * m_contract * price; break;
         case SYMBOL_CALC_MODE_CFDLEVERAGE: base = volume * m_contract * price / m_leverage; break;
         case SYMBOL_CALC_MODE_CFDINDEX:
           {
            // Remove deposit-currency conversion from the broker tick value
            // before converting the final margin exactly once.
            double profitConversion = m_tickProfit / (m_tickSize * m_contract);
            double tickInProfitCurrency = m_tickProfit / profitConversion;
            base = volume * m_contract * price * tickInProfitCurrency / m_tickSize;
            break;
           }
         case SYMBOL_CALC_MODE_EXCH_STOCKS:
         case SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX: base = volume * m_contract * price; break;
         case SYMBOL_CALC_MODE_FUTURES:
         case SYMBOL_CALC_MODE_EXCH_FUTURES: base = volume * m_initial; break;
         default: return Fail("Unsupported indicator margin mode");
        }
      margin = base * (side == ORDER_TYPE_BUY ? m_buyRate * m_marginBuyConversion : m_sellRate * m_marginSellConversion);
      if(!MathIsValidNumber(margin) || margin < 0) return Fail("Invalid indicator margin estimate");
      return true;
     }
  };

CMarcoIndicatorFinance g_marcoIndicatorFinance;

bool MarcoIndicatorCalcProfit(ENUM_ORDER_TYPE side, string symbol, double volume, double opened, double closed, double &profit)
  { return g_marcoIndicatorFinance.Profit(side, symbol, volume, opened, closed, profit); }
bool MarcoIndicatorCalcMargin(ENUM_ORDER_TYPE side, string symbol, double volume, double price, double &margin)
  { return g_marcoIndicatorFinance.Margin(side, symbol, volume, price, margin); }

// Engine destructors use generic drawing names even with drawings disabled.
// Suppress only those engine-side deletes; never erase another chart indicator.
bool MarcoSimulationObjectDelete(long chart, string name) { return true; }
int MarcoSimulationObjectsDeleteAll(long chart, string prefix, int window = -1, int type = -1) { return 0; }

#endif
