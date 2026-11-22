#ifndef MARCO_OPPOSING_ENTRY_WAIT_MQH
#define MARCO_OPPOSING_ENTRY_WAIT_MQH
#include <Custom\Marcotrades\opposing_sequence.mqh>

// Per-setup wait; never represents a fill or consumes an LB cluster.
struct SMarcoOpposingEntryWait
  {
   bool required, waiting;
   datetime since, sourceEvent;
   int sourceTF;
   string sourceId;
  };

class CMarcoOpposingEntryWait
  {
public:
   static bool Vicinity(double price,double low,double high,double buffer)
     {
      return MathIsValidNumber(price) && price>0 && low<=high && buffer>=0 &&
             price>=low-buffer && price<=high+buffer;
     }

   static bool OpposingSource(CTradeRejectionHistory &history,bool bull,datetime now,
                              ENUM_TIMEFRAMES tf,SRejectionEvent &event,string &id)
     {
      if(!history.Latest(now,event) || CMarcoOpposingSequence::Direction(event.name)!=(bull ? -1 : 1))
         return false;
      SRejectionEvent linked=event;
      for(int pass=0;pass<history.EventCount();pass++)
        {
         // A source may first be registered on the second structure. Use only
         // its currently available version, without backdating its availability.
         for(int z=history.ZoneCount()-1;z>=0;z--)
           {
            SRejectionLB lb;
            if(!history.ZoneAt(z,lb) || !history.ActiveSource(lb,bull,now,tf)) continue;
            if(lb.choch==linked.time ||
               (lb.available<=linked.available && CTradeRejection::OriginInside(linked.originTime,linked.originPrice,
                   lb.created,lb.mitigation,PeriodSeconds(tf),lb.low,lb.high,0)))
              { id=lb.id; return true; }
           }
         SRejectionEvent previous; bool found=false;
         for(int i=0;i<history.EventCount();i++)
           {
            SRejectionEvent candidate;
            if(!history.EventAt(i,now,candidate) || candidate.time>=linked.time) continue;
            if(!found || candidate.time>previous.time) { previous=candidate; found=true; }
           }
         if(!found || CMarcoOpposingSequence::Direction(previous.name)!=(bull ? -1 : 1)) break;
         linked=previous;
        }
      return false;
     }

   static bool Begin(SMarcoOpposingEntryWait &state,CTradeRejectionHistory &history,
                     bool bull,datetime now,ENUM_TIMEFRAMES tf)
     {
      if(state.waiting) return true;
      if(state.required) { state.waiting=true; state.since=now; return true; }
      SRejectionEvent event; string id;
      if(!OpposingSource(history,bull,now,tf,event,id)) return false;
      state.required=true; state.waiting=true; state.since=now; state.sourceEvent=event.time;
      state.sourceTF=(int)tf; state.sourceId=id;
      return true;
     }

   // Vicinity belongs to the CHoCH swing, not its break candle or fill price.
   static bool Ready(SMarcoOpposingEntryWait &state,CTradeRejectionHistory &m1,bool bull,
                     datetime now,double low,double high,double buffer,
                     SRejectionEvent &event)
     {
      if(!state.waiting || !m1.Latest(now,event) || event.name!=(bull ? "BL-CHoCH" : "BR-CHoCH") ||
         event.time<state.since-state.since%60 || event.available<=state.since || event.available>now || now>=event.available+60 ||
         event.originTime<=0 || event.originTime>event.time ||
         !Vicinity(event.originPrice,low,high,buffer)) return false;
      return true;
     }

   // Only the exact M1 CHoCH used by this entry can activate this extension.
   // Revisions are read as-of now; an old chart label cannot supply future data.
   static bool FailedEntry(CTradeRejectionHistory &m1,SMarcoTPPlan &plan,
                           datetime opened,datetime now,double price,SMarcoSequenceSignal &signal)
     {
      if(plan.reversalEntryEvent<=0 || plan.reversalEntryDone || now<=opened) return false;
      SRejectionEvent first,next; bool haveFirst=false,haveNext=false;
      for(int i=0;i<m1.EventCount();i++)
        {
         SRejectionEvent event;
         if(!m1.EventAt(i,now,event)) continue;
         if(event.time==plan.reversalEntryEvent) { first=event; haveFirst=true; }
         if(event.time<=plan.reversalEntryEvent || CMarcoOpposingSequence::Direction(event.name)==0) continue;
         if(!haveNext || event.time<next.time) { next=event; haveNext=true; }
        }
      if(!haveFirst || !haveNext || next.available<=opened) return false;
      if(next.name==(plan.direction==1 ? "BL-BOS" : "BR-BOS"))
        { plan.reversalEntryDone=true; return false; }
      if(first.name!=(plan.direction==1 ? "SSL-Swept" : "BSL-Swept") ||
         CMarcoOpposingSequence::Direction(next.name)!=-plan.direction) return false;
      plan.reversalEntryDone=true;
      if(plan.direction*(price-plan.entry)>=0) return false;
      plan.sequence.step=2; plan.sequence.tf=(int)PERIOD_M1;
      plan.sequence.firstEvent=plan.reversalEntryEvent; plan.sequence.firstProfit=false;
      plan.sequence.pending=true; plan.sequence.share=1.0; plan.sequence.requestedLots=0;
      signal.action=2; signal.step=2; signal.tf=(int)PERIOD_M1;
      signal.eventTime=next.time; signal.lbId="M1 entry CHoCH reclassified as sweep";
      signal.share=1.0; signal.profit=false;
      return true;
     }
  };
#endif
