//+------------------------------------------------------------------+
//|                                Include\Custom\Marcotrades\Inducements.mqh |
//|                 Smart Money Concepts: Inducement Detection Engine|
//|                 Identifies Buyers' & Sellers' Inducement Zones   |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.03"

#ifndef MARCOTRADES_INDUCEMENTS_MQH
#define MARCOTRADES_INDUCEMENTS_MQH

#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\trade_rejection.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mql_plotting.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Inducement Zone Model                                            |
//+------------------------------------------------------------------+
class CInducementZone : public CObject
  {
public:
   string            id;                 // Unique zone identifier
   string            sourceType;         // "Demand", "Supply", "Order Block", "Swing POI", "Flip", "Breaker"
   bool              isBullish;          // true = Bullish (Buyers' Inducement), false = Bearish (Sellers' Inducement)
   double            zoneHigh;           // Zone upper boundary
   double            zoneLow;            // Zone lower boundary
   datetime          createdTime;        // Time of origin candle / pivot
   int               createdBarIndex;    // Historical bar index where zone formed

   // Touch Analytics
   int               touchCount;         // Number of qualifying non-mitigating touches
   CArrayLong        touchTimes;         // Timestamps of confirmed ZigZag pivots that tested the zone
   datetime          lastTouchTime;      // Last touch timestamp

   // Inducement State
   bool              isInducement;       // Touch threshold passed and structure qualification accepted
   bool              structureRejected;  // Opposing structure on both sides at qualification
   int               structureBefore;    // Last valid BOS/CHoCH direction before origin: +1/-1/0
   int               structureAfter;     // Last valid BOS/CHoCH direction when touches qualify
   datetime          qualifiedTime;      // First bar-close time when IND qualification was actually known.
   datetime          inducementTime;     // Timestamp when zone qualified as inducement

   // Mitigation State
   bool              isMitigated;        // true if a candle breached opposite boundary
   datetime          mitigationTime;     // Timestamp when mitigation occurred
   int               mitigationBarIndex; // Bar index of mitigation candle

                     CInducementZone()
     {
      id                 = "";
      sourceType         = "";
      isBullish          = true;
      zoneHigh           = 0.0;
      zoneLow            = 0.0;
      createdTime        = 0;
      createdBarIndex    = 0;
      touchCount         = 0;
      lastTouchTime      = 0;
      isInducement       = false;
      structureRejected  = false;
      structureBefore    = 0;
      structureAfter     = 0;
      inducementTime     = 0;
      qualifiedTime      = 0;
      isMitigated        = false;
      mitigationTime     = 0;
      mitigationBarIndex = 0;
     }

   bool              HasPivotTouched(datetime p_time)
     {
      for(int i = 0; i < touchTimes.Total(); i++)
        {
         if((datetime)touchTimes.At(i) == p_time)
            return true;
        }
      return false;
     }
  };

//+------------------------------------------------------------------+
//| Core Inducement Logic Engine                                     |
//+------------------------------------------------------------------+
class CInducementLogic
  {
private:
   int               m_minTouches;
   double            m_proximityPips;
   bool              m_checkDS;
   bool              m_checkOB;
   bool              m_checkSP;
   bool              m_checkFZ;
   bool              m_checkBB;
   bool              m_strictOriginPivots;

   // Anti-Clustering & Consolidation Controls
   bool              m_mergeClustered;
   double            m_clusterTolerancePips;
   bool              m_expandBounds;

   CArrayString      m_registered_keys;
   datetime          m_last_evaluated_pivot_time;

   int               FindBarIndexByTime(datetime targetTime, const datetime &time[], int rates_total)
     {
      int left = 0;
      int right = rates_total - 1;
      while(left <= right)
        {
         int mid = left + (right - left) / 2;
         if(time[mid] == targetTime)
            return mid;
         if(time[mid] < targetTime)
            left = mid + 1;
         else
            right = mid - 1;
        }
      return -1;
     }

public:
   CArrayObj         m_zones;            // Collection of all tracked zones

                     CInducementLogic()
     {
      m_minTouches                = 3;
      m_proximityPips             = 1.0;
      m_checkDS                   = true;
      m_checkOB                   = true;
      m_checkSP                   = true;
      m_checkFZ                   = false;
      m_checkBB                   = false;
      m_strictOriginPivots        = true;
      m_mergeClustered            = true;
      m_clusterTolerancePips      = 10.0;
      m_expandBounds              = false;
      m_last_evaluated_pivot_time = 0;
      m_zones.FreeMode(true);
     }

                    ~CInducementLogic()
     {
      Cleanup();
     }

   void              Init(int minTouches, double proximityPips, bool checkDS, bool checkOB, bool checkSP,
                          bool checkFZ, bool checkBB, bool strictOrigin,
                          bool mergeClustered, double clusterTolerancePips, bool expandBounds)
     {
      m_minTouches           = minTouches;
      m_proximityPips        = proximityPips;
      m_checkDS              = checkDS;
      m_checkOB              = checkOB;
      m_checkSP              = checkSP;
      m_checkFZ              = checkFZ;
      m_checkBB              = checkBB;
      m_strictOriginPivots   = strictOrigin;
      m_mergeClustered       = mergeClustered;
      m_clusterTolerancePips = clusterTolerancePips;
      m_expandBounds         = expandBounds;
     }

   void              ResetState()
     {
      m_zones.Clear();
      m_registered_keys.Clear();
      m_last_evaluated_pivot_time = 0;
     }

   void              Cleanup()
     {
      ResetState();
     }

   bool              IsKeyRegistered(string key)
     {
      for(int i = 0; i < m_registered_keys.Total(); i++)
        {
         if(m_registered_keys.At(i) == key)
            return true;
        }
      return false;
     }

   // Registers zone with strict origin polarity and cluster suppression
   void              RegisterZone(string sType, bool isBull, double zHigh, double zLow, datetime zTime, int barIdx, ZigZag* zz, double pipSize)
     {
      if(zz != NULL && zTime < zz.zoneStartTime) return;
      // 1. STRICT ORIGIN VALIDATION
      // Buyers' Inducement MUST strictly originate from a ZigZag Pivot LOW.
      // Sellers' Inducement MUST strictly originate from a ZigZag Pivot HIGH.
      if(m_strictOriginPivots && zz != NULL)
        {
         for(int p = 0; p < zz.pivots.Total(); p++)
           {
            Pivot* pv = (Pivot*)zz.pivots.At(p);
            if(pv != NULL && pv.end.time == zTime)
              {
               if(CTradeRejection::WrongOrigin(m_strictOriginPivots, isBull, pv.isHigh))
                  return;
               break;
              }
           }
        }

      string key = sType + "_" + (isBull ? "BULL_" : "BEAR_") + IntegerToString((long)zTime);
      if(IsKeyRegistered(key))
         return;

      double clusterTol = m_clusterTolerancePips * pipSize;

      // 2. ANTI-CLUSTERING & ZONE PROLONGATION
      // If an unmitigated zone of the same direction already exists in this price territory,
      // prolong that single master zone instead of spawning duplicate stacked boxes.
      if(m_mergeClustered)
        {
         for(int i = 0; i < m_zones.Total(); i++)
           {
            CInducementZone* existing = (CInducementZone*)m_zones.At(i);
            if(existing == NULL || existing.isMitigated || existing.structureRejected || existing.isBullish != isBull)
               continue;

            // Check if candidate zone overlaps or sits within cluster tolerance of the active zone
            bool isClustered = CTradeRejection::Clustered(zLow, zHigh, existing.zoneLow, existing.zoneHigh, clusterTol);

            if(isClustered)
              {
               // Prolong master zone; optionally widen bounds to envelop the cluster
               if(m_expandBounds)
                 {
                  existing.zoneHigh = MathMax(existing.zoneHigh, zHigh);
                  existing.zoneLow  = MathMin(existing.zoneLow, zLow);
                 }
               m_registered_keys.Add(key); // Suppress candidate zone
               return;
              }
           }
        }

      // 3. REGISTER NEW MASTER ZONE
      CInducementZone* zone = new CInducementZone();
      zone.id              = key;
      zone.sourceType      = sType;
      zone.isBullish       = isBull;
      zone.zoneHigh        = zHigh;
      zone.zoneLow         = zLow;
      zone.createdTime     = zTime;
      zone.createdBarIndex = barIdx;

      m_zones.Add(zone);
      m_registered_keys.Add(key);
     }

   // --- STEP 1: HARVEST DETECTED SMC ZONES ---
   void              HarvestZones(int current_i, const datetime &time[],
                                  CDemandSupplyLogic* ds, CSwingPOILogic* sp,
                                  COrderBlockLogic* ob, CFlipZoneLogic* fz,
                                  CBreakerBlockLogic* bb, CMarketStructure* ms,
                                  ZigZag* zz, double pipSize)
     {
      // 1. Order Blocks
      if(m_checkOB && ob != NULL)
        {
         for(int i = 0; i < ob.poi_demandTime.Total(); i++)
           {
            datetime zt = (datetime)ob.poi_demandTime.At(i);
            if(ob.ob_time_found(&ms.ob_bull_struct_times, zt) && ob.ob_time_found(&ob.ob_bull_valid_times, zt))
               RegisterZone("Order Block", true, ob.poi_demandZoneHigh.At(i), ob.poi_demandZoneLow.At(i), zt, current_i, zz, pipSize);
           }
         for(int i = 0; i < ob.poi_supplyTime.Total(); i++)
           {
            datetime zt = (datetime)ob.poi_supplyTime.At(i);
            if(ob.ob_time_found(&ms.ob_bear_struct_times, zt) && ob.ob_time_found(&ob.ob_bear_valid_times, zt))
               RegisterZone("Order Block", false, ob.poi_supplyZoneHigh.At(i), ob.poi_supplyZoneLow.At(i), zt, current_i, zz, pipSize);
           }
        }

      // 2. Swing POIs
      if(m_checkSP && sp != NULL)
        {
         for(int i = 0; i < sp.poi_demandTime.Total(); i++)
           {
            datetime zt = (datetime)sp.poi_demandTime.At(i);
            if(sp.ob_time_found(&ms.ob_bull_struct_times, zt))
               RegisterZone("Swing POI", true, sp.poi_demandZoneHigh.At(i), sp.poi_demandZoneLow.At(i), zt, current_i, zz, pipSize);
           }
         for(int i = 0; i < sp.poi_supplyTime.Total(); i++)
           {
            datetime zt = (datetime)sp.poi_supplyTime.At(i);
            if(sp.ob_time_found(&ms.ob_bear_struct_times, zt))
               RegisterZone("Swing POI", false, sp.poi_supplyZoneHigh.At(i), sp.poi_supplyZoneLow.At(i), zt, current_i, zz, pipSize);
           }
        }

      // 3. Demand / Supply Zones
      if(m_checkDS && ds != NULL)
        {
         for(int i = 0; i < ds.poi_demandTime.Total(); i++)
            RegisterZone("Demand / Supply", true, ds.poi_demandZoneHigh.At(i), ds.poi_demandZoneLow.At(i), (datetime)ds.poi_demandTime.At(i), current_i, zz, pipSize);
         for(int i = 0; i < ds.poi_supplyTime.Total(); i++)
            RegisterZone("Demand / Supply", false, ds.poi_supplyZoneHigh.At(i), ds.poi_supplyZoneLow.At(i), (datetime)ds.poi_supplyTime.At(i), current_i, zz, pipSize);
        }

      // 4. Flip Zones
      if(m_checkFZ && fz != NULL)
        {
         for(int i = 0; i < fz.fz_time.Total(); i++)
           {
            bool isDemFlip = (fz.fz_type.At(i) == 1);
            RegisterZone("Flip Zone", isDemFlip, fz.fz_zoneHigh.At(i), fz.fz_zoneLow.At(i), (datetime)fz.fz_time.At(i), current_i, zz, pipSize);
           }
        }

      // 5. Breaker Blocks
      if(m_checkBB && bb != NULL)
        {
         for(int i = 0; i < bb.bb_time.Total(); i++)
           {
            bool isBullBreaker = (bb.bb_type.At(i) == 1);
            RegisterZone("Breaker Block", isBullBreaker, bb.bb_zoneHigh.At(i), bb.bb_zoneLow.At(i), (datetime)bb.bb_time.At(i), current_i, zz, pipSize);
           }
        }
     }

   // --- STEP 2: MITIGATION EVALUATION ---
   void              UpdateMitigations(int current_i, const datetime &time[], const double &high[], const double &low[])
     {
      for(int z = 0; z < m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)m_zones.At(z);
         if(zone == NULL || zone.isMitigated)
            continue;

         if(time[current_i] <= zone.createdTime)
            continue;

         if(zone.isBullish)
           {
            // Bullish Zone: Mitigated when candle low trades below zone.low
            if(low[current_i] < zone.zoneLow)
              {
               zone.isMitigated        = true;
               zone.mitigationTime     = time[current_i];
               zone.mitigationBarIndex = current_i;
              }
           }
         else
           {
            // Bearish Zone: Mitigated when candle high trades above zone.high
            if(high[current_i] > zone.zoneHigh)
              {
               zone.isMitigated        = true;
               zone.mitigationTime     = time[current_i];
               zone.mitigationBarIndex = current_i;
              }
           }
        }
     }

   // --- STEP 3: INDUCEMENT TOUCH EVALUATION ---
   void              UpdateTouches(int current_i, const datetime &time[], const double &open[],
                                   const double &high[], const double &low[], const double &close[],
                                   ZigZag* zz, double pipSize)
     {
      if(zz == NULL || zz.pivots.Total() < 2)
         return;

      int p_total = zz.pivots.Total();
      double prox = m_proximityPips * pipSize;

      for(int z = 0; z < m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)m_zones.At(z);
         if(zone == NULL)
            continue;

         datetime cutoffTime = zone.isMitigated ? zone.mitigationTime : time[current_i];

         for(int p_idx = 0; p_idx <= p_total - 2; p_idx++)
           {
            Pivot* p = (Pivot*)zz.pivots.At(p_idx);
            if(p == NULL || (zz.projection != NULL && p == zz.projection))
               continue;

            datetime p_time = p.end.time;

            if(p_time <= zone.createdTime || p_time > cutoffTime)
               continue;

            if(zone.HasPivotTouched(p_time))
               continue;

            int p_bar = p.end.index;
            if(p_bar < 0 || p_bar >= ArraySize(time) || time[p_bar] != p_time)
               p_bar = FindBarIndexByTime(p_time, time, current_i + 1);

            if(p_bar < 0)
               continue;

            double c_open  = open[p_bar];
            double c_high  = high[p_bar];
            double c_low   = low[p_bar];
            double c_close = close[p_bar];
            double p_price = p.end.price;

            // -------------------------------------------------------------
            // BULLISH ZONE (Buyers' Inducement Candidate)
            // -------------------------------------------------------------
            if(zone.isBullish)
              {
               if(!p.isHigh)
                 {
                  if(c_low >= zone.zoneLow)
                    {
                     double touchCeiling = zone.zoneHigh + prox;
                     bool pivot_in_zone = (p_price <= touchCeiling && p_price >= zone.zoneLow);
                     bool low_in_zone   = (c_low <= touchCeiling && c_low >= zone.zoneLow);
                     bool close_in_zone = (c_close <= touchCeiling && c_close >= zone.zoneLow);
                     bool body_in_zone  = (MathMin(c_open, c_close) <= touchCeiling && MathMax(c_open, c_close) >= zone.zoneLow);

                     if(pivot_in_zone || low_in_zone || close_in_zone || body_in_zone)
                       {
                        zone.touchTimes.Add((long)p_time);
                        zone.touchCount++;
                        zone.lastTouchTime = p_time;

                        // Qualification is performed once below, after checking structure.
                       }
                    }
                 }
              }
            // -------------------------------------------------------------
            // BEARISH ZONE (Sellers' Inducement Candidate)
            // -------------------------------------------------------------
            else
              {
               if(p.isHigh)
                 {
                  if(c_high <= zone.zoneHigh)
                    {
                     double touchFloor = zone.zoneLow - prox;
                     bool pivot_in_zone = (p_price >= touchFloor && p_price <= zone.zoneHigh);
                     bool high_in_zone  = (c_high >= touchFloor && c_high <= zone.zoneHigh);
                     bool close_in_zone = (c_close >= touchFloor && c_close <= zone.zoneHigh);
                     bool body_in_zone  = (MathMax(c_open, c_close) >= touchFloor && MathMin(c_open, c_close) <= zone.zoneHigh);

                     if(pivot_in_zone || high_in_zone || close_in_zone || body_in_zone)
                       {
                        zone.touchTimes.Add((long)p_time);
                        zone.touchCount++;
                        zone.lastTouchTime = p_time;

                        // Qualification is performed once below, after checking structure.
                       }
                    }
                 }
              }
           }
        }
     }

   // Use the structural registry as known now. Sweeps are not directional
   // BOS/CHoCH events, and the engine's initial default trend is not evidence.
   int StructureDirection(CMarketStructure* structure, datetime cutoff, bool strictlyBefore)
     {
      if(structure==NULL) return 0;
      datetime latest=0;
      int direction=0;
      for(int e=structure.all_event_times.Total()-1;e>=0;e--)
        {
         datetime eventTime=(datetime)structure.all_event_times.At(e);
         if(eventTime<=0 || eventTime>cutoff || (strictlyBefore && eventTime==cutoff) || eventTime<latest) continue;
         string name=structure.all_event_names.At(e);
         int side=0;
         if(StringFind(name,"BL-BOS")>=0 || StringFind(name,"BL-CHoCH")>=0) side=1;
         else if(StringFind(name,"BR-BOS")>=0 || StringFind(name,"BR-CHoCH")>=0) side=-1;
         if(side!=0) { latest=eventTime; direction=side; }
        }
      return direction;
     }

   void QualifyZone(CInducementZone* zone, CMarketStructure* structure, datetime barTime, datetime knownAt)
     {
      if(zone==NULL || zone.isInducement || zone.structureRejected ||
         zone.touchCount<MathMax(1,m_minTouches) || barTime<=zone.createdTime) return;
      zone.structureBefore=StructureDirection(structure,zone.createdTime,true);
      zone.structureAfter=StructureDirection(structure,barTime,false);
      int opposite=zone.isBullish ? -1 : 1;
      if(zone.structureBefore==opposite && zone.structureAfter==opposite)
        {
         zone.structureRejected=true;
         PrintFormat("[IND STRUCTURE REJECT] %s zone=%s origin=%s known=%s bounds=%.8f..%.8f before=%s after=%s; not an inducement.",
                     structure!=NULL ? structure.tf_str() : "",zone.id,TimeToString(zone.createdTime,TIME_DATE|TIME_MINUTES),
                     TimeToString(knownAt,TIME_DATE|TIME_MINUTES),zone.zoneLow,zone.zoneHigh,
                     opposite==1 ? "BULLISH" : "BEARISH",opposite==1 ? "BULLISH" : "BEARISH");
         return;
        }
      zone.isInducement=true;
      // Preserve the first pivot that met the threshold, even if a late-harvested
      // zone has several already-confirmed touches in this processing batch.
      int thresholdIndex=(int)MathMax(1,m_minTouches)-1;
      zone.inducementTime=zone.touchTimes.Total()>thresholdIndex ?
                          (datetime)zone.touchTimes.At(thresholdIndex) : zone.lastTouchTime;
      zone.qualifiedTime=knownAt;
     }

   // --- STEP 4: COORDINATED PROCESSING BATCH ---
   void              Process(int current_i, const datetime &time[], const double &open[],
                             const double &high[], const double &low[], const double &close[],
                             ZigZag* zz, CMarketStructure* ms, CDemandSupplyLogic* ds,
                             CSwingPOILogic* sp, COrderBlockLogic* ob, CFlipZoneLogic* fz,
                             CBreakerBlockLogic* bb, double pipSize)
     {
      if(zz != NULL && time[current_i] < zz.zoneStartTime) return;
      HarvestZones(current_i, time, ds, sp, ob, fz, bb, ms, zz, pipSize);
      UpdateMitigations(current_i, time, high, low);
      UpdateTouches(current_i, time, open, high, low, close, zz, pipSize);
      ENUM_TIMEFRAMES tf=(ms!=NULL && ms.m_tf!=PERIOD_CURRENT) ? ms.m_tf : (ENUM_TIMEFRAMES)_Period;
      datetime knownAt=time[current_i]+PeriodSeconds(tf);
      for(int z=0;z<m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)m_zones.At(z);
         QualifyZone(zone,ms,time[current_i],knownAt);
        }
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\Inducements.mqh
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\Inducements.mqh
