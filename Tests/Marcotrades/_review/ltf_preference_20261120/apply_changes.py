from pathlib import Path
root=Path(__file__).resolve().parents[4]
def edit(path,fn):
 p=root/path;raw=p.read_bytes();bom=raw.startswith(b'\xef\xbb\xbf');crlf=b'\r\n' in raw
 text=raw.decode('utf-8-sig').replace('\r\n','\n');updated=fn(text)
 assert updated!=text,path
 p.write_bytes((b'\xef\xbb\xbf' if bom else b'')+updated.replace('\n','\r\n' if crlf else '\n').encode('utf8'))

methods='''   // Publish current entry candidates, not historical cluster boundary unions.
   void ObserveTFPreferences(CMarcoLBEntryClusters &book,datetime now,CLiquidityBlockLogic* logic)
     {
      if(!CMarcoLBTFPreference::Enabled()) return;
      CMarcoLBTFPreference::ResetOwner(m_symbol,m_tradeTF);
      if(logic==NULL) return;
      datetime day=CMarcoLBEntryClusters::Day(now);
      for(int k=0;k<m_htf_lb_count;k++)
        {
         if(!m_htf_lbs[k].sourceActive || m_htf_lbs[k].entryTriggerTime<=0 ||
            CTradeRejection::Used(m_htf_lbs[k].touchCount,m_htf_lbs[k].isMitigated)) continue;
         datetime available=m_htf_lbs[k].entryTriggerTime+PeriodSeconds(m_tradeTF);
         bool ind=(m_htf_lbs[k].triggerType==LB_TRIGGER_BL_IND || m_htf_lbs[k].triggerType==LB_TRIGGER_BR_IND);
         datetime origin=ind ? m_htf_lbs[k].inducementOriginTime : m_htf_lbs[k].sweepLineTime;
         if(available>now || CTradeRejection::OutsideSession(origin,m_htf_lbs[k].createdTime,m_htf_lbs[k].confirmedTime,day)) continue;
         string source=""; datetime used=0;
         if(!book.Eligible(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now) ||
            book.Blocked(m_symbol,(int)m_tradeTF,m_htf_lbs[k].id,now,source,used)) continue;
         for(int z=0;z<logic.m_liquidity_blocks.Total();z++)
           {
            CLiquidityBlock* lb=(CLiquidityBlock*)logic.m_liquidity_blocks.At(z);
            if(lb==NULL || lb.id!=m_htf_lbs[k].id) continue;
            if(!lb.isMitigated)
               CMarcoLBTFPreference::Observe(m_symbol,m_tradeTF,lb.id,lb.isBullish,
                                              lb.zoneLow,lb.zoneHigh,available,now);
            break;
           }
        }
     }

   bool DeferToLowerTF(int k,datetime now)
     {
      if(!CMarcoLBTFPreference::Enabled()) return false;
      SMarcoLBTFChoice choice;
      if(!CMarcoLBTFPreference::Preferred(m_symbol,m_tradeTF,m_htf_lbs[k].isBullish,
                                          m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now,choice))
        { m_htf_lbs[k].preferredLTF=""; return false; }
      string key=EnumToString(choice.tf)+":"+choice.id;
      if(m_htf_lbs[k].preferredLTF!=key)
        {
         PrintFormat("[LTF LB PREFERENCE] %s %s LB=%s deferred to %s LB=%s zone=[%.8f, %.8f]; wait for that setup's touch and entry confirmation.",
                     m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,EnumToString(choice.tf),choice.id,choice.low,choice.high);
         m_htf_lbs[k].preferredLTF=key;
        }
      return true; // Waiting alone never consumes a setup or a cluster.
     }

'''

def engine(text,live):
 text=text.replace('#include <Custom\\Marcotrades\\pivot_entry.mqh>', '#include <Custom\\Marcotrades\\pivot_entry.mqh>\n#include <Custom\\Marcotrades\\lb_tf_preference.mqh>',1)
 marker='    datetime          opposingRejectedAt;'
 # Preserve the existing layout/comments of each cached LB definition.
 lines=text.splitlines(keepends=True);out=[]
 for line in lines:
  out.append(line)
  if 'datetime' in line and 'opposingRejectedAt;' in line:
   out.append('    string            preferredLTF; // Diagnostic only; does not retire the HTF setup.\n')
  if 'm_htf_lbs[sz].opposingRejectedAt' in line and '= 0;' in line:
   out.append(line[:len(line)-len(line.lstrip())]+'m_htf_lbs[sz].preferredLTF         = "";\n')
 text=''.join(out)
 if live:
  marker='   datetime m_clusterSyncedBar;'
  assert marker in text;text=text.replace(marker,methods+marker,1)
  marker='         double firstPivotPrice = 0.0;'
  start=text.index('   void              ProcessLive(')
  pos=text.index(marker,start)
  text=text[:pos]+'          if(DeferToLowerTF(k,TimeCurrent())) continue;\n'+text[pos:]
  text=text.replace('      if(!changed) return true;','       if(!changed && !CMarcoLBTFPreference::Enabled()) return true;',1)
  old='''       for(int pass=0;pass<2;pass++)
         {
          if(pass==1) state.book.RetireCompleted();
          for(int i=0;i<m_total_instances;i++)
            {
             CMarcoLiveAutoInstance* inst=m_instances[i];
             if(inst.m_symbol==symbol) inst.ObserveEntryClusters(state.book,now,inst.lbLogicHtf,pass);
            }
         }
       if(!state.Save()) return false;'''
  new='''       if(changed)
         {
          for(int pass=0;pass<2;pass++)
            {
             if(pass==1) state.book.RetireCompleted();
             for(int i=0;i<m_total_instances;i++)
               {
                CMarcoLiveAutoInstance* inst=m_instances[i];
                if(inst.m_symbol==symbol) inst.ObserveEntryClusters(state.book,now,inst.lbLogicHtf,pass);
               }
            }
          if(!state.Save()) return false;
         }
       // All TFs are updated before publishing; never let scan order select the HTF first.
       if(CMarcoLBTFPreference::Enabled())
          for(int i=0;i<m_total_instances;i++)
             if(m_instances[i].m_symbol==symbol)
                m_instances[i].ObserveTFPreferences(state.book,now,m_instances[i].lbLogicHtf);'''
  old='\n'.join(line[1:] if line.startswith(' ') else line for line in old.split('\n'))
  assert old in text;text=text.replace(old,new,1)
 else:
  text=text.replace('      s_clusters.Clear();','       s_clusters.Clear();\n       CMarcoLBTFPreference::Clear();',1)
  old='      if(m_sim!=NULL && m_sim.prepared) ObserveEntryClusters(now,m_sim.lbLogicHtf,1);'
  new='''       if(m_sim!=NULL && m_sim.prepared)
         {
          ObserveEntryClusters(now,m_sim.lbLogicHtf,1);
          ObserveTFPreferences(s_clusters,now,m_sim.lbLogicHtf);
         }'''
  assert old in text;text=text.replace(old,new,1)
  text=text.replace('   void SyncGlobalTrades()',methods+'   void SyncGlobalTrades()',1)
  marker='            double candidateBid=executionBid, candidateAsk=executionAsk;'
  assert marker in text;text=text.replace(marker,'             if(DeferToLowerTF(k,m_sim.run_time[i])) continue;\n'+marker,1)
 return text

edit('Include/Custom/Marcotrades/marco_live_auto.mqh',lambda s:engine(s,True))
edit('Include/Custom/Marcotrades/marco_backtest.mqh',lambda s:engine(s,False))
programs=[('Experts/Custom EAs/Marcotrades/marco_live_auto_ea.mq5','1.51','1.52'),('Experts/Custom EAs/Backtesting/marco_backtest_ea.mq5','1.72','1.73'),('Indicators/Custom/Marcotrades/marco_backtest_trades.mq5','2.30','2.31')]
for path,old,new in programs:
 def change(s):
  s=s.replace('#property version   "'+old+'"','#property version   "'+new+'"',1)
  lines=s.splitlines(keepends=True);out=[]
  for line in lines:
   out.append(line)
   if line.startswith('input ') and 'InpAllowOverlappingTrades' in line:
    out.append('input bool InpPreferNestedLowerTFLB = true; // Prefer deeper qualified LTF LB inside same-direction HTF LB\n')
  s=''.join(out)
  marker='   CMarcoPivotEntry::Configure(InpEntryTiming);'
  assert marker in s;s=s.replace(marker,marker+'\n   CMarcoLBTFPreference::Configure(InpPreferNestedLowerTFLB);',1)
  if 'marco_backtest_trades' in path:
   s=s.replace('MarcoTradeCache30|','MarcoTradeCache31|').replace('header.version=30','header.version=31').replace('header.version==30','header.version==31')
   marker='   key+="|InpAllowOverlappingTrades="+(string)InpAllowOverlappingTrades;'
   assert marker in s;s=s.replace(marker,marker+'\n   key+="|InpPreferNestedLowerTFLB="+(string)InpPreferNestedLowerTFLB;',1)
  return s
 edit(path,change)
print('Updated both engines and three clients')
