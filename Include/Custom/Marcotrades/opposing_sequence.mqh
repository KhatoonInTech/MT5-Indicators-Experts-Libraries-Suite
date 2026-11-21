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

   // The first linked event may already be known when the position opens.
   // Consult its entry-time version, never a link/label discovered afterwards.
   // No historical partial is invented: only its adjacent post-entry opposing
   // event can request a full close, and only at an executable losing price.
   static bool PreEntryContinuation(CTradeRejectionHistory &history, int slot,
                                     ENUM_TIMEFRAMES tf, int direction, double entry,
                                     double executionPrice, datetime opened, datetime now,
                                     SMarcoOpposingSequence &state, SMarcoSequenceSignal &result)
     {
      if(state.step!=0 || state.pending || now<=opened || direction*(executionPrice-entry)>=0) return false;
      SRejectionEvent first; bool found=false;
      for(int i=0;i<history.EventCount();i++)
        {
         SRejectionEvent event;
         if(!history.EventAt(i,opened,event) || Direction(event.name)==0) continue;
         if(!found || event.time>first.time) { first=event; found=true; }
        }
      string id;
      if(!found || first.time>=opened || Direction(first.name)!=-direction ||
         !Source(history,first,-direction,tf,id)) return false;
      // A later reclassification reversing the first event cancels its chain.
      bool stillOpposing=false;
      SRejectionEvent next; found=false;
      for(int i=0;i<history.EventCount();i++)
        {
         SRejectionEvent event;
         if(!history.EventAt(i,now,event)) continue;
         if(event.time==first.time) stillOpposing=Direction(event.name)==-direction;
         if(event.time<=first.time || Direction(event.name)==0) continue;
         if(!found || event.time<next.time) { next=event; found=true; }
        }
      if(!stillOpposing || !found || next.available<=opened || next.time<=state.seen[slot] ||
         Direction(next.name)!=-direction) return false;
      state.seen[slot]=next.time;
      state.step=2; state.tf=(int)tf; state.firstEvent=first.time; state.firstProfit=false;
      state.pending=true; state.share=1.0; state.requestedLots=0;
      result.action=2; result.step=2; result.tf=(int)tf; result.eventTime=next.time;
      result.lbId=id; result.share=1.0; result.profit=false;
      PrintFormat("[PRE-ENTRY OPPOSING CONTINUATION] source=%s LB=%s first=%s opened=%s second=%s region=SL share=100%%",
                  EnumToString(tf),id,TimeToString(first.time,TIME_DATE|TIME_SECONDS),
                  TimeToString(opened,TIME_DATE|TIME_SECONDS),TimeToString(next.time,TIME_DATE|TIME_SECONDS));
      return true;
     }

   static SMarcoSequenceSignal Advance(CTradeRejectionHistory &history, SMarcoOpposingSequence &state,
                                       int slot, ENUM_TIMEFRAMES tf, int direction, double entry,
                                       double executionPrice, datetime opened, datetime now, bool checkPreEntry=true)
     {
      SMarcoSequenceSignal result; ZeroMemory(result);
      if(state.pending || state.step>=2 || (state.step==1 && state.tf!=(int)tf)) return result;
      if(checkPreEntry && PreEntryContinuation(history,slot,tf,direction,entry,executionPrice,opened,now,state,result)) return result;
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
