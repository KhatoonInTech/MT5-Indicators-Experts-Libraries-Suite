"""Compare actual live/backtest sizing functions with a fake broker. No MT5 orders."""
from pathlib import Path
import re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
engine = (root / 'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
methods = engine[engine.index('   static bool       EntryVolumeRejected('):engine.index('   void ObserveEntryClusters(')]
policy = (root / 'Include/Custom/Marcotrades/staged_tp.mqh').read_text(encoding='utf-8-sig')
risk_policy = (root / 'Include/Custom/Marcotrades/risk_capital.mqh').read_text(encoding='utf-8-sig')
back = (root / 'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
back_method = back[back.index('   double            CalculateLotSize('):back.index('   double            GetPipSize(')]
source = r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <string>
#include <vector>
using string=std::string;using uint=unsigned int;using ulong=unsigned long long;
using datetime=long long;using ENUM_ORDER_TYPE=int;
template<class T>void ZeroMemory(T&v){v=T{};}
double MathAbs(double x){return std::abs(x);}double MathFloor(double x){return std::floor(x);}
double MathCeil(double x){return std::ceil(x);}double MathRound(double x){return std::round(x);}
double MathMin(double x,double y){return std::min(x,y);}double MathMax(double x,double y){return std::max(x,y);}
double NormalizeDouble(double x,int d){double n=std::pow(10.,d);return std::round(x*n)/n;}
bool MathIsValidNumber(double x){return std::isfinite(x);}
enum {SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_MAX,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_LIMIT,
 POSITION_SYMBOL,POSITION_TYPE,POSITION_VOLUME,POSITION_TYPE_BUY,POSITION_TYPE_SELL,
 ORDER_SYMBOL,ORDER_TYPE,ORDER_VOLUME_CURRENT,ORDER_TYPE_BUY,ORDER_TYPE_SELL,
 ORDER_TYPE_BUY_LIMIT,ORDER_TYPE_BUY_STOP,ORDER_TYPE_BUY_STOP_LIMIT,
 ORDER_TYPE_SELL_LIMIT,ORDER_TYPE_SELL_STOP,ORDER_TYPE_SELL_STOP_LIMIT,ORDER_TYPE_CLOSE_BY,
 ACCOUNT_BALANCE,ACCOUNT_EQUITY,ACCOUNT_MARGIN,ACCOUNT_MARGIN_FREE,SYMBOL_FILLING_MODE,SYMBOL_FILLING_FOK,SYMBOL_TRADE_EXEMODE,
 SYMBOL_TRADE_EXECUTION_INSTANT,SYMBOL_TRADE_EXECUTION_REQUEST,ORDER_FILLING_FOK,TRADE_ACTION_DEAL,
 TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,TRADE_RETCODE_INVALID_VOLUME=10014,
 TRADE_RETCODE_NO_MONEY=10019,TRADE_RETCODE_LIMIT_VOLUME=10034,TRADE_RETCODE_CLOSE_ONLY=10044,
 TRADE_RETCODE_TIMEOUT=10012};
struct Exposure{string symbol;int type;double volume;};
std::vector<Exposure> positions,orders;int positionIndex=0,orderIndex=0;
double accountBalance=10000,accountEquity=10000,accountMargin=0;
int capitalShrinkAt=0;double capitalAfter=0;
double freeCash=10000,minimum=.01,maximum=1000,lotStep=.01,limit=0,valuePerPrice=100,marginPerLot=10;
double hiddenMargin=10,lossMultiplier=1;bool badMetadata=false,badSelection=false,badProfit=false;
int permissionCode=0,precheckCode=0,sendCode=TRADE_RETCODE_DONE,sends=0,checks=0,prechecks=0;
int shrinkAt=0;double afterShrink=0,lastSent=0,lastSL=0;
struct MqlTradeRequest{int action,type,deviation,type_filling;long long magic;string symbol,comment;double price,sl,tp,volume;};
struct MqlTradeResult{uint retcode=0;string comment;ulong order=0,deal=0;double volume=0,price=0;};
struct MqlTradeCheckResult{uint retcode=0;double margin_free=0;string comment;};
int PositionsTotal(){return positions.size();}int OrdersTotal(){return orders.size();}
ulong PositionGetTicket(int i){positionIndex=i;return badSelection?0:i+1;}
string PositionGetString(int){return positions.at(positionIndex).symbol;}
long long PositionGetInteger(int){return positions.at(positionIndex).type;}
double PositionGetDouble(int){return positions.at(positionIndex).volume;}
ulong OrderGetTicket(int i){orderIndex=i;return badSelection?0:i+1;}
string OrderGetString(int){return orders.at(orderIndex).symbol;}
long long OrderGetInteger(int){return orders.at(orderIndex).type;}
double OrderGetDouble(int){return orders.at(orderIndex).volume;}
double SymbolInfoDouble(string,int property){switch(property){case SYMBOL_VOLUME_MIN:return minimum;case SYMBOL_VOLUME_MAX:return maximum;case SYMBOL_VOLUME_STEP:return lotStep;default:return limit;}}
bool SymbolInfoDouble(string s,int property,double&out){out=SymbolInfoDouble(s,property);return !badMetadata;}
long long SymbolInfoInteger(string,int property){return property==SYMBOL_FILLING_MODE?SYMBOL_FILLING_FOK:SYMBOL_TRADE_EXECUTION_INSTANT;}
double AccountInfoDouble(int p){switch(p){case ACCOUNT_BALANCE:return accountBalance;case ACCOUNT_EQUITY:return accountEquity;case ACCOUNT_MARGIN:return accountMargin;default:return freeCash;}}
bool OrderCalcProfit(int type,string,double volume,double entry,double stop,double&out){
 out=(type==ORDER_TYPE_BUY?1:-1)*(stop-entry)*volume*valuePerPrice*(volume>minimum?lossMultiplier:1);return !badProfit;
}
bool OrderCalcMargin(int,string,double volume,double,double&out){out=volume*marginPerLot;return true;}
void ResetLastError(){}int GetLastError(){return 0;}string EnumToString(int t){return std::to_string(t);}
template<class...T>void PrintFormat(const char*,T...){}
template<class...T>string StringFormat(T...){return "";}
template<class...T>void Print(T...){}
bool OrderCheck(MqlTradeRequest&r,MqlTradeCheckResult&c){
 ++prechecks;if(shrinkAt==prechecks)freeCash=afterShrink;
 if(capitalShrinkAt==prechecks)accountBalance=accountEquity=accountMargin=capitalAfter;
 c.retcode=precheckCode;c.margin_free=freeCash-r.volume*hiddenMargin;
 if(c.margin_free<0)c.retcode=TRADE_RETCODE_NO_MONEY;
 return c.retcode==0 || c.retcode==TRADE_RETCODE_DONE;
}
class CTrade{public:void SetAsyncMode(bool){}
 bool OrderSend(MqlTradeRequest&r,MqlTradeResult&out){++sends;lastSent=r.volume;lastSL=r.sl;
  out.retcode=sendCode;if(sendCode!=TRADE_RETCODE_DONE)return false;
  out.deal=1;out.order=2;out.volume=r.volume;out.price=r.price;return true;}
};
class CTradeRejection{public:
 static bool SizingInputs(double f,double r,double s,double n,double x){return f>0&&r>0&&s>0&&n>0&&x>=n;}
 static bool CheckPassed(bool c,uint code){return c&&(code==0||code==TRADE_RETCODE_DONE);}
 static bool ReserveFits(double remaining,double f){return remaining+1e-8>=f*.1;}
 static bool MarginFits(double needed,double free){return needed<=free*.90;}
};
class CMarcoBrokerExecution{public:
 static uint CurrentEntryCode(string,bool){return permissionCode;}
 static bool Supported(uint code){return code==TRADE_RETCODE_INVALID_VOLUME||code==TRADE_RETCODE_LIMIT_VOLUME||code==TRADE_RETCODE_CLOSE_ONLY;}
};
'''
source += '\n' + risk_policy + '\n' + policy + '\nclass Engine{public:bool HasOppositePosition(bool){return false;} string m_symbol="TEST";long long m_magic=42;double m_riskPercent=2;\n' + methods + '\n};\n'
source += r'''
template<class T>int ArraySize(const std::vector<T>&a){return a.size();}
struct SimTrade{SMarcoTPPlan tpPlan{};bool isOpen=true;double lots=4,openPrice=100;int direction=1;};
class BackEngine{public:string m_symbol="TEST";double m_currentBalance=10000,m_riskPercent=2;std::vector<SimTrade> m_trades;
''' + back_method + '\n};\n'
source += r'''
void check(bool ok){++checks;if(!ok){std::cerr<<"Failure "<<checks<<"\n";std::exit(1);}}
void eq(double a,double b){if(std::abs(a-b)>1e-7)std::cerr<<"Expected "<<b<<" got "<<a<<"\n";check(std::abs(a-b)<1e-7);}
void reset(){CMarcoRiskCapital::Configure(RISK_CAPITAL_FREE_MARGIN);accountBalance=accountEquity=10000;accountMargin=0;capitalShrinkAt=0;capitalAfter=0;positions.clear();orders.clear();freeCash=10000;minimum=.01;maximum=1000;lotStep=.01;limit=0;valuePerPrice=100;
 marginPerLot=hiddenMargin=10;lossMultiplier=1;badMetadata=badSelection=badProfit=false;permissionCode=precheckCode=0;
 sendCode=TRADE_RETCODE_DONE;sends=prechecks=shrinkAt=0;afterShrink=lastSent=lastSL=0;}
int main(){Engine e;CTrade t;MqlTradeResult result;double lots,risk,margin,n,x,step,l,u,cap;
 for(bool buy:{false,true}){
  reset();double sl=buy?95:105;check(e.SendCheckedEntry(t,buy,100,sl,buy?110:90,"setup",lots,result));
  eq(lots,.4);eq(lastSL,sl);eq(lots*5*valuePerPrice,200); // 2% of free margin to FINAL buffered SL.
  reset();sl=buy?94:106;check(e.SendCheckedEntry(t,buy,100,sl,buy?110:90,"setup",lots,result));
  eq(lots,.32);check(lots*6*valuePerPrice<=200); // Wider SL -> smaller volume, quarter-grid down.
  reset();maximum=.31;check(e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));eq(lots,.28);
  reset();freeCash=900;check(!e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));eq(sends,0); // Cannot fund a minimum quarter.
  reset();limit=.5;positions={{"TEST",buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL,.1},{"TEST",buy?POSITION_TYPE_SELL:POSITION_TYPE_BUY,10},{"OTHER",buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL,20}};
  orders={{"TEST",buy?ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT,.04},{"TEST",buy?ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP,.04},{"TEST",buy?ORDER_TYPE_BUY_STOP_LIMIT:ORDER_TYPE_SELL_STOP_LIMIT,.04},{"OTHER",ORDER_TYPE_BUY,90},{"TEST",buy?ORDER_TYPE_SELL_LIMIT:ORDER_TYPE_BUY_LIMIT,90}};
  check(e.EntryVolumeLimits(buy,n,x,step,l,u,cap));eq(u,.22);eq(cap,.28);
  check(e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));eq(lots,.28);
  limit=.2;check(!e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));eq(sends,1);
 }
 // Unlimited aggregate volume still obeys the per-order maximum.
 reset();positions={{"TEST",POSITION_TYPE_BUY,2000}};check(e.EntryVolumeLimits(true,n,x,step,l,u,cap));eq(cap,1000);
 // Posted maximum 1000 but remaining directional capacity 40: send 40, not 1000.
 reset();e.m_riskPercent=25;freeCash=14165.70;valuePerPrice=.25;limit=100;positions={{"TEST",POSITION_TYPE_SELL,60}};
 check(e.SendCheckedEntry(t,false,7605.16,7607.56,7590.14,"US500",lots,result));eq(lots,40);
 // No hidden limit can be inferred from OrderCheck: propagate the server rejection.
 reset();e.m_riskPercent=25;freeCash=14165.70;valuePerPrice=.25;sendCode=TRADE_RETCODE_INVALID_VOLUME;
 check(!e.SendCheckedEntry(t,false,7605.16,7607.56,7590.14,"US500",lots,result));eq(sends,1);eq(lots,1000);
 check(Engine::EntryVolumeRejected(result.retcode));check(!Engine::EntryVolumeRejected(TRADE_RETCODE_TIMEOUT));
 // Preliminary invalid-volume/aggregate-volume failures reach the same caller guard.
 for(int code:{TRADE_RETCODE_INVALID_VOLUME,TRADE_RETCODE_LIMIT_VOLUME}){
  reset();precheckCode=code;check(!e.SendCheckedEntry(t,true,100,95,110,"setup",lots,result));check(Engine::EntryVolumeRejected(result.retcode));eq(sends,0);
 }
 // Record the actual rejected candidate after a margin-driven reduction, not the original risk size.
 for(bool buy:{false,true}){
  reset();e.m_riskPercent=2;hiddenMargin=40000;precheckCode=TRADE_RETCODE_INVALID_VOLUME;
  check(!e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));
  eq(lots,.2);eq(result.retcode,TRADE_RETCODE_INVALID_VOLUME);eq(sends,0);eq(prechecks,2);
  reset();permissionCode=TRADE_RETCODE_CLOSE_ONLY;lots=20;
  check(!e.SendCheckedEntry(t,buy,100,buy?95:105,110,"setup",lots,result));
  eq(lots,0);eq(result.retcode,TRADE_RETCODE_CLOSE_ONLY);eq(sends,0);eq(prechecks,0);
 }
 // Smaller risk on conversion/nonlinear candidate calculation, and insufficient margin.
 reset();e.m_riskPercent=2;lossMultiplier=2;
 check(e.SendCheckedEntry(t,true,100,95,110,"setup",lots,result));eq(lots,.2);
 reset();hiddenMargin=50000;check(e.SendCheckedEntry(t,true,100,95,110,"setup",lots,result));eq(lots,.16);
 // Free margin falling between initial calculation and final check never over-risks.
 reset();shrinkAt=1;afterShrink=1000;check(!e.SendCheckedEntry(t,true,100,95,110,"setup",lots,result));eq(sends,0);
 // Invalid inputs and unavailable account exposure fail closed.
 reset();badMetadata=true;eq(e.CalculateLotSize(true,100,95,risk,margin),0);
 reset();badSelection=true;positions={{"TEST",POSITION_TYPE_BUY,.1}};eq(e.CalculateLotSize(true,100,95,risk,margin),0);
 reset();badProfit=true;eq(e.CalculateLotSize(true,100,95,risk,margin),0);
 reset();freeCash=std::numeric_limits<double>::quiet_NaN();eq(e.CalculateLotSize(true,100,95,risk,margin),0);
 reset();eq(e.CalculateLotSize(true,100,105,risk,margin),0);eq(e.CalculateLotSize(false,100,95,risk,margin),0);
 // Sample valid lot grids: never round UP above the allowed cash risk or maximum.
 for(double grid:{.001,.01,.1,1.})for(int k=1;k<=40;k++){
  reset();lotStep=minimum=grid;maximum=k*grid;freeCash=10000+k*11;
  if(e.SendCheckedEntry(t,true,100,95,110,"setup",lots,result)){
   check(lots<=maximum+1e-9);check(lots*500<=freeCash*.02+1e-8);eq(lots/(4*grid),std::round(lots/(4*grid)));
  }else eq(sends,0);
 }
 // Equal prices, cash and broker specifications must produce equal live/simulated lots.
 for(bool buy:{false,true})for(double grid:{.001,.01,.1,1.})for(int k=1;k<=40;k++){
  reset();BackEngine b;lotStep=minimum=grid;maximum=k*grid;freeCash=10000+k*11;b.m_currentBalance=freeCash;
  bool sent=e.SendCheckedEntry(t,buy,100,buy?95:105,110,"compare",lots,result);
  eq(b.CalculateLotSize(buy,100,buy?95:105,100,100),sent?lots:0);
 }
 // Remaining 25% counts as one lot, not the original four, for BOTH capacity and margin.
 for(bool buy:{false,true}){
  reset();BackEngine b;b.m_currentBalance=10010;limit=1.28;
  SimTrade open;open.direction=buy?1:-1;open.tpPlan.remaining=.25;b.m_trades.push_back(open);
  positions={{"TEST",buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL,1}};
  check(e.SendCheckedEntry(t,buy,100,buy?95:105,110,"partial",lots,result));eq(lots,.28);
  eq(b.CalculateLotSize(buy,100,buy?95:105,100,100),lots);
  // A closed trade must not consume the directional allowance or margin.
  b.m_trades[0].isOpen=false;b.m_currentBalance=10000;eq(b.CalculateLotSize(buy,100,buy?95:105,100,100),.4);
  // Opposite-side exposure uses margin but not this direction's volume allowance.
  b.m_trades[0].isOpen=true;b.m_trades[0].direction=buy?-1:1;b.m_currentBalance=10010;limit=.31;
  eq(b.CalculateLotSize(buy,100,buy?95:105,100,100),.28);
 }
 // Realized balance already includes partial exits; floating P/L uses the remainder only.
 reset();BackEngine b;SimTrade open;open.openPrice=95;open.tpPlan.remaining=.25;b.m_trades.push_back(open);
 freeCash=10490;check(e.SendCheckedEntry(t,true,100,95,110,"profit",lots,result));eq(lots,.4);
 eq(b.CalculateLotSize(true,100,95,100,100),lots);
 open.openPrice=105;b.m_trades[0]=open;freeCash=9490;
 check(e.SendCheckedEntry(t,true,100,95,110,"loss",lots,result));eq(lots,.36);
 eq(b.CalculateLotSize(true,100,95,100,100),lots);
 // Historical sizing must ignore real account positions, pending orders and free margin.
 reset();BackEngine isolated;limit=.28;freeCash=1;positions={{"TEST",POSITION_TYPE_BUY,9999}};orders={{"TEST",ORDER_TYPE_BUY_LIMIT,9999}};
 eq(isolated.CalculateLotSize(true,100,95,100,100),.28);eq(sends,0);
 // Actual candidate-risk check (not only the minimum-volume estimate).
 reset();BackEngine nonlinear;lossMultiplier=2;check(e.SendCheckedEntry(t,true,100,95,110,"nonlinear",lots,result));
 eq(nonlinear.CalculateLotSize(true,100,95,100,100),lots);eq(lots,.2);
 // Margin affordability and existing 10% reserve agree with live for equal models.
 reset();BackEngine constrained;hiddenMargin=marginPerLot=50000;
 check(e.SendCheckedEntry(t,true,100,95,110,"margin",lots,result));eq(constrained.CalculateLotSize(true,100,95,100,100),lots);eq(lots,.16);
 // Spread loss is included in the simulator's post-entry reserve check.
 reset();BackEngine spread;spread.m_currentBalance=1000;spread.m_riskPercent=100;hiddenMargin=marginPerLot=40000;
 eq(spread.CalculateLotSize(true,101,95,100,101),0); // Minimum quarter cannot fit.
 // Invalid metadata, direction and non-finite calculation inputs fail closed.
 reset();BackEngine invalid;badMetadata=true;eq(invalid.CalculateLotSize(true,100,95,100,100),0);
 reset();badProfit=true;eq(invalid.CalculateLotSize(true,100,95,100,100),0);
 reset();eq(invalid.CalculateLotSize(true,100,105,100,100),0);
 invalid.m_currentBalance=std::numeric_limits<double>::quiet_NaN();eq(invalid.CalculateLotSize(true,100,95,100,100),0);
 // Four capital choices: live and historical account values must agree.
 for(bool buy:{false,true})for(auto mode:{RISK_CAPITAL_BALANCE,RISK_CAPITAL_EQUITY,RISK_CAPITAL_FREE_MARGIN,RISK_CAPITAL_MARGIN}){
  reset();check(CMarcoRiskCapital::Configure(mode));BackEngine selected;
  accountBalance=10000;accountEquity=12000;accountMargin=4000;freeCash=8000;
  marginPerLot=hiddenMargin=1000;
  SimTrade prior;prior.openPrice=95;prior.tpPlan.remaining=1;selected.m_trades.push_back(prior);
  double expected=mode==RISK_CAPITAL_BALANCE?.4:mode==RISK_CAPITAL_EQUITY?.48:mode==RISK_CAPITAL_FREE_MARGIN?.32:.16;
  check(e.SendCheckedEntry(t,buy,100,buy?95:105,110,"capital",lots,result));eq(lots,expected);
  eq(selected.CalculateLotSize(buy,100,buy?95:105,100,100),expected);
  // Actual risk never exceeds the selected budget and still respects free-margin reserve.
  check(lots*500<=CMarcoRiskCapital::LiveBase()*.02+1e-8);check(lots*marginPerLot<=freeCash*.9);
  // Simulations must not read the live capital value.
  accountBalance=accountEquity=accountMargin=freeCash=1;
  eq(selected.CalculateLotSize(buy,100,buy?95:105,100,100),expected);
 }
 // No used margin means no budget under MARGIN; do not silently substitute another basis.
 reset();check(CMarcoRiskCapital::Configure(RISK_CAPITAL_MARGIN));BackEngine noPositions;
 check(!e.SendCheckedEntry(t,true,100,95,110,"zero margin",lots,result));eq(sends,0);
 eq(noPositions.CalculateLotSize(true,100,95,100,100),0);
 // Any selected account value that falls during preflight is revalidated before sending.
 for(auto mode:{RISK_CAPITAL_BALANCE,RISK_CAPITAL_EQUITY,RISK_CAPITAL_MARGIN}){
  reset();check(CMarcoRiskCapital::Configure(mode));accountMargin=10000;capitalShrinkAt=1;capitalAfter=10;
  check(!e.SendCheckedEntry(t,true,100,95,110,"capital drop",lots,result));eq(sends,0);
 }
 // Selected capital falling during the FINAL OrderCheck is also caught.
 for(auto mode:{RISK_CAPITAL_BALANCE,RISK_CAPITAL_EQUITY,RISK_CAPITAL_FREE_MARGIN,RISK_CAPITAL_MARGIN}){
  reset();check(CMarcoRiskCapital::Configure(mode));accountMargin=10000;
  if(mode==RISK_CAPITAL_FREE_MARGIN){shrinkAt=2;afterShrink=1000;}
  else {capitalShrinkAt=2;capitalAfter=10;}
  check(!e.SendCheckedEntry(t,true,100,95,110,"final capital drop",lots,result));eq(sends,0);
 }
 // Invalid selection, invalid capital and invalid percentages cannot produce a risk budget.
 reset();check(!CMarcoRiskCapital::Configure((ENUM_MARCO_RISK_CAPITAL)99));
 for(double capital:{0.,-1.,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()})
  eq(CMarcoRiskCapital::Budget(capital,25),0);
 for(double percent:{0.,-1.,101.,std::numeric_limits<double>::quiet_NaN()})
  eq(CMarcoRiskCapital::Budget(10000,percent),0);
 eq(CMarcoRiskCapital::Budget(10000,25),2500);
 std::cout<<"PASS: "<<checks<<" live/backtest sizing checks (parity, buffered SL, remaining exposure, free margin, broker limits and risk validation)\n";
}
'''
# Verify the real entry caller consumes definite volume rejections, but retains its
# separate accepted/ambiguous-order guard. No changes to unrelated rejection rules.
assert 'CTradeRejection::ConsumeOrderResult(entryResult.retcode) || CMarcoBrokerExecution::Supported(entryResult.retcode)' in engine
source = re.sub(r'\blong\b', 'long long', source.replace('long long', 'long'))
with tempfile.TemporaryDirectory(prefix='marco_entry_sizing_') as directory:
    cpp, binary = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    cpp.write_text(source, encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe', '-std=c++17', '-O2', str(cpp), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
