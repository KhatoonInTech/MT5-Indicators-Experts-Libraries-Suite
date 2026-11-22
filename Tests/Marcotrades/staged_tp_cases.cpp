int checks=0;
void eq(double a,double b){checks++;if(std::abs(a-b)>1e-7){std::cerr<<"Expected "<<b<<" got "<<a<<"\n";std::abort();}}
SMarcoTPPlan plan(bool buy=true,double lb=120,double ind=130,int priority=0,double rr=1){
 SMarcoTPPlan p;assert(CMarcoStagedTP::Build(p,buy,100,buy?90:110,lb,ind,rr,priority,0,0.01,2));return p;
}
void bar(SMarcoTPPlan&p,double o,double h,double l,double c,bool vicinity=false,bool rejection=false){
 double last=0;CMarcoStagedTP::Bar(p,1000,o,h,l,c,vicinity,1,rejection,900,last);
}
void reset(){files.clear();handles.clear();volume=4;sl=90;tp=130;bid=ask=100;sends=mode=0;modifyAllowed=enabled=true;clockNow=1000;}
void save(const SMarcoTPPlan&p){SMarcoLiveTPState s{};s.plan=p;s.lots=4;s.riskCash=40;s.pendingStage=-1;assert(CMarcoLiveStagedTP::Save(magic,identifier,s));}
SMarcoLiveTPState load(){SMarcoLiveTPState s;assert(CMarcoLiveStagedTP::Load(magic,identifier,s));return s;}
bool manage(CTrade&t){return CMarcoLiveStagedTP::Manage(t,magic,identifier,"TEST",false,1,1);}
int main(){
 // New sequence primitives: quarter sizing respects the broker grid and can
 // account for a losing partial without silently enabling a breakeven stop.
 eq(CMarcoStagedTP::PartialLots(.08,.25,.01,.01),.02);
 eq(CMarcoStagedTP::PartialLots(.06,.25,.01,.01),.01);
 eq(CMarcoStagedTP::PartialLots(.03,.25,.01,.01),0);
 eq(CMarcoStagedTP::PartialLots(.08,.5,.01,.01),.04);
 eq(CMarcoStagedTP::PartialLots(.08,1,.01,.01),0);
 for(bool buy:{false,true}){
   auto q=plan(buy,buy?120:80,buy?130:70);
   CMarcoStagedTP::StructureExit(q,false,.25,buy?98:102,1000,4,.01,.01,false);
   eq(q.remaining,.75);eq(q.realizedR,-.05);assert(!q.breakeven);
   eq(CMarcoStagedTP::Stop(q),buy?90:110);
   double pending=0;for(int k=0;k<q.count;k++)pending+=q.fraction[k]-q.closed[k];
   eq(pending,q.remaining);
 }
 // Every direction, priority, and combination of structural availability.
 for(int buy=0;buy<2;buy++)for(int priority=0;priority<3;priority++)for(int mask=0;mask<4;mask++){
   double d=buy?1:-1;auto p=plan(buy,mask&1?100+d*20:0,mask&2?100+d*30:0,priority);
   eq(p.count,mask==3?3:2);double sum=0;
   for(int i=0;i<p.count;i++){
     double expected=mask==3?(p.kind[i]==priority?.5:.25):mask==0?(p.kind[i]==2?.75:.25):
       (priority==2?(p.kind[i]==2?.75:.25):(p.kind[i]<2?.75:.25));
     eq(p.fraction[i],expected);sum+=p.fraction[i];
   }eq(sum,1);
   double expectedR=0;int quarters=0;
   while(CMarcoStagedTP::Next(p)>=0){int i=CMarcoStagedTP::Next(p);expectedR+=p.fraction[i]*d*(p.price[i]-100)/10;
      CMarcoStagedTP::Exit(p,i,p.fraction[i],p.price[i],1000);int major=CMarcoStagedTP::Primary(p);if(p.fraction[i]==.25)quarters++;assert(p.breakeven==(quarters>=2 || p.closed[major]+1e-9>=p.fraction[major]));}
   eq(p.remaining,0);eq(p.realizedR,expectedR);
 }
 // Early 25% fallback must retain the initial stop until the selected major TP fills.
 // Exercise all target orders, priorities, missing-zone combinations and both
 // directions. Two completed early quarters arm BE; one quarter never does.
 for(bool buy:{false,true})for(int priority=0;priority<3;priority++)for(int mask=0;mask<4;mask++){
  int order[3]={0,1,2};
  do{
   double distance[3];for(int n=0;n<3;n++)distance[order[n]]=10.0*(n+1);
   int d=buy?1:-1;
   auto q=plan(buy,mask&1?100+d*distance[0]:0,mask&2?100+d*distance[1]:0,priority,distance[2]/10);
   int major=CMarcoStagedTP::Primary(q);bool majorFilled=false;int quarters=0;
   while(CMarcoStagedTP::Next(q)>=0){
    int stage=CMarcoStagedTP::Next(q);double allocation=q.fraction[stage];
    CMarcoStagedTP::Exit(q,stage,allocation/2,q.price[stage],1000);
    assert(q.breakeven==(majorFilled || quarters>=2)); // A partial broker fill is not completion.
    eq(CMarcoStagedTP::Stop(q),(majorFilled || quarters>=2)?100:100-d*10);
    CMarcoStagedTP::Exit(q,stage,allocation/2,q.price[stage],1001);
    if(stage==major)majorFilled=true;else if(allocation==.25)quarters++;
    assert(q.breakeven==(majorFilled || quarters>=2));
    eq(CMarcoStagedTP::Stop(q),(majorFilled || quarters>=2)?100:100-d*10);
   }
   eq(q.remaining,0);
  }while(std::next_permutation(order,order+3));
 }
 auto p=plan();bar(p,100,111,99,110);eq(p.remaining,.75);eq(p.realizedR,.25);assert(!p.breakeven);
 bar(p,109,109,98,99);eq(p.remaining,.75);eq(CMarcoStagedTP::Stop(p),90);
 bar(p,99,99,89,90);eq(p.remaining,0);eq(p.realizedR,-.5);
 // Mirrored sell case.
 p=plan(false,80,70);bar(p,100,101,89,90);eq(p.remaining,.75);eq(p.realizedR,.25);
 bar(p,91,102,91,101);eq(p.remaining,.75);eq(CMarcoStagedTP::Stop(p),110);
 bar(p,101,111,101,110);eq(p.remaining,0);eq(p.realizedR,-.5);
 // All three are reached in one continuous favorable leg: 25/50/25, weighted 2R.
 p=plan();bar(p,100,131,99,130);eq(p.remaining,0);eq(p.realizedR,2);
 // Fallback-only policy is R plus one, NOT R times two (R=2 => 2R and 3R).
 p=plan(true,0,0,2,2);eq(p.price[0],120);eq(p.price[1],130);
 bar(p,100,121,99,120);eq(p.remaining,.25);eq(p.realizedR,1.5);
 bar(p,121,131,120,130);eq(p.remaining,0);eq(p.realizedR,2.25);
 // Initial SL, adverse gap, favorable gap, equal targets.
 p=plan();bar(p,100,105,89,92);eq(p.realizedR,-1);eq(p.remaining,0);
 p=plan();bar(p,85,95,80,90);eq(p.realizedR,-1.5);
 p=plan();bar(p,135,140,134,139);eq(p.realizedR,3.5);eq(p.remaining,0);
 p=plan(true,110,110);bar(p,100,111,99,110);eq(p.remaining,0);eq(p.realizedR,1);
 // Rejection near nearest TP closes only its allocation; next bar hits BE.
 p=plan();bar(p,109,109.5,108,108.5,true,true);eq(p.remaining,.75);eq(p.realizedR,.2125);
 bar(p,108,109,99,100);eq(p.realizedR,.2125);eq(p.remaining,0);
 // Valid lot splitting never increases risk and each quarter fits broker limits.
 for(int n=1;n<10000;n++){double cap=n*.001;double v=CMarcoStagedTP::Lots(cap,.01,.01);assert(v<=cap+1e-9);if(v>0){eq(v/.04,std::round(v/.04));assert(v/4>=.01-1e-9);}}
 eq(CMarcoStagedTP::Lots(.03,.01,.01),0);eq(CMarcoStagedTP::Lots(.19,.01,.01),.16);
 SMarcoTPPlan invalid;assert(!CMarcoStagedTP::Build(invalid,true,100,90,101,0,1,0,2,.01,2));
 assert(!CMarcoStagedTP::Build(invalid,true,100,90,0,0,0,0,0,.01,2));
 // Filled entry adjusts RR distances, without changing structural targets/allocations.
 p=plan();CMarcoStagedTP::RebaseFill(p,101,1,0,.01,2);
 eq(p.entry,101);eq(p.price[0],120);eq(p.price[1],130);eq(p.price[2],112);
 p=plan(false,80,70);CMarcoStagedTP::RebaseFill(p,99,1,0,.01,2);
 eq(p.price[0],80);eq(p.price[1],70);eq(p.price[2],88);
 // Production persistence roundtrip (64-bit IDs), partial fills, restart and duplicate prevention.
 reset();save(plan());auto state=load();eq(state.lots,4);eq(state.plan.price[1],130);
 CTrade trade;bid=ask=110;assert(manage(trade));eq(volume,3);eq(sl,90);eq(sends,1);
 assert(!manage(trade));eq(sends,1); // State reloaded from disk on every call.
 bid=ask=120;assert(manage(trade));eq(volume,1);eq(sl,100);eq(sends,2);
 bid=ask=130;assert(manage(trade));eq(volume,0);eq(sends,3);
 reset();sl=110;tp=70;save(plan(false,80,70));bid=ask=90;
 assert(manage(trade));eq(volume,3);eq(sl,110);eq(sends,1);
 bid=ask=80;assert(manage(trade));eq(volume,1);eq(sl,100);
 bid=ask=70;assert(manage(trade));eq(volume,0);
 reset();p=plan();CMarcoStagedTP::RebaseFill(p,100.005,1,0,.01,2);save(p);bid=ask=111;
 manage(trade);eq(sl,90);bid=ask=120;manage(trade);eq(sl,100.01);
 // Rejected close retains allocation and retries only after cooldown.
 reset();save(plan());bid=ask=110;mode=1;assert(!manage(trade));eq(load().plan.remaining,1);
 manage(trade);eq(sends,1);clockNow+=6;mode=0;assert(manage(trade));eq(volume,3);
 // Ambiguous timeout: never resend while unresolved, including after restart.
 reset();save(plan());bid=ask=110;mode=2;manage(trade);eq(sends,1);clockNow+=100;
 manage(trade);eq(sends,1);eq(load().pendingStage,2);
 volume-=pending.volume;mode=0;assert(manage(trade));eq(volume,3);eq(sends,1);eq(sl,90);
 // A frozen server SL gets a market fallback if price reaches BE before modify succeeds.
 reset();save(plan());modifyAllowed=false;bid=ask=120;manage(trade);eq(sl,90);assert(load().plan.breakeven);
 bid=ask=99;assert(manage(trade));eq(volume,0);
 // Terminal trade permissions prevent sends; corrupt state never triggers a trade.
 // Both quarters precede the priority LB. Persist/reload after each fill and
 // wait for the second quarter to finish, including a partial broker execution.
 for(bool buy:{false,true}){
  reset();int d=buy?1:-1;sl=100-d*10;
  save(plan(buy,100+d*30,100+d*20,0));
  bid=ask=100+d*10;manage(trade);eq(volume,3);eq(sl,100-d*10);
  bid=ask=100+d*20;mode=2;manage(trade);eq(load().pendingStage,1);
  volume-=.5;mode=0;bid=ask=100+d*19;manage(trade);
  eq(volume,2.5);eq(sl,100-d*10);assert(!load().plan.breakeven);
  bid=ask=100+d*20;manage(trade);
  eq(volume,2);eq(sl,100);eq(load().plan.closed[0],0);
  eq(load().plan.closed[1],.25);eq(load().plan.closed[2],.25);
 }
 // Major-stage timeout/restart with only half of its allocation filled: wait
 // for the remaining major volume before enabling BE, and never resend twice.
 reset();save(plan());bid=ask=110;manage(trade);eq(sl,90);
 bid=ask=120;mode=2;manage(trade);eq(load().pendingStage,0);
 volume-=1;mode=0;bid=ask=119;manage(trade);
 eq(load().plan.closed[0],.25);eq(sl,90);assert(!load().plan.breakeven);
 bid=ask=120;manage(trade);eq(load().plan.closed[0],.5);eq(sl,100);eq(volume,1);
 // Vicinity protection retains its existing BE rule, including an uncertain
 // broker close that completes after the manager reloads its persisted state.
 reset();save(plan());state=load();state.plan.vicinityTime[2]=900;
 CMarcoLiveStagedTP::Save(magic,identifier,state);bid=ask=109.5;mode=2;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",true,1,1);
 eq(load().pendingStage,9);eq(sl,90);eq(sends,1);
 volume-=pending.volume;mode=0;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",true,1,1);
 eq(sl,100);eq(volume,3);eq(sends,1);
 // A loss-side opposing partial changes allocations: subsequent TP behaviour
 // remains the old rule, rather than applying the normal-entry 50/75% gate.
 reset();p=plan();CMarcoStagedTP::StructureExit(p,false,.5,98,1000,4,.01,.01,false);
 assert(!p.breakeven);CMarcoStagedTP::Exit(p,2,p.fraction[2],110,1001);assert(p.breakeven);
 // Existing v4 state upgrades without restoring an already tightened stop.
 reset();p=plan();p.breakeven=true;save(p);
 auto &v4=files[CMarcoLiveStagedTP::Path(magic,identifier)];v4.resize(436);int32_t v4version=4;
 std::memcpy(v4.data(),&v4version,4);assert(load().plan.breakeven);
 reset();save(plan());enabled=false;bid=ask=140;manage(trade);eq(sends,0);
 enabled=true;files[CMarcoLiveStagedTP::Path(magic,identifier)].resize(10);manage(trade);eq(sends,0);
 // Structural partial uses remaining volume, once, with valid later TP allocations.
 reset();save(plan());bid=ask=110;manage(trade);eq(volume,3);
 bid=ask=111;assert(CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,1));
 eq(volume,1.5);state=load();eq(state.plan.structureClosed[0],.375);eq(sl,100);
 eq(state.plan.fraction[0]-state.plan.closed[0],.25);
 eq(state.plan.fraction[1]-state.plan.closed[1],.125);
 int priorSends=sends;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,1);eq(sends,priorSends);
 bid=ask=120;manage(trade);eq(volume,.5);bid=ask=130;manage(trade);eq(volume,0);
 // SL-side full close overrides targets and also works after the half exit.
 reset();save(plan());bid=ask=95;
 assert(CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,2));
 eq(volume,0);eq(load().plan.realizedR,-.5);eq(load().plan.structureClosed[1],1);
 reset();save(plan(false,80,70));sl=110;bid=ask=105;
 assert(CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,2));eq(volume,0);eq(load().plan.realizedR,-.5);
 reset();save(plan());bid=ask=105;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,1);eq(volume,2);
 bid=ask=99;CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,2);eq(volume,0);
 eq(load().plan.structureClosed[1],.5);
 // Rejected request retains full-close intent even when the source signal disappears.
 reset();save(plan());bid=ask=95;mode=1;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,2);eq(volume,4);eq(load().structureAction,2);
 mode=0;clockNow+=6;manage(trade);eq(volume,0);
 // Timeout survives reload: no duplicate half request; reconcile actual reduction once.
 reset();save(plan());bid=ask=105;mode=2;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,1);eq(sends,1);
 clockNow+=10;manage(trade);eq(sends,1);eq(load().pendingStage,3);
 volume-=pending.volume;mode=0;manage(trade);eq(volume,2);eq(sends,1);eq(sl,100);eq(load().plan.structureClosed[0],.5);
 // Full close upgrades an already pending partial without sending a duplicate.
 reset();save(plan());bid=ask=105;mode=2;
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,1);
 CMarcoLiveStagedTP::Manage(trade,magic,identifier,"TEST",false,1,1,2);eq(sends,1);eq(load().structureAction,2);
 volume-=pending.volume;mode=0;manage(trade);eq(volume,0);eq(sends,2);
 // Quantization: half .06 is .03; half .03 rounds down to .01, never increases risk.
 eq(CMarcoStagedTP::HalfLots(.06,.01,.01),.03);eq(CMarcoStagedTP::HalfLots(.03,.01,.01),.01);
 eq(CMarcoStagedTP::HalfLots(.01,.01,.01),0);
 for(int lots=4;lots<100;lots++)for(int priority=0;priority<3;priority++){
   p=plan(true,120,130,priority);double original=lots*.01;
   double half=CMarcoStagedTP::HalfLots(original,.01,.01);
   CMarcoStagedTP::StructureExit(p,false,half/original,105,1000,original,.01,.01);
   double allocated=0;
   for(int i=0;i<p.count;i++){double targetLots=(p.fraction[i]-p.closed[i])*original;
     eq(targetLots/.01,std::round(targetLots/.01));allocated+=targetLots;}
   eq(allocated,original-half);bar(p,105,140,104,140);eq(p.remaining,0);
 }
 // Extensions preserve original risk and clear only the moved target's vicinity.
 for(bool buy:{false,true}){
  int d=buy?1:-1;p=plan(buy,100+d*20,100+d*30);
  p.vicinityTime[0]=111;p.vicinityTime[1]=222;
  assert(CMarcoStagedTP::Extend(p,1,1,.01,2,500));eq(p.price[1],100+d*40);
  eq(p.price[0],100+d*20);eq(p.fraction[1],.25);eq(p.vicinityTime[1],0);eq(p.vicinityTime[0],111);
  CMarcoStagedTP::TightenStop(p,100+d*5);eq(CMarcoStagedTP::Stop(p),100+d*5);
  assert(CMarcoStagedTP::Extend(p,1,2,.01,2,600));eq(p.price[1],100+d*60);eq(p.initialSL,100-d*10);
  CMarcoStagedTP::TightenStop(p,100-d*3);eq(CMarcoStagedTP::Stop(p),100+d*5);
  CMarcoStagedTP::TightenStop(p,100+d*2);eq(CMarcoStagedTP::Stop(p),100+d*5);
  if(buy)bar(p,108,109,104,106);else bar(p,92,96,91,94);
  eq(p.remaining,0);eq(p.realizedR,.5);
 }
 // Extension and deduplication ledger survive reload; only TP changes below 75%.
 reset();save(plan());state=load();state.extension.seen="|1:LB_BULL_150||3:LB_BULL_160|";
 CMarcoStagedTP::Extend(state.plan,1,1,.01,2,1100);
 assert(CMarcoLiveStagedTP::Save(magic,identifier,state));state=load();
 eq(state.plan.extensionCount,1);eq(state.plan.extensionTime,1100);assert(state.extension.seen=="|1:LB_BULL_150||3:LB_BULL_160|");
 bid=ask=105;manage(trade);eq(tp,140);eq(sl,90);eq(sends,0);
 // A rejected SL must not block TP extension; protection retries later.
 state=load();CMarcoStagedTP::TightenStop(state.plan,103);
 CMarcoStagedTP::Extend(state.plan,1,1,.01,2,1200);assert(CMarcoLiveStagedTP::Save(magic,identifier,state));
 rejectSLOnly=true;manage(trade);eq(tp,150);eq(sl,90);
 rejectSLOnly=false;manage(trade);eq(sl,103);eq(load().plan.protectedSL,103);
 sl=104;manage(trade);eq(sl,104);
 // Market fallback protects a stop the broker has not accepted yet.
 reset();p=plan();CMarcoStagedTP::TightenStop(p,103);save(p);modifyAllowed=false;
 bid=ask=102;manage(trade);eq(volume,0);
 // v2 states migrate without invented extension events.
 reset();save(plan());auto &v2=files[CMarcoLiveStagedTP::Path(magic,identifier)];v2.resize(308);
 int32_t v2version=2;std::memcpy(v2.data(),&v2version,4);state=load();
 eq(state.plan.extensionCount,0);eq(state.plan.protectedSL,0);assert(state.extension.seen.empty());
 // A v1 state remains readable and upgrades on the next save.
 reset();save(plan());auto &old=files[CMarcoLiveStagedTP::Path(magic,identifier)];old.resize(256);
 int32_t version=1;std::memcpy(old.data(),&version,4);state=load();eq(state.structureAction,0);eq(state.plan.structureClosed[0],0);
 assert(CMarcoLiveStagedTP::Save(magic,identifier,state));eq(files[CMarcoLiveStagedTP::Path(magic,identifier)].size(),448);
 std::cout<<"PASS: "<<checks<<" assertions; staged TP, structural exits, half-remaining sizing, durable broker retries and v1 migration\n";
}
