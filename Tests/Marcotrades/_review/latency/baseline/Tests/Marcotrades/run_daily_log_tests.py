"""Exercise the production logger with an in-memory MQL filesystem/clock.

No terminal is launched and no trading or account access is performed.
"""
from pathlib import Path
import re
import subprocess

root=Path(__file__).resolve().parents[2]
source=(root/'Include/Custom/General/daily_log.mqh').read_text(encoding='utf-8')
source=source.replace('(string)value','ToString(value)')
source=re.sub(r'\(string\)(ChartID|GetTickCount64|GetMicrosecondCount)\(\)',r'ToString(\1())',source)
mock=r'''
#include <string>
#include <map>
#include <set>
#include <iostream>
#include <cstdio>
#include <cstdlib>
using string=std::string;
using datetime=long long;
using ulong=unsigned long;
using ENUM_TIMEFRAMES=int;
const int INVALID_HANDLE=-1,FILE_READ=1,FILE_WRITE=2,FILE_TXT=4,FILE_ANSI=8,FILE_SHARE_READ=16,CP_UTF8=65001,SEEK_END_=2;
#undef SEEK_END
#define SEEK_END SEEK_END_
const int TIME_DATE=1,TIME_SECONDS=2,MQL_PROGRAM_NAME=1;
string _Symbol="XAUEURm",program="marco_backtest_trades",date="2026.11.15";
int _Period=1,nextHandle=1,prints=0,opens=0,flushes=0,failures=0;
unsigned long ticks=1;
std::map<string,string> files;
std::map<int,string> handles;
std::set<string> folders,locked;
bool deny=false,failWrite=false;
template<class T> string ToString(T v){return std::to_string(v);}
string ToString(string v){return v;}
string ToString(const char* v){return v;}
int StringLen(string s){return (int)s.size();}
string StringSubstr(string s,int start,int n){return s.substr(start,n);}
void StringReplace(string &s,string a,string b){size_t p=0;while((p=s.find(a,p))!=string::npos){s.replace(p,a.size(),b);p+=b.size();}}
datetime TimeLocal(){return 1;}
string TimeToString(datetime,int flags){return flags==TIME_DATE?date:date+" 12:34:56";}
unsigned long GetTickCount64(){return ticks;}
unsigned long GetMicrosecondCount(){return 99;}
string MQLInfoString(int){return program;}
long long ChartID(){return 123;}
string EnumToString(int){return "PERIOD_M1";}
void FolderCreate(string p){folders.insert(p);}
bool FileIsExist(string p){return files.count(p);}
int FileOpen(string p,int flags,int,int encoding){++opens;if(deny||locked.count(p))return -1; if(encoding!=CP_UTF8 || !(flags&FILE_READ) || !(flags&FILE_SHARE_READ))abort();files[p];locked.insert(p);handles[nextHandle]=p;return nextHandle++;}
void FileSeek(int,int,int){}
void FileClose(int h){locked.erase(handles.at(h));handles.erase(h);}
void FileFlush(int){++flushes;}
int FileWriteString(int h,string s){if(failWrite)return 0;files[handles.at(h)]+=s;return (int)s.size();}
template<class... T> void Print(T...){++prints;}
template<class T> T fmtarg(T v){return v;}
const char* fmtarg(string const& s){return s.c_str();}
template<class... T> string StringFormat(string fmt,T... args){char b[8192];std::snprintf(b,sizeof b,fmt.c_str(),fmtarg(args)...);return b;}
int checks=0;
void check(bool ok){++checks;if(!ok){std::cerr<<"Failed check "<<checks<<"\n";exit(1);}}
'''
tests=r'''
int main(){
 program="";g_marcoDailyLog.Write("early message");g_marcoDailyLog.Pulse();
 check(opens==0);g_marcoDailyLog.Start();check(opens==0);check(g_marcoDailyLog.Path()=="");
 program="marco_backtest_trades";
 g_marcoDailyLog.Start();
 string first=g_marcoDailyLog.Path();
 check(first=="Logs\\20261115\\marco_backtest_trades.log");
 check(files[first].find("early message")!=string::npos);
 check(folders.count("Logs\\20261115")==1);
 check(files[first].find("[LIFECYCLE] Started")!=string::npos);
 Print("Unicode ✅ ",42," ",true," ",1.25);
 check(files[first].find("Unicode ✅ 42 true 1.25")!=string::npos);
 PrintFormat("price=%.2f count=%d %s",1.234,2,string("ok"));
 check(files[first].find("price=1.23 count=2 ok")!=string::npos);
 check(files[first].find("[XAUEURm,PERIOD_M1]")!=string::npos);
 check(flushes>=3);
 int before=opens;g_marcoDailyLog.Pulse();check(opens==before);
 g_marcoDailyLog.Close();g_marcoDailyLog.Start();
 check(files[first].find("Unicode ✅")!=string::npos);
 CMarcoDailyLog duplicate;duplicate.Start();
 check(duplicate.Path()!=first);check(locked.count(first)==1);
 check(duplicate.Path().find("Logs\\20261115\\marco_backtest_trades_")==0);
 program="marco_live_auto_ea";
 CMarcoDailyLog other;other.Start();check(other.Path()!=first);
 check(other.Path().find("marco_live_auto_ea")!=string::npos);
 program="marco_backtest_trades";
 date="2026.11.16";g_marcoDailyLog.Pulse();
 check(g_marcoDailyLog.Path().find("20261116")!=string::npos);
 check(locked.count(first)==0);
 Print("next day");check(files[g_marcoDailyLog.Path()].find("next day")!=string::npos);
 check(files[first].find("next day")==string::npos);
 date="2026.11.17";deny=true;before=prints;Print("still terminal");
 check(prints>before);before=opens;g_marcoDailyLog.Pulse();check(opens==before);
 deny=false;ticks+=60001;Print("recovered");
 check(files[g_marcoDailyLog.Path()].find("recovered")!=string::npos);
 failWrite=true;before=prints;Print("disk full");check(prints>before);
 failWrite=false;ticks+=60001;Print("disk recovered");
 check(files[g_marcoDailyLog.Path()].find("disk recovered")!=string::npos);
 std::cout<<checks<<" daily logging assertions passed\n";
}
'''
out=root/'Tests/Marcotrades/_review'
out.mkdir(exist_ok=True)
cpp=out/'daily_log_test.cpp';exe=out/'daily_log_test.exe'
cpp.write_text(mock+source+tests,encoding='utf-8')
subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17',str(cpp),'-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)

# The root program's explicit name wins even when MT5 metadata is empty/wrong.
explicit=r'''
int main(){
 program="";g_marcoDailyLog.Write("constructor message");check(opens==0);
 g_marcoDailyLog.Start();
 check(g_marcoDailyLog.Path()=="Logs\\20261115\\compiled_ea.log");
 check(files[g_marcoDailyLog.Path()].find("constructor message")!=string::npos);
 program="incorrect_runtime_name";date="2026.11.16";g_marcoDailyLog.Pulse();
 check(g_marcoDailyLog.Path()=="Logs\\20261116\\compiled_ea.log");
 std::cout<<checks<<" explicit program-name assertions passed\n";
}
'''
cpp=out/'daily_log_explicit_name.cpp';exe=out/'daily_log_explicit_name.exe'
cpp.write_text(mock+'\n#define MARCO_LOG_PROGRAM "compiled_ea"\n'+source+explicit,encoding='utf-8')
subprocess.run([r'C:\MinGW\bin\g++.exe','-std=c++17',str(cpp),'-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)

programs=list((root/'Experts/Custom EAs').rglob('*.mq5'))+list((root/'Indicators/Custom').rglob('*.mq5'))
for program in programs:
    text=program.read_text(encoding='utf-8-sig')
    assert text.startswith('#define MARCO_LOG_PROGRAM "'+program.stem+'"'),program
    assert '#include <Custom\\General\\daily_log.mqh>' in text,program
    assert 'g_marcoDailyLog.Start();' in text,program
print(f'{len(programs)} custom programs wired to daily logging')
