#ifndef MARCO_OPPOSING_SEQUENCE_MQH
#define MARCO_OPPOSING_SEQUENCE_MQH
#include <Custom\Marcotrades\trade_rejection.mqh>
#include <Custom\Marcotrades\staged_tp.mqh>

struct SMarcoSequenceSignal
  {
   int action, step, tf; // 0=no close, 1=partial, 2=full remaining close.
   datetime eventTime;
   string lbId;
   double share;
   bool profit;
  };

class CMarcoOpposingSequence
  {
public:
   static int Direction(string name)
     {
      if(name=="BL-BOS" || name=="BL-CHoCH" || name=="BSL-Swept") return 1;
      if(name=="BR-BOS" || name=="BR-CHoCH" || name=="SSL-Swept") return -1;
      return 0;
     }

   static bool Source(CTradeRejectionHistory &history, const SRejectionEvent &event,
                      int direction, ENUM_TIMEFRAMES tf, string &id)
     {
      for(int i=history.ZoneCount()-1;i>=0;i--)
        {
         SRejectionLB lb;
         if(!history.ZoneAt(i,lb) || lb.bull!=(direction==1) || lb.available>event.available ||
            (lb.until>0 && event.available>=lb.until)) continue;
         if(lb.choch!=event.time &&
            !CTradeRejection::OriginInside(event.originTime,event.originPrice,lb.created,
                                          lb.mitigation,PeriodSeconds(tf),lb.low,lb.high,0)) continue;
         id=lb.id; return true;
        }
      return false;
     }

   static SMarcoSequenceSignal Advance(CTradeRejectionHistory &history, SMarcoOpposingSequence &state,
                                       int slot, ENUM_TIMEFRAMES tf, int direction, double entry,
                                       double executionPrice, datetime opened, datetime now)
     {
      SMarcoSequenceSignal result; ZeroMemory(result);
      if(state.pending || state.step>=2 || (state.step==1 && state.tf!=(int)tf)) return result;
      // Select by event time, not insertion order: label revisions are appended
      // to history but must never become another first/second structure.
      for(int pass=0;pass<history.EventCount();pass++)
        {
         SRejectionEvent next; bool found=false;
         for(int i=0;i<history.EventCount();i++)
           {
            SRejectionEvent event;
            if(!history.EventAt(i,now,event) || event.time<=state.seen[slot] ||
               event.time<opened || event.available<=opened || Direction(event.name)==0) continue;
            if(!found || event.time<next.time) { next=event; found=true; }
           }
         if(!found) break;
         state.seen[slot]=next.time;
         int opposing=-direction;
         if(state.step==1)
           {
            for(int i=0;i<history.EventCount();i++)
              {
               SRejectionEvent first;
               if(history.EventAt(i,now,first) && first.time==state.firstEvent && Direction(first.name)!=opposing)
                 { state.step=2; return result; }
              }
            // The next structural event must be adjacent on the SAME timeframe.
            // A return to the trade's direction cancels the outstanding second exit.
            state.step=2;
            if(Direction(next.name)!=opposing) return result;
            result.profit=direction*(executionPrice-entry)>0;
            result.share=result.profit ? (state.firstProfit ? 0.25 : 0.0) : 1.0;
           }
         else
           {
            if(Direction(next.name)!=opposing || !Source(history,next,opposing,tf,result.lbId)) continue;
            state.step=1; state.tf=(int)tf; state.firstEvent=next.time;
            state.firstProfit=direction*(executionPrice-entry)>0;
            result.profit=state.firstProfit;
            result.share=result.profit ? 0.25 : 0.50;
           }
         result.step=state.step; result.tf=(int)tf; result.eventTime=next.time;
         result.action=result.share>=1 ? 2 : (result.share>0 ? 1 : 0);
         state.pending=result.action>0; state.share=result.share; state.requestedLots=0;
         return result;
        }
      return result;
     }
  };
#endif
