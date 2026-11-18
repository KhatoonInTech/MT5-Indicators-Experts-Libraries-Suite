"""Test the production rejection replay/recorder and supplied-log importer; no MT5 orders."""
from pathlib import Path
import importlib.util, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('broker_import', root/'Tools/Marcotrades/import_broker_rejections.py')
imp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(imp)
sample = '''MS 0 00:00:03.816 EA Fresh daily journal initiated for 2026.11.12
DG 0 02:34:00.313 EA [M1 CONFIRMED] US500m PERIOD_M3 LB=LB_BEAR_1794449880 pivot=2026.11.12 02:32:00 price=7607.06 confirmed=2026.11.12 02:34:00
RR 0 02:34:00.428 EA [ENTRY RESULT] US500m: sent=false code=10014 deal=0 volume=1000.00000000 too big volume
RR 0 02:34:05.428 EA [ENTRY RESULT] US500m: sent=false code=10014 deal=0 volume=1000.00000000 too big volume
LK 0 11:40:00.420 EA [M1 CONFIRMED] BTCXAUm PERIOD_M3 LB=LB_BULL_1794462840 pivot=2026.11.12 11:38:00 price=18.47335 confirmed=2026.11.12 11:40:00
IQ 0 11:40:00.420 EA [ORDER CHECK FAILED] BTCXAUm ORDER_TYPE_BUY: volume=20.00000000 code=10044 error=4756 Only position closing is allowed
IQ 0 11:40:05.420 EA [ORDER CHECK FAILED] BTCXAUm ORDER_TYPE_BUY: volume=18.00000000 code=10044 error=4756 Only position closing is allowed
IQ 0 11:40:10.420 EA [ENTRY RESULT] BTCXAUm: sent=true code=10009 deal=123 volume=1.76 ok
'''
rows = imp.parse_log(sample)
assert len(rows) == 2 and rows[0][-1] == 1000 and rows[1][-1] == 0
assert imp.timeframe('MN1') == 49153
try:
    imp.parse_log('EA 11:40:00 [ORDER CHECK FAILED] TEST ORDER_TYPE_BUY: volume=1 code=10044', '2026-11-12')
    raise AssertionError('Importer must not guess an unidentified LB')
except ValueError:
    pass

production = (root/'Include/Custom/Marcotrades/broker_execution.mqh').read_text(encoding='utf-8-sig')
production = re.sub(r'\b(\w+)\s+([\w:]+)\[\];', r'std::vector<\1> \2;', production)
production = re.sub(r'\blong\b', 'long long', production)
mock = r'''
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <map>
#include <sstream>
#include <iomanip>
#include <string>
#include <vector>
using string=std::string;using uint=unsigned int;using datetime=long long;
enum{FILE_READ=1,FILE_WRITE=2,FILE_TXT=4,FILE_ANSI=8,FILE_SHARE_READ=16,FILE_SHARE_WRITE=32,
 INVALID_HANDLE=-1,CP_UTF8=65001,SEEK_END=2,ACCOUNT_SERVER=101,ACCOUNT_LOGIN=102,SYMBOL_TRADE_MODE=103,
 SYMBOL_TRADE_MODE_DISABLED=0,SYMBOL_TRADE_MODE_LONGONLY=1,SYMBOL_TRADE_MODE_SHORTONLY=2,SYMBOL_TRADE_MODE_CLOSEONLY=3,SYMBOL_TRADE_MODE_FULL=4,
 TRADE_RETCODE_INVALID_VOLUME=10014,TRADE_RETCODE_LIMIT_VOLUME=10034,TRADE_RETCODE_TRADE_DISABLED=10017,
 TRADE_RETCODE_MARKET_CLOSED=10018,TRADE_RETCODE_LONG_ONLY=10042,TRADE_RETCODE_SHORT_ONLY=10043,TRADE_RETCODE_CLOSE_ONLY=10044};
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
double MathAbs(double x){return std::abs(x);}double MathMax(double x,double y){return std::max(x,y);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
int StringLen(string x){return x.size();}int StringGetCharacter(string x,int i){return (unsigned char)x.at(i);}
int StringFind(string x,string y){auto p=x.find(y);return p==string::npos?-1:int(p);}
int StringSplit(string s,char separator,std::vector<string>&out){out.clear();std::stringstream stream(s);string cell;while(std::getline(stream,cell,separator))out.push_back(cell);return out.size();}
long long StringToInteger(string s){return std::strtoll(s.c_str(),nullptr,10);}double StringToDouble(string s){return std::strtod(s.c_str(),nullptr);}
string IntegerToString(long long x){return std::to_string(x);}
string DoubleToString(double x,int n){std::ostringstream s;s<<std::fixed<<std::setprecision(n)<<x;return s.str();}
string server="Broker-A";long long login=42;int tradeMode=SYMBOL_TRADE_MODE_FULL;bool metadata=true;
string AccountInfoString(int){return server;}long long AccountInfoInteger(int){return login;}
bool SymbolInfoInteger(string,int,long long&mode){mode=tradeMode;return metadata;}
template<class...T>void PrintFormat(const char*,T...){}
std::map<string,string> files;
struct Handle{string path;size_t at=0;};std::map<int,Handle> handles;int nextHandle=0;
bool FileIsExist(string path){return files.count(path);}
int FileOpen(string path,int flags,int,int){if(!files.count(path)&&!(flags&FILE_WRITE))return INVALID_HANDLE;files.try_emplace(path,"");handles[++nextHandle]={path,0};return nextHandle;}
bool FileIsEnding(int f){auto&h=handles.at(f);return h.at>=files[h.path].size();}
string FileReadString(int f){auto&h=handles.at(f);auto&s=files[h.path];size_t end=s.find('\n',h.at);if(end==string::npos)end=s.size();string line=s.substr(h.at,end-h.at);h.at=std::min(end+1,s.size());if(!line.empty()&&line.back()=='\r')line.pop_back();return line;}
void FileClose(int f){handles.erase(f);}void FolderCreate(string){}void FileFlush(int){}
void FileSeek(int f,int,int){auto&h=handles.at(f);h.at=files[h.path].size();}
int FileWriteString(int f,string line){auto&h=handles.at(f);files[h.path]+=line;h.at=files[h.path].size();return line.size();}
'''
# SEEK_END is a C stdio macro; use the actual constant rather than redeclaring it.
mock = mock.replace('CP_UTF8=65001,SEEK_END=2,', 'CP_UTF8=65001,')
cases = r'''
int checks=0;void check(bool ok){++checks;if(!ok){std::cerr<<"Failed broker check "<<checks<<"\n";std::exit(1);}}
int main(){
 files["import.csv"]="version;server;account;symbol;tf;lb_id;side;minute;code;volume\n"
 "1;;0;BTCXAUm;3;LB_BULL_1794462840;1;1794483600;10044;0\n"
 "1;;0;BTCAUDm;3;LB_BULL_1794485160;1;1794486300;10044;0\n"
 "1;;0;US500m;3;LB_BEAR_1794449880;-1;1794450840;10014;1000\n";
 check(CMarcoBrokerExecution::Configure(true,"import.csv"));string original=CMarcoBrokerExecution::Fingerprint();
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"LB_BULL_1794462840",true,1794483600,1.76,.01)==10044);
 check(CMarcoBrokerExecution::Rejection("BTCAUDm",3,"LB_BULL_1794485160",true,1794486300,2,.01)==10044);
 check(CMarcoBrokerExecution::Rejection("US500m",3,"LB_BEAR_1794449880",false,1794450840,83.32,.01)==0);
 check(CMarcoBrokerExecution::Rejection("US500m",3,"LB_BEAR_1794449880",false,1794450840,1000,.01)==10014);
 // No whole-symbol blacklist, no invented history, no other size/direction/setup/TF/broker-symbol match.
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",15,"LB_BULL_1794462840",true,1794483600,1.76,.01)==0);
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"LB_BULL_1794462840",true,1794483660,1.76,.01)==0);
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"different",true,1794483600,1.76,.01)==0);
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"LB_BULL_1794462840",false,1794483600,1.76,.01)==0);
 check(CMarcoBrokerExecution::Rejection("BTCXAUc",3,"LB_BULL_1794462840",true,1794483600,1.76,.01)==0);
 // Current mode only governs LIVE entries; configure/replay never reads it.
 tradeMode=SYMBOL_TRADE_MODE_FULL;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==0);
 tradeMode=SYMBOL_TRADE_MODE_CLOSEONLY;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==10044);check(CMarcoBrokerExecution::CurrentEntryCode("TEST",false)==10044);
 tradeMode=SYMBOL_TRADE_MODE_LONGONLY;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==0);check(CMarcoBrokerExecution::CurrentEntryCode("TEST",false)==10042);
 tradeMode=SYMBOL_TRADE_MODE_SHORTONLY;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==10043);check(CMarcoBrokerExecution::CurrentEntryCode("TEST",false)==0);
 tradeMode=SYMBOL_TRADE_MODE_DISABLED;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==10017);
 check(CMarcoBrokerExecution::Rejection("UNRECORDED",3,"other",true,1794483600,1,.01)==0);
 metadata=false;check(CMarcoBrokerExecution::CurrentEntryCode("TEST",true)==0);metadata=true;
 // Automatic native recording is durable, account scoped and deduplicated.
 check(CMarcoBrokerExecution::Record("SELL",5,"LB_BEAR_100",false,1794486307,10044,20));
 string path=CMarcoBrokerExecution::NativePath(), saved=files[path];
 check(CMarcoBrokerExecution::Record("SELL",5,"LB_BEAR_100",false,1794486310,10044,16));check(files[path]==saved);
 check(CMarcoBrokerExecution::Configure(true,"import.csv"));check(CMarcoBrokerExecution::Fingerprint()!=original);
 check(CMarcoBrokerExecution::Rejection("SELL",5,"LB_BEAR_100",false,1794486300,.04,.01)==10044);
 check(CMarcoBrokerExecution::Record("NO",5,"LB_BEAR_100",false,1794486300,10012,20));check(files[path]==saved); // Timeout isn't a proven rejection.
 login=99;files[CMarcoBrokerExecution::NativePath()]=saved;check(CMarcoBrokerExecution::Configure(true,""));
 check(CMarcoBrokerExecution::Rejection("SELL",5,"LB_BEAR_100",false,1794486300,.04,.01)==0);
 login=42;server="Broker-B";files[CMarcoBrokerExecution::NativePath()]=saved;check(CMarcoBrokerExecution::Configure(true,""));
 check(CMarcoBrokerExecution::Rejection("SELL",5,"LB_BEAR_100",false,1794486300,.04,.01)==0);server="Broker-A";
 check(CMarcoBrokerExecution::Configure(false,"import.csv"));check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"LB_BULL_1794462840",true,1794483600,1.76,.01)==0);
 // Unscoped imports cannot enter the automatically loaded native journal.
 files[path]=files["import.csv"];check(CMarcoBrokerExecution::Configure(true,""));
 check(CMarcoBrokerExecution::Rejection("BTCXAUm",3,"LB_BULL_1794462840",true,1794483600,1.76,.01)==0);
 files["bad.csv"]="1;;0;truncated\n";check(!CMarcoBrokerExecution::Configure(true,"bad.csv"));
 // Repeated identical rows do not spuriously change the cache fingerprint.
 files[path]="";check(CMarcoBrokerExecution::Configure(true,"import.csv"));original=CMarcoBrokerExecution::Fingerprint();
 files["import.csv"]+="1;;0;BTCXAUm;3;LB_BULL_1794462840;1;1794483600;10044;0\n";
 check(CMarcoBrokerExecution::Configure(true,"import.csv"));check(CMarcoBrokerExecution::Fingerprint()==original);
 std::cout<<"PASS: "<<checks<<" broker replay/recording checks, plus log importer checks\n";
}
'''
# The production gate must precede trade creation. It must never mutate the
# balance or increment a win/loss count on the rejected branch.
back = (root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
gate = back.index('uint brokerRejection=')
create = back.index('int t_idx = ArraySize(m_trades);', gate)
branch = back[gate:back.index('double stopProfit', gate)]
assert gate < create and 'continue;' in branch and 'm_currentBalance' not in branch
with tempfile.TemporaryDirectory(prefix='marco_broker_execution_') as directory:
    cpp, binary = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    cpp.write_text(mock+production+cases, encoding='utf-8')
    subprocess.run([shutil.which('g++') or r'C:\MinGW\bin\g++.exe', '-std=c++17', '-O2', str(cpp), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
