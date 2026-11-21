// Shared strategy pip convention and broker price-grid validation.
// A strategy pip is not necessarily the broker's minimum tradable tick.
#ifndef MARCO_SYMBOL_UNITS_MQH
#define MARCO_SYMBOL_UNITS_MQH

struct SMarcoSymbolUnits
  {
   int digits;
   double point, tick, pip;
  };

struct SMarcoPipOverride
  {
   string symbol;
   double pip;
  };

class CMarcoSymbolUnits
  {
private:
   static SMarcoPipOverride overrides[];
   static bool validConfig;

   static bool Matches(string name, string base)
     {
      int at=StringFind(name,base);
      if(at<0) return false;
      int end=at+StringLen(base);
      // Broker suffixes are allowed, but US500 must not also match US5000.
      if(end<StringLen(name))
        {
         ushort next=StringGetCharacter(name,end);
         if(next>='0' && next<='9') return false;
        }
      return true;
     }

   static double DefinedPip(string name)
     {
      // Fixed STRATEGY units, not a claim that every broker calls these a pip.
      // All 42 requested instruments are explicit and independent of digits.
      // Override a broker-specific convention with InpPipSizeOverrides.
      static string bases[]={
         "XAUUSD","XAGUSD","US30","US500","USTEC","USOIL","UKOIL","BTCUSD","ETHUSD","BCHUSD","SOLUSD","GER40",
         "AUS200","EU50","FRA40","HK50","JP225","N25","SPN35","US2000",
         "XAUAUD","XAUEUR","XAGAUD","XAGEUR","XPDUSD","XPTUSD","XCUUSD",
         "EURCZK","EURHUF","EURNOK","EURPLN","USDCZK","USDHKD","USDHUF","USDILS","USDMXN","USDNOK","USDPLN","USDSEK","USDZAR","USDSGD","USDCNH",
         "US100","DE30","DE40","FR40","STOXX50","XAUGBP","GOLD","SILVER"};
      static double sizes[]={
         .10,.01,1.0,.10,.10,.01,.01,.10,.10,.01,.01,1.0,
         .10,.10,.10,1.0,1.0,.10,1.0,.10,
         .10,.10,.01,.01,.10,.10,.01,
         .0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001,
         .10,1.0,1.0,.10,.10,.10,.10,.01};
      double pip=0.0; int longest=0;
      for(int i=0;i<ArraySize(bases);i++)
         if(StringLen(bases[i])>longest && Matches(name,bases[i]))
           { longest=StringLen(bases[i]); pip=sizes[i]; }
      return pip;
     }
public:
   static bool Configure(string settings)
     {
      validConfig=false; ArrayResize(overrides,0);
      StringTrimLeft(settings); StringTrimRight(settings);
      if(settings=="") { validConfig=true; return true; }
      string rows[];
      int count=StringSplit(settings,';',rows);
      for(int i=0;i<count;i++)
        {
         string pair[];
         if(StringSplit(rows[i],'=',pair)!=2) return ConfigError();
         StringTrimLeft(pair[0]); StringTrimRight(pair[0]); StringToUpper(pair[0]);
         StringTrimLeft(pair[1]); StringTrimRight(pair[1]);
         if(pair[0]=="" || pair[1]=="") return ConfigError();
         // Reject partial numeric parses such as 0.1abc, negatives and NaN.
         int dots=0, numbers=0;
         for(int c=0;c<StringLen(pair[1]);c++)
           {
            ushort ch=StringGetCharacter(pair[1],c);
            if(ch=='.') dots++;
            else if(ch>='0' && ch<='9') numbers++;
            else return ConfigError();
           }
         double pip=StringToDouble(pair[1]);
         if(dots>1 || numbers==0 || !MathIsValidNumber(pip) || pip<=0) return ConfigError();
         for(int n=0;n<ArraySize(overrides);n++)
            if(overrides[n].symbol==pair[0]) return ConfigError();
         int n=ArraySize(overrides); ArrayResize(overrides,n+1);
         overrides[n].symbol=pair[0]; overrides[n].pip=pip;
        }
      validConfig=true;
      Print("[PIP UNITS] Explicit strategy units with ",ArraySize(overrides)," custom pip definitions.");
      return true;
     }

   static bool ConfigError()
     {
      Print("[PIP CONFIG ERROR] Use unique SYMBOL=positive-price-size entries separated by semicolons, e.g. US500=0.1;XAUUSD=0.01");
      return false;
     }

   static bool Load(string symbol, SMarcoSymbolUnits &units)
     {
      units.digits=0; units.point=0.0; units.tick=0.0; units.pip=0.0;
      long digits=0;
      double point=0.0, tick=0.0;
      if(!validConfig || symbol == "" || !SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits) ||
         !SymbolInfoDouble(symbol, SYMBOL_POINT, point) ||
         !SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tick)) return false;
      if(digits < 0 || digits > 8 || !MathIsValidNumber(point) || point <= 0.0 ||
         !MathIsValidNumber(tick) || tick <= 0.0) return false;
      double decimalPoint=MathPow(10.0, -(int)digits);
      if(MathAbs(point-decimalPoint) > decimalPoint*1e-8) return false;
      double tickPoints=tick/point;
      if(!MathIsValidNumber(tickPoints) || tickPoints < 1.0-1e-8 ||
         tickPoints > 1e12 || MathAbs(tickPoints-MathRound(tickPoints)) > 1e-7) return false;

      string name=symbol;
      StringToUpper(name);
      double pip=DefinedPip(name);
      int longest=0;
      for(int i=0;i<ArraySize(overrides);i++)
         if(StringLen(overrides[i].symbol)>longest && Matches(name,overrides[i].symbol))
           { longest=StringLen(overrides[i].symbol); pip=overrides[i].pip; }
      // Legacy fallback only for instruments outside the explicit table/overrides.
      if(pip<=0) pip=(digits == 3 || digits == 5) ? point*10.0 : point;
      units.digits=(int)digits; units.point=point; units.tick=tick; units.pip=pip;
      return true;
     }

   static bool Buffer(double pips, double pip, double &distance)
     {
      distance=0.0;
      if(!MathIsValidNumber(pips) || pips < 0.0 ||
         !MathIsValidNumber(pip) || pip <= 0.0) return false;
      double value=pips*pip;
      if(!MathIsValidNumber(value) || (pips > 0.0 && value <= 0.0)) return false;
      distance=value;
      return true;
     }

   static double PipSize(string symbol)
     {
      SMarcoSymbolUnits units;
      return Load(symbol, units) ? units.pip : 0.0;
     }

   // Round BUY stops down and SELL stops up, never deliberately narrowing the buffer.
   // Snap only floating-point noise around an exact tick before directional rounding.
   static bool RoundStop(double rawPrice, bool buy, const SMarcoSymbolUnits &units, double &price)
     {
      price=0.0;
      if(!MathIsValidNumber(rawPrice) || rawPrice <= 0.0 ||
         !MathIsValidNumber(units.tick) || units.tick <= 0.0 ||
         units.digits < 0 || units.digits > 8) return false;
      double steps=rawPrice/units.tick;
      if(!MathIsValidNumber(steps) || steps <= 0.0 || steps > 1e12) return false;
      double nearest=MathRound(steps);
      double tolerance=MathMin(1e-4, 4.0*DBL_EPSILON*MathMax(1.0, MathAbs(steps)));
      if(MathAbs(steps-nearest) <= tolerance) steps=nearest;
      double whole=buy ? MathFloor(steps) : MathCeil(steps);
      double rounded=NormalizeDouble(whole*units.tick, units.digits);
      if(!MathIsValidNumber(rounded) || rounded <= 0.0) return false;
      double priceTolerance=MathMax(units.tick*1e-9, 4.0*DBL_EPSILON*MathAbs(rawPrice));
      if((buy && rounded > rawPrice+priceTolerance) ||
         (!buy && rounded < rawPrice-priceTolerance)) return false;
      if(MathAbs(rounded/units.tick-whole) > MathMax(1e-7, tolerance)) return false;
      price=rounded;
      return true;
     }

   static bool BufferedStop(string symbol, double reference, double pips, bool buy, double &price)
     {
      SMarcoSymbolUnits units;
      double distance=0.0;
      price=0.0;
      if(!Load(symbol, units) || !Buffer(pips, units.pip, distance) ||
         !MathIsValidNumber(reference) || reference <= 0.0) return false;
      double raw=buy ? reference-distance : reference+distance;
      // Reject a positive buffer too small to survive price arithmetic.
      if(distance > 0.0 && raw == reference) return false;
      if(!RoundStop(raw, buy, units, price)) return false;
      if(distance > 0.0 && (buy ? price >= reference : price <= reference)) return false;
      return true;
     }

   static bool StopPrice(string symbol, double rawPrice, bool buy, double &price)
     {
      SMarcoSymbolUnits units;
      price=0.0;
      return Load(symbol, units) && RoundStop(rawPrice, buy, units, price);
     }
  };
SMarcoPipOverride CMarcoSymbolUnits::overrides[];
bool CMarcoSymbolUnits::validConfig=true;
#endif
