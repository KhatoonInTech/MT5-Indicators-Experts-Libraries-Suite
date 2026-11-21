#ifndef MARCO_RAW_EXIT_CONTEXT_MQH
#define MARCO_RAW_EXIT_CONTEXT_MQH
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\liquidity_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\trade_rejection.mqh"

// Early exit observation is independent of the stricter entry-prevention registry.
class CMarcoRawExitHistory
  {
public:
   static void Capture(CMarketStructure* ms, CLiquidityBlockLogic* lbs, datetime available,
                       CTradeRejectionHistory &history)
     {
      int n=ms.all_event_names.Total();
      for(int e=MathMax(0,n-3);e<n;e++)
         history.Observe(ms.all_event_names.At(e),(datetime)ms.all_event_times.At(e),available,
                         (datetime)ms.all_event_origin_times.At(e),ms.all_event_origin_prices.At(e),ms.all_event_prices.At(e));
      history.BeginZones();
      for(int group=0;group<2;group++)
        {
         int count=group==0 ? lbs.m_exit_sources.Total() : lbs.m_liquidity_blocks.Total();
         for(int i=0;i<count;i++)
           {
            CLiquidityBlock* lb=group==0 ? (CLiquidityBlock*)lbs.m_exit_sources.At(i) :
                                         (CLiquidityBlock*)lbs.m_liquidity_blocks.At(i);
            if(lb!=NULL) history.Zone(lb.id,lb.isBullish,lb.zoneLow,lb.zoneHigh,lb.createdTime,
                                     lb.mitigationTime,lb.causalChochTime,available,group==0);
           }
        }
      history.EndZones(available);
     }
  };
#endif
