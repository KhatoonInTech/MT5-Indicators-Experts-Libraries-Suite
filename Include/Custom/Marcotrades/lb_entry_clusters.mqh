// Entry-only, same-symbol/same-direction LB cluster memory.
// Price intervals are inclusive. Types and setup timeframes do not split a cluster.
#ifndef MARCO_LB_ENTRY_CLUSTERS_MQH
#define MARCO_LB_ENTRY_CLUSTERS_MQH
struct SMarcoLBClusterNode
  {
   string symbol, id;
   int tf, side, group;
   datetime day, usedAt, formed;
   datetime opposingRejectedAt, freshQualifiedAt;
   double low, high;
   bool mitigated, retired;
  };

class CMarcoLBEntryClusters
  {
public:
   SMarcoLBClusterNode nodes[];
   void Clear() { ArrayResize(nodes,0); }
   static datetime Day(datetime at) { return at-at%86400; }
   int Find(string symbol,int tf,string id,datetime day)
     {
      for(int i=ArraySize(nodes)-1;i>=0;i--)
         if(nodes[i].symbol==symbol && nodes[i].tf==tf && nodes[i].id==id && nodes[i].day==day) return i;
      return -1;
     }
   void RetireCompleted()
     {
      // Keep mitigated members as connecting boundaries until ALL members expire.
      for(int i=0;i<ArraySize(nodes);i++)
        {
         if(nodes[i].retired) continue;
         bool active=false;
         for(int j=0;j<ArraySize(nodes);j++)
            if(!nodes[j].retired && nodes[j].group==nodes[i].group && !nodes[j].mitigated) { active=true; break; }
         if(!active)
           {
            int group=nodes[i].group;
            for(int j=0;j<ArraySize(nodes);j++) if(nodes[j].group==group) nodes[j].retired=true;
           }
        }
     }
   void Observe(string symbol,int tf,string id,int side,double low,double high,datetime now,bool mitigated,datetime formed=0,datetime freshQualifiedAt=0)
     {
      if(symbol=="" || id=="" || MathAbs(side)!=1 || !MathIsValidNumber(low) || !MathIsValidNumber(high) || low>high) return;
      datetime day=Day(now);
      int n=Find(symbol,tf,id,day);
      if(n>=0 && nodes[n].retired) return; // Never resurrect the same expired setup.
      if(n>=0 && mitigated) { nodes[n].mitigated=true; return; }
      if(n<0 && mitigated) return;
      // Caller applies ALL mitigation updates before adding the newly confirmed LBs.
      if(n<0)
        {
         n=ArraySize(nodes); ArrayResize(nodes,n+1);
         nodes[n].symbol=symbol; nodes[n].tf=tf; nodes[n].id=id; nodes[n].side=side;
         nodes[n].day=day; nodes[n].group=n; nodes[n].usedAt=0; nodes[n].formed=formed>0 ? formed : now;
         nodes[n].opposingRejectedAt=0; nodes[n].freshQualifiedAt=0;
         nodes[n].mitigated=false; nodes[n].retired=false;
         nodes[n].low=low; nodes[n].high=high;
        }
      else
        {
         // A later expansion can join clusters; do not forget previously linked premises.
         nodes[n].low=MathMin(nodes[n].low,low); nodes[n].high=MathMax(nodes[n].high,high);
        }
      if(freshQualifiedAt>nodes[n].formed && freshQualifiedAt<=now)
         nodes[n].freshQualifiedAt=freshQualifiedAt;
      for(int i=0;i<ArraySize(nodes);i++)
        {
         if(i==n || nodes[i].retired || nodes[i].day!=day || nodes[i].symbol!=symbol || nodes[i].side!=side ||
            nodes[i].group==nodes[n].group || nodes[i].low>nodes[n].high || nodes[i].high<nodes[n].low) continue;
         int oldGroup=nodes[i].group, group=nodes[n].group;
         for(int j=0;j<ArraySize(nodes);j++) if(nodes[j].group==oldGroup) nodes[j].group=group;
        }
     }
   void RejectOpposing(string symbol,int tf,string id,datetime now)
     {
      int n=Find(symbol,tf,id,Day(now));
      if(n>=0 && !nodes[n].retired)
         nodes[n].opposingRejectedAt=MathMax(nodes[n].opposingRejectedAt,now);
     }
   bool Blocked(string symbol,int tf,string id,datetime now,string &source,datetime &used)
     {
      source=""; used=0;
      int n=Find(symbol,tf,id,Day(now));
      if(n<0 || nodes[n].retired) return false;
      for(int i=0;i<ArraySize(nodes);i++)
         if(!nodes[i].retired && nodes[i].group==nodes[n].group && nodes[i].usedAt>0 &&
            (used==0 || nodes[i].usedAt<used))
           { used=nodes[i].usedAt; source=IntegerToString(nodes[i].tf)+":"+nodes[i].id; }
      if(used>0) return true; // An actual trade/reservation always wins; never exempt it.
      datetime rejected=0; string rejectedSource="";
      for(int i=0;i<ArraySize(nodes);i++)
         if(!nodes[i].retired && nodes[i].group==nodes[n].group && nodes[i].opposingRejectedAt>rejected)
           { rejected=nodes[i].opposingRejectedAt; rejectedSource=IntegerToString(nodes[i].tf)+":"+nodes[i].id; }
      if(rejected<=0) return false;
      // Only a new IND setup with its own subsequent adjacent pair can enter.
      // Older members remain blocked even if they finish qualifying later.
      if(nodes[n].formed>rejected && nodes[n].freshQualifiedAt>nodes[n].formed &&
         nodes[n].freshQualifiedAt<=now && nodes[n].opposingRejectedAt==0) return false;
      source="OPPOSING_STRUCTURE_REJECTION:"+rejectedSource; used=rejected;
      return true;
     }
   bool Eligible(string symbol,int tf,string id,datetime now)
     {
      int n=Find(symbol,tf,id,Day(now));
      return n>=0 && !nodes[n].retired && !nodes[n].mitigated;
     }
   bool Consume(string symbol,int tf,string id,datetime now)
     {
      int n=Find(symbol,tf,id,Day(now));
      if(n<0 || nodes[n].retired || nodes[n].mitigated) return false;
      string source=""; datetime used=0;
      if(Blocked(symbol,tf,id,now,source,used)) return false;
      nodes[n].usedAt=now;
      return true;
     }
   void ReleaseReservation(string symbol,int tf,string id,datetime now)
     {
      int n=Find(symbol,tf,id,Day(now));
      if(n>=0 && nodes[n].usedAt==now) nodes[n].usedAt=0;
     }
  };
#endif
