
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

#define MARCO_LOG_PROGRAM "compiled_ea"
#ifndef MARCO_DAILY_LOG_MQH
#define MARCO_DAILY_LOG_MQH
#ifndef MARCO_LOG_PROGRAM
#define MARCO_LOG_PROGRAM ""
#endif

// Logs use the host PC/VPS calendar date, not the strategy's historical window.
// One writer per file; different charts (or duplicate instances) cannot corrupt it.
class CMarcoDailyLog
  {
private:
   int handle;
   string day, stem, path;
   string programName, queued;
   bool started;
   ulong retryAfter;
   string SafeName(string value)
     {
      string invalid="\\/:*?\"<>|";
      for(int i=0;i<StringLen(invalid);i++)
         StringReplace(value,StringSubstr(invalid,i,1),"_");
      return value;
     }
public:
   CMarcoDailyLog():handle(INVALID_HANDLE),started(false),retryAfter(0) {}
   ~CMarcoDailyLog() { Close(); }
   void Close()
     {
      if(handle!=INVALID_HANDLE) { FileFlush(handle); FileClose(handle); }
      handle=INVALID_HANDLE;
     }
   string Path() { return path; }
   void Pulse()
     {
      // Global constructors can print before terminal metadata is ready.
      // Only OnInit/Start may establish the filename, never an early Print.
      if(!started || programName=="" || stem=="") return;
      string today=TimeToString(TimeLocal(),TIME_DATE);
      StringReplace(today,".","");
      if(today==day && handle!=INVALID_HANDLE) return;
      if(today==day && GetTickCount64()<retryAfter) return;
      Close(); day=today;
      FolderCreate("Logs");
      FolderCreate("Logs\\"+day);
      path="Logs\\"+day+"\\"+stem+".log";
      handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
      // Another copy of the same program can be attached to the same chart.
      if(handle==INVALID_HANDLE && FileIsExist(path))
        {
         stem=programName+"_"+SafeName(_Symbol)+"_"+ToString(ChartID())+"_"+ToString(GetTickCount64())+"_"+ToString(GetMicrosecondCount());
         path="Logs\\"+day+"\\"+stem+".log";
         handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
        }
      if(handle==INVALID_HANDLE)
        {
         retryAfter=GetTickCount64()+60000;
         Print("[DAILY LOG] Cannot open MQL5\\Files\\",path,". Terminal logging continues; retry in 60 seconds.");
         return;
        }
      FileSeek(handle,0,SEEK_END);
     }
   void Write(string message)
     {
      if(!started) { queued+=message+"\r\n"; return; }
      Pulse();
      if(handle==INVALID_HANDLE) return;
      string line=TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS)+" ["+_Symbol+","+EnumToString((ENUM_TIMEFRAMES)_Period)+"] "+message+"\r\n";
      if(FileWriteString(handle,line)==0)
        {
         Print("[DAILY LOG] Write failed: ",path,". Terminal logging continues.");
         Close(); retryAfter=GetTickCount64()+60000;
         return;
        }
      FileFlush(handle);
     }
   void Start()
     {
      string name=MARCO_LOG_PROGRAM;
      if(name=="") name=MQLInfoString(MQL_PROGRAM_NAME);
      name=SafeName(name);
      if(name=="")
        { Print("[DAILY LOG] Program name unavailable; no unnamed file will be created."); return; }
      if(!started || programName!=name)
        {
         Close(); programName=name; stem=name; day=""; retryAfter=0;
         started=true;
        }
      Pulse();
      Write("[LIFECYCLE] Started "+programName);
      if(queued!="") { string early=queued; queued=""; Write("[PRE-INIT MESSAGES]\r\n"+early); }
      Print("[DAILY LOG] MQL5\\Files\\",path);
     }
  };
CMarcoDailyLog g_marcoDailyLog;

template<typename T> string MarcoLogText(T value) { return ToString(value); }
string MarcoLogText(bool value) { return value ? "true" : "false"; }
string MarcoLogText(double value) { return StringFormat("%.16g",value); }
string MarcoLogText(float value) { return StringFormat("%.5g",value); }
string MarcoLogText(datetime value) { return TimeToString(value,TIME_DATE|TIME_SECONDS); }

// Overloads are generated below by Tools/instrument_daily_logging.py.
void MarcoDailyPrintFormat(string format) { string message=format; Print(message); g_marcoDailyLog.Write(message); }
template<typename T0>
void MarcoDailyPrint(T0 a0) { Print(a0); g_marcoDailyLog.Write(MarcoLogText(a0)); }
template<typename T0>
void MarcoDailyPrintFormat(string format,T0 a0) { string message=StringFormat(format,a0); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1>
void MarcoDailyPrint(T0 a0,T1 a1) { Print(a0,a1); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)); }
template<typename T0,typename T1>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1) { string message=StringFormat(format,a0,a1); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2) { Print(a0,a1,a2); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)); }
template<typename T0,typename T1,typename T2>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2) { string message=StringFormat(format,a0,a1,a2); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2,typename T3>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2,T3 a3) { Print(a0,a1,a2,a3); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)+MarcoLogText(a3)); }
template<typename T0,typename T1,typename T2,typename T3>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2,T3 a3) { string message=StringFormat(format,a0,a1,a2,a3); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2,typename T3,typename T4>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2,T3 a3,T4 a4) { Print(a0,a1,a2,a3,a4); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)+MarcoLogText(a3)+MarcoLogText(a4)); }
template<typename T0,typename T1,typename T2,typename T3,typename T4>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2,T3 a3,T4 a4) { string message=StringFormat(format,a0,a1,a2,a3,a4); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5) { Print(a0,a1,a2,a3,a4,a5); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)+MarcoLogText(a3)+MarcoLogText(a4)+MarcoLogText(a5)); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5) { string message=StringFormat(format,a0,a1,a2,a3,a4,a5); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5,typename T6>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5,T6 a6) { Print(a0,a1,a2,a3,a4,a5,a6); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)+MarcoLogText(a3)+MarcoLogText(a4)+MarcoLogText(a5)+MarcoLogText(a6)); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5,typename T6>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5,T6 a6) { string message=StringFormat(format,a0,a1,a2,a3,a4,a5,a6); Print(message); g_marcoDailyLog.Write(message); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5,typename T6,typename T7>
void MarcoDailyPrint(T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5,T6 a6,T7 a7) { Print(a0,a1,a2,a3,a4,a5,a6,a7); g_marcoDailyLog.Write(MarcoLogText(a0)+MarcoLogText(a1)+MarcoLogText(a2)+MarcoLogText(a3)+MarcoLogText(a4)+MarcoLogText(a5)+MarcoLogText(a6)+MarcoLogText(a7)); }
template<typename T0,typename T1,typename T2,typename T3,typename T4,typename T5,typename T6,typename T7>
void MarcoDailyPrintFormat(string format,T0 a0,T1 a1,T2 a2,T3 a3,T4 a4,T5 a5,T6 a6,T7 a7) { string message=StringFormat(format,a0,a1,a2,a3,a4,a5,a6,a7); Print(message); g_marcoDailyLog.Write(message); }

#define Print MarcoDailyPrint
#define PrintFormat MarcoDailyPrintFormat
#endif

int main(){
 program="";g_marcoDailyLog.Write("constructor message");check(opens==0);
 g_marcoDailyLog.Start();
 check(g_marcoDailyLog.Path()=="Logs\\20261115\\compiled_ea.log");
 check(files[g_marcoDailyLog.Path()].find("constructor message")!=string::npos);
 program="incorrect_runtime_name";date="2026.11.16";g_marcoDailyLog.Pulse();
 check(g_marcoDailyLog.Path()=="Logs\\20261116\\compiled_ea.log");
 std::cout<<checks<<" explicit program-name assertions passed\n";
}
