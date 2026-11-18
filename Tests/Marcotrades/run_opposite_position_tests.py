"""Offline execution of the production overlap guards; no terminal orders."""
from pathlib import Path
import re, shutil, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
live=(root/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
back=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
policy=(root/'Include/Custom/Marcotrades/trade_rejection.mqh').read_text(encoding='utf-8-sig')
def method(text,name):
 start=re.search(r'   (?:static )?bool\s+'+name+r'\(',text).start()
 brace=text.index('{',start);end=brace+1;depth=1
 while depth:
  depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end]
start=back.index('            bool blockNewTrade = false;')
end=back.index('            if(blockNewTrade)',start)
guard=back[start:end].replace("m_sim.", "")
assert 'if(HasOppositePosition(isBull)) continue;' in live
send=method(live,'SendCheckedEntry')
assert send.count('if(HasOppositePosition(isBull)) return false;')==2
assert send.rindex('if(HasOppositePosition(isBull)) return false;')>send.rindex('OrderCheck(')
assert send.rindex('if(HasOppositePosition(isBull)) return false;')<send.index('trade.OrderSend(')
mock=r'''
#include <string>
#include <vector>
#include <iostream>
#include <cstdlib>
using string=std::string;using datetime=long long;using ulong=unsigned long;
enum {TIME_DATE=1,TIME_SECONDS=2,POSITION_SYMBOL=1,POSITION_TYPE=2,POSITION_TYPE_BUY=0,POSITION_TYPE_SELL=1,POSITION_VOLUME=3,POSITION_MAGIC=4};
string TimeToString(datetime,int){return "time";}string EnumToString(int){return "tf";}
template<class...T>void PrintFormat(T...){}
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
struct Trade {string symbol="S";bool isOpen=true;int direction=1;double openPrice=100,tpPrice=120;datetime openTime=100,closeTime=0;ulong ticket=1;};
struct Position {string symbol;int direction;double volume;long magic;ulong ticket;};
std::vector<Position> positions;int selected=-1;datetime clockNow=1000;
int PositionsTotal(){return positions.size();}
ulong PositionGetTicket(int i){selected=i;return positions[i].ticket;}
string PositionGetString(int){return positions[selected].symbol;}
long PositionGetInteger(int what){return what==POSITION_TYPE ? (positions[selected].direction==1?POSITION_TYPE_BUY:POSITION_TYPE_SELL) : positions[selected].magic;}
double PositionGetDouble(int){return positions[selected].volume;}
datetime TimeCurrent(){return clockNow;}
int checks=0;
#define CHECK(x) do{++checks;if(!(x)){std::cerr<<"Failure line "<<__LINE__<<": "<<#x<<"\n";std::exit(1);}}while(0)
'''
cpp=mock+'\nclass CTradeRejection {public:\n'+method(policy,'OppositeDirection')+method(policy,'Overlap')+'\n};\n'
cpp+='class Sim {public: string m_symbol="S";int m_tradeTF=3;bool m_allowOverlappingTrades=true;std::vector<Trade> m_trades,s_global_trades;bool blocked(bool isBull,datetime now,double price){std::vector<datetime> run_time={now};int i=0;double candidateBid=price,candidateAsk=price;\n'+guard+'\nreturn blockNewTrade;}};\n'
cpp+='class Live {public:string m_symbol="S";int m_tradeTF=3;datetime m_lastOppositeBlockTime=0;ulong m_lastOppositeBlockTicket=0;\n'+method(live,'HasOppositePosition')+'\n};\n'
cpp+=r'''
int main(){
 for(bool candidateBuy:{false,true})for(bool allow:{false,true})for(bool global:{false,true}){
  Sim s;s.m_allowOverlappingTrades=allow;Trade t;t.direction=candidateBuy?-1:1;t.tpPrice=t.direction==1?120:80;
  auto &trades=global?s.s_global_trades:s.m_trades;trades={t};
  // Opposing positions block even beyond 50% progress or TP, with/without overlap.
  for(double price:{80.,89.,90.,100.,110.,111.,120.}) CHECK(s.blocked(candidateBuy,150,price));
  trades[0].direction=candidateBuy?1:-1;trades[0].tpPrice=candidateBuy?120:80;
  CHECK(s.blocked(candidateBuy,150,100));
  CHECK(s.blocked(candidateBuy,150,candidateBuy?109.:91.));
  CHECK(s.blocked(candidateBuy,150,candidateBuy?110.:90.)==!allow);
  CHECK(s.blocked(candidateBuy,150,candidateBuy?115.:85.)==!allow);
  trades[0].tpPrice=100;CHECK(s.blocked(candidateBuy,150,100));
  if(global){
   trades[0]=t;trades[0].symbol="OTHER";CHECK(!s.blocked(candidateBuy,150,100));
   trades[0]=t;trades[0].closeTime=150;CHECK(!s.blocked(candidateBuy,150,100));
   trades[0].closeTime=149;CHECK(!s.blocked(candidateBuy,150,100));
   trades[0]=t;trades[0].openTime=151;CHECK(!s.blocked(candidateBuy,150,100));
  }else{trades[0]=t;trades[0].isOpen=false;CHECK(!s.blocked(candidateBuy,150,100));}
 }
 Live l;
 for(bool candidateBuy:{false,true})for(long magic:{0L,123L,999L})for(double lots:{0.01,0.1,1.0}){
  positions={{"S",candidateBuy?-1:1,lots,magic,7}};CHECK(l.HasOppositePosition(candidateBuy));
  positions[0].symbol="OTHER";CHECK(!l.HasOppositePosition(candidateBuy));
  positions[0].symbol="S";positions[0].direction=candidateBuy?1:-1;CHECK(!l.HasOppositePosition(candidateBuy));
  positions.push_back({"S",candidateBuy?-1:1,0.01,magic,8});CHECK(l.HasOppositePosition(candidateBuy));
  positions.clear();CHECK(!l.HasOppositePosition(candidateBuy));
 }
 std::cout<<"PASS: "<<checks<<" opposite-position checks\n";
}
'''
with tempfile.TemporaryDirectory(prefix='marco_opposite_') as td:
 p=Path(td)/'test.cpp';exe=Path(td)/'test.exe';p.write_text(cpp,encoding='utf-8')
 compiler=shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
 subprocess.run([compiler,'-std=c++17','-O2',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
 broken=cpp.replace('return openDirection == (candidateBull ? -1 : 1);','return false;')
 assert broken!=cpp
 p.write_text(broken,encoding='utf-8')
 subprocess.run([compiler,'-std=c++17','-O2',str(p),'-o',str(exe)],check=True)
 failure=subprocess.run([str(exe)],capture_output=True,text=True)
 assert failure.returncode!=0
 print('PASS: restoring the former missing-direction check fails regression')
