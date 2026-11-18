//+------------------------------------------------------------------+
//|                                   Include\ZigZag\poc_analyzer.mqh|
//|                 Advanced 7-Point Confluence (PoC) Scoring Engine |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.21"

#include <ZigZag\ZigZag.mqh>
#include <ZigZag\market_structure.mqh>
#include <Arrays\ArrayString.mqh>

struct PoCResult {
    int    finalScore;      
    string recommendation;
    string reasoning;
    // Track individual PoC scores for advanced Backtest reporting
    int    p1_score;
    int    p2_score;
    int    p3_score;
    int    p4_score;
    int    p5_score;
    int    p6_score;
    int    p7_score;
    int    p8_score;
};

class CPoCAnalyzer {
private:
    double m_volThreshold;
    double m_dispThreshold;

    double GetBodySize(double open, double close) {
        return MathAbs(close - open);
    }

    bool IsInSessionTime(datetime time, string sessionStr) {
        int start = (int)StringToInteger(StringSubstr(sessionStr, 0, 4));
        int end   = (int)StringToInteger(StringSubstr(sessionStr, 5, 4));
        MqlDateTime dt; TimeToStruct(time, dt);
        int current = dt.hour * 100 + dt.min;
        if(start < end) return (current >= start && current < end);
        return (current >= start || current < end);
    }

    int EvaluateStructureSequence(ZigZag* zigZag, datetime targetTime, bool isBullish) {
        int breaks[]; ArrayResize(breaks, 0);
        double hh = -1.0, ll = -1.0;

        for(int i = 0; i < zigZag.pivots.Total(); i++) {
            Pivot* p = (Pivot*)zigZag.pivots.At(i);
            if(p.end.time > targetTime) break; 

            if(p.isHigh) {
                if(hh == -1.0 || p.end.price > hh) {
                    hh = p.end.price;
                    int s = ArraySize(breaks); ArrayResize(breaks, s + 1); breaks[s] = 1; 
                }
            } else {
                if(ll == -1.0 || p.end.price < ll) {
                    ll = p.end.price;
                    int s = ArraySize(breaks); ArrayResize(breaks, s + 1); breaks[s] = -1; 
                }
            }
        }

        int s = ArraySize(breaks);
        if (s < 5) return 0;

        int b1=breaks[s-5], b2=breaks[s-4], b3=breaks[s-3], b4=breaks[s-2], b5=breaks[s-1];

        if(isBullish) {
            if(b1==1 && b2==1 && b3==1 && b4==1 && b5==1) return 1; 
            if(b1==-1 && b2==-1 && b3==-1 && b4==1 && b5==1) return 2; 
        } else {
            if(b1==-1 && b2==-1 && b3==-1 && b4==-1 && b5==-1) return 1; 
            if(b1==1 && b2==1 && b3==1 && b4==-1 && b5==-1) return 2; 
        }
        return 0;
    }

public:
    CPoCAnalyzer() {
        m_volThreshold = 1000;   
        m_dispThreshold = 0.002; 
    }

     PoCResult EvaluateZone(bool isBullishZone, datetime zoneCreationTime, double zoneHigh, double zoneLow, 
                           int touch_index, const datetime &time[], const double &open[], const double &high[], 
                           const double &low[], const double &close[], 
                           ZigZag* zigZag, CMarketStructure* ms, 
                           double livePrice, double pipSize, 
                           ENUM_TIMEFRAMES currentTF, 
                           string lonSession = "0800-1200", string nySession = "1200-1600") 
    {
        PoCResult res;
        res.finalScore = 0; res.reasoning = "";
        
        int p1_score = 0, p2_score = 0, p3_score = 0, p4_score = 0, p5_score = 0, p6_score = 0, p7_score = 0, p8_score = 0;

        // ==========================================
        // PoC 1: Liquidity Sweep, Vol & Disp (Max 15)
        // ==========================================
        Pivot* originPivot = NULL;
        Pivot* prevSamePivot = NULL;
        int originIdx = -1;
        
        for(int p = zigZag.pivots.Total() - 1; p >= 0; p--) {
            Pivot* temp = (Pivot*)zigZag.pivots.At(p);
            if(temp.end.time == zoneCreationTime) { originPivot = temp; originIdx = p; break; }
        }
        if(originIdx >= 2) prevSamePivot = (Pivot*)zigZag.pivots.At(originIdx - 2);

        if(originPivot != NULL && prevSamePivot != NULL) {
            bool sweptLiquidity = isBullishZone ? (originPivot.end.price < prevSamePivot.end.price) 
                                                : (originPivot.end.price > prevSamePivot.end.price);
            
            double displacement = MathAbs(originPivot.end.price - originPivot.start.price);
            if(sweptLiquidity && originPivot.vol > m_volThreshold && displacement > m_dispThreshold) {
                p1_score = 15; res.reasoning += "- ✅ **Liquidity:** Swept + High Vol/Disp\\n\\n";
            } else if (sweptLiquidity) {
                p1_score = 8; res.reasoning += "- ☑️ **Liquidity:** Swept (Avg Vol)\\n\\n";
            } else {
                res.reasoning += "- ❌ **Liquidity:** No Sweep Detected\\n\\n";
            }
        } else {
            res.reasoning += "- ❌ **Liquidity:** Insufficient Historical Data\\n\\n";
        }

        // ==========================================
        // PoC 2: Approach Momentum 3-5 Bars (Max 15)
        // ==========================================
        double likelyBodySum = 0; double unlikelyBodySum = 0;
        int lookbackLimit = MathMax(0, touch_index - 5);
        int barsCounted = 0;

        for(int b = touch_index - 1; b >= lookbackLimit; b--) {
            double body = GetBodySize(open[b], close[b]);
            bool isGreen = close[b] > open[b];
            if(isBullishZone) { if(isGreen) likelyBodySum += body; else unlikelyBodySum += body; } 
            else { if(!isGreen) likelyBodySum += body; else unlikelyBodySum += body; }
            barsCounted++;
            if(barsCounted >= 3) break; 
        }

        if(unlikelyBodySum > (likelyBodySum * 2.0)) { 
            p2_score = 0; res.reasoning += "- ❌ **Momentum:** Dangerous Approach\\n\\n";
        } else if(likelyBodySum > unlikelyBodySum) { 
            p2_score = 15; res.reasoning += "- ✅ **Momentum:** Favorable Approach\\n\\n";
        } else {
            p2_score = 5; res.reasoning += "- ⚠️ **Momentum:** Neutral Approach\\n\\n";
        }

        // ==========================================
        // PoC 3: Trend & Structural Sequences (Max 20)
        // ==========================================
        int seqStatus = EvaluateStructureSequence(zigZag, zoneCreationTime, isBullishZone);
        if(seqStatus == 1) {
            p3_score = 15; res.reasoning += "- ✅ **Structure:** Backed by 5+ BOS\\n\\n";
        } else if(seqStatus == 2) {
            p3_score = 20; res.reasoning += "- 🔥 **Structure:** Smart Money Trap Detected\\n\\n";
        } else {
            p3_score = 5; res.reasoning += "- ⚠️ **Structure:** Weak Sequence\\n\\n";
        }

        // ==========================================
        // PoC 4: Zone Freshness (Max 15)
        // ==========================================
        int touches = 0;
        for(int t = touch_index - 1; t >= 0; t--) {
            if(time[t] <= zoneCreationTime) break;
            if(isBullishZone && low[t] <= zoneHigh && high[t] >= zoneLow) touches++;
            if(!isBullishZone && high[t] >= zoneLow && low[t] <= zoneHigh) touches++;
        }

        if(touches == 0) { p4_score = 15; res.reasoning += "- ✅ **Freshness:** Zone is perfectly FRESH\\n\\n"; }
        else if(touches == 1) { p4_score = 5; res.reasoning += "- ⚠️ **Freshness:** Mitigated Once\\n\\n"; }
        else { p4_score = -10; res.reasoning += "- ❌ **Freshness:** Heavily Mitigated\\n\\n"; }

        // ==========================================
        // PoC 5: Session Confluence (Max 10)
        // ==========================================
        datetime touchTime = time[touch_index];
        bool inLon = IsInSessionTime(touchTime, lonSession);
        bool inNY  = IsInSessionTime(touchTime, nySession);

        if(inLon && inNY) { p5_score = 10; res.reasoning += "- ✅ **Session:** NY & Lon Overlap\\n\\n"; } 
        else if (inLon || inNY) { p5_score = 5; res.reasoning += "- ☑️ **Session:** Single Major Session\\n\\n"; }
        else { res.reasoning += "- ⚠️ **Session:** Outside Major Sessions\\n\\n"; }

        // ==========================================
        // PoC 6: Fib Premium / Discount (Max 10)
        // ==========================================
        double maxH = -1.0; double minL = -1.0;
        for(int t = 0; t <= touch_index; t++) {
            if(time[t] >= zoneCreationTime && time[t] <= touchTime) {
                if(maxH == -1.0 || high[t] > maxH) maxH = high[t];
                if(minL == -1.0 || low[t] < minL) minL = low[t];
            }
        }
        
        if(maxH != -1.0 && minL != -1.0 && maxH > minL) {
            double midline = (maxH + minL) / 2.0;
            bool inDiscount = (zoneHigh <= midline);
            bool inPremium  = (zoneLow >= midline);
            
            if(isBullishZone && inDiscount) {
                p6_score = 10; res.reasoning += "- ✅ **Fibonacci:** Valid Discount Zone\\n\\n";
            } else if(!isBullishZone && inPremium) {
                p6_score = 10; res.reasoning += "- ✅ **Fibonacci:** Valid Premium Zone\\n\\n";
            } else {
                p6_score = 0; res.reasoning += "- ❌ **Fibonacci:** Poor Positioning\\n\\n";
            }
        }

        // ==========================================
        // PoC 7: Distance to Zone Entrance (Max 15)
        // ==========================================
        double distancePips = 0;
        if(isBullishZone) {
            distancePips = (livePrice - zoneHigh) / pipSize;
            if(distancePips < 0) distancePips = 0; 
        } else {
            distancePips = (zoneLow - livePrice) / pipSize;
            if(distancePips < 0) distancePips = 0; 
        }

        if (distancePips >= 0.0 && distancePips <= 5.0) {
            p7_score = 15; res.reasoning += "- 🎯 **Proximity:** Optimal Entrance (" + DoubleToString(distancePips, 1) + " pips)";
        } else if (distancePips <= 15.0) {
            p7_score = 5; res.reasoning += "- ⚠️ **Proximity:** Acceptable (" + DoubleToString(distancePips, 1) + " pips)";
        } else {
            p7_score = -20; res.reasoning += "- ❌ **Proximity:** Too Far (" + DoubleToString(distancePips, 1) + " pips)";
        }

        // ==========================================
        // PoC 8: HTF-LTF Trend Alignment (Max 15)
        // ==========================================
        bool htfIsBullish = (ms.trend == 1);
        bool ltfIsBullish = (currentTF <= PERIOD_H1 && ms.trend == 1); 
        
        if((isBullishZone && htfIsBullish) || (!isBullishZone && !htfIsBullish)) {
            p8_score = 15;
            res.reasoning += "- ✅ **Alignment:** HTF & LTF Trend Synergy\\n\\n";
        } else {
            p8_score = -5;
            res.reasoning += "- ⚠️ **Alignment:** Counter-Trend Alert\\n\\n";
        }

        // Link internal scores to struct
        res.p1_score = p1_score;
        res.p2_score = p2_score;
        res.p3_score = p3_score;
        res.p4_score = p4_score;
        res.p5_score = p5_score;
        res.p6_score = p6_score;
        res.p7_score = p7_score;
        res.p8_score = p8_score;

        // Final Score Calculation
        res.finalScore = p1_score + p2_score + p3_score + p4_score + p5_score + p6_score + p7_score + p8_score;
        res.finalScore = (int)MathMax(0, MathMin(100, res.finalScore));
        
        if(res.finalScore >= 80) res.recommendation = "High Probability Setup. Execution is heavily supported by confluences.";
        else if(res.finalScore >= 60) res.recommendation = "Average Setup. Consider waiting for LTF confirmation.";
        else res.recommendation = "Low Probability. Lacks crucial structural & momentum support.";

        return res;
    }
};