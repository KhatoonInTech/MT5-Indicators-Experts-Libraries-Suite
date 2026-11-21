#ifndef MARCO_LB_EXTENSION_MQH
#define MARCO_LB_EXTENSION_MQH
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\trade_rejection.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\staged_tp.mqh"

struct SMarcoExtensionSource
  {
   int tf;
   string id;
   datetime created, available;
  };

class CMarcoLBExtension
  {
public:
   // Inspect both timeframes before changing the TP. The caller extends once per update;
   // if both provide an SL source in this update, prefer the configured entry TF.
   static int Observe(CTradeRejectionHistory &history, const SMarcoTPPlan &plan,
                      SMarcoExtensionState &state, datetime opened, datetime now,
                      int tf, int preferredTF, SMarcoExtensionSource &source)
     {
      int last=CMarcoStagedTP::LastPending(plan), count=0;
      if(last<0 || plan.remaining<=1e-9) return 0;
      double low=MathMin(plan.entry,plan.price[last]), high=MathMax(plan.entry,plan.price[last]);
      for(int i=0;i<history.ZoneCount();i++)
        {
         SRejectionLB lb; if(!history.ZoneAt(i,lb)) continue;
         if(lb.entryVetoed || lb.available>now || (lb.until>0 && now>=lb.until)) continue;
         string key="|"+IntegerToString(tf)+":"+lb.id+"|";
         if(StringFind(state.seen,key)>=0) continue;
         state.seen+=key; // Bound/label changes cannot turn this same LB into a new one.
         SRejectionLB first=lb;
         for(int v=0;v<i;v++)
           {
            SRejectionLB old; if(history.ZoneAt(v,old) && old.id==lb.id) { first=old; break; }
           }
         if(first.created<=opened || first.available<=opened || lb.bull!=(plan.direction==1) ||
            (lb.mitigation>0 && lb.mitigation<=now) || lb.high<low || lb.low>high) continue;
         count++;
         bool preferred=tf==preferredTF, priorPreferred=source.tf==preferredTF;
         if(source.tf==0 || (preferred && !priorPreferred) ||
            (preferred==priorPreferred && (first.available>source.available ||
             (first.available==source.available && first.created>source.created))))
           { source.tf=tf; source.id=lb.id; source.created=first.created; source.available=first.available; }
        }
      return count;
     }
  };
#endif
