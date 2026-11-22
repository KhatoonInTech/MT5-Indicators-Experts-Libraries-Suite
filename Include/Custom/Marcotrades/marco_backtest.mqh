//+------------------------------------------------------------------+
//|                                  marco_backtest.mqh              |
//|                 SMC Dual-Timeframe LB & Inducement Backtester    |
//|                 Strict Wave-Touch Audit & HTF ZigZag Pivot Entry |
//|                 With Opposing Leg Filter & Dynamic TP Priorities |
//|                 With 50% TP Overlap Progress & Pure Exit SL Mode |
//|                 With Spread-Inclusive TP & Vicinity Rejection    |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "2.10"

#ifndef MARCO_BACKTEST_MQH
#define MARCO_BACKTEST_MQH

#include <Custom\Marcotrades\history_context.mqh>
#include <Custom\Marcotrades\lb_entry_clusters.mqh>
#include <Custom\Marcotrades\risk_capital.mqh>
#include <Custom\Marcotrades\trade_rejection.mqh>
#include <Custom\Marcotrades\m1_ind_entry.mqh>
#include <Custom\Marcotrades\pivot_entry.mqh>
#include <Custom\Marcotrades\lb_tf_preference.mqh>
#include <Custom\Marcotrades\broker_execution.mqh>
#include <Custom\Marcotrades\structure_exit.mqh>
#include <Custom\Marcotrades\opposing_sequence.mqh>
#include <Custom\Marcotrades\opposing_entry_wait.mqh>
#include <Custom\Marcotrades\raw_exit_context.mqh>
#include <Custom\Marcotrades\lb_extension.mqh>
#include <Custom\Marcotrades\symbol_units.mqh>
#include <Custom\Marcotrades\staged_tp.mqh>
#include <Custom\Marcotrades\liquidity_blocks.mqh>
#include <Custom\Marcotrades\Inducements.mqh>
#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\demand_supply.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\ZigZag\order_blocks.mqh>
#include <Custom\ZigZag\flipzone.mqh>
#include <Custom\ZigZag\breaker_blocks.mqh>

// Independent M1 structure context; TP timeframe must not select the entry filter's zones.
#ifndef MARCO_M1_LB_CONTEXT_DEF
#define MARCO_M1_LB_CONTEXT_DEF
class CMarcoM1LBContext
  {
private:
   CMarketStructure* ms;
   CDemandSupplyLogic* ds;
   CSwingPOILogic* sp;
   COrderBlockLogic* ob;
   CFlipZoneLogic* fz;
   CBreakerBlockLogic* bb;
   CInducementLogic* ind;
   CLiquidityBlockLogic* lbs;
   datetime times[];
   double opens[], highs[], lows[], closes[];
   string knownIds[];
   datetime availableTimes[];
   string entryPolicyIds[];
   datetime entryPolicyTimes[];
   bool applyEntryPolicyToPreventionExits;

   int KnownIndex(string id)
     {
      for(int i = 0; i < ArraySize(knownIds); i++)
         if(knownIds[i] == id)
            return i;
      return -1;
     }

   int EntryPolicyIndex(string id)
     {
      for(int i = 0; i < ArraySize(entryPolicyIds); i++)
         if(entryPolicyIds[i] == id)
            return i;
      return -1;
     }

   bool EntryPolicyReady(CLiquidityBlock* lb, datetime cutoff, datetime available)
     {
      if(!applyEntryPolicyToPreventionExits)
         return true;
      int index=EntryPolicyIndex(lb.id);
      if(index<0)
        {
         index=ArraySize(entryPolicyIds);
         ArrayResize(entryPolicyIds,index+1);
         ArrayResize(entryPolicyTimes,index+1);
         entryPolicyIds[index]=lb.id;
         entryPolicyTimes[index]=0;
        }
      if(entryPolicyTimes[index]<=0)
        {
         datetime structureTime=lbs.EntryTriggerStructureTime(lb.isBullish,lb.triggerType,
                                      lb.sweepLineTime,ind,ms,cutoff);
         if(structureTime>0)
            entryPolicyTimes[index]=available;
        }
      return entryPolicyTimes[index]>0 && entryPolicyTimes[index]<=available;
     }

public:
   CTradeRejectionHistory rejectionHistory;
   CTradeRejectionHistory rawExitHistory;
   CMarcoIndEntryFilter indEntry;
   CMarcoM1LBContext()
     {
      ms = new CMarketStructure();
      ms.Init(false, false, PERIOD_M1);
      ds = new CDemandSupplyLogic();
      sp = new CSwingPOILogic();
      ob = new COrderBlockLogic();
      fz = new CFlipZoneLogic();
      bb = new CBreakerBlockLogic();
      ind = new CInducementLogic();
      lbs = new CLiquidityBlockLogic();
      applyEntryPolicyToPreventionExits=false;
     }

   ~CMarcoM1LBContext()
     {
      delete lbs;
      delete ind;
      delete bb;
      delete fz;
      delete ob;
      delete sp;
      delete ds;
      delete ms;
     }

   void Init(bool sweeps, bool postInd, int minTouches, double proximity,
             bool strictOrigin, bool mergeClusters, double tolerance, bool expandBounds,
             bool checkDS, bool checkOB, bool checkSP, bool checkFZ, bool checkBB, double symbolPoint,
             bool applyEntryPolicy=false)
     {
      applyEntryPolicyToPreventionExits=applyEntryPolicy;
      ind.Init(minTouches, proximity, checkDS, checkOB, checkSP, checkFZ, checkBB,
               strictOrigin, mergeClusters, tolerance, expandBounds);
      lbs.Init(sweeps, postInd, symbolPoint);
     }

   void Update(datetime barTime, double open, double high, double low, double close,
               ZigZag* zz, double pipSize)
     {
      int i = ArraySize(times);
      if(zz == NULL || (i > 0 && barTime <= times[i - 1]))
         return;
      ArrayResize(times, i + 1, 2048);
      ArrayResize(opens, i + 1, 2048);
      ArrayResize(highs, i + 1, 2048);
      ArrayResize(lows, i + 1, 2048);
      ArrayResize(closes, i + 1, 2048);
      times[i] = barTime;
      opens[i] = open;
      highs[i] = high;
      lows[i] = low;
      closes[i] = close;
      ms.Update(i, times, highs, lows, closes, zz);
      ds.DetectPOIs(i, times, highs, lows, zz);
      ds.UpdateMitigation(close);
      sp.DetectPOIs(i, times, highs, lows, zz);
      sp.UpdateMitigation(close);
      ob.DetectPOIs(i, times, highs, lows, zz);
      ob.UpdateMitigation(close);
      fz.DetectFlipZones(i, times, highs, lows, closes, zz, ms, ds);
      fz.UpdateMitigation(close);
      bb.DetectBreakers(zz, ds, sp, ob, fz);
      bb.UpdateMitigation(high, low, barTime);
      ind.Process(i, times, opens, highs, lows, closes, zz, ms, ds, sp, ob, fz, bb, pipSize);
      lbs.Process(i, times, highs, lows, ms, sp, ind, zz);
      datetime available = barTime + PeriodSeconds(PERIOD_M1);
      indEntry.Begin(low,high);
      for(int z=0;z<ind.m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)ind.m_zones.At(z);
         if(zone!=NULL && zone.isInducement && !zone.isMitigated)
            indEntry.Zone(zone.id,zone.isBullish,zone.zoneLow,zone.zoneHigh,available);
        }
      indEntry.End(available);
      int eventCount = ms.all_event_names.Total();
      for(int e=MathMax(0,eventCount-3);e<eventCount;e++)
         indEntry.Observe(ms.all_event_names.At(e),(datetime)ms.all_event_times.At(e),available);
      // Renaming can change either of the previous two events as well as the newest one.
      for(int e=MathMax(0,eventCount-3);e<eventCount;e++)
         rejectionHistory.Observe(ms.all_event_names.At(e), (datetime)ms.all_event_times.At(e),
                                  available, (datetime)ms.all_event_origin_times.At(e), ms.all_event_origin_prices.At(e),
                                  ms.all_event_prices.At(e));
      rejectionHistory.BeginZones();
      // An IND-vetoed source can protect against opposing entries after its
      // structural gate qualifies; it remains unavailable as an entry setup.
      for(int b=0;b<lbs.m_exit_sources.Total();b++)
        {
         CLiquidityBlock* source=(CLiquidityBlock*)lbs.m_exit_sources.At(b);
         if(lbs.GuardSourceReady(source,ind,ms,barTime,available,applyEntryPolicyToPreventionExits))
            rejectionHistory.Zone(source.id,source.isBullish,source.zoneLow,source.zoneHigh,source.createdTime,
                                  source.mitigationTime,source.causalChochTime,available,true);
        }
      for(int b = 0; b < lbs.m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs.m_liquidity_blocks.At(b);
         if(lb != NULL && EntryPolicyReady(lb,barTime,available))
            rejectionHistory.Zone(lb.id, lb.isBullish, lb.zoneLow, lb.zoneHigh, lb.createdTime,
                                  lb.mitigationTime, lb.causalChochTime, available);
        }
      rejectionHistory.EndZones(available);
      CMarcoRawExitHistory::Capture(ms,lbs,available,rawExitHistory);
      // A zone's origin can predate its confirmation. Never backdate its availability.
      for(int b = 0; b < lbs.m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs.m_liquidity_blocks.At(b);
         if(lb == NULL || KnownIndex(lb.id) >= 0)
            continue;
         int n = ArraySize(knownIds);
         ArrayResize(knownIds, n + 1);
         ArrayResize(availableTimes, n + 1);
         knownIds[n] = lb.id;
         availableTimes[n] = barTime + PeriodSeconds(PERIOD_M1);
        }
     }

   bool FindOpposingOrigin(bool candidateIsBull, datetime originTime, double originPrice,
                           datetime now, double buffer, string &opposingId)
     {
      opposingId = "";
      for(int b = 0; b < lbs.m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs.m_liquidity_blocks.At(b);
         if(lb == NULL || lb.isBullish == candidateIsBull)
            continue;
         int known = KnownIndex(lb.id);
         if(known < 0 || availableTimes[known] > now)
            continue;
         int policy=EntryPolicyIndex(lb.id);
         if(applyEntryPolicyToPreventionExits &&
            (policy<0 || entryPolicyTimes[policy]<=0 || entryPolicyTimes[policy]>now))
            continue;
         // Match the existing origin rule, using M1 for the mitigation candle.
         if(CTradeRejection::OriginInside(originTime, originPrice, lb.createdTime, lb.mitigationTime,
                                           PeriodSeconds(PERIOD_M1), lb.zoneLow, lb.zoneHigh, buffer))
           {
            opposingId = lb.id;
            return true;
           }
        }
      return false;
     }
  };
#endif

#ifndef ENUM_TP_PRIORITY_DEF
#define ENUM_TP_PRIORITY_DEF
enum ENUM_TP_PRIORITY
  {
   TP_PRIORITY_LB,       // Opposing LB (Liquidity Block)
   TP_PRIORITY_IND,      // Opposing IND (Inducement)
   TP_PRIORITY_FALLBACK  // Fallback R:R
  };
#endif

#ifndef ENUM_MARCO_ENTRY_TF_DEF
#define ENUM_MARCO_ENTRY_TF_DEF
enum ENUM_MARCO_ENTRY_TF
  {
   ENTRY_TF_M1 = 1, // M1
   ENTRY_TF_LB = 0  // LB TF
  };
#endif

#ifndef ENUM_SL_LOCATION_DEF
#define ENUM_SL_LOCATION_DEF
enum ENUM_SL_LOCATION
  {
   SL_LOCATION_LB_BOUNDARIES,     // LB boundaries
   SL_LOCATION_CONFIRM_PIVOT      // Confirmation pivot
  };
#endif

struct SSimulatedTrade
  {
   SMarcoTPPlan       tpPlan;
   SMarcoExtensionState extension;
   ulong             ticket;
   string            symbol;
   string            setupType;
   int               direction;

   datetime          openTime;
   double            openPrice;
   double            slPrice;
   double            tpPrice;

   double            lots;
   double            riskAmount;

   bool              isOpen;
   datetime          closeTime;
   double            closePrice;
   double            realizedProfit;
   string            outcome;

   // First-bar execution segment for a pivot-edge fill in OHLC replay.
   bool              edgeIntrabar;
   double            edgeBid, edgeHigh, edgeLow;

   // Vicinity Engine State
   bool              hasEnteredVicinity;
  };

// First availability of each confirmed pivot in this engine's chronological stream.
struct SBacktestPivotConfirmation
  {
   datetime pivotTime;
   double   price;
   bool     isHigh;
   datetime availableTime;
  };

struct SBacktestHTFLB
  {
   string            id;
   bool              isBullish;
   ENUM_LB_TRIGGER   triggerType;
   double            zoneHigh;
   double            zoneLow;
   datetime          createdTime;
   datetime          confirmedTime;
   datetime          entryTriggerTime; // Entry-only gate; policy depends on the LB trigger type.
   datetime          opposingRejectedAt; // Opposing-structure rejection, distinct from a filled trade.
   string            preferredLTF; // Diagnostic only; does not retire the HTF setup.
   bool              sourceActive; // Still present in the authoritative LB engine.
   datetime          firstTouchTime;
   datetime          m1TouchTime;
   SMarcoIndWait     indWait;
   SMarcoPivotEntry  pivotEntry;
   SMarcoPivotWatch  pivotWatch;
   SMarcoOpposingEntryWait opposingWait;
   datetime          rejectionTouchTime;
   datetime          rejectionHTFTouchTime;
   datetime          m1PivotTime;
   double            m1PivotPrice;
   datetime          m1ConfirmTime;
   datetime          sweepLineTime;
   datetime          inducementOriginTime;
   int               touchCount;
   bool              isMitigated;
   datetime          mitigationTime;
   string            nomenclature;
  };

struct SBacktestGlobalTrade
  {
   string            symbol;
   datetime          openTime;
   datetime          closeTime;
   double            openPrice;
   double            tpPrice;
   int               direction;
   int setupTF;
   ulong ticket;
  };

//+------------------------------------------------------------------+
//| Class CMarcoBacktestInstance                                     |
//+------------------------------------------------------------------+
class CMarcoSimulationState
  {
public:
   datetime startTime, endTime, htf_time[], ltf_time[], run_time[];
   double htf_open[], htf_high[], htf_low[], htf_close[], ltf_open[], ltf_high[], ltf_low[], ltf_close[], run_open[], run_high[], run_low[], run_close[], pipSize, point, spreadVal;
   long htf_vol[], ltf_vol[], run_vol[];
   int htf_copy, ltf_copy, run_copy, digits, rejectionCount, nextRejection, nextHtf, nextTp, nextBar;
   MqlRates rejectionRates[];
   ZigZag* zzHtf;
   ZigZag* zzLtf;
   CMarketStructure* msHtf;
   CMarketStructure* msLtf;
   CDemandSupplyLogic* dsHtf;
   CDemandSupplyLogic* dsLtf;
   CSwingPOILogic* spHtf;
   CSwingPOILogic* spLtf;
   COrderBlockLogic* obHtf;
   COrderBlockLogic* obLtf;
   CFlipZoneLogic* fzHtf;
   CFlipZoneLogic* fzLtf;
   CBreakerBlockLogic* bbHtf;
   CBreakerBlockLogic* bbLtf;
   CInducementLogic* indHtf;
   CInducementLogic* indLtf;
   CLiquidityBlockLogic* lbLogicHtf;
   CLiquidityBlockLogic* lbLogicLtf;
   bool prepared;
   CMarcoSimulationState() { prepared=false; zzHtf=NULL; zzLtf=NULL; msHtf=NULL; msLtf=NULL; dsHtf=NULL; dsLtf=NULL; spHtf=NULL; spLtf=NULL; obHtf=NULL; obLtf=NULL; fzHtf=NULL; fzLtf=NULL; bbHtf=NULL; bbLtf=NULL; indHtf=NULL; indLtf=NULL; lbLogicHtf=NULL; lbLogicLtf=NULL; nextBar=1; }
   ~CMarcoSimulationState() { if(CheckPointer(zzHtf)==POINTER_DYNAMIC) delete zzHtf; if(CheckPointer(zzLtf)==POINTER_DYNAMIC) delete zzLtf; if(CheckPointer(msHtf)==POINTER_DYNAMIC) delete msHtf; if(CheckPointer(msLtf)==POINTER_DYNAMIC) delete msLtf; if(CheckPointer(dsHtf)==POINTER_DYNAMIC) delete dsHtf; if(CheckPointer(dsLtf)==POINTER_DYNAMIC) delete dsLtf; if(CheckPointer(spHtf)==POINTER_DYNAMIC) delete spHtf; if(CheckPointer(spLtf)==POINTER_DYNAMIC) delete spLtf; if(CheckPointer(obHtf)==POINTER_DYNAMIC) delete obHtf; if(CheckPointer(obLtf)==POINTER_DYNAMIC) delete obLtf; if(CheckPointer(fzHtf)==POINTER_DYNAMIC) delete fzHtf; if(CheckPointer(fzLtf)==POINTER_DYNAMIC) delete fzLtf; if(CheckPointer(bbHtf)==POINTER_DYNAMIC) delete bbHtf; if(CheckPointer(bbLtf)==POINTER_DYNAMIC) delete bbLtf; if(CheckPointer(indHtf)==POINTER_DYNAMIC) delete indHtf; if(CheckPointer(indLtf)==POINTER_DYNAMIC) delete indLtf; if(CheckPointer(lbLogicHtf)==POINTER_DYNAMIC) delete lbLogicHtf; if(CheckPointer(lbLogicLtf)==POINTER_DYNAMIC) delete lbLogicLtf; }
  };

class CMarcoBacktestInstance
  {
public:
   static SBacktestGlobalTrade s_global_trades[];
   static CMarcoLBEntryClusters s_clusters;
   CMarcoSimulationState *m_sim;
   bool m_simComplete, m_simFailed;
   datetime NextSimulationTime() { return m_sim==NULL || m_simComplete ? 0 : (m_sim.nextBar<m_sim.run_copy ? m_sim.run_time[m_sim.nextBar] : m_sim.endTime); }

   static void       ResetGlobalTrades()
     {
      ArrayResize(s_global_trades, 0);
      s_clusters.Clear();
      CMarcoLBTFPreference::Clear();
     }

   string            m_symbol;
   ENUM_TIMEFRAMES   m_tradeTF;
   ENUM_TIMEFRAMES   m_tpTF;
   ENUM_MARCO_ENTRY_TF m_entryTF;
   ZigZag*           zzEntry;
   CMarcoM1LBContext* m1LBContext;
   CMarcoIndEntryFilter m_setupIndEntry;
   CTradeRejectionHistory m_htfRejection;
   CTradeRejectionHistory m_htfRawExit;
   int               m_entryBarCount;
   datetime          m_last_entry_bar;
   double m_last_entry_close;

   double            m_startCapital;
   double            m_currentBalance;
   double            m_riskPercent;
   double            m_slBufferPips;
   bool              m_requireZZConfirmation;
   bool              m_riskyMode;
   bool              m_applyEntryPolicyToPreventionExits;
   bool              m_useFallbackTP;
   double            m_fallbackRR;
   bool              m_blockLessRR;
   ENUM_TP_PRIORITY  m_tpPriority1;
   bool              m_allowOverlappingTrades;
   ENUM_SL_LOCATION  m_slLocation;

   // Take Profit Protection & Execution Controls
   bool              m_adjustTPForSpread;
   bool              m_enableVicinityExit;
   double            m_tpVicinityPips;
   ENUM_TIMEFRAMES    m_tpVicinityTF;

   int               m_zzDepth;
   double            m_zzDev;
   string            m_priceDiff;
   datetime          m_startWindow;
   datetime          m_endWindow;

   SSimulatedTrade   m_trades[];
   ulong             m_ticketCounter;

   int               m_wins;
   int               m_losses;
   double            m_totalLots;
   double            m_totalRewards;

   SBacktestHTFLB    m_htf_lbs[];
   int               m_htf_lb_count;

                     CMarcoBacktestInstance()
     {
      m_sim=NULL; m_simComplete=false; m_simFailed=false;
      m_entryTF = ENTRY_TF_LB;
      zzEntry = NULL;
      m1LBContext = NULL;
      m_entryBarCount = 0;
      m_last_entry_bar = 0; m_last_entry_close=0;
      m_ticketCounter          = 1000;
      m_blockLessRR            = true;
      m_tpPriority1            = TP_PRIORITY_IND;
      m_allowOverlappingTrades = false;
      m_slLocation             = SL_LOCATION_LB_BOUNDARIES;
      m_adjustTPForSpread      = true;
      m_enableVicinityExit     = true;
      m_tpVicinityPips         = 1.0;
      m_tpVicinityTF           = PERIOD_M1;
      m_applyEntryPolicyToPreventionExits = false;
     }

                    ~CMarcoBacktestInstance() { if(CheckPointer(m_sim)==POINTER_DYNAMIC) delete m_sim; if(CheckPointer(m1LBContext) == POINTER_DYNAMIC) delete m1LBContext; if(CheckPointer(zzEntry) == POINTER_DYNAMIC) delete zzEntry; }

   void              Init(string sym, ENUM_TIMEFRAMES trdTF, ENUM_TIMEFRAMES tpTF, double capital, double riskPct, double slPips,
                          int zzDep, double zzDev, datetime startWindow, datetime endWindow,
                          bool requireZZConf = true, bool riskyMode = false,
                          bool useFallbackTP = true, double fallbackRR = 2.0, string priceDiff = "Percent",
                          bool blockLessRR = true, ENUM_TP_PRIORITY tpPriority1 = TP_PRIORITY_IND,
                          bool allowOverlapping = false, ENUM_SL_LOCATION slLocation = SL_LOCATION_LB_BOUNDARIES,
                          bool adjustTPForSpread = true, bool enableVicinityExit = true, double tpVicinityPips = 1.0, ENUM_MARCO_ENTRY_TF entryTF = ENTRY_TF_LB,
                          ENUM_TIMEFRAMES tpVicinityTF = PERIOD_M1,
                          bool applyEntryPolicyToPreventionExits = false)
     {
      m_symbol                 = sym;
      m_tradeTF                = trdTF;
      m_tpTF                   = PERIOD_M1; // Staged structural targets are always M1.
      m_entryTF                = entryTF;
      m_startCapital           = capital;
      m_currentBalance         = capital;
      m_riskPercent            = riskPct;
      m_slBufferPips           = slPips;
      m_zzDepth                = zzDep;
      m_zzDev                  = zzDev;
      m_requireZZConfirmation  = requireZZConf;
      m_riskyMode              = riskyMode;
      m_applyEntryPolicyToPreventionExits = applyEntryPolicyToPreventionExits;
      m_useFallbackTP          = useFallbackTP;
      m_fallbackRR             = fallbackRR;
      m_blockLessRR            = blockLessRR;
      m_tpPriority1            = tpPriority1;
      m_allowOverlappingTrades = allowOverlapping;
      m_slLocation             = slLocation;
      m_priceDiff              = priceDiff;
      m_startWindow            = startWindow;
      m_endWindow              = endWindow;
      m_wins                   = 0;
      m_losses                 = 0;
      m_totalLots              = 0.0;
      m_totalRewards           = 0.0;
      m_htf_lb_count           = 0;

      m_adjustTPForSpread      = adjustTPForSpread;
      m_enableVicinityExit     = enableVicinityExit;
      m_tpVicinityPips         = tpVicinityPips;
      m_tpVicinityTF           = tpVicinityTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : tpVicinityTF;

      ArrayResize(m_htf_lbs, 0);
      ArrayResize(m_trades, 0);
     }

   SBacktestPivotConfirmation m_pivotConfirmations[];

   void              CapturePivotConfirmations(ZigZag* zz, datetime availableTime)
     {
      int oldSize = ArraySize(m_pivotConfirmations);
      int count = zz.pivots.Total();
      ArrayResize(m_pivotConfirmations, count);
      for(int p = 0; p < count; p++)
        {
         Pivot* pv = (Pivot*)zz.pivots.At(p);
         if(pv == NULL || pv == zz.projection || StringFind(pv.ln, "ZZ_Proj") >= 0)
           {
            m_pivotConfirmations[p].availableTime = 0;
            continue;
           }
         if(p >= oldSize || m_pivotConfirmations[p].availableTime == 0 ||
            m_pivotConfirmations[p].pivotTime != pv.end.time ||
            m_pivotConfirmations[p].price != pv.end.price ||
            m_pivotConfirmations[p].isHigh != pv.isHigh)
           {
            m_pivotConfirmations[p].pivotTime = pv.end.time;
            m_pivotConfirmations[p].price = pv.end.price;
            m_pivotConfirmations[p].isHigh = pv.isHigh;
            m_pivotConfirmations[p].availableTime = availableTime;
           }
        }
     }

   SBacktestPivotConfirmation m_m1PivotConfirmations[];

   void              CaptureM1PivotConfirmations(ZigZag* zz, datetime availableTime)
     {
      int oldSize = ArraySize(m_m1PivotConfirmations);
      int count = zz.pivots.Total();
      ArrayResize(m_m1PivotConfirmations, count);
      for(int p = 0; p < count; p++)
        {
         Pivot* pv = (Pivot*)zz.pivots.At(p);
         if(pv == NULL || pv == zz.projection || StringFind(pv.ln, "ZZ_Proj") >= 0)
           {
            m_m1PivotConfirmations[p].availableTime = 0;
            continue;
           }
         if(p >= oldSize || m_m1PivotConfirmations[p].availableTime == 0 ||
            m_m1PivotConfirmations[p].pivotTime != pv.end.time ||
            m_m1PivotConfirmations[p].price != pv.end.price ||
            m_m1PivotConfirmations[p].isHigh != pv.isHigh)
           {
            m_m1PivotConfirmations[p].pivotTime = pv.end.time;
            m_m1PivotConfirmations[p].price = pv.end.price;
            m_m1PivotConfirmations[p].isHigh = pv.isHigh;
            m_m1PivotConfirmations[p].availableTime = availableTime;
           }
        }
     }

   void              ResetM1EntryEngine()
     {
      m_htfRejection.Reset();
      m_setupIndEntry.Clear();
      m_htfRawExit.Reset();
      if(CheckPointer(m1LBContext) == POINTER_DYNAMIC)
         delete m1LBContext;
      if(CheckPointer(zzEntry) == POINTER_DYNAMIC)
         delete zzEntry;
      zzEntry = NULL;
      m1LBContext = NULL;
      m_entryBarCount = 0;
      m_last_entry_bar = 0; m_last_entry_close=0;
      ArrayResize(m_m1PivotConfirmations, 0);
      // Observe M1 rejection context in both entry modes.
      Settings* entrySettings = new Settings(m_zzDev, m_zzDepth, clrNONE, false, false, false, false, m_priceDiff);
      entrySettings.draw = false;
      zzEntry = newInstance(entrySettings);
      zzEntry.zoneStartTime = m_startWindow;
     }

   void              FeedM1EntryBar(datetime barTime, double open, double high, double low, double close, long volume)
     {
      if(zzEntry == NULL || barTime <= m_last_entry_bar)
         return;
      if(m_applyEntryPolicyToPreventionExits)
         for(int k=0;k<m_htf_lb_count;k++) ObserveOpposingEntryBar(k,barTime,open,high,low,close);
      zzEntry.update(high, low, barTime, volume, m_entryBarCount++, true, false);
      if(m1LBContext != NULL)
         m1LBContext.Update(barTime, open, high, low, close, zzEntry, GetPipSize(m_symbol));
      CaptureM1PivotConfirmations(zzEntry, barTime + PeriodSeconds(PERIOD_M1));
      m_last_entry_bar = barTime; m_last_entry_close=close;
      if(m_applyEntryPolicyToPreventionExits)
         for(int k=0;k<m_htf_lb_count;k++)
            ObserveOpposingEntry(k,barTime+60,close,close,barTime+60,PERIOD_M1);
      if(CMarcoPivotEntry::Enabled())
         for(int k=0;k<m_htf_lb_count;k++)
           {
            if(m_htf_lbs[k].opposingWait.required || ObservePivotEntryRange(k,barTime,low,high)) continue;
            datetime pivot=0,confirmed=0; double price=0;
            if(m_entryTF==ENTRY_TF_M1 && m_htf_lbs[k].m1TouchTime>0)
               GetLatestEntryPivot(k,barTime+PeriodSeconds(PERIOD_M1),zzEntry,true,pivot,price,confirmed);
           }
      if(m1LBContext != NULL)
         AuditChochTouches(barTime, low, high, barTime + PeriodSeconds(PERIOD_M1), zzEntry,
                          PERIOD_M1, m1LBContext.rejectionHistory);
      // Latch the first eligible pivot before a later catch-up candle can replace it.
      for(int k = 0; k < m_htf_lb_count; k++)
        {
         if(m_htf_lbs[k].entryTriggerTime <= 0)
            continue;
         if(CheckIndWaitBoundary(k,barTime+PeriodSeconds(PERIOD_M1),low,high)) continue;
         if(m_entryTF != ENTRY_TF_M1) continue;
         if(m_htf_lbs[k].m1TouchTime == 0 || m_htf_lbs[k].m1ConfirmTime != 0 ||
            CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated))
            continue;
         datetime pivotTime = 0, confirmTime = 0;
         double pivotPrice = 0.0;
         GetM1EntryPivot(k, barTime + PeriodSeconds(PERIOD_M1), pivotTime, pivotPrice, confirmTime);
        }
     }

   void              ArmM1Entry(int k, datetime sampleTime, double sampleLow, double sampleHigh)
     {
      if(m_entryTF != ENTRY_TF_M1 || m_htf_lbs[k].m1TouchTime != 0 ||
         m_htf_lbs[k].entryTriggerTime <= 0 ||
         CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated) ||
         sampleTime < m_htf_lbs[k].entryTriggerTime + PeriodSeconds(m_tradeTF))
         return;
      double pip = GetPipSize(m_symbol); // Exactly one pip, independent of the SL buffer.
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      bool near = CTradeRejection::NearEntry(m_htf_lbs[k].isBullish, sampleLow, sampleHigh,
                            m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh, pip, digits);
      if(!near)
         return;
      m_htf_lbs[k].m1TouchTime = sampleTime;
      PrintFormat("[M1 ARMED] %s %s LB=%s touch=%s zone=[%.8f, %.8f]",
                  m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id, TimeToString(sampleTime, TIME_DATE|TIME_SECONDS),
                  m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh);
     }

   void CaptureRejectionContext(CMarketStructure* ms, CLiquidityBlockLogic* lbs, CInducementLogic* inducements,
                                datetime available, CTradeRejectionHistory &history)
     {
      int n = ms.all_event_names.Total();
      for(int e=MathMax(0,n-3);e<n;e++)
         history.Observe(ms.all_event_names.At(e), (datetime)ms.all_event_times.At(e),
                         available, (datetime)ms.all_event_origin_times.At(e), ms.all_event_origin_prices.At(e),
                         ms.all_event_prices.At(e));
      history.BeginZones();
      // Structural qualification and the source's own entry veto are independent.
      for(int b=0;b<lbs.m_exit_sources.Total();b++)
        {
         CLiquidityBlock* source=(CLiquidityBlock*)lbs.m_exit_sources.At(b);
         if(lbs.GuardSourceReady(source,inducements,ms,available-PeriodSeconds(m_tradeTF),
                                 available,m_applyEntryPolicyToPreventionExits))
            history.Zone(source.id,source.isBullish,source.zoneLow,source.zoneHigh,source.createdTime,
                         source.mitigationTime,source.causalChochTime,available,true);
        }
      for(int b = 0; b < lbs.m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbs.m_liquidity_blocks.At(b);
         int cached=(lb==NULL ? -1 : FindCachedLB(lb.id));
         if(lb != NULL && (!m_applyEntryPolicyToPreventionExits ||
                           (cached>=0 && m_htf_lbs[cached].entryTriggerTime>0 && m_htf_lbs[cached].sourceActive)))
            history.Zone(lb.id, lb.isBullish, lb.zoneLow, lb.zoneHigh, lb.createdTime,
                         lb.mitigationTime, lb.causalChochTime, available);
        }
      history.EndZones(available);
      CMarcoRawExitHistory::Capture(ms,lbs,available,m_htfRawExit);
     }

   SMarcoSequenceSignal ObserveOpposingSequence(SMarcoTPPlan &plan, datetime opened, datetime now, double price)
     {
      SMarcoSequenceSignal signal; ZeroMemory(signal);
      if(m1LBContext!=NULL && CMarcoOpposingEntryWait::FailedEntry(m1LBContext.rawExitHistory,plan,opened,now,price,signal))
        {
         PrintFormat("[ENTRY CHOCH FAILED] entry_event=%s reversal=%s region=SL close=100%%",
                     TimeToString(plan.reversalEntryEvent,TIME_DATE|TIME_SECONDS),TimeToString(signal.eventTime,TIME_DATE|TIME_SECONDS));
         return signal;
        }
      bool preferM1=m_entryTF==ENTRY_TF_M1;
      // A full pre-entry continuation on either TF takes precedence over
      // starting an ordinary post-entry partial on the other TF in this cycle.
      if(plan.sequence.step==0 && !plan.sequence.pending)
         for(int pass=0;pass<2;pass++)
           {
            bool m1=(pass==0 ? preferM1 : !preferM1);
            if(m1)
              {
               if(m1LBContext==NULL || m_tradeTF==PERIOD_M1) continue;
               if(CMarcoOpposingSequence::PreEntryContinuation(m1LBContext.rawExitHistory,1,PERIOD_M1,
                     plan.direction,plan.entry,price,opened,now,plan.sequence,signal)) return signal;
              }
            else if(CMarcoOpposingSequence::PreEntryContinuation(m_htfRawExit,0,m_tradeTF,
                     plan.direction,plan.entry,price,opened,now,plan.sequence,signal)) return signal;
           }
      for(int pass=0;pass<2;pass++)
        {
         bool m1=(pass==0 ? preferM1 : !preferM1);
         if(m1)
           {
            if(m1LBContext==NULL || m_tradeTF==PERIOD_M1) continue;
            signal=CMarcoOpposingSequence::Advance(m1LBContext.rawExitHistory,plan.sequence,1,PERIOD_M1,
                                                  plan.direction,plan.entry,price,opened,now,false);
           }
         else signal=CMarcoOpposingSequence::Advance(m_htfRawExit,plan.sequence,0,m_tradeTF,
                                                     plan.direction,plan.entry,price,opened,now,false);
         if(signal.step>0 || plan.sequence.step>=2) break;
        }
      return signal;
     }

   void ObserveRejectionTouch(int k, datetime sampleBar, double low, double high, datetime knownAt, ENUM_TIMEFRAMES tf)
     {
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated) ||
         sampleBar < m_htf_lbs[k].confirmedTime + PeriodSeconds(m_tradeTF)) return;
      if(!CTradeRejection::Intersects(low, high, m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh)) return;
      // Independent clocks prevent an HTF catch-up bar from hiding earlier M1 touches.
      if(tf == PERIOD_M1)
         m_htf_lbs[k].rejectionTouchTime = MathMax(m_htf_lbs[k].rejectionTouchTime, knownAt);
      else
         m_htf_lbs[k].rejectionHTFTouchTime = MathMax(m_htf_lbs[k].rejectionHTFTouchTime, knownAt);
     }

   void ObserveOpposingEntry(int k,datetime sampleBar,double low,double high,datetime now,ENUM_TIMEFRAMES tf)
     {
      if(!m_applyEntryPolicyToPreventionExits || !m_htf_lbs[k].sourceActive ||
         CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated) ||
         m_htf_lbs[k].entryTriggerTime<=0 ||
         sampleBar<m_htf_lbs[k].entryTriggerTime+PeriodSeconds(m_tradeTF)) return;
      double buffer=m_slBufferPips*GetPipSize(m_symbol);
      SMarcoOpposingEntryWait state=m_htf_lbs[k].opposingWait;
      if(state.waiting && now<state.since) return;
      // A reversal may close beyond the band after its swing formed inside it.
      // Retain this wait while the setup is valid; Resolve checks that exact swing.
      if(state.waiting || !CTradeRejection::Intersects(low,high,m_htf_lbs[k].zoneLow-buffer,m_htf_lbs[k].zoneHigh+buffer)) return;
      bool armed=false;
      if(tf==PERIOD_M1 && m1LBContext!=NULL)
         armed=CMarcoOpposingEntryWait::Begin(state,m1LBContext.rawExitHistory,m_htf_lbs[k].isBullish,now,PERIOD_M1);
      else if(tf==m_tradeTF)
         armed=CMarcoOpposingEntryWait::Begin(state,m_htfRawExit,m_htf_lbs[k].isBullish,now,m_tradeTF);
      if(!armed) return;
      m_htf_lbs[k].opposingWait=state;
      ZeroMemory(m_htf_lbs[k].pivotEntry); ZeroMemory(m_htf_lbs[k].pivotWatch);
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
      PrintFormat("[OPPOSING LB WAIT] %s %s LB=%s source=%s opposing=%s since=%s; awaiting fresh M1 %s with swing inside setup+SL-buffer.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,EnumToString((ENUM_TIMEFRAMES)state.sourceTF),
                  state.sourceId,TimeToString(now,TIME_DATE|TIME_SECONDS),m_htf_lbs[k].isBullish ? "BL-CHoCH" : "BR-CHoCH");
     }

   // Reconstruct a closed M1 candle using the simulator's existing OHLC path.
   // Consult pre-candle histories so a touch before its closing CHoCH is not lost.
   void ObserveOpposingEntryBar(int k,datetime barTime,double open,double high,double low,double close)
     {
      if(!m_applyEntryPolicyToPreventionExits || m_htf_lbs[k].opposingWait.since>barTime) return;
      double prices[4]; prices[0]=open; prices[1]=close>=open ? low : high;
      prices[2]=close>=open ? high : low; prices[3]=close;
      double buffer=m_slBufferPips*GetPipSize(m_symbol);
      double bottom=m_htf_lbs[k].zoneLow-buffer,top=m_htf_lbs[k].zoneHigh+buffer;
      for(int p=0;p<4;p++)
        {
         if(p>0 && (prices[p-1]<bottom || prices[p-1]>top) &&
            MathMin(prices[p-1],prices[p])<=top && MathMax(prices[p-1],prices[p])>=bottom)
           {
            double crossing=prices[p-1]<bottom ? bottom : top;
            ObserveOpposingEntry(k,barTime,crossing,crossing,barTime,m_tradeTF);
            ObserveOpposingEntry(k,barTime,crossing,crossing,barTime,PERIOD_M1);
           }
         ObserveOpposingEntry(k,barTime,prices[p],prices[p],barTime,m_tradeTF);
         ObserveOpposingEntry(k,barTime,prices[p],prices[p],barTime,PERIOD_M1);
        }
     }

   bool ResolveOpposingEntry(int k,datetime now,double executionPrice,SRejectionEvent &event)
     {
      if(!m_applyEntryPolicyToPreventionExits || m1LBContext==NULL || zzEntry==NULL ||
         !m_htf_lbs[k].sourceActive || CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return false;
      double buffer=m_slBufferPips*GetPipSize(m_symbol);
      if(!CMarcoOpposingEntryWait::Ready(m_htf_lbs[k].opposingWait,m1LBContext.rawExitHistory,
            m_htf_lbs[k].isBullish,now,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,buffer,event) ||
         event.time!=m_last_entry_bar || !MathIsValidNumber(executionPrice) || executionPrice<=0) return false;
      // Confirm the exact swing still exists; do not enter on a replaced pivot.
      for(int p=zzEntry.pivots.Total()-1;p>=0;p--)
        {
         Pivot* pivot=(Pivot*)zzEntry.pivots.At(p);
         if(pivot==NULL || pivot==zzEntry.projection || pivot.end==NULL || StringFind(pivot.ln,"ZZ_Proj")>=0) continue;
         if(pivot.isHigh==m_htf_lbs[k].isBullish || pivot.end.time!=event.originTime) continue;
         return MathAbs(pivot.end.price-event.originPrice)<=SymbolInfoDouble(m_symbol,SYMBOL_POINT)*0.1;
        }
      return false;
     }

   bool CheckChochRejection(int k, datetime now, ZigZag* zz, ENUM_TIMEFRAMES tf,
                            CTradeRejectionHistory &history, bool diagnostics = false)
     {
      if(m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required) return false;
      datetime touch = tf == PERIOD_M1 ? m_htf_lbs[k].rejectionTouchTime : m_htf_lbs[k].rejectionHTFTouchTime;
      if(zz == NULL)
        {
         if(diagnostics) Print("[CHOCH AUDIT] decision=ALLOW reason=MISSING_ZIGZAG_CONTEXT");
         return false;
        }
      if(!diagnostics && (touch == 0 ||
         CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated))) return false;
      // In M1 entry mode the actual touching leg belongs to M1. The history below
      // still belongs to tf (LB TF or M1); an unconfirmed LB-TF swing must not bypass it.
      ZigZag* legZZ = (m_entryTF == ENTRY_TF_M1 && zzEntry != NULL) ? zzEntry : zz;
      ENUM_TIMEFRAMES legTF = (m_entryTF == ENTRY_TF_M1 && zzEntry != NULL) ? PERIOD_M1 : tf;
      datetime legTouch = (m_entryTF == ENTRY_TF_M1 && m_htf_lbs[k].m1TouchTime > 0) ?
                          m_htf_lbs[k].m1TouchTime : touch;
      datetime selectedPivot = (m_entryTF == ENTRY_TF_M1 && m_htf_lbs[k].m1ConfirmTime > 0) ?
                               m_htf_lbs[k].m1PivotTime : 0;
      datetime origin = 0, legEnd = 0;
      for(int p = legZZ.pivots.Total()-1; p >= 0; p--)
        {
         Pivot* pv = (Pivot*)legZZ.pivots.At(p);
         if(pv == NULL || pv == legZZ.projection || pv.end == NULL || StringFind(pv.ln, "ZZ_Proj") >= 0) continue;
         if(selectedPivot > 0 && pv.end.time != selectedPivot) continue;
         if(diagnostics)
            PrintFormat("[CHOCH AUDIT] source=%s leg_tf=%s latest_pivot=%s is_high=%s leg_start=%s",
                        EnumToString(tf), EnumToString(legTF), TimeToString(pv.end.time, TIME_DATE|TIME_SECONDS), pv.isHigh ? "true" : "false",
                        pv.start == NULL ? "none" : TimeToString(pv.start.time, TIME_DATE|TIME_SECONDS));
         if(pv.isHigh == m_htf_lbs[k].isBullish)
            origin = pv.end.time;
         // M1 confirmation may close several candles after the touch; retain its selected leg.
         else if(pv.start != NULL &&
                 ((m_entryTF == ENTRY_TF_M1 && (selectedPivot > 0 ||
                   pv.end.time >= legTouch - legTouch % PeriodSeconds(legTF))) ||
                  (m_entryTF != ENTRY_TF_M1 && pv.end.time + PeriodSeconds(tf) >= touch)))
           { origin = pv.start.time; legEnd = pv.end.time; }
         break;
        }
      STradeRejection result = history.OpposingChoch(m_htf_lbs[k].isBullish, origin, legEnd,
                        touch, now, tf, m_slBufferPips * GetPipSize(m_symbol), diagnostics);
      // Entry audit is read-only, including when the setup has already been consumed.
      if(diagnostics) return result.action == TRADE_RETIRE_ZONE;
      if(result.action != TRADE_RETIRE_ZONE) return false;
      if(m_applyEntryPolicyToPreventionExits)
        {
         m_htf_lbs[k].opposingWait.required=true; m_htf_lbs[k].opposingWait.waiting=true;
         m_htf_lbs[k].opposingWait.since=now; m_htf_lbs[k].opposingWait.sourceEvent=result.eventTime;
         m_htf_lbs[k].opposingWait.sourceTF=(int)tf; m_htf_lbs[k].opposingWait.sourceId=result.opposingId;
         ZeroMemory(m_htf_lbs[k].pivotEntry); ZeroMemory(m_htf_lbs[k].pivotWatch);
         m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
         PrintFormat("[OPPOSING LB WAIT] %s %s LB=%s opposing=%s; retirement replaced by M1 CHoCH wait.",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,result.opposingId);
         return true;
        }
      m_htf_lbs[k].opposingRejectedAt=now;
      s_clusters.RejectOpposing(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now);
      CTradeRejection::Retire(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated, m_htf_lbs[k].mitigationTime, now);
      m_htf_lbs[k].m1PivotTime = 0; m_htf_lbs[k].m1PivotPrice = 0.0; m_htf_lbs[k].m1ConfirmTime = 0;
      PrintFormat("[TRADE REJECTED] %s %s LB=%s reason=OPPOSING_STRUCTURE_LB source=%s opposing=%s event=%s at=%s",
                  m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id, EnumToString(result.sourceTF),
                  result.opposingId, TimeToString(result.eventTime, TIME_DATE|TIME_SECONDS), TimeToString(now, TIME_DATE|TIME_SECONDS));
      return true;
     }

   void AuditChochTouches(datetime barTime, double low, double high, datetime available,
                           ZigZag* zz, ENUM_TIMEFRAMES tf, CTradeRejectionHistory &history)
     {
      for(int k = 0; k < m_htf_lb_count; k++)
        {
         ObserveRejectionTouch(k, barTime, low, high, available, tf);
         // Policy waits are observed on the M1 path and executable quotes.
         // An HTF close processed first must not predate/overwrite an M1 touch
         // within that candle, or expose its new structure to earlier M1 bars.
         if(!m_applyEntryPolicyToPreventionExits)
            CheckChochRejection(k, available, zz, tf, history);
        }
     }

   bool              BlockM1OpposingLeg(int k, datetime now)
     {
      if(m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required) return true;
      if(m_entryTF != ENTRY_TF_M1 || m1LBContext == NULL || zzEntry == NULL ||
         m_htf_lbs[k].m1TouchTime == 0 || now < m_htf_lbs[k].m1TouchTime)
         return false;
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated))
         return true;
      datetime touchMinute = m_htf_lbs[k].m1TouchTime - m_htf_lbs[k].m1TouchTime % 60;
      datetime originTime = 0;
      double originPrice = 0.0;
      bool isBull = m_htf_lbs[k].isBullish;
      for(int p = zzEntry.pivots.Total() - 1; p >= 0; p--)
        {
         Pivot* pv = (Pivot*)zzEntry.pivots.At(p);
         if(pv == NULL || pv == zzEntry.projection || pv.end == NULL ||
            StringFind(pv.ln, "ZZ_Proj") >= 0)
            continue;
         // If already latched, inspect that exact entry leg, not a subsequent leg.
         if(m_htf_lbs[k].m1ConfirmTime != 0 && pv.end.time != m_htf_lbs[k].m1PivotTime)
            continue;
         if(pv.isHigh == isBull)
           {
            // Incoming low/high is not confirmed yet: the latest opposite pivot is its origin.
            originTime = pv.end.time;
            originPrice = pv.end.price;
           }
         else if(pv.end.time >= touchMinute && pv.start != NULL && pv.start.time < pv.end.time)
           {
            originTime = pv.start.time;
            originPrice = pv.start.price;
           }
         break;
        }
      if(originTime == 0)
         return false;
      string opposingId;
      if(!m1LBContext.FindOpposingOrigin(isBull, originTime, originPrice, now,
                                        m_slBufferPips * GetPipSize(m_symbol), opposingId))
         return false;
      m_htf_lbs[k].opposingRejectedAt=now;
      s_clusters.RejectOpposing(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now);
      CTradeRejection::Retire(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated, m_htf_lbs[k].mitigationTime, now);
      m_htf_lbs[k].m1PivotTime = 0;
      m_htf_lbs[k].m1PivotPrice = 0.0;
      m_htf_lbs[k].m1ConfirmTime = 0;
      PrintFormat("[M1 OPPOSING LB BLOCK] %s %s LB=%s opposing=%s origin=%s price=%.8f blocked=%s touches=%d",
                  m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id, opposingId,
                  TimeToString(originTime, TIME_DATE|TIME_SECONDS), originPrice,
                  TimeToString(now, TIME_DATE|TIME_SECONDS), m_htf_lbs[k].touchCount);
      return true;
     }

   bool CheckIndWaitBoundary(int k, datetime now, double low, double high)
     {
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return false;
      if(!CMarcoIndEntryFilter::Broken(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,
                                       low,high,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh)) return false;
      CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,now);
      PrintFormat("[M1 IND WAIT CANCELLED] %s %s LB=%s: setup outer boundary breached.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id);
      return true;
     }

   // Snapshot existing setup-TF results; do not run another calculation engine.
   void CaptureSetupIndContext(CInducementLogic* ind, CMarketStructure* ms,
                               datetime available, double low, double high)
     {
      if(!CMarcoIndEntryFilter::Enabled()) return;
      m_setupIndEntry.Begin(low,high);
      for(int z=0;z<ind.m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)ind.m_zones.At(z);
         if(zone!=NULL && zone.isInducement && !zone.isMitigated)
            m_setupIndEntry.Zone(zone.id,zone.isBullish,zone.zoneLow,zone.zoneHigh,available);
        }
      m_setupIndEntry.End(available);
      int n=ms.all_event_names.Total();
      for(int e=MathMax(0,n-3);e<n;e++)
         m_setupIndEntry.Observe(ms.all_event_names.At(e),(datetime)ms.all_event_times.At(e),available);
     }

   bool IndEntryReady(int k, datetime pivot, double price, datetime available, datetime now)
     {
      if(!CMarcoIndEntryFilter::Enabled() || !m_htf_lbs[k].indWait.waiting) return true;
      if(m_entryTF==ENTRY_TF_M1 || (m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required))
         return m1LBContext!=NULL && m1LBContext.indEntry.Ready(m_htf_lbs[k].indWait,
                   m_htf_lbs[k].isBullish,pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
      return m_setupIndEntry.Ready(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,
                   pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
     }

   bool SkipIndPivot(int k, datetime pivot, double price, datetime available)
     {
      if(!CMarcoIndEntryFilter::CheckPivot() || pivot<=0) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      ENUM_TIMEFRAMES entryTF=(m_entryTF==ENTRY_TF_M1 ||
         (m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required)) ? PERIOD_M1 : m_tradeTF;
      string id="";
      if(m_setupIndEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      // Same timeframe is checked once. Both blockers contribute to the wait bounds.
      if(entryTF!=m_tradeTF && m1LBContext!=NULL &&
         m1LBContext.indEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(entryTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      return blocked;
     }

   bool SkipIndEntryPrice(int k, datetime now, double entry, datetime pivot=0, datetime confirmed=0)
     {
      if(!CMarcoIndEntryFilter::CheckPrice()) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      bool reversalEntry=m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required;
      bool useM1=reversalEntry || m_entryTF==ENTRY_TF_M1;
      if(!reversalEntry && m_entryTF==ENTRY_TF_M1)
        { pivot=m_htf_lbs[k].m1PivotTime; confirmed=m_htf_lbs[k].m1ConfirmTime; }
      string id="";
      m_setupIndEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,m_tradeTF);
      if(m_setupIndEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
        {
         blocked=true;
         PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,entry);
        }
      if(useM1 && m_tradeTF!=PERIOD_M1 && m1LBContext!=NULL)
        {
         m1LBContext.indEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,PERIOD_M1);
         if(m1LBContext.indEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
           {
            blocked=true;
            PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                        m_symbol,EnumToString(m_tradeTF),EnumToString(PERIOD_M1),id,entry);
           }
        }
      if(!blocked) return false;
      PrintFormat("[IND WAIT] %s setup=%s LB=%s: waiting for a new %s CHoCH and pivot beyond blocking INDs.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                  EnumToString(useM1 ? PERIOD_M1 : m_tradeTF));
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
      if(useM1 && m1LBContext!=NULL)
         CheckIndWaitBoundary(k,now,m1LBContext.indEntry.lastLow,m1LBContext.indEntry.lastHigh);
      else CheckIndWaitBoundary(k,now,m_setupIndEntry.lastLow,m_setupIndEntry.lastHigh);
      return true;
     }

   // After an IND rejection, ignore the rejected pivot and require a new
   // entry-TF pivot after the directional CHoCH, still within the setup LB.
   bool GetSetupIndWaitPivot(int k, datetime now, ZigZag* zz,
                             datetime &pivot, double &price, datetime &confirmed)
     {
      pivot=0; price=0; confirmed=0;
      if(zz==NULL) return false;
      for(int p=0;p<zz.pivots.Total() && p<ArraySize(m_pivotConfirmations);p++)
        {
         Pivot* pv=(Pivot*)zz.pivots.At(p);
         if(pv==NULL || pv==zz.projection || StringFind(pv.ln,"ZZ_Proj")>=0 ||
            pv.isHigh==m_htf_lbs[k].isBullish) continue;
         datetime available=m_pivotConfirmations[p].availableTime;
         if(available<=0 || available>now || !IndEntryReady(k,pv.end.time,pv.end.price,available,now)) continue;
         if(confirmed==0 || available<confirmed)
           { pivot=pv.end.time; price=pv.end.price; confirmed=available; }
        }
      return confirmed>0;
     }

   void DiscardPivotEntry(int k, datetime now, string reason)
     {
      if(!m_htf_lbs[k].pivotWatch.invalid && m_htf_lbs[k].pivotWatch.confirmed>0)
         PrintFormat("[PIVOT DISCARDED] %s setup=%s LB=%s pivot=%s price=%.8f at=%s reason=%s; waiting for latest confirmed pivot",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                     TimeToString(m_htf_lbs[k].pivotWatch.pivot,TIME_DATE|TIME_SECONDS),m_htf_lbs[k].pivotWatch.price,
                     TimeToString(now,TIME_DATE|TIME_SECONDS),reason);
      m_htf_lbs[k].pivotWatch.invalid=true;
      ZeroMemory(m_htf_lbs[k].pivotEntry);
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
     }

   bool ObservePivotEntryRange(int k, datetime sampleTime, double low, double high)
     {
      if(!CMarcoPivotEntry::Enabled() || m_htf_lbs[k].entryTriggerTime<=0 ||
         sampleTime<m_htf_lbs[k].entryTriggerTime+PeriodSeconds(m_tradeTF)) return false;
      if(CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return true;
      bool bull=m_htf_lbs[k].isBullish;
      // A waiting edge entry never receives the SL buffer as extra LB validity.
      if(CTradeRejection::BoundaryBroken(bull,low,high,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,0))
        {
         DiscardPivotEntry(k,sampleTime,"SETUP_LB_MITIGATED");
         CTradeRejection::Retire(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated,m_htf_lbs[k].mitigationTime,sampleTime);
         PrintFormat("[PIVOT WAIT CANCELLED] %s setup=%s LB=%s: setup LB boundary broken at %s",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,TimeToString(sampleTime,TIME_DATE|TIME_SECONDS));
         return true;
        }
      if(m_htf_lbs[k].pivotWatch.confirmed>0 && sampleTime>=m_htf_lbs[k].pivotWatch.confirmed &&
         (bull ? low<m_htf_lbs[k].pivotWatch.price : high>m_htf_lbs[k].pivotWatch.price))
         DiscardPivotEntry(k,sampleTime,"PIVOT_EXTREME_BROKEN");
      return false;
     }

   bool GetLatestEntryPivot(int k, datetime now, ZigZag* zz, bool m1,
                            datetime &pivot, double &price, datetime &confirmed)
     {
      pivot=0; price=0; confirmed=0;
      if(zz==NULL || CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) return false;
      int selected=-1; datetime latest=0, known=0;
      int count=m1 ? ArraySize(m_m1PivotConfirmations) : ArraySize(m_pivotConfirmations);
      for(int p=0;p<zz.pivots.Total() && p<count;p++)
        {
         Pivot* pv=(Pivot*)zz.pivots.At(p);
         if(pv==NULL || pv==zz.projection || StringFind(pv.ln,"ZZ_Proj")>=0 ||
            pv.isHigh==m_htf_lbs[k].isBullish) continue;
         datetime available=m1 ? m_m1PivotConfirmations[p].availableTime : m_pivotConfirmations[p].availableTime;
         datetime at=m1 ? m_m1PivotConfirmations[p].pivotTime : m_pivotConfirmations[p].pivotTime;
         double value=m1 ? m_m1PivotConfirmations[p].price : m_pivotConfirmations[p].price;
         bool high=m1 ? m_m1PivotConfirmations[p].isHigh : m_pivotConfirmations[p].isHigh;
         // The availability record must describe this exact current endpoint.
         if(available<=0 || available>now || at!=pv.end.time || value!=pv.end.price || high!=pv.isHigh) continue;
         if(selected<0 || at>latest || (at==latest && available>known))
           { selected=p; latest=at; known=available; }
        }
      if(selected<0)
        { DiscardPivotEntry(k,now,"NO_CURRENT_CONFIRMED_PIVOT"); return false; }
      Pivot* current=(Pivot*)zz.pivots.At(selected);
      SMarcoPivotWatch previous=m_htf_lbs[k].pivotWatch;
      bool same=previous.pivot==latest && previous.price==current.end.price && previous.confirmed==known;
      if(previous.confirmed>0 && (latest<previous.pivot || known<previous.confirmed))
        { DiscardPivotEntry(k,now,"PIVOT_REMOVED_NO_NEW_CONFIRMATION"); return false; }
      if(same && previous.invalid) return false;
      if(!same)
        {
         if(previous.confirmed>0)
            PrintFormat("[PIVOT REPLACED] %s setup=%s LB=%s old=%s/%.8f latest=%s/%.8f confirmed=%s; recalculate entry edge and SL",
                        m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                        TimeToString(previous.pivot,TIME_DATE|TIME_SECONDS),previous.price,
                        TimeToString(latest,TIME_DATE|TIME_SECONDS),current.end.price,TimeToString(known,TIME_DATE|TIME_SECONDS));
         ZeroMemory(m_htf_lbs[k].pivotEntry);
         m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
         m_htf_lbs[k].pivotWatch.pivot=latest;
         m_htf_lbs[k].pivotWatch.price=current.end.price;
         m_htf_lbs[k].pivotWatch.confirmed=known;
         m_htf_lbs[k].pivotWatch.invalid=false;
        }
      bool bull=m_htf_lbs[k].isBullish;
      // Pick the latest endpoint FIRST. Never fall back to an older in-zone pivot
      // just because the latest pivot fails zone, IND, touch or CHoCH eligibility.
      if(current.end.price<m_htf_lbs[k].zoneLow || current.end.price>m_htf_lbs[k].zoneHigh) return false;
      if(m1)
        {
         if(!CTradeRejection::M1Pivot(bull,current.isHigh,latest,current.end.price,
                                     m_htf_lbs[k].m1TouchTime,known,now,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh)) return false;
        }
      else if(latest<=m_htf_lbs[k].entryTriggerTime) return false;
      if(!IndEntryReady(k,latest,current.end.price,known,now) || SkipIndPivot(k,latest,current.end.price,known)) return false;
      pivot=latest; price=current.end.price; confirmed=known;
      if(m1)
        {
         m_htf_lbs[k].m1PivotTime=pivot; m_htf_lbs[k].m1PivotPrice=price; m_htf_lbs[k].m1ConfirmTime=confirmed;
         if(BlockM1OpposingLeg(k,now)) return false;
        }
      return true;
     }

   bool              GetM1EntryPivot(int k, datetime now, datetime &pivotTime,
                                     double &pivotPrice, datetime &confirmTime)
     {
      pivotTime = 0;
      pivotPrice = 0.0;
      confirmTime = 0;
      if(zzEntry == NULL || m_htf_lbs[k].m1TouchTime == 0)
         return false;
      if(CMarcoPivotEntry::Enabled())
         return GetLatestEntryPivot(k,now,zzEntry,true,pivotTime,pivotPrice,confirmTime);
      // Opposing M1 origin invalidates the setup before pivot confirmation or execution.
      if(BlockM1OpposingLeg(k, now))
         return false;
      while(m_htf_lbs[k].m1ConfirmTime == 0)
        {
         int selected = -1;
         datetime earliest = 0;
         for(int p = 0; p < zzEntry.pivots.Total() && p < ArraySize(m_m1PivotConfirmations); p++)
           {
            Pivot* pv = (Pivot*)zzEntry.pivots.At(p);
            if(pv == NULL || pv == zzEntry.projection || StringFind(pv.ln, "ZZ_Proj") >= 0)
               continue;
            datetime available = m_m1PivotConfirmations[p].availableTime;
            if(m_htf_lbs[k].indWait.waiting &&
               (pv.end.time<=m_htf_lbs[k].indWait.rejectedPivot || available<=m_htf_lbs[k].indWait.rejectedAvailable)) continue;
            if(!IndEntryReady(k,pv.end.time,pv.end.price,available,now)) continue;
            if(!CTradeRejection::M1Pivot(m_htf_lbs[k].isBullish, pv.isHigh, pv.end.time, pv.end.price,
                                        m_htf_lbs[k].m1TouchTime, available, now, m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh))
               continue;
            if(selected < 0 || available < earliest)
              {
               selected = p;
               earliest = available;
              }
           }
         if(selected < 0)
            return false;
         Pivot* first = (Pivot*)zzEntry.pivots.At(selected);
         if(SkipIndPivot(k,first.end.time,first.end.price,earliest))
           {
            if(m1LBContext!=NULL && CheckIndWaitBoundary(k,now,m1LBContext.indEntry.lastLow,m1LBContext.indEntry.lastHigh)) return false;
            continue;
           }
         m_htf_lbs[k].m1PivotTime = first.end.time;
         m_htf_lbs[k].m1PivotPrice = first.end.price;
         m_htf_lbs[k].m1ConfirmTime = earliest;
         PrintFormat("[M1 CONFIRMED] %s %s LB=%s pivot=%s price=%.8f confirmed=%s",
                     m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id,
                     TimeToString(first.end.time, TIME_DATE|TIME_SECONDS), first.end.price,
                     TimeToString(earliest, TIME_DATE|TIME_SECONDS));
        }
      if(!IndEntryReady(k,m_htf_lbs[k].m1PivotTime,m_htf_lbs[k].m1PivotPrice,m_htf_lbs[k].m1ConfirmTime,now))
        {
         m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
         return false;
        }
      // Freeze the first qualifying confirmed pivot; a later one must not replace it.
      pivotTime = m_htf_lbs[k].m1PivotTime;
      pivotPrice = m_htf_lbs[k].m1PivotPrice;
      confirmTime = m_htf_lbs[k].m1ConfirmTime;
      return pivotPrice >= m_htf_lbs[k].zoneLow && pivotPrice <= m_htf_lbs[k].zoneHigh && confirmTime <= now;
     }

   double            CalculateLotSize(bool isBull, double entryPrice, double slPrice,
                                      double bid, double ask)
     {
      if(!MathIsValidNumber(entryPrice) || !MathIsValidNumber(slPrice) ||
         !MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
         entryPrice<=0 || slPrice<=0 || bid<=0 || ask<=0 || ask<bid ||
         (isBull ? slPrice>=entryPrice : slPrice<=entryPrice)) return 0.0;
      // Each scenario owns its simulated account. Never consult real positions
      // or orders for historical risk/capacity; this simulator has no pending orders.
      double usedMargin=0.0, floatingProfit=0.0, directionalUsed=0.0;
      for(int t=0;t<ArraySize(m_trades);t++)
        {
         if(!m_trades[t].isOpen) continue;
         double remaining=m_trades[t].tpPlan.remaining;
         if(!MathIsValidNumber(remaining) || remaining<0 || remaining>1.0+1e-9 ||
            !MathIsValidNumber(m_trades[t].lots) || m_trades[t].lots<=0) return 0.0;
         double openLots=m_trades[t].lots*remaining;
         if(openLots<=0.0) continue;
         ENUM_ORDER_TYPE side=m_trades[t].direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double margin=0.0, profit=0.0;
         double mark=m_trades[t].direction==1 ? bid : ask;
         if(!OrderCalcMargin(side,m_symbol,openLots,m_trades[t].openPrice,margin) ||
            !OrderCalcProfit(side,m_symbol,openLots,m_trades[t].openPrice,mark,profit) ||
            !MathIsValidNumber(margin) || margin<0 || !MathIsValidNumber(profit)) return 0.0;
         usedMargin+=margin; floatingProfit+=profit;
         if((m_trades[t].direction==1)==isBull) directionalUsed+=openLots;
        }
      double equity=m_currentBalance+floatingProfit;
      double freeMargin=equity-usedMargin;
      double riskCapital=CMarcoRiskCapital::Select(m_currentBalance,equity,freeMargin,usedMargin);
      double step=0, minLot=0, maxLot=0, limit=0;
      if(!SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP,step) ||
         !SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN,minLot) ||
         !SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX,maxLot) ||
         !SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_LIMIT,limit) ||
         !MathIsValidNumber(step) || !MathIsValidNumber(minLot) || !MathIsValidNumber(maxLot) ||
         !MathIsValidNumber(limit) || limit<0 || !MathIsValidNumber(directionalUsed) ||
         !MathIsValidNumber(freeMargin) || !MathIsValidNumber(m_riskPercent) ||
         !CTradeRejection::SizingInputs(freeMargin,m_riskPercent,step,minLot,maxLot)) return 0.0;
      double capacity=limit>0 ? MathMin(maxLot,MathMax(0.0,limit-directionalUsed)) : maxLot;
      double riskBudget=CMarcoRiskCapital::Budget(riskCapital,m_riskPercent);
      if(!MathIsValidNumber(riskBudget) || riskBudget<=0)
        {
         PrintFormat("[ENTRY SIZING SKIP] %s: riskBase=%s capital=%.2f riskPercent=%.4f; no positive risk budget.",
                     m_symbol,CMarcoRiskCapital::Name(),riskCapital,m_riskPercent);
         return 0.0;
        }
      ENUM_ORDER_TYPE side=isBull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double loss=0.0, margin=0.0, openingProfit=0.0;
      if(!OrderCalcProfit(side,m_symbol,minLot,entryPrice,slPrice,loss) ||
         !MathIsValidNumber(loss) || loss>=0 ||
         !OrderCalcMargin(side,m_symbol,minLot,entryPrice,margin) ||
         !MathIsValidNumber(margin) || margin<0) return 0.0;
      double riskLots=riskBudget*minLot/(-loss);
      double marginLots=margin>0 ? freeMargin*0.90*minLot/margin : maxLot;
      if(!MathIsValidNumber(riskLots) || !MathIsValidNumber(marginLots)) return 0.0;
      double cap=MathMin(capacity,MathMin(riskLots,marginLots));
      // Same quarter-volume grid as live, without floating-point truncation of
      // exact valid values (for example a 0.28 allowance becoming 0.24 lots).
      double lots=CMarcoStagedTP::Lots(cap,step,minLot);
      if(lots<=0 || lots>cap+1e-10) return 0.0;
      double quarterStep=4.0*step;
      long lowUnits=(long)MathCeil(4.0*minLot/quarterStep-1e-8);
      long highUnits=(long)MathRound(lots/quarterStep);
      long candidate=highUnits, bestUnits=0;
      while(lowUnits<=highUnits)
        {
         lots=NormalizeDouble(candidate*quarterStep,8);
         if(!OrderCalcProfit(side,m_symbol,lots,entryPrice,slPrice,loss) ||
            !OrderCalcMargin(side,m_symbol,lots,entryPrice,margin) ||
            !OrderCalcProfit(side,m_symbol,lots,entryPrice,isBull ? bid : ask,openingProfit) ||
            !MathIsValidNumber(loss) || loss>=0 || !MathIsValidNumber(margin) || margin<0 ||
            !MathIsValidNumber(openingProfit)) return 0.0;
         // Equivalent to live's actual-volume risk check and post-entry margin reserve.
         if(-loss<=riskBudget+MathMax(1e-8,riskBudget*1e-10) &&
            CTradeRejection::MarginFits(margin+MathMax(0.0,-openingProfit),freeMargin))
           {
            bestUnits=candidate;
            if(candidate==highUnits) break;
            lowUnits=candidate+1;
           }
         else highUnits=candidate-1;
         candidate=lowUnits+(highUnits-lowUnits)/2;
        }
      if(bestUnits==0) return 0.0;
      lots=NormalizeDouble(bestUnits*quarterStep,8);
      // Revalidate the chosen candidate, rather than the last binary-search probe.
      if(lots>capacity+1e-10 || lots/4.0<minLot-1e-10 ||
         !OrderCalcProfit(side,m_symbol,lots,entryPrice,slPrice,loss) ||
         !OrderCalcMargin(side,m_symbol,lots,entryPrice,margin) ||
         !OrderCalcProfit(side,m_symbol,lots,entryPrice,isBull ? bid : ask,openingProfit) ||
         !MathIsValidNumber(loss) || loss>=0 || !MathIsValidNumber(margin) || margin<0 ||
         !MathIsValidNumber(openingProfit) || -loss>riskBudget+MathMax(1e-8,riskBudget*1e-10) ||
         !CTradeRejection::MarginFits(margin+MathMax(0.0,-openingProfit),freeMargin)) return 0.0;
      Print(StringFormat("[ENTRY SIZING SIM] %s: riskBase=%s capital=%.2f free=%.2f riskPercent=%.4f budget=%.2f estimatedSLRisk=%.2f lots=%.8f entry=%.8f bufferedSL=%.8f min=%.8f max=%.8f step=%.8f directionalLimit=%.8f used=%.8f capacity=%.8f",
                  m_symbol,CMarcoRiskCapital::Name(),riskCapital,freeMargin,m_riskPercent,riskBudget,-loss,lots,entryPrice,slPrice,
                  minLot,maxLot,step,limit,directionalUsed,capacity));
      return lots;
     }

   double            GetPipSize(string sym)
     {
      double pip=CMarcoSymbolUnits::PipSize(sym), buffer=0.0;
      return CMarcoSymbolUnits::Buffer(m_slBufferPips, pip, buffer) ? pip : 0.0;
     }

   int               CountPivotTouches(bool isBullish, double zHigh, double zLow, double buffer,
                                       datetime startTime, datetime endTime, ZigZag* zz)
     {
      if(zz == NULL || zz.pivots.Total() == 0)
         return 0;
      int count = 0;
      int totalP = zz.pivots.Total();
      for(int p = 0; p < totalP; p++)
        {
         Pivot* pv = (Pivot*)zz.pivots.At(p);
         if(pv == NULL || pv == zz.projection)
            continue;
         if(StringFind(pv.ln, "ZZ_Proj") >= 0)
            continue;

         if(pv.end.time <= startTime)
            continue;
         if(pv.end.time > endTime)
            break;

         if(isBullish)
           {
            if(!pv.isHigh && pv.end.price <= zHigh && pv.end.price >= (zLow - buffer))
               count++;
           }
         else
           {
            if(pv.isHigh && pv.end.price >= zLow && pv.end.price <= (zHigh + buffer))
               count++;
           }
        }
      return count;
     }

   int               CountTouchingPivots(bool isBullish, double zHigh, double zLow, double buffer,
                                         datetime confirmedTime, datetime currentTime, ZigZag* zzHtfRef,
                                         datetime &outFirstPivotTime, double &outFirstPivotPrice,
                                         datetime &outFirstPivotConfirmTime)
     {
      outFirstPivotTime        = 0;
      outFirstPivotPrice       = 0.0;
      outFirstPivotConfirmTime = 0;
      if(zzHtfRef == NULL || zzHtfRef.pivots.Total() == 0)
         return 0;

      int count = 0;
      int totalP = zzHtfRef.pivots.Total();
      for(int p = 0; p < totalP; p++)
        {
         Pivot* pv = (Pivot*)zzHtfRef.pivots.At(p);
         if(pv == NULL || pv == zzHtfRef.projection)
            continue;
         if(StringFind(pv.ln, "ZZ_Proj") >= 0)
            continue;

         if(pv.end.time <= confirmedTime)
            continue;

         if(p >= ArraySize(m_pivotConfirmations))
            continue;
         datetime pivotConfirmTime = m_pivotConfirmations[p].availableTime;
         if(pivotConfirmTime == 0 || pivotConfirmTime > currentTime)
            continue;
         if(pv.end.time > currentTime)
            break;

         if(isBullish)
           {
            if(!pv.isHigh && pv.end.price <= zHigh && pv.end.price >= (zLow - buffer))
              {
               count++;
               if(count == 1)
                 {
                  outFirstPivotTime        = pv.end.time;
                  outFirstPivotPrice       = pv.end.price;
                  outFirstPivotConfirmTime = pivotConfirmTime;
                 }
              }
           }
         else
           {
            if(pv.isHigh && pv.end.price >= zLow && pv.end.price <= (zHigh + buffer))
              {
               count++;
               if(count == 1)
                 {
                  outFirstPivotTime        = pv.end.time;
                  outFirstPivotPrice       = pv.end.price;
                  outFirstPivotConfirmTime = pivotConfirmTime;
                 }
              }
           }
        }
      return count;
     }

   int               FindCachedLB(string id)
     {
      for(int k = 0; k < m_htf_lb_count; k++)
         if(m_htf_lbs[k].id == id) return k;
      return -1;
     }

   bool              IsLegComingFromOppositeLB(bool candidateIsBull, datetime touchPivotTime, ZigZag* zzHtfRef, double buffer, datetime now)
     {
      if(zzHtfRef == NULL || zzHtfRef.pivots.Total() < 2)
         return false;

      int touchIdx = -1;
      for(int p = zzHtfRef.pivots.Total() - 1; p >= 0; p--)
        {
         Pivot* pv = (Pivot*)zzHtfRef.pivots.At(p);
         if(pv == NULL || pv == zzHtfRef.projection || pv.end == NULL || StringFind(pv.ln,"ZZ_Proj")>=0)
            continue;
         if(pv.end.time == touchPivotTime)
           {
            touchIdx = p;
            break;
           }
        }

      if(touchIdx < 0)
         return false;

      Pivot* selected=(Pivot*)zzHtfRef.pivots.At(touchIdx);
      if(selected==NULL || selected.start==NULL) return false;
      double prevPrice=selected.start.price;
      datetime prevTime=selected.start.time;

      string opposingId="";
      ENUM_TIMEFRAMES sourceTF=m_tradeTF;
      bool blocked=m_htfRejection.IncomingLeg(candidateIsBull,prevTime,prevPrice,now,m_tradeTF,buffer,opposingId);
      if(!blocked && m1LBContext!=NULL && m_tradeTF!=PERIOD_M1)
        {
         sourceTF=PERIOD_M1;
         blocked=m1LBContext.rejectionHistory.IncomingLeg(candidateIsBull,prevTime,prevPrice,now,PERIOD_M1,buffer,opposingId);
        }
      if(blocked)
        {
         PrintFormat("[ENTRY LEG BLOCK] %s %s source=%s LB=%s origin=%s price=%.8f at=%s",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(sourceTF),opposingId,
                     TimeToString(prevTime,TIME_DATE|TIME_SECONDS),prevPrice,TimeToString(now,TIME_DATE|TIME_SECONDS));
         return true;
        }

      return false;
     }

   double            FindOpposingIND_TP(bool isBull, double entryPx, datetime sessionStart, datetime sessionEnd, CInducementLogic* indLogic)
     {
      double tp = 0.0;
      double bestDist = DBL_MAX;
      if(indLogic == NULL)
         return 0.0;

      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic.m_zones.At(z);
         if(ind == NULL || !ind.isInducement || ind.isMitigated)
            continue;

         datetime indTime = (ind.inducementTime > 0) ? ind.inducementTime : ind.createdTime;
         if(indTime < sessionStart || indTime > sessionEnd)
            continue;

         if(isBull)
           {
            if(!ind.isBullish && ind.zoneHigh > entryPx)
              {
               double dist = ind.zoneHigh - entryPx;
               if(dist < bestDist)
                 {
                  bestDist = dist;
                  tp       = ind.zoneHigh;
                 }
              }
           }
         else
           {
            if(ind.isBullish && ind.zoneLow < entryPx)
              {
               double dist = entryPx - ind.zoneLow;
               if(dist < bestDist)
                 {
                  bestDist = dist;
                  tp       = ind.zoneLow;
                 }
              }
           }
        }
      return tp;
     }

   double            FindOpposingLB_TP(bool isBull, double entryPx, datetime sessionStart, datetime sessionEnd, CLiquidityBlockLogic* lbLogic)
     {
      double tp = 0.0;
      double bestLBDist = DBL_MAX;
      if(lbLogic == NULL)
         return 0.0;

      for(int b = 0; b < lbLogic.m_liquidity_blocks.Total(); b++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)lbLogic.m_liquidity_blocks.At(b);
         if(lb == NULL || lb.isMitigated)
            continue;

         if(lb.createdTime < sessionStart || lb.createdTime > sessionEnd)
            continue;

         if(isBull)
           {
            if(!lb.isBullish && lb.zoneLow > entryPx)
              {
               double dist = lb.zoneLow - entryPx;
               if(dist < bestLBDist)
                 {
                  bestLBDist = dist;
                  tp         = lb.zoneLow;
                 }
              }
           }
         else
           {
            if(lb.isBullish && lb.zoneHigh < entryPx)
              {
               double dist = entryPx - lb.zoneHigh;
               if(dist < bestLBDist)
                 {
                  bestLBDist = dist;
                  tp         = lb.zoneHigh;
                 }
              }
           }
        }
      return tp;
     }

   double            FindFallback_TP(bool isBull, double entryPx, double riskDist)
     {
      if(m_fallbackRR > 0.0)
         return isBull ? (entryPx + m_fallbackRR * riskDist) : (entryPx - m_fallbackRR * riskDist);
      return 0.0;
     }

   ENUM_TIMEFRAMES   ExecutionTF()
     {
      return m_entryTF == ENTRY_TF_M1 ? PERIOD_M1 : m_tpTF;
     }

   void              ResolveClosedBar(datetime barTime, double barOpen, double barHigh,
                                      double barLow, double barClose, double spread, double pipSize)
     {
      datetime closedAt=barTime+PeriodSeconds(ExecutionTF());
      for(int t=0; t<ArraySize(m_trades); t++)
        {
         if(!m_trades[t].isOpen || barTime<m_trades[t].openTime) continue;
         SMarcoTPPlan plan=m_trades[t].tpPlan;
         double offset=plan.direction==1 ? 0.0 : spread;
         bool rejection=false;
         datetime rejectionStart=0;
         int seconds=PeriodSeconds(m_tpVicinityTF);
         if(m_enableVicinityExit && seconds>0)
           {
            int shift=iBarShift(m_symbol,m_tpVicinityTF,closedAt-1);
            rejectionStart=iTime(m_symbol,m_tpVicinityTF,shift);
            if(shift>=0 && rejectionStart>=m_trades[t].openTime && rejectionStart+seconds==closedAt)
               rejection=plan.direction*(iClose(m_symbol,m_tpVicinityTF,shift)-iOpen(m_symbol,m_tpVicinityTF,shift))<0;
           }
         double before=plan.realizedR, lastExit=0;
         double segmentOpen=barOpen, segmentHigh=barHigh, segmentLow=barLow;
         if(m_trades[t].edgeIntrabar && barTime==m_trades[t].openTime)
           {
            segmentOpen=m_trades[t].edgeBid;
            segmentHigh=m_trades[t].edgeHigh;
            segmentLow=m_trades[t].edgeLow;
            rejection=false; // Whole-candle rejection would include pre-entry movement.
           }
         CMarcoStagedTP::Bar(plan,closedAt,segmentOpen+offset,segmentHigh+offset,segmentLow+offset,barClose+offset,
                            m_enableVicinityExit,m_tpVicinityPips*pipSize,rejection,rejectionStart,lastExit);
         // Book only this bar's realized share; the original risk never changes at BE.
         double profit=(plan.realizedR-before)*m_trades[t].riskAmount;
         m_currentBalance+=profit;
         m_trades[t].realizedProfit+=profit;
         m_trades[t].tpPlan=plan;
         m_trades[t].slPrice=CMarcoStagedTP::Stop(plan);
         if(plan.remaining<=1e-9)
           {
            m_trades[t].isOpen=false;
            m_trades[t].closeTime=closedAt;
            m_trades[t].closePrice=lastExit;
            m_trades[t].outcome=m_trades[t].realizedProfit>1e-8 ? "WIN" : (m_trades[t].realizedProfit < -1e-8 ? "LOSS" : "BE");
            if(m_trades[t].outcome=="WIN") m_wins++;
            else if(m_trades[t].outcome=="LOSS") m_losses++;
           }
        }
     }

   double ExtensionSourcePivot(const SMarcoExtensionSource &source, int direction, datetime now)
     {
      bool m1=source.tf==PERIOD_M1;
      int count=m1 ? ArraySize(m_m1PivotConfirmations) : ArraySize(m_pivotConfirmations);
      for(int p=0;p<count;p++)
        {
         datetime at=m1 ? m_m1PivotConfirmations[p].pivotTime : m_pivotConfirmations[p].pivotTime;
         datetime known=m1 ? m_m1PivotConfirmations[p].availableTime : m_pivotConfirmations[p].availableTime;
         bool high=m1 ? m_m1PivotConfirmations[p].isHigh : m_pivotConfirmations[p].isHigh;
         if(at==source.created && known>0 && known<=now && high==(direction==-1))
            return m1 ? m_m1PivotConfirmations[p].price : m_pivotConfirmations[p].price;
        }
      return 0.0;
     }

   bool ExtendFromNewLB(SMarcoTPPlan &plan, SMarcoExtensionState &state, datetime opened, datetime now)
     {
      if(plan.remaining<=1e-9) return false;
      SMarcoExtensionSource source; source.tf=0; source.id=""; source.created=0; source.available=0;
      int preferred=m_entryTF==ENTRY_TF_M1 ? (int)PERIOD_M1 : (int)m_tradeTF;
      string before=state.seen;
      int count=CMarcoLBExtension::Observe(m_htfRejection,plan,state,opened,now,(int)m_tradeTF,preferred,source);
      if(m1LBContext!=NULL && m_tradeTF!=PERIOD_M1)
         count+=CMarcoLBExtension::Observe(m1LBContext.rejectionHistory,plan,state,opened,now,(int)PERIOD_M1,preferred,source);
      if(count>0)
        {
         double tick=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
         int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
         if(CMarcoStagedTP::Extend(plan,1,m_fallbackRR,tick,digits,now))
           {
            double pivot=0.0;
            if(plan.remaining<=0.25+1e-9)
              {
               pivot=ExtensionSourcePivot(source,plan.direction,now);
               double stop=plan.entry;
               if(pivot>0) CMarcoSymbolUnits::BufferedStop(m_symbol,pivot,m_slBufferPips,plan.direction==1,stop);
               CMarcoStagedTP::TightenStop(plan,stop);
              }
            Print(StringFormat("[LB TP EXTEND] %s %s entry=%s new_LBs=%d total=%d last_TP=%.8f remaining=%.2f%% source=%s LB=%s source_pivot=%.8f SL=%.8f",
                        m_symbol,EnumToString(m_tradeTF),TimeToString(opened,TIME_DATE|TIME_SECONDS),count,plan.extensionCount,
                        plan.price[CMarcoStagedTP::LastPending(plan)],100.0*plan.remaining,
                        EnumToString((ENUM_TIMEFRAMES)source.tf),source.id,pivot,CMarcoStagedTP::Stop(plan)));
           }
         else PrintFormat("[LB TP EXTEND SKIPPED] %s: extended target is invalid for this symbol.",m_symbol);
        }
      return state.seen!=before;
     }

   void ApplyStructureExits(datetime now, double bid, double ask)
     {
      double step=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      double minimum=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
      if(step<=0 || minimum<=0) return;
      for(int t=0;t<ArraySize(m_trades);t++)
        {
         if(!m_trades[t].isOpen || m_trades[t].openTime>=now) continue;
         SMarcoTPPlan plan=m_trades[t].tpPlan;
         double price=plan.direction==1 ? bid : ask;
         SMarcoStructureExit signal; ZeroMemory(signal);
         SMarcoSequenceSignal sequence; ZeroMemory(sequence);
         if(m_applyEntryPolicyToPreventionExits)
           {
            sequence=ObserveOpposingSequence(plan,m_trades[t].openTime,now,price);
            signal.action=sequence.action; signal.tf=(ENUM_TIMEFRAMES)sequence.tf;
            signal.eventTime=sequence.eventTime; signal.lbId=sequence.lbId;
            m_trades[t].tpPlan=plan; // Persist observed/cancelled events even when no close is due.
           }
         else signal=CMarcoStructureExit::Evaluate(m_htfRejection,plan,m_trades[t].openTime,now,m_tradeTF);
         if(!m_applyEntryPolicyToPreventionExits && m1LBContext!=NULL)
           {
            SMarcoStructureExit m1=CMarcoStructureExit::Evaluate(m1LBContext.rejectionHistory,plan,m_trades[t].openTime,now,PERIOD_M1);
            if(m1.action>signal.action) signal=m1;
           }
         if(signal.action==0) continue;
         double lots=signal.action==2 ? m_trades[t].lots*plan.remaining :
                     CMarcoStagedTP::PartialLots(m_trades[t].lots*plan.remaining,
                                                m_applyEntryPolicyToPreventionExits ? sequence.share : 0.5,step,minimum);
         if(lots<=0)
           {
            if(m_applyEntryPolicyToPreventionExits) m_trades[t].tpPlan.sequence.pending=false;
            else m_trades[t].tpPlan.structureTime[0]=now;
            PrintFormat("[STRUCTURE EXIT SKIPPED] %s #%I64u: requested share cannot fit broker lot grid; existing exits retained.",m_symbol,m_trades[t].ticket);
            continue;
           }
         double before=plan.realizedR;
         if(m_applyEntryPolicyToPreventionExits)
           {
            plan.sequence.requestedLots=lots;
            CMarcoStagedTP::SequenceFill(plan,lots,price,now,m_trades[t].lots,step,minimum);
           }
         else CMarcoStagedTP::StructureExit(plan,signal.action==2,lots/m_trades[t].lots,price,now,m_trades[t].lots,step,minimum);
         double profit=(plan.realizedR-before)*m_trades[t].riskAmount;
         m_currentBalance+=profit; m_trades[t].realizedProfit+=profit;
         m_trades[t].tpPlan=plan;
         m_trades[t].slPrice=CMarcoStagedTP::Stop(plan);
         if(m_applyEntryPolicyToPreventionExits)
            Print(StringFormat("[OPPOSING SEQUENCE] %s %s #%I64u step=%d region=%s share=%.0f%% source=%s event=%s closed=%.8f price=%.8f remaining=%.8f",
                        m_symbol,EnumToString(m_tradeTF),m_trades[t].ticket,sequence.step,sequence.profit ? "TP" : "SL",
                        sequence.share*100,EnumToString(signal.tf),TimeToString(signal.eventTime,TIME_DATE|TIME_SECONDS),lots,price,m_trades[t].lots*plan.remaining));
         else Print(StringFormat("[CHOCH EXIT] %s %s #%I64u %s source=%s LB=%s event=%s line=%.8f closed=%.8f at=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),m_trades[t].ticket,signal.action==2 ? "FULL" : "HALF + BE",
                     EnumToString(signal.tf),signal.lbId,TimeToString(signal.eventTime,TIME_DATE|TIME_SECONDS),signal.level,
                     lots,TimeToString(now,TIME_DATE|TIME_SECONDS),price));
         if(plan.remaining<=1e-9)
           {
            m_trades[t].isOpen=false; m_trades[t].closeTime=now; m_trades[t].closePrice=price;
            m_trades[t].outcome=m_trades[t].realizedProfit>1e-8 ? "WIN" : (m_trades[t].realizedProfit < -1e-8 ? "LOSS" : "BE");
            if(m_trades[t].outcome=="WIN") m_wins++;
            else if(m_trades[t].outcome=="LOSS") m_losses++;
           }
        }
     }

   void ObserveEntryClusters(datetime now,CLiquidityBlockLogic* logic,int pass)
     {
      for(int k=0;k<m_htf_lb_count;k++)
        {
         if(m_htf_lbs[k].entryTriggerTime<=0 || m_htf_lbs[k].createdTime<CMarcoLBEntryClusters::Day(now)) continue;
         for(int z=0;z<logic.m_liquidity_blocks.Total();z++)
           {
            CLiquidityBlock* lb=(CLiquidityBlock*)logic.m_liquidity_blocks.At(z);
            if(lb==NULL || lb.id!=m_htf_lbs[k].id || (pass==0)!=lb.isMitigated) continue;
            datetime freshQualified=0;
            if(lb.triggerType==LB_TRIGGER_BL_IND || lb.triggerType==LB_TRIGGER_BR_IND)
               freshQualified=m_htfRawExit.FreshClusterQualification(lb.isBullish,lb.createdTime,lb.causalChochTime,now);
            s_clusters.Observe(m_symbol,(int)m_tradeTF,lb.id,lb.isBullish ? 1 : -1,lb.zoneLow,lb.zoneHigh,now,lb.isMitigated,lb.createdTime,freshQualified);
            if(m_htf_lbs[k].opposingRejectedAt>0)
               s_clusters.RejectOpposing(m_symbol,(int)m_tradeTF,lb.id,m_htf_lbs[k].opposingRejectedAt);
            break;
           }
        }

      // Preserve a recorded rejection even if its source was reclassified away.
      if(pass==1)
         for(int k=0;k<m_htf_lb_count;k++)
            if(m_htf_lbs[k].entryTriggerTime>0 && m_htf_lbs[k].opposingRejectedAt>0 &&
               m_htf_lbs[k].createdTime>=CMarcoLBEntryClusters::Day(now))
              {
               s_clusters.RejectOpposing(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,m_htf_lbs[k].opposingRejectedAt);
              }

      // Reclassification can remove a source object. Its recorded premises must
      // still be allowed to mitigate; disappearance alone does not reset a cluster.
      if(pass==0)
         for(int n=0;n<ArraySize(s_clusters.nodes);n++)
           {
            SMarcoLBClusterNode node=s_clusters.nodes[n];
            if(node.symbol!=m_symbol || node.tf!=(int)m_tradeTF || node.day!=CMarcoLBEntryClusters::Day(now) || node.mitigated || node.retired) continue;
            bool found=false;
            for(int z=0;z<logic.m_liquidity_blocks.Total();z++)
              {
               CLiquidityBlock* lb=(CLiquidityBlock*)logic.m_liquidity_blocks.At(z);
               if(lb!=NULL && lb.id==node.id) { found=true; break; }
              }
            if(found) continue;
            for(int r=m_sim.nextHtf-1;r>=0 && m_sim.htf_time[r]>node.formed;r--)
               if(m_sim.htf_time[r]+PeriodSeconds(m_tradeTF)<=now &&
                  CTradeRejection::BoundaryBroken(node.side==1,m_sim.htf_low[r],m_sim.htf_high[r],node.low,node.high,0.0))
                 { s_clusters.nodes[n].mitigated=true; break; }
           }
     }

   void RegisterPreparedClusters(datetime now)
     {
      if(m_sim!=NULL && m_sim.prepared) ObserveEntryClusters(now,m_sim.lbLogicHtf,1);
     }

   void RegisterPreparedTFPreferences(datetime now)
     {
      if(m_sim!=NULL && m_sim.prepared) ObserveTFPreferences(s_clusters,now,m_sim.lbLogicHtf);
     }

   // Publish current entry candidates, not historical cluster boundary unions.
   void ObserveTFPreferences(CMarcoLBEntryClusters &book,datetime now,CLiquidityBlockLogic* logic)
     {
      if(!CMarcoLBTFPreference::Enabled()) return;
      CMarcoLBTFPreference::ResetOwner(m_symbol,m_tradeTF);
      if(logic==NULL) return;
      datetime day=CMarcoLBEntryClusters::Day(now);
      for(int k=0;k<m_htf_lb_count;k++)
        {
         if(!m_htf_lbs[k].sourceActive || m_htf_lbs[k].entryTriggerTime<=0 ||
            CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) continue;
         datetime available=m_htf_lbs[k].entryTriggerTime+PeriodSeconds(m_tradeTF);
         bool ind=(m_htf_lbs[k].triggerType==LB_TRIGGER_BL_IND || m_htf_lbs[k].triggerType==LB_TRIGGER_BR_IND);
         datetime origin=ind ? m_htf_lbs[k].inducementOriginTime : m_htf_lbs[k].sweepLineTime;
         if(available>now || CTradeRejection::OutsideSession(origin,m_htf_lbs[k].createdTime,m_htf_lbs[k].confirmedTime,day)) continue;
         string source=""; datetime used=0;
         if(!book.Eligible(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now) ||
            book.Blocked(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now,source,used)) continue;
         for(int z=0;z<logic.m_liquidity_blocks.Total();z++)
           {
            CLiquidityBlock* lb=(CLiquidityBlock*)logic.m_liquidity_blocks.At(z);
            if(lb==NULL || lb.id!=m_htf_lbs[k].id) continue;
            if(!lb.isMitigated)
               CMarcoLBTFPreference::Observe(m_symbol,m_tradeTF,lb.id,lb.isBullish,
                                              lb.zoneLow,lb.zoneHigh,available,now);
            break;
           }
        }
     }

   bool DeferToLowerTF(int k,datetime now)
     {
      if(!CMarcoLBTFPreference::Enabled()) return false;
      SMarcoLBTFChoice choice;
      if(!CMarcoLBTFPreference::Preferred(m_symbol,m_tradeTF,m_htf_lbs[k].isBullish,
                                          m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now,choice))
        { m_htf_lbs[k].preferredLTF=""; return false; }
      string key=EnumToString(choice.tf)+":"+choice.id;
      if(m_htf_lbs[k].preferredLTF!=key)
        {
         PrintFormat("[LTF LB PREFERENCE] %s %s LB=%s deferred to %s LB=%s zone=[%.8f, %.8f]; wait for that setup's touch and entry confirmation.",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,EnumToString(choice.tf),choice.id,choice.low,choice.high);
         m_htf_lbs[k].preferredLTF=key;
        }
      return true; // Waiting alone never consumes a setup or a cluster.
     }

   void SyncGlobalTrades()
     {
      for(int t=0;t<ArraySize(m_trades);t++)
        {
         int n=-1;
         for(int j=0;j<ArraySize(s_global_trades);j++)
            if(s_global_trades[j].symbol==m_symbol && s_global_trades[j].setupTF==(int)m_tradeTF && s_global_trades[j].ticket==m_trades[t].ticket) { n=j; break; }
         if(n<0) { n=ArraySize(s_global_trades); ArrayResize(s_global_trades,n+1); }
         s_global_trades[n].symbol=m_symbol; s_global_trades[n].setupTF=(int)m_tradeTF;
         s_global_trades[n].ticket=m_trades[t].ticket; s_global_trades[n].direction=m_trades[t].direction;
         s_global_trades[n].openTime=m_trades[t].openTime; s_global_trades[n].closeTime=m_trades[t].closeTime;
         s_global_trades[n].openPrice=m_trades[t].openPrice; s_global_trades[n].tpPrice=m_trades[t].tpPrice;
        }
     }

   bool              RunSimulation(bool trackSweepsAnywhere, bool InpTrackPostInducementCHoCH,
                                   int InpMinTouches, double InpProximityPips, bool InpStrictOriginPivots,
                                   bool InpMergeClusteredZones, double InpClusterTolerancePips, bool InpMergeExpandBounds,
                                   bool InpCheckDemandSupply, bool InpCheckOrderBlocks, bool InpCheckSwingPOIs,
                                   bool InpCheckFlipZones, bool InpCheckBreakers, datetime through=0, bool initializeOnly=false, bool prepareOnly=false)
     {
      if(m_simComplete) return !m_simFailed;
      if(m_sim==NULL)
        {
         m_sim=new CMarcoSimulationState();
      SMarcoSymbolUnits symbolUnits;
      double slBuffer=0.0;
      if(!CMarcoSymbolUnits::Load(m_symbol, symbolUnits) ||
         !CMarcoSymbolUnits::Buffer(m_slBufferPips, symbolUnits.pip, slBuffer))
        {
         PrintFormat("[SIMULATION SKIPPED] %s: invalid symbol price units or InpSLBufferPips.", m_symbol);
         return false;
        }
      PrintFormat("[PIP UNITS] %s: pip=%.8f tick=%.8f SL buffer=%.8f pips -> %.8f price; stops round outward to ticks.",
                  m_symbol, symbolUnits.pip, symbolUnits.tick, m_slBufferPips, slBuffer);
      Print(StringFormat("[SIM CONFIG] %s setup=%s point=%.8f entry_mode=%d IND_pivot=%s IND_price=%s proximity=%.8f merge=%s cluster=%.8f expand=%s ZZ=%.8f/%d/%s TP_spread=%s vicinity=%s",
                  m_symbol,EnumToString(m_tradeTF),symbolUnits.point,(int)m_entryTF,
                  CMarcoIndEntryFilter::CheckPivot() ? "on" : "off",CMarcoIndEntryFilter::CheckPrice() ? "on" : "off",
                  InpProximityPips*symbolUnits.pip,InpMergeClusteredZones ? "on" : "off",InpClusterTolerancePips*symbolUnits.pip,InpMergeExpandBounds ? "on" : "off",
                  m_zzDev,m_zzDepth,m_priceDiff,m_adjustTPForSpread ? "on" : "off",m_enableVicinityExit ? "on" : "off"));
      ResetM1EntryEngine();
      m1LBContext = new CMarcoM1LBContext();
      m1LBContext.Init(trackSweepsAnywhere, InpTrackPostInducementCHoCH,
                       InpMinTouches, InpProximityPips, InpStrictOriginPivots,
                       InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds,
                       InpCheckDemandSupply, InpCheckOrderBlocks, InpCheckSwingPOIs,
                       InpCheckFlipZones, InpCheckBreakers, symbolUnits.point,
                       m_applyEntryPolicyToPreventionExits);
      m_sim.startTime =0;
      m_sim.endTime = (m_endWindow == 0 || m_endWindow > TimeCurrent()) ? TimeCurrent() : m_endWindow;
      if(m_startWindow >= m_sim.endTime) return false;
      if(!CMarcoHistoryContext::ResolveStart(m_symbol,m_startWindow,m_sim.startTime))
        {
         PrintFormat("[HISTORY WARMUP] %s %s: previous-day history unavailable; simulation not run.",m_symbol,EnumToString(m_tradeTF));
         return false;
        }
      PrintFormat("[HISTORY WARMUP] %s %s: context from %s; trades from %s. Previous-day bars do not create simulated trades.",
                  m_symbol,EnumToString(m_tradeTF),TimeToString(m_sim.startTime,TIME_DATE|TIME_SECONDS),TimeToString(m_startWindow,TIME_DATE|TIME_SECONDS));

      // =====================================================================
      // 1. HTF DATA PREPARATION & CHRONOLOGICAL SIMULATION
      // =====================================================================

      m_sim.htf_copy = CopyTime(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_time);
      if(m_sim.htf_copy <= m_zzDepth * 2 || !CMarcoHistoryContext::HasPriorContext(m_sim.htf_time[0],m_startWindow))
         return false;

      if(CopyOpen(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_open) != m_sim.htf_copy ||
         CopyHigh(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_high) != m_sim.htf_copy ||
         CopyLow(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_low) != m_sim.htf_copy ||
         CopyClose(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_close) != m_sim.htf_copy ||
         CopyTickVolume(m_symbol, m_tradeTF, m_sim.startTime, m_sim.endTime, m_sim.htf_vol) != m_sim.htf_copy)
         return false;

      Settings* sHtf = new Settings(m_zzDev, m_zzDepth, clrNONE, true, false, false, false, m_priceDiff);
      sHtf.draw = false;
      m_sim.zzHtf = newInstance(sHtf);
      m_sim.zzHtf.zoneStartTime = m_startWindow;
      m_sim.msHtf = new CMarketStructure();
      m_sim.msHtf.Init(false, false, m_tradeTF);
      m_sim.dsHtf = new CDemandSupplyLogic();
      m_sim.spHtf = new CSwingPOILogic();
      m_sim.obHtf = new COrderBlockLogic();
      m_sim.fzHtf = new CFlipZoneLogic();
      m_sim.bbHtf = new CBreakerBlockLogic();

      m_sim.indHtf = new CInducementLogic();
      m_sim.indHtf.Init(InpMinTouches, InpProximityPips,
                  InpCheckDemandSupply, InpCheckOrderBlocks, InpCheckSwingPOIs,
                  InpCheckFlipZones, InpCheckBreakers,
                  InpStrictOriginPivots, InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds);

      m_sim.lbLogicHtf = new CLiquidityBlockLogic();
      m_sim.lbLogicHtf.Init(trackSweepsAnywhere, InpTrackPostInducementCHoCH, symbolUnits.point);

      m_sim.pipSize = symbolUnits.pip;
      m_htf_lb_count = 0;
      ArrayResize(m_htf_lbs, 0);
      ArrayResize(m_pivotConfirmations, 0);

      // =====================================================================
      // 2. LTF EXECUTION & BAR-BY-BAR TRADE RESOLUTION
      // =====================================================================

      m_sim.ltf_copy = CopyTime(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_time);
      if(m_sim.ltf_copy <= m_zzDepth * 2 || !CMarcoHistoryContext::HasPriorContext(m_sim.ltf_time[0],m_startWindow))
        {

         return false;
        }

      if(CopyOpen(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_open) != m_sim.ltf_copy ||
         CopyHigh(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_high) != m_sim.ltf_copy ||
         CopyLow(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_low) != m_sim.ltf_copy ||
         CopyClose(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_close) != m_sim.ltf_copy ||
         CopyTickVolume(m_symbol, m_tpTF, m_sim.startTime, m_sim.endTime, m_sim.ltf_vol) != m_sim.ltf_copy)
        {

         return false;
        }

      Settings* sLtf = new Settings(m_zzDev, m_zzDepth, clrNONE, true, false, false, false, m_priceDiff);
      sLtf.draw = false;
      m_sim.zzLtf = newInstance(sLtf);
      m_sim.zzLtf.zoneStartTime = m_startWindow;
      m_sim.msLtf = new CMarketStructure();
      m_sim.msLtf.Init(false, false, m_tpTF);
      m_sim.dsLtf = new CDemandSupplyLogic();
      m_sim.spLtf = new CSwingPOILogic();
      m_sim.obLtf = new COrderBlockLogic();
      m_sim.fzLtf = new CFlipZoneLogic();
      m_sim.bbLtf = new CBreakerBlockLogic();
      m_sim.indLtf = new CInducementLogic();
      m_sim.indLtf.Init(InpMinTouches, InpProximityPips,
                  InpCheckDemandSupply, InpCheckOrderBlocks, InpCheckSwingPOIs,
                  InpCheckFlipZones, InpCheckBreakers,
                  InpStrictOriginPivots, InpMergeClusteredZones, InpClusterTolerancePips, InpMergeExpandBounds);
      m_sim.lbLogicLtf = new CLiquidityBlockLogic();
      m_sim.lbLogicLtf.Init(trackSweepsAnywhere, InpTrackPostInducementCHoCH, symbolUnits.point);

      m_sim.run_copy = m_sim.ltf_copy;
      if(m_entryTF == ENTRY_TF_M1)
        {
         MqlRates entryRates[];
         m_sim.run_copy = CopyRates(m_symbol, PERIOD_M1, m_sim.startTime, m_sim.endTime, entryRates);
         if(m_sim.run_copy < 0)
            m_sim.run_copy = 0;
         ArrayResize(m_sim.run_time, m_sim.run_copy);
         ArrayResize(m_sim.run_open, m_sim.run_copy);
         ArrayResize(m_sim.run_high, m_sim.run_copy);
         ArrayResize(m_sim.run_low, m_sim.run_copy);
         ArrayResize(m_sim.run_close, m_sim.run_copy);
         ArrayResize(m_sim.run_vol, m_sim.run_copy);
         for(int r = 0; r < m_sim.run_copy; r++)
           {
            m_sim.run_time[r] = entryRates[r].time;
            m_sim.run_open[r] = entryRates[r].open;
            m_sim.run_high[r] = entryRates[r].high;
            m_sim.run_low[r] = entryRates[r].low;
            m_sim.run_close[r] = entryRates[r].close;
            m_sim.run_vol[r] = entryRates[r].tick_volume;
           }
        }
      else
        {
         ArrayCopy(m_sim.run_time, m_sim.ltf_time);
         ArrayCopy(m_sim.run_open, m_sim.ltf_open);
         ArrayCopy(m_sim.run_high, m_sim.ltf_high);
         ArrayCopy(m_sim.run_low, m_sim.ltf_low);
         ArrayCopy(m_sim.run_close, m_sim.ltf_close);
         ArrayCopy(m_sim.run_vol, m_sim.ltf_vol);
        }

      if(m_sim.run_copy<=m_zzDepth*2) return false;
      m_sim.digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_sim.point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // Constant spread assumption for this bar-based run; no future candle spread is consulted.
      m_sim.spreadVal = MathMax(0.0, (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD)) * m_sim.point;
      PrintFormat("[SIMULATION] %s %s: closed-candle signals, next-bar bid/ask open, fixed spread=%.8f; commission/swap not modeled.",
                  m_symbol, EnumToString(m_tradeTF), m_sim.spreadVal);

      m_sim.rejectionCount = CopyRates(m_symbol, PERIOD_M1, m_sim.startTime, m_sim.endTime, m_sim.rejectionRates);
      if(m_sim.rejectionCount <= 0 || !CMarcoHistoryContext::HasPriorContext(m_sim.rejectionRates[0].time,m_startWindow))
        {
         PrintFormat("[REJECTION CONTEXT UNAVAILABLE] %s: M1 history is required; simulation cancelled.", m_symbol);

         return false;
        }
      m_sim.nextRejection = 0;
      m_sim.nextHtf = 0;
      m_sim.nextTp = 0;
      m_sim.nextBar=1;
        }
      if(initializeOnly) return true;
      for(int i=m_sim.nextBar;i<m_sim.run_copy;i++)
        {
         if(through>0 && m_sim.run_time[i]>through) { m_sim.nextBar=i; return true; }
         m_sim.nextBar=i+1;
         int closed_i = i - 1;
         if(m_sim.run_time[closed_i] + PeriodSeconds(ExecutionTF()) > m_sim.run_time[i])
            continue;
         double executionBid = m_sim.run_open[i];
         double executionAsk = executionBid + m_sim.spreadVal;
         if(!m_sim.prepared)
           {
         while(m_sim.nextHtf < m_sim.htf_copy && m_sim.htf_time[m_sim.nextHtf] + PeriodSeconds(m_tradeTF) <= m_sim.run_time[i])
           {
            int h = m_sim.nextHtf++;
            m_sim.zzHtf.update(m_sim.htf_high[h], m_sim.htf_low[h], m_sim.htf_time[h], m_sim.htf_vol[h], h, true, false);
            CapturePivotConfirmations(m_sim.zzHtf, m_sim.htf_time[h] + PeriodSeconds(m_tradeTF));
            m_sim.msHtf.Update(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.htf_close, m_sim.zzHtf);
            m_sim.dsHtf.DetectPOIs(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.zzHtf);
            m_sim.spHtf.DetectPOIs(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.zzHtf);
            m_sim.obHtf.DetectPOIs(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.zzHtf);
            m_sim.fzHtf.DetectFlipZones(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.htf_close, m_sim.zzHtf, m_sim.msHtf, m_sim.dsHtf);
            m_sim.bbHtf.DetectBreakers(m_sim.zzHtf, m_sim.dsHtf, m_sim.spHtf, m_sim.obHtf, m_sim.fzHtf);
            m_sim.indHtf.Process(h, m_sim.htf_time, m_sim.htf_open, m_sim.htf_high, m_sim.htf_low, m_sim.htf_close, m_sim.zzHtf, m_sim.msHtf, m_sim.dsHtf, m_sim.spHtf, m_sim.obHtf, m_sim.fzHtf, m_sim.bbHtf, m_sim.pipSize);

            m_sim.lbLogicHtf.Process(h, m_sim.htf_time, m_sim.htf_high, m_sim.htf_low, m_sim.msHtf, m_sim.spHtf, m_sim.indHtf, m_sim.zzHtf);
            int cur_count  = m_sim.lbLogicHtf.m_liquidity_blocks.Total();

            if(cur_count > 0)
              {
               for(int b = 0; b < cur_count; b++)
                 {
                  CLiquidityBlock* src = (CLiquidityBlock*)m_sim.lbLogicHtf.m_liquidity_blocks.At(b);
                  if(src == NULL || CheckPointer(src) != POINTER_DYNAMIC || FindCachedLB(src.id) >= 0)
                     continue;

                  int sz = ArraySize(m_htf_lbs);
                  ArrayResize(m_htf_lbs, sz + 1);
                  m_htf_lbs[sz].id                   = src.id;
                  m_htf_lbs[sz].isBullish            = src.isBullish;
                  m_htf_lbs[sz].triggerType          = src.triggerType;
                  m_htf_lbs[sz].zoneHigh             = src.zoneHigh;
                  m_htf_lbs[sz].zoneLow              = src.zoneLow;
                  m_htf_lbs[sz].createdTime          = src.createdTime;
                  m_htf_lbs[sz].confirmedTime        = m_sim.htf_time[h];
                  m_htf_lbs[sz].entryTriggerTime     = 0;
                  m_htf_lbs[sz].opposingRejectedAt   = 0;
                  m_htf_lbs[sz].preferredLTF         = "";
                  m_htf_lbs[sz].sourceActive         = true;
                  m_htf_lbs[sz].firstTouchTime       = 0;
                  m_htf_lbs[sz].m1TouchTime = 0;
                  ZeroMemory(m_htf_lbs[sz].pivotEntry);
                  ZeroMemory(m_htf_lbs[sz].pivotWatch);
                     ZeroMemory(m_htf_lbs[sz].opposingWait);
                  CMarcoIndEntryFilter::Reset(m_htf_lbs[sz].indWait);
                  m_htf_lbs[sz].rejectionTouchTime = 0;
                  m_htf_lbs[sz].rejectionHTFTouchTime = 0;
                  m_htf_lbs[sz].m1PivotTime = 0;
                  m_htf_lbs[sz].m1PivotPrice = 0.0;
                  m_htf_lbs[sz].m1ConfirmTime = 0;
                  m_htf_lbs[sz].sweepLineTime        = src.sweepLineTime;
                  m_htf_lbs[sz].inducementOriginTime = src.inducementOriginTime;
                  m_htf_lbs[sz].touchCount           = 0;
                  m_htf_lbs[sz].isMitigated          = false;
                  m_htf_lbs[sz].mitigationTime       = 0;
                  m_htf_lbs[sz].nomenclature         = src.GetNomenclature(m_sim.msHtf.tf_str());
                  m_htf_lb_count++;
                 }
              }

            // Entry setup always waits for this arm. Guardrails either use raw
            // LBs immediately or wait for the same arm, according to the input.
            for(int cached = 0; cached < ArraySize(m_htf_lbs); cached++)
              {
               if(m_htf_lbs[cached].entryTriggerTime > 0 || !m_htf_lbs[cached].sourceActive)
                  continue;
               // Registration can merge an existing IND LB with a new BSL/SSL
               // trigger during this same bar. Read the authoritative trigger
               // before applying its entry policy.
               for(int b = 0; b < m_sim.lbLogicHtf.m_liquidity_blocks.Total(); b++)
                 {
                  CLiquidityBlock* src = (CLiquidityBlock*)m_sim.lbLogicHtf.m_liquidity_blocks.At(b);
                  if(src == NULL || CheckPointer(src) != POINTER_DYNAMIC || src.id != m_htf_lbs[cached].id)
                     continue;
                  m_htf_lbs[cached].triggerType = src.triggerType;
                  m_htf_lbs[cached].sweepLineTime = src.sweepLineTime;
                  break;
                 }
               datetime structureTime = m_sim.lbLogicHtf.EntryTriggerStructureTime(
                                           m_htf_lbs[cached].isBullish,m_htf_lbs[cached].triggerType,
                                           m_htf_lbs[cached].sweepLineTime,m_sim.indHtf,m_sim.msHtf,m_sim.htf_time[h]);
               if(structureTime <= 0)
                  continue;
               m_htf_lbs[cached].entryTriggerTime = m_sim.htf_time[h];
               PrintFormat("[ENTRY LB ARMED] %s %s LB=%s side=%s trigger=%s entry_structure=%s available=%s",
                           m_symbol,EnumToString(m_tradeTF),m_htf_lbs[cached].id,
                           m_htf_lbs[cached].isBullish ? "BL" : "BR",
                           EnumToString(m_htf_lbs[cached].triggerType),
                           TimeToString(structureTime,TIME_DATE|TIME_MINUTES),
                           TimeToString(m_sim.htf_time[h]+PeriodSeconds(m_tradeTF),TIME_DATE|TIME_MINUTES));
              }

            for(int cached = 0; cached < ArraySize(m_htf_lbs); cached++)
              {
               bool foundSource = false;
               for(int b = 0; b < m_sim.lbLogicHtf.m_liquidity_blocks.Total(); b++)
                 {
                  CLiquidityBlock* src = (CLiquidityBlock*)m_sim.lbLogicHtf.m_liquidity_blocks.At(b);
                  if(src == NULL || CheckPointer(src) != POINTER_DYNAMIC || src.id != m_htf_lbs[cached].id)
                     continue;

                  foundSource = true;
                  m_htf_lbs[cached].triggerType          = src.triggerType;
                  m_htf_lbs[cached].zoneHigh             = src.zoneHigh;
                  m_htf_lbs[cached].zoneLow              = src.zoneLow;
                  m_htf_lbs[cached].sweepLineTime        = src.sweepLineTime;
                  m_htf_lbs[cached].inducementOriginTime = src.inducementOriginTime;
                  m_htf_lbs[cached].nomenclature         = src.GetNomenclature(m_sim.msHtf.tf_str());
                  break;
                 }
               if(!foundSource && m_htf_lbs[cached].sourceActive)
                 {
                  m_htf_lbs[cached].sourceActive = false;
                  CTradeRejection::Retire(m_htf_lbs[cached].touchCount, m_htf_lbs[cached].isMitigated,
                                          m_htf_lbs[cached].mitigationTime, m_sim.htf_time[h] + PeriodSeconds(m_tradeTF));
                  m_htf_lbs[cached].m1TouchTime = 0;
                  ZeroMemory(m_htf_lbs[cached].pivotEntry);
                  ZeroMemory(m_htf_lbs[cached].pivotWatch);
                  CMarcoIndEntryFilter::Reset(m_htf_lbs[cached].indWait);
                  m_htf_lbs[cached].m1PivotTime = 0;
                  m_htf_lbs[cached].m1PivotPrice = 0.0;
                  m_htf_lbs[cached].m1ConfirmTime = 0;
                  PrintFormat("[LB REMOVED] %s %s LB=%s at=%s; pending entry cancelled.",
                              m_symbol, EnumToString(m_tradeTF), m_htf_lbs[cached].id,
                              TimeToString(m_sim.htf_time[h] + PeriodSeconds(m_tradeTF), TIME_DATE|TIME_SECONDS));
                 }
              }

            CaptureSetupIndContext(m_sim.indHtf,m_sim.msHtf,m_sim.htf_time[h]+PeriodSeconds(m_tradeTF),m_sim.htf_low[h],m_sim.htf_high[h]);
            CaptureRejectionContext(m_sim.msHtf, m_sim.lbLogicHtf, m_sim.indHtf, m_sim.htf_time[h] + PeriodSeconds(m_tradeTF), m_htfRejection);
            AuditChochTouches(m_sim.htf_time[h], m_sim.htf_low[h], m_sim.htf_high[h], m_sim.htf_time[h] + PeriodSeconds(m_tradeTF), m_sim.zzHtf, m_tradeTF, m_htfRejection);

            // Pre-Confirmation Touch & Mitigation Audit
            for(int k = 0; k < m_htf_lb_count; k++)
              {
               if(m_htf_lbs[k].entryTriggerTime <= 0)
                  continue;
               bool isBull   = m_htf_lbs[k].isBullish;
               double zHigh  = m_htf_lbs[k].zoneHigh;
               double zLow   = m_htf_lbs[k].zoneLow;
               double buffer = m_slBufferPips * m_sim.pipSize;

               int preConfTouches = 0;
               bool preConfMitigated = false;

               for(int j = 0; j < m_sim.htf_copy; j++)
                 {
                  if(m_sim.htf_time[j] <= m_htf_lbs[k].createdTime)
                     continue;
                  if(m_sim.htf_time[j] > m_htf_lbs[k].entryTriggerTime)
                     break;

                  if(isBull)
                    {
                     if(m_sim.htf_low[j] <= zHigh)
                        preConfTouches++;
                     if(m_sim.htf_low[j] < (zLow - buffer))
                        preConfMitigated = true;
                    }
                  else
                    {
                     if(m_sim.htf_high[j] >= zLow)
                        preConfTouches++;
                     if(m_sim.htf_high[j] > (zHigh + buffer))
                        preConfMitigated = true;
                    }
                 }

               int preConfPivots = CountPivotTouches(isBull, zHigh, zLow, buffer, m_htf_lbs[k].createdTime, m_htf_lbs[k].entryTriggerTime, m_sim.zzHtf);

               if(!m_riskyMode)
                 {
                  if(CTradeRejection::PreConfirmation(false, preConfTouches, preConfPivots, preConfMitigated))
                    {
                     m_htf_lbs[k].touchCount     = MathMax(1, preConfTouches);
                     m_htf_lbs[k].isMitigated    = true;
                     m_htf_lbs[k].mitigationTime = m_htf_lbs[k].entryTriggerTime;
                    }
                 }
               else
                 {
                  if(CTradeRejection::PreConfirmation(true, 0, 0, preConfMitigated))
                    {
                     m_htf_lbs[k].isMitigated    = true;
                     m_htf_lbs[k].mitigationTime = m_htf_lbs[k].entryTriggerTime;
                    }
                 }
              }
           }
         while(m_sim.nextTp < m_sim.ltf_copy && m_sim.ltf_time[m_sim.nextTp] + PeriodSeconds(m_tpTF) <= m_sim.run_time[i])
           {
            int tp_i = m_sim.nextTp++;
         m_sim.zzLtf.update(m_sim.ltf_high[tp_i], m_sim.ltf_low[tp_i], m_sim.ltf_time[tp_i], m_sim.ltf_vol[tp_i], tp_i, true, false);
         m_sim.msLtf.Update(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.ltf_close, m_sim.zzLtf);
         m_sim.dsLtf.DetectPOIs(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.zzLtf);
         m_sim.dsLtf.UpdateMitigation(m_sim.ltf_close[tp_i]);
         m_sim.spLtf.DetectPOIs(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.zzLtf);
         m_sim.spLtf.UpdateMitigation(m_sim.ltf_close[tp_i]);
         m_sim.obLtf.DetectPOIs(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.zzLtf);
         m_sim.obLtf.UpdateMitigation(m_sim.ltf_close[tp_i]);
         m_sim.fzLtf.DetectFlipZones(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.ltf_close, m_sim.zzLtf, m_sim.msLtf, m_sim.dsLtf);
         m_sim.fzLtf.UpdateMitigation(m_sim.ltf_close[tp_i]);
         m_sim.bbLtf.DetectBreakers(m_sim.zzLtf, m_sim.dsLtf, m_sim.spLtf, m_sim.obLtf, m_sim.fzLtf);
         m_sim.bbLtf.UpdateMitigation(m_sim.ltf_high[tp_i], m_sim.ltf_low[tp_i], m_sim.ltf_time[tp_i]);
         m_sim.indLtf.Process(tp_i, m_sim.ltf_time, m_sim.ltf_open, m_sim.ltf_high, m_sim.ltf_low, m_sim.ltf_close, m_sim.zzLtf, m_sim.msLtf, m_sim.dsLtf, m_sim.spLtf, m_sim.obLtf, m_sim.fzLtf, m_sim.bbLtf, m_sim.pipSize);
         m_sim.lbLogicLtf.Process(tp_i, m_sim.ltf_time, m_sim.ltf_high, m_sim.ltf_low, m_sim.msLtf, m_sim.spLtf, m_sim.indLtf, m_sim.zzLtf);

           }
         while(m_sim.nextRejection < m_sim.rejectionCount && m_sim.rejectionRates[m_sim.nextRejection].time + PeriodSeconds(PERIOD_M1) <= m_sim.run_time[i])
            {
             int r = m_sim.nextRejection++;
             FeedM1EntryBar(m_sim.rejectionRates[r].time, m_sim.rejectionRates[r].open, m_sim.rejectionRates[r].high,
                            m_sim.rejectionRates[r].low, m_sim.rejectionRates[r].close, m_sim.rejectionRates[r].tick_volume);
            }

         // Warm all setup/TP/M1 contexts before the requested window, without trading.
         if(!CMarcoHistoryContext::TradingWindow(m_sim.run_time[i],m_startWindow)) continue;

         // -----------------------------------------------------------------
         // 1. CHECK TRADE EXITS (FOR PREVIOUSLY OPENED POSITIONS)
         // -----------------------------------------------------------------
         ResolveClosedBar(m_sim.run_time[closed_i], m_sim.run_open[closed_i], m_sim.run_high[closed_i],
                          m_sim.run_low[closed_i], m_sim.run_close[closed_i], m_sim.spreadVal, m_sim.pipSize);
         // Signals use only closed candles; execute at this next M1 bid/ask open.
         ApplyStructureExits(m_sim.run_time[i],executionBid,executionAsk);
         for(int t=0;t<ArraySize(m_trades);t++)
            if(m_trades[t].isOpen)
              {
               ExtendFromNewLB(m_trades[t].tpPlan,m_trades[t].extension,m_trades[t].openTime,m_sim.run_time[i]);
               m_trades[t].slPrice=CMarcoStagedTP::Stop(m_trades[t].tpPlan);
              }

         // -----------------------------------------------------------------
         // 2. TRACK POST-CONFIRMATION MITIGATIONS
         // -----------------------------------------------------------------
         for(int k = 0; k < m_htf_lb_count; k++)
           {
            if(m_htf_lbs[k].entryTriggerTime <= 0)
               continue;
            if(m_htf_lbs[k].isMitigated)
               continue;

            datetime eligibleTime = m_htf_lbs[k].entryTriggerTime + PeriodSeconds(m_tradeTF);
            if(m_sim.run_time[closed_i] < eligibleTime)
               continue;

            double buffer = m_slBufferPips * m_sim.pipSize;

            if(m_htf_lbs[k].isBullish)
              {
               if(CTradeRejection::BoundaryBroken(true, m_sim.run_low[closed_i], m_sim.run_high[closed_i], m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh, buffer))
                 {
                  m_htf_lbs[k].isMitigated = true;
                  m_htf_lbs[k].mitigationTime = m_sim.run_time[closed_i];
                 }
              }
            else
              {
               if(CTradeRejection::BoundaryBroken(false, m_sim.run_low[closed_i], m_sim.run_high[closed_i], m_htf_lbs[k].zoneLow, m_htf_lbs[k].zoneHigh, buffer))
                 {
                  m_htf_lbs[k].isMitigated = true;
                  m_htf_lbs[k].mitigationTime = m_sim.run_time[closed_i];
                 }
              }
           }

         ObserveEntryClusters(m_sim.run_time[i],m_sim.lbLogicHtf,0);
         SyncGlobalTrades();
         m_sim.prepared=true;
           }
         if(prepareOnly) { m_sim.nextBar=i; return true; }
         s_clusters.RetireCompleted();
         RegisterPreparedClusters(m_sim.run_time[i]);
         RegisterPreparedTFPreferences(m_sim.run_time[i]);
         m_sim.prepared=false;
         // -----------------------------------------------------------------
         // 3. SCAN NEW ENTRY TRIGGERS ON THIS BAR
         // -----------------------------------------------------------------
         for(int k = 0; k < m_htf_lb_count; k++)
           {
            if(m_htf_lbs[k].entryTriggerTime <= 0)
               continue;
            if(CTradeRejection::Used(m_htf_lbs[k].touchCount, m_htf_lbs[k].isMitigated))
               continue;

            // Strict 00:00:00 Daily Structural Creation Enforcement
            datetime dayStart = m_sim.run_time[i] - (m_sim.run_time[i] % 86400); // 00:00:00 of current day
            datetime dayEnd   = dayStart + 86399;                    // 23:59:59 of current day

            if(m_htf_lbs[k].triggerType == LB_TRIGGER_BL_BSL || m_htf_lbs[k].triggerType == LB_TRIGGER_BR_SSL ||
               m_htf_lbs[k].triggerType == LB_TRIGGER_BL_IND_BSL || m_htf_lbs[k].triggerType == LB_TRIGGER_BR_IND_SSL)
              {
               if(CTradeRejection::OutsideSession(m_htf_lbs[k].sweepLineTime, m_htf_lbs[k].createdTime, m_htf_lbs[k].confirmedTime, dayStart))
                  continue;
              }

            if(m_htf_lbs[k].triggerType == LB_TRIGGER_BL_IND || m_htf_lbs[k].triggerType == LB_TRIGGER_BR_IND)
              {
               if(CTradeRejection::OutsideSession(m_htf_lbs[k].inducementOriginTime, m_htf_lbs[k].createdTime, m_htf_lbs[k].confirmedTime, dayStart))
                  continue;
              }

            datetime eligibleTime = m_htf_lbs[k].entryTriggerTime + PeriodSeconds(m_tradeTF);
            if(CTradeRejection::Unconfirmed(m_htf_lbs[k].entryTriggerTime, PeriodSeconds(m_tradeTF), m_sim.run_time[i]))
               continue;

            double buffer = m_slBufferPips * m_sim.pipSize;
            bool isBull   = m_htf_lbs[k].isBullish;
            double zHigh  = m_htf_lbs[k].zoneHigh;
            double zLow   = m_htf_lbs[k].zoneLow;
            if(CTradeRejection::BoundaryBroken(isBull, executionBid, executionAsk, zLow, zHigh, buffer))
              {
               m_htf_lbs[k].isMitigated = true;
               m_htf_lbs[k].mitigationTime = m_sim.run_time[i];
               continue;
              }

            ObserveOpposingEntry(k,m_sim.run_time[i],executionBid,executionBid,m_sim.run_time[i],m_tradeTF);
            ObserveOpposingEntry(k,m_sim.run_time[i],executionBid,executionBid,m_sim.run_time[i],PERIOD_M1);
            if(!m_htf_lbs[k].opposingWait.required && CMarcoPivotEntry::Enabled())
              {
               if(ObservePivotEntryRange(k,m_sim.run_time[i],executionBid,executionBid)) continue;
               datetime latestPivot=0,latestConfirmed=0; double latestPrice=0;
               ZigZag* currentZZ=m_entryTF==ENTRY_TF_M1 ? zzEntry : m_sim.zzHtf;
               if(m_entryTF!=ENTRY_TF_M1 || m_htf_lbs[k].m1TouchTime>0)
                  GetLatestEntryPivot(k,m_sim.run_time[i],currentZZ,m_entryTF==ENTRY_TF_M1,latestPivot,latestPrice,latestConfirmed);
              }
            if(CheckIndWaitBoundary(k,m_sim.run_time[i],executionBid,executionAsk)) continue;

            ObserveRejectionTouch(k, m_sim.run_time[closed_i], m_sim.run_low[closed_i], m_sim.run_high[closed_i], m_sim.run_time[i], m_tradeTF);
            ObserveRejectionTouch(k, m_sim.run_time[i], executionBid, executionBid, m_sim.run_time[i], m_tradeTF);
            ObserveRejectionTouch(k, m_sim.run_time[i], executionBid, executionBid, m_sim.run_time[i], PERIOD_M1);
            if(CheckChochRejection(k, m_sim.run_time[i], m_sim.zzHtf, m_tradeTF, m_htfRejection) ||
               (m1LBContext != NULL && CheckChochRejection(k, m_sim.run_time[i], zzEntry, PERIOD_M1, m1LBContext.rejectionHistory))) continue;
            if(DeferToLowerTF(k,m_sim.run_time[i])) continue;
            double candidateBid=executionBid, candidateAsk=executionAsk;
            double   firstPivotPrice = 0.0;
            datetime firstPivotTime = 0;
            datetime firstPivotConfirmTime = 0;
            int pivotTouches = 0;
            ZigZag* entryZigZag = m_sim.zzHtf;
            bool reversalEntry=m_applyEntryPolicyToPreventionExits && m_htf_lbs[k].opposingWait.required;
            SRejectionEvent reversalEvent;
            if(reversalEntry)
              {
               if(!ResolveOpposingEntry(k,m_sim.run_time[i],isBull ? executionAsk : executionBid,reversalEvent)) continue;
               firstPivotTime=reversalEvent.originTime; firstPivotPrice=reversalEvent.originPrice;
               firstPivotConfirmTime=reversalEvent.available; pivotTouches=1; entryZigZag=zzEntry;
              }
            else if(m_entryTF == ENTRY_TF_M1)
              {
               // The closed M1 range establishes the first touch minute without future data.
               ArmM1Entry(k, m_sim.run_time[closed_i], m_sim.run_low[closed_i], m_sim.run_high[closed_i]);
               ArmM1Entry(k, m_sim.run_time[i], candidateBid, candidateBid);
               if(!GetM1EntryPivot(k, m_sim.run_time[i], firstPivotTime, firstPivotPrice, firstPivotConfirmTime))
                  continue;
               if(!CMarcoPivotEntry::Prepare(m_htf_lbs[k].pivotEntry,m_symbol,PERIOD_M1,isBull,
                                            firstPivotTime,firstPivotConfirmTime,m_sim.run_time[i])) continue;
               if(!CMarcoPivotEntry::Enabled() && !CTradeRejection::M1Expired(m_last_entry_bar,firstPivotConfirmTime) &&
                  SkipIndEntryPrice(k,m_sim.run_time[i],isBull ? candidateAsk : candidateBid)) continue;
               if(!CMarcoPivotEntry::Waiting(m_htf_lbs[k].pivotEntry) &&
                  CTradeRejection::M1Expired(m_last_entry_bar, firstPivotConfirmTime))
                 {
                  CTradeRejection::Consume(m_htf_lbs[k].touchCount, 1);
                  continue;
                 }
               pivotTouches = 1;
               entryZigZag = zzEntry;
              }
            else
              {
               if(CMarcoPivotEntry::Enabled())
              {
               if(!GetLatestEntryPivot(k,m_sim.run_time[i],m_sim.zzHtf,false,firstPivotTime,firstPivotPrice,firstPivotConfirmTime)) continue;
               pivotTouches=1;
              }
            else if(CMarcoIndEntryFilter::Enabled() && m_htf_lbs[k].indWait.waiting)
                 {
                  if(!GetSetupIndWaitPivot(k,m_sim.run_time[i],m_sim.zzHtf,firstPivotTime,firstPivotPrice,firstPivotConfirmTime)) continue;
                  pivotTouches=1;
                 }
               else
                  pivotTouches = CountTouchingPivots(isBull, zHigh, zLow, buffer,
                                                  m_htf_lbs[k].entryTriggerTime, m_sim.run_time[i],
                                                  m_sim.zzHtf, firstPivotTime, firstPivotPrice, firstPivotConfirmTime);

               if(CTradeRejection::MultiplePivots(pivotTouches))
                 {
                  CTradeRejection::Consume(m_htf_lbs[k].touchCount, pivotTouches);
                  continue;
                 }

               if(m_requireZZConfirmation || CMarcoPivotEntry::Enabled() || (CMarcoIndEntryFilter::Enabled() && m_htf_lbs[k].indWait.waiting))
                 {
                  if(CTradeRejection::NeedsPivot(pivotTouches))
                     continue;

                  if(m_sim.run_time[i] < firstPivotConfirmTime)
                     continue;

                  if(!CMarcoPivotEntry::Prepare(m_htf_lbs[k].pivotEntry,m_symbol,m_tradeTF,isBull,
                                              firstPivotTime,firstPivotConfirmTime,m_sim.run_time[i])) continue;

                  if(!CMarcoPivotEntry::Waiting(m_htf_lbs[k].pivotEntry) &&
                     CTradeRejection::Expired(m_sim.run_time[i], firstPivotConfirmTime, PeriodSeconds(m_tradeTF)))
                    {
                     CTradeRejection::Consume(m_htf_lbs[k].touchCount, 1);
                     continue;
                    }
                 }
               else
                 {
                  bool priceInZone = CTradeRejection::DirectEntry(isBull, candidateBid, candidateAsk, zLow, zHigh, buffer);
                  if(!priceInZone)
                     continue;
                 }

              }

            bool edgeIntrabar=false;
            double edgeHigh=m_sim.run_high[i], edgeLow=m_sim.run_low[i];
            if(!m_htf_lbs[k].opposingWait.required && CMarcoPivotEntry::Enabled())
              {
               if(!CMarcoPivotEntry::Bar(m_htf_lbs[k].pivotEntry,isBull,m_sim.run_open[i],m_sim.run_high[i],
                                        m_sim.run_low[i],m_sim.run_close[i],candidateBid,edgeIntrabar,edgeHigh,edgeLow)) continue;
               // An unfinished candle cannot supply a future historical level fill.
               if(edgeIntrabar && m_sim.run_time[i]+PeriodSeconds(ExecutionTF())>m_sim.endTime) continue;
               candidateAsk=candidateBid+m_sim.spreadVal;
               // Cancel invalidations before the crossing on the existing OHLC
               // path (bullish candle O-L-H-C, bearish candle O-H-L-C).
               double priorLow=(isBull && m_sim.run_close[i]>=m_sim.run_open[i]) ? m_sim.run_low[i] : m_sim.run_open[i];
               double priorHigh=(!isBull && m_sim.run_close[i]<m_sim.run_open[i]) ? m_sim.run_high[i] : m_sim.run_open[i];
               if(edgeIntrabar && (ObservePivotEntryRange(k,m_sim.run_time[i],priorLow,priorHigh) ||
                  m_htf_lbs[k].pivotWatch.invalid || CheckIndWaitBoundary(k,m_sim.run_time[i],priorLow,priorHigh))) continue;
               if(CheckIndWaitBoundary(k,m_sim.run_time[i],candidateBid,candidateAsk) ||
                  SkipIndEntryPrice(k,m_sim.run_time[i],isBull ? candidateAsk : candidateBid,firstPivotTime,firstPivotConfirmTime)) continue;
              }

            if((reversalEntry || m_entryTF!=ENTRY_TF_M1) &&
               (SkipIndPivot(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime) ||
                !IndEntryReady(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime,m_sim.run_time[i]) ||
                SkipIndEntryPrice(k,m_sim.run_time[i],isBull ? candidateAsk : candidateBid,firstPivotTime,firstPivotConfirmTime))) continue;

            if(!s_clusters.Eligible(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,m_sim.run_time[i])) continue;
            string clusterSource=""; datetime clusterUsed=0;
            if(s_clusters.Blocked(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,m_sim.run_time[i],clusterSource,clusterUsed))
              {
               PrintFormat("[LB CLUSTER BLOCK] %s %s LB=%s: block source=%s recorded_at=%s; a traded cluster remains blocked until all members mitigate or the next broker day.",
                           m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,clusterSource,TimeToString(clusterUsed,TIME_DATE|TIME_SECONDS));
               continue;
              }

            // Opposing Leg Filter (Anti-Bait Trap Guard)
            if(!reversalEntry && IsLegComingFromOppositeLB(isBull, firstPivotTime, entryZigZag, buffer, m_sim.run_time[i]))
              {
               CTradeRejection::Consume(m_htf_lbs[k].touchCount, MathMax(1, pivotTouches));
               continue;
              }

            // =============================================================
            // SYMBOL-LEVEL CONCURRENCY & 50% TP PROGRESS GUARD
            // =============================================================
            bool blockNewTrade = false;
            bool oppositePositionBlock = false;

            // 1. Check open trades within this timeframe instance
            for(int ot = 0; ot < ArraySize(m_trades); ot++)
              {
               if(m_trades[ot].isOpen)
                 {
                  if(CTradeRejection::OppositeDirection(isBull,m_trades[ot].direction))
                    {
                     PrintFormat("[OPPOSITE POSITION BLOCK] %s %s: %s entry skipped at %s; %s trade #%I64u is still open.",
                                 m_symbol,EnumToString(m_tradeTF),isBull ? "BUY" : "SELL",
                                 TimeToString(m_sim.run_time[i],TIME_DATE|TIME_SECONDS),isBull ? "SELL" : "BUY",m_trades[ot].ticket);
                     oppositePositionBlock = true;
                     blockNewTrade = true;
                     break;
                    }
                  if(!m_allowOverlappingTrades)
                    {
                     blockNewTrade = true;
                     break;
                    }

                  double openPx    = m_trades[ot].openPrice;
                  double tpPx_open = m_trades[ot].tpPrice;

                  if(m_trades[ot].direction == 1) // BUY
                    {
                     double tpDist = tpPx_open - openPx;
                     if(tpDist <= 0.0)
                       {
                        blockNewTrade = true;
                        break;
                       }
                     double coveredDist = candidateBid - openPx;
                     if(CTradeRejection::Overlap(m_allowOverlappingTrades, tpDist, coveredDist))
                       {
                        blockNewTrade = true;
                        break;
                       }
                    }
                  else
                     if(m_trades[ot].direction == -1) // SELL
                       {
                        double tpDist = openPx - tpPx_open;
                        if(tpDist <= 0.0)
                          {
                           blockNewTrade = true;
                           break;
                          }
                        double coveredDist = openPx - candidateAsk;
                        if(CTradeRejection::Overlap(m_allowOverlappingTrades, tpDist, coveredDist))
                          {
                           blockNewTrade = true;
                           break;
                          }
                       }
                 }
              }

            // 2. Check if this symbol has an active open trade from another timeframe
            if(!blockNewTrade)
              {
               for(int gt = 0; gt < ArraySize(s_global_trades); gt++)
                 {
                  if(s_global_trades[gt].symbol == m_symbol)
                    {
                     if(m_sim.run_time[i] >= s_global_trades[gt].openTime &&
                        (s_global_trades[gt].closeTime == 0 || m_sim.run_time[i] < s_global_trades[gt].closeTime))
                       {
                        if(CTradeRejection::OppositeDirection(isBull,s_global_trades[gt].direction))
                          {
                           PrintFormat("[OPPOSITE POSITION BLOCK] %s %s: %s entry skipped at %s; %s trade from another setup timeframe remains open since %s.",
                                       m_symbol,EnumToString(m_tradeTF),isBull ? "BUY" : "SELL",
                                       TimeToString(m_sim.run_time[i],TIME_DATE|TIME_SECONDS),isBull ? "SELL" : "BUY",
                                       TimeToString(s_global_trades[gt].openTime,TIME_DATE|TIME_SECONDS));
                           oppositePositionBlock = true;
                           blockNewTrade = true;
                           break;
                          }
                        if(!m_allowOverlappingTrades)
                          {
                           blockNewTrade = true;
                           break;
                          }

                        double openPx    = s_global_trades[gt].openPrice;
                        double tpPx_open = s_global_trades[gt].tpPrice;

                        if(s_global_trades[gt].direction == 1) // BUY
                          {
                           double tpDist = tpPx_open - openPx;
                           if(tpDist <= 0.0)
                             {
                              blockNewTrade = true;
                              break;
                             }
                           double coveredDist = candidateBid - openPx;
                           if(CTradeRejection::Overlap(m_allowOverlappingTrades, tpDist, coveredDist))
                             {
                              blockNewTrade = true;
                              break;
                             }
                          }
                        else
                           if(s_global_trades[gt].direction == -1) // SELL
                             {
                              double tpDist = openPx - tpPx_open;
                              if(tpDist <= 0.0)
                                {
                                 blockNewTrade = true;
                                 break;
                                }
                              double coveredDist = openPx - candidateAsk;
                              if(CTradeRejection::Overlap(m_allowOverlappingTrades, tpDist, coveredDist))
                                {
                                 blockNewTrade = true;
                                 break;
                                }
                             }
                       }
                    }
                 }
              }

            if(blockNewTrade)
              {
               if(m_entryTF == ENTRY_TF_M1 || oppositePositionBlock)
                  continue; // Keep observing M1 touches and allow other same-direction setups.
               break;
              }

            if(m_htf_lbs[k].firstTouchTime == 0)
               m_htf_lbs[k].firstTouchTime = m_sim.run_time[i];

            double entryPx = 0.0;
            if(reversalEntry || m_entryTF == ENTRY_TF_M1 || m_requireZZConfirmation || CMarcoPivotEntry::Enabled())
               entryPx = isBull ? candidateAsk : candidateBid;
            else
               entryPx = isBull ? zHigh : zLow;

            // =============================================================
            // PURE EXIT STOP LOSS PLACEMENT
            // =============================================================
            double slReference = isBull ? zLow : zHigh;
            if(reversalEntry || (m_entryTF == ENTRY_TF_M1 && m_slLocation == SL_LOCATION_CONFIRM_PIVOT))
               slReference = firstPivotPrice;
            else if(m_slLocation == SL_LOCATION_CONFIRM_PIVOT && firstPivotPrice > 0.0)
              {
               double testSL = isBull ? firstPivotPrice - buffer : firstPivotPrice + buffer;
               if(isBull ? testSL < entryPx : testSL > entryPx) slReference = firstPivotPrice;
              }
            double slPx = 0.0;
            if(!CMarcoSymbolUnits::BufferedStop(m_symbol, slReference, m_slBufferPips, isBull, slPx)) continue;
            if(CTradeRejection::InvalidSL(isBull, entryPx, slPx))
               continue;
            SMarcoTPPlan plan;
            double lbTP=FindOpposingLB_TP(isBull,entryPx,dayStart,dayEnd,m_sim.lbLogicLtf);
            double indTP=FindOpposingIND_TP(isBull,entryPx,dayStart,dayEnd,m_sim.indLtf);
            if(!CMarcoStagedTP::Build(plan,isBull,entryPx,slPx,lbTP,indTP,m_fallbackRR,(int)m_tpPriority1,
                                    m_adjustTPForSpread ? m_sim.spreadVal : 0.0,
                                    SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE),m_sim.digits)) continue;
            if(reversalEntry)
              {
               plan.reversalEntryEvent=reversalEvent.time;
               PrintFormat("[M1 REVERSAL ENTRY READY] %s %s LB=%s CHoCH=%s swing=%s pivot=%.8f entry=%.8f SL=%.8f",
                           m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                           TimeToString(reversalEvent.time,TIME_DATE|TIME_SECONDS),
                           TimeToString(reversalEvent.originTime,TIME_DATE|TIME_SECONDS),firstPivotPrice,entryPx,slPx);
              }
            int primary=CMarcoStagedTP::Primary(plan);
            double rr=MathAbs(plan.price[primary]-entryPx)/MathAbs(entryPx-slPx);
            if(CTradeRejection::LowRR(m_blockLessRR,plan.kind[primary]<2,rr,m_fallbackRR))
              { CTradeRejection::Consume(m_htf_lbs[k].touchCount,1); continue; }
            double tpPx=plan.price[primary]; // Preserve priority-TP overlap progress checks.
            CTradeRejection::Consume(m_htf_lbs[k].touchCount, 1);

            double lotSize = CalculateLotSize(isBull, entryPx, slPx, candidateBid, candidateAsk);
            if(lotSize <= 0.0)
               continue;
            uint brokerRejection=CMarcoBrokerExecution::Rejection(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,isBull,
                                                                 m_sim.run_time[i],lotSize,SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP));
            if(brokerRejection!=0)
              {
               PrintFormat("[SIM BROKER REJECTED] %s %s LB=%s at=%s code=%u lots=%.8f; skipped, no trade or P/L recorded.",
                           m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,TimeToString(m_sim.run_time[i],TIME_DATE|TIME_SECONDS),brokerRejection,lotSize);
               continue;
              }
            double stopProfit = 0.0;
            if(!OrderCalcProfit(isBull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, lotSize, entryPx, slPx, stopProfit) ||
               !MathIsValidNumber(stopProfit) || stopProfit>=0)
               continue;
            PrintFormat("[ENTRY REJECTION AUDIT v2] %s %s LB=%s entry=%s mode=%s pivot=%s confirmed=%s",
                        m_symbol, EnumToString(m_tradeTF), m_htf_lbs[k].id,
                        TimeToString(m_sim.run_time[i], TIME_DATE|TIME_SECONDS), EnumToString(m_entryTF),
                        TimeToString(firstPivotTime, TIME_DATE|TIME_SECONDS), TimeToString(firstPivotConfirmTime, TIME_DATE|TIME_SECONDS));
            CheckChochRejection(k, m_sim.run_time[i], m_sim.zzHtf, m_tradeTF, m_htfRejection, true);
            if(m1LBContext != NULL)
               CheckChochRejection(k, m_sim.run_time[i], zzEntry, PERIOD_M1, m1LBContext.rejectionHistory, true);
            else
               Print("[CHOCH AUDIT] source=PERIOD_M1 reason=MISSING_LB_CONTEXT");
            int t_idx = ArraySize(m_trades);
            ArrayResize(m_trades, t_idx + 1);

            ZeroMemory(m_trades[t_idx]);
            m_trades[t_idx].edgeIntrabar = edgeIntrabar;
            m_trades[t_idx].edgeBid = candidateBid;
            m_trades[t_idx].edgeHigh = edgeHigh;
            m_trades[t_idx].edgeLow = edgeLow;
            m_trades[t_idx].tpPlan      = plan;
            m_trades[t_idx].ticket      = m_ticketCounter++;
            m_trades[t_idx].symbol      = m_symbol;
            m_trades[t_idx].setupType   = m_htf_lbs[k].nomenclature;
            m_trades[t_idx].direction   = isBull ? 1 : -1;
            m_trades[t_idx].openTime    = m_sim.run_time[i];
            m_trades[t_idx].openPrice   = entryPx;
            m_trades[t_idx].slPrice     = slPx;
            m_trades[t_idx].tpPrice     = tpPx;
            m_trades[t_idx].lots        = lotSize;
            m_trades[t_idx].riskAmount         = MathAbs(stopProfit);
            m_trades[t_idx].isOpen             = true;
            m_trades[t_idx].outcome            = "OPEN";
            m_trades[t_idx].hasEnteredVicinity = false;
            s_clusters.Consume(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,m_sim.run_time[i]);

            }
         SyncGlobalTrades();
        }

      // Resolve the final bar only when it is fully inside the requested history window.
      int lastBar = m_sim.run_copy - 1;
      if(lastBar >= 0 && m_sim.run_time[lastBar] + PeriodSeconds(ExecutionTF()) <= m_sim.endTime)
         ResolveClosedBar(m_sim.run_time[lastBar], m_sim.run_open[lastBar], m_sim.run_high[lastBar],
                          m_sim.run_low[lastBar], m_sim.run_close[lastBar], m_sim.spreadVal, m_sim.pipSize);

      // =====================================================================
      // 3. ACCUMULATE METRICS & REGISTER SYMBOL TRADES
      // =====================================================================
      m_totalLots    = 0.0;
      m_totalRewards = 0.0;
      for(int t = 0; t < ArraySize(m_trades); t++)
        {
         m_totalLots += m_trades[t].lots*(1.0-m_trades[t].tpPlan.remaining);
         m_totalRewards += m_trades[t].tpPlan.realizedR;
        }

      SyncGlobalTrades();
      m_simComplete=true;
      delete m_sim; m_sim=NULL;
      return true;
     }

  };

// All setup timeframes of one symbol share the clock. At each timestamp every
// instance updates structures/mitigations/exits before any instance admits entries.
struct SMarcoSimulationConfig
  {
   bool sweeps,postInd,strictOrigin,merge,expand,ds,ob,sp,fz,bb;
   int touches;
   double proximity,tolerance;
  };
class CMarcoSimulationBatch
  {
public:
   static bool Run(CMarcoBacktestInstance* instance,const SMarcoSimulationConfig &c,
                   datetime through=0,bool initialize=false,bool prepare=false)
     {
      return instance.RunSimulation(c.sweeps,c.postInd,c.touches,c.proximity,c.strictOrigin,
                                    c.merge,c.tolerance,c.expand,c.ds,c.ob,c.sp,c.fz,c.bb,through,initialize,prepare);
     }
   static bool Pump(CMarcoBacktestInstance* &items[],int first,int end,const SMarcoSimulationConfig &c,
                    int milliseconds=250)
     {
      ulong started=GetTickCount64();
      for(int i=first;i<end;i++)
        {
         if(items[i]==NULL || items[i].m_simComplete || items[i].m_sim!=NULL) continue;
         if(!Run(items[i],c,0,true))
           {
            items[i].m_simFailed=true; items[i].m_simComplete=true;
            if(CheckPointer(items[i].m_sim)==POINTER_DYNAMIC) delete items[i].m_sim;
            items[i].m_sim=NULL;
           }
         if(IsStopped() || GetTickCount64()-started>=(ulong)milliseconds) return false;
        }
      while(!IsStopped())
        {
         datetime next=0;
         for(int i=first;i<end;i++)
           {
            if(items[i]==NULL || items[i].m_simComplete) continue;
            datetime at=items[i].NextSimulationTime();
            if(at>0 && (next==0 || at<next)) next=at;
           }
         if(next==0) return true;
         // Finish both phases before yielding, even when this timestamp exceeds the budget.
         for(int phase=0;phase<2;phase++)
           {
            if(phase==1)
              {
               CMarcoBacktestInstance::s_clusters.RetireCompleted();
               for(int i=first;i<end;i++)
                  if(items[i]!=NULL && !items[i].m_simComplete && items[i].NextSimulationTime()==next)
                     items[i].RegisterPreparedClusters(next);
               // New overlap/bridge members can change old candidates' eligibility.
               // Freeze preferences only after every TF has joined its clusters.
               for(int i=first;i<end;i++)
                  if(items[i]!=NULL && !items[i].m_simComplete && items[i].NextSimulationTime()==next)
                     items[i].RegisterPreparedTFPreferences(next);
              }
            for(int i=first;i<end;i++)
              {
               if(items[i]==NULL || items[i].m_simComplete || items[i].NextSimulationTime()!=next) continue;
               if(!Run(items[i],c,next,false,phase==0)) return false;
              }
           }
         if(GetTickCount64()-started>=(ulong)milliseconds) return false;
        }
      return false;
     }
  };

// Static member instantiation
SBacktestGlobalTrade CMarcoBacktestInstance::s_global_trades[];
CMarcoLBEntryClusters CMarcoBacktestInstance::s_clusters;

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\marco_backtest.mqh
