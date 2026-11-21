
#include <string>
#include <vector>
#include <iostream>
#include <cassert>
using string=std::string;using datetime=long long;using ENUM_TIMEFRAMES=int;
const int SERIES_SYNCHRONIZED=1;
struct MqlRates { datetime time;double open,high,low,close;long tick_volume;int spread;long real_volume; };
datetime now=600,current=600;int loads=0,itimes=0;bool sync=true,fail=false,partial=false;
std::vector<MqlRates> data={{60,1,3,0,2,10,2,0},{120,2,4,1,3,20,3,0}};
datetime TimeCurrent(){return now;}datetime iTime(string,int,int){itimes++;return current;}
int SeriesInfoInteger(string,int,int){return sync;}
int Bars(string,int,datetime first,datetime last){int n=0;for(auto r:data)if(r.time>=first&&r.time<=last)n++;return n;}
int CopyRates(string,int,datetime first,datetime last,std::vector<MqlRates>&v){loads++;v.clear();if(fail)return -1;for(auto r:data)if(r.time>=first&&r.time<=last)v.push_back(r);if(partial&&!v.empty())v.pop_back();return v.size();}
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
template<class T>void ArrayCopy(std::vector<T>&a,const std::vector<T>&b){a=b;}
int checks=0;
#define CHECK(x) do{++checks;if(!(x)){std::cerr<<"FAILED "<<__LINE__<<": "<<#x<<"\n";return 1;}}while(0)
#ifndef MARCO_CALCULATION_CONTEXT_MQH
#define MARCO_CALCULATION_CONTEXT_MQH

// Immutable candle snapshot for one program processing cycle. Consumers receive
// copies; neither simulation cursors nor per-setup trading state live here.
class CMarcoCalculationContext
  {
public:
   string symbol;
   ENUM_TIMEFRAMES tf;
   datetime from,to;
   std::vector<MqlRates> rates;
   std::vector<datetime> times;
   std::vector<double> opens,highs,lows,closes;
   std::vector<long> volumes;
   bool columnsReady;
   CMarcoCalculationContext() { columnsReady=false; }
   int Load(string sym,ENUM_TIMEFRAMES period,datetime first,datetime last)
     {
      symbol=sym; tf=period; from=first; to=last;
      return CopyRates(sym,period,first,last,rates);
     }
   void Columns()
     {
      if(columnsReady) return;
      int n=ArraySize(rates);
      ArrayResize(times,n); ArrayResize(opens,n); ArrayResize(highs,n);
      ArrayResize(lows,n); ArrayResize(closes,n); ArrayResize(volumes,n);
      for(int i=0;i<n;i++)
        {
         times[i]=rates[i].time; opens[i]=rates[i].open; highs[i]=rates[i].high;
         lows[i]=rates[i].low; closes[i]=rates[i].close; volumes[i]=rates[i].tick_volume;
        }
      columnsReady=true;
     }
  };
#endif

#ifndef MARCO_CALCULATION_POOL_MQH
#define MARCO_CALCULATION_POOL_MQH


// The pool deliberately expires at every event/pump boundary. Same-size history
// corrections therefore cannot leave persistent stale snapshots. Incomplete
// candles and failed/partial history loads are never cached.
class CMarcoCalculationPool
  {
private:
   std::vector<CMarcoCalculationContext*> items;
   std::vector<string> barSymbols;
   std::vector<ENUM_TIMEFRAMES> barTFs;
   std::vector<datetime> barTimes;
   datetime clock;
   bool active;
   int storedBars;
public:
   long loads,hits,columnBuilds;
   CMarcoCalculationPool() { active=false; clock=0; storedBars=0; loads=0; hits=0; columnBuilds=0; }
   ~CMarcoCalculationPool() { Clear(); }
   void Clear()
     {
      for(int i=0;i<ArraySize(items);i++) delete items[i];
      ArrayResize(items,0); ArrayResize(barSymbols,0); ArrayResize(barTFs,0); ArrayResize(barTimes,0);
      storedBars=0;
     }
   void Begin() { Clear(); clock=TimeCurrent(); active=true; }
   void End() { active=false; Clear(); }
   datetime CurrentBar(string symbol,ENUM_TIMEFRAMES tf)
     {
      if(!active) return iTime(symbol,tf,0);
      // Do not mask a new bar that arrives during a long processing callback.
      if(clock!=TimeCurrent()) { Clear(); clock=TimeCurrent(); }
      for(int i=0;i<ArraySize(barSymbols);i++)
         if(barSymbols[i]==symbol && barTFs[i]==tf) return barTimes[i];
      datetime value=iTime(symbol,tf,0);
      if(value<=0) return value;
      int n=ArraySize(barSymbols); ArrayResize(barSymbols,n+1); ArrayResize(barTFs,n+1); ArrayResize(barTimes,n+1);
      barSymbols[n]=symbol; barTFs[n]=tf; barTimes[n]=value;
      return value;
     }
   CMarcoCalculationContext *Find(string symbol,ENUM_TIMEFRAMES tf,datetime from,datetime to)
     {
      datetime current=CurrentBar(symbol,tf);
      if(!active || current<=0 || to>=current) return NULL;
      for(int i=0;i<ArraySize(items);i++)
         if(items[i]->symbol==symbol && items[i]->tf==tf && items[i]->from==from && items[i]->to==to)
           { hits++; return items[i]; }
      // A bounded working set; uncached requests still execute normally.
      if(storedBars>=131072) return NULL;
      CMarcoCalculationContext *context=new CMarcoCalculationContext(); loads++;
      int count=context->Load(symbol,tf,from,to);
      if(count<=0 || !SeriesInfoInteger(symbol,tf,SERIES_SYNCHRONIZED) ||
         count!=Bars(symbol,tf,from,to) || storedBars+count>131072)
        { delete context; return NULL; }
      int n=ArraySize(items); ArrayResize(items,n+1); items[n]=context; storedBars+=count;
      return context;
     }
   int Rates(string symbol,ENUM_TIMEFRAMES tf,datetime from,datetime to,std::vector<MqlRates> &result)
     {
      CMarcoCalculationContext *context=Find(symbol,tf,from,to);
      if(context==NULL) return CopyRates(symbol,tf,from,to,result);
      ArrayResize(result,ArraySize(context->rates)); ArrayCopy(result,context->rates);
      return ArraySize(result);
     }
   int Columns(string symbol,ENUM_TIMEFRAMES tf,datetime from,datetime to,
               std::vector<datetime> &times,std::vector<double> &opens,std::vector<double> &highs,std::vector<double> &lows,std::vector<double> &closes,std::vector<long> &volumes)
     {
      CMarcoCalculationContext *context=Find(symbol,tf,from,to);
      bool temporary=context==NULL;
      if(temporary)
        {
         context=new CMarcoCalculationContext();
         int count=context->Load(symbol,tf,from,to);
         if(count<=0) { delete context; return count; }
        }
      if(!context->columnsReady) columnBuilds++;
      context->Columns();
      int n=ArraySize(context->rates);
      ArrayResize(times,n); ArrayResize(opens,n); ArrayResize(highs,n);
      ArrayResize(lows,n); ArrayResize(closes,n); ArrayResize(volumes,n);
      ArrayCopy(times,context->times); ArrayCopy(opens,context->opens); ArrayCopy(highs,context->highs);
      ArrayCopy(lows,context->lows); ArrayCopy(closes,context->closes); ArrayCopy(volumes,context->volumes);
      if(temporary) delete context;
      return n;
     }
  };
CMarcoCalculationPool g_marcoCalculations;
class CMarcoCalculationCycle
  {
public:
   CMarcoCalculationCycle() { g_marcoCalculations.Begin(); }
   ~CMarcoCalculationCycle() { g_marcoCalculations.End(); }
  };
#endif

int main(){
 CMarcoCalculationPool p;std::vector<MqlRates>a,b;
 p.Begin();CHECK(p.Rates("A",1,60,180,a)==2);CHECK(p.Rates("A",1,60,180,b)==2);CHECK(loads==1);
 a[0].low=-100;CHECK(b[0].low==0); // consumer mutation cannot poison shared data
 std::vector<datetime>t;std::vector<double>o,h,l,c;std::vector<long>v;
 CHECK(p.Columns("A",1,60,180,t,o,h,l,c,v)==2);CHECK(loads==1&&p.columnBuilds==1);
 CHECK(t[1]==120&&o[1]==2&&h[1]==4&&l[1]==1&&c[1]==3&&v[1]==20);
 CHECK(p.Columns("A",1,60,180,t,o,h,l,c,v)==2);CHECK(p.columnBuilds==1);
 CHECK(p.Rates("B",1,60,180,b)==2);CHECK(loads==2);
 CHECK(p.Rates("A",2,60,180,b)==2);CHECK(loads==3);
 CHECK(p.Rates("A",1,120,180,b)==1);CHECK(b[0].time==120&&loads==4);
 CHECK(p.Rates("A",1,60,90,b)==1);CHECK(b[0].time==60&&loads==5); // earlier replay cutoff
 p.End();data[0].close=77;p.Begin();CHECK(p.Rates("A",1,60,180,b)==2);CHECK(b[0].close==77&&loads==6);
 now++;data[0].close=88;CHECK(p.Rates("A",1,60,180,b)==2);CHECK(b[0].close==88&&loads==7);
 // An incomplete candle must be re-read even within the same callback.
 data.push_back({600,3,5,2,4,40,2,0});int before=loads;
 CHECK(p.Rates("A",1,60,600,b)==3);data.back().close=99;CHECK(p.Rates("A",1,60,600,b)==3);
 CHECK(b.back().close==99&&loads==before+2);
 p.End();p.Begin();partial=true;CHECK(p.Rates("A",1,60,180,b)==1);partial=false;CHECK(p.Rates("A",1,60,180,b)==2);
 p.End();p.Begin();fail=true;CHECK(p.Rates("A",1,60,180,b)==-1);fail=false;CHECK(p.Rates("A",1,60,180,b)==2);
 p.End();p.Begin();sync=false;CHECK(p.Rates("A",1,60,180,b)==2);sync=true;data[0].close=111;CHECK(p.Rates("A",1,60,180,b)==2);CHECK(b[0].close==111);
 p.End();CHECK(p.Rates("A",1,60,180,b)==2);data[0].close=112;CHECK(p.Rates("A",1,60,180,b)==2);CHECK(b[0].close==112);
 // A second program owns a distinct pool, even for matching symbols/windows.
 CMarcoCalculationPool other;other.Begin();CHECK(other.Rates("A",1,60,180,b)==2);CHECK(other.loads==1);
 {CMarcoCalculationCycle cycle;CHECK(g_marcoCalculations.Rates("A",1,60,180,b)==2);}
 data[0].close=113;CHECK(g_marcoCalculations.Rates("A",1,60,180,b)==2);CHECK(b[0].close==113);
 std::cout<<checks<<" calculation-pool assertions passed\n";
}
