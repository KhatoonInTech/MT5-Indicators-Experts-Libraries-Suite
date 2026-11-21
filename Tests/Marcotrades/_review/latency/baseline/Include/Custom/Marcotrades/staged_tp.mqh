// Shared partial-exit policy with durable target extensions. Kind: 0=LB, 1=IND, 2=RR, 3=RR+1.
#ifndef MARCO_STAGED_TP_MQH
#define MARCO_STAGED_TP_MQH
struct SMarcoOpposingSequence
  {
   datetime seen[2];
   int step, tf;
   datetime firstEvent;
   bool firstProfit, pending;
   double share, requestedLots;
   double closed[2], price[2];
   datetime time[2];
  };
struct SMarcoTPPlan
  {
   int count, direction;
   double entry, initialSL, remaining, realizedR;
   bool breakeven;
   int kind[3];
   double price[3], fraction[3], closed[3], exitPrice[3];
   datetime exitTime[3], vicinityTime[3];
   // Index 0 = one-time half exit; index 1 = emergency full exit.
   double structureClosed[2], structurePrice[2];
   datetime structureTime[2];
   double protectedSL; // Profit-side stop requested by a same-direction LB.
   int extensionCount;
   datetime extensionTime;
   SMarcoOpposingSequence sequence;
  };

// Kept outside the fixed-size plan so indicator cache records remain serializable.
struct SMarcoExtensionState
  {
   string seen; // Delimited timeframe + LB ID keys, retained for the life of the trade.
  };

class CMarcoStagedTP
  {
public:
   static string Name(int kind)
     { return kind == 0 ? "LB" : (kind == 1 ? "IND" : (kind == 2 ? "RR" : "RR+1")); }

   static bool ValidTarget(int direction, double entry, double price)
     { return MathIsValidNumber(price) && price > 0.0 && direction * (price-entry) > 0.0; }

   static void Add(SMarcoTPPlan &plan, int kind, double price, double fraction)
     {
      int i = plan.count++;
      plan.kind[i] = kind;
      plan.price[i] = price;
      plan.fraction[i] = fraction;
     }

   static bool Build(SMarcoTPPlan &plan, bool buy, double entry, double sl,
                     double lb, double ind, double rr, int priority,
                     double spreadAdjustment, double tickSize, int digits)
     {
      ZeroMemory(plan);
      plan.direction = buy ? 1 : -1;
      plan.entry = entry;
      plan.initialSL = sl;
      plan.remaining = 1.0;
      double risk = plan.direction * (entry-sl);
      if(!MathIsValidNumber(risk) || risk <= 0 || !MathIsValidNumber(rr) || rr <= 0 ||
         !MathIsValidNumber(tickSize) || tickSize <= 0 || spreadAdjustment < 0 ||
         !MathIsValidNumber(spreadAdjustment) || priority < 0 || priority > 2) return false;
      bool hasLB = ValidTarget(plan.direction, entry, lb);
      bool hasIND = ValidTarget(plan.direction, entry, ind);
      int structural = (hasLB ? 1 : 0) + (hasIND ? 1 : 0);
      double fallback = entry + plan.direction * rr * risk;
      if(structural == 2)
        {
         Add(plan, 0, lb, priority == 0 ? 0.50 : 0.25);
         Add(plan, 1, ind, priority == 1 ? 0.50 : 0.25);
         Add(plan, 2, fallback, priority == 2 ? 0.50 : 0.25);
        }
      else if(structural == 1)
        {
         Add(plan, hasLB ? 0 : 1, hasLB ? lb : ind, priority == 2 ? 0.25 : 0.75);
         Add(plan, 2, fallback, priority == 2 ? 0.75 : 0.25);
        }
      else
        {
         Add(plan, 2, fallback, 0.75);
         Add(plan, 3, entry + plan.direction * (rr+1.0) * risk, 0.25);
        }
      for(int i=0; i<plan.count; i++)
        {
         double adjusted = plan.price[i] - plan.direction * spreadAdjustment;
         // Round towards entry, preserving the existing spread-adjustment option.
         double units = adjusted / tickSize;
         plan.price[i] = NormalizeDouble((buy ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize, digits);
         // Do not silently turn an invalid adjusted TP into a different target.
         if(!ValidTarget(plan.direction, entry, plan.price[i])) return false;
        }
      return true;
     }

   static int Next(const SMarcoTPPlan &plan)
     {
      int next = -1;
      for(int i=0; i<plan.count; i++)
         if(plan.closed[i]+1e-9 < plan.fraction[i] &&
            (next < 0 || plan.direction*(plan.price[i]-plan.price[next]) < 0)) next=i;
      return next;
     }

   static double Farthest(const SMarcoTPPlan &plan)
     {
      double price = plan.price[0];
      for(int i=1; i<plan.count; i++)
         if(plan.direction*(plan.price[i]-price)>0) price=plan.price[i];
      return price;
     }

   static int LastPending(const SMarcoTPPlan &plan)
     {
      int last=-1;
      for(int i=0;i<plan.count;i++)
         if(plan.closed[i]+1e-9<plan.fraction[i] &&
            (last<0 || plan.direction*(plan.price[i]-plan.price[last])>0)) last=i;
      return last;
     }

   static double Stop(const SMarcoTPPlan &plan)
     {
      double stop=plan.breakeven ? plan.entry : plan.initialSL;
      if(plan.protectedSL>0 && plan.direction*(plan.protectedSL-stop)>0) stop=plan.protectedSL;
      return stop;
     }

   static void TightenStop(SMarcoTPPlan &plan, double candidate)
     {
      // Never cross to the loss side of entry, or loosen an already tighter stop.
      if(candidate<=0 || plan.direction*(candidate-plan.entry)<0) candidate=plan.entry;
      plan.breakeven=true;
      if(plan.protectedSL<=0 || plan.direction*(candidate-plan.protectedSL)>0) plan.protectedSL=candidate;
     }

   static bool Extend(SMarcoTPPlan &plan, int count, double rr, double tick, int digits, datetime now)
     {
      int last=LastPending(plan);
      if(last<0 || count<=0 || plan.remaining<=1e-9 || rr<=0 || tick<=0) return false;
      double distance=count*rr*MathAbs(plan.entry-plan.initialSL);
      double raw=plan.price[last]+plan.direction*distance;
      if(!MathIsValidNumber(raw) || !MathIsValidNumber(distance) || distance<=0 || raw<=0) return false;
      double units=raw/tick;
      double target=NormalizeDouble((plan.direction==1 ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*tick,digits);
      if(target<=0 || plan.direction*(target-plan.price[last])<=0) return false;
      plan.price[last]=target;
      plan.vicinityTime[last]=0; // A near-touch of the old TP cannot close the extended target.
      plan.extensionCount+=count; plan.extensionTime=now;
      return true;
     }

   static int Primary(const SMarcoTPPlan &plan)
     {
      int p=0;
      for(int i=1; i<plan.count; i++) if(plan.fraction[i]>plan.fraction[p]) p=i;
      return p;
     }

   static void RebaseFill(SMarcoTPPlan &plan, double fill, double rr, double adjustment, double tickSize, int digits)
     {
      plan.entry=fill;
      double risk=MathAbs(fill-plan.initialSL);
      // Zones and allocations stay frozen; RR distances use the actual filled entry.
      for(int i=0;i<plan.count;i++)
         if(plan.kind[i]>=2)
           {
            double multiple=rr+(plan.kind[i]==3 ? 1.0 : 0.0);
            double units=(fill+plan.direction*(multiple*risk-adjustment))/tickSize;
            plan.price[i]=NormalizeDouble((plan.direction==1 ? MathFloor(units+1e-8) : MathCeil(units-1e-8))*tickSize,digits);
           }
     }

   static double Lots(double maximum, double step, double minimum)
     {
      if(step<=0 || minimum<=0 || maximum<=0) return 0;
      double lots=NormalizeDouble(MathFloor(maximum/(4.0*step)+1e-8)*4.0*step,8);
      return lots/4.0+1e-9 >= minimum ? lots : 0.0;
     }

   // A stage closes a share of ORIGINAL volume, never a share of the remainder.
   static double Exit(SMarcoTPPlan &plan, int stage, double fraction, double price, datetime time,
                      bool normalTarget=true)
     {
      fraction = MathMin(fraction, plan.remaining);
      if(stage>=0) fraction=MathMin(fraction, plan.fraction[stage]-plan.closed[stage]);
      if(fraction<=1e-9) return 0;
      double reward=fraction*plan.direction*(price-plan.entry)/MathAbs(plan.entry-plan.initialSL);
      plan.realizedR+=reward;
      plan.remaining=MathMax(0.0,plan.remaining-fraction);
      if(stage>=0)
        {
         plan.exitPrice[stage]=(plan.exitPrice[stage]*plan.closed[stage]+price*fraction)/(plan.closed[stage]+fraction);
         plan.closed[stage]+=fraction;
         plan.exitTime[stage]=time;
         // Only the normal, entry-time TP allocation is subject to this gate.
         // Structure exits can redistribute fractions and LB extensions have
         // their own stop rules; preserve their existing later-TP behaviour.
         bool otherScenario=!normalTarget || plan.extensionCount>0 ||
                            plan.structureClosed[0]>0 || plan.structureClosed[1]>0 ||
                            plan.sequence.closed[0]>0 || plan.sequence.closed[1]>0;
         // Until another scenario intervenes, fractions are the frozen entry
         // allocations: 50/25/25 or 75/25. The exception is two fully closed
         // quarter targets: together they protect the remaining half at BE.
         // A touch or an incomplete broker execution does not complete a stage.
         int completedQuarters=0;
         for(int i=0;i<plan.count;i++)
            if(MathAbs(plan.fraction[i]-0.25)<1e-9 &&
               plan.closed[i]+1e-9>=plan.fraction[i]) completedQuarters++;
         if(otherScenario || completedQuarters>=2 || (plan.fraction[stage]>=0.5 &&
                              plan.closed[stage]+1e-9>=plan.fraction[stage]))
            plan.breakeven=true;
        }
      return reward;
     }

   // A share of currently open volume; neither side may violate the broker lot grid.
   static double PartialLots(double remainingLots, double share, double step, double minimum)
     {
      if(step<=0 || minimum<=0 || share<=0 || share>=1 || remainingLots<=0) return 0;
      double lots=NormalizeDouble(MathFloor(remainingLots*share/step+1e-8)*step,8);
      return lots+1e-9>=minimum && remainingLots-lots+1e-9>=minimum ? lots : 0.0;
     }

   static double HalfLots(double remainingLots, double step, double minimum)
     { return PartialLots(remainingLots,0.5,step,minimum); }

   static void StructureExit(SMarcoTPPlan &plan, bool full, double fraction, double price,
                             datetime time, double originalLots, double step, double minimum,
                             bool moveToBreakeven=true)
     {
      double before=plan.remaining;
      fraction=MathMin(fraction,before);
      if(fraction<=1e-9) return;
      int index=full ? 1 : 0;
      double prior=plan.structureClosed[index];
      plan.structurePrice[index]=(plan.structurePrice[index]*prior+price*fraction)/(prior+fraction);
      plan.structureClosed[index]+=fraction; plan.structureTime[index]=time;
      Exit(plan,-1,fraction,price,time);
      if(!full && moveToBreakeven) plan.breakeven=true;
      // Reduce outstanding allocations proportionally, respecting broker volume steps.
      // Any indivisible residue stays at the farthest still-outstanding target.
      int last=-1; double allocated=0;
      for(int i=0;i<plan.count;i++)
        {
         double pending=plan.fraction[i]-plan.closed[i];
         if(pending<=1e-9) continue;
         if(last<0 || plan.direction*(plan.price[i]-plan.price[last])>0) last=i;
         double lots=NormalizeDouble(MathFloor(pending*plan.remaining/before*originalLots/step+1e-8)*step,8);
         if(lots+1e-9<minimum) lots=0;
         plan.fraction[i]=plan.closed[i]+lots/originalLots;
         allocated+=lots/originalLots;
        }
      if(last>=0) plan.fraction[last]+=MathMax(0.0,plan.remaining-allocated);
     }

   static void SequenceFill(SMarcoTPPlan &plan, double lots, double price, datetime time,
                            double originalLots, double step, double minimum)
     {
      int index=plan.sequence.step-1;
      if(index<0 || index>1 || lots<=0 || originalLots<=0) return;
      double fraction=MathMin(lots/originalLots,plan.remaining);
      if(fraction<=1e-9) return;
      double prior=plan.sequence.closed[index];
      plan.sequence.price[index]=(plan.sequence.price[index]*prior+price*fraction)/(prior+fraction);
      plan.sequence.closed[index]+=fraction; plan.sequence.time[index]=time;
      // Reuse allocation accounting without labelling these fills as legacy CHoCH exits.
      double oldClosed[2],oldPrice[2]; datetime oldTime[2];
      for(int i=0;i<2;i++) { oldClosed[i]=plan.structureClosed[i]; oldPrice[i]=plan.structurePrice[i]; oldTime[i]=plan.structureTime[i]; }
      StructureExit(plan,plan.sequence.share>=1,fraction,price,time,originalLots,step,minimum,
                    plan.direction*(price-plan.entry)>0);
      for(int i=0;i<2;i++) { plan.structureClosed[i]=oldClosed[i]; plan.structurePrice[i]=oldPrice[i]; plan.structureTime[i]=oldTime[i]; }
      plan.sequence.requestedLots=MathMax(0.0,plan.sequence.requestedLots-lots);
      if(plan.remaining<=1e-9 || plan.sequence.requestedLots<step*0.1)
        { plan.sequence.pending=false; plan.sequence.requestedLots=0; }
     }

   // OHLC fallback: bullish candle O-L-H-C; bearish candle O-H-L-C.
   // This is a deterministic simulation assumption, not reconstructed tick history.
   static void Bar(SMarcoTPPlan &plan, datetime time, double open, double high, double low, double close,
                   bool vicinity, double distance, bool rejection, datetime rejectionStart,
                   double &lastExit)
     {
      double path[4]; path[0]=open; path[1]=close>=open ? low : high;
      path[2]=close>=open ? high : low; path[3]=close;
      double stop=Stop(plan);
      if(plan.direction*(open-stop)<=0)
        { Exit(plan,-1,plan.remaining,open,time); lastExit=open; return; }
      for(int leg=0; leg<4 && plan.remaining>1e-9; leg++)
        {
         double end=path[leg];
         stop=Stop(plan);
         if(plan.direction*(end-stop)<=0)
           { Exit(plan,-1,plan.remaining,stop,time); lastExit=stop; return; }
         int stage=Next(plan);
         while(stage>=0 && plan.direction*(end-plan.price[stage])>=0)
           {
            double fill=leg==0 ? open : plan.price[stage];
            Exit(plan,stage,plan.fraction[stage]-plan.closed[stage],fill,time);
            lastExit=fill;
            stage=Next(plan);
           }
         if(vicinity && stage>=0 && plan.vicinityTime[stage]==0 &&
            plan.direction*(end-plan.price[stage])>=-distance) plan.vicinityTime[stage]=time;
        }
      if(vicinity && rejection && plan.direction*(close-plan.entry)>0)
         for(int i=0; i<plan.count; i++)
            if(plan.vicinityTime[i]>0 &&
               plan.closed[i]+1e-9<plan.fraction[i])
              {
               Exit(plan,i,plan.fraction[i]-plan.closed[i],close,time,false);
               lastExit=close;
              }
     }
  };
#endif
