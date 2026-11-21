#ifndef MARCO_STRUCTURE_EXIT_MQH
#define MARCO_STRUCTURE_EXIT_MQH
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\trade_rejection.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\staged_tp.mqh"

// Actions: 0=none, 1=half the remaining position + BE, 2=all remaining volume.
struct SMarcoStructureExit
  {
   int action;
   ENUM_TIMEFRAMES tf;
   datetime eventTime;
   string lbId;
   double level;
  };

class CMarcoStructureExit
  {
public:
   static bool Inside(double price, double a, double b)
     { return price>=MathMin(a,b) && price<=MathMax(a,b); }
   static bool Overlaps(double low, double high, double a, double b)
     { return high>=MathMin(a,b) && low<=MathMax(a,b); }

   static SMarcoStructureExit Evaluate(CTradeRejectionHistory &history, const SMarcoTPPlan &plan,
                                       datetime opened, datetime now, ENUM_TIMEFRAMES tf)
     {
      SMarcoStructureExit result; result.action=0; result.tf=tf;
      result.eventTime=0; result.lbId=""; result.level=0;
      if(plan.remaining<=1e-9) return result;
      // Check every still-valid post-entry CHoCH. A later BOS must not hide an
      // exit while its source LB is awaiting recognition or live bars catch up.
      for(int e=history.EventCount()-1;e>=0;e--)
        {
         SRejectionEvent event;
         if(!history.EventAt(e,now,event) || event.time<opened || event.available<=opened ||
            event.name!=(plan.direction==1 ? "BR-CHoCH" : "BL-CHoCH") || event.linePrice<=0)
            continue;
         for(int b=history.ZoneCount()-1;b>=0;b--)
           {
            SRejectionLB lb; if(!history.ZoneAt(b,lb)) continue;
            if(lb.bull!=(plan.direction==-1) || lb.available>now || (lb.until>0 && now>=lb.until)) continue;
            // Require the CHoCH's source in this LB, or an explicit causal CHoCH link.
            bool linked=lb.choch==event.time;
            datetime firstAvailable=lb.available;
            for(int v=b;v>=0;v--)
              {
               SRejectionLB source; if(!history.ZoneAt(v,source) || source.id!=lb.id) continue;
               firstAvailable=MathMin(firstAvailable,source.available);
               if(source.available>event.available || (source.until>0 && event.available>=source.until)) continue;
               if(CTradeRejection::OriginInside(event.originTime,event.originPrice,source.created,
                                               source.mitigation,PeriodSeconds(tf),source.low,source.high,0.0)) linked=true;
              }
            if(!linked) continue;
            int action=0;
            // SL-side overlap also qualifies; full exit wins if the LB spans both regions.
            if(Inside(event.linePrice,plan.entry,plan.initialSL) ||
               Overlaps(lb.low,lb.high,plan.entry,plan.initialSL)) action=2;
            else if(plan.structureTime[0]==0 && lb.created>opened && firstAvailable>opened &&
                    Overlaps(lb.low,lb.high,plan.entry,CMarcoStagedTP::Farthest(plan))) action=1;
            if(action<=result.action) continue;
            result.action=action; result.eventTime=event.time; result.lbId=lb.id; result.level=event.linePrice;
           }
        }
      return result;
     }
  };
#endif
