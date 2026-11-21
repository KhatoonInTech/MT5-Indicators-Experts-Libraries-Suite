"""Offline replay of production M1 context against exported terminal candles.

MQL syntax is adapted to C++; chart drawing and terminal metadata are mocked.
No connection to a terminal and no order execution.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'Tests/Marcotrades/_review'
names = ['ZigZag/ZigZag.mqh', 'ZigZag/market_structure.mqh',
         'ZigZag/demand_supply.mqh', 'ZigZag/swing_pois.mqh',
         'ZigZag/order_blocks.mqh', 'ZigZag/flipzone.mqh',
         'ZigZag/breaker_blocks.mqh', 'Marcotrades/trade_rejection.mqh',
         'Marcotrades/Inducements.mqh', 'Marcotrades/liquidity_blocks.mqh',
         'Marcotrades/m1_ind_entry.mqh', 'Marcotrades/staged_tp.mqh',
         'Marcotrades/structure_exit.mqh', 'Marcotrades/raw_exit_context.mqh', 'Marcotrades/opposing_sequence.mqh']
sources = [(ROOT/'Include/Custom'/n).read_text(encoding='utf-8-sig') for n in names]
engine = 'marco_live_auto' if '--live-context' in sys.argv else 'marco_backtest'
back = (ROOT/'Include/Custom/Marcotrades'/f'{engine}.mqh').read_text(encoding='utf-8-sig')
sources.append(back[back.index('class CMarcoM1LBContext'):back.index('#endif', back.index('class CMarcoM1LBContext'))])
source = '\n'.join(sources)
source = re.sub(r'^#(?:include|property).*$', '', source, flags=re.M)
source = source.replace('private:', 'public:')
# Translate pointer member access without changing value-member access.
classes=set(re.findall(r'(?:class|struct)\s+(\w+)',source)) | {'CArrayLong','CArrayString','CArrayDouble','CArrayInt','CArrayObj'}
pointers=set(re.findall(r'\b(?:'+ '|'.join(classes) +r')\s*\*\s*([A-Za-z_]\w*)',source))
for name in sorted(pointers, key=len, reverse=True):
    source = re.sub(r'\b'+name+r'\.', name+'->', source)
source = re.sub(r'\b(class|struct)\s+(\w+)([^;{]*)\{', lambda m:m[0]+' public: '+m[2]+'* operator->(){return this;} const '+m[2]+'* operator->()const{return this;}',source)
source = re.sub(r'\b(const\s+)?(\w+)\s+&(\w+)\[\]', r'\1std::vector<\2> &\3', source)
source = re.sub(r'\b(\w+)\s+(\w+)\[\](?:,\s*(\w+)\[\])*(?=;)', lambda m: m.group(0), source)
# Expand comma-separated MQL dynamic-array declarations.
source = re.sub(r'\b(\w+)\s+((?:\w+\[\]\s*,\s*)*\w+\[\]);',
                lambda m: 'std::vector<'+m[1]+'> '+m[2].replace('[]','')+';', source)
source = re.sub(r'"([^"\n]*)"\s*\+', r'string("\1") +', source)
source = re.sub(r"C'\d+,\d+,\d+'", '0', source)
source = source.replace('PeriodSeconds()', 'PeriodSeconds(_Period)')

mock = r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cfloat>
#include <ctime>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>
#include <set>
using string=std::string;using datetime=long long;using color=int;using ENUM_TIMEFRAMES=int;using uint=unsigned int;
const double EMPTY_VALUE=DBL_MAX;const double _Point=.1;const int _Digits=1;const int _Period=1;const string _Symbol="US30c";
struct CObject {virtual ~CObject()=default;};
template<class T> struct MArray {MArray* operator->(){return this;} std::vector<T> v;
 int Total(){return int(v.size());}T At(int i){return i>=0&&i<Total()?v[i]:T{};}
 bool Add(T x){v.push_back(x);return true;}void Clear(){v.clear();}
 bool Update(int i,T x){if(i<0||i>=Total())return false;v[i]=x;return true;}
 bool Delete(int i){if(i<0||i>=Total())return false;v.erase(v.begin()+i);return true;}
 int Search(T x){auto p=std::find(v.begin(),v.end(),x);return p==v.end()?-1:int(p-v.begin());}
};
using CArrayLong=MArray<long>;using CArrayInt=MArray<int>;using CArrayDouble=MArray<double>;using CArrayString=MArray<string>;
struct CArrayObj:MArray<CObject*> {bool owns=true;void FreeMode(bool x){owns=x;}
 void Clear(){if(owns)for(auto x:v)delete x;v.clear();}
 bool Delete(int i){if(i<0||i>=Total())return false;if(owns)delete v[i];v.erase(v.begin()+i);return true;}
 CObject* Detach(int i){if(i<0||i>=Total())return nullptr;auto p=v[i];v.erase(v.begin()+i);return p;}
 ~CArrayObj(){Clear();}
};
template<class T> int CheckPointer(T*p){return p?1:0;}
template<class T> T* GetPointer(T&x){return &x;}
template<class T> void ArrayFree(std::vector<T>&v){v.clear();}
template<class T> int ArrayMaximum(const std::vector<T>&v){return v.empty()?-1:int(std::max_element(v.begin(),v.end())-v.begin());}
template<class T> int ArrayMinimum(const std::vector<T>&v){return v.empty()?-1:int(std::min_element(v.begin(),v.end())-v.begin());}
template<class T> int ArraySize(const std::vector<T>&v){return int(v.size());}
template<class T> int ArrayResize(std::vector<T>&v,int n,int=0){v.resize(n);return n;}
template<class T,class V> void ArrayInitialize(std::vector<T>&v,V x){std::fill(v.begin(),v.end(),x);}
double MathMax(double a,double b){return std::max(a,b);}double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}double MathFloor(double a){return std::floor(a);}
double MathCeil(double a){return std::ceil(a);}bool MathIsValidNumber(double a){return std::isfinite(a);}
template<class T>void ZeroMemory(T&v){v=T{};}
double NormalizeDouble(double a,int d){double k=std::pow(10.,d);return std::round(a*k)/k;}
int StringLen(string s){return int(s.size());}int StringFind(string s,string q){auto p=s.find(q);return p==string::npos?-1:int(p);}
string StringSubstr(string s,int p,int n=2147483647){return s.substr(p,n);}
string IntegerToString(long long x){return std::to_string(x);}string DoubleToString(double x,int d){std::ostringstream s;s<<std::fixed<<std::setprecision(d)<<x;return s.str();}
string TimeToString(datetime t,int=0){time_t n=t;char b[30];std::strftime(b,sizeof(b),"%Y.%m.%d %H:%M",std::gmtime(&n));return b;}
string EnumToString(int tf){return std::to_string(tf);}int PeriodSeconds(int tf){return tf*60;}datetime TimeCurrent(){return 1794528000;}
template<class...A>void Print(A...){}template<class...A>void PrintFormat(A...){}
template<class...A>string StringFormat(string format,A...){return format;}
template<class...A>int ObjectFind(A...){return -1;}template<class...A>bool ObjectDelete(A...){return true;}
template<class...A>void ObjectsDeleteAll(A...){}template<class...A>void ObjectSetString(A...){}
template<class...A>void ObjectSetInteger(A...){}template<class...A>void ObjectSetDouble(A...){}
template<class...A>void ObjectMove(A...){}template<class...A>void ObjectCreate(A...){}
template<class...A>double SymbolInfoDouble(A...){return 0;}
template<class...A>int CopyTickVolume(A...){return 0;}template<class...A>int CopyRealVolume(A...){return 0;}
template<class...A>double ObjectGetDouble(A...){return 0;}
struct Plotter {template<class...A>static void DrawLine(A...){}template<class...A>static void DrawLabel(A...){}
 template<class...A>static void DrawBox(A...){} };
'''
tokens = sorted(set(re.findall(r'\b(?:clr\w+|OBJ\w+|ANCHOR_\w+|STYLE_\w+|SYMBOL_\w+|TIME_\w+|PERIOD_\w+|POINTER_DYNAMIC|TRADE_RETCODE_\w+)\b', source)))
mock += '\nenum {'+','.join(t+'='+('1' if t in ('PERIOD_M1','POINTER_DYNAMIC') else '0') for t in tokens)+'};\n'

main = r'''
int main(int argc,char**argv){
 CMarcoIndEntryFilter::Configure(IND_ENTRY_PRICE);
 Settings* settings=new Settings(.001,1,0,false,false,false,false,"Absolute");settings->draw=false;
 ZigZag* zz=newInstance(settings);CMarcoM1LBContext ctx;
 ctx.Init(true,true,2,1,true,true,10,false,true,true,true,false,false,.1);
 SMarcoTPPlan plan;assert(CMarcoStagedTP::Build(plan,true,52412.8,52353.5,52528.5,52472.3,1,2,0,.1,1));
 datetime opened=1794513780,firstExit=0;bool checkedEntry=false,checkedQualification=false;
 std::ifstream f(argv[1]);string line;std::getline(f,line);int i=0;
 while(std::getline(f,line)){
  std::replace(line.begin(),line.end(),',',' ');std::istringstream s(line);
  datetime t;double o,h,l,c;long volume,real;int spread;s>>t>>o>>h>>l>>c>>volume>>spread>>real;
  zz->update(h,l,t,volume,i++,true,false);ctx.Update(t,o,h,l,c,zz,1.0);
  string stamp=TimeToString(t+60);
  for(int j=0;j<ctx.ind->m_zones.Total();j++){
   auto z=(CInducementZone*)ctx.ind->m_zones.At(j);
   if(z->id!="Swing POI_BULL_1794497100")continue;
   if(stamp=="2026.11.12 20:03"){
    assert(!z->isInducement&&z->touchCount==0&&z->qualifiedTime==0);checkedEntry=true;
    double low,high;string id;assert(!ctx.indEntry.Inside(true,52412.8,t+60,low,high,id));
    std::cout<<"VERIFIED entry zone was not IND at "<<stamp<<"\n";
   }
   if(stamp=="2026.11.12 20:10"){
    assert(z->isInducement&&z->touchCount==2&&z->qualifiedTime==t+60);checkedQualification=true;
    double low,high;string id;assert(ctx.indEntry.Inside(true,52412.8,t+60,low,high,id));
    std::cout<<"VERIFIED IND first available at "<<stamp<<"\n";
   }
  }
  if(t+60>opened&&!firstExit){
   auto exit=CMarcoStructureExit::Evaluate(ctx.rejectionHistory,plan,opened,t+60,1);
   if(exit.action){
    firstExit=t+60;
    assert(exit.action==2&&stamp=="2026.11.12 20:33"&&TimeToString(exit.eventTime)=="2026.11.12 20:32");
    assert(exit.lbId.find("EXIT_ONLY_LB_")==0);
    for(int j=0;j<ctx.lbs->m_liquidity_blocks.Total();j++){
     auto lb=(CLiquidityBlock*)ctx.lbs->m_liquidity_blocks.At(j);
     assert(lb->isBullish||lb->createdTime!=1794514860); // Still rejected for new entries.
    }
    std::cout<<"VERIFIED FULL EXIT known="<<stamp<<" CHoCH="<<TimeToString(exit.eventTime)<<" level="<<exit.level<<" source="<<exit.lbId<<"\n";
   }
  }
  if(firstExit&&t==firstExit){
   assert(std::abs(o-52386.5)<.00001);
   std::cout<<"VERIFIED next-open bid="<<o<<" gross R="<<(o-plan.entry)/(plan.entry-plan.initialSL)<<"\n";
  }
  if(stamp>="2026.11.12 19:45" && stamp<="2026.11.12 20:52"){
   std::cout<<"BAR "<<stamp<<" OHLC "<<o<<" "<<h<<" "<<l<<" "<<c<<" pivots="<<zz->pivots->Total()<<"\n";
   for(int j=0;j<ctx.ind->m_zones.Total();j++){
    auto z=(CInducementZone*)ctx.ind->m_zones.At(j);
    if((z->zoneLow<=52412.8 && z->zoneHigh>=52412.8)||(!z->isBullish&&z->zoneLow<52460&&z->zoneHigh>52380))
     std::cout<<" IND "<<z->id<<" "<<z->zoneLow<<" "<<z->zoneHigh<<" touches="<<z->touchCount<<" qualified="<<z->isInducement<<" dead="<<z->isMitigated<<" death="<<TimeToString(z->mitigationTime)<<"\n";
   }
   SRejectionEvent e;if(ctx.rejectionHistory.Latest(t+60,e))std::cout<<" STRUCT "<<e.name<<" at="<<TimeToString(e.time)<<" line="<<e.linePrice<<" origin="<<TimeToString(e.originTime)<<" price="<<e.originPrice<<"\n";
   for(int j=0;j<ctx.lbs->m_liquidity_blocks.Total();j++){
    auto z=(CLiquidityBlock*)ctx.lbs->m_liquidity_blocks.At(j);
    if(z->zoneHigh>52350&&z->zoneLow<52480)std::cout<<" LB "<<z->id<<" "<<z->zoneLow<<" "<<z->zoneHigh<<" cause="<<TimeToString(z->causalChochTime)<<"\n";
   }
  }
 }
 assert(checkedEntry&&checkedQualification&&firstExit);delete zz;
}
'''
suffix='_live' if engine=='marco_live_auto' else ''
cpp=OUT/f'us30_context{suffix}.cpp';exe=OUT/f'us30_context{suffix}.exe'
cpp.write_text(mock+source+main,encoding='utf-8')
result=subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17','-O2','-fmax-errors=15',str(cpp),'-o',str(exe)],capture_output=True,text=True)
if result.returncode:
    print(result.stderr);raise SystemExit(result.returncode)
with (OUT/f'us30_context{suffix}_replay.txt').open('w') as out:
    subprocess.run([str(exe),str(OUT/'us30_20261112_m1.csv')],stdout=out,check=True)
print('Replay saved:',OUT/f'us30_context{suffix}_replay.txt')
