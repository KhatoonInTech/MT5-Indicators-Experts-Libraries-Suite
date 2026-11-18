// Shared risk budget selection. Broker margin checks always use free margin.
#ifndef MARCO_RISK_CAPITAL_MQH
#define MARCO_RISK_CAPITAL_MQH
enum ENUM_MARCO_RISK_CAPITAL
  {
   RISK_CAPITAL_BALANCE,      // BALANCE
   RISK_CAPITAL_EQUITY,       // EQUITY
   RISK_CAPITAL_FREE_MARGIN,  // FREE_MARGIN
   RISK_CAPITAL_MARGIN        // MARGIN (currently used margin)
  };
class CMarcoRiskCapital
  {
private:
   static ENUM_MARCO_RISK_CAPITAL mode;
public:
   static bool Configure(ENUM_MARCO_RISK_CAPITAL selected)
     {
      if(selected<RISK_CAPITAL_BALANCE || selected>RISK_CAPITAL_MARGIN) return false;
      mode=selected; return true;
     }
   static string Name()
     {
      switch(mode)
        {
         case RISK_CAPITAL_BALANCE: return "BALANCE";
         case RISK_CAPITAL_EQUITY: return "EQUITY";
         case RISK_CAPITAL_FREE_MARGIN: return "FREE_MARGIN";
         case RISK_CAPITAL_MARGIN: return "MARGIN";
        }
      return "INVALID";
     }
   static double Positive(double value)
     { return MathIsValidNumber(value) && value>0.0 ? value : 0.0; }
   static double Select(double balance,double equity,double freeMargin,double margin)
     {
      switch(mode)
        {
         case RISK_CAPITAL_BALANCE: return Positive(balance);
         case RISK_CAPITAL_EQUITY: return Positive(equity);
         case RISK_CAPITAL_FREE_MARGIN: return Positive(freeMargin);
         case RISK_CAPITAL_MARGIN: return Positive(margin);
        }
      return 0.0;
     }
   static double LiveBase()
     {
      switch(mode)
        {
         case RISK_CAPITAL_BALANCE: return Positive(AccountInfoDouble(ACCOUNT_BALANCE));
         case RISK_CAPITAL_EQUITY: return Positive(AccountInfoDouble(ACCOUNT_EQUITY));
         case RISK_CAPITAL_FREE_MARGIN: return Positive(AccountInfoDouble(ACCOUNT_MARGIN_FREE));
         case RISK_CAPITAL_MARGIN: return Positive(AccountInfoDouble(ACCOUNT_MARGIN));
        }
      return 0.0;
     }
   static double Budget(double capital,double percent)
     {
      if(!MathIsValidNumber(capital) || capital<=0.0 ||
         !MathIsValidNumber(percent) || percent<=0.0 || percent>100.0) return 0.0;
      return Positive(capital*percent/100.0);
     }
  };
ENUM_MARCO_RISK_CAPITAL CMarcoRiskCapital::mode=RISK_CAPITAL_FREE_MARGIN;
#endif
