//+------------------------------------------------------------------+
//|                             Include\Custom\Marcotrades\liquidity_blocks.mqh |
//|                 Smart Money Concepts: Liquidity Block Engine     |
//|                 - TF-BL-LB-BSL (Bullish LB at Pivot Low of BSL-Swept) |
//|                 - TF-BR-LB-SSL (Bearish LB at Pivot High of SSL-Swept)|
//|                 - TF-BL-LB-IND (Buyers' Inducement Swept CHoCH/BOS)   |
//|                 - TF-BR-LB-IND (Sellers' Inducement Swept CHoCH/BOS)  |
//|                 - STRICT 5+ STRUCTURE CONFIRMATION (CHoCH -> BOS)     |
//+------------------------------------------------------------------+
#property copyright "Marcotrades SMC Architecture"
#property version   "1.33"

#ifndef MARCOTRADES_LIQUIDITY_BLOCK_MQH
#define MARCOTRADES_LIQUIDITY_BLOCK_MQH

#include <Custom\Marcotrades\trade_rejection.mqh>
#include <Custom\Marcotrades\Inducements.mqh>
#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\ZigZag\market_structure.mqh>
#include <Custom\ZigZag\swing_pois.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>

enum ENUM_LB_TRIGGER
  {
   LB_TRIGGER_BL_BSL,    // TF-BL-LB-BSL
   LB_TRIGGER_BR_SSL,    // TF-BR-LB-SSL
   LB_TRIGGER_BL_IND,    // TF-BL-LB-IND
   LB_TRIGGER_BR_IND,    // TF-BR-LB-IND
   LB_TRIGGER_BL_IND_BSL,// TF-BL-LB-IND-BSL
   LB_TRIGGER_BR_IND_SSL // TF-BR-LB-IND-SSL
  };

//+------------------------------------------------------------------+
//| Liquidity Block Object Model                                     |
//+------------------------------------------------------------------+
class CLiquidityBlock : public CObject
  {
public:
   string            id;
   bool              isBullish;
   ENUM_LB_TRIGGER   triggerType;
   double            zoneHigh;
   double            zoneLow;
   datetime          createdTime;
   int               createdBarIndex;
   datetime          sweepLineTime;
   datetime          inducementOriginTime;
   datetime          causalChochTime; // Event which initiated this LB, distinct from its origin candle.
   datetime          guardQualifiedTime; // Structural eligibility, independent of the new-entry IND veto.

   bool              isMitigated;
   datetime          mitigationTime;
   int               mitigationBarIndex;

   int               touchCount;
   CArrayLong        touchTimes;

                     CLiquidityBlock()
     {
      id                   = "";
      isBullish            = true;
      triggerType          = LB_TRIGGER_BL_BSL;
      zoneHigh             = 0.0;
      zoneLow              = 0.0;
      createdTime          = 0;
      createdBarIndex      = 0;
      sweepLineTime        = 0;
      inducementOriginTime = 0;
      causalChochTime = 0;
      guardQualifiedTime = 0;
      isMitigated          = false;
      mitigationTime       = 0;
      mitigationBarIndex   = 0;
      touchCount           = 0;
     }

                    ~CLiquidityBlock()
     {
      if(id != "")
        {
         ObjectDelete(0, "LB_" + id);
         ObjectDelete(0, "LB_" + id + "_lbl");
        }
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

   string            GetNomenclature(string tfStr)
     {
      switch(triggerType)
        {
         case LB_TRIGGER_BL_IND:
            return tfStr + "-BL-LB-IND";
         case LB_TRIGGER_BR_IND:
            return tfStr + "-BR-LB-IND";
         case LB_TRIGGER_BL_IND_BSL:
            return tfStr + "-BL-LB-IND-BSL";
         case LB_TRIGGER_BR_IND_SSL:
            return tfStr + "-BR-LB-IND-SSL";
         case LB_TRIGGER_BL_BSL:
            return tfStr + "-BL-LB-BSL";
         case LB_TRIGGER_BR_SSL:
            return tfStr + "-BR-LB-SSL";
        }
      return tfStr + "-LB";
     }
  };

struct SInducementMitigationTracker
  {
   string            inducementId;
   bool              isBullishInducement;
   double            inducementLevel;
   datetime          mitigationTime;
   datetime          inducementOriginTime;
   bool              chochCaptured;

   // Two-Step Confirmation State Tracker for 5+ prevailing structures
   bool              waitingForBOS;
   datetime          chochTime;
   datetime          pendingProtTime;
   double            pendingZHigh;
   double            pendingZLow;
  };

//+------------------------------------------------------------------+
//| Core Liquidity Block Logic Engine                                |
//+------------------------------------------------------------------+
class CLiquidityBlockLogic
  {
private:
   double            m_symbolPoint;
   bool              m_trackSweepsAnywhere;
   bool              m_trackPostInducementCHoCH;

   CArrayString      m_registered_lb_keys;
   datetime          m_last_breakout_evaluated;
   long              m_last_swept_event_id;

   SInducementMitigationTracker m_mitig_trackers[];

   int               GetRequiredStructureCount(CMarketStructure* ms)
     {
      ENUM_TIMEFRAMES tf = (ms != NULL && ms.m_tf != PERIOD_CURRENT) ? ms.m_tf : _Period;
      int mins = PeriodSeconds(tf) / 60;

      // LTF: M5, M3, M1 (<= 5 minutes) -> requires min 5 structures
      return CTradeRejection::RequiredStructures(mins);
     }

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
   datetime          m_zoneStartTime;
   CArrayObj         m_liquidity_blocks;
   CArrayObj         m_exit_sources; // Structurally valid sources vetoed for new entries by IND overlap.

                     CLiquidityBlockLogic()
     {
      m_zoneStartTime = 0;
      m_symbolPoint = _Point; // Default for legacy single-chart callers.
      m_last_swept_event_id      = 0;
      m_trackSweepsAnywhere       = true;
      m_trackPostInducementCHoCH = true;
      m_last_breakout_evaluated  = 0;
      m_liquidity_blocks.FreeMode(true);
      m_exit_sources.FreeMode(true);
     }

                    ~CLiquidityBlockLogic()
     {
      Cleanup();
     }

   void              Init(bool trackSweepsAnywhere = true, bool trackPostInducementCHoCH = true, double symbolPoint = 0.0)
     {
      m_symbolPoint = symbolPoint > 0.0 ? symbolPoint : _Point;
      m_trackSweepsAnywhere       = trackSweepsAnywhere;
      m_trackPostInducementCHoCH = trackPostInducementCHoCH;
     }

   void              ResetState()
     {
      m_liquidity_blocks.Clear();
      m_exit_sources.Clear();
      m_registered_lb_keys.Clear();
      ArrayResize(m_mitig_trackers, 0);
      m_last_breakout_evaluated = 0;
      m_last_swept_event_id = 0;
     }

   void              Cleanup()
     {
      ResetState();
     }

   bool              IsLBRegistered(string key)
     {
      for(int i = 0; i < m_registered_lb_keys.Total(); i++)
        {
         if(m_registered_lb_keys.At(i) == key)
            return true;
        }
     return false;
     }

   // Entry qualification; also used by prevention/exits when their policy input is enabled.
   datetime          EntryTriggerStructureTime(bool isBullish, ENUM_LB_TRIGGER triggerType,
                                               datetime sweepLineTime, CInducementLogic* indLogic,
                                               CMarketStructure* structure, datetime cutoff)
     {
      if(structure == NULL || cutoff <= 0)
         return 0;

      bool indTrigger = (triggerType == LB_TRIGGER_BL_IND || triggerType == LB_TRIGGER_BR_IND);
      bool sweepTrigger = (triggerType == LB_TRIGGER_BL_BSL || triggerType == LB_TRIGGER_BR_SSL ||
                           triggerType == LB_TRIGGER_BL_IND_BSL || triggerType == LB_TRIGGER_BR_IND_SSL);
      if((isBullish && triggerType == LB_TRIGGER_BR_IND) ||
         (!isBullish && triggerType == LB_TRIGGER_BL_IND) ||
         (isBullish && (triggerType == LB_TRIGGER_BR_SSL || triggerType == LB_TRIGGER_BR_IND_SSL)) ||
         (!isBullish && (triggerType == LB_TRIGGER_BL_BSL || triggerType == LB_TRIGGER_BL_IND_BSL)))
         return 0;

      // Sweep-triggered entry setups have their own, lighter gate. The
      // registered BSL/SSL event must still exist. The CHoCH which renames the
      // older line into a sweep is recognition, not the extra structure. Require
      // its next adjacent structural event to support the LB. No IND is required.
      // A merged IND-BSL/IND-SSL LB follows this sweep path because it still
      // has a concrete sweep trigger.
      if(sweepTrigger)
        {
         if(sweepLineTime <= 0 || sweepLineTime > cutoff)
            return 0;

         string expectedSweep = isBullish ? "BSL-Swept" : "SSL-Swept";
         bool sweepExists = false;
         for(int e = 0; e < structure.all_event_times.Total(); e++)
           {
            datetime eventTime = (datetime)structure.all_event_times.At(e);
            if(eventTime == sweepLineTime && structure.all_event_names.At(e) == expectedSweep)
              {
               sweepExists = true;
               break;
              }
           }
         if(!sweepExists)
            return 0;

         datetime confirmingTime=structure.GetSweepConfirmingChochTime(sweepLineTime,!isBullish);
         if(confirmingTime<=sweepLineTime || confirmingTime>cutoff)
            return 0;

         datetime adjacentTime = 0;
         int adjacentDirection = 0;
         for(int e = 0; e < structure.all_event_times.Total(); e++)
           {
            datetime eventTime = (datetime)structure.all_event_times.At(e);
            if(eventTime <= confirmingTime || eventTime > cutoff ||
               (adjacentTime > 0 && eventTime >= adjacentTime))
               continue;

            string name = structure.all_event_names.At(e);
            int direction = 0;
            if(name == "BL-BOS" || name == "BL-CHoCH" || name == "BSL-Swept")
               direction = 1;
            else
               if(name == "BR-BOS" || name == "BR-CHoCH" || name == "SSL-Swept")
                  direction = -1;
            if(direction == 0)
               continue;
            adjacentTime = eventTime;
            adjacentDirection = direction;
           }
         return (adjacentDirection == (isBullish ? 1 : -1)) ? adjacentTime : 0;
        }

      if(!indTrigger || indLogic == NULL)
         return 0;

      // A newer same-side IND mitigation starts the sequence relevant to new
      // setups. Once an individual cached setup becomes ready, its caller
      // latches that state, so a later IND cannot revoke it retroactively.
      datetime mitigation = 0;
      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* zone = (CInducementZone*)indLogic.m_zones.At(z);
         if(zone == NULL || !zone.isInducement || zone.structureRejected ||
            !zone.isMitigated || zone.isBullish != isBullish ||
            zone.qualifiedTime <= 0 || zone.qualifiedTime > cutoff ||
            zone.mitigationTime <= 0 || zone.mitigationTime > cutoff)
            continue;
         if(zone.mitigationTime > mitigation)
            mitigation = zone.mitigationTime;
        }
      if(mitigation <= 0)
         return 0;

      int consecutive = 0;
      datetime lastEvent = 0;
      for(int e = 0; e < structure.all_event_times.Total(); e++)
        {
         datetime eventTime = (datetime)structure.all_event_times.At(e);
         if(eventTime <= mitigation || eventTime > cutoff || eventTime == lastEvent)
            continue;

         string name = structure.all_event_names.At(e);
         int direction = 0;
         if(name == "BL-BOS" || name == "BL-CHoCH" || name == "BSL-Swept")
            direction = 1;
         else
            if(name == "BR-BOS" || name == "BR-CHoCH" || name == "SSL-Swept")
               direction = -1;
            else
               continue;

         lastEvent = eventTime;
         if(direction == (isBullish ? 1 : -1))
           {
            consecutive++;
            if(consecutive >= 2)
               return eventTime;
           }
         else
            consecutive = 0;
        }
      return 0;
     }

   // IND overlap forbids opening a trade from this source; it does not erase
   // its opposing structural context. Apply the requested structure gate before
   // admitting it to prevention history, and never backdate availability.
   bool GuardSourceReady(CLiquidityBlock* source,CInducementLogic* inducements,
                         CMarketStructure* structure,datetime cutoff,datetime available,
                         bool applyPolicy)
     {
      if(source==NULL || available<=0 || cutoff>available) return false;
      if(!applyPolicy) return true;
      if(source.guardQualifiedTime<=0)
        {
         datetime qualified=EntryTriggerStructureTime(source.isBullish,source.triggerType,
                                source.sweepLineTime,inducements,structure,cutoff);
         if(qualified<=0) return false;
         source.guardQualifiedTime=available;
         PrintFormat("[LB GUARD ARMED] source=%s side=%s trigger=%s structure=%s available=%s; entry remains vetoed by IND overlap",
                     source.id,source.isBullish ? "BL" : "BR",EnumToString(source.triggerType),
                     TimeToString(qualified,TIME_DATE|TIME_SECONDS),TimeToString(available,TIME_DATE|TIME_SECONDS));
        }
      return source.guardQualifiedTime<=available;
     }

   CLiquidityBlock*  GetContainingLiquidityBlock(CInducementZone* ind)
     {
      if(ind == NULL || CheckPointer(ind) != POINTER_DYNAMIC || !ind.isInducement)
         return NULL;

      CLiquidityBlock* best = NULL;
      double bestHeight = DBL_MAX;
      datetime indCreatedTime = (ind.inducementTime > 0 ? ind.inducementTime : ind.createdTime);
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb.isBullish != ind.isBullish)
            continue;
         if(indCreatedTime < lb.createdTime)
            continue;
         if(lb.isMitigated && lb.mitigationTime > 0 && indCreatedTime > lb.mitigationTime)
            continue;
         if(ind.zoneLow < lb.zoneLow || ind.zoneHigh > lb.zoneHigh)
            continue;

         double height = lb.zoneHigh - lb.zoneLow;
         if(best == NULL || height < bestHeight)
           {
            best = lb;
            bestHeight = height;
           }
        }
      return best;
     }

   string            GetDisplayNomenclature(CLiquidityBlock* lb, string tfStr, CInducementLogic* indLogic, bool includeMitigatedInducements)
     {
      string text = lb.GetNomenclature(tfStr);
      if(indLogic == NULL || CheckPointer(indLogic) != POINTER_DYNAMIC)
         return text;

      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic.m_zones.At(z);
         if(ind != NULL && ind.isMitigated && !includeMitigatedInducements)
            continue;
         if(GetContainingLiquidityBlock(ind) == lb)
            return text + (lb.isBullish ? " & BL-IND" : " & BR-IND");
        }
      return text;
     }

   void RecordExitSource(bool bull, ENUM_LB_TRIGGER trigger, double high, double low,
                         datetime origin, int bar, datetime sweep, datetime cause)
     {
      if(cause<=0) return; // A source must have an explicit confirmed CHoCH link.
      string id="EXIT_ONLY_LB_"+(bull ? "BULL_" : "BEAR_")+IntegerToString((long)origin)+"_"+IntegerToString((long)cause);
      for(int i=0;i<m_exit_sources.Total();i++)
        {
         CLiquidityBlock* known=(CLiquidityBlock*)m_exit_sources.At(i);
         if(known!=NULL && known.id==id) return;
        }
      CLiquidityBlock* source=new CLiquidityBlock();
      source.id=id; source.isBullish=bull; source.triggerType=trigger;
      source.zoneHigh=high; source.zoneLow=low; source.createdTime=origin;
      source.createdBarIndex=bar; source.sweepLineTime=sweep; source.causalChochTime=cause;
      m_exit_sources.Add(source);
     }

   void RefreshExitSources(CMarketStructure* structure, datetime now, double high, double low)
     {
      if(structure==NULL) return;
      for(int i=m_exit_sources.Total()-1;i>=0;i--)
        {
         CLiquidityBlock* source=(CLiquidityBlock*)m_exit_sources.At(i);
         if(source==NULL) continue;
         bool valid=false;
         for(int e=structure.all_event_times.Total()-1;e>=0;e--)
            if((datetime)structure.all_event_times.At(e)==source.causalChochTime)
              {
               valid=structure.all_event_names.At(e)==(source.isBullish ? "BL-CHoCH" : "BR-CHoCH");
               break;
              }
         if(!valid) { m_exit_sources.Delete(i); continue; }
         if(!source.isMitigated && now>source.createdTime &&
            CTradeRejection::BoundaryBroken(source.isBullish,low,high,source.zoneLow,source.zoneHigh,0.0))
           { source.isMitigated=true; source.mitigationTime=now; }
        }
     }

   // Register Liquidity Block with active Inducement overlap filter
   void              RegisterLiquidityBlock(bool isBull, ENUM_LB_TRIGGER trigger, double zHigh, double zLow, datetime zTime, int barIdx, datetime sweepLineTime, CInducementLogic* indLogic, datetime indOriginTime = 0, datetime causalChoch = 0)
     {
      if(zTime < m_zoneStartTime) return;
      // OVERLAP FILTER:
      // A BR-LB (SSL/IND) is invalid if its pivot candle originates / lies in the premises of an active BR-IND
      // A BL-LB (BSL/IND) is invalid if its pivot candle originates / lies in the premises of an active BL-IND
      if(indLogic != NULL)
        {
         for(int z = 0; z < indLogic.m_zones.Total(); z++)
           {
            CInducementZone* iz = (CInducementZone*)indLogic.m_zones.At(z);
            if(iz == NULL || !iz.isInducement)
               continue;

            datetime indTime = (iz.inducementTime > 0 ? iz.inducementTime : iz.createdTime);
            if(CTradeRejection::ActiveInducementOverlap(isBull, zLow, zHigh, zTime,
                  iz.isBullish, iz.zoneLow, iz.zoneHigh, indTime, iz.mitigationTime))
              {
               // Reject new entries here, but retain the structure for protecting an existing opposite trade.
               RecordExitSource(isBull,trigger,zHigh,zLow,zTime,barIdx,sweepLineTime,causalChoch);
               return;
              }
           }
        }

      // Check if already registered
      double zoneTolerance = MathMax(m_symbolPoint, 1e-10);
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* exist = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(exist != NULL && CheckPointer(exist) == POINTER_DYNAMIC && CTradeRejection::SameLB(isBull, zTime, zLow, zHigh, exist.isBullish, exist.createdTime, exist.zoneLow, exist.zoneHigh, zoneTolerance))
           {
            if(exist.triggerType != LB_TRIGGER_BL_IND_BSL && exist.triggerType != LB_TRIGGER_BR_IND_SSL)
              {
               if((exist.triggerType == LB_TRIGGER_BL_BSL && trigger == LB_TRIGGER_BL_IND) ||
                  (exist.triggerType == LB_TRIGGER_BL_IND && trigger == LB_TRIGGER_BL_BSL))
                  exist.triggerType = LB_TRIGGER_BL_IND_BSL;
               else
                  if((exist.triggerType == LB_TRIGGER_BR_SSL && trigger == LB_TRIGGER_BR_IND) ||
                     (exist.triggerType == LB_TRIGGER_BR_IND && trigger == LB_TRIGGER_BR_SSL))
                     exist.triggerType = LB_TRIGGER_BR_IND_SSL;
                  else
                     if(trigger == LB_TRIGGER_BL_IND || trigger == LB_TRIGGER_BR_IND)
                        exist.triggerType = trigger;
              }

            if(causalChoch > 0) exist.causalChochTime = causalChoch;
            if(sweepLineTime > 0 && exist.sweepLineTime == 0)
               exist.sweepLineTime = sweepLineTime;

            if(indOriginTime > 0 && exist.inducementOriginTime == 0)
               exist.inducementOriginTime = indOriginTime;

            return;
           }
        }

      string key = "LB_" + (isBull ? "BULL_" : "BEAR_") + IntegerToString((long)zTime);
      if(IsLBRegistered(key))
         return;

      CLiquidityBlock* lb = new CLiquidityBlock();
      lb.id                   = key;
      lb.isBullish            = isBull;
      lb.triggerType          = trigger;
      lb.zoneHigh             = zHigh;
      lb.zoneLow              = zLow;
      lb.createdTime          = zTime;
      lb.createdBarIndex      = barIdx;
      lb.sweepLineTime        = sweepLineTime;
      lb.inducementOriginTime = indOriginTime;
      lb.causalChochTime = causalChoch;

      m_liquidity_blocks.Add(lb);
      m_registered_lb_keys.Add(key);
     }

   bool              ResolveSwingPOIBounds(datetime protTime, bool isBullish, CSwingPOILogic* sp,
                                           const datetime &time[], const double &high[], const double &low[],
                                           int rates_total, double &outHigh, double &outLow)
     {
      outHigh = 0.0;
      outLow  = 0.0;

      if(sp != NULL && CheckPointer(sp) == POINTER_DYNAMIC)
        {
         if(isBullish)
           {
            for(int k = 0; k < sp.poi_demandTime.Total(); k++)
              {
               if((datetime)sp.poi_demandTime.At(k) == protTime)
                 {
                  outHigh = sp.poi_demandZoneHigh.At(k);
                  outLow  = sp.poi_demandZoneLow.At(k);
                  return true;
                 }
              }
           }
         else
           {
            for(int k = 0; k < sp.poi_supplyTime.Total(); k++)
              {
               if((datetime)sp.poi_supplyTime.At(k) == protTime)
                 {
                  outHigh = sp.poi_supplyZoneHigh.At(k);
                  outLow  = sp.poi_supplyZoneLow.At(k);
                  return true;
                 }
              }
           }
        }

      int idx = FindBarIndexByTime(protTime, time, rates_total);
      if(idx >= 0 && idx < rates_total)
        {
         outHigh = high[idx];
         outLow  = low[idx];
         return true;
        }

      return false;
     }

   void              ProcessSweptAnywhere(int current_i, const datetime &time[], const double &high[], const double &low[],
                                          CMarketStructure* ms, CSwingPOILogic* sp, ZigZag* zz, CInducementLogic* indLogic)
     {
      if(!m_trackSweepsAnywhere || ms == NULL || CheckPointer(ms) != POINTER_DYNAMIC)
         return;

      // 1. Scrub phantom BR-LB-IND if its origin line was retroactively renamed to BSL-Swept
      for(int s = 0; s < ms.swept_bsl_times.Total(); s++)
        {
         datetime sweptTime = (datetime)ms.swept_bsl_times.At(s);
         for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
            if(lb != NULL && lb.triggerType == LB_TRIGGER_BR_IND && lb.sweepLineTime == sweptTime)
              {
               m_liquidity_blocks.Delete(i);
              }
           }
        }

      // 2. Scrub phantom BL-LB-IND if its origin line was retroactively renamed to SSL-Swept
      for(int s = 0; s < ms.swept_ssl_times.Total(); s++)
        {
         datetime sweptTime = (datetime)ms.swept_ssl_times.At(s);
         for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
           {
            CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
            if(lb != NULL && lb.triggerType == LB_TRIGGER_BL_IND && lb.sweepLineTime == sweptTime)
              {
               m_liquidity_blocks.Delete(i);
              }
           }
        }

      for(int i = m_liquidity_blocks.Total() - 1; i >= 0; i--)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC)
            continue;

         if((lb.triggerType == LB_TRIGGER_BL_BSL || lb.triggerType == LB_TRIGGER_BL_IND_BSL) && lb.sweepLineTime > 0)
           {
            bool found = false;
            for(int j = 0; j < ms.swept_bsl_times.Total(); j++)
              {
               if(ms.swept_bsl_times.At(j) == (long)lb.sweepLineTime)
                 {
                  found = true;
                  break;
                 }
              }
            if(!found)
              {
               string sweep_key = "LB_SWEEP_BSL_" + IntegerToString(lb.sweepLineTime);
               for(int k = m_registered_lb_keys.Total() - 1; k >= 0; k--)
                 {
                  if(m_registered_lb_keys.At(k) == sweep_key || m_registered_lb_keys.At(k) == lb.id)
                     m_registered_lb_keys.Delete(k);
                 }
               m_liquidity_blocks.Delete(i);
              }
           }
         else
            if((lb.triggerType == LB_TRIGGER_BR_SSL || lb.triggerType == LB_TRIGGER_BR_IND_SSL) && lb.sweepLineTime > 0)
              {
               bool found = false;
               for(int j = 0; j < ms.swept_ssl_times.Total(); j++)
                 {
                  if(ms.swept_ssl_times.At(j) == (long)lb.sweepLineTime)
                    {
                     found = true;
                     break;
                    }
                 }
              }
        }

      for(int s = 0; s < ms.swept_bsl_times.Total(); s++)
        {
         datetime sweepLineTime = (datetime)ms.swept_bsl_times.At(s);
         string   key           = "LB_SWEEP_BSL_" + IntegerToString(sweepLineTime);

         if(IsLBRegistered(key))
            continue;

         datetime pivotLowTime = 0;

         if(zz != NULL && CheckPointer(zz) == POINTER_DYNAMIC)
            pivotLowTime = ms.GetSweepExtremePivotTime(sweepLineTime, false, zz);

         if(pivotLowTime > 0)
           {
            double zHigh = 0.0, zLow = 0.0;
            if(ResolveSwingPOIBounds(pivotLowTime, true, sp, time, high, low, current_i + 1, zHigh, zLow))
              {
               RegisterLiquidityBlock(true, LB_TRIGGER_BL_BSL, zHigh, zLow, pivotLowTime, current_i, sweepLineTime, indLogic, 0,
                                      ms.GetSweepConfirmingChochTime(sweepLineTime, false));
               m_registered_lb_keys.Add(key);
              }
           }
        }

      for(int s = 0; s < ms.swept_ssl_times.Total(); s++)
        {
         datetime sweepLineTime = (datetime)ms.swept_ssl_times.At(s);
         string   key           = "LB_SWEEP_SSL_" + IntegerToString(sweepLineTime);

         if(IsLBRegistered(key))
            continue;

         datetime pivotHighTime = 0;

         if(zz != NULL && CheckPointer(zz) == POINTER_DYNAMIC)
            pivotHighTime = ms.GetSweepExtremePivotTime(sweepLineTime, true, zz);

         if(pivotHighTime > 0)
           {
            double zHigh = 0.0, zLow = 0.0;
            if(ResolveSwingPOIBounds(pivotHighTime, false, sp, time, high, low, current_i + 1, zHigh, zLow))
              {
               RegisterLiquidityBlock(false, LB_TRIGGER_BR_SSL, zHigh, zLow, pivotHighTime, current_i, sweepLineTime, indLogic, 0,
                                      ms.GetSweepConfirmingChochTime(sweepLineTime, true));
               m_registered_lb_keys.Add(key);
              }
           }
        }
     }

   void              SyncInducementMitigations(CInducementLogic* indLogic)
     {
      if(!m_trackPostInducementCHoCH || indLogic == NULL || CheckPointer(indLogic) != POINTER_DYNAMIC)
         return;

      for(int z = 0; z < indLogic.m_zones.Total(); z++)
        {
         CInducementZone* ind = (CInducementZone*)indLogic.m_zones.At(z);
         if(ind == NULL || CheckPointer(ind) != POINTER_DYNAMIC || !ind.isInducement || !ind.isMitigated || ind.mitigationTime == 0)
            continue;

         bool alreadyTracked = false;
         for(int t = 0; t < ArraySize(m_mitig_trackers); t++)
           {
            if(m_mitig_trackers[t].inducementId == ind.id)
              {
               alreadyTracked = true;
               break;
              }
           }

         if(!alreadyTracked)
           {
            int sz = ArraySize(m_mitig_trackers);
            ArrayResize(m_mitig_trackers, sz + 1);
            m_mitig_trackers[sz].inducementId         = ind.id;
            m_mitig_trackers[sz].isBullishInducement  = ind.isBullish;
            m_mitig_trackers[sz].inducementLevel      = ind.isBullish ? ind.zoneLow : ind.zoneHigh;
            m_mitig_trackers[sz].mitigationTime       = ind.mitigationTime;
            m_mitig_trackers[sz].inducementOriginTime = ind.createdTime;
            m_mitig_trackers[sz].chochCaptured        = false;
            m_mitig_trackers[sz].waitingForBOS        = false;
            m_mitig_trackers[sz].chochTime            = 0;
            m_mitig_trackers[sz].pendingProtTime      = 0;
            m_mitig_trackers[sz].pendingZHigh         = 0.0;
            m_mitig_trackers[sz].pendingZLow          = 0.0;
           }
        }
     }

   //+------------------------------------------------------------------+
   //| Strict 3+ Structure Confirmation (CHoCH -> BOS) Implementation   |
   //+------------------------------------------------------------------+
   //+------------------------------------------------------------------+
   //| Adaptive Structure Confirmation (HTF: 3+ | LTF: 5+)              |
   //+------------------------------------------------------------------+
   void              ProcessPostInducementCHoCH(int current_i, const datetime &time[], const double &high[], const double &low[],
         CMarketStructure* ms, CSwingPOILogic* sp, CInducementLogic* indLogic)
     {
      if(!m_trackPostInducementCHoCH || ms == NULL || CheckPointer(ms) != POINTER_DYNAMIC)
         return;

      if(ms.last_breakout_time == 0)
         return;

      datetime boTime = ms.last_breakout_time;
      int minReq = GetRequiredStructureCount(ms); // 3 for HTF (H4, H1, M15, M10) | 5 for LTF (M5, M3, M1)

      for(int t = 0; t < ArraySize(m_mitig_trackers); t++)
        {
         if(m_mitig_trackers[t].chochCaptured)
            continue;

         if(boTime < m_mitig_trackers[t].mitigationTime)
            continue;

         // -----------------------------------------------------------------
         // CASE A: Post Buyers' Inducement Mitigation -> Candidate BL-LB-IND
         // -----------------------------------------------------------------
         if(m_mitig_trackers[t].isBullishInducement)
           {
            // If waiting for BL-BOS (because preceding structures met threshold)
            if(m_mitig_trackers[t].waitingForBOS)
              {
               if(ms.trend == 1 && (ms.ev1_name == "BL-BOS" || ms.ev2_name == "BL-BOS"))
                 {
                  RegisterLiquidityBlock(true, LB_TRIGGER_BL_IND, m_mitig_trackers[t].pendingZHigh, m_mitig_trackers[t].pendingZLow,
                                         m_mitig_trackers[t].pendingProtTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, m_mitig_trackers[t].chochTime);
                  m_mitig_trackers[t].chochCaptured = true;
                  m_mitig_trackers[t].waitingForBOS = false;
                 }
               else
                  if(ms.trend == -1 && (ms.ev1_name == "BR-CHoCH" || ms.ev1_name == "BR-BOS" || ms.ev1_name == "SSL-Swept"))
                    {
                     m_mitig_trackers[t].waitingForBOS = false; // Invalidated
                    }
               continue;
              }

            if(ms.trend == 1 && (ms.ev1_name == "BL-CHoCH" || ms.ev2_name == "BL-CHoCH" || ms.ev1_name == "BL-BOS" || ms.ev2_name == "BL-BOS"))
              {
               datetime protTime = ms.protected_level_time;
               if(protTime >= m_mitig_trackers[t].mitigationTime || ms.protected_level_price <= m_mitig_trackers[t].inducementLevel)
                 {
                  double zHigh = 0.0, zLow = 0.0;
                  if(ResolveSwingPOIBounds(protTime, true, sp, time, high, low, current_i + 1, zHigh, zLow))
                    {
                     int bearCount = ms.GetPrecedingBearishStructureCount(boTime);
                     if(bearCount >= minReq)
                       {
                        // Exceeded threshold: Wait for tf-BL-CHoCH -> tf-BL-BOS
                        m_mitig_trackers[t].waitingForBOS   = true;
                        m_mitig_trackers[t].chochTime       = boTime;
                        m_mitig_trackers[t].pendingProtTime = protTime;
                        m_mitig_trackers[t].pendingZHigh    = zHigh;
                        m_mitig_trackers[t].pendingZLow     = zLow;
                       }
                     else
                       {
                        RegisterLiquidityBlock(true, LB_TRIGGER_BL_IND, zHigh, zLow, protTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, ms.ev1_name == "BL-CHoCH" ? boTime : 0);
                        m_mitig_trackers[t].chochCaptured = true;
                       }
                    }
                 }
              }
           }
         // -----------------------------------------------------------------
         // CASE B: Post Sellers' Inducement Mitigation -> Candidate BR-LB-IND
         // -----------------------------------------------------------------
         else
           {
            // If waiting for BR-BOS (because preceding structures met threshold)
            if(m_mitig_trackers[t].waitingForBOS)
              {
               if(ms.trend == -1 && (ms.ev1_name == "BR-BOS" || ms.ev2_name == "BR-BOS"))
                 {
                  RegisterLiquidityBlock(false, LB_TRIGGER_BR_IND, m_mitig_trackers[t].pendingZHigh, m_mitig_trackers[t].pendingZLow,
                                         m_mitig_trackers[t].pendingProtTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, m_mitig_trackers[t].chochTime);
                  m_mitig_trackers[t].chochCaptured = true;
                  m_mitig_trackers[t].waitingForBOS = false;
                 }
               else
                  if(ms.trend == 1 && (ms.ev1_name == "BL-CHoCH" || ms.ev1_name == "BL-BOS" || ms.ev1_name == "BSL-Swept"))
                    {
                     m_mitig_trackers[t].waitingForBOS = false; // Invalidated
                    }
               continue;
              }

            if(ms.trend == -1 && (ms.ev1_name == "BR-CHoCH" || ms.ev2_name == "BR-CHoCH" || ms.ev1_name == "BR-BOS" || ms.ev2_name == "BR-BOS"))
              {
               datetime protTime = ms.protected_level_time;
               if(protTime >= m_mitig_trackers[t].mitigationTime || ms.protected_level_price >= m_mitig_trackers[t].inducementLevel)
                 {
                  double zHigh = 0.0, zLow = 0.0;
                  if(ResolveSwingPOIBounds(protTime, false, sp, time, high, low, current_i + 1, zHigh, zLow))
                    {
                     int bullCount = ms.GetPrecedingBullishStructureCount(boTime);
                     if(bullCount >= minReq)
                       {
                        // Exceeded threshold: Wait for tf-BR-CHoCH -> tf-BR-BOS
                        m_mitig_trackers[t].waitingForBOS   = true;
                        m_mitig_trackers[t].chochTime       = boTime;
                        m_mitig_trackers[t].pendingProtTime = protTime;
                        m_mitig_trackers[t].pendingZHigh    = zHigh;
                        m_mitig_trackers[t].pendingZLow     = zLow;
                       }
                     else
                       {
                        RegisterLiquidityBlock(false, LB_TRIGGER_BR_IND, zHigh, zLow, protTime, current_i, boTime, indLogic, m_mitig_trackers[t].inducementOriginTime, ms.ev1_name == "BR-CHoCH" ? boTime : 0);
                        m_mitig_trackers[t].chochCaptured = true;
                       }
                    }
                 }
              }
           }
        }
     }
   void              UpdateLBMitigations(int current_i, const datetime &time[], const double &high[], const double &low[])
     {
      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb.isMitigated)
            continue;

         if(time[current_i] <= lb.createdTime)
            continue;

         if(lb.isBullish)
           {
            if(CTradeRejection::BoundaryBroken(true, low[current_i], high[current_i], lb.zoneLow, lb.zoneHigh, 0.0))
              {
               lb.isMitigated        = true;
               lb.mitigationTime     = time[current_i];
               lb.mitigationBarIndex = current_i;
              }
           }
         else
           {
            if(CTradeRejection::BoundaryBroken(false, low[current_i], high[current_i], lb.zoneLow, lb.zoneHigh, 0.0))
              {
               lb.isMitigated        = true;
               lb.mitigationTime     = time[current_i];
               lb.mitigationBarIndex = current_i;
              }
           }
        }
     }

   void              UpdateLBTouches(int current_i, const datetime &time[], const double &high[], const double &low[], ZigZag* zz)
     {
      if(zz == NULL || CheckPointer(zz) != POINTER_DYNAMIC || zz.pivots.Total() < 2)
         return;
      int p_total = zz.pivots.Total();

      for(int i = 0; i < m_liquidity_blocks.Total(); i++)
        {
         CLiquidityBlock* lb = (CLiquidityBlock*)m_liquidity_blocks.At(i);
         if(lb == NULL || CheckPointer(lb) != POINTER_DYNAMIC || lb.isMitigated)
            continue;

         datetime cutoffTime = time[current_i];

         for(int p_idx = 0; p_idx <= p_total - 2; p_idx++)
           {
            Pivot* p = (Pivot*)zz.pivots.At(p_idx);
            if(p == NULL || CheckPointer(p) != POINTER_DYNAMIC || (zz.projection != NULL && p == zz.projection))
               continue;
            if(p.end == NULL || CheckPointer(p.end) != POINTER_DYNAMIC)
               continue;

            datetime p_time = p.end.time;
            if(p_time <= lb.createdTime || p_time > cutoffTime)
               continue;
            if(lb.HasPivotTouched(p_time))
               continue;

            double p_price = p.end.price;

            if(lb.isBullish)
              {
               if(!p.isHigh && p_price <= lb.zoneHigh && p_price >= lb.zoneLow)
                 {
                  lb.touchTimes.Add((long)p_time);
                  lb.touchCount++;
                 }
              }
            else
              {
               if(p.isHigh && p_price >= lb.zoneLow && p_price <= lb.zoneHigh)
                 {
                  lb.touchTimes.Add((long)p_time);
                  lb.touchCount++;
                 }
              }
           }
        }
     }

   void              Process(int current_i, const datetime &time[], const double &high[], const double &low[],
                             CMarketStructure* ms, CSwingPOILogic* sp, CInducementLogic* indLogic, ZigZag* zz = NULL)
     {
      if(zz != NULL) m_zoneStartTime = zz.zoneStartTime;
      if(time[current_i] < m_zoneStartTime) return;
      ProcessSweptAnywhere(current_i, time, high, low, ms, sp, zz, indLogic);
      SyncInducementMitigations(indLogic);
      ProcessPostInducementCHoCH(current_i, time, high, low, ms, sp, indLogic);
      UpdateLBMitigations(current_i, time, high, low);
      UpdateLBTouches(current_i, time, high, low, zz);
      RefreshExitSources(ms,time[current_i],high[current_i],low[current_i]);

      if(ms != NULL && CheckPointer(ms) == POINTER_DYNAMIC)
         m_last_breakout_evaluated = ms.last_breakout_time;
     }
  };

#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Marcotrades\liquidity_blocks.mqh
