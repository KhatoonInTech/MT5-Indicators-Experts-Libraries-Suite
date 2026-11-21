#ifndef MARCO_BROKER_EXECUTION_MQH
#define MARCO_BROKER_EXECUTION_MQH

struct SMarcoBrokerRejection
  {
   string symbol, lb;
   int tf, side;
   datetime minute;
   uint code;
   double volume;
  };

// Historical simulations replay observed decisions, never today's trade mode.
// Native records are account/server scoped. The explicitly selected import file
// may contain unscoped records from a user-supplied log (server empty/account 0).
class CMarcoBrokerExecution
  {
private:
   static SMarcoBrokerRejection records[];
   static string keys[];
   static string lastWritten;
   static bool enabled;
   static uint digest;

   static uint Hash(string value, uint seed=2166136261)
     {
      for(int i=0;i<StringLen(value);i++) { seed^=(uint)StringGetCharacter(value,i); seed*=16777619; }
      return seed;
     }
   static bool LoadFile(string path, bool imported)
     {
      if(path=="" || !FileIsExist(path)) return true;
      int file=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,0,CP_UTF8);
      if(file==INVALID_HANDLE) { PrintFormat("[BROKER REPLAY ERROR] Cannot read %s",path); return false; }
      bool ok=true;
      while(!FileIsEnding(file))
        {
         string line=FileReadString(file);
         if(line=="" || StringFind(line,"version;")==0 || StringFind(line,"#")==0) continue;
         string cells[];
         if(StringSplit(line,';',cells)!=10 || cells[0]!="1") { ok=false; break; }
         string server=cells[1]; long account=StringToInteger(cells[2]);
         if(!(imported && server=="" && account==0) &&
            (server!=AccountInfoString(ACCOUNT_SERVER) || account!=AccountInfoInteger(ACCOUNT_LOGIN))) continue;
         SMarcoBrokerRejection r;
         r.symbol=cells[3]; r.tf=(int)StringToInteger(cells[4]); r.lb=cells[5];
         r.side=(int)StringToInteger(cells[6]); r.minute=(datetime)StringToInteger(cells[7]);
         r.code=(uint)StringToInteger(cells[8]); r.volume=StringToDouble(cells[9]);
         if(r.symbol=="" || r.lb=="" || r.tf<=0 || MathAbs(r.side)!=1 || r.minute<=0 || r.minute%60!=0 ||
            !Supported(r.code) || !MathIsValidNumber(r.volume) || r.volume<0 ||
            (VolumeSpecific(r.code) && r.volume<=0)) { ok=false; break; }
         if(!VolumeSpecific(r.code)) r.volume=0;
         string key=Key(r);
         bool duplicate=false;
         for(int i=0;i<ArraySize(keys);i++) if(keys[i]==key) { duplicate=true; break; }
         if(duplicate) continue;
         int n=ArraySize(records); ArrayResize(records,n+1); ArrayResize(keys,n+1);
         records[n]=r; keys[n]=key; digest=Hash(key,digest);
        }
      FileClose(file);
      if(!ok) PrintFormat("[BROKER REPLAY ERROR] Invalid rejection record in %s; simulation cancelled.",path);
      return ok;
     }
   static string Key(const SMarcoBrokerRejection &r)
     {
      return r.symbol+"|"+IntegerToString(r.tf)+"|"+r.lb+"|"+IntegerToString(r.side)+"|"+
             IntegerToString((long)r.minute)+"|"+IntegerToString(r.code)+"|"+DoubleToString(r.volume,8);
     }
public:
   static bool VolumeSpecific(uint code)
     { return code==TRADE_RETCODE_INVALID_VOLUME || code==TRADE_RETCODE_LIMIT_VOLUME; }
   static bool Supported(uint code)
     {
      return VolumeSpecific(code) || code==TRADE_RETCODE_TRADE_DISABLED || code==TRADE_RETCODE_MARKET_CLOSED ||
             code==TRADE_RETCODE_LONG_ONLY || code==TRADE_RETCODE_SHORT_ONLY || code==TRADE_RETCODE_CLOSE_ONLY;
     }
   static uint CurrentEntryCode(string symbol, bool buy)
     {
      long mode=0;
      // Missing metadata is not evidence of a broker rejection to record/replay.
      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,mode)) return 0;
      if(mode==SYMBOL_TRADE_MODE_DISABLED) return TRADE_RETCODE_TRADE_DISABLED;
      if(mode==SYMBOL_TRADE_MODE_CLOSEONLY) return TRADE_RETCODE_CLOSE_ONLY;
      if(mode==SYMBOL_TRADE_MODE_LONGONLY && !buy) return TRADE_RETCODE_LONG_ONLY;
      if(mode==SYMBOL_TRADE_MODE_SHORTONLY && buy) return TRADE_RETCODE_SHORT_ONLY;
      return 0;
     }
   static string NativePath()
     {
      return "marcotrades\\BrokerExecution\\rejections_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
             IntegerToString(Hash(AccountInfoString(ACCOUNT_SERVER)))+".csv";
     }
   static bool Configure(bool useRecorded, string importFile)
     {
      enabled=useRecorded; ArrayResize(records,0); ArrayResize(keys,0); digest=2166136261;
      if(!enabled) return true;
      if(!LoadFile(NativePath(),false) || !LoadFile(importFile,true)) return false;
      PrintFormat("[BROKER REPLAY] Loaded %d recorded rejections; exact symbol/TF/LB/entry-minute matching. Unrecorded attempts remain simulated.",ArraySize(records));
      return true;
     }
   static string Fingerprint()
     { return (enabled ? "on:" : "off:")+IntegerToString(digest)+":"+IntegerToString(ArraySize(records)); }
   static uint Rejection(string symbol, int tf, string lb, bool buy, datetime at, double volume, double step)
     {
      if(!enabled) return 0;
      datetime minute=at-at%60;
      for(int i=0;i<ArraySize(records);i++)
        {
         SMarcoBrokerRejection r=records[i];
         if(r.symbol!=symbol || r.tf!=tf || r.lb!=lb || r.side!=(buy ? 1 : -1) || r.minute!=minute) continue;
         if(VolumeSpecific(r.code) && MathAbs(r.volume-volume)>MathMax(1e-8,step*1e-6)) continue;
         return r.code;
        }
      return 0;
     }
   static bool Record(string symbol, int tf, string lb, bool buy, datetime at, uint code, double volume)
     {
      if(!Supported(code) || lb=="" || (VolumeSpecific(code) && volume<=0)) return true;
      SMarcoBrokerRejection r; r.symbol=symbol; r.tf=tf; r.lb=lb; r.side=buy ? 1 : -1;
      r.minute=at-at%60; r.code=code; r.volume=VolumeSpecific(code) ? volume : 0;
      string server=AccountInfoString(ACCOUNT_SERVER);
      string key=server+"|"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"|"+Key(r);
      if(key==lastWritten) return true;
      if(StringFind(server,";")>=0 || StringFind(symbol,";")>=0 || StringFind(lb,";")>=0) return false;
      FolderCreate("marcotrades"); FolderCreate("marcotrades\\BrokerExecution");
      int file=FileOpen(NativePath(),FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
      if(file==INVALID_HANDLE) return false;
      FileSeek(file,0,SEEK_END);
      string line="1;"+server+";"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+";"+symbol+";"+
                  IntegerToString(tf)+";"+lb+";"+IntegerToString(r.side)+";"+IntegerToString((long)r.minute)+";"+
                  IntegerToString(code)+";"+DoubleToString(r.volume,8)+"\r\n";
      bool ok=FileWriteString(file,line)>0; FileFlush(file); FileClose(file);
      if(ok) lastWritten=key;
      return ok;
     }
  };
SMarcoBrokerRejection CMarcoBrokerExecution::records[];
string CMarcoBrokerExecution::keys[];
string CMarcoBrokerExecution::lastWritten="";
bool CMarcoBrokerExecution::enabled=false;
uint CMarcoBrokerExecution::digest=2166136261;
#endif
