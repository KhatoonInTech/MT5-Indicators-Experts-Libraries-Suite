
#include <vector>
#include <string>
#include <iostream>
#include <algorithm>
#include <random>
#include <cassert>
using string=std::string;
template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
struct Instance {string m_symbol;};
struct Scheduler {int m_total_instances;std::vector<Instance*> m_instances;
   std::vector<string> m_groupSymbols;
   std::vector<int> m_instanceGroup;
   std::vector<int> m_groupFirst;
   std::vector<int> m_groupNext;
   std::vector<bool> m_groupPrepared;
   std::vector<bool> m_groupOK;
   void BuildSymbolGroups()
     {
      ArrayResize(m_groupSymbols,0); ArrayResize(m_groupFirst,0);
      ArrayResize(m_instanceGroup,m_total_instances); ArrayResize(m_groupNext,m_total_instances);
      for(int i=m_total_instances-1;i>=0;i--)
        {
         int group=-1;
         for(int g=0;g<ArraySize(m_groupSymbols);g++)
            if(m_groupSymbols[g]==m_instances[i]->m_symbol) { group=g; break; }
         if(group<0)
           {
            group=ArraySize(m_groupSymbols); ArrayResize(m_groupSymbols,group+1); ArrayResize(m_groupFirst,group+1);
            m_groupSymbols[group]=m_instances[i]->m_symbol; m_groupFirst[group]=-1;
           }
         m_instanceGroup[i]=group; m_groupNext[i]=m_groupFirst[group]; m_groupFirst[group]=i;
        }
      ArrayResize(m_groupPrepared,ArraySize(m_groupSymbols)); ArrayResize(m_groupOK,ArraySize(m_groupSymbols));
     }
};
int main(){
 std::mt19937 rng(1927);int checks=0;
 for(int n=0;n<100;n++){
  Scheduler s;s.m_total_instances=n;std::vector<Instance> instances(n);
  for(int i=0;i<n;i++){instances[i].m_symbol="S"+std::to_string(rng()%11);s.m_instances.push_back(&instances[i]);}
  s.BuildSymbolGroups();
  for(int g=0;g<(int)s.m_groupSymbols.size();g++){
   std::vector<int>a,b;for(int i=0;i<n;i++)if(instances[i].m_symbol==s.m_groupSymbols[g])a.push_back(i);
   for(int i=s.m_groupFirst[g];i>=0;i=s.m_groupNext[i])b.push_back(i);
   assert(a==b);checks++;
  }
  if(!n)continue;
  for(int from=0;from<n;from++)for(int count:{1,15,n,n+15}){
   std::vector<string> old,newOrder;std::vector<bool> prepared(s.m_groupSymbols.size(),false);
   for(int k=0;k<count;k++){
    int index=(from+k)%n;string symbol=instances[index].m_symbol;
    if(std::find(old.begin(),old.end(),symbol)==old.end())old.push_back(symbol);
    int group=s.m_instanceGroup[index];assert(s.m_groupSymbols[group]==symbol);
    if(!prepared[group]){prepared[group]=true;newOrder.push_back(s.m_groupSymbols[group]);}
   }
   assert(old==newOrder);checks++;
  }
 }
 std::cout<<checks<<" symbol grouping and scan-order assertions passed\n";
}
