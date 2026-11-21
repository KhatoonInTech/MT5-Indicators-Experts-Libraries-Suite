#ifndef MARCO_LB_ENTRY_CLUSTERS_LIVE_MQH
#define MARCO_LB_ENTRY_CLUSTERS_LIVE_MQH
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Marcotrades\lb_entry_clusters.mqh"

// One journal per account/server/symbol/broker day. Exclusive lock covers
// reservation, synchronous submission and release of a definitively rejected attempt.
class CMarcoLiveLBClusters
  {
private:
   int lock;
   string path, scope;
   static uint Hash(string text)
     { uint h=2166136261; for(int i=0;i<StringLen(text);i++) h=(h^(uint)StringGetCharacter(text,i))*16777619; return h; }
   bool WriteText(int f,string text)
     { int n=StringLen(text); return FileWriteInteger(f,n)==4 && (n==0 || FileWriteString(f,text,n)==(uint)(n*2)); }
   bool ReadText(int f,string &text)
     {
      if(FileTell(f)+4>FileSize(f)) return false;
      int n=FileReadInteger(f);
      if(n<0 || n>32768 || FileTell(f)+(ulong)n*2>FileSize(f)) return false;
      text=n>0 ? FileReadString(f,n) : "";
      return StringLen(text)==n;
     }
public:
   CMarcoLBEntryClusters book;
   CMarcoLiveLBClusters() { lock=INVALID_HANDLE; }
   ~CMarcoLiveLBClusters() { Close(); }
   void Close() { if(lock!=INVALID_HANDLE) FileClose(lock); lock=INVALID_HANDLE; }
   bool Open(string symbol,datetime now)
     {
      Close(); book.Clear();
      scope=AccountInfoString(ACCOUNT_SERVER)+"|"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"|"+symbol+"|"+IntegerToString((long)CMarcoLBEntryClusters::Day(now));
      path="marcotrades\\LiveEA\\LBClusters_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)Hash(scope))+"_"+IntegerToString((long)CMarcoLBEntryClusters::Day(now))+".bin";
      FolderCreate("marcotrades"); FolderCreate("marcotrades\\LiveEA");
      lock=FileOpen(path+".lock",FILE_READ|FILE_WRITE|FILE_BIN);
      if(lock==INVALID_HANDLE) return false;
      if(!FileIsExist(path)) return true;
      int f=FileOpen(path,FILE_READ|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) { Close(); return false; }
      string stored;
      bool ok=FileReadInteger(f)==0x4C424332 && ReadText(f,stored) && stored==scope;
      int count=ok ? FileReadInteger(f) : -1;
      ok=ok && count>=0 && count<=100000 && ArrayResize(book.nodes,count)==count;
      for(int i=0;i<count && ok;i++)
        {
         SMarcoLBClusterNode n;
         ok=ReadText(f,n.symbol) && ReadText(f,n.id);
         if(!ok || FileTell(f)+54>FileSize(f)) { ok=false; break; }
         n.tf=FileReadInteger(f); n.side=FileReadInteger(f); n.group=FileReadInteger(f);
         n.day=(datetime)FileReadLong(f); n.usedAt=(datetime)FileReadLong(f); n.formed=(datetime)FileReadLong(f);
         n.low=FileReadDouble(f); n.high=FileReadDouble(f);
         n.mitigated=FileReadInteger(f,CHAR_VALUE)!=0; n.retired=FileReadInteger(f,CHAR_VALUE)!=0;
         ok=n.symbol==symbol && n.day==CMarcoLBEntryClusters::Day(now) && n.tf>0 && n.id!="" &&
            MathAbs(n.side)==1 && n.group>=0 && n.group<count && n.usedAt>=0 && n.formed>=n.day && n.formed<=now &&
            MathIsValidNumber(n.low) && MathIsValidNumber(n.high) && n.low<=n.high;
         book.nodes[i]=n;
        }
      if(ok) ok=FileReadInteger(f)==0x454E4443 && FileTell(f)==FileSize(f);
      FileClose(f);
      if(!ok) { PrintFormat("[LB CLUSTER STATE ERROR] %s: unreadable cluster journal; new entries blocked.",path); Close(); }
      return ok;
     }
   bool Save()
     {
      if(lock==INVALID_HANDLE) return false;
      string temp=path+".tmp";
      int f=FileOpen(temp,FILE_WRITE|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      bool ok=FileWriteInteger(f,0x4C424332)==4 && WriteText(f,scope) && FileWriteInteger(f,ArraySize(book.nodes))==4;
      for(int i=0;i<ArraySize(book.nodes) && ok;i++)
        {
         SMarcoLBClusterNode n=book.nodes[i];
         ok=WriteText(f,n.symbol) && WriteText(f,n.id) &&
            FileWriteInteger(f,n.tf)==4 && FileWriteInteger(f,n.side)==4 && FileWriteInteger(f,n.group)==4 &&
            FileWriteLong(f,(long)n.day)==8 && FileWriteLong(f,(long)n.usedAt)==8 && FileWriteLong(f,(long)n.formed)==8 &&
            FileWriteDouble(f,n.low)==8 && FileWriteDouble(f,n.high)==8 &&
            FileWriteInteger(f,n.mitigated ? 1 : 0,CHAR_VALUE)==1 && FileWriteInteger(f,n.retired ? 1 : 0,CHAR_VALUE)==1;
        }
      if(ok) ok=FileWriteInteger(f,0x454E4443)==4;
      FileFlush(f); FileClose(f);
      if(ok) ok=FileMove(temp,0,path,FILE_REWRITE);
      if(!ok) PrintFormat("[LB CLUSTER STATE ERROR] Cannot save %s; new entry withheld.",path);
      return ok;
     }
  };
#endif
