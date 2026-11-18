"""Offline checks for trigger-specific, entry-only LB gates."""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
adapter=ROOT/'Tests/Marcotrades/replay_us30_context.py'
env={'__file__':str(adapter)}
exec(compile(adapter.read_text().split("main = r'''",1)[0],str(adapter),'exec'),env)

shared=(ROOT/'Include/Custom/Marcotrades/liquidity_blocks.mqh').read_text(encoding='utf-8-sig')
back=(ROOT/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
live=(ROOT/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
def method(text,name):
    start=re.search(r'^\s*(?:void|bool|double|datetime)\s+'+name+r'\(',text,re.M).start()
    opening=text.index('{',start);end=opening+1;depth=1
    while depth:
        depth+=(text[end]=='{')-(text[end]=='}');end+=1
    return text[start:end]

# Scope guard: registration remains raw. Prevention and position management
# switch between raw and entry-qualified LB histories through the new input.
assert 'EntryTriggerStructureTime' not in method(shared,'RegisterLiquidityBlock')
for source in (back,live):
    capture=method(source,'CaptureRejectionContext')
    assert 'm_applyEntryPolicyToPreventionExits' in capture
    assert 'entryTriggerTime>0' in capture
    assert 'm_exit_sources' in capture
    assert 'GuardSourceReady(source,inducements,ms,' in capture
    assert 'GuardSourceReady(source,ind,ms,barTime,available,applyEntryPolicyToPreventionExits)' in source
    assert 'entryTriggerTime' not in method(source,'ExtendFromNewLB')
    assert 'EntryPolicyReady(lb,barTime,available)' in source
    opposing=method(source,'FindOpposingOrigin')
    assert 'applyEntryPolicyToPreventionExits' in opposing
    assert 'entryPolicyTimes[policy]' in opposing
    assert source.count('entryTriggerTime') >= 10
assert 'entryTriggerTime' not in method(back,'ApplyStructureExits')
assert 'entryTriggerTime <= 0' in method(back,'FeedM1EntryBar')
assert 'entryTriggerTime <= 0' in method(live,'FeedM1EntryBar')

main=r'''
int checks=0;
void checked(bool ok,int line){++checks;if(!ok){std::cerr<<"failure at "<<line<<" check "<<checks<<"\n";std::exit(1);}}
#define check(x) checked((x),__LINE__)
void event(CMarketStructure&ms,datetime t,string name){ms.all_event_times.Add(t);ms.all_event_names.Add(name);}
void sweep(CMarketStructure&ms,bool bull,datetime at,datetime confirmed){
 if(bull)ms.RegisterBSLSweep(at,at-10,at,confirmed);
 else ms.RegisterSSLSweep(at,at-10,at,confirmed);
}
CInducementZone* ind(CInducementLogic&logic,bool bull,datetime mitigation,bool valid=true){
 auto z=new CInducementZone();z->isBullish=bull;z->createdTime=10;z->qualifiedTime=50;
 z->isInducement=valid;z->structureRejected=false;z->isMitigated=true;z->mitigationTime=mitigation;
 logic.m_zones.Add(z);return z;
}
int main(){
 for(bool bull:{false,true}){
  string one=bull?"BL-CHoCH":"BR-CHoCH",two=bull?"BL-BOS":"BR-BOS";
  string sameSweep=bull?"BSL-Swept":"SSL-Swept";
  string oppositeSweep=bull?"SSL-Swept":"BSL-Swept";
  string opposite=bull?"BR-BOS":"BL-BOS";
  ENUM_LB_TRIGGER indTrigger=bull?LB_TRIGGER_BL_IND:LB_TRIGGER_BR_IND;
  ENUM_LB_TRIGGER sweepTrigger=bull?LB_TRIGGER_BL_BSL:LB_TRIGGER_BR_SSL;
  ENUM_LB_TRIGGER combinedTrigger=bull?LB_TRIGGER_BL_IND_BSL:LB_TRIGGER_BR_IND_SSL;
  CLiquidityBlockLogic lbs;CInducementLogic zones;CMarketStructure ms;
  ind(zones,bull,100);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&ms,500)==0);
  event(ms,150,one);check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&ms,500)==0);
  event(ms,200,two);check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&ms,500)==200);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&ms,175)==0); // No future event.

  // An IND-overlap veto cannot erase a structurally qualified guard source.
  // Reported M2 BUY/M1 bearish chain, plus the bullish mirror.
  lbs.RecordExitSource(bull,indTrigger,120,110,120,0,150,150);
  auto guard=(CLiquidityBlock*)lbs.m_exit_sources.At(0);
  check(guard!=NULL && lbs.m_liquidity_blocks.Total()==0);
  check(!lbs.GuardSourceReady(guard,&zones,&ms,150,210,true));
  check(guard->guardQualifiedTime==0);
  check(lbs.GuardSourceReady(guard,&zones,&ms,200,260,true));
  check(guard->guardQualifiedTime==260);
  check(!lbs.GuardSourceReady(guard,&zones,&ms,150,210,true));
  CTradeRejectionHistory history;
  history.Observe(one,150,210,120,115);
  history.Observe(two,200,260,180,105); // Continuation originates outside the LB.
  history.BeginZones();
  history.Zone(guard->id,bull,110,120,120,0,150,260,true);
  history.EndZones(260);
  check(history.OpposingChoch(!bull,280,290,295,300,1,0).action==TRADE_RETIRE_ZONE);
  history.Observe(opposite,275,335,270,105);
  check(history.OpposingChoch(!bull,280,340,345,350,1,0).action==TRADE_ALLOW);
  check(lbs.m_liquidity_blocks.Total()==0); // Guard never becomes an entry setup.
  CInducementLogic newer;ind(newer,bull,300);
  check(lbs.GuardSourceReady(guard,&newer,&ms,300,360,true)); // Keep readiness latched.
  CLiquidityBlock invalidGuard;invalidGuard.isBullish=bull;invalidGuard.triggerType=indTrigger;
  CInducementLogic noInd;
  check(!lbs.GuardSourceReady(&invalidGuard,&noInd,&ms,200,260,true));
  check(lbs.GuardSourceReady(&invalidGuard,&noInd,&ms,200,260,false));
  check(invalidGuard.guardQualifiedTime==0);

  CMarketStructure broken;event(broken,150,one);event(broken,175,opposite);event(broken,200,two);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&broken,500)==0);
  event(broken,250,one);check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&broken,500)==250);

  // Same-side sweeps count as bullish/bearish structures for an IND trigger.
  CMarketStructure swept;event(swept,150,one);event(swept,175,sameSweep);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&swept,500)==175);
  swept.UpdateHistoricalEventName(150,oppositeSweep);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&swept,500)==0);

  CMarketStructure duplicate;event(duplicate,150,one);event(duplicate,150,two);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&duplicate,500)==0);
  event(duplicate,200,two);check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&zones,&duplicate,500)==200);

  CInducementLogic invalid;
  auto a=ind(invalid,bull,100,false);event(ms,250,one);event(ms,300,two);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&invalid,&ms,500)==0);
  a->isInducement=true;a->structureRejected=true;
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&invalid,&ms,500)==0);
  a->structureRejected=false;a->isMitigated=false;
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&invalid,&ms,500)==0);
  a->isMitigated=true;a->qualifiedTime=600;
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&invalid,&ms,500)==0);

  // A newer same-side mitigation starts a fresh entry sequence.
  CInducementLogic latest;ind(latest,bull,100);ind(latest,bull,225);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&latest,&ms,500)==300);
  CMarketStructure stale;event(stale,150,one);event(stale,200,two);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&latest,&stale,500)==0);

  // Opposite-side IND cannot arm this entry direction.
  CInducementLogic wrong;ind(wrong,!bull,100);
  check(lbs.EntryTriggerStructureTime(bull,indTrigger,0,&wrong,&ms,500)==0);

  // The CHoCH that recognizes the sweep cannot also count as its follow-up.
  CMarketStructure sweepOk;event(sweepOk,100,sameSweep);event(sweepOk,150,one);sweep(sweepOk,bull,100,150);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepOk,150)==0);
  check(lbs.EntryTriggerStructureTime(bull,combinedTrigger,100,NULL,&sweepOk,150)==0);
  event(sweepOk,200,two);
  CLiquidityBlock sweepGuard;sweepGuard.isBullish=bull;sweepGuard.triggerType=sweepTrigger;sweepGuard.sweepLineTime=100;
  check(!lbs.GuardSourceReady(&sweepGuard,NULL,&sweepOk,150,210,true));
  check(lbs.GuardSourceReady(&sweepGuard,NULL,&sweepOk,200,260,true));
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepOk,199)==0);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepOk,200)==200);
  check(lbs.EntryTriggerStructureTime(bull,combinedTrigger,100,NULL,&sweepOk,200)==200);

  CMarketStructure sweepBad;event(sweepBad,100,sameSweep);event(sweepBad,150,one);sweep(sweepBad,bull,100,150);
  event(sweepBad,200,opposite);event(sweepBad,250,one);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepBad,500)==0);

  CMarketStructure sweepMissing;event(sweepMissing,100,oppositeSweep);event(sweepMissing,150,one);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepMissing,500)==0);

  CMarketStructure sweepCounts;event(sweepCounts,100,sameSweep);event(sweepCounts,150,one);sweep(sweepCounts,bull,100,150);
  event(sweepCounts,200,sameSweep);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&sweepCounts,500)==200);

  // A displayed sweep label alone is not a confirmed registry link.
  CMarketStructure unregistered;event(unregistered,100,sameSweep);event(unregistered,150,one);event(unregistered,200,two);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&unregistered,500)==0);
  sweep(unregistered,bull,100,600);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&unregistered,500)==0);

  // Run the actual renaming rules: bullish, bearish, bullish CHoCH -> provisional BSL.
  // Reversal at the next event undoes that BSL; it must never arm the bullish LB.
  CMarketStructure renamed;renamed.Init(false,false,1);
  renamed.AddEvent(50,two,40,50,100);renamed.ProcessRenamingRules();
  renamed.AddEvent(100,bull?"BR-CHoCH":"BL-CHoCH",90,100,100);renamed.ProcessRenamingRules();
  renamed.AddEvent(150,one,140,150,100);renamed.ProcessRenamingRules();
  check(renamed.GetSweepConfirmingChochTime(100,!bull)==150);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&renamed,150)==0);
  renamed.AddEvent(200,bull?"BR-CHoCH":"BL-CHoCH",190,200,100);renamed.ProcessRenamingRules();
  check(renamed.GetSweepConfirmingChochTime(100,!bull)==0);
  check(lbs.EntryTriggerStructureTime(bull,sweepTrigger,100,NULL,&renamed,200)==0);

  // Production M1 policy plus production full-exit evaluation, in both directions.
  for(bool strict:{false,true}){
   CMarcoM1LBContext ctx;
   ctx.Init(true,true,2,1,true,true,5,false,true,true,true,false,false,.001,strict);
   ctx.ms->AddEvent(50,two,40,50,100);ctx.ms->ProcessRenamingRules();
   ctx.ms->AddEvent(100,bull?"BR-CHoCH":"BL-CHoCH",90,100,100);ctx.ms->ProcessRenamingRules();
   ctx.ms->AddEvent(150,one,140,150,100);ctx.ms->ProcessRenamingRules();
   auto lb=new CLiquidityBlock();lb->id="sweep-exit";lb->isBullish=bull;lb->triggerType=sweepTrigger;
   lb->createdTime=120;lb->sweepLineTime=100;lb->causalChochTime=150;
   lb->zoneLow=bull?101:98;lb->zoneHigh=bull?102:99;
   ctx.lbs->m_liquidity_blocks.Add(lb);
   SMarcoTPPlan plan{};plan.direction=bull?-1:1;plan.entry=100;plan.initialSL=bull?110:90;plan.remaining=1;
   ctx.rejectionHistory.Observe(one,150,160,120,bull?101:99,bull?103:97);
   auto capture=[&](datetime cutoff,datetime available){
    ctx.rejectionHistory.BeginZones();
    if(ctx.EntryPolicyReady(lb,cutoff,available))
     ctx.rejectionHistory.Zone(lb->id,bull,lb->zoneLow,lb->zoneHigh,120,0,150,available);
    ctx.rejectionHistory.EndZones(available);
   };
   capture(150,160);
   check(CMarcoStructureExit::Evaluate(ctx.rejectionHistory,plan,140,160,1).action==(strict?0:2));
   check(ctx.EntryPolicyReady(lb,150,160)==!strict);
   ctx.ms->AddEvent(200,two,190,200,100);ctx.ms->ProcessRenamingRules();
   capture(200,210);
   check(ctx.EntryPolicyReady(lb,200,210));
   check(CMarcoStructureExit::Evaluate(ctx.rejectionHistory,plan,140,210,1).action==2);
  }
 }
 std::cout<<checks<<" entry-trigger structure assertions passed\n";
}
'''
out=ROOT/'Tests/Marcotrades/_review'
cpp,exe=out/'entry_trigger_structure.cpp',out/'entry_trigger_structure.exe'
cpp.write_text(env['mock']+env['source']+main,encoding='utf-8')
result=subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2','-fmax-errors=5',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:raise SystemExit(result.stderr)
result=subprocess.run([str(exe)],capture_output=True,text=True)
(out/'entry_trigger_structure_results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout,end='')
if result.returncode:raise SystemExit(result.stderr or str(result.returncode))
