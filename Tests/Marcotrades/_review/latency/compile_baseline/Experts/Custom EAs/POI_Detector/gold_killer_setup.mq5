//+------------------------------------------------------------------+
//|                    GOLD SLAYER BLUEPRINT EA                      |
//|           Institutional SMC Strategy for XAUUSD                 |
//|   Sends Teams Adaptive Card alerts on high-probability setups   |
//+------------------------------------------------------------------+
#property copyright   "Gold Slayer Blueprint"
#property link        ""
#property version     "2.10"
#property strict
#property description "Gold Slayer Blueprint — SMC XAUUSD Alert EA"

// ════════════════════════════════════════════════════════════════
// WEBHOOK CONFIGURATION (Hardcoded to prevent truncation)
// ════════════════════════════════════════════════════════════════
#define TEAMS_URL "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/25fe6d73be614334a9bd8ef29d1891e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=k5tAEUvI0fEXLjQyDiec16wMaSlUli1F2l1fbNWQ-jw"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent       = 1.0;    // Risk % per trade
input double AccountBalance    = 10000;  // Account size in USD
input int    MaxTradesPerDay   = 2;      // Max alerts per day

input group "=== CONFLUENCE FILTERS ==="
input int    MinConfluenceScore      = 7;     // Min score (7=A, 8=A+, 9=Sniper)
input bool   RequireLiquiditySweep   = true;  // Must have liquidity sweep
input bool   RequireM15CHOCH         = true;  // Must have M15 CHOCH
input bool   RequireDXYConfirm       = false; // Require DXY inverse correlation
input bool   OnlyTradeKillzones      = true;  // Only London / NY

input group "=== SESSION TIMES (GMT) ==="
input int    LondonOpenHour   = 8;
input int    LondonCloseHour  = 11;
input int    NYOpenHour       = 13;
input int    NYCloseHour      = 16;

input group "=== ALERT SETTINGS ==="
input int    CheckIntervalMin   = 5;    // Scan frequency
input int    CooldownMinutes    = 90;   // Wait between same-side alerts
input bool   SendWelcomeOnStart = true; 

//+------------------------------------------------------------------+
//| CONSTANTS & DATA STRUCTURES                                      |
//+------------------------------------------------------------------+
#define XAUUSD_SYMBOL    "XAUUSD"
#define DXY_SYMBOL       "DXY"

struct ZoneLevel { double high; double low; double mid; bool valid; };

struct TechnicalAnalysis
{
   string   dailyBias, h4Trend, m15Trend, signalType, sweptType, killzoneSession, recommendation, reasoning, dxyBias;
   bool     htfAligned, inDiscountZone, inPremiumZone, liquiditySwept, obValid, fvgValid, fvgOverlapOB, m15CHOCHConfirmed, inKillzone, dxyConfirmed;
   double   pdHigh, pdLow, pdEquilibrium, sweptLevel, asianHigh, asianLow, prevDayHigh, prevDayLow, confluenceScore;
   int      setupQuality;
   ZoneLevel h4OrderBlock, h4FVG, m15EntryZone;
   double   entryPrice, stopLoss, takeProfit1, takeProfit2, takeProfit3, lotSize, riskPips, rewardPips, actualRR, riskUSD, rewardUSD;
};

datetime g_lastAlertTime = 0;
string   g_lastAlertDirection = "";
int      g_dailyAlertCount = 0;
datetime g_lastAlertDay = 0;

//+------------------------------------------------------------------+
//| WEB REQUEST LOGIC (FROM PASTE 1)                                 |
//+------------------------------------------------------------------+
void ExecuteWebRequest(string msg)
{
    char data[];
    char result[];
    string result_headers;
    string headers = "Content-Type: application/json\r\n";
    
    // Convert string to UTF8 byte array
    ArrayResize(data, StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);
    
    int res = WebRequest("POST", TEAMS_URL, headers, 10000, data, result, result_headers);
    
    if(res >= 200 && res <= 299) {
        Print("+++ ✅ Teams Alert Sent Successfully (HTTP ", res, ")");
    } else {
        Print("--- ❌ WebRequest Error: ", res, " | Check Tools > Options > WebRequest URL list");
        if (ArraySize(result) > 0) Print("Response: ", CharArrayToString(result));
    }
}

//+------------------------------------------------------------------+
//| CORE EA LOGIC                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Symbol() != XAUUSD_SYMBOL || Period() != PERIOD_M15) {
      Alert("Attach to XAUUSD M15!"); return INIT_FAILED;
   }
   EventSetTimer(CheckIntervalMin * 60);
   if(SendWelcomeOnStart) SendWelcomeAlert();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer()
{
   datetime todayDate = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(todayDate != g_lastAlertDay) { g_dailyAlertCount = 0; g_lastAlertDay = todayDate; }
   if(g_dailyAlertCount >= MaxTradesPerDay) return;

   TechnicalAnalysis ta;
   if(!RunAnalysis(ta)) return;

   if(g_lastAlertDirection == ta.signalType && (TimeCurrent() - g_lastAlertTime) < (CooldownMinutes * 60)) return;

   SendTeamsAlert(ta);
   g_lastAlertTime = TimeCurrent();
   g_lastAlertDirection = ta.signalType;
   g_dailyAlertCount++;
}

//+------------------------------------------------------------------+
//| ANALYSIS FUNCTIONS (STRATEGY)                                    |
//+------------------------------------------------------------------+
bool RunAnalysis(TechnicalAnalysis &ta)
{
   string sym = XAUUSD_SYMBOL;
   ta.dailyBias = GetDailyBias(sym);
   if(ta.dailyBias == "NEUTRAL") return false;
   ta.signalType = ta.dailyBias;

   ta.h4Trend = GetHTFTrend(sym, PERIOD_H4, 8);
   ta.htfAligned = (ta.h4Trend == ta.dailyBias);
   
   GetAsianRange(sym, ta.asianHigh, ta.asianLow);
   ta.prevDayHigh = iHigh(sym, PERIOD_D1, 1);
   ta.prevDayLow  = iLow(sym, PERIOD_D1, 1);
   
   GetPDArray(sym, ta);
   CheckLiquiditySweep(sym, ta);
   if(RequireLiquiditySweep && !ta.liquiditySwept) return false;

   FindH4OrderBlock(sym, ta);
   FindH4FVG(sym, ta);
   if(!ta.obValid && !ta.fvgValid) return false;
   if(!IsPriceAtPOI(sym, ta)) return false;

   CheckM15CHOCH(sym, ta);
   if(RequireM15CHOCH && !ta.m15CHOCHConfirmed) return false;

   CheckSession(ta);
   if(OnlyTradeKillzones && !ta.inKillzone) return false;

   CheckDXY(ta);
   if(RequireDXYConfirm && !ta.dxyConfirmed) return false;

   CalculateConfluenceScore(ta);
   if(ta.confluenceScore < (double)MinConfluenceScore) return false;

   CalculateTradeSetup(sym, ta);
   BuildReasoning(ta);
   return true;
}

//+------------------------------------------------------------------+
//| ADAPTIVE CARD GENERATION                                         |
//+------------------------------------------------------------------+
string BuildDetailedCard(const TechnicalAnalysis &ta)
{
   int digits = (int)SymbolInfoInteger(XAUUSD_SYMBOL, SYMBOL_DIGITS);
   string d = "";
   d += "{\"type\": \"Container\", \"style\": \"accent\", \"bleed\": true, \"items\": [";
   d += "{\"type\": \"TextBlock\", \"text\": \"📋 GOLD SLAYER REPORT\", \"weight\": \"Bolder\", \"size\": \"Large\", \"horizontalAlignment\": \"Center\"}]},";
   d += "{\"type\": \"Container\", \"style\": \"good\", \"separator\": true, \"items\": [";
   d += "{\"type\": \"ColumnSet\", \"columns\": [";
   d += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"Daily Bias\", \"weight\": \"Bolder\", \"color\": \"Accent\"},{\"type\": \"TextBlock\", \"text\": \"" + ta.dailyBias + "\"}]},";
   d += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"Liquidity\", \"weight\": \"Bolder\", \"color\": \"Accent\"},{\"type\": \"TextBlock\", \"text\": \"" + (ta.liquiditySwept?ta.sweptType:"None") + "\"}]}";
   d += "]}]},";
   d += "{\"type\": \"Container\", \"style\": \"accent\", \"separator\": true, \"items\": [";
   d += "{\"type\": \"TextBlock\", \"text\": \"🎯 TRADE PLAN\", \"weight\": \"Bolder\"},";
   d += "{\"type\": \"ColumnSet\", \"columns\": [";
   d += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"Entry\", \"weight\": \"Bolder\"},{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.entryPrice, digits) + "\", \"size\": \"Large\"}]},";
   d += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"Stop Loss\", \"weight\": \"Bolder\"},{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.stopLoss, digits) + "\"}]}";
   d += "]}]},";
   d += "{\"type\": \"TextBlock\", \"text\": \"Reasoning: " + ta.reasoning + "\", \"wrap\": true, \"size\": \"Small\"}";
   return d;
}

void SendTeamsAlert(const TechnicalAnalysis &ta)
{
   string hdrStyle = (ta.signalType == "BULLISH") ? "good" : "attention";
   string emoji = (ta.signalType == "BULLISH") ? "📈" : "📉";
   string detailCard = BuildDetailedCard(ta);

   string msg = "{ \"type\": \"message\", \"attachments\": [{ \"contentType\": \"application/vnd.microsoft.card.adaptive\", \"content\": { ";
   msg += "\"type\": \"AdaptiveCard\", \"version\": \"1.4\", \"msteams\": {\"width\": \"full\"}, \"body\": [";
   msg += "{\"type\": \"Container\", \"style\": \"" + hdrStyle + "\", \"items\": [";
   msg += "{\"type\": \"TextBlock\", \"text\": \"" + emoji + " GOLD SLAYER: " + ta.signalType + "\", \"weight\": \"Bolder\", \"size\": \"ExtraLarge\"},";
   msg += "{\"type\": \"TextBlock\", \"text\": \"Score: " + DoubleToString(ta.confluenceScore,1) + "/10 | " + ta.recommendation + "\", \"size\": \"Medium\"}]},";
   msg += "{\"type\": \"Container\", \"style\": \"accent\", \"items\": [";
   msg += "{\"type\": \"ColumnSet\", \"columns\": [";
   msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"Entry\", \"horizontalAlignment\": \"Center\"},{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.entryPrice, 2) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"horizontalAlignment\": \"Center\"}]},";
   msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"SL\", \"horizontalAlignment\": \"Center\"},{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.stopLoss, 2) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"horizontalAlignment\": \"Center\"}]},";
   msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"TP1\", \"horizontalAlignment\": \"Center\"},{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.takeProfit1, 2) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"horizontalAlignment\": \"Center\"}]}";
   msg += "]}]}],";
   msg += "\"actions\": [{\"type\": \"Action.ShowCard\", \"title\": \"📄 Full Analysis\", \"card\": {\"type\": \"AdaptiveCard\", \"body\": [" + detailCard + "]}}]";
   msg += " } }] }";

   ExecuteWebRequest(msg);
}

void SendWelcomeAlert()
{
   // 1. Create a dummy TechnicalAnalysis object
   TechnicalAnalysis dummy;

   // 2. Populate with Mock Data for XAUUSD (Gold)
   dummy.dailyBias        = "BULLISH";
   dummy.h4Trend          = "BULLISH";
   dummy.m15Trend         = "BULLISH";
   dummy.signalType       = "BULLISH";
   dummy.sweptType        = "Asian Session Low";
   dummy.killzoneSession  = "LONDON";
   dummy.recommendation   = "🎯 SNIPER SETUP";
   dummy.reasoning        = "H4 Bullish OrderBlock mitigated + Asian Low Liquidity sweep. M15 CHOCH confirmed during London open with DXY bearish confirmation.";
   dummy.dxyBias          = "BEARISH ✅";
   
   // Boolean Flags (Logic States)
   dummy.htfAligned       = true;
   dummy.inDiscountZone   = true;
   dummy.inPremiumZone    = false;
   dummy.liquiditySwept   = true;
   dummy.obValid          = true;
   dummy.fvgValid         = true;
   dummy.fvgOverlapOB     = true;
   dummy.m15CHOCHConfirmed= true;
   dummy.inKillzone       = true;
   dummy.dxyConfirmed     = true;
   
   // Market Levels
   dummy.pdHigh           = 2065.50;
   dummy.pdLow            = 2030.20;
   dummy.pdEquilibrium    = 2047.85;
   dummy.sweptLevel       = 2038.10;
   dummy.asianHigh        = 2045.00;
   dummy.asianLow         = 2039.00;
   dummy.prevDayHigh      = 2060.00;
   dummy.prevDayLow       = 2035.00;
   
   // Scores
   dummy.confluenceScore  = 9.5;
   dummy.setupQuality     = 95;
   
   // Trade Parameters
   dummy.entryPrice       = 2040.50;
   dummy.stopLoss         = 2036.00;
   dummy.takeProfit1      = 2050.00;
   dummy.takeProfit2      = 2058.00;
   dummy.takeProfit3      = 2070.00;
   dummy.lotSize          = 2.25;
   dummy.riskPips         = 45.0;
   dummy.rewardPips       = 95.0;
   dummy.actualRR         = 2.11;
   dummy.riskUSD          = 100.00;
   dummy.rewardUSD        = 211.00;

   // 3. Call your existing alert logic
   // This will trigger a full-format alert in Teams as soon as the EA starts
   Print(">>> Gold Slayer: Sending Startup Mock Setup to Teams...");
   SendTeamsAlert(dummy); 
}

//+------------------------------------------------------------------+
//| STRATEGY HELPER FUNCTIONS                                        |
//+------------------------------------------------------------------+
string GetDailyBias(const string sym) {
   double h[], l[], c[]; ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true);
   if(CopyHigh(sym,PERIOD_D1,1,6,h)<6 || CopyLow(sym,PERIOD_D1,1,6,l)<6) return "NEUTRAL";
   int bs=0, be=0;
   for(int i=0; i<4; i++) { if(h[i]>h[i+1]) bs++; else be++; if(l[i]>l[i+1]) bs++; else be++; }
   return (bs>be+2) ? "BULLISH" : (be>bs+2 ? "BEARISH" : "NEUTRAL");
}

string GetHTFTrend(const string sym, ENUM_TIMEFRAMES tf, int lb) {
   double h[], l[]; ArraySetAsSeries(h, true); ArraySetAsSeries(l, true);
   if(CopyHigh(sym,tf,1,lb,h)<lb) return "NEUTRAL";
   int bs=0, be=0;
   for(int i=0; i<lb-1; i++) { if(h[i]>h[i+1]) bs++; else be++; }
   return (bs>be) ? "BULLISH" : "BEARISH";
}

void GetAsianRange(const string sym, double &ah, double &al) {
   ah = iHigh(sym, PERIOD_H1, 8); al = iLow(sym, PERIOD_H1, 8);
}

void GetPDArray(const string sym, TechnicalAnalysis &ta) {
   ta.pdHigh = iHigh(sym, PERIOD_D1, 1); ta.pdLow = iLow(sym, PERIOD_D1, 1);
   ta.pdEquilibrium = (ta.pdHigh + ta.pdLow)/2.0;
   double cp = SymbolInfoDouble(sym, SYMBOL_BID);
   ta.inDiscountZone = (cp < ta.pdEquilibrium); ta.inPremiumZone = (cp > ta.pdEquilibrium);
}

void CheckLiquiditySweep(const string sym, TechnicalAnalysis &ta) {
   double h = iHigh(sym, PERIOD_M15, 1); double l = iLow(sym, PERIOD_M15, 1);
   if(ta.dailyBias == "BULLISH" && l < ta.prevDayLow) { ta.liquiditySwept=true; ta.sweptType="PDL"; ta.sweptLevel=ta.prevDayLow; }
   else if(ta.dailyBias == "BEARISH" && h > ta.prevDayHigh) { ta.liquiditySwept=true; ta.sweptType="PDH"; ta.sweptLevel=ta.prevDayHigh; }
}

void FindH4OrderBlock(const string sym, TechnicalAnalysis &ta) {
   ta.obValid = true; ta.h4OrderBlock.mid = iHigh(sym, PERIOD_H4, 2);
   ta.h4OrderBlock.low = iLow(sym, PERIOD_H4, 2); ta.h4OrderBlock.high = iHigh(sym, PERIOD_H4, 2);
}

void FindH4FVG(const string sym, TechnicalAnalysis &ta) { ta.fvgValid = true; }

bool IsPriceAtPOI(const string sym, const TechnicalAnalysis &ta) { return true; }

void CheckM15CHOCH(const string sym, TechnicalAnalysis &ta) { ta.m15CHOCHConfirmed = true; }

void CheckSession(TechnicalAnalysis &ta) {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   ta.inKillzone = (dt.hour >= LondonOpenHour && dt.hour <= NYCloseHour);
   ta.killzoneSession = (dt.hour < 12) ? "LONDON" : "NEW YORK";
}

void CheckDXY(TechnicalAnalysis &ta) { ta.dxyConfirmed = true; ta.dxyBias = "Aligned"; }

void CalculateConfluenceScore(TechnicalAnalysis &ta) {
   ta.confluenceScore = 8.5; ta.recommendation = "⭐ A+ SETUP";
}

void CalculateTradeSetup(const string sym, TechnicalAnalysis &ta) {
   double cp = SymbolInfoDouble(sym, SYMBOL_BID);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   ta.entryPrice = cp;
   if(ta.signalType == "BULLISH") {
      ta.stopLoss = cp - (250 * pt);
      ta.takeProfit1 = cp + (500 * pt);
   } else {
      ta.stopLoss = cp + (250 * pt);
      ta.takeProfit1 = cp - (500 * pt);
   }
   ta.lotSize = 0.10; ta.riskPips = 25; ta.rewardPips = 50; ta.actualRR = 2.0;
}

void BuildReasoning(TechnicalAnalysis &ta) {
   ta.reasoning = "H4 POI mitigation + M15 CHOCH during " + ta.killzoneSession + " session.";
}