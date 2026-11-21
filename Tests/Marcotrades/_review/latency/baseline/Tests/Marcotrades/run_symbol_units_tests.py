"""Validate production pip conversion and outward stop rounding without broker orders."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
policy = (root/'Include/Custom/Marcotrades/symbol_units.mqh').read_text(encoding='utf-8-sig')
policy = re.sub(r'\b(\w+)\s+([\w:]+)\[\](\s*=\s*\{[^}]*\})?;',
                lambda m: 'std::vector<'+m[1]+'> '+m[2]+(m[3] or '')+';', policy)
mock = r'''
#include <algorithm>
#include <cctype>
#include <cfloat>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
#include <vector>
using string=std::string;
using ushort=unsigned short;
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
template<class...T>void Print(T...){}
int StringLen(string s){return s.size();}ushort StringGetCharacter(string s,int i){return s.at(i);}
void StringTrimLeft(string&s){s.erase(0,s.find_first_not_of(" \t\r\n"));}
void StringTrimRight(string&s){auto n=s.find_last_not_of(" \t\r\n");s=n==string::npos?"":s.substr(0,n+1);}
double StringToDouble(string s){return std::strtod(s.c_str(),nullptr);}
int StringSplit(string s,char delimiter,std::vector<string>&out){out.clear();size_t at=0;while(true){auto end=s.find(delimiter,at);out.push_back(s.substr(at,end==string::npos?end:end-at));if(end==string::npos)break;at=end+1;}return out.size();}
enum {SYMBOL_DIGITS,SYMBOL_POINT,SYMBOL_TRADE_TICK_SIZE};
long digits=2;double point=.01,tick=.01;bool available=true;
bool SymbolInfoInteger(string,int,long&out){out=digits;return available;}
bool SymbolInfoDouble(string,int property,double&out){out=property==SYMBOL_POINT?point:tick;return available;}
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathPow(double x,double y){return std::pow(x,y);}double MathAbs(double x){return std::abs(x);}
double MathRound(double x){return std::round(x);}double MathFloor(double x){return std::floor(x);}
double MathCeil(double x){return std::ceil(x);}double MathMax(double x,double y){return std::max(x,y);}
double MathMin(double x,double y){return std::min(x,y);}
double NormalizeDouble(double x,int d){double n=std::pow(10.,d);return std::round(x*n)/n;}
void StringToUpper(string &s){for(char &c:s)c=std::toupper(static_cast<unsigned char>(c));}
int StringFind(string s,string needle){auto p=s.find(needle);return p==string::npos?-1:int(p);}
'''
cases = r'''
int checks=0;void check(bool ok){++checks;if(!ok){std::cerr<<"Symbol units failure "<<checks<<"\n";std::exit(1);}}
void eq(double a,double b){check(std::abs(a-b)<1e-8);}
void quote(int d,double t){digits=d;point=std::pow(10.,-d);tick=t;available=true;}
int main(){
 double stop=0,distance=0;SMarcoSymbolUnits units;
 check(CMarcoSymbolUnits::Configure(""));
 // Same strategy distance for broker suffixes, prefixes and quote precisions.
 for(string symbol:{"US500","US500m","US500c","US500.cash","broker.US500m","us500m"})
 for(int d:{1,2,3}){
  quote(d,std::pow(10.,-d));check(CMarcoSymbolUnits::Load(symbol,units));eq(units.pip,.10);
  check(CMarcoSymbolUnits::Buffer(50,units.pip,distance));eq(distance,5);
  check(CMarcoSymbolUnits::BufferedStop(symbol,7608.48,50,false,stop));eq(stop,d==1?7613.5:7613.48);
  check(CMarcoSymbolUnits::BufferedStop(symbol,7608.48,50,true,stop));eq(stop,d==1?7603.4:7603.48);
 }
 // Tradable grid still controls rounding: never narrow the requested buffer.
 for(double grid:{.01,.05,.25,.50,1.0}){
  quote(2,grid);
  check(CMarcoSymbolUnits::BufferedStop("US500m",7608.48,50,false,stop));
  check(stop>=7613.48-1e-8);eq(stop/grid,std::round(stop/grid));
  check(CMarcoSymbolUnits::BufferedStop("US500m",7608.48,50,true,stop));
  check(stop<=7603.48+1e-8);eq(stop/grid,std::round(stop/grid));
 }
 // Existing unrelated-symbol conventions remain intact.
 quote(5,.00001);eq(CMarcoSymbolUnits::PipSize("EURUSDm"),.0001);
 quote(4,.0001);eq(CMarcoSymbolUnits::PipSize("EURUSD"),.0001);
 quote(3,.001);eq(CMarcoSymbolUnits::PipSize("USDJPYm"),.01);
 quote(2,.01);eq(CMarcoSymbolUnits::PipSize("USDJPY"),.01);
 eq(CMarcoSymbolUnits::PipSize("XAUUSDm"),.10);eq(CMarcoSymbolUnits::PipSize("XAGUSDm"),.01);
 eq(CMarcoSymbolUnits::PipSize("BTCUSDm"),.10);eq(CMarcoSymbolUnits::PipSize("UKOILc"),.01);
 // Each requested symbol: base name, both account suffixes and .cash, and
 // varying broker precision must preserve the same explicit strategy unit.
 struct Expected {string name;double pip;};
 std::vector<Expected> all={
  {"XAUUSD",.1},{"XAGUSD",.01},{"US30",1},{"US500",.1},{"USTEC",.1},{"USOIL",.01},{"UKOIL",.01},
  {"BTCUSD",.1},{"ETHUSD",.1},{"BCHUSD",.01},{"SOLUSD",.01},{"GER40",1},
  {"AUS200",.1},{"EU50",.1},{"FRA40",.1},{"HK50",1},{"JP225",1},{"N25",.1},{"SPN35",1},{"US2000",.1},
  {"XAUAUD",.1},{"XAUEUR",.1},{"XAGAUD",.01},{"XAGEUR",.01},{"XPDUSD",.1},{"XPTUSD",.1},{"XCUUSD",.01},
  {"EURCZK",.0001},{"EURHUF",.0001},{"EURNOK",.0001},{"EURPLN",.0001},{"USDCZK",.0001},
  {"USDHKD",.0001},{"USDHUF",.0001},{"USDILS",.0001},{"USDMXN",.0001},{"USDNOK",.0001},
  {"USDPLN",.0001},{"USDSEK",.0001},{"USDZAR",.0001},{"USDSGD",.0001},{"USDCNH",.0001}};
 check(all.size()==42);
 for(auto e:all)for(string suffix:{"","m","c",".cash"})for(int d:{2,3,4,5}){
  quote(d,std::pow(10.,-d));string name="broker."+e.name+suffix;
  check(CMarcoSymbolUnits::Load(name,units));eq(units.pip,e.pip);
  check(CMarcoSymbolUnits::Buffer(50,units.pip,distance));eq(distance,50*e.pip);
  for(bool buy:{false,true}){
   check(CMarcoSymbolUnits::BufferedStop(name,10000,50,buy,stop));
   check(buy?stop<=10000-distance+1e-8:stop>=10000+distance-1e-8);
   check(std::abs(stop/tick-std::round(stop/tick))<1e-5);
  }
 }
 quote(2,.01);check(CMarcoSymbolUnits::Configure(" US500=0.25 ; US500m=0.5 ; XAUUSD=0.01 "));
 eq(CMarcoSymbolUnits::PipSize("US500m"),.5);eq(CMarcoSymbolUnits::PipSize("US500c"),.25);
 eq(CMarcoSymbolUnits::PipSize("XAUUSDm"),.01);eq(CMarcoSymbolUnits::PipSize("XAUAUDm"),.1);
 check(CMarcoSymbolUnits::BufferedStop("US500m",7608.48,50,false,stop));eq(stop,7633.48);
 // Unknown broker instrument can receive a unit; malformed settings fail closed.
 check(CMarcoSymbolUnits::Configure("OTHER=2"));eq(CMarcoSymbolUnits::PipSize("OTHER.cash"),2);
 for(string bad:{"US500=0","US500=-1","US500=NaN","US500=.1abc","US500=1.2.3","US500","=0.1","US500=","US500=0.1;us500=1"}){
  check(!CMarcoSymbolUnits::Configure(bad));check(!CMarcoSymbolUnits::Load("US500m",units));
 }
 check(CMarcoSymbolUnits::Configure(""));eq(CMarcoSymbolUnits::PipSize("US500m"),.1);
 eq(CMarcoSymbolUnits::PipSize("US5000"),.01); // Not the US500 index.
 // Missing or invalid metadata and invalid buffers fail closed.
 available=false;check(!CMarcoSymbolUnits::BufferedStop("US500m",7608.48,50,false,stop));eq(stop,0);
 quote(2,.01);check(!CMarcoSymbolUnits::BufferedStop("US500m",7608.48,-50,false,stop));
 check(!CMarcoSymbolUnits::Buffer(std::numeric_limits<double>::quiet_NaN(),.1,distance));
 tick=0;check(!CMarcoSymbolUnits::Load("US500m",units));
 tick=.015;check(!CMarcoSymbolUnits::Load("US500m",units));
 quote(2,.01);point=.1;check(!CMarcoSymbolUnits::Load("US500m",units));
 std::cout<<"PASS: "<<checks<<" symbol-unit/buffer/stop-grid checks\n";
}
'''
# All three products must reach the shared implementation.
for name in ('marco_live_auto.mqh', 'marco_backtest.mqh'):
    source = (root/'Include/Custom/Marcotrades'/name).read_text(encoding='utf-8-sig')
    assert '#include <Custom\\Marcotrades\\symbol_units.mqh>' in source
    assert 'CMarcoSymbolUnits::BufferedStop(m_symbol, slReference, m_slBufferPips, isBull, slPx)' in source
indicator = (root/'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5').read_text(encoding='utf-8-sig')
assert '#include <Custom\\Marcotrades\\marco_backtest.mqh>' in indicator
for path in ('Experts/Custom EAs/Marcotrades/marco_live_auto_ea.mq5',
             'Experts/Custom EAs/Backtesting/marco_backtest_ea.mq5',
             'Indicators/Custom/Marcotrades/marco_backtest_trades.mq5'):
    source=(root/path).read_text(encoding='utf-8-sig')
    assert 'CMarcoSymbolUnits::Configure(InpPipSizeOverrides)' in source
with tempfile.TemporaryDirectory(prefix='marco_symbol_units_') as directory:
    cpp, binary = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    cpp.write_text(mock+policy+cases, encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe','-std=c++17','-O2',str(cpp),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
