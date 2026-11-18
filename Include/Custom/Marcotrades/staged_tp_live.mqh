#ifndef MARCO_STAGED_TP_LIVE_MQH
#define MARCO_STAGED_TP_LIVE_MQH
#include <Trade\Trade.mqh>
#include <Custom\Marcotrades\staged_tp.mqh>

struct SMarcoLiveTPState
  {
   SMarcoTPPlan plan;
   SMarcoExtensionState extension;
   double lots, riskCash;
   int pendingStage; // 0..2 normal TP, 3..6 structure/sequence, 7..9 vicinity TP.
   double pendingBefore, pendingVolume;
   ulong pendingOrder;
   datetime retryAt;
   int structureAction; // Durable intent: 1=half remaining, 2=full close.
  };

// Per-position durable state is separate from the daily report, so partial exits
// survive a chart/input restart and journal rewrites. Never recalculate target zones.
class CMarcoLiveStagedTP
  {
public:
   static ulong Select(ulong identifier)
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==identifier) return ticket;
        }
      return 0;
     }
   static string Path(long magic, ulong identifier)
     {
      return "marcotrades\\LiveEA\\TP_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
             IntegerToString(magic)+"_"+IntegerToString(identifier)+".bin";
     }
   static bool Save(long magic, ulong identifier, const SMarcoLiveTPState &state)
     {
      FolderCreate("marcotrades"); FolderCreate("marcotrades\\LiveEA");
      string path=Path(magic,identifier), temp=path+".tmp";
      int f=FileOpen(temp,FILE_WRITE|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      FileWriteInteger(f,5); FileWriteInteger(f,state.plan.count); FileWriteInteger(f,state.plan.direction);
      FileWriteDouble(f,state.plan.entry); FileWriteDouble(f,state.plan.initialSL);
      FileWriteDouble(f,state.plan.remaining); FileWriteDouble(f,state.plan.realizedR);
      FileWriteInteger(f,state.plan.breakeven ? 1 : 0);
      FileWriteDouble(f,state.lots); FileWriteDouble(f,state.riskCash);
      for(int i=0;i<3;i++)
        {
         FileWriteInteger(f,state.plan.kind[i]);
         FileWriteDouble(f,state.plan.price[i]); FileWriteDouble(f,state.plan.fraction[i]);
         FileWriteDouble(f,state.plan.closed[i]); FileWriteDouble(f,state.plan.exitPrice[i]);
         FileWriteLong(f,(long)state.plan.exitTime[i]); FileWriteLong(f,(long)state.plan.vicinityTime[i]);
        }
      FileWriteInteger(f,state.pendingStage); FileWriteDouble(f,state.pendingBefore);
      FileWriteDouble(f,state.pendingVolume); FileWriteLong(f,(long)state.pendingOrder);
      FileWriteLong(f,(long)state.retryAt);
      for(int i=0;i<2;i++)
        {
         FileWriteDouble(f,state.plan.structureClosed[i]); FileWriteDouble(f,state.plan.structurePrice[i]);
         FileWriteLong(f,(long)state.plan.structureTime[i]);
        }
      FileWriteInteger(f,state.structureAction);
      FileWriteDouble(f,state.plan.protectedSL); FileWriteInteger(f,state.plan.extensionCount);
      FileWriteLong(f,(long)state.plan.extensionTime);
      int keys=StringLen(state.extension.seen); FileWriteInteger(f,keys);
      if(keys>0) FileWriteString(f,state.extension.seen,keys);
      for(int i=0;i<2;i++) FileWriteLong(f,(long)state.plan.sequence.seen[i]);
      FileWriteInteger(f,state.plan.sequence.step); FileWriteInteger(f,state.plan.sequence.tf);
      FileWriteLong(f,(long)state.plan.sequence.firstEvent);
      FileWriteInteger(f,state.plan.sequence.firstProfit ? 1 : 0);
      FileWriteInteger(f,state.plan.sequence.pending ? 1 : 0);
      FileWriteDouble(f,state.plan.sequence.share); FileWriteDouble(f,state.plan.sequence.requestedLots);
      for(int i=0;i<2;i++)
        {
         FileWriteDouble(f,state.plan.sequence.closed[i]); FileWriteDouble(f,state.plan.sequence.price[i]);
         FileWriteLong(f,(long)state.plan.sequence.time[i]);
        }
      FileFlush(f);
      bool complete=FileTell(f)==(ulong)(436+keys*2);
      FileClose(f);
      return complete && FileMove(temp,0,path,FILE_REWRITE);
     }
   static bool Load(long magic, ulong identifier, SMarcoLiveTPState &state)
     {
      ZeroMemory(state); state.pendingStage=-1;
      int f=FileOpen(Path(magic,identifier),FILE_READ|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      ulong size=FileSize(f); int version=FileReadInteger(f);
      if(!((version==1 && size==256) || (version==2 && size==308) ||
           (version==3 && size>=332 && size<=2000332) || ((version==4 || version==5) && size>=436 && size<=2000436))) { FileClose(f); return false; }
      state.plan.count=FileReadInteger(f); state.plan.direction=FileReadInteger(f);
      state.plan.entry=FileReadDouble(f); state.plan.initialSL=FileReadDouble(f);
      state.plan.remaining=FileReadDouble(f); state.plan.realizedR=FileReadDouble(f);
      state.plan.breakeven=FileReadInteger(f)!=0;
      state.lots=FileReadDouble(f); state.riskCash=FileReadDouble(f);
      for(int i=0;i<3;i++)
        {
         state.plan.kind[i]=FileReadInteger(f);
         state.plan.price[i]=FileReadDouble(f); state.plan.fraction[i]=FileReadDouble(f);
         state.plan.closed[i]=FileReadDouble(f); state.plan.exitPrice[i]=FileReadDouble(f);
         state.plan.exitTime[i]=(datetime)FileReadLong(f); state.plan.vicinityTime[i]=(datetime)FileReadLong(f);
        }
      state.pendingStage=FileReadInteger(f); state.pendingBefore=FileReadDouble(f);
      state.pendingVolume=FileReadDouble(f); state.pendingOrder=(ulong)FileReadLong(f);
      state.retryAt=(datetime)FileReadLong(f);
      if(version>=2)
        {
         for(int i=0;i<2;i++)
           {
            state.plan.structureClosed[i]=FileReadDouble(f); state.plan.structurePrice[i]=FileReadDouble(f);
            state.plan.structureTime[i]=(datetime)FileReadLong(f);
           }
         state.structureAction=FileReadInteger(f);
        }
      if(version>=3)
        {
         state.plan.protectedSL=FileReadDouble(f); state.plan.extensionCount=FileReadInteger(f);
         state.plan.extensionTime=(datetime)FileReadLong(f);
         int keys=FileReadInteger(f);
         if(keys<0 || keys>1000000 || size!=(ulong)((version>=4 ? 436 : 332)+keys*2)) { FileClose(f); return false; }
         if(keys>0) state.extension.seen=FileReadString(f,keys);
         if(StringLen(state.extension.seen)!=keys) { FileClose(f); return false; }
        }
      if(version>=4)
        {
         for(int i=0;i<2;i++) state.plan.sequence.seen[i]=(datetime)FileReadLong(f);
         state.plan.sequence.step=FileReadInteger(f); state.plan.sequence.tf=FileReadInteger(f);
         state.plan.sequence.firstEvent=(datetime)FileReadLong(f);
         state.plan.sequence.firstProfit=FileReadInteger(f)!=0;
         state.plan.sequence.pending=FileReadInteger(f)!=0;
         state.plan.sequence.share=FileReadDouble(f); state.plan.sequence.requestedLots=FileReadDouble(f);
         for(int i=0;i<2;i++)
           {
            state.plan.sequence.closed[i]=FileReadDouble(f); state.plan.sequence.price[i]=FileReadDouble(f);
            state.plan.sequence.time[i]=(datetime)FileReadLong(f);
           }
        }
      else
        {
         // Upgrading a running position must not replay old opposing structures.
         state.plan.sequence.seen[0]=TimeCurrent(); state.plan.sequence.seen[1]=TimeCurrent();
         if(state.plan.structureClosed[0]>0 || state.plan.structureClosed[1]>0) state.plan.sequence.step=2;
        }
      FileClose(f);
      bool valid=state.plan.count>=2 && state.plan.count<=3 && MathAbs(state.plan.direction)==1 && state.lots>0 &&
             (state.pendingStage==-1 || (state.pendingStage>=0 && state.pendingStage<state.plan.count) ||
              state.pendingStage==3 || state.pendingStage==4 || state.pendingStage==5 || state.pendingStage==6 ||
              (version>=5 && state.pendingStage>=7 && state.pendingStage<7+state.plan.count)) &&
             state.structureAction>=0 && state.structureAction<=2 && state.plan.sequence.step>=0 && state.plan.sequence.step<=2 &&
             (!state.plan.sequence.pending || (state.plan.sequence.step>0 && state.plan.sequence.share>0 && state.plan.sequence.share<=1));
      return valid && (version>=5 || Save(magic,identifier,state));
     }

   static void Breakeven(CTrade &trade, ulong identifier, const SMarcoLiveTPState &state)
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return;
      ulong ticket=Select(identifier);
      if(ticket==0) return;
      double sl=PositionGetDouble(POSITION_SL);
      string symbol=PositionGetString(POSITION_SYMBOL);
      double grid=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      if(grid<=0) return;
      // A multi-fill average entry can fall between ticks. Round BE towards profit.
      double desired=CMarcoStagedTP::Stop(state.plan);
      double units=desired/grid;
      double be=NormalizeDouble((state.plan.direction==1 ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*grid,
                                (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
      int last=CMarcoStagedTP::LastPending(state.plan);
      double target=last>=0 ? state.plan.price[last] : CMarcoStagedTP::Farthest(state.plan);
      bool moveSL=(state.plan.breakeven || state.plan.protectedSL>0) && (sl<=0 || state.plan.direction*(sl-be)<-1e-9);
      if(!moveSL && MathAbs(PositionGetDouble(POSITION_TP)-target)<1e-9) return;
      // A rejected stops/freeze-level modification remains pending and is retried.
      trade.SetAsyncMode(false);
      bool modified=trade.PositionModify(ticket,moveSL ? be : sl,target);
      if(moveSL && (!modified || trade.ResultRetcode()!=TRADE_RETCODE_DONE))
        {
         // A too-close/frozen SL must not prevent the independent TP extension.
         if(Select(identifier)>0 && MathAbs(PositionGetDouble(POSITION_TP)-target)>1e-9)
            trade.PositionModify(ticket,PositionGetDouble(POSITION_SL),target);
        }
     }

   static void RecordFill(SMarcoLiveTPState &state, int stage, double lots, double price, string symbol)
     {
      if(stage>=7)
         CMarcoStagedTP::Exit(state.plan,stage-7,lots/state.lots,price,TimeCurrent(),false);
      else if(stage>=5)
        {
         CMarcoStagedTP::SequenceFill(state.plan,lots,price,TimeCurrent(),state.lots,
                                    SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
        }
      else if(stage>=3)
        {
         CMarcoStagedTP::StructureExit(state.plan,stage==4,lots/state.lots,price,TimeCurrent(),
                                      state.lots,SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
         if(stage==4 || state.structureAction==1) state.structureAction=0;
        }
      else CMarcoStagedTP::Exit(state.plan,stage,lots/state.lots,price,TimeCurrent());
     }

   static bool Manage(CTrade &trade, long magic, ulong identifier, string symbol,
                      bool useVicinity, double vicinityDistance, ENUM_TIMEFRAMES vicinityTF, int structureAction=0)
     {
      SMarcoLiveTPState state;
      if(!Load(magic,identifier,state)) return false; // Legacy positions retain legacy handling.
      ulong ticket=Select(identifier);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol || PositionGetInteger(POSITION_MAGIC)!=magic) return false;
      if(structureAction>state.structureAction && (structureAction==2 || state.plan.structureTime[0]==0))
        {
         state.structureAction=structureAction;
         if(!Save(magic,identifier,state)) return false;
        }
      double volume=PositionGetDouble(POSITION_VOLUME);
      double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      if(step<=0) return false;
      MqlTick tick={}; if(!SymbolInfoTick(symbol,tick)) return false;
      double price=state.plan.direction==1 ? tick.bid : tick.ask;
      bool changed=false;
      // Persisted before sending: an uncertain request must never be blindly resent.
      if(state.pendingStage>=0)
        {
         double reduced=state.pendingBefore-volume;
         if(reduced>step*0.1)
           {
            RecordFill(state,state.pendingStage,reduced,price,symbol);
            state.pendingStage=-1; state.pendingOrder=0;
            if(!Save(magic,identifier,state)) return false;
            changed=true;
           }
         else if(state.pendingOrder>0 && HistoryOrderSelect(state.pendingOrder))
           {
            long status=HistoryOrderGetInteger(state.pendingOrder,ORDER_STATE);
            if(status==ORDER_STATE_REJECTED || status==ORDER_STATE_CANCELED || status==ORDER_STATE_EXPIRED)
              {
               state.pendingStage=-1; state.pendingOrder=0; state.retryAt=TimeCurrent()+5;
               if(!Save(magic,identifier,state)) return false;
              }
            else return false;
           }
         else return false;
        }
      Breakeven(trade,identifier,state);
      // Do not allocate another strategy's/manual additions or unexplained reductions.
      if(MathAbs(volume-state.lots*state.plan.remaining)>step*0.1) return changed;
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return changed;
      if(TimeCurrent()<state.retryAt) return changed;
      // Broker stop/freeze limits may reject SL=entry. Protect the remainder at
      // market if price crosses the requested protective stop before the server accepts it.
      if(state.structureAction!=2 && (state.plan.breakeven || state.plan.protectedSL>0) &&
         state.plan.direction*(price-CMarcoStagedTP::Stop(state.plan))<=0)
        {
         trade.SetAsyncMode(false);
         if(trade.PositionClose(ticket) && trade.ResultRetcode()==TRADE_RETCODE_DONE)
           {
            CMarcoStagedTP::Exit(state.plan,-1,state.plan.remaining,trade.ResultPrice(),TimeCurrent());
            Save(magic,identifier,state);
            return true;
           }
         state.retryAt=TimeCurrent()+5; Save(magic,identifier,state);
         return changed;
        }
      for(int n=0;n<state.plan.count+1 && state.plan.remaining>1e-9;n++)
        {
         int stage=state.structureAction>0 ? (state.structureAction==2 ? 4 : 3) :
                   (state.plan.sequence.pending ? (state.plan.sequence.share>=1 ? 6 : 5) : CMarcoStagedTP::Next(state.plan));
         if(stage<0) break;
         bool structural=stage>=3;
         bool hit=structural;
         bool vicinityExit=false;
         if(!structural) hit=state.plan.direction*(price-state.plan.price[stage])>=0;
         if(!structural && useVicinity && state.plan.direction*(price-state.plan.price[stage])>=-vicinityDistance && state.plan.vicinityTime[stage]==0)
           {
            state.plan.vicinityTime[stage]=TimeCurrent();
            if(!Save(magic,identifier,state)) return changed;
           }
         if(!structural && !hit && useVicinity && state.plan.vicinityTime[stage]>0 && state.plan.direction*(price-state.plan.entry)>0)
           {
            datetime bar=iTime(symbol,vicinityTF,1);
            if(bar>0 && bar+PeriodSeconds(vicinityTF)>state.plan.vicinityTime[stage])
             {
               hit=state.plan.direction*(iClose(symbol,vicinityTF,1)-iOpen(symbol,vicinityTF,1))<0;
               vicinityExit=hit;
             }
           }
         if(!hit) break;
         ticket=Select(identifier); if(ticket==0) break;
         volume=PositionGetDouble(POSITION_VOLUME);
         double closeLots=volume;
         if(stage>=5)
           {
            if(state.plan.sequence.requestedLots<=0)
               state.plan.sequence.requestedLots=stage==6 ? volume : CMarcoStagedTP::PartialLots(volume,state.plan.sequence.share,step,SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
            closeLots=state.plan.sequence.requestedLots;
           }
         else if(stage==3) closeLots=CMarcoStagedTP::HalfLots(volume,step,SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
         else if(stage<3) closeLots=NormalizeDouble(state.lots*(state.plan.fraction[stage]-state.plan.closed[stage]),8);
         if(stage==3 && closeLots<=0)
           {
            PrintFormat("[CHOCH EXIT] %s #%I64u: remaining %.8f lots cannot be halved on broker lot grid; existing exits retained.",symbol,identifier,volume);
            state.plan.structureTime[0]=TimeCurrent(); state.structureAction=0;
            if(!Save(magic,identifier,state)) return changed;
            continue;
           }
         if(stage>=5 && closeLots<=0)
           {
            PrintFormat("[OPPOSING SEQUENCE SKIPPED] %s #%I64u step=%d: requested share cannot fit broker lot grid.",symbol,identifier,state.plan.sequence.step);
            state.plan.sequence.pending=false;
            if(!Save(magic,identifier,state)) return changed;
            continue;
           }
         closeLots=MathMin(closeLots,volume);
         MqlTradeRequest request={}; MqlTradeResult result={}; MqlTradeCheckResult check={};
         request.action=TRADE_ACTION_DEAL; request.position=ticket; request.symbol=symbol; request.magic=magic;
         request.type=state.plan.direction==1 ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price=price; request.volume=closeLots; request.deviation=10;
         request.type_filling=ORDER_FILLING_FOK;
         request.comment=stage>=5 ? "OPP SEQ "+IntegerToString(state.plan.sequence.step) :
                         (structural ? (stage==4 ? "CHOCH FULL" : "CHOCH HALF") : "MTP"+IntegerToString(stage));
         if(!OrderCheck(request,check) || (check.retcode!=TRADE_RETCODE_DONE && check.retcode!=0))
           { state.retryAt=TimeCurrent()+5; Save(magic,identifier,state); break; }
         state.pendingStage=vicinityExit ? stage+7 : stage;
         state.pendingBefore=volume; state.pendingVolume=closeLots; state.pendingOrder=0;
         if(!Save(magic,identifier,state)) break;
         trade.SetAsyncMode(false);
         bool sent=trade.OrderSend(request,result);
         state.pendingOrder=result.order;
         if(result.retcode==TRADE_RETCODE_DONE && result.volume>0)
           {
            RecordFill(state,state.pendingStage,result.volume,result.price,symbol);
            state.pendingStage=-1; state.pendingOrder=0;
            if(stage>=5)
               PrintFormat("[OPPOSING SEQUENCE FILLED] %s #%I64u step=%d: closed %.8f lots at %.8f remaining=%.8f",
                           symbol,identifier,state.plan.sequence.step,result.volume,result.price,state.lots*state.plan.remaining);
            else if(structural)
               PrintFormat("[CHOCH EXIT FILLED] %s #%I64u %s: closed %.8f lots at %.8f",symbol,identifier,stage==4 ? "FULL" : "HALF + BE",result.volume,result.price);
            else
               PrintFormat("[PARTIAL TP] %s #%I64u %s: closed %.8f lots of original %.8f; stop=%.8f BE_requested=%s",
                           symbol,identifier,CMarcoStagedTP::Name(state.plan.kind[stage]),result.volume,state.lots,
                           CMarcoStagedTP::Stop(state.plan),state.plan.breakeven ? "true" : "false");
            changed=true;
           }
         else if(result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_TIMEOUT &&
                 result.retcode!=TRADE_RETCODE_CONNECTION && result.retcode!=TRADE_RETCODE_DONE_PARTIAL && result.retcode!=0)
           { state.pendingStage=-1; state.pendingOrder=0; state.retryAt=TimeCurrent()+5; }
         if(state.pendingStage>=0)
            PrintFormat("[TP EXIT PENDING] %s #%I64u: code=%u order=%I64u; waiting for broker confirmation before another close.",
                        symbol,identifier,result.retcode,result.order);
         if(!Save(magic,identifier,state)) return changed;
         Breakeven(trade,identifier,state);
         if(state.pendingStage>=0 || !sent || result.retcode!=TRADE_RETCODE_DONE) break;
        }
      return changed;
     }
  };
#endif
