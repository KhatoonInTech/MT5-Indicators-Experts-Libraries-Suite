//+------------------------------------------------------------------+
//|                                     PropFirmAccountHelper.mqh    |
//|                 Prop Firm & Safe Capital Risk Management Helper  |
//|                 Dynamic Capital Sizing & Asset-Class Lot Caps    |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.00"
#property strict

#ifndef PROPFIRM_ACCOUNT_HELPER_MQH
#define PROPFIRM_ACCOUNT_HELPER_MQH

enum ENUM_ACCOUNT_TYPE
  {
   ACCOUNT_PERSONAL,   // Personal Capital
   ACCOUNT_PROP_FIRM   // Prop Firm
  };

enum ENUM_PROP_ASSET_CLASS
  {
   PROP_ASSET_FOREX,
   PROP_ASSET_METALS,
   PROP_ASSET_INDICES,
   PROP_ASSET_COMMODITIES,
   PROP_ASSET_CRYPTO
  };

struct SPropFirmData
  {
   double            maxDailyLoss;       // InpMaxDailyLoss
   double            maxLoss;            // InpMaxLoss
   double            profitTarget;       // InpProfitTarget
   double            maxLotMetals;       // InpMaxLotMetals
   double            maxLotIndicies;     // InpMaxLotIndicies
   double            maxLotForex;        // InpMaxLotForex
   double            maxLotCommodities;  // InpMaxLotCommodities
   string            serverApiUrl;       // Optional remote server endpoint
  };

//+------------------------------------------------------------------+
//| Helper Class: CPropFirmAccountHelper                             |
//+------------------------------------------------------------------+
class CPropFirmAccountHelper
  {
public:
   //+------------------------------------------------------------------+
   //| Classify symbol into respective asset category                   |
   //+------------------------------------------------------------------+
   static ENUM_PROP_ASSET_CLASS DetectAssetClass(string sym)
     {
      string upper = sym;
      StringToUpper(upper);

      // Metals
      if(StringFind(upper, "XAU") >= 0 || StringFind(upper, "GOLD") >= 0 ||
         StringFind(upper, "XAG") >= 0 || StringFind(upper, "SILVER") >= 0 ||
         StringFind(upper, "XPT") >= 0 || StringFind(upper, "XPD") >= 0)
         return PROP_ASSET_METALS;

      // Indices
      if(StringFind(upper, "US30") >= 0 || StringFind(upper, "DJI") >= 0 || StringFind(upper, "WS30") >= 0 ||
         StringFind(upper, "US500") >= 0 || StringFind(upper, "SPX500") >= 0 || StringFind(upper, "SP500") >= 0 ||
         StringFind(upper, "USTEC") >= 0 || StringFind(upper, "NAS100") >= 0 || StringFind(upper, "NDX") >= 0 ||
         StringFind(upper, "GER30") >= 0 || StringFind(upper, "GER40") >= 0 || StringFind(upper, "DAX") >= 0 ||
         StringFind(upper, "UK100") >= 0 || StringFind(upper, "JP225") >= 0 || StringFind(upper, "HK50") >= 0)
         return PROP_ASSET_INDICES;

      // Commodities / Energies
      if(StringFind(upper, "USOIL") >= 0 || StringFind(upper, "UKOIL") >= 0 ||
         StringFind(upper, "WTI") >= 0 || StringFind(upper, "BRENT") >= 0 ||
         StringFind(upper, "CRUDE") >= 0 || StringFind(upper, "OIL") >= 0 ||
         StringFind(upper, "NGAS") >= 0 || StringFind(upper, "GAS") >= 0 || StringFind(upper, "COPPER") >= 0)
         return PROP_ASSET_COMMODITIES;

      // Crypto
      if(StringFind(upper, "BTC") >= 0 || StringFind(upper, "ETH") >= 0 ||
         StringFind(upper, "SOL") >= 0 || StringFind(upper, "XRP") >= 0 ||
         StringFind(upper, "LTC") >= 0 || StringFind(upper, "CRYPTO") >= 0)
         return PROP_ASSET_CRYPTO;

      return PROP_ASSET_FOREX;
     }

   //+------------------------------------------------------------------+
   //| Fetch Prop Firm Server Metrics on every trade check              |
   //+------------------------------------------------------------------+
   static bool       FetchPropFirmServerData(SPropFirmData &data)
     {
      // 1. Sync from Prop Firm Bridge GlobalVariables if available
      if(GlobalVariableCheck("PROP_MaxDailyLoss"))
         data.maxDailyLoss = GlobalVariableGet("PROP_MaxDailyLoss");
      if(GlobalVariableCheck("PROP_MaxLoss"))
         data.maxLoss = GlobalVariableGet("PROP_MaxLoss");
      if(GlobalVariableCheck("PROP_ProfitTarget"))
         data.profitTarget = GlobalVariableGet("PROP_ProfitTarget");
      if(GlobalVariableCheck("PROP_MaxLotMetals"))
         data.maxLotMetals = GlobalVariableGet("PROP_MaxLotMetals");
      if(GlobalVariableCheck("PROP_MaxLotIndicies"))
         data.maxLotIndicies = GlobalVariableGet("PROP_MaxLotIndicies");
      if(GlobalVariableCheck("PROP_MaxLotForex"))
         data.maxLotForex = GlobalVariableGet("PROP_MaxLotForex");
      if(GlobalVariableCheck("PROP_MaxLotCommodities"))
         data.maxLotCommodities = GlobalVariableGet("PROP_MaxLotCommodities");

      // 2. Query Prop Firm REST API endpoint if configured
      if(data.serverApiUrl != "" && StringFind(data.serverApiUrl, "http") == 0)
        {
         char post_data[], result_data[];
         string result_headers;
         string headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
         ResetLastError();
         int res = WebRequest("GET", data.serverApiUrl, headers, 3000, post_data, result_data, result_headers);
         if(res == 200)
           {
            string json = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
            double v = ExtractJsonDouble(json, "\"max_daily_loss\":");
            if(v > 0)
               data.maxDailyLoss = v;
            v = ExtractJsonDouble(json, "\"max_loss\":");
            if(v > 0)
               data.maxLoss = v;
            v = ExtractJsonDouble(json, "\"profit_target\":");
            if(v > 0)
               data.profitTarget = v;
            v = ExtractJsonDouble(json, "\"max_lot_metals\":");
            if(v > 0)
               data.maxLotMetals = v;
            v = ExtractJsonDouble(json, "\"max_lot_indices\":");
            if(v > 0)
               data.maxLotIndicies = v;
            v = ExtractJsonDouble(json, "\"max_lot_forex\":");
            if(v > 0)
               data.maxLotForex = v;
            v = ExtractJsonDouble(json, "\"max_lot_commodities\":");
            if(v > 0)
               data.maxLotCommodities = v;

            PrintFormat("📡 [PROP SERVER SYNC] DailyLoss: $%.2f | MaxLoss: $%.2f | Target: $%.2f",
                        data.maxDailyLoss, data.maxLoss, data.profitTarget);
            return true;
           }
        }

      return true;
     }

   //+------------------------------------------------------------------+
   //| Calculate Base / Effective Capital for Risk Evaluation           |
   //+------------------------------------------------------------------+
   static double     GetEffectiveCapital(ENUM_ACCOUNT_TYPE accType,
                                     double currentBalance,
                                     bool useSafeCapital,
                                     double safeCapital,
                                     double maxDailyLoss,
                                     double maxLoss)
     {
      double baseCapital = currentBalance;

      if(accType == ACCOUNT_PROP_FIRM)
        {
         // Consider Min(InpMaxDailyLoss, InpMaxLoss) as base capital
         baseCapital = MathMin(maxDailyLoss, maxLoss);
         if(baseCapital <= 0.0)
            baseCapital = currentBalance;

         // If InpUseSafeCapital is active, cap further by InpSafeCapital
         if(useSafeCapital && safeCapital > 0.0)
            baseCapital = MathMin(baseCapital, safeCapital);
        }
      else // Personal Capital
        {
         if(useSafeCapital && safeCapital > 0.0)
            baseCapital = safeCapital;
         else
            baseCapital = currentBalance;
        }

      return (baseCapital > 0.0) ? baseCapital : currentBalance;
     }

   //+------------------------------------------------------------------+
   //| Enforce Prop Firm Asset Class Max Lot Limits                     |
   //+------------------------------------------------------------------+
   static double     ClampLotByAssetClass(string sym, double calculatedLot, const SPropFirmData &propData, ENUM_ACCOUNT_TYPE accType)
     {
      if(accType != ACCOUNT_PROP_FIRM)
         return calculatedLot;

      ENUM_PROP_ASSET_CLASS aClass = DetectAssetClass(sym);
      double maxAllowed = calculatedLot;

      switch(aClass)
        {
         case PROP_ASSET_METALS:
            if(propData.maxLotMetals > 0.0)
               maxAllowed = MathMin(calculatedLot, propData.maxLotMetals);
            break;
         case PROP_ASSET_INDICES:
            if(propData.maxLotIndicies > 0.0)
               maxAllowed = MathMin(calculatedLot, propData.maxLotIndicies);
            break;
         case PROP_ASSET_FOREX:
            if(propData.maxLotForex > 0.0)
               maxAllowed = MathMin(calculatedLot, propData.maxLotForex);
            break;
         case PROP_ASSET_COMMODITIES:
            if(propData.maxLotCommodities > 0.0)
               maxAllowed = MathMin(calculatedLot, propData.maxLotCommodities);
            break;
         default:
            break;
        }

      double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      if(minLot <= 0.0)
         minLot = 0.01;

      return MathMax(minLot, maxAllowed);
     }

private:
   static double     ExtractJsonDouble(string &src, string key)
     {
      int kPos = StringFind(src, key);
      if(kPos == -1)
         return 0.0;
      int start = kPos + StringLen(key);
      int comma = StringFind(src, ",", start);
      int brace = StringFind(src, "}", start);
      int end = (comma != -1 && comma < brace) ? comma : brace;
      if(end == -1)
         return 0.0;
      return StringToDouble(StringSubstr(src, start, end - start));
     }
  };

#endif
//+------------------------------------------------------------------+
// END FILE: Include\Custom\Marcotrades\PropFirmAccountHelper.mqh

// END FILE: Include\Custom\General\PropFirmAccountHelper.mqh
