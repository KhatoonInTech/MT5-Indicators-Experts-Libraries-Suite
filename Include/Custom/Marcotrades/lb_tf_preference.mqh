// Entry admission only: prefer a deeper, overlapping, qualified lower-TF setup.
// Snapshots are private to this EA/indicator and contain no future replay state.
#ifndef MARCO_LB_TF_PREFERENCE_MQH
#define MARCO_LB_TF_PREFERENCE_MQH
struct SMarcoLBTFChoice
  {
   string symbol,id;
   ENUM_TIMEFRAMES tf;
   bool bull;
   double low,high;
   datetime available,day;
  };

class CMarcoLBTFPreference
  {
private:
   static bool enabled;
   static SMarcoLBTFChoice choices[];
public:
   static void Configure(bool value) { enabled=value; Clear(); }
   static bool Enabled() { return enabled; }
   static void Clear() { ArrayResize(choices,0); }
   static void ResetOwner(string symbol,ENUM_TIMEFRAMES tf)
     {
      if(!enabled) return;
      int keep=0;
      for(int i=0;i<ArraySize(choices);i++)
         if(choices[i].symbol!=symbol || choices[i].tf!=tf) choices[keep++]=choices[i];
      ArrayResize(choices,keep);
     }
   static void Observe(string symbol,ENUM_TIMEFRAMES tf,string id,bool bull,
                       double low,double high,datetime available,datetime now)
     {
      if(!enabled || symbol=="" || id=="" || PeriodSeconds(tf)<=0 ||
         !MathIsValidNumber(low) || !MathIsValidNumber(high) || low>=high ||
         available<=0 || available>now || available<now-now%86400) return;
      int n=ArraySize(choices); ArrayResize(choices,n+1);
      choices[n].symbol=symbol; choices[n].tf=tf; choices[n].id=id; choices[n].bull=bull;
      choices[n].low=low; choices[n].high=high; choices[n].available=available;
      choices[n].day=now-now%86400;
     }
   static bool Preferred(string symbol,ENUM_TIMEFRAMES tf,bool bull,double low,double high,
                         datetime now,SMarcoLBTFChoice &choice)
     {
      if(!enabled) return false;
      int best=-1,seconds=PeriodSeconds(tf);
      for(int i=0;i<ArraySize(choices);i++)
        {
         SMarcoLBTFChoice candidate=choices[i];
         if(candidate.symbol!=symbol || candidate.bull!=bull || candidate.day!=now-now%86400 ||
            candidate.available>now || PeriodSeconds(candidate.tf)>=seconds) continue;
         // The entry-facing edge must be strictly inside the HTF interval.
         // The distal edge may be contained or extend beyond the HTF distal edge:
         // buy LTF low below HTF low; sell LTF high above HTF high.
         // Mere boundary contact and shallower overlaps do not defer.
         if(bull ? (candidate.high<=low || candidate.high>=high) :
                   (candidate.low<=low || candidate.low>=high)) continue;
         // Deterministic diagnostics; every matching higher TF is deferred.
         if(best<0 || PeriodSeconds(candidate.tf)<PeriodSeconds(choices[best].tf) ||
            (candidate.tf==choices[best].tf && candidate.available<choices[best].available)) best=i;
        }
      if(best<0) return false;
      choice=choices[best]; return true;
     }
  };
bool CMarcoLBTFPreference::enabled=false;
SMarcoLBTFChoice CMarcoLBTFPreference::choices[];
#endif
