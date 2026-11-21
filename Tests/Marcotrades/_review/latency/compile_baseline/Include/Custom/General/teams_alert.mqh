//+------------------------------------------------------------------+
//|                                   Include/ZigZag/teams_alert.mqh |
//|                                      MS Teams Alerting Framework |
//+------------------------------------------------------------------+
#property copyright "Pine Script Translated"
#property version   "1.25"

// =========================================================================
// SAFE STANDALONE CLEAN SYMBOL PREPROCESSOR GUARD
// =========================================================================
#ifndef CLEAN_SYMBOL_FN
#define CLEAN_SYMBOL_FN
string CleanSymbol(string sym)
  {
   int len = StringLen(sym);
   if(len > 1 && StringSubstr(sym, len - 1, 1) == "m")
     {
      return StringSubstr(sym, 0, len - 1);
     }
   return sym;
  }
#endif

#define ALERTS_TEAMS_URL "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/25fe6d73be614334a9bd8ef29d1891e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=k5tAEUvI0fEXLjQyDiec16wMaSlUli1F2l1fbNWQ-jw"
#define DAILY_REPORT_TEAMS_URL "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/b9349d8a045143fbad8a424902de7df4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=CvyDW3vxyW7_3LBamn8eGwPqyXaOgvDhsRwMf1dhRqY"

#include <Arrays\ArrayInt.mqh>
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\poc_analyzer.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\entry_model.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mq5_dashboard.mqh"

// =============================================================================
// STRUCTURE FOR ORDER BLOCK / POI SIGNAL DATA
// =============================================================================
struct OBAnalysis
  {
   double            zoneHigh;
   double            zoneLow;
   long              zoneCreatedTime;
   int               touchCount;
   bool              isFresh;
   bool              isPreviouslyMitigated;

   string            trendBias;
   string            marketStructureType;
   bool              bosDetected;
   bool              chochDetected;
   datetime          lastBosTime;
   string            lastBosType;

   long              tickVolume;
   long              realVolume;
   long              cumulativeVolume;

   double            zzReversalPrice;
   double            zzPriorReversalPrice;
   double            zzPriceChange;
   string            zzDirection;

   int               setupQuality;
   string            recommendation;
   string            reasoning;
   string            zoneLabel;

   int               maxLookbackBars;
   double            deviationInput;
   int               depthInput;

   double            slPrice;
   double            tpPrice;
   double            estLoss;
   double            estProfit;
  };

struct AlertTask
  {
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   string            obType;
   OBAnalysis        oa;
  };

// =============================================================================
// HELPER FUNCTION
// =============================================================================
string GetTVInterval(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
         return "1";
      case PERIOD_M5:
         return "5";
      case PERIOD_M15:
         return "15";
      case PERIOD_M30:
         return "30";
      case PERIOD_H1:
         return "60";
      case PERIOD_H4:
         return "240";
      case PERIOD_D1:
         return "D";
      case PERIOD_W1:
         return "W";
      default:
         return "60";
     }
  }

// =============================================================================
// BACKTEST METRICS DATA STRUCTURES
// =============================================================================
class ZoneStats
  {
public:
   int               success;
   int               fail;
   int               pending;

   CArrayInt         successScores;
   CArrayInt         failScores;

   CArrayInt         p1_success, p2_success, p3_success, p4_success, p5_success, p6_success, p7_success, p8_success, p9_success;
   CArrayInt         p1_fail, p2_fail, p3_fail, p4_fail, p5_fail, p6_fail, p7_fail, p8_fail, p9_fail;

                     ZoneStats() { Init(); }
   void              Init()
     {
      success = 0;
      fail = 0;
      pending = 0;
      successScores.Clear();
      failScores.Clear();
      p1_success.Clear();
      p2_success.Clear();
      p3_success.Clear();
      p4_success.Clear();
      p5_success.Clear();
      p6_success.Clear();
      p7_success.Clear();
      p8_success.Clear();
      p9_success.Clear();
      p1_fail.Clear();
      p2_fail.Clear();
      p3_fail.Clear();
      p4_fail.Clear();
      p5_fail.Clear();
      p6_fail.Clear();
      p7_fail.Clear();
      p8_fail.Clear();
      p9_fail.Clear();
     }

   double            Ratio()
     {
      int total = success + fail;
      if(total == 0)
         return 0.0;
      return ((double)success / total) * 100.0;
     }

   void              RecordSuccess(PoCResult &poc)
     {
      success++;
      successScores.Add(poc.finalScore);
      p1_success.Add(poc.p1_score);
      p2_success.Add(poc.p2_score);
      p3_success.Add(poc.p3_score);
      p4_success.Add(poc.p4_score);
      p5_success.Add(poc.p5_score);
      p6_success.Add(poc.p6_score);
      p7_success.Add(poc.p7_score);
      p8_success.Add(poc.p8_score);
      p9_success.Add(poc.p9_score);
     }

   void              RecordFail(PoCResult &poc)
     {
      fail++;
      failScores.Add(poc.finalScore);
      p1_fail.Add(poc.p1_score);
      p2_fail.Add(poc.p2_score);
      p3_fail.Add(poc.p3_score);
      p4_fail.Add(poc.p4_score);
      p5_fail.Add(poc.p5_score);
      p6_fail.Add(poc.p6_score);
      p7_fail.Add(poc.p7_score);
      p8_fail.Add(poc.p8_score);
      p9_fail.Add(poc.p9_score);
     }

   void              RecordPending() { pending++; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class BacktestMetrics
  {
public:
   ZoneStats         demand;
   ZoneStats         supply;
   ZoneStats         bullPOI;
   ZoneStats         bearPOI;
   ZoneStats         bullOB;
   ZoneStats         bearOB;
   ZoneStats         demandFlip;
   ZoneStats         supplyFlip;
   ZoneStats         bullBreaker;
   ZoneStats         bearBreaker;

                     BacktestMetrics() { Init(); }
   void              Init()
     {
      demand.Init();
      supply.Init();
      bullPOI.Init();
      bearPOI.Init();
      bullOB.Init();
      bearOB.Init();
      demandFlip.Init();
      supplyFlip.Init();
      bullBreaker.Init();
      bearBreaker.Init();
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string FormatZoneAge(long createdTime)
  {
   long elapsed = (long)TimeCurrent() - createdTime;
   long hours   = elapsed / 3600;
   long mins    = (elapsed % 3600) / 60;
   if(hours > 0)
      return IntegerToString(hours) + "h " + IntegerToString(mins) + "m ago";
   return IntegerToString(mins) + "m ago";
  }

// =============================================================================
// GENERATE EXPANDABLE DETAIL CARD BODY
// =============================================================================
string GenerateOBDetailedReport(string symbol, ENUM_TIMEFRAMES tf, string obType, OBAnalysis &oa)
  {
   string cleanSym = CleanSymbol(symbol);
   string tfStr    = StringSubstr(EnumToString(tf), 7);
   string ts       = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   int    digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pipSize  = (digits == 3 || digits == 5) ? point * 10.0 : point;

   string report = "";

   string headerStyle = (obType == "BULLISH") ? "good" : "attention";
   report += "{\"type\":\"Container\",\"style\":\"" + headerStyle + "\",\"bleed\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"📊 " + oa.zoneLabel + " ANALYSIS — " + cleanSym + " " + tfStr + "\",";
   report +=     "\"weight\":\"Bolder\",\"size\":\"Medium\",\"horizontalAlignment\":\"Center\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"⭐ Quality: " + IntegerToString(oa.setupQuality) + "/100  |  " +
             oa.recommendation + "\",\"horizontalAlignment\":\"Center\",\"size\":\"Small\"}";
   report += "]},";

   string mitigationText = oa.isFresh
                           ? "✅ FRESH (0 touches)"
                           : (oa.isPreviouslyMitigated
                              ? "❌ MITIGATED (" + IntegerToString(oa.touchCount) + "×)"
                              : "⚠️ TESTED (" + IntegerToString(oa.touchCount) + "×)");

   string bosLabel = oa.bosDetected ? "BOS" : (oa.chochDetected ? "CHoCH" : "—");
   string bosTime  = (oa.bosDetected || oa.chochDetected)
                     ? bosLabel + " · " + TimeToString(oa.lastBosTime, TIME_MINUTES)
                     : "None detected";

   report += "{\"type\":\"Container\",\"style\":\"accent\",\"bleed\":true,\"spacing\":\"Medium\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"🧱 ZONE DETAIL\",\"weight\":\"Bolder\",\"size\":\"Medium\",\"spacing\":\"None\"},";
   report += "{\"type\":\"ColumnSet\",\"columns\":[";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Zone Age\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + FormatZoneAge(oa.zoneCreatedTime) + "\",\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Mitigation Status\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + mitigationText + "\",\"wrap\":true,\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Recent BOS / CHoCH\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + bosTime + "\",\"wrap\":true,\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]}]}]},";

   report += "{\"type\":\"Container\",\"style\":\"warning\",\"bleed\":true,\"spacing\":\"Medium\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"📊 VOLUME\",\"weight\":\"Bolder\",\"size\":\"Medium\",\"spacing\":\"None\"},";
   report += "{\"type\":\"ColumnSet\",\"columns\":[";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Tick Volume\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + IntegerToString(oa.tickVolume) + "\",\"size\":\"Large\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Real Volume\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + IntegerToString(oa.realVolume) + "\",\"size\":\"Large\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Cumulative Vol (ZZ)\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + IntegerToString(oa.cumulativeVolume) + "\",\"size\":\"Large\",\"color\":\"Warning\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]}]}]},";

   double changePips = MathAbs(oa.zzPriceChange) / pipSize;
   string changeArrow = (oa.zzDirection == "UP") ? "▲ +" : "▼ -";
   string changeColor = (oa.zzDirection == "UP") ? "Good" : "Attention";

   report += "{\"type\":\"Container\",\"style\":\"" + headerStyle + "\",\"bleed\":true,\"spacing\":\"Medium\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"〰️ ZIGZAG REVERSALS\",\"weight\":\"Bolder\",\"size\":\"Medium\",\"spacing\":\"None\"},";
   report += "{\"type\":\"ColumnSet\",\"columns\":[";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Reversal Price\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + DoubleToString(oa.zzReversalPrice, digits) + "\",";
   report +=     "\"size\":\"Large\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Prior Reversal\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + DoubleToString(oa.zzPriorReversalPrice, digits) + "\",";
   report +=     "\"size\":\"Large\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Price Change\",\"weight\":\"Bolder\",\"size\":\"Small\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + changeArrow + DoubleToString(changePips, 1) + " pips\",";
   report +=     "\"size\":\"Large\",\"color\":\"" + changeColor + "\",\"weight\":\"Bolder\",\"spacing\":\"None\",\"horizontalAlignment\":\"Center\"}";
   report += "]}]}]},";

   report += "{\"type\":\"Container\",\"bleed\":true,\"spacing\":\"Medium\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"⚙️ ALGO SETTINGS\",\"weight\":\"Bolder\",\"size\":\"Medium\",\"spacing\":\"None\"},";
   report += "{\"type\":\"ColumnSet\",\"columns\":[";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Lookback\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + IntegerToString(oa.maxLookbackBars) + " Bars\",\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Deviation\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + DoubleToString(oa.deviationInput, 2) + "%\",\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]},";

   report += "{\"type\":\"Column\",\"width\":\"stretch\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"Depth\",\"weight\":\"Bolder\",\"size\":\"Small\",\"color\":\"Accent\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + IntegerToString(oa.depthInput) + "\",\"size\":\"Small\",\"spacing\":\"None\"}";
   report += "]}]}]},";

   report += "{\"type\":\"Container\",\"bleed\":true,\"spacing\":\"Medium\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"🧩 POINTS OF CONFLUENCE\",\"weight\":\"Bolder\",\"size\":\"Medium\",\"spacing\":\"None\"},";
   report += "{\"type\":\"TextBlock\",\"text\":\"" + oa.reasoning + "\",\"wrap\":true,\"size\":\"Small\"}";
   report += "]},";

   report += "{\"type\":\"Container\",\"style\":\"accent\",\"bleed\":true,\"spacing\":\"Small\",\"separator\":true,\"items\":[";
   report += "{\"type\":\"TextBlock\",\"text\":\"🕐 " + ts + " | 💾 " + cleanSym + "_SMC_Report.txt\",";
   report +=     "\"size\":\"Small\",\"horizontalAlignment\":\"Center\"}";
   report += "]}";

   return report;
  }

// =============================================================================
// MAIN SEND FUNCTION — ALERTS
// =============================================================================
void SendOBAlert(string symbol, ENUM_TIMEFRAMES tf, string obType, OBAnalysis &oa, string WebhookURL)
  {
   if(WebhookURL == "" || StringFind(WebhookURL, "http") < 0)
     {
      Print("Alert generated but Webhook URL is invalid.");
      return;
     }

   string cleanSym = CleanSymbol(symbol);
   string tfStr   = StringSubstr(EnumToString(tf), 7);
   int    digits  = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pipSize = (digits == 3 || digits == 5) ? point * 10.0 : point;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double spread = (ask - bid) / pipSize;
   double zoneSizePips = (oa.zoneHigh - oa.zoneLow) / pipSize;

   string accCurr   = AccountInfoString(ACCOUNT_CURRENCY);
   string slStr     = DoubleToString(oa.slPrice, digits);
   string tpStr     = DoubleToString(oa.tpPrice, digits);
   string lossStr   = "-" + DoubleToString(oa.estLoss, 2) + " " + accCurr;
   string profitStr = "+" + DoubleToString(oa.estProfit, 2) + " " + accCurr;

   double entryPx = (obType == "BULLISH") ? ask : bid;
   CDashboardAPI::SendAlert(symbol, tf, obType, oa.zoneLabel, entryPx, oa.slPrice, oa.tpPrice, oa.setupQuality, oa.recommendation, oa.reasoning);

   string reportContent = GenerateOBDetailedReport(symbol, tf, obType, oa);
   string headerStyle   = (obType == "BULLISH") ? "good"    : "attention";
   string dirEmoji      = (obType == "BULLISH") ? "📈"      : "📉";
   string eventLabel    = obType + " " + oa.zoneLabel + " TOUCHED";
   string chartURL      = "https://www.tradingview.com/chart/?symbol=" + cleanSym + "&interval=" + GetTVInterval(tf);

   string msg = "{\n"
                "  \"type\": \"message\",\n"
                "  \"attachments\":[\n"
                "    {\n"
                "      \"contentType\": \"application/vnd.microsoft.card.adaptive\",\n"
                "      \"content\": {\n"
                "        \"$schema\": \"http://adaptivecards.io/schemas/adaptive-card.json\",\n"
                "        \"type\": \"AdaptiveCard\",\n"
                "        \"version\": \"1.4\",\n"
                "        \"msteams\": { \"width\": \"full\" },\n"
                "        \"body\":[\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"" + headerStyle + "\",\n"
          "            \"bleed\": true,\n"
          "            \"items\":[\n"
          "              {\n"
          "                \"type\": \"ColumnSet\",\n"
          "                \"columns\":[\n"
          "                  { \"type\": \"Column\", \"width\": \"auto\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"" + dirEmoji + "\", \"size\": \"ExtraLarge\", \"weight\": \"Bolder\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"" + cleanSym + " | " + tfStr + "\", \"weight\": \"Bolder\", \"size\": \"ExtraLarge\" }, { \"type\": \"TextBlock\", \"text\": \"" + eventLabel + "\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"auto\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"⭐ " + IntegerToString(oa.setupQuality) + "/100\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"color\": \"Warning\", \"horizontalAlignment\": \"Right\" } ] }\n"
          "                ]\n"
          "              }\n"
          "            ]\n"
          "          },\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"accent\",\n"
          "            \"bleed\": true,\n"
          "            \"spacing\": \"Medium\",\n"
          "            \"items\":[\n"
          "              { \"type\": \"TextBlock\", \"text\": \"💰 CURRENT PRICE\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\" },\n"
          "              {\n"
          "                \"type\": \"ColumnSet\",\n"
          "                \"columns\":[\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Bid\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(bid, digits) + "\", \"size\": \"Large\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Ask\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ask, digits) + "\", \"size\": \"Large\", \"color\": \"Attention\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Spread\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(spread, 1) + " pips\", \"size\": \"Large\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] }\n"
          "                ]\n"
          "              }\n"
          "            ]\n"
          "          },\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"" + headerStyle + "\",\n"
          "            \"bleed\": true,\n"
          "            \"spacing\": \"Medium\",\n"
          "            \"separator\": true,\n"
          "            \"items\":[\n"
          "              { \"type\": \"TextBlock\", \"text\": \"🎯 ZONE RANGE\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\" },\n"
          "              {\n"
          "                \"type\": \"ColumnSet\",\n"
          "                \"columns\":[\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Zone High\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(oa.zoneHigh, digits) + "\", \"size\": \"Large\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Zone Low\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(oa.zoneLow, digits) + "\", \"size\": \"Large\", \"color\": \"Attention\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Zone Size\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + DoubleToString(zoneSizePips, 1) + " pips\", \"size\": \"Large\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] }\n"
          "                ]\n"
          "              }\n"
          "            ]\n"
          "          },\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"default\",\n"
          "            \"bleed\": true,\n"
          "            \"spacing\": \"Medium\",\n"
          "            \"separator\": true,\n"
          "            \"items\":[\n"
          "              { \"type\": \"TextBlock\", \"text\": \"⚖️ TRADE SETUP (1:2 R:R)\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\" },\n"
          "              {\n"
          "                \"type\": \"ColumnSet\",\n"
          "                \"columns\":[\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Stop Loss (3 pips buf)\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + slStr + "\", \"size\": \"Large\", \"color\": \"Attention\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Take Profit\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + tpStr + "\", \"size\": \"Large\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] }\n"
          "                ]\n"
          "              },\n"
          "              {\n"
          "                \"type\": \"ColumnSet\",\n"
          "                \"spacing\": \"Small\",\n"
          "                \"columns\":[\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Est. Loss (1 Lot)\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + lossStr + "\", \"size\": \"Medium\", \"color\": \"Attention\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] },\n"
          "                  { \"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\":[ { \"type\": \"TextBlock\", \"text\": \"Est. Profit (1 Lot)\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\" }, { \"type\": \"TextBlock\", \"text\": \"" + profitStr + "\", \"size\": \"Medium\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\" } ] }\n"
          "                ]\n"
          "              }\n"
          "            ]\n"
          "          },\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"default\",\n"
          "            \"bleed\": true,\n"
          "            \"spacing\": \"Medium\",\n"
          "            \"separator\": true,\n"
          "            \"items\":[\n"
          "              { \"type\": \"TextBlock\", \"text\": \"💡 **Verdict:** " + oa.recommendation + "\", \"wrap\": true, \"size\": \"Medium\", \"weight\": \"Bolder\", \"color\": \"Accent\" }\n"
          "            ]\n"
          "          }\n"
          "        ],\n"
          "        \"actions\":[\n"
          "          { \"type\": \"Action.ShowCard\", \"title\": \"📄 View Analysis Report\", \"card\": { \"type\": \"AdaptiveCard\", \"body\":[\n" + reportContent + "\n          ] } },\n"
          "          { \"type\": \"Action.OpenUrl\", \"title\": \"📊 View Chart\", \"url\": \"" + chartURL + "\" }\n"
          "        ]\n"
          "      }\n"
          "    }\n"
          "  ]\n"
          "}";

   char data[], result[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";
   ArrayResize(data, StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);

   int res = WebRequest("POST", WebhookURL, headers, 10000, data, result, result_headers);
   if(res >= 200 && res <= 299)
      Print("+++ ✅ SMC alert sent: ", cleanSym, " ", obType);
   else
      Print("--- ❌ WebRequest failed: ", res, " | ", CharArrayToString(result));
  }

// =============================================================================
// MAIN SEND FUNCTION — SWING POI PROXIMITY CSV BATCH ALERT
// =============================================================================
void SendSwingPOIBatchTeamsAlert(int count, double maxPips, string fileLink, string WebhookURL = ALERTS_TEAMS_URL)
  {
   if(WebhookURL == "" || StringFind(WebhookURL, "http") < 0 || count <= 0)
      return;

   string msg = "{\n"
                "  \"type\": \"message\",\n"
                "  \"attachments\":[\n"
                "    {\n"
                "      \"contentType\": \"application/vnd.microsoft.card.adaptive\",\n"
                "      \"content\": {\n"
                "        \"$schema\": \"http://adaptivecards.io/schemas/adaptive-card.json\",\n"
                "        \"type\": \"AdaptiveCard\",\n"
                "        \"version\": \"1.4\",\n"
                "        \"msteams\": { \"width\": \"full\" },\n"
                "        \"body\":[\n";

   msg += "          {\n"
          "            \"type\": \"Container\",\n"
          "            \"style\": \"good\",\n"
          "            \"bleed\": true,\n"
          "            \"items\":[\n"
          "              {\n"
          "                \"type\": \"TextBlock\",\n"
          "                \"text\":\"🎯 SWING POI PROXIMITY SWEEP\",\n"
          "                \"weight\": \"Bolder\",\n"
          "                \"size\": \"Large\",\n"
          "                \"horizontalAlignment\": \"Center\"\n"
          "              }\n"
          "            ]\n"
          "          },\n";

   msg += "          {\n"
          "            \"type\": \"FactSet\",\n"
          "            \"facts\":[\n"
          "              { \"title\": \"Total POIs Near Price\", \"value\": \"" + IntegerToString(count) + "\" },\n"
          "              { \"title\": \"Max Distance (Pips)\", \"value\": \"" + DoubleToString(maxPips, 1) + " pips\" }\n"
          "            ]\n"
          "          }\n"
          "        ],\n"
          "        \"actions\":[\n"
          "          { \"type\": \"Action.OpenUrl\", \"title\": \"📥 Download CSV Report\", \"url\": \"" + fileLink + "\" }\n"
          "        ]\n"
          "      }\n"
          "    }\n"
          "  ]\n"
          "}";

   char data[], result[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";
   ArrayResize(data, StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);

   int res = WebRequest("POST", WebhookURL, headers, 10000, data, result, result_headers);
   if(res >= 200 && res <= 299)
      Print("+++ ✅ SMC Swing POI Proximity Batch alert sent successfully to Teams.");
   else
      Print("--- ❌ WebRequest to Teams failed: ", res, " | ", CharArrayToString(result));
  }

// =============================================================================
// MOCK DEMO ALERT FUNCTION (For testing webhook connectivity at Init)
// =============================================================================
void SendDemoAlert()
  {
   Print("Sending Demo Alert to Webhook...");
   OBAnalysis oa;

   oa.zoneHigh = 1.25050;
   oa.zoneLow = 1.24900;
   oa.zoneCreatedTime = TimeCurrent() - 14400;
   oa.touchCount = 0;
   oa.isFresh = true;
   oa.isPreviouslyMitigated = false;
   oa.trendBias = "BULLISH";
   oa.marketStructureType = "Higher Highs & Higher Lows";
   oa.bosDetected = true;
   oa.chochDetected = false;
   oa.lastBosTime = TimeCurrent() - 3600;
   oa.lastBosType = "BOS";

   oa.tickVolume = 4502;
   oa.realVolume = 184500;
   oa.cumulativeVolume = 952000;
   oa.zzReversalPrice = 1.24850;
   oa.zzPriorReversalPrice = 1.25500;
   oa.zzPriceChange = -0.00650;
   oa.zzDirection = "DOWN";

   oa.maxLookbackBars = 3000;
   oa.deviationInput  = 1.0;
   oa.depthInput      = 15;

   oa.setupQuality = 92;
   oa.recommendation = "High confluence setup. Monitor LTF CHoCH for entry.";
   oa.zoneLabel = "ORDER-BLOCK";
   oa.reasoning = "- ✅ **Liquidity:** Swept + High Vol/Disp\\n\\n- ✅ **Momentum:** Favorable Approach\\n\\n- 🔥 **Structure:** Smart Money Trap Detected\\n\\n- ✅ **Freshness:** Zone is perfectly FRESH\\n\\n- ✅ **Session:** NY & Lon Overlap\\n\\n- ✅ **Fibonacci:** Valid Premium Zone\\n\\n- 🎯 **Proximity:** Optimal Entrance\\n\\n- ✅ **Alignment:** HTF & LTF Trend Synergy\\n\\n- ✅ **Obstacles:** Clear path to TP\\n\\n";

   oa.slPrice = 1.24870;
   oa.tpPrice = 1.25300;
   oa.estLoss = 180.00;
   oa.estProfit = 360.00;

   SendOBAlert("GBPUSDm", PERIOD_H4, "BULLISH", oa, ALERTS_TEAMS_URL);
  }

// =============================================================================
// BACKTEST REPORTER CLASS (Direct CSV Generation for Python)
// =============================================================================
class CBacktestReporter
  {
public:
   static string     UploadFileToCatbox(string report_content, string file_name)
     {
      Print("📤 Uploading ", file_name, " to Catbox.moe...");

      string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
      headers += "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n";

      string body = "--" + boundary + "\r\n";
      body += "Content-Disposition: form-data; name=\"reqtype\"\r\n\r\n";
      body += "fileupload\r\n";
      body += "--" + boundary + "\r\n";
      body += "Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"" + file_name + "\"\r\n";
      body += "Content-Type: text/plain\r\n\r\n";
      body += report_content + "\r\n";
      body += "--" + boundary + "--\r\n";

      char data[];
      StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      char result[];
      string result_headers;
      ResetLastError();
      int res = WebRequest("POST", "https://catbox.moe/user/api.php", headers, 15000, data, result, result_headers);

      if(res >= 200 && res <= 299)
        {
         string response = CharArrayToString(result);
         if(StringFind(response, "http") == 0)
            return response;
        }

      Print("❌ Catbox Error: ", res, " | LastError: ", _LastError);

      Print("🔄 Attempting Fallback to file.io...");
      string fb_boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      string fb_headers = "Content-Type: multipart/form-data; boundary=" + fb_boundary + "\r\n";
      string fb_body = "--" + fb_boundary + "\r\n";
      fb_body += "Content-Disposition: form-data; name=\"file\"; filename=\"" + file_name + "\"\r\n";
      fb_body += "Content-Type: text/plain\r\n\r\n";
      fb_body += report_content + "\r\n";
      fb_body += "--" + fb_boundary + "--\r\n";

      char fb_data[];
      StringToCharArray(fb_body, fb_data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(fb_data, ArraySize(fb_data) - 1);

      int fb_res = WebRequest("POST", "https://file.io/", fb_headers, 15000, fb_data, result, result_headers);
      if(fb_res >= 200 && fb_res <= 299)
        {
         string resp = CharArrayToString(result);
         int link_idx = StringFind(resp, "\"link\":\"");
         if(link_idx > 0)
           {
            int start = link_idx + 8;
            int end = StringFind(resp, "\"", start);
            return StringSubstr(resp, start, end - start);
           }
        }
      return "Upload Failed";
     }

   static double     GetMean(CArrayInt &arr)
     {
      if(arr.Total() == 0)
         return 0.0;
      double sum = 0;
      for(int i = 0; i < arr.Total(); i++)
         sum += arr.At(i);
      return sum / arr.Total();
     }

   static string     FormatScoreArray(CArrayInt &arr)
     {
      if(arr.Total() == 0)
         return "[]";
      string res = "[";
      for(int i = 0; i < arr.Total(); i++)
        {
         res += IntegerToString(arr.At(i));
         if(i < arr.Total() - 1)
            res += ", ";
        }
      res += "]";
      return res;
     }

   static string     FormatZoneCSVRow(string symbol, string tf, string zoneName, ZoneStats &metric)
     {
      int success = metric.success;
      int fail = metric.fail;
      double rate = metric.Ratio();

      string succ_scores = "\"" + FormatScoreArray(metric.successScores) + "\"";
      string fail_scores = "\"" + FormatScoreArray(metric.failScores) + "\"";

      string cleanSym = CleanSymbol(symbol);

      string row = cleanSym + "," + tf + "," + zoneName + "," +
                   IntegerToString(success) + "," + IntegerToString(fail) + "," +
                   DoubleToString(rate, 2) + "," +
                   DoubleToString(GetMean(metric.successScores), 2) + "," +
                   DoubleToString(GetMean(metric.failScores), 2) + "," +
                   succ_scores + "," + fail_scores;

      row += "," + DoubleToString(GetMean(metric.p1_success), 2) + "," + DoubleToString(GetMean(metric.p1_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p2_success), 2) + "," + DoubleToString(GetMean(metric.p2_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p3_success), 2) + "," + DoubleToString(GetMean(metric.p3_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p4_success), 2) + "," + DoubleToString(GetMean(metric.p4_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p5_success), 2) + "," + DoubleToString(GetMean(metric.p5_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p6_success), 2) + "," + DoubleToString(GetMean(metric.p6_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p7_success), 2) + "," + DoubleToString(GetMean(metric.p7_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p8_success), 2) + "," + DoubleToString(GetMean(metric.p8_fail), 2);
      row += "," + DoubleToString(GetMean(metric.p9_success), 2) + "," + DoubleToString(GetMean(metric.p9_fail), 2);

      row += ",\"" + FormatScoreArray(metric.p1_success) + "\",\"" + FormatScoreArray(metric.p1_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p2_success) + "\",\"" + FormatScoreArray(metric.p2_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p3_success) + "\",\"" + FormatScoreArray(metric.p3_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p4_success) + "\",\"" + FormatScoreArray(metric.p4_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p5_success) + "\",\"" + FormatScoreArray(metric.p5_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p6_success) + "\",\"" + FormatScoreArray(metric.p6_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p7_success) + "\",\"" + FormatScoreArray(metric.p7_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p8_success) + "\",\"" + FormatScoreArray(metric.p8_fail) + "\"";
      row += ",\"" + FormatScoreArray(metric.p9_success) + "\",\"" + FormatScoreArray(metric.p9_fail) + "\"";

      return row + "\n";
     }

   static string     FormatTimeframeCSV(string symbol, string tf, BacktestMetrics &metrics)
     {
      string res = "";
      res += FormatZoneCSVRow(symbol, tf, "Demand Zones", metrics.demand);
      res += FormatZoneCSVRow(symbol, tf, "Supply Zones", metrics.supply);
      res += FormatZoneCSVRow(symbol, tf, "Bullish Swing POI", metrics.bullPOI);
      res += FormatZoneCSVRow(symbol, tf, "Bearish Swing POI", metrics.bearPOI);
      res += FormatZoneCSVRow(symbol, tf, "Bullish OrderBlock", metrics.bullOB);
      res += FormatZoneCSVRow(symbol, tf, "Bearish OrderBlock", metrics.bearOB);
      res += FormatZoneCSVRow(symbol, tf, "Demand Flip Zone", metrics.demandFlip);
      res += FormatZoneCSVRow(symbol, tf, "Supply Flip Zone", metrics.supplyFlip);
      res += FormatZoneCSVRow(symbol, tf, "Bullish Breaker Block", metrics.bullBreaker);
      res += FormatZoneCSVRow(symbol, tf, "Bearish Breaker Block", metrics.bearBreaker);
      return res;
     }

   static string     FormatSymbolCSV(string symbol, BacktestMetrics &mM15, BacktestMetrics &mH1, BacktestMetrics &mH4, BacktestMetrics &mD1)
     {
      string res = "";
      res += FormatTimeframeCSV(symbol, "PERIOD_M15", mM15);
      res += FormatTimeframeCSV(symbol, "PERIOD_H1", mH1);
      res += FormatTimeframeCSV(symbol, "PERIOD_H4", mH4);
      res += FormatTimeframeCSV(symbol, "PERIOD_D1", mD1);
      return res;
     }
  };

// =============================================================================
// STARTUP DAILY REPORT EVALUATOR CLASS
// =============================================================================
class CDailyReporter
  {
public:
   static void       ProcessPendingReports()
     {
      Print("🔍 CDailyReporter: Checking for previous days' logs...");
      string file_name;
      long search_handle = FileFindFirst("*_alert.csv", file_name);

      if(search_handle == INVALID_HANDLE)
        {
         Print("ℹ️ CDailyReporter: No previous alert files found.");
         return;
        }

      string today = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(today, ".", "-");

      do
        {
         if(StringFind(file_name, today) >= 0)
            continue;
         string flag_name = file_name + ".processed";
         if(FileIsExist(flag_name))
            continue;

         string reportType = (StringFind(file_name, "touch") >= 0) ? "TOUCH" : "MITIGATION";
         Print("🚀 CDailyReporter: Found file to process: ", file_name);

         if(ProcessDailyFile(file_name, reportType))
           {
            int fh = FileOpen(flag_name, FILE_WRITE|FILE_TXT|FILE_ANSI);
            if(fh != INVALID_HANDLE)
              {
               FileWriteString(fh, "done");
               FileClose(fh);
              }
            Print("✅ CDailyReporter: Successfully processed and flagged ", file_name);
           }

        }
      while(FileFindNext(search_handle, file_name));
      FileFindClose(search_handle);
     }

private:
   static bool       ProcessDailyFile(string file_name, string rType)
     {
      int fh = FileOpen(file_name, FILE_READ|FILE_TXT|FILE_ANSI);
      if(fh == INVALID_HANDLE)
        {
         Print("❌ CDailyReporter: Could not open ", file_name);
         return false;
        }

      int total = 0, wins = 0, losses = 0, pending = 0;

      // Start building the new CSV contents, now containing an Outcome column
      string csv_content = "Time,Symbol,Timeframe,Type,Direction,Entry,SL,TP,Key,Outcome\r\n";

      while(!FileIsEnding(fh))
        {
         string line = FileReadString(fh);
         if(line == "" || StringLen(line) < 10)
            continue;
         if(StringFind(line, "Time,Symbol") == 0)
            continue;

         string parts[];
         int cnt = StringSplit(line, ',', parts);
         if(cnt < 8)
            continue;

         datetime entryTime = (datetime)StringToInteger(parts[0]);
         string sym = parts[1];
         string cleanSym = CleanSymbol(sym);
         string dir = parts[4];
         double entry = StringToDouble(parts[5]);
         double sl = StringToDouble(parts[6]);
         double tp = StringToDouble(parts[7]);

         string outcome = EvaluateTrade(sym, entryTime, dir, sl, tp);
         total++;
         if(outcome == "WIN")
            wins++;
         else
            if(outcome == "LOSS")
               losses++;
            else
               pending++;

         parts[1] = cleanSym;
         string cleanedLine = parts[0];
         for(int p = 1; p < cnt; p++)
           {
            cleanedLine += "," + parts[p];
           }

         csv_content += cleanedLine + "," + outcome + "\r\n";
        }
      FileClose(fh);

      if(total > 0)
        {
         string cleaned_filename = file_name;
         StringReplace(cleaned_filename, "m_alert", "_alert");
         StringReplace(cleaned_filename, "m_mitigation", "_mitigation");
         StringReplace(cleaned_filename, "m_touch", "_touch");

         string link = CBacktestReporter::UploadFileToCatbox(csv_content, cleaned_filename);
         Print("🔗 Report Link: ", link);
         return SendReportAlert(cleaned_filename, rType, total, wins, losses, pending, link, csv_content);
        }
      return true;
     }

   static string     EvaluateTrade(string sym, datetime entryTime, string dir, double sl, double tp)
     {
      return CEntryModel::EvaluateTradeOutcomeM1(sym, entryTime, dir, sl, tp);
     }

   static bool       SendReportAlert(string file, string rType, int total, int wins, int losses, int pending, string link, string csv_content)
     {
      if(DAILY_REPORT_TEAMS_URL == "" || StringFind(DAILY_REPORT_TEAMS_URL, "http") < 0)
         return false;

      CDashboardAPI::SendReport(file, csv_content);

      int closed_trades = wins + losses;
      double winRate = (closed_trades > 0) ? ((double)wins / closed_trades) * 100.0 : 0;
      string colorStyle = (rType == "TOUCH") ? "accent" : "attention";

      string msg = "{\"type\":\"message\",\"attachments\":[{\"contentType\":\"application/vnd.microsoft.card.adaptive\",\"content\":{"
                   "\"$schema\":\"http://adaptivecards.io/schemas/adaptive-card.json\",\"type\":\"AdaptiveCard\",\"version\":\"1.4\","
                   "\"body\":["
                   "{\"type\":\"Container\",\"style\":\""+colorStyle+"\",\"items\":["
                   "{\"type\":\"TextBlock\",\"text\":\"📊 SMC "+rType+" PERFORMANCE\",\"weight\":\"Bolder\",\"size\":\"Large\",\"horizontalAlignment\":\"Center\"},"
                   "{\"type\":\"TextBlock\",\"text\":\"Log: "+file+"\",\"isSubtle\":true,\"horizontalAlignment\":\"Center\",\"spacing\":\"None\"}]}, "
                   "{\"type\":\"FactSet\",\"facts\":["
                   "{\"title\":\"Total Signals\",\"value\":\"" + IntegerToString(total) + "\"},"
                   "{\"title\":\"Wins (2R)\",\"value\":\"" + IntegerToString(wins) + "\"},"
                   "{\"title\":\"Losses (-1R)\",\"value\":\"" + IntegerToString(losses) + "\"},"
                   "{\"title\":\"Pending\",\"value\":\"" + IntegerToString(pending) + "\"},"
                   "{\"title\":\"Win Rate\",\"value\":\"**" + DoubleToString(winRate, 1) + "%**\"}"
                   "]}"
                   "],"
                   "\"actions\":[{\"type\":\"Action.OpenUrl\",\"title\":\"📥 Download Evaluated CSV\",\"url\":\"" + link + "\"}]"
                   "}}] }";

      char data[], result[];
      string result_headers;
      string headers = "Content-Type: application/json\r\n";
      StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      int res = WebRequest("POST", DAILY_REPORT_TEAMS_URL, headers, 10000, data, result, result_headers);
      if(res >= 200 && res <= 299)
        {
         Print("✅ Teams Performance Alert Sent!");
         return true;
        }
      else
        {
         Print("❌ Teams Performance Alert Error: ", res);
         return false;
        }
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\teams_alert.mqh

// END FILE: Include\Custom\General\teams_alert.mqh
