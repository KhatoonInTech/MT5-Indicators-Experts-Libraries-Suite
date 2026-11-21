#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <vector>
using string=std::string;
using datetime=long long;
using ulong=unsigned long long;
using ENUM_TIMEFRAMES=int;
template<class T> void ZeroMemory(T &v){ v=T{}; }
bool MathIsValidNumber(double v){return std::isfinite(v);}
double MathAbs(double v){return std::abs(v);}
double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
double MathFloor(double v){return std::floor(v);}
double MathCeil(double v){return std::ceil(v);}
double NormalizeDouble(double v,int d){double n=std::pow(10.,d);return std::round(v*n)/n;}
string IntegerToString(long long n){return std::to_string(n);}
int StringLen(const string&s){return int(s.size());}
int StringFind(const string&s,const string&needle){auto pos=s.find(needle);return pos==string::npos?-1:int(pos);}
int StringGetCharacter(const string&s,int i){return (unsigned char)s.at(i);}
enum {FILE_WRITE=1,FILE_BIN=2,FILE_READ=4,FILE_REWRITE=8,FILE_UNICODE=16,INVALID_HANDLE=-1,
 ACCOUNT_LOGIN=10,POSITION_IDENTIFIER,POSITION_SL,POSITION_TP,POSITION_SYMBOL,POSITION_MAGIC,
 POSITION_VOLUME,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MIN,SYMBOL_TRADE_TICK_SIZE,SYMBOL_DIGITS,TERMINAL_TRADE_ALLOWED,MQL_TRADE_ALLOWED,
 ACCOUNT_TRADE_ALLOWED,ACCOUNT_TRADE_EXPERT,ORDER_STATE,ORDER_STATE_REJECTED,
 ORDER_STATE_CANCELED,ORDER_STATE_EXPIRED,TRADE_ACTION_DEAL,ORDER_TYPE_SELL,ORDER_TYPE_BUY,
 ORDER_FILLING_FOK,TRADE_RETCODE_DONE=100,TRADE_RETCODE_PLACED,TRADE_RETCODE_TIMEOUT,
 TRADE_RETCODE_CONNECTION,TRADE_RETCODE_DONE_PARTIAL,TRADE_RETCODE_REJECT};
struct MqlTick {double bid,ask;};
struct MqlTradeRequest {int action,type,type_filling,deviation; ulong position; long long magic; string symbol,comment; double price,volume;};
struct MqlTradeResult {ulong order; int retcode; double volume,price;};
struct MqlTradeCheckResult {int retcode;};
std::map<string,std::vector<char>> files;
struct Handle {string path; size_t offset;};
std::map<int,Handle> handles; int nextHandle=0;
bool FolderCreate(const string&){return true;}
int FileOpen(const string& path,int flags){
 if((flags&FILE_READ)&&!files.count(path))return INVALID_HANDLE;
 if(flags&FILE_WRITE)files[path].clear();
 handles[++nextHandle]={path,0};return nextHandle;
}
template<class T> void put(int f,T v){auto &h=handles.at(f);auto &b=files[h.path];size_t end=h.offset+sizeof v;b.resize(end);std::memcpy(b.data()+h.offset,&v,sizeof v);h.offset=end;}
template<class T> T get(int f){auto &h=handles.at(f);auto &b=files.at(h.path);assert(h.offset+sizeof(T)<=b.size());T v;std::memcpy(&v,b.data()+h.offset,sizeof v);h.offset+=sizeof v;return v;}
void FileWriteInteger(int f,int v){put<int32_t>(f,v);}
void FileWriteDouble(int f,double v){put(f,v);}
void FileWriteLong(int f,long long v){put<int64_t>(f,v);}
int FileReadInteger(int f){return get<int32_t>(f);}
double FileReadDouble(int f){return get<double>(f);}
long long FileReadLong(int f){return get<int64_t>(f);}
size_t FileTell(int f){return handles.at(f).offset;}
size_t FileSize(int f){return files.at(handles.at(f).path).size();}
unsigned int FileWriteString(int f,const string&s,int n){for(int i=0;i<n;i++)put<uint16_t>(f,(uint16_t)(unsigned char)s.at(i));return n*2;}
string FileReadString(int f,int n){string s;for(int i=0;i<n;i++)s+=(char)get<uint16_t>(f);return s;}
void FileFlush(int){}
void FileClose(int f){handles.erase(f);}
bool FileMove(const string&a,int,const string&b,int){files[b]=files.at(a);files.erase(a);return true;}
double volume=4,sl=90,tp=130,bid=100,ask=100,step=0.01;
ulong identifier=6000000000ULL,ticket=7000000000ULL;
long long magic=77;
int sends=0,mode=0; bool modifyAllowed=true,enabled=true,rejectSLOnly=false;
datetime clockNow=1000; MqlTradeRequest pending{};
int PositionsTotal(){return volume>0?1:0;}
ulong PositionGetTicket(int){return ticket;}
long long PositionGetInteger(int p){return p==POSITION_IDENTIFIER?identifier:magic;}
double PositionGetDouble(int p){return p==POSITION_SL?sl:(p==POSITION_TP?tp:volume);}
string PositionGetString(int){return "TEST";}
double SymbolInfoDouble(const string&,int){return step;}
long long SymbolInfoInteger(const string&,int){return 2;}
bool SymbolInfoTick(const string&,MqlTick&t){t.bid=bid;t.ask=ask;return true;}
long long AccountInfoInteger(int p){return p==ACCOUNT_LOGIN?42:enabled;}
bool TerminalInfoInteger(int){return enabled;}
bool MQLInfoInteger(int){return enabled;}
datetime TimeCurrent(){return clockNow;}
bool HistoryOrderSelect(ulong){return false;}
long long HistoryOrderGetInteger(ulong,int){return ORDER_STATE_REJECTED;}
datetime iTime(const string&,int,int){return 900;}
int PeriodSeconds(int){return 60;}
double iOpen(const string&,int,int){return 110;}
double iClose(const string&,int,int){return 109;}
template<class...T> void PrintFormat(const char*,T...){}
bool OrderCheck(const MqlTradeRequest&r,MqlTradeCheckResult&c){
 bool valid=r.volume>0&&r.volume<=volume+1e-9&&std::abs(r.volume/step-std::round(r.volume/step))<1e-7;
 c.retcode=valid?TRADE_RETCODE_DONE:TRADE_RETCODE_REJECT;return valid;
}
struct CTrade {
 int last=0; double lastPrice=0;
 void SetAsyncMode(bool){}
 bool PositionModify(ulong t,double stop,double target){assert(t==ticket);bool allowed=modifyAllowed && !(rejectSLOnly && std::abs(stop-sl)>1e-9);if(allowed){sl=stop;tp=target;}last=allowed?TRADE_RETCODE_DONE:TRADE_RETCODE_REJECT;return allowed;}
 bool PositionClose(ulong t){assert(t==ticket);lastPrice=bid;volume=0;last=TRADE_RETCODE_DONE;return true;}
 int ResultRetcode(){return last;}
 double ResultPrice(){return lastPrice;}
 bool OrderSend(const MqlTradeRequest&r,MqlTradeResult&out){
   assert(r.position==ticket);assert(r.magic==magic);assert(r.volume<=volume+1e-9);sends++;
   out.order=8000000000ULL+sends;out.price=r.price;
   if(mode==1){out.retcode=TRADE_RETCODE_REJECT;return false;}
   if(mode==2){pending=r;out.retcode=TRADE_RETCODE_TIMEOUT;return false;}
   volume-=r.volume;out.volume=r.volume;out.retcode=TRADE_RETCODE_DONE;return true;
 }
};
