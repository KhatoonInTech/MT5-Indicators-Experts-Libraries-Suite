from pathlib import Path
import re
root=Path(__file__).resolve().parents[3]

def method(source,name):
    start=re.search(r'   (?:void|bool)\s+'+name+r'\(',source).start()
    opening=source.index('{',start); depth=1; end=opening+1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    return source[start:end]

helpers='''   // Snapshot existing setup-TF results; do not run another calculation engine.
   void CaptureSetupIndContext(CInducementLogic* ind, CMarketStructure* ms,
                               datetime available, double low, double high)
     {
      if(!CMarcoIndEntryFilter::Enabled()) return;
      m_setupIndEntry.Begin(low,high);
      for(int z=0;z<ind.m_zones.Total();z++)
        {
         CInducementZone* zone=(CInducementZone*)ind.m_zones.At(z);
         if(zone!=NULL && zone.isInducement && !zone.isMitigated)
            m_setupIndEntry.Zone(zone.id,zone.isBullish,zone.zoneLow,zone.zoneHigh,available);
        }
      m_setupIndEntry.End(available);
      int n=ms.all_event_names.Total();
      for(int e=MathMax(0,n-3);e<n;e++)
         m_setupIndEntry.Observe(ms.all_event_names.At(e),(datetime)ms.all_event_times.At(e),available);
     }

   bool IndEntryReady(int k, datetime pivot, double price, datetime available, datetime now)
     {
      if(!CMarcoIndEntryFilter::Enabled() || !m_htf_lbs[k].indWait.waiting) return true;
      if(m_entryTF==ENTRY_TF_M1)
         return m1LBContext!=NULL && m1LBContext.indEntry.Ready(m_htf_lbs[k].indWait,
                   m_htf_lbs[k].isBullish,pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
      return m_setupIndEntry.Ready(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,
                   pivot,price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now);
     }

   bool SkipIndPivot(int k, datetime pivot, double price, datetime available)
     {
      if(!CMarcoIndEntryFilter::CheckPivot() || pivot<=0) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      ENUM_TIMEFRAMES entryTF=m_entryTF==ENTRY_TF_M1 ? PERIOD_M1 : m_tradeTF;
      string id="";
      if(m_setupIndEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      // Same timeframe is checked once. Both blockers contribute to the wait bounds.
      if(entryTF!=m_tradeTF && m1LBContext!=NULL &&
         m1LBContext.indEntry.SkipPivot(m_htf_lbs[k].indWait,bull,pivot,price,available,id,entryTF))
        {
         blocked=true;
         PrintFormat("[IND PIVOT WAIT] %s setup=%s source=%s IND=%s pivot=%s price=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(entryTF),id,
                     TimeToString(pivot,TIME_DATE|TIME_SECONDS),price);
        }
      return blocked;
     }

   bool SkipIndEntryPrice(int k, datetime now, double entry, datetime pivot=0, datetime confirmed=0)
     {
      if(!CMarcoIndEntryFilter::CheckPrice()) return false;
      bool bull=m_htf_lbs[k].isBullish, blocked=false;
      if(m_entryTF==ENTRY_TF_M1)
        { pivot=m_htf_lbs[k].m1PivotTime; confirmed=m_htf_lbs[k].m1ConfirmTime; }
      string id="";
      m_setupIndEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,m_tradeTF);
      if(m_setupIndEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
        {
         blocked=true;
         PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                     m_symbol,EnumToString(m_tradeTF),EnumToString(m_tradeTF),id,entry);
        }
      if(m_entryTF==ENTRY_TF_M1 && m_tradeTF!=PERIOD_M1 && m1LBContext!=NULL)
        {
         m1LBContext.indEntry.Audit(m_symbol,m_tradeTF,bull,now,entry,PERIOD_M1);
         if(m1LBContext.indEntry.SkipPrice(m_htf_lbs[k].indWait,bull,pivot,confirmed,now,entry,id))
           {
            blocked=true;
            PrintFormat("[IND PRICE WAIT] %s setup=%s source=%s IND=%s entry=%.8f",
                        m_symbol,EnumToString(m_tradeTF),EnumToString(PERIOD_M1),id,entry);
           }
        }
      if(!blocked) return false;
      PrintFormat("[IND WAIT] %s setup=%s LB=%s: waiting for a new %s CHoCH and pivot beyond blocking INDs.",
                  m_symbol,EnumToString(m_tradeTF),m_htf_lbs[k].id,
                  EnumToString(m_entryTF==ENTRY_TF_M1 ? PERIOD_M1 : m_tradeTF));
      m_htf_lbs[k].m1PivotTime=0; m_htf_lbs[k].m1PivotPrice=0; m_htf_lbs[k].m1ConfirmTime=0;
      if(m_entryTF==ENTRY_TF_M1 && m1LBContext!=NULL)
         CheckIndWaitBoundary(k,now,m1LBContext.indEntry.lastLow,m1LBContext.indEntry.lastHigh);
      else CheckIndWaitBoundary(k,now,m_setupIndEntry.lastLow,m_setupIndEntry.lastHigh);
      return true;
     }

   // After an IND rejection, ignore the rejected pivot and require a new
   // entry-TF pivot after the directional CHoCH, still within the setup LB.
   bool GetSetupIndWaitPivot(int k, datetime now, ZigZag* zz,
                             datetime &pivot, double &price, datetime &confirmed)
     {
      pivot=0; price=0; confirmed=0;
      if(zz==NULL) return false;
      for(int p=0;p<zz.pivots.Total() && p<ArraySize(m_pivotConfirmations);p++)
        {
         Pivot* pv=(Pivot*)zz.pivots.At(p);
         if(pv==NULL || pv==zz.projection || StringFind(pv.ln,"ZZ_Proj")>=0 ||
            pv.isHigh==m_htf_lbs[k].isBullish) continue;
         datetime available=m_pivotConfirmations[p].availableTime;
         if(available<=0 || available>now || !IndEntryReady(k,pv.end.time,pv.end.price,available,now)) continue;
         if(confirmed==0 || available<confirmed)
           { pivot=pv.end.time; price=pv.end.price; confirmed=available; }
        }
      return confirmed>0;
     }

'''

for filename in ('marco_backtest.mqh','marco_live_auto.mqh'):
    path=root/'Include/Custom/Marcotrades'/filename
    text=path.read_text(encoding='utf-8-sig')
    text=text.replace('   CTradeRejectionHistory m_htfRejection;', '   CMarcoIndEntryFilter m_setupIndEntry;\n   CTradeRejectionHistory m_htfRejection;',1)
    text=text.replace('      m_htfRejection.Reset();','      m_htfRejection.Reset();\n      m_setupIndEntry.Clear();',1)
    text=text.replace(method(text,'SkipIndEntryPrice'),helpers.rstrip())
    old=method(text,'GetM1EntryPivot'); new=old
    new=new.replace('m1LBContext!=NULL && !m1LBContext.indEntry.Ready(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,\n                  pv.end.time,pv.end.price,available,m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now)',
                    '!IndEntryReady(k,pv.end.time,pv.end.price,available,now)')
    new=new.replace('m1LBContext!=NULL && m1LBContext.indEntry.SkipPivot(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,\n                                    first.end.time,first.end.price,earliest,blockedInd)',
                    'SkipIndPivot(k,first.end.time,first.end.price,earliest)')
    start=new.index('         string blockedInd="";'); new=new[:start]+new[start:].replace('         string blockedInd="";\n','',1)
    a=new.index('            PrintFormat("[M1 IND WAIT]'); b=new.index('            if(CheckIndWaitBoundary',a)
    new=new[:a]+new[b:]
    new=new.replace('if(CheckIndWaitBoundary(k,now,m1LBContext.indEntry.lastLow,m1LBContext.indEntry.lastHigh))',
                    'if(m1LBContext!=NULL && CheckIndWaitBoundary(k,now,m1LBContext.indEntry.lastLow,m1LBContext.indEntry.lastHigh))')
    new=new.replace('m1LBContext!=NULL && !m1LBContext.indEntry.Ready(m_htf_lbs[k].indWait,m_htf_lbs[k].isBullish,\n            m_htf_lbs[k].m1PivotTime,m_htf_lbs[k].m1PivotPrice,m_htf_lbs[k].m1ConfirmTime,\n            m_htf_lbs[k].zoneLow,m_htf_lbs[k].zoneHigh,now)',
                    '!IndEntryReady(k,m_htf_lbs[k].m1PivotTime,m_htf_lbs[k].m1PivotPrice,m_htf_lbs[k].m1ConfirmTime,now)')
    assert 'indEntry.Ready' not in new and 'indEntry.SkipPivot' not in new
    text=text.replace(old,new)
    if filename=='marco_backtest.mqh':
        anchor='            CaptureRejectionContext(msHtf, lbLogicHtf, htf_time[h] + PeriodSeconds(m_tradeTF), m_htfRejection);'
        text=text.replace(anchor,'            CaptureSetupIndContext(indHtf,msHtf,htf_time[h]+PeriodSeconds(m_tradeTF),htf_low[h],htf_high[h]);\n'+anchor)
        now='run_time[i]'; zz='zzHtf'; indent='               '
        before='            // Opposing Leg Filter (Anti-Bait Trap Guard)'
        common='''            if(m_entryTF!=ENTRY_TF_M1 &&
               (SkipIndPivot(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime) ||
                !IndEntryReady(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime,run_time[i]) ||
                SkipIndEntryPrice(k,run_time[i],isBull ? executionAsk : executionBid,firstPivotTime,firstPivotConfirmTime))) continue;

'''
    else:
        anchor='               CaptureRejectionContext(ms, lbLgc, m_htf_time[i] + PeriodSeconds(tf), m_htfRejection);'
        text=text.replace(anchor,'               CaptureSetupIndContext(ind,ms,m_htf_time[i]+PeriodSeconds(tf),m_htf_low[i],m_htf_high[i]);\n'+anchor)
        anchor='            CaptureRejectionContext(msHtf, lbLogicHtf, m_htf_time[new_i] + PeriodSeconds(m_tradeTF), m_htfRejection);'
        text=text.replace(anchor,'            CaptureSetupIndContext(indHtf,msHtf,m_htf_time[new_i]+PeriodSeconds(m_tradeTF),m_htf_low[new_i],m_htf_high[new_i]);\n'+anchor)
        now='TimeCurrent()';zz='zzHtf';indent='            '
        before='         if(!entryAllowed)\n            continue;\n         // Opposing Leg Filter'
        common='''         if(m_entryTF!=ENTRY_TF_M1 &&
            (SkipIndPivot(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime) ||
             !IndEntryReady(k,firstPivotTime,firstPivotPrice,firstPivotConfirmTime,TimeCurrent()) ||
             SkipIndEntryPrice(k,TimeCurrent(),isBull ? ask : bid,firstPivotTime,firstPivotConfirmTime))) continue;

'''
        text=text.replace('if(m_entryTF==ENTRY_TF_M1 &&\n            (CheckIndWaitBoundary(k,entryTick.time,bid,ask) || SkipIndEntryPrice(k,entryTick.time,entryPx))) continue;',
                          'if(CheckIndWaitBoundary(k,entryTick.time,bid,ask) ||\n            SkipIndEntryPrice(k,entryTick.time,entryPx,firstPivotTime,firstPivotConfirmTime)) continue;')
    assert before in text
    text=text.replace(before,common+before,1)
    # Only the actual LB-entry branch, never pre-confirmation counting.
    pattern=r'(\s*)pivotTouches = CountTouchingPivots\(isBull, zHigh, zLow, buffer,\s*m_htf_lbs\[k\]\.entryTriggerTime, '+re.escape(now)+r',\s*zzHtf, firstPivotTime, firstPivotPrice, firstPivotConfirmTime\);'
    found=re.search(pattern,text); assert found, filename
    original=found.group().lstrip()
    replacement='\n'+indent+'''if(CMarcoIndEntryFilter::Enabled() && m_htf_lbs[k].indWait.waiting)
'''+indent+'''  {
'''+indent+f'''   if(!GetSetupIndWaitPivot(k,{now},{zz},firstPivotTime,firstPivotPrice,firstPivotConfirmTime)) continue;
'''+indent+'''   pivotTouches=1;
'''+indent+'''  }
'''+indent+'''else
'''+indent+'   '+original
    text=text[:found.start()]+replacement+text[found.end():]
    # A blocked direct-entry setup must also wait for confirmation before resuming.
    marker='if(m_requireZZConfirmation)\n'
    pos=text.index(replacement)
    a=text[:pos];b=text[pos:].replace(marker,'if(m_requireZZConfirmation || (CMarcoIndEntryFilter::Enabled() && m_htf_lbs[k].indWait.waiting))\n',1)
    text=a+b
    path.write_text(text,encoding='utf-8-sig')

for rel,old,new in [('Experts/Custom EAs/Backtesting/marco_backtest_ea.mq5','1.61','1.62'),
                    ('Experts/Custom EAs/Marcotrades/marco_live_auto_ea.mq5','1.40','1.41'),
                    ('Indicators/Custom/Marcotrades/marco_backtest_trades.mq5','2.19','2.20')]:
    path=root/rel;text=path.read_text(encoding='utf-8-sig')
    text=text.replace('"'+old+'"','"'+new+'"',1)
    text=text.replace('// Skip M1 IND entry and wait: Pivot / Entry price / Either / Off',
                      '// Skip IND on setup + entry TF: Pivot / Entry price / Either / Off')
    if 'marco_backtest_trades' in rel:
        text=text.replace('header.version=19','header.version=20').replace('header.version==19','header.version==20')
    path.write_text(text,encoding='utf-8-sig')
