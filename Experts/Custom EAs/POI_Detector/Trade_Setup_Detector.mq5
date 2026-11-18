//+------------------------------------------------------------------+
//|                Enhanced_Scanner_UPGRADED.mq5                     |
//|           100-Point Institutional FVG Scanner - UPGRADED         |
//|    WITH: Dynamic Risk, Async Execution, Enhanced Patterns        |
//+------------------------------------------------------------------+
#property strict

// --- SETTINGS ---
#define TEAMS_URL "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/25fe6d73be614334a9bd8ef29d1891e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=k5tAEUvI0fEXLjQyDiec16wMaSlUli1F2l1fbNWQ-jw"

input string  SymbolsToScan   = "EURUSD,EURJPY,USDJPY,GBPUSD,BTCUSD,XAUUSD";
input int     ScanFrequency   = 1;  // Now in seconds (OnTimer)
input int     LookbackBars    = 100;
input double  RiskRewardRatio = 2.0;

// ════════════════════════════════════════════════════════════════
// UPGRADE #1: DYNAMIC RISK MANAGEMENT
// ════════════════════════════════════════════════════════════════
input double  RiskAmountUSD   = 50.0;  // Risk per trade in USD
input double  MaxLotSizeForex = 2.0;   // Safety cap for Forex
input double  MaxLotSizeGold  = 0.10;  // Safety cap for Gold/Metals
input double  AccountRiskPercent = 2.0;

// --- INSTITUTIONAL FILTERS ---
input bool    EnableHTFAlignment = true;
input bool    EnablePDArrayFilter = true;
input bool    EnableLiquiditySweep = true;
input bool    EnableLTFConfirmation = true;
input bool    EnableKillzoneFilter = true;
input bool    EnableVolumeFilter = true;
input double  VolumeSpikeThreshold = 1.20;
input int     LiquiditySweepBars = 30;

// --- SMT & FRESHNESS FILTERS ---
input bool    EnableSMTDivergence = true;
input bool    EnableZoneFreshness = true;
input int     SMTLookbackBars = 20;
input double  SMTTolerancePips = 10;

// --- MENTOR'S CHECKLIST FILTERS ---
input bool    EnableMarketStructure = true;
input bool    EnableBreakoutFilter = true;
input bool    EnableWickPsychology = true;
input bool    EnableRoundNumberConfluence = true;
input int     ConsolidationBars = 10;
input double  FVGClarityMultiplier = 2.0;
input double  WickPercentageMin = 30.0;
input double  RoundNumberTolerance = 5.0;

// ════════════════════════════════════════════════════════════════
// UPGRADE #3: ENHANCED REJECTION LOGIC
// ════════════════════════════════════════════════════════════════
input bool    EnableEngulfingRejection = true;  // Railway Track pattern
input double  EngulfingBodyRatio = 0.7;         // Body must be 70%+ of candle

// Correlated asset pairs mapping
string correlatedPairs[][2] = {
    {"EURUSD", "GBPUSD"},
    {"GBPUSD", "EURUSD"},
    {"EURJPY", "USDJPY"},
    {"USDJPY", "EURJPY"},
    {"BTCUSD", "ETHUSD"},
    {"ETHUSD", "BTCUSD"},
    {"XAUUSD", "XAGUSD"},
    {"XAGUSD", "XAUUSD"}
};

string symbolsArray[];
ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_M30, PERIOD_H1};

struct FVGTracker {
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    datetime lastAlertTime;
    string lastAlertType;
    double fvgTop;
    double fvgBottom;
    bool waitingForConfirmation;
    datetime fvgFormationTime;
    bool liquiditySwept;
    double sweepLevel;
    int touchCount;
    datetime lastTouchTime;
    bool isActive;
    string zoneID;
    string signalID;  // NEW: Unique signal ID for async processing
};

FVGTracker trackedFVGs[];
int maxTrackedZones = 500;

struct TechnicalAnalysis {
    string trendM5;
    string trendM15;
    string trendM30;
    string trendH1;
    string trendH4;
    string overallTrend;
    double nearestSupport;
    double nearestResistance;
    double distanceToSupport;
    double distanceToResistance;
    bool hasRejectionAtLevel;
    string rejectionType;
    double liquidityLevel;
    bool higherHighs;
    bool higherLows;
    bool lowerHighs;
    bool lowerLows;
    string momentum;
    bool volumeIncreasing;
    bool htfAligned;
    string htfTrend;
    bool inPremiumZone;
    bool inDiscountZone;
    double pdHigh;
    double pdLow;
    double pdEquilibrium;
    bool liquiditySwept;
    double sweptLevel;
    string sweptType;
    bool ltfConfirmed;
    bool inKillzone;
    string killzoneSession;
    bool volumeSpike;
    double volumeRatio;
    bool smtDetected;
    string smtAsset;
    string smtType;
    double smtPrimarySwing;
    double smtSecondarySwing;
    string smtDescription;
    int zoneTouchCount;
    string zoneFreshness;
    bool isFreshZone;
    bool isTestedZone;
    bool isMitigatedZone;
    
    // MENTOR'S CHECKLIST
    bool marketStructureConfirmed;
    string marketStructureType;
    bool breakoutConfirmed;
    string breakoutType;
    bool fvgClarityConfirmed;
    double fvgClarityRatio;
    bool wickPsychologyDetected;
    double wickPercentage;
    string wickType;
    bool roundNumberConfluence;
    double nearestRoundNumber;
    double distanceToRoundNumber;
    bool trendContinuationDetected;
    string trendContinuationType;
    string candlePattern;
    
    // UPGRADE #3: Enhanced Rejection
    bool engulfingRejection;
    string engulfingType;
    
    int setupQuality;
    string recommendation;
    string reasoning;
    string filterStatus;
    double buyLimit;
    double stopLoss;
    double takeProfit;
    double riskPips;
    double rewardPips;
    double actualRR;
    double riskUSD;
    double rewardUSD;
    double dynamicLotSize;  // NEW: Calculated lot size
};

// ════════════════════════════════════════════════════════════════
// UPGRADE #2: ASYNC SIGNAL QUEUE
// ════════════════════════════════════════════════════════════════
struct PendingSignal {
    bool isActive;
    string signalID;
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    string type;
    double top;
    double bottom;
    TechnicalAnalysis analysis;
    bool isWelcome;
    datetime createdAt;
};

PendingSignal signalQueue[];
int maxQueueSize = 100;
string processedSignals[];
int processedCount = 0;

int OnInit() {
    StringSplit(SymbolsToScan, ',', symbolsArray);
    ArrayResize(trackedFVGs, maxTrackedZones);
    ArrayResize(signalQueue, maxQueueSize);
    ArrayResize(processedSignals, 1000);
    
    for(int i=0; i<maxTrackedZones; i++) {
        trackedFVGs[i].symbol = "";
        trackedFVGs[i].isActive = false;
        trackedFVGs[i].touchCount = 0;
    }
    
    for(int i=0; i<maxQueueSize; i++) {
        signalQueue[i].isActive = false;
    }
    
    // ════════════════════════════════════════════════════════════════
    // UPGRADE #2: SWITCH TO OnTimer() FOR ASYNC EXECUTION
    // ════════════════════════════════════════════════════════════════
    EventSetTimer(ScanFrequency);
    
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║     ENHANCED 100-POINT SCANNER - UPGRADED VERSION            ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  ✅ UPGRADE 1: Dynamic Risk Management                        ║");
    Print("║     Risk per trade: $", RiskAmountUSD, "                      ║");
    Print("║  ✅ UPGRADE 2: Async Execution (OnTimer)                      ║");
    Print("║     Scan interval: ", ScanFrequency, " second(s)              ║");
    Print("║  ✅ UPGRADE 3: Enhanced Rejection (Engulfing)                 ║");
    Print("║  ✅ UPGRADE 4: Structural SMT (Fractal-based)                 ║");
    Print("║  ✅ UPGRADE 5: Spread Protection                              ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  Market Structure: ", (EnableMarketStructure ? "ON" : "OFF"), "                               ║");
    Print("║  Breakout Filter: ", (EnableBreakoutFilter ? "ON" : "OFF"), "                                ║");
    Print("║  Wick Psychology: ", (EnableWickPsychology ? "ON" : "OFF"), "                                ║");
    Print("║  Engulfing Rejection: ", (EnableEngulfingRejection ? "ON" : "OFF"), "                        ║");
    Print("║  Round Numbers: ", (EnableRoundNumberConfluence ? "ON" : "OFF"), "                            ║");
    Print("║  SMT Divergence: ", (EnableSMTDivergence ? "ON" : "OFF"), "                                  ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    SendWelcomeMessage();
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    EventKillTimer();
    Print("=== Enhanced Scanner UPGRADED shutting down. Reason: ", reason, " ===");
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #2: OnTimer() REPLACES OnTick()
// ════════════════════════════════════════════════════════════════
void OnTimer() {
    // Process pending signals from queue (async)
    ProcessSignalQueue();
    
    // Scan for new FVGs
    for(int s=0; s<ArraySize(symbolsArray); s++) {
        for(int t=0; t<ArraySize(timeframes); t++) {
            CheckFVG(symbolsArray[s], timeframes[t]);
            
            if(EnableLTFConfirmation) {
                CheckLTFConfirmation(symbolsArray[s], timeframes[t]);
            }
        }
    }
    
    CleanupOldZones();
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #1: DYNAMIC LOT SIZE CALCULATION
// ════════════════════════════════════════════════════════════════
double CalculateDynamicLot(string symbol, double stopLossPips) {
    if(stopLossPips <= 0) {
        Print("ERROR: Invalid Stop Loss pips: ", stopLossPips);
        return 0.01;
    }
    
    // Get symbol specifications
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Calculate pip size
    double pipSize = pointValue;
    if(digits == 3 || digits == 5) pipSize = pointValue * 10;
    
    // Calculate pip value per lot
    double pipValuePerLot = 0;
    
    if(digits == 5 || digits == 3) {
        double pipSizeNorm = (digits == 3) ? 0.01 : 0.0001;
        pipValuePerLot = (pipSizeNorm / tickSize) * tickValue;
    }
    else if(digits == 4 || digits == 2) {
        pipValuePerLot = (pointValue / tickSize) * tickValue;
    }
    else {
        pipValuePerLot = tickValue;
    }
    
    // Special handling for JPY pairs
    if(StringFind(symbol, "JPY") >= 0 && digits == 3) {
        pipValuePerLot = (0.01 / tickSize) * tickValue;
    }
    
    // Calculate required lot size to risk exactly RiskAmountUSD
    double calculatedLot = 0;
    
    if(pipValuePerLot > 0) {
        calculatedLot = RiskAmountUSD / (stopLossPips * pipValuePerLot);
    } else {
        Print("WARNING: Could not calculate pip value. Using fallback formula.");
        calculatedLot = RiskAmountUSD / (stopLossPips * 10);
    }
    
    // ════════════════════════════════════════════════════════════════
    // SAFETY CAP: Prevent margin calls on FTMO accounts
    // ════════════════════════════════════════════════════════════════
    bool isGold = (StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0);
    double maxAllowed = isGold ? MaxLotSizeGold : MaxLotSizeForex;
    
    if(calculatedLot > maxAllowed) {
        Print("⚠ WARNING: Calculated lot ", DoubleToString(calculatedLot, 2), 
              " exceeds safety cap. Capping to ", DoubleToString(maxAllowed, 2));
        calculatedLot = maxAllowed;
    }
    
    // Normalize to lot step
    calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
    
    // Ensure within broker limits
    if(calculatedLot < minLot) calculatedLot = minLot;
    if(calculatedLot > maxLot) calculatedLot = maxLot;
    
    Print(">>> Dynamic Lot Calculation: Symbol=", symbol, 
          " | SL=", DoubleToString(stopLossPips, 1), " pips",
          " | Risk=$", DoubleToString(RiskAmountUSD, 2),
          " | Lot=", DoubleToString(calculatedLot, 2));
    
    return calculatedLot;
}

void CheckFVG(string symbol, ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, tf, 0, ConsolidationBars + 10, rates) < ConsolidationBars + 10) return;
    
    datetime patternTime = rates[3].time;
    
    // BULLISH FVG
    bool threeGreen = (rates[1].close > rates[1].open && rates[2].close > rates[2].open && rates[3].close > rates[3].open);
    bool precedingRed = (rates[4].close < rates[4].open);
    bool bullishGap = (rates[1].low > rates[3].high);
    
    if(threeGreen && precedingRed && bullishGap) {
        string zoneID = GenerateZoneID(symbol, tf, rates[3].high, rates[1].low, patternTime);
        
        if(IsNewFVG(symbol, tf, patternTime, "BULLISH")) {
            Print("╔══════════════════════════════════════════════════════════════╗");
            Print("║  🎯 BULLISH FVG DETECTED                                     ║");
            Print("╠══════════════════════════════════════════════════════════════╣");
            Print("║  Symbol:      ", symbol, StringFormat("%-40s", ""), "║");
            Print("║  Timeframe:   ", EnumToString(tf), StringFormat("%-40s", ""), "║");
            Print("║  Time:        ", TimeToString(patternTime, TIME_DATE|TIME_MINUTES), StringFormat("%-33s", ""), "║");
            Print("╠══════════════════════════════════════════════════════════════╣");
            Print("║  FVG ZONE:                                                   ║");
            Print("║    Top:       ", DoubleToString(rates[3].high, _Digits), StringFormat("%-40s", ""), "║");
            Print("║    Bottom:    ", DoubleToString(rates[1].low, _Digits), StringFormat("%-40s", ""), "║");
            Print("╚══════════════════════════════════════════════════════════════╝");
            
            int touchCount = GetZoneTouchCount(zoneID);
            TechnicalAnalysis analysis = PerformAdvancedAnalysis(symbol, "BULLISH", rates[3].high, rates[1].low, tf, touchCount, rates);
            bool passesFilters = CheckAllFilters(analysis, "BULLISH");
            
            if(passesFilters) {
                Print(">>> ✅ ALL FILTERS PASSED - Quality: ", analysis.setupQuality, "/100");
                
                if(EnableLTFConfirmation) {
                    Print(">>> ⏳ WAITING FOR LTF CONFIRMATION");
                    MarkForConfirmation(symbol, tf, patternTime, "BULLISH", rates[3].high, rates[1].low, zoneID);
                } else {
                    Print(">>> 🚀 QUEUING ALERT");
                    QueueSignal(symbol, tf, "BULLISH", rates[3].high, rates[1].low, analysis, false);
                }
            } else {
                Print(">>> ❌ FILTERS FAILED - ", analysis.filterStatus);
            }
            Print("");
        }
    }
    
    // BEARISH FVG
    bool threeRed = (rates[1].close < rates[1].open && rates[2].close < rates[2].open && rates[3].close < rates[3].open);
    bool precedingGreen = (rates[4].close > rates[4].open);
    bool bearishGap = (rates[1].high < rates[3].low);
    
    if(threeRed && precedingGreen && bearishGap) {
        string zoneID = GenerateZoneID(symbol, tf, rates[1].high, rates[3].low, patternTime);
        
        if(IsNewFVG(symbol, tf, patternTime, "BEARISH")) {
            Print("╔══════════════════════════════════════════════════════════════╗");
            Print("║  🎯 BEARISH FVG DETECTED                                     ║");
            Print("╠══════════════════════════════════════════════════════════════╣");
            Print("║  Symbol:      ", symbol, StringFormat("%-40s", ""), "║");
            Print("║  Timeframe:   ", EnumToString(tf), StringFormat("%-40s", ""), "║");
            Print("╚══════════════════════════════════════════════════════════════╝");
            
            int touchCount = GetZoneTouchCount(zoneID);
            TechnicalAnalysis analysis = PerformAdvancedAnalysis(symbol, "BEARISH", rates[1].high, rates[3].low, tf, touchCount, rates);
            bool passesFilters = CheckAllFilters(analysis, "BEARISH");
            
            if(passesFilters) {
                Print(">>> ✅ ALL FILTERS PASSED - Quality: ", analysis.setupQuality, "/100");
                
                if(EnableLTFConfirmation) {
                    Print(">>> ⏳ WAITING FOR LTF CONFIRMATION");
                    MarkForConfirmation(symbol, tf, patternTime, "BEARISH", rates[1].high, rates[3].low, zoneID);
                } else {
                    Print(">>> 🚀 QUEUING ALERT");
                    QueueSignal(symbol, tf, "BEARISH", rates[1].high, rates[3].low, analysis, false);
                }
            } else {
                Print(">>> ❌ FILTERS FAILED - ", analysis.filterStatus);
            }
            Print("");
        }
    }
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #2: ASYNC SIGNAL QUEUE MANAGEMENT
// ════════════════════════════════════════════════════════════════
void QueueSignal(string symbol, ENUM_TIMEFRAMES tf, string type, double top, double bottom, TechnicalAnalysis &analysis, bool isWelcome) {
    string signalID = GenerateSignalID(symbol, tf, type, top, bottom, analysis.setupQuality);
    
    // Check if already processed
    for(int i=0; i<processedCount; i++) {
        if(processedSignals[i] == signalID) {
            Print(">>> Signal already sent: ", signalID);
            return;
        }
    }
    
    // Find free slot
    for(int i=0; i<maxQueueSize; i++) {
        if(!signalQueue[i].isActive) {
            signalQueue[i].isActive = true;
            signalQueue[i].signalID = signalID;
            signalQueue[i].symbol = symbol;
            signalQueue[i].timeframe = tf;
            signalQueue[i].type = type;
            signalQueue[i].top = top;
            signalQueue[i].bottom = bottom;
            signalQueue[i].analysis = analysis;
            signalQueue[i].isWelcome = isWelcome;
            signalQueue[i].createdAt = TimeCurrent();
            
            Print(">>> Signal queued: ", signalID, " [Slot ", i, "]");
            return;
        }
    }
    
    Print(">>> ERROR: Signal queue full!");
}

void ProcessSignalQueue() {
    for(int i=0; i<maxQueueSize; i++) {
        if(signalQueue[i].isActive) {
            // Send the alert
            SendAlert(
                signalQueue[i].symbol,
                signalQueue[i].timeframe,
                signalQueue[i].type,
                signalQueue[i].top,
                signalQueue[i].bottom,
                signalQueue[i].analysis,
                signalQueue[i].isWelcome
            );
            
            // Mark as processed
            if(processedCount < 1000) {
                processedSignals[processedCount++] = signalQueue[i].signalID;
            }
            
            // Clear slot
            signalQueue[i].isActive = false;
            
            // Process one at a time to avoid blocking
            break;
        }
    }
}

string GenerateSignalID(string symbol, ENUM_TIMEFRAMES tf, string type, double top, double bottom, int quality) {
    return symbol + "_" + EnumToString(tf) + "_" + type + "_" + 
           DoubleToString(top, 5) + "_" + IntegerToString(quality) + "_" + 
           TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #3: ENHANCED REJECTION LOGIC WITH ENGULFING
// ════════════════════════════════════════════════════════════════
bool CheckWickPsychology(MqlRates &rates[], string direction, double entryZoneTop, double entryZoneBottom, TechnicalAnalysis &ta) {
    ta.wickPsychologyDetected = false;
    ta.engulfingRejection = false;
    
    // CHECK 1: Traditional Wick Rejection (Pin Bars)
    for(int i=3; i<=4; i++) {
        double candleSize = MathAbs(rates[i].high - rates[i].low);
        if(candleSize == 0) continue;
        
        if(direction == "BULLISH") {
            double lowerWick = rates[i].open < rates[i].close ? 
                              (rates[i].open - rates[i].low) : 
                              (rates[i].close - rates[i].low);
            double wickPercent = (lowerWick / candleSize) * 100.0;
            
            if(wickPercent >= WickPercentageMin) {
                ta.wickPsychologyDetected = true;
                ta.wickPercentage = wickPercent;
                ta.wickType = "Bullish Rejection (Long Lower Wick)";
                
                if(lowerWick > (candleSize * 0.6)) {
                    ta.candlePattern = "Pin Bar / Hammer";
                } else {
                    ta.candlePattern = "Rejection Candle";
                }
                return true;
            }
        }
        else if(direction == "BEARISH") {
            double upperWick = rates[i].open > rates[i].close ? 
                              (rates[i].high - rates[i].open) : 
                              (rates[i].high - rates[i].close);
            double wickPercent = (upperWick / candleSize) * 100.0;
            
            if(wickPercent >= WickPercentageMin) {
                ta.wickPsychologyDetected = true;
                ta.wickPercentage = wickPercent;
                ta.wickType = "Bearish Rejection (Long Upper Wick)";
                
                if(upperWick > (candleSize * 0.6)) {
                    ta.candlePattern = "Shooting Star";
                } else {
                    ta.candlePattern = "Rejection Candle";
                }
                return true;
            }
        }
    }
    
    // ════════════════════════════════════════════════════════════════
    // CHECK 2: INSTITUTIONAL ENGULFING (Railway Track)
    // ════════════════════════════════════════════════════════════════
    if(EnableEngulfingRejection) {
        if(direction == "BULLISH") {
            // Candle 4 = Red, Candle 3 = Strong Green Engulfing
            bool candle4Red = (rates[4].close < rates[4].open);
            bool candle3Green = (rates[3].close > rates[3].open);
            
            if(candle4Red && candle3Green) {
                double candle4Body = MathAbs(rates[4].close - rates[4].open);
                double candle3Body = MathAbs(rates[3].close - rates[3].open);
                double candle3Size = rates[3].high - rates[3].low;
                
                // Check if body is strong (>70% of candle)
                double bodyRatio = (candle3Size > 0) ? (candle3Body / candle3Size) : 0;
                
                // Check if C3 engulfs C4's body + top wick
                bool engulfsBody = (rates[3].close > rates[4].open) && (rates[3].open < rates[4].close);
                bool engulfsTopWick = (rates[3].high > rates[4].high);
                
                if(engulfsBody && engulfsTopWick && bodyRatio >= EngulfingBodyRatio) {
                    ta.wickPsychologyDetected = true;
                    ta.engulfingRejection = true;
                    ta.engulfingType = "Bullish Engulfing (Railway Track)";
                    ta.wickType = "Institutional Bullish Engulfing";
                    ta.candlePattern = "Railway Track / Engulfing";
                    ta.wickPercentage = bodyRatio * 100.0;
                    
                    Print(">>> 🚂 RAILWAY TRACK DETECTED (Bullish Engulfing)");
                    return true;
                }
            }
        }
        else if(direction == "BEARISH") {
            // Candle 4 = Green, Candle 3 = Strong Red Engulfing
            bool candle4Green = (rates[4].close > rates[4].open);
            bool candle3Red = (rates[3].close < rates[3].open);
            
            if(candle4Green && candle3Red) {
                double candle4Body = MathAbs(rates[4].close - rates[4].open);
                double candle3Body = MathAbs(rates[3].close - rates[3].open);
                double candle3Size = rates[3].high - rates[3].low;
                
                double bodyRatio = (candle3Size > 0) ? (candle3Body / candle3Size) : 0;
                
                bool engulfsBody = (rates[3].close < rates[4].open) && (rates[3].open > rates[4].close);
                bool engulfsBottomWick = (rates[3].low < rates[4].low);
                
                if(engulfsBody && engulfsBottomWick && bodyRatio >= EngulfingBodyRatio) {
                    ta.wickPsychologyDetected = true;
                    ta.engulfingRejection = true;
                    ta.engulfingType = "Bearish Engulfing (Railway Track)";
                    ta.wickType = "Institutional Bearish Engulfing";
                    ta.candlePattern = "Railway Track / Engulfing";
                    ta.wickPercentage = bodyRatio * 100.0;
                    
                    Print(">>> 🚂 RAILWAY TRACK DETECTED (Bearish Engulfing)");
                    return true;
                }
            }
        }
    }
    
    ta.wickType = "No Significant Wick";
    ta.candlePattern = "Neutral";
    return false;
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #4: STRUCTURAL SMT WITH FRACTAL SWING POINTS
// ════════════════════════════════════════════════════════════════
bool CheckSMTDivergence(string primarySymbol, string direction, TechnicalAnalysis &ta) {
    string secondarySymbol = GetCorrelatedAsset(primarySymbol);
    
    if(secondarySymbol == "") {
        ta.smtDetected = false;
        return false;
    }
    
    ta.smtAsset = secondarySymbol;
    
    MqlRates primaryRates[], secondaryRates[];
    ArraySetAsSeries(primaryRates, true);
    ArraySetAsSeries(secondaryRates, true);
    
    if(CopyRates(primarySymbol, PERIOD_M15, 0, 50, primaryRates) < 50) {
        ta.smtDetected = false;
        return false;
    }
    
    if(CopyRates(secondarySymbol, PERIOD_M15, 0, 50, secondaryRates) < 50) {
        ta.smtDetected = false;
        return false;
    }
    
    if(direction == "BULLISH") {
        // Find most recent fractal lows
        double primaryFractalLow1 = FindRecentFractalLow(primaryRates, 0, 20);
        double primaryFractalLow2 = FindRecentFractalLow(primaryRates, 21, 45);
        double secondaryFractalLow1 = FindRecentFractalLow(secondaryRates, 0, 20);
        double secondaryFractalLow2 = FindRecentFractalLow(secondaryRates, 21, 45);
        
        if(primaryFractalLow1 > 0 && primaryFractalLow2 > 0 && 
           secondaryFractalLow1 > 0 && secondaryFractalLow2 > 0) {
            
            bool primaryLowerLow = (primaryFractalLow1 < primaryFractalLow2);
            bool secondaryHigherLow = (secondaryFractalLow1 > secondaryFractalLow2);
            
            if(primaryLowerLow && secondaryHigherLow) {
                ta.smtDetected = true;
                ta.smtType = "BULLISH DIVERGENCE (Fractal)";
                ta.smtPrimarySwing = primaryFractalLow1;
                ta.smtSecondarySwing = secondaryFractalLow1;
                ta.smtDescription = primarySymbol + " Lower Fractal Low, " + secondarySymbol + " Higher Fractal Low";
                Print(">>> ✅ SMT DIVERGENCE: ", ta.smtDescription);
                return true;
            }
        }
    }
    else if(direction == "BEARISH") {
        double primaryFractalHigh1 = FindRecentFractalHigh(primaryRates, 0, 20);
        double primaryFractalHigh2 = FindRecentFractalHigh(primaryRates, 21, 45);
        double secondaryFractalHigh1 = FindRecentFractalHigh(secondaryRates, 0, 20);
        double secondaryFractalHigh2 = FindRecentFractalHigh(secondaryRates, 21, 45);
        
        if(primaryFractalHigh1 > 0 && primaryFractalHigh2 > 0 && 
           secondaryFractalHigh1 > 0 && secondaryFractalHigh2 > 0) {
            
            bool primaryHigherHigh = (primaryFractalHigh1 > primaryFractalHigh2);
            bool secondaryLowerHigh = (secondaryFractalHigh1 < secondaryFractalHigh2);
            
            if(primaryHigherHigh && secondaryLowerHigh) {
                ta.smtDetected = true;
                ta.smtType = "BEARISH DIVERGENCE (Fractal)";
                ta.smtPrimarySwing = primaryFractalHigh1;
                ta.smtSecondarySwing = secondaryFractalHigh1;
                ta.smtDescription = primarySymbol + " Higher Fractal High, " + secondarySymbol + " Lower Fractal High";
                Print(">>> ✅ SMT DIVERGENCE: ", ta.smtDescription);
                return true;
            }
        }
    }
    
    ta.smtDetected = false;
    return false;
}

double FindRecentFractalLow(MqlRates &rates[], int startIndex, int endIndex) {
    int lowestBar = -1;
    double lowestValue = 999999;
    
    for(int i=startIndex+3; i<endIndex-3 && i<ArraySize(rates)-3; i++) {
        // Fractal: 3 bars on each side are higher
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low && rates[i].low < rates[i-3].low &&
           rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low && rates[i].low < rates[i+3].low) {
            if(rates[i].low < lowestValue) {
                lowestValue = rates[i].low;
                lowestBar = i;
            }
        }
    }
    
    return (lowestBar >= 0) ? lowestValue : 0;
}

double FindRecentFractalHigh(MqlRates &rates[], int startIndex, int endIndex) {
    int highestBar = -1;
    double highestValue = 0;
    
    for(int i=startIndex+3; i<endIndex-3 && i<ArraySize(rates)-3; i++) {
        // Fractal: 3 bars on each side are lower
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high && rates[i].high > rates[i-3].high &&
           rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high && rates[i].high > rates[i+3].high) {
            if(rates[i].high > highestValue) {
                highestValue = rates[i].high;
                highestBar = i;
            }
        }
    }
    
    return (highestBar >= 0) ? highestValue : 0;
}

// ════════════════════════════════════════════════════════════════
// UPGRADE #5: SPREAD PROTECTION IN STOP LOSS
// ════════════════════════════════════════════════════════════════
void CalculateInstitutionalEntry(string symbol, string fvgType, double fvgTop, double fvgBottom, TechnicalAnalysis &ta) {
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    double pipSize = pointValue;
    if(digits == 3 || digits == 5) pipSize = pointValue * 10;
    
    // ════════════════════════════════════════════════════════════════
    // UPGRADE #5: ADD SPREAD BUFFER TO STOP LOSS
    // ════════════════════════════════════════════════════════════════
    int spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double spreadDistance = spread * pointValue;
    
    Print(">>> Spread Protection: ", symbol, " spread=", spread, " points (", 
          DoubleToString(spreadDistance / pipSize, 1), " pips)");
    
    if(fvgType == "BULLISH") {
        ta.buyLimit = NormalizeDouble((fvgTop + fvgBottom) / 2.0, digits);
        
        if(ta.liquiditySwept && ta.sweptLevel > 0) {
            ta.stopLoss = NormalizeDouble(ta.sweptLevel - (2 * pipSize) - spreadDistance, digits);
        } else {
            double fvgBuffer = (fvgTop - fvgBottom) * 0.3;
            ta.stopLoss = NormalizeDouble(fvgBottom - fvgBuffer - spreadDistance, digits);
        }
        
        double riskDistance = ta.buyLimit - ta.stopLoss;
        double minTP = ta.buyLimit + (riskDistance * RiskRewardRatio);
        
        double nearestSwingHigh = FindNearestSwingHigh(symbol, PERIOD_M15, ta.buyLimit);
        
        if(nearestSwingHigh > minTP) {
            ta.takeProfit = NormalizeDouble(nearestSwingHigh - (5 * pipSize), digits);
        } else {
            ta.takeProfit = NormalizeDouble(minTP, digits);
        }
    }
    else if(fvgType == "BEARISH") {
        ta.buyLimit = NormalizeDouble((fvgTop + fvgBottom) / 2.0, digits);
        
        if(ta.liquiditySwept && ta.sweptLevel > 0) {
            ta.stopLoss = NormalizeDouble(ta.sweptLevel + (2 * pipSize) + spreadDistance, digits);
        } else {
            double fvgBuffer = (fvgTop - fvgBottom) * 0.3;
            ta.stopLoss = NormalizeDouble(fvgTop + fvgBuffer + spreadDistance, digits);
        }
        
        double riskDistance = ta.stopLoss - ta.buyLimit;
        double minTP = ta.buyLimit - (riskDistance * RiskRewardRatio);
        
        double nearestSwingLow = FindNearestSwingLow(symbol, PERIOD_M15, ta.buyLimit);
        
        if(nearestSwingLow < minTP && nearestSwingLow > 0) {
            ta.takeProfit = NormalizeDouble(nearestSwingLow + (5 * pipSize), digits);
        } else {
            ta.takeProfit = NormalizeDouble(minTP, digits);
        }
    }
    
    if(fvgType == "BULLISH") {
        ta.riskPips = (ta.buyLimit - ta.stopLoss) / pipSize;
        ta.rewardPips = (ta.takeProfit - ta.buyLimit) / pipSize;
    } else {
        ta.riskPips = (ta.stopLoss - ta.buyLimit) / pipSize;
        ta.rewardPips = (ta.buyLimit - ta.takeProfit) / pipSize;
    }
    
    if(ta.riskPips > 0) {
        ta.actualRR = ta.rewardPips / ta.riskPips;
    }
    
    // ════════════════════════════════════════════════════════════════
    // UPGRADE #1: CALCULATE DYNAMIC LOT SIZE
    // ════════════════════════════════════════════════════════════════
    ta.dynamicLotSize = CalculateDynamicLot(symbol, ta.riskPips);
    
    // Calculate actual USD values with dynamic lot
    CalculateUSDValues(symbol, ta.riskPips, ta.rewardPips, ta.dynamicLotSize, ta.riskUSD, ta.rewardUSD);
    
    Print(">>> Entry Calc: Entry=", DoubleToString(ta.buyLimit, digits),
          " | SL=", DoubleToString(ta.stopLoss, digits),
          " | TP=", DoubleToString(ta.takeProfit, digits),
          " | Risk=", DoubleToString(ta.riskPips, 1), " pips",
          " | Lot=", DoubleToString(ta.dynamicLotSize, 2),
          " | USD=$", DoubleToString(ta.riskUSD, 2));
}

void CalculateUSDValues(string symbol, double riskPips, double rewardPips, double lotSize, double &riskUSD, double &rewardUSD) {
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    double pipValue = 0;
    
    if(digits == 5 || digits == 3) {
        double pipSize = (digits == 3) ? 0.01 : 0.0001;
        pipValue = (pipSize / tickSize) * tickValue * lotSize;
    }
    else if(digits == 4 || digits == 2) {
        pipValue = (pointValue / tickSize) * tickValue * lotSize;
    }
    else {
        pipValue = tickValue * lotSize;
    }
    
    if(StringFind(symbol, "JPY") >= 0 && digits == 3) {
        pipValue = (0.01 / tickSize) * tickValue * lotSize;
    }
    
    riskUSD = riskPips * pipValue;
    rewardUSD = rewardPips * pipValue;
    
    if(riskUSD <= 0 || riskUSD > 100000) {
        double standardPipValue = 1.0 * lotSize * 10;
        riskUSD = riskPips * standardPipValue;
        rewardUSD = rewardPips * standardPipValue;
    }
}

// ════════════════════════════════════════════════════════════════
// MENTOR'S CHECKLIST FUNCTIONS
// ════════════════════════════════════════════════════════════════

bool CheckMarketStructure(string symbol, ENUM_TIMEFRAMES tf, string direction, TechnicalAnalysis &ta) {
    MqlRates m15Rates[], h1Rates[];
    ArraySetAsSeries(m15Rates, true);
    ArraySetAsSeries(h1Rates, true);
    
    if(CopyRates(symbol, PERIOD_M15, 0, 50, m15Rates) < 50) return false;
    if(CopyRates(symbol, PERIOD_H1, 0, 50, h1Rates) < 50) return false;
    
    bool m15Structure = false, h1Structure = false;
    
    if(direction == "BULLISH") {
        double m15High1 = 0, m15High2 = 0;
        double m15Low1 = 999999, m15Low2 = 999999;
        
        for(int i=2; i<20; i++) {
            if(m15Rates[i].high > m15Rates[i-1].high && m15Rates[i].high > m15Rates[i+1].high) {
                if(m15High1 == 0) m15High1 = m15Rates[i].high;
                else if(m15High2 == 0) m15High2 = m15Rates[i].high;
            }
            if(m15Rates[i].low < m15Rates[i-1].low && m15Rates[i].low < m15Rates[i+1].low) {
                if(m15Low1 == 999999) m15Low1 = m15Rates[i].low;
                else if(m15Low2 == 999999) m15Low2 = m15Rates[i].low;
            }
        }
        
        m15Structure = (m15High1 > m15High2 && m15Low1 > m15Low2);
        
        double h1High1 = 0, h1High2 = 0;
        double h1Low1 = 999999, h1Low2 = 999999;
        
        for(int i=2; i<20; i++) {
            if(h1Rates[i].high > h1Rates[i-1].high && h1Rates[i].high > h1Rates[i+1].high) {
                if(h1High1 == 0) h1High1 = h1Rates[i].high;
                else if(h1High2 == 0) h1High2 = h1Rates[i].high;
            }
            if(h1Rates[i].low < h1Rates[i-1].low && h1Rates[i].low < h1Rates[i+1].low) {
                if(h1Low1 == 999999) h1Low1 = h1Rates[i].low;
                else if(h1Low2 == 999999) h1Low2 = h1Rates[i].low;
            }
        }
        
        h1Structure = (h1High1 > h1High2 && h1Low1 > h1Low2);
        ta.marketStructureType = "Higher Highs & Higher Lows";
    }
    else if(direction == "BEARISH") {
        double m15High1 = 0, m15High2 = 0;
        double m15Low1 = 999999, m15Low2 = 999999;
        
        for(int i=2; i<20; i++) {
            if(m15Rates[i].high > m15Rates[i-1].high && m15Rates[i].high > m15Rates[i+1].high) {
                if(m15High1 == 0) m15High1 = m15Rates[i].high;
                else if(m15High2 == 0) m15High2 = m15Rates[i].high;
            }
            if(m15Rates[i].low < m15Rates[i-1].low && m15Rates[i].low < m15Rates[i+1].low) {
                if(m15Low1 == 999999) m15Low1 = m15Rates[i].low;
                else if(m15Low2 == 999999) m15Low2 = m15Rates[i].low;
            }
        }
        
        m15Structure = (m15High1 < m15High2 && m15Low1 < m15Low2);
        
        double h1High1 = 0, h1High2 = 0;
        double h1Low1 = 999999, h1Low2 = 999999;
        
        for(int i=2; i<20; i++) {
            if(h1Rates[i].high > h1Rates[i-1].high && h1Rates[i].high > h1Rates[i+1].high) {
                if(h1High1 == 0) h1High1 = h1Rates[i].high;
                else if(h1High2 == 0) h1High2 = h1Rates[i].high;
            }
            if(h1Rates[i].low < h1Rates[i-1].low && h1Rates[i].low < h1Rates[i+1].low) {
                if(h1Low1 == 999999) h1Low1 = h1Rates[i].low;
                else if(h1Low2 == 999999) h1Low2 = h1Rates[i].low;
            }
        }
        
        h1Structure = (h1High1 < h1High2 && h1Low1 < h1Low2);
        ta.marketStructureType = "Lower Highs & Lower Lows";
    }
    
    ta.marketStructureConfirmed = (m15Structure && h1Structure);
    return ta.marketStructureConfirmed;
}

bool CheckBreakout(MqlRates &rates[], string direction, TechnicalAnalysis &ta) {
    double highestHigh = 0;
    double lowestLow = 999999;
    
    for(int i=4; i<4+ConsolidationBars; i++) {
        if(rates[i].high > highestHigh) highestHigh = rates[i].high;
        if(rates[i].low < lowestLow) lowestLow = rates[i].low;
    }
    
    if(direction == "BULLISH") {
        bool breaksHigh = (rates[3].close > highestHigh);
        ta.breakoutConfirmed = breaksHigh;
        ta.breakoutType = breaksHigh ? "Break of Consolidation High" : "No Breakout";
    }
    else if(direction == "BEARISH") {
        bool breaksLow = (rates[3].close < lowestLow);
        ta.breakoutConfirmed = breaksLow;
        ta.breakoutType = breaksLow ? "Break of Consolidation Low" : "No Breakout";
    }
    
    double avgCandleSize = 0;
    for(int i=4; i<14; i++) {
        avgCandleSize += MathAbs(rates[i].high - rates[i].low);
    }
    avgCandleSize /= 10.0;
    
    double gapCandleSize = MathAbs(rates[2].high - rates[2].low);
    ta.fvgClarityRatio = (avgCandleSize > 0) ? (gapCandleSize / avgCandleSize) : 0;
    ta.fvgClarityConfirmed = (ta.fvgClarityRatio >= FVGClarityMultiplier);
    
    return ta.breakoutConfirmed;
}

bool CheckRoundNumberConfluence(string symbol, double entryPrice, TechnicalAnalysis &ta) {
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(digits == 3 || digits == 5) pipSize *= 10;
    
    double multiplier = MathPow(10, digits);
    double priceInPips = entryPrice * multiplier;
    
    double majorRound = MathFloor(priceInPips / 1000) * 1000;
    double majorRoundPrice = majorRound / multiplier;
    double distanceToMajor = MathAbs(entryPrice - majorRoundPrice) / pipSize;
    
    double midRound = MathFloor(priceInPips / 1000) * 1000 + 500;
    double midRoundPrice = midRound / multiplier;
    double distanceToMid = MathAbs(entryPrice - midRoundPrice) / pipSize;
    
    if(distanceToMajor < distanceToMid) {
        ta.nearestRoundNumber = majorRoundPrice;
        ta.distanceToRoundNumber = distanceToMajor;
    } else {
        ta.nearestRoundNumber = midRoundPrice;
        ta.distanceToRoundNumber = distanceToMid;
    }
    
    ta.roundNumberConfluence = (ta.distanceToRoundNumber <= RoundNumberTolerance);
    return ta.roundNumberConfluence;
}

bool CheckTrendContinuation(string symbol, ENUM_TIMEFRAMES tf, string direction, TechnicalAnalysis &ta) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, tf, 0, 30, rates) < 30) {
        ta.trendContinuationDetected = false;
        return false;
    }
    
    if(direction == "BULLISH") {
        bool foundFlag = false;
        for(int i=1; i<10; i++) {
            double range = rates[i].high - rates[i].low;
            double prevRange = rates[i+1].high - rates[i+1].low;
            
            if(range < prevRange * 0.7) {
                foundFlag = true;
                ta.trendContinuationType = "Bullish Flag";
                break;
            }
        }
        
        for(int i=1; i<10; i++) {
            if(rates[i].low > rates[i+2].high && 
               rates[i].close > rates[i].open &&
               rates[i+1].close > rates[i+1].open) {
                foundFlag = true;
                ta.trendContinuationType = "Secondary Bullish FVG";
                break;
            }
        }
        
        ta.trendContinuationDetected = foundFlag;
    }
    else if(direction == "BEARISH") {
        bool foundFlag = false;
        for(int i=1; i<10; i++) {
            double range = rates[i].high - rates[i].low;
            double prevRange = rates[i+1].high - rates[i+1].low;
            
            if(range < prevRange * 0.7) {
                foundFlag = true;
                ta.trendContinuationType = "Bearish Flag";
                break;
            }
        }
        
        for(int i=1; i<10; i++) {
            if(rates[i].high < rates[i+2].low && 
               rates[i].close < rates[i].open &&
               rates[i+1].close < rates[i+1].open) {
                foundFlag = true;
                ta.trendContinuationType = "Secondary Bearish FVG";
                break;
            }
        }
        
        ta.trendContinuationDetected = foundFlag;
    }
    
    return ta.trendContinuationDetected;
}

bool CheckAllFilters(TechnicalAnalysis &ta, string fvgType) {
    string failedFilters = "";
    bool allPass = true;
    
    if(EnableMarketStructure && !ta.marketStructureConfirmed) {
        failedFilters += "MARKET_STRUCTURE_FAIL ";
        allPass = false;
    }
    
    if(EnableBreakoutFilter && (!ta.breakoutConfirmed || !ta.fvgClarityConfirmed)) {
        failedFilters += "BREAKOUT_OR_CLARITY_FAIL ";
        allPass = false;
    }
    
    if(EnableWickPsychology && !ta.wickPsychologyDetected) {
        failedFilters += "NO_WICK_REJECTION ";
        allPass = false;
    }
    
    if(EnableRoundNumberConfluence && !ta.roundNumberConfluence) {
        failedFilters += "NO_ROUND_NUMBER ";
        allPass = false;
    }
    
    if(EnableSMTDivergence && !ta.smtDetected) {
        failedFilters += "NO_SMT_DIVERGENCE ";
        allPass = false;
    }
    
    if(EnablePDArrayFilter) {
        if(fvgType == "BULLISH" && !ta.inDiscountZone) {
            failedFilters += "NOT_IN_DISCOUNT ";
            allPass = false;
        }
        if(fvgType == "BEARISH" && !ta.inPremiumZone) {
            failedFilters += "NOT_IN_PREMIUM ";
            allPass = false;
        }
    }
    
    if(EnableLiquiditySweep && !ta.liquiditySwept) {
        failedFilters += "NO_LIQUIDITY_SWEEP ";
        allPass = false;
    }
    
    if(EnableZoneFreshness && ta.isMitigatedZone) {
        failedFilters += "ZONE_MITIGATED ";
        allPass = false;
    }
    
    if(EnableKillzoneFilter && !ta.inKillzone) {
        failedFilters += "OUTSIDE_KILLZONE ";
        allPass = false;
    }
    
    if(EnableVolumeFilter && !ta.volumeSpike) {
        failedFilters += "NO_VOLUME_SPIKE ";
        allPass = false;
    }
    
    if(allPass) {
        ta.filterStatus = "✅ ALL FILTERS PASSED";
    } else {
        ta.filterStatus = "❌ FAILED: " + failedFilters;
    }
    
    return allPass;
}

void GenerateAdvancedRecommendation(string symbol, string fvgType, TechnicalAnalysis &ta) {
    int score = 0;
    ta.reasoning = "";
    
    if(ta.marketStructureConfirmed) {
        score += 15;
        ta.reasoning += "✅ Structure aligned. ";
    } else {
        ta.reasoning += "❌ Structure NOT aligned. ";
    }
    
    if(ta.breakoutConfirmed && ta.fvgClarityConfirmed) {
        score += 15;
        ta.reasoning += "✅ Breakout + Clear FVG. ";
    } else if(ta.breakoutConfirmed) {
        score += 8;
        ta.reasoning += "⚠ Breakout but weak clarity. ";
    } else {
        ta.reasoning += "❌ No breakout. ";
    }
    
    if(ta.wickPsychologyDetected) {
        score += 15;
        if(ta.engulfingRejection) {
            ta.reasoning += "✅ Railway Track pattern! ";
        } else {
            ta.reasoning += "✅ Wick rejection (" + DoubleToString(ta.wickPercentage, 0) + "%). ";
        }
    } else {
        ta.reasoning += "❌ No wick rejection. ";
    }
    
    if(ta.roundNumberConfluence) {
        score += 10;
        ta.reasoning += "✅ Round number (" + DoubleToString(ta.nearestRoundNumber, 5) + "). ";
    } else {
        ta.reasoning += "⚠ No round number. ";
    }
    
    if(ta.smtDetected) {
        score += 10;
        ta.reasoning += "✅ SMT divergence. ";
    } else {
        ta.reasoning += "❌ No SMT. ";
    }
    
    if(fvgType == "BULLISH" && ta.inDiscountZone) {
        score += 10;
        ta.reasoning += "✅ Discount zone. ";
    } else if(fvgType == "BEARISH" && ta.inPremiumZone) {
        score += 10;
        ta.reasoning += "✅ Premium zone. ";
    } else {
        ta.reasoning += "❌ Wrong PD zone. ";
    }
    
    if(ta.liquiditySwept) {
        score += 10;
        ta.reasoning += "✅ Liquidity swept. ";
    } else {
        ta.reasoning += "❌ No liquidity sweep. ";
    }
    
    if(ta.isFreshZone) {
        score += 10;
        ta.reasoning += "✅ Fresh zone. ";
    } else if(ta.isTestedZone) {
        score += 5;
        ta.reasoning += "⚠ Tested zone. ";
    } else {
        ta.reasoning += "❌ MITIGATED zone. ";
    }
    
    if(ta.inKillzone) {
        score += 3;
        ta.reasoning += "✅ Killzone. ";
    }
    
    if(ta.volumeSpike) {
        score += 2;
        ta.reasoning += "✅ Volume spike. ";
    }
    
    if(ta.trendContinuationDetected) {
        score += 5;
        ta.reasoning += "🎯 Trend continuation! ";
    }
    
    ta.setupQuality = MathMax(0, MathMin(100, score));
    
    if(score >= 90) {
        ta.recommendation = fvgType == "BULLISH" ? "🎯 STRONG BUY" : "🎯 STRONG SELL";
    } else if(score >= 70) {
        ta.recommendation = fvgType == "BULLISH" ? "✅ BUY" : "✅ SELL";
    } else if(score >= 50) {
        ta.recommendation = "⏸ WAIT";
    } else {
        ta.recommendation = "⛔ AVOID";
    }
}

TechnicalAnalysis PerformAdvancedAnalysis(string symbol, string fvgType, double fvgTop, double fvgBottom, ENUM_TIMEFRAMES currentTF, int touchCount, MqlRates &rates[]) {
    TechnicalAnalysis ta;
    
    if(EnableMarketStructure) {
        CheckMarketStructure(symbol, currentTF, fvgType, ta);
    } else {
        ta.marketStructureConfirmed = true;
        ta.marketStructureType = "Filter Disabled";
    }
    
    if(EnableBreakoutFilter) {
        CheckBreakout(rates, fvgType, ta);
    } else {
        ta.breakoutConfirmed = true;
        ta.fvgClarityConfirmed = true;
        ta.breakoutType = "Filter Disabled";
    }
    
    if(EnableWickPsychology) {
        CheckWickPsychology(rates, fvgType, fvgTop, fvgBottom, ta);
    } else {
        ta.wickPsychologyDetected = true;
        ta.wickType = "Filter Disabled";
        ta.candlePattern = "N/A";
    }
    
    double entryPrice = (fvgTop + fvgBottom) / 2.0;
    if(EnableRoundNumberConfluence) {
        CheckRoundNumberConfluence(symbol, entryPrice, ta);
    } else {
        ta.roundNumberConfluence = true;
        ta.nearestRoundNumber = 0;
    }
    
    CheckTrendContinuation(symbol, currentTF, fvgType, ta);
    CheckHTFAlignment(symbol, fvgType, ta);
    CalculatePDArray(symbol, PERIOD_H4, ta);
    DetectLiquiditySweep(symbol, currentTF, fvgType, ta);
    CheckKillzone(ta);
    CheckVolumeSpike(symbol, currentTF, ta);
    
    if(EnableSMTDivergence) {
        CheckSMTDivergence(symbol, fvgType, ta);
    } else {
        ta.smtDetected = false;
    }
    
    if(EnableZoneFreshness) {
        AnalyzeZoneFreshness(touchCount, ta);
    } else {
        ta.isFreshZone = true;
        ta.zoneFreshness = "N/A";
    }
    
    ta.trendM5 = AnalyzeTrend(symbol, PERIOD_M5);
    ta.trendM15 = AnalyzeTrend(symbol, PERIOD_M15);
    ta.trendM30 = AnalyzeTrend(symbol, PERIOD_M30);
    ta.trendH1 = AnalyzeTrend(symbol, PERIOD_H1);
    ta.overallTrend = DetermineOverallTrend(ta.trendM5, ta.trendM15, ta.trendM30, ta.trendH1);
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    FindNearestSupportResistance(symbol, PERIOD_H1, currentPrice, ta.nearestSupport, ta.nearestResistance);
    ta.distanceToSupport = MathAbs(currentPrice - ta.nearestSupport);
    ta.distanceToResistance = MathAbs(ta.nearestResistance - currentPrice);
    
    AnalyzeMarketStructure(symbol, PERIOD_H1, ta);
    ta.momentum = AnalyzeMomentum(symbol, PERIOD_H1);
    
    GenerateAdvancedRecommendation(symbol, fvgType, ta);
    CalculateInstitutionalEntry(symbol, fvgType, fvgTop, fvgBottom, ta);
    
    return ta;
}

// ════════════════════════════════════════════════════════════════
// INSTITUTIONAL FILTERS
// ════════════════════════════════════════════════════════════════

void CheckHTFAlignment(string symbol, string fvgType, TechnicalAnalysis &ta) {
    ta.trendH1 = AnalyzeTrend(symbol, PERIOD_H1);
    ta.trendH4 = AnalyzeTrend(symbol, PERIOD_H4);
    
    if(fvgType == "BULLISH") {
        bool h1Bullish = (StringFind(ta.trendH1, "BULLISH") >= 0);
        bool h4Bullish = (StringFind(ta.trendH4, "BULLISH") >= 0);
        ta.htfAligned = (h1Bullish && h4Bullish);
        ta.htfTrend = "H1: " + ta.trendH1 + " | H4: " + ta.trendH4;
    }
    else if(fvgType == "BEARISH") {
        bool h1Bearish = (StringFind(ta.trendH1, "BEARISH") >= 0);
        bool h4Bearish = (StringFind(ta.trendH4, "BEARISH") >= 0);
        ta.htfAligned = (h1Bearish && h4Bearish);
        ta.htfTrend = "H1: " + ta.trendH1 + " | H4: " + ta.trendH4;
    }
}

void CalculatePDArray(string symbol, ENUM_TIMEFRAMES tf, TechnicalAnalysis &ta) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, tf, 0, 100, rates) < 100) {
        ta.inPremiumZone = false;
        ta.inDiscountZone = false;
        return;
    }
    
    ta.pdHigh = rates[0].high;
    ta.pdLow = rates[0].low;
    
    for(int i=0; i<50; i++) {
        if(rates[i].high > ta.pdHigh) ta.pdHigh = rates[i].high;
        if(rates[i].low < ta.pdLow) ta.pdLow = rates[i].low;
    }
    
    ta.pdEquilibrium = (ta.pdHigh + ta.pdLow) / 2.0;
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    ta.inPremiumZone = (currentPrice > ta.pdEquilibrium);
    ta.inDiscountZone = (currentPrice < ta.pdEquilibrium);
}

void DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf, string fvgType, TechnicalAnalysis &ta) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, tf, 0, LiquiditySweepBars + 10, rates) < LiquiditySweepBars + 10) {
        ta.liquiditySwept = false;
        return;
    }
    
    if(fvgType == "BULLISH") {
        for(int i=2; i<LiquiditySweepBars; i++) {
            if(rates[i].low <= rates[i-1].low && rates[i].low <= rates[i+1].low) {
                bool wasSwept = false;
                for(int j=0; j<i; j++) {
                    if(rates[j].low < rates[i].low - (5 * SymbolInfoDouble(symbol, SYMBOL_POINT))) {
                        wasSwept = true;
                        ta.sweptLevel = rates[i].low;
                        break;
                    }
                }
                
                if(wasSwept) {
                    ta.liquiditySwept = true;
                    ta.sweptType = "SWING LOW";
                    return;
                }
            }
        }
    }
    else if(fvgType == "BEARISH") {
        for(int i=2; i<LiquiditySweepBars; i++) {
            if(rates[i].high >= rates[i-1].high && rates[i].high >= rates[i+1].high) {
                bool wasSwept = false;
                for(int j=0; j<i; j++) {
                    if(rates[j].high > rates[i].high + (5 * SymbolInfoDouble(symbol, SYMBOL_POINT))) {
                        wasSwept = true;
                        ta.sweptLevel = rates[i].high;
                        break;
                    }
                }
                
                if(wasSwept) {
                    ta.liquiditySwept = true;
                    ta.sweptType = "SWING HIGH";
                    return;
                }
            }
        }
    }
    ta.liquiditySwept = false;
}

void CheckKillzone(TechnicalAnalysis &ta) {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour;
    
    if(hour >= 7 && hour < 10) {
        ta.inKillzone = true;
        ta.killzoneSession = "LONDON";
    }
    else if(hour >= 12 && hour < 15) {
        ta.inKillzone = true;
        ta.killzoneSession = "NEW YORK";
    }
    else {
        ta.inKillzone = false;
        ta.killzoneSession = "NONE";
    }
}

void CheckVolumeSpike(string symbol, ENUM_TIMEFRAMES tf, TechnicalAnalysis &ta) {
    long volumes[];
    ArraySetAsSeries(volumes, true);
    
    if(CopyTickVolume(symbol, tf, 0, 25, volumes) < 25) {
        ta.volumeSpike = false;
        ta.volumeRatio = 0;
        return;
    }
    
    long volumeSum = 0;
    for(int i=1; i<=20; i++) {
        volumeSum += volumes[i];
    }
    double avgVolume = (double)volumeSum / 20.0;
    
    double currentVolume = (double)volumes[0];
    ta.volumeRatio = currentVolume / avgVolume;
    ta.volumeSpike = (ta.volumeRatio >= VolumeSpikeThreshold);
}

void AnalyzeZoneFreshness(int touchCount, TechnicalAnalysis &ta) {
    ta.zoneTouchCount = touchCount;
    
    if(touchCount == 0 || touchCount == 1) {
        ta.isFreshZone = true;
        ta.isTestedZone = false;
        ta.isMitigatedZone = false;
        ta.zoneFreshness = "FRESH";
    }
    else if(touchCount == 2) {
        ta.isFreshZone = false;
        ta.isTestedZone = true;
        ta.isMitigatedZone = false;
        ta.zoneFreshness = "TESTED";
    }
    else {
        ta.isFreshZone = false;
        ta.isTestedZone = false;
        ta.isMitigatedZone = true;
        ta.zoneFreshness = "MITIGATED";
    }
}

// ════════════════════════════════════════════════════════════════
// LTF CONFIRMATION
// ════════════════════════════════════════════════════════════════

void CheckLTFConfirmation(string symbol, ENUM_TIMEFRAMES tf) {
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(trackedFVGs[i].symbol == symbol && 
           trackedFVGs[i].timeframe == tf && 
           trackedFVGs[i].waitingForConfirmation) {
            
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            bool inFVGZone = (currentPrice >= trackedFVGs[i].fvgBottom && 
                             currentPrice <= trackedFVGs[i].fvgTop);
            
            if(inFVGZone) {
                bool ltfConfirmed = CheckLTFCHoCH(symbol, trackedFVGs[i].lastAlertType);
                
                if(ltfConfirmed) {
                    Print("╔══════════════════════════════════════════════════════════════╗");
                    Print("║  ✅ LTF CONFIRMATION ACHIEVED                                ║");
                    Print("╚══════════════════════════════════════════════════════════════╝");
                    
                    MqlRates rates[];
                    ArraySetAsSeries(rates, true);
                    CopyRates(symbol, tf, 0, ConsolidationBars + 10, rates);
                    
                    int touchCount = GetZoneTouchCount(trackedFVGs[i].zoneID);
                    TechnicalAnalysis analysis = PerformAdvancedAnalysis(
                        symbol, trackedFVGs[i].lastAlertType, 
                        trackedFVGs[i].fvgTop, trackedFVGs[i].fvgBottom, tf, touchCount, rates
                    );
                    analysis.ltfConfirmed = true;
                    
                    QueueSignal(symbol, tf, trackedFVGs[i].lastAlertType, 
                               trackedFVGs[i].fvgTop, trackedFVGs[i].fvgBottom, analysis, false);
                    
                    trackedFVGs[i].waitingForConfirmation = false;
                    UpdateZoneTouchCount(trackedFVGs[i].zoneID, symbol, tf, 
                                        trackedFVGs[i].fvgTop, trackedFVGs[i].fvgBottom,
                                        trackedFVGs[i].fvgFormationTime, trackedFVGs[i].lastAlertType);
                }
            }
        }
    }
}

bool CheckLTFCHoCH(string symbol, string direction) {
    ENUM_TIMEFRAMES ltf = PERIOD_M1;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, ltf, 0, 30, rates) < 30) return false;
    
    if(direction == "BULLISH") {
        double recentLowerHigh = 0;
        for(int i=5; i<25; i++) {
            if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) {
                recentLowerHigh = rates[i].high;
                break;
            }
        }
        if(recentLowerHigh > 0 && rates[0].close > recentLowerHigh) return true;
    }
    else if(direction == "BEARISH") {
        double recentHigherLow = 999999;
        for(int i=5; i<25; i++) {
            if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) {
                recentHigherLow = rates[i].low;
                break;
            }
        }
        if(recentHigherLow < 999999 && rates[0].close < recentHigherLow) return true;
    }
    return false;
}

void MarkForConfirmation(string symbol, ENUM_TIMEFRAMES tf, datetime patternTime, string type, double top, double bottom, string zoneID) {
    int freeSlot = FindFreeSlot();
    if(freeSlot >= 0) {
        trackedFVGs[freeSlot].symbol = symbol;
        trackedFVGs[freeSlot].timeframe = tf;
        trackedFVGs[freeSlot].waitingForConfirmation = true;
        trackedFVGs[freeSlot].fvgFormationTime = patternTime;
        trackedFVGs[freeSlot].lastAlertType = type;
        trackedFVGs[freeSlot].fvgTop = top;
        trackedFVGs[freeSlot].fvgBottom = bottom;
        trackedFVGs[freeSlot].zoneID = zoneID;
        trackedFVGs[freeSlot].isActive = true;
    }
}

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

string GetCorrelatedAsset(string primaryAsset) {
    for(int i=0; i<ArraySize(correlatedPairs)/2; i++) {
        if(correlatedPairs[i][0] == primaryAsset) {
            return correlatedPairs[i][1];
        }
    }
    return "";
}

double FindRecentLow(MqlRates &rates[], int startIndex, int endIndex) {
    double lowestLow = 999999;
    for(int i=startIndex+2; i<endIndex-2 && i<ArraySize(rates)-2; i++) {
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
           rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low) {
            if(rates[i].low < lowestLow) lowestLow = rates[i].low;
        }
    }
    return (lowestLow < 999999) ? lowestLow : 0;
}

double FindRecentHigh(MqlRates &rates[], int startIndex, int endIndex) {
    double highestHigh = 0;
    for(int i=startIndex+2; i<endIndex-2 && i<ArraySize(rates)-2; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
           rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high) {
            if(rates[i].high > highestHigh) highestHigh = rates[i].high;
        }
    }
    return highestHigh;
}

double FindNearestSwingHigh(string symbol, ENUM_TIMEFRAMES tf, double fromPrice) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, tf, 0, 50, rates) < 50) return 0;
    
    double nearestHigh = 999999;
    
    for(int i=2; i<45; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) {
            if(rates[i].high > fromPrice && rates[i].high < nearestHigh) {
                nearestHigh = rates[i].high;
            }
        }
    }
    
    return (nearestHigh < 999999) ? nearestHigh : 0;
}

double FindNearestSwingLow(string symbol, ENUM_TIMEFRAMES tf, double fromPrice) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(symbol, tf, 0, 50, rates) < 50) return 0;
    
    double nearestLow = 0;
    
    for(int i=2; i<45; i++) {
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) {
            if(rates[i].low < fromPrice && rates[i].low > nearestLow) {
                nearestLow = rates[i].low;
            }
        }
    }
    
    return nearestLow;
}

string AnalyzeTrend(string symbol, ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, tf, 0, 50, rates) < 50) return "UNKNOWN";
    
    double ema20 = CalculateEMA(rates, 20);
    double ema50 = CalculateEMA(rates, 50);
    double currentPrice = rates[0].close;
    
    int bullish = 0, bearish = 0;
    for(int i=1; i<=20; i++) {
        if(rates[i].close > rates[i].open) bullish++;
        else bearish++;
    }
    
    if(currentPrice > ema20 && ema20 > ema50 && bullish > bearish + 5) return "STRONG BULLISH";
    if(currentPrice > ema20 && ema20 > ema50) return "BULLISH";
    if(currentPrice < ema20 && ema20 < ema50 && bearish > bullish + 5) return "STRONG BEARISH";
    if(currentPrice < ema20 && ema20 < ema50) return "BEARISH";
    return "NEUTRAL";
}

double CalculateEMA(MqlRates &rates[], int period) {
    if(ArraySize(rates) < period) return 0;
    
    double multiplier = 2.0 / (period + 1);
    double ema = rates[period-1].close;
    
    for(int i=period-2; i>=0; i--) {
        ema = (rates[i].close - ema) * multiplier + ema;
    }
    return ema;
}

string DetermineOverallTrend(string m5, string m15, string m30, string h1) {
    int bullishCount = 0, bearishCount = 0;
    
    if(StringFind(m5, "BULLISH") >= 0) bullishCount++;
    if(StringFind(m15, "BULLISH") >= 0) bullishCount++;
    if(StringFind(m30, "BULLISH") >= 0) bullishCount++;
    if(StringFind(h1, "BULLISH") >= 0) bullishCount++;
    
    if(StringFind(m5, "BEARISH") >= 0) bearishCount++;
    if(StringFind(m15, "BEARISH") >= 0) bearishCount++;
    if(StringFind(m30, "BEARISH") >= 0) bearishCount++;
    if(StringFind(h1, "BEARISH") >= 0) bearishCount++;
    
    if(bullishCount >= 3) return "BULLISH ALIGNED";
    if(bearishCount >= 3) return "BEARISH ALIGNED";
    if(bullishCount > bearishCount) return "WEAKLY BULLISH";
    if(bearishCount > bullishCount) return "WEAKLY BEARISH";
    return "MIXED/RANGING";
}

void FindNearestSupportResistance(string symbol, ENUM_TIMEFRAMES tf, double currentPrice, double &support, double &resistance) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, tf, 0, LookbackBars, rates) < LookbackBars) {
        support = 0;
        resistance = 999999;
        return;
    }
    
    double levels[];
    int levelCount = 0;
    ArrayResize(levels, 200);
    
    for(int i=2; i<LookbackBars-2; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
           rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high) {
            levels[levelCount++] = rates[i].high;
        }
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
           rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low) {
            levels[levelCount++] = rates[i].low;
        }
    }
    
    support = 0;
    resistance = 999999;
    
    for(int i=0; i<levelCount; i++) {
        if(levels[i] < currentPrice && levels[i] > support) {
            support = levels[i];
        }
        if(levels[i] > currentPrice && levels[i] < resistance) {
            resistance = levels[i];
        }
    }
}

void AnalyzeMarketStructure(string symbol, ENUM_TIMEFRAMES tf, TechnicalAnalysis &ta) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, tf, 0, 50, rates) < 50) {
        ta.higherHighs = false;
        ta.higherLows = false;
        ta.lowerHighs = false;
        ta.lowerLows = false;
        return;
    }
    
    double swingHighs[];
    double swingLows[];
    ArrayResize(swingHighs, 10);
    ArrayResize(swingLows, 10);
    int highCount = 0, lowCount = 0;
    
    for(int i=3; i<30; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) {
            if(highCount < 10) swingHighs[highCount++] = rates[i].high;
        }
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) {
            if(lowCount < 10) swingLows[lowCount++] = rates[i].low;
        }
    }
    
    ta.higherHighs = (highCount >= 3 && swingHighs[0] > swingHighs[1] && swingHighs[1] > swingHighs[2]);
    ta.higherLows = (lowCount >= 3 && swingLows[0] > swingLows[1] && swingLows[1] > swingLows[2]);
    ta.lowerHighs = (highCount >= 3 && swingHighs[0] < swingHighs[1] && swingHighs[1] < swingHighs[2]);
    ta.lowerLows = (lowCount >= 3 && swingLows[0] < swingLows[1] && swingLows[1] < swingLows[2]);
}

string AnalyzeMomentum(string symbol, ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, tf, 0, 20, rates) < 20) return "UNKNOWN";
    
    double recentAvg = 0, olderAvg = 0;
    for(int i=1; i<=5; i++) recentAvg += rates[i].close;
    for(int i=10; i<=15; i++) olderAvg += rates[i].close;
    
    recentAvg /= 5;
    olderAvg /= 5;
    
    double pctChange = ((recentAvg - olderAvg) / olderAvg) * 100;
    
    if(pctChange > 0.5) return "STRONG BULLISH";
    if(pctChange > 0.1) return "BULLISH";
    if(pctChange < -0.5) return "STRONG BEARISH";
    if(pctChange < -0.1) return "BEARISH";
    return "NEUTRAL";
}

bool IsNewFVG(string symbol, ENUM_TIMEFRAMES tf, datetime patternTime, string type) {
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(trackedFVGs[i].symbol == symbol && trackedFVGs[i].timeframe == tf && trackedFVGs[i].isActive) {
            if(trackedFVGs[i].lastAlertTime == patternTime && trackedFVGs[i].lastAlertType == type) {
                return false;
            }
        }
    }
    return true;
}

string GenerateZoneID(string symbol, ENUM_TIMEFRAMES tf, double top, double bottom, datetime time) {
    return symbol + "_" + EnumToString(tf) + "_" + 
           DoubleToString(top, 5) + "_" + DoubleToString(bottom, 5);
}

int GetZoneTouchCount(string zoneID) {
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(trackedFVGs[i].isActive && trackedFVGs[i].zoneID == zoneID) {
            return trackedFVGs[i].touchCount;
        }
    }
    return 0;
}

void UpdateZoneTouchCount(string zoneID, string symbol, ENUM_TIMEFRAMES tf, double top, double bottom, datetime time, string type) {
    int existingIndex = -1;
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(trackedFVGs[i].isActive && trackedFVGs[i].zoneID == zoneID) {
            existingIndex = i;
            break;
        }
    }
    
    if(existingIndex >= 0) {
        trackedFVGs[existingIndex].touchCount++;
        trackedFVGs[existingIndex].lastTouchTime = TimeCurrent();
    } else {
        int freeSlot = FindFreeSlot();
        if(freeSlot >= 0) {
            trackedFVGs[freeSlot].symbol = symbol;
            trackedFVGs[freeSlot].timeframe = tf;
            trackedFVGs[freeSlot].zoneID = zoneID;
            trackedFVGs[freeSlot].fvgTop = top;
            trackedFVGs[freeSlot].fvgBottom = bottom;
            trackedFVGs[freeSlot].fvgFormationTime = time;
            trackedFVGs[freeSlot].lastAlertType = type;
            trackedFVGs[freeSlot].touchCount = 1;
            trackedFVGs[freeSlot].lastTouchTime = TimeCurrent();
            trackedFVGs[freeSlot].isActive = true;
        }
    }
}

int FindFreeSlot() {
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(!trackedFVGs[i].isActive) return i;
    }
    return -1;
}

void CleanupOldZones() {
    datetime cutoffTime = TimeCurrent() - (7 * 24 * 3600);
    for(int i=0; i<ArraySize(trackedFVGs); i++) {
        if(trackedFVGs[i].isActive && trackedFVGs[i].lastTouchTime < cutoffTime) {
            trackedFVGs[i].isActive = false;
            trackedFVGs[i].symbol = "";
        }
    }
}

// ════════════════════════════════════════════════════════════════
// WELCOME MESSAGE AND TEAMS ALERT
// ════════════════════════════════════════════════════════════════

void SendWelcomeMessage() {
    string demoSymbol = (ArraySize(symbolsArray) > 0) ? symbolsArray[0] : "EURUSD";
    
    double currentPrice = SymbolInfoDouble(demoSymbol, SYMBOL_BID);
    int digits = (int)SymbolInfoInteger(demoSymbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(demoSymbol, SYMBOL_POINT);
    double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
    
    double demoFVGTop = currentPrice + (50 * pipSize);
    double demoFVGBottom = currentPrice - (20 * pipSize);
    double demoEntry = (demoFVGTop + demoFVGBottom) / 2.0;
    double demoSL = demoFVGBottom - (22 * pipSize);
    double demoTP = demoEntry + (44 * pipSize);
    double demoPDHigh = currentPrice + (150 * pipSize);
    double demoPDLow = currentPrice - (150 * pipSize);
    double demoPDEq = (demoPDHigh + demoPDLow) / 2.0;
    double demoSweptLevel = currentPrice - (30 * pipSize);
    double demoRoundNumber = MathRound(currentPrice / (100 * pipSize)) * (100 * pipSize);
    
    TechnicalAnalysis dummyTA;
    dummyTA.trendM15 = "STRONG BULLISH";
    dummyTA.trendH1 = "BULLISH";
    dummyTA.trendH4 = "BULLISH";
    dummyTA.overallTrend = "BULLISH ALIGNED";
    dummyTA.htfAligned = true;
    dummyTA.inDiscountZone = true;
    dummyTA.pdHigh = demoPDHigh;
    dummyTA.pdLow = demoPDLow;
    dummyTA.pdEquilibrium = demoPDEq;
    dummyTA.liquiditySwept = true;
    dummyTA.sweptLevel = demoSweptLevel;
    dummyTA.sweptType = "SWING LOW";
    dummyTA.ltfConfirmed = true;
    dummyTA.inKillzone = true;
    dummyTA.killzoneSession = "LONDON";
    dummyTA.volumeSpike = true;
    dummyTA.volumeRatio = 1.45;
    dummyTA.smtDetected = true;
    dummyTA.smtAsset = GetCorrelatedAsset(demoSymbol);
    if(dummyTA.smtAsset == "") dummyTA.smtAsset = "GBPUSD";
    dummyTA.smtType = "BULLISH DIVERGENCE (Fractal)";
    dummyTA.smtDescription = demoSymbol + " Lower Fractal Low, " + dummyTA.smtAsset + " Higher Fractal Low";
    dummyTA.zoneTouchCount = 1;
    dummyTA.zoneFreshness = "FRESH";
    dummyTA.isFreshZone = true;
    dummyTA.marketStructureConfirmed = true;
    dummyTA.marketStructureType = "Higher Highs & Higher Lows";
    dummyTA.breakoutConfirmed = true;
    dummyTA.breakoutType = "Break of Consolidation High";
    dummyTA.fvgClarityConfirmed = true;
    dummyTA.fvgClarityRatio = 2.3;
    dummyTA.wickPsychologyDetected = true;
    dummyTA.wickPercentage = 45.0;
    dummyTA.wickType = "Bullish Rejection";
    dummyTA.candlePattern = "Pin Bar / Hammer";
    dummyTA.engulfingRejection = false;
    dummyTA.roundNumberConfluence = true;
    dummyTA.nearestRoundNumber = demoRoundNumber;
    dummyTA.distanceToRoundNumber = 3.2;
    dummyTA.trendContinuationDetected = true;
    dummyTA.trendContinuationType = "Bullish Flag";
    dummyTA.setupQuality = 98;
    dummyTA.recommendation = "🎯 STRONG BUY";
    dummyTA.reasoning = "✅ Structure aligned. ✅ Breakout + Clear FVG. ✅ Wick rejection (45%). ✅ Round number. ✅ SMT divergence. ✅ Discount zone. ✅ Liquidity swept. ✅ Fresh zone. ✅ Killzone. ✅ Volume spike. 🎯 Trend continuation!";
    dummyTA.filterStatus = "✅ ALL FILTERS PASSED";
    dummyTA.buyLimit = NormalizeDouble(demoEntry, digits);
    dummyTA.stopLoss = NormalizeDouble(demoSL, digits);
    dummyTA.takeProfit = NormalizeDouble(demoTP, digits);
    dummyTA.riskPips = 22.0;
    dummyTA.rewardPips = 44.0;
    dummyTA.actualRR = 2.0;
    dummyTA.dynamicLotSize = CalculateDynamicLot(demoSymbol, 22.0);
    dummyTA.riskUSD = RiskAmountUSD;
    dummyTA.rewardUSD = RiskAmountUSD * 2.0;
    
    Print("=== WELCOME: Sending demo alert for ", demoSymbol, " ===");
    
    QueueSignal(demoSymbol, PERIOD_M15, "BULLISH", demoFVGTop, demoFVGBottom, dummyTA, true);
}

// ════════════════════════════════════════════════════════════════
// GENERATE DETAILED ANALYSIS ATTACHMENT - MOBILE OPTIMIZED
// ════════════════════════════════════════════════════════════════
string GenerateDetailedAnalysisAttachment(string symbol, ENUM_TIMEFRAMES tf, string type, double top, double bottom, TechnicalAnalysis &ta) {
    string timeframeStr = StringSubstr(EnumToString(tf), 7);
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    
    // Build the detailed report card content (this will be embedded in ShowCard)
    string reportContent = "";
    
    // Header Block - Vibrant Accent
    reportContent += "{\"type\": \"Container\", \"style\": \"accent\", \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"📊 INSTITUTIONAL FVG ANALYSIS REPORT\", \"weight\": \"Bolder\", \"size\": \"Large\", \"horizontalAlignment\": \"Center\"},";
    reportContent += "{\"type\": \"ColumnSet\", \"columns\": [";
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"📍 " + symbol + "\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"horizontalAlignment\": \"Center\"}]},";
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"⏰ " + timeframeStr + "\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"horizontalAlignment\": \"Center\"}]},";
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"⭐ " + IntegerToString(ta.setupQuality) + "/100\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"color\": \"Warning\", \"horizontalAlignment\": \"Center\"}]}";
    reportContent += "]}]},";
    
    // ═══ ROW 1: MENTOR CHECKLIST (3 COLUMNS) - Good background ═══
    reportContent += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"style\": \"good\", \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"✅ MENTOR CHECKLIST\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    
    // First Row: 3 blocks side by side
    reportContent += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: Structure + Breakout
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Market Structure\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.marketStructureConfirmed ? "✅ " + ta.marketStructureType : "❌ FAIL") + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Breakout\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.breakoutConfirmed ? "✅ " + ta.breakoutType : "❌ NO") + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]},";
    
    // Column 2: FVG Clarity + Wick Psychology
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"FVG Clarity\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.fvgClarityConfirmed ? "✅ ×" + DoubleToString(ta.fvgClarityRatio, 1) : "❌ WEAK") + "\", \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Wick Psychology\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    if(ta.wickPsychologyDetected) {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"✅ " + DoubleToString(ta.wickPercentage, 0) + "%\", \"size\": \"Small\", \"spacing\": \"None\"}";
    } else {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"❌ NO\", \"size\": \"Small\", \"spacing\": \"None\"}";
    }
    reportContent += "]},";
    
    // Column 3: Candle Pattern + Round Number
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Candle Pattern\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    if(ta.engulfingRejection) {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"🚂 Railway\", \"wrap\": true, \"size\": \"Small\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\"},";
    } else {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + ta.candlePattern + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"},";
    }
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Round Number\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\"},";
    if(ta.roundNumberConfluence) {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"✅ " + DoubleToString(ta.nearestRoundNumber, 5) + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"}";
    } else {
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"❌ NO\", \"size\": \"Small\", \"spacing\": \"None\"}";
    }
    reportContent += "]}]}]},";
    
    // ═══ ROW 2: INSTITUTIONAL FILTERS (3 COLUMNS) - MOBILE OPTIMIZED ═══
    reportContent += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"style\": \"attention\", \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"🏛️ INSTITUTIONAL FILTERS\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    
    reportContent += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: HTF + PD Array
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"HTF Alignment\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.htfAligned ? "✅ YES" : "❌ NO") + "\", \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"PD Array\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    string pdText = ta.inDiscountZone ? "✅ DISC" : (ta.inPremiumZone ? "✅ PREM" : "⚠️ NEUT");
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + pdText + "\", \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]},";
    
    // Column 2: Liquidity + Freshness
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Liquidity Sweep\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.liquiditySwept ? "✅ " + ta.sweptType : "❌ NO") + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Zone Freshness\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    string freshnessText = ta.isFreshZone ? "✅ FRESH" : (ta.isTestedZone ? "⚠️ TEST" : "❌ MIT");
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + freshnessText + "\", \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]},";
    
    // Column 3: Killzone + Volume
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Killzone\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.inKillzone ? "✅ " + ta.killzoneSession : "❌ OUT") + "\", \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \" \", \"spacing\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Volume Spike\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + (ta.volumeSpike ? "✅ ×" + DoubleToString(ta.volumeRatio, 2) : "❌ NO") + "\", \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]}]}]},";
    
    // ═══ ROW 3: SMT DIVERGENCE (if detected) - Warning background ═══
    if(ta.smtDetected) {
        reportContent += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"style\": \"warning\", \"bleed\": true, \"items\": [";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"🔄 SMT DIVERGENCE DETECTED\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"color\": \"Attention\", \"spacing\": \"None\"},";
        
        reportContent += "{\"type\": \"ColumnSet\", \"columns\": [";
        reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"Type\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + ta.smtType + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"}";
        reportContent += "]},";
        reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"Correlated Asset\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + ta.smtAsset + "\", \"size\": \"Small\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\"}";
        reportContent += "]},";
        reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"Description\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
        reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + ta.smtDescription + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"}";
        reportContent += "]}]}]},";
    }
    
    // ═══ ROW 4: MARKET CONTEXT (2 COLUMNS) - Accent background ═══
    reportContent += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"style\": \"accent\", \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"📈 MARKET CONTEXT\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    
    reportContent += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: Trend Analysis
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Trend Analysis\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Overall: " + ta.overallTrend + "\", \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"H1: " + ta.trendH1 + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"H4: " + ta.trendH4 + "\", \"wrap\": true, \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]},";
    
    // Column 2: PD Levels
    reportContent += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"PD Array Levels\", \"weight\": \"Bolder\", \"size\": \"Small\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"High: " + DoubleToString(ta.pdHigh, 5) + "\", \"size\": \"Small\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Eq: " + DoubleToString(ta.pdEquilibrium, 5) + "\", \"size\": \"Small\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"Low: " + DoubleToString(ta.pdLow, 5) + "\", \"size\": \"Small\", \"spacing\": \"None\"}";
    reportContent += "]}]}]},";
    
    // ═══ ROW 5: REASONING (FULL WIDTH) - Default background ═══
    reportContent += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"🧠 REASONING\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"" + ta.reasoning + "\", \"wrap\": true, \"size\": \"Small\"}";
    reportContent += "]},";
    
    // Footer - Accent background
    reportContent += "{\"type\": \"Container\", \"spacing\": \"Small\", \"separator\": true, \"style\": \"accent\", \"bleed\": true, \"items\": [";
    reportContent += "{\"type\": \"TextBlock\", \"text\": \"🕐 " + timestamp + " | 💾 " + symbol + "_" + type + "_Report.txt\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"}";
    reportContent += "]}";
    
    return reportContent;
}

void SendAlert(string symbol, ENUM_TIMEFRAMES tf, string type, double top, double bottom, TechnicalAnalysis &ta, bool isWelcome = false) {
    string timeframeStr = StringSubstr(EnumToString(tf), 7);
    
    // --- 1. SAVE FILE LOCALLY (MQL5/Files/...) ---
    string fileTimestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    StringReplace(fileTimestamp, ":", "-"); 
    StringReplace(fileTimestamp, " ", "_");
    string filename = symbol + "_" + type + "_" + fileTimestamp + "_Report.txt";
    
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        string localReport = "INSTITUTIONAL FVG ANALYSIS REPORT\n";
        localReport += "========================================\n";
        localReport += "Symbol:    " + symbol + " (" + timeframeStr + ")\n";
        localReport += "Signal:    " + type + " FVG\n";
        localReport += "Quality:   " + IntegerToString(ta.setupQuality) + "/100\n";
        localReport += "Rec:       " + ta.recommendation + "\n";
        localReport += "Time:      " + fileTimestamp + "\n\n";
        localReport += "TRADE SETUP:\n";
        localReport += "Entry: " + DoubleToString(ta.buyLimit, 5) + "\n";
        localReport += "SL:    " + DoubleToString(ta.stopLoss, 5) + "\n";
        localReport += "TP:    " + DoubleToString(ta.takeProfit, 5) + "\n";
        localReport += "Lot:   " + DoubleToString(ta.dynamicLotSize, 2) + "\n";
        localReport += "R:R:   1:" + DoubleToString(ta.actualRR, 2) + "\n\n";
        localReport += "REASONING:\n" + ta.reasoning + "\n";
        
        FileWriteString(fileHandle, localReport);
        FileClose(fileHandle);
    }

    // --- 2. GET DETAILED REPORT CONTENT ---
    string reportContent = GenerateDetailedAnalysisAttachment(symbol, tf, type, top, bottom, ta);

    // --- 3. BUILD MAIN CARD WITH MOBILE-OPTIMIZED LAYOUT ---
    string headerStyle = (type == "BULLISH") ? "good" : "attention";
    string directionEmoji = (type == "BULLISH") ? "📈" : "📉";
    
    string msg = "{ \"type\": \"message\", \"attachments\": [{ ";
    msg += "\"contentType\": \"application/vnd.microsoft.card.adaptive\", ";
    msg += "\"content\": { ";
    msg += "\"$schema\": \"http://adaptivecards.io/schemas/adaptive-card.json\", ";
    msg += "\"type\": \"AdaptiveCard\", ";
    msg += "\"version\": \"1.4\", ";
    msg += "\"msteams\": {\"width\": \"full\"}, ";
    msg += "\"body\": [";

    // ═══════════════════════════════════════════════════════════
    // ROW 1: TITLE HEADER
    // ═══════════════════════════════════════════════════════════
    msg += "{\"type\": \"Container\", \"style\": \"" + headerStyle + "\", \"bleed\": true, \"items\": [";
    msg += "{\"type\": \"ColumnSet\", \"columns\": [";
    msg += "{\"type\": \"Column\", \"width\": \"auto\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"" + directionEmoji + "\", \"size\": \"ExtraLarge\", \"weight\": \"Bolder\"}]},";
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + symbol + " " + type + " SIGNAL\", \"weight\": \"Bolder\", \"size\": \"ExtraLarge\"},";
    msg += "{\"type\": \"ColumnSet\", \"columns\": [";
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"⭐ " + IntegerToString(ta.setupQuality) + "/100\", \"size\": \"Medium\", \"color\": \"Warning\", \"weight\": \"Bolder\"}]},";
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"⏰ " + timeframeStr + "\", \"size\": \"Medium\"}]},";
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"items\": [{\"type\": \"TextBlock\", \"text\": \"" + ta.recommendation + "\", \"size\": \"Medium\", \"color\": \"Warning\", \"weight\": \"Bolder\"}]}";
    msg += "]}]}]}]},";

    // ═══════════════════════════════════════════════════════════
    // ROW 2: FVG ZONE DETECTION (3 COLUMNS) - Accent background
    // ═══════════════════════════════════════════════════════════
    msg += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"style\": \"accent\", \"bleed\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"🎯 FVG ZONE DETECTED\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    
    msg += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: Zone Top
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Zone Top\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(top, 5) + "\", \"size\": \"Large\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 2: Zone Bottom
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Zone Bottom\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(bottom, 5) + "\", \"size\": \"Large\", \"color\": \"Good\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 3: Zone Size
    double zoneSizePips = MathAbs(top - bottom) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(digits == 3 || digits == 5) zoneSizePips /= 10;
    
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Zone Size\", \"weight\": \"Bolder\", \"size\": \"Small\", \"color\": \"Accent\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(zoneSizePips, 1) + " pips\", \"size\": \"Large\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]}]}]},";

    // ═══════════════════════════════════════════════════════════
    // ROW 3: TRADE SETUP (4 COLUMNS) - Good/Attention background
    // ═══════════════════════════════════════════════════════════
    string tradeSetupStyle = (type == "BULLISH") ? "good" : "attention";
    msg += "{\"type\": \"Container\", \"spacing\": \"Medium\", \"separator\": true, \"style\": \"" + tradeSetupStyle + "\", \"bleed\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"💼 TRADE SETUP\", \"weight\": \"Bolder\", \"size\": \"Medium\", \"spacing\": \"None\"},";
    
    msg += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: Entry - Using default color for mobile compatibility
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Buy Limit\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.buyLimit, 5) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 2: Lot Size
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Lot Size 📊\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.dynamicLotSize, 2) + "\", \"size\": \"Large\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 3: Stop Loss
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Stop Loss\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.stopLoss, 5) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 4: Take Profit
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"Take Profit\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.takeProfit, 5) + "\", \"size\": \"Large\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]}]}]},";
    
    // ═══════════════════════════════════════════════════════════
    // ROW 4: RISK METRICS (3 COLUMNS) - Default background
    // ═══════════════════════════════════════════════════════════
    msg += "{\"type\": \"Container\", \"spacing\": \"Small\", \"separator\": true, \"bleed\": true, \"items\": [";
    msg += "{\"type\": \"ColumnSet\", \"columns\": [";
    
    // Column 1: Risk
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"⚠️ Risk\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.riskPips, 1) + " pips\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"$" + DoubleToString(ta.riskUSD, 2) + "\", \"spacing\": \"None\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 2: Reward
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"💰 Reward\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"" + DoubleToString(ta.rewardPips, 1) + " pips\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"$" + DoubleToString(ta.rewardUSD, 2) + "\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"}";
    msg += "]},";
    
    // Column 3: R:R
    msg += "{\"type\": \"Column\", \"width\": \"stretch\", \"separator\": true, \"items\": [";
    msg += "{\"type\": \"TextBlock\", \"text\": \"📊 R:R\", \"weight\": \"Bolder\", \"size\": \"Small\", \"horizontalAlignment\": \"Center\"},";
    msg += "{\"type\": \"TextBlock\", \"text\": \"1:" + DoubleToString(ta.actualRR, 2) + "\", \"size\": \"ExtraLarge\", \"color\": \"Warning\", \"weight\": \"Bolder\", \"spacing\": \"None\", \"horizontalAlignment\": \"Center\"}";
    msg += "]}]}]}";

    msg += "],";
    
    // --- 4. ADD ACTION BUTTON WITH SHOWCARD FOR DETAILED REPORT ---
    msg += "\"actions\": [";
    msg += "{\"type\": \"Action.ShowCard\", \"title\": \"📄 View Detailed Analysis Report\", \"card\": {";
    msg += "\"type\": \"AdaptiveCard\", \"body\": [";
    msg += reportContent;
    msg += "] } }";
    msg += "]";
    
    msg += " } }] }";

    // --- 5. SEND WEB REQUEST ---
    char data[];
    char result[];
    string result_headers;
    string headers = "Content-Type: application/json\r\n";
    ArrayResize(data, StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);
    
    int res = WebRequest("POST", TEAMS_URL, headers, 10000, data, result, result_headers);
    if(res >= 200 && res <= 299) {
        Print("+++ ✅ Signal sent successfully: ", symbol, " ", type, " | Report saved: ", filename);
    } else {
        Print("--- ❌ WebRequest Error: ", res, " | Response: ", CharArrayToString(result));
    }
}