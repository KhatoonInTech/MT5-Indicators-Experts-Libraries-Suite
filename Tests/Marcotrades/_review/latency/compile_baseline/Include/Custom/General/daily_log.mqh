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
         stem=programName+"_"+SafeName(_Symbol)+"_"+(string)ChartID()+"_"+(string)GetTickCount64()+"_"+(string)GetMicrosecondCount();
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

template<typename T> string MarcoLogText(T value) { return (string)value; }
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
