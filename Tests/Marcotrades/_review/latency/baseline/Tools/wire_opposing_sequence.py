"""Apply shared sequence plumbing consistently to the two engine implementations."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for name in ('marco_backtest.mqh','marco_live_auto.mqh'):
    path=root/'Include/Custom/Marcotrades'/name
    text=path.read_text(encoding='utf-8-sig')
    def edit(old,new,count=1):
        global text
        assert text.count(old)==count,(name,old,text.count(old))
        text=text.replace(old,new)
    edit('#include <Custom\\Marcotrades\\structure_exit.mqh>', '#include <Custom\\Marcotrades\\structure_exit.mqh>\n#include <Custom\\Marcotrades\\opposing_sequence.mqh>\n#include <Custom\\Marcotrades\\raw_exit_context.mqh>')
    edit('   CTradeRejectionHistory rejectionHistory;', '   CTradeRejectionHistory rejectionHistory;\n   CTradeRejectionHistory rawExitHistory;')
    edit('      rejectionHistory.EndZones(available);','      rejectionHistory.EndZones(available);\n      CMarcoRawExitHistory::Capture(ms,lbs,available,rawExitHistory);')
    edit('   CTradeRejectionHistory m_htfRejection;', '   CTradeRejectionHistory m_htfRejection;\n   CTradeRejectionHistory m_htfRawExit;')
    edit('      m_htfRejection.Reset();','      m_htfRejection.Reset();\n      m_htfRawExit.Reset();')
    edit('      history.EndZones(available);','      history.EndZones(available);\n      CMarcoRawExitHistory::Capture(ms,lbs,available,m_htfRawExit);')
    marker='   void ObserveRejectionTouch('
    assert text.count(marker)==1
    method='''   SMarcoSequenceSignal ObserveOpposingSequence(SMarcoTPPlan &plan, datetime opened, datetime now, double price)
     {
      SMarcoSequenceSignal signal; ZeroMemory(signal);
      bool preferM1=m_entryTF==ENTRY_TF_M1;
      for(int pass=0;pass<2;pass++)
        {
         bool m1=(pass==0 ? preferM1 : !preferM1);
         if(m1)
           {
            if(m1LBContext==NULL || m_tradeTF==PERIOD_M1) continue;
            signal=CMarcoOpposingSequence::Advance(m1LBContext.rawExitHistory,plan.sequence,1,PERIOD_M1,
                                                  plan.direction,plan.entry,price,opened,now);
           }
         else signal=CMarcoOpposingSequence::Advance(m_htfRawExit,plan.sequence,0,m_tradeTF,
                                                     plan.direction,plan.entry,price,opened,now);
         if(signal.step>0 || plan.sequence.step>=2) break;
        }
      return signal;
     }

'''
    text=text.replace(marker,method+marker)
    path.write_text(text,encoding='utf-8')
