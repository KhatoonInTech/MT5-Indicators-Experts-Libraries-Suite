"""Execute production LB cluster policy, durable journal and chronological scheduler offline."""
from pathlib import Path
import re, shutil, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
core=(root/'Include/Custom/Marcotrades/lb_entry_clusters.mqh').read_text(encoding='utf-8-sig')
journal=(root/'Include/Custom/Marcotrades/lb_entry_clusters_live.mqh').read_text(encoding='utf-8-sig')
back=(root/'Include/Custom/Marcotrades/marco_backtest.mqh').read_text(encoding='utf-8-sig')
live=(root/'Include/Custom/Marcotrades/marco_live_auto.mqh').read_text(encoding='utf-8-sig')
scheduler=back[back.index('struct SMarcoSimulationConfig'):back.index('// Static member instantiation')]
def adapt(s):
 s=re.sub(r'^#include.*$', '',s,flags=re.M)
 s=re.sub(r'\blong\b','long long',s)
 s=re.sub(r'(\w+)\s+(\w+)\[\];',r'std::vector<\1> \2;',s)
 s=s.replace('CMarcoBacktestInstance* &items[]','std::vector<CMarcoBacktestInstance*> &items')
 s=s.replace('instance.','instance->')
 s=re.sub(r'(items\[i\])\.',r'\1->',s)
 return s
mock=r'''
#include <string>
#include <vector>
#include <map>
#include <set>
#include <cmath>
#include <cstring>
#include <iostream>
#include <cstdlib>
#include <algorithm>
#include <cstdint>
using string=std::string;using datetime=long long;using ulong=unsigned long long;using uint=unsigned int;
template<class T> int ArraySize(const std::vector<T>&v){return v.size();}
template<class T> int ArrayResize(std::vector<T>&v,int n){v.resize(n);return n;}
template<class T>T MathAbs(T x){return std::abs(x);}
double MathMin(double a,double b){return std::min(a,b);}double MathMax(double a,double b){return std::max(a,b);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
string IntegerToString(long long x){return std::to_string(x);}
int StringLen(const string&s){return s.size();}int StringGetCharacter(const string&s,int i){return (unsigned char)s[i];}
template<class...T>void PrintFormat(T...){}
enum{INVALID_HANDLE=-1,FILE_READ=1,FILE_WRITE=2,FILE_BIN=4,FILE_UNICODE=8,FILE_REWRITE=16,CHAR_VALUE=1,ACCOUNT_SERVER=1,ACCOUNT_LOGIN=2,POINTER_DYNAMIC=1};
string server="broker";long long account=123;
string AccountInfoString(int){return server;}long long AccountInfoInteger(int){return account;}
std::map<string,std::vector<unsigned char>> files;
struct Handle{string path;size_t pos;};std::map<int,Handle> handles;int nextHandle=1;bool failWrites=false,failMove=false;
void FolderCreate(string){}bool FileIsExist(string p){return files.count(p);}
int FileOpen(string p,int mode){for(auto &h:handles)if(h.second.path==p)return -1;if(mode&FILE_WRITE){if(failWrites)return -1;if(!(mode&FILE_READ))files[p].clear();else if(!files.count(p))files[p]={};}else if(!files.count(p))return -1;int h=nextHandle++;handles[h]={p,0};return h;}
void FileClose(int h){handles.erase(h);}void FileFlush(int){}
size_t FileTell(int h){return handles.at(h).pos;}size_t FileSize(int h){return files.at(handles.at(h).path).size();}
template<class T> int write(int h,T x){auto &a=handles.at(h);auto &v=files[a.path];v.resize(std::max(v.size(),a.pos+sizeof(T)));std::memcpy(v.data()+a.pos,&x,sizeof(T));a.pos+=sizeof(T);return sizeof(T);}
template<class T>T read(int h){auto &a=handles.at(h);auto &v=files[a.path];if(a.pos+sizeof(T)>v.size())return T{};T x;std::memcpy(&x,v.data()+a.pos,sizeof(T));a.pos+=sizeof(T);return x;}
int FileWriteInteger(int h,int v,int size=4){return size==1?write<uint8_t>(h,v):write<int32_t>(h,v);}int FileReadInteger(int h,int size=4){return size==1?read<uint8_t>(h):read<int32_t>(h);}
int FileWriteLong(int h,long long v){return write<int64_t>(h,v);}long long FileReadLong(int h){return read<int64_t>(h);}
int FileWriteDouble(int h,double v){return write<double>(h,v);}double FileReadDouble(int h){return read<double>(h);}
int FileWriteString(int h,string s,int n){for(int i=0;i<n;i++)write<uint16_t>(h,s[i]);return 2*n;}
string FileReadString(int h,int n){string s;for(int i=0;i<n;i++)s+=(char)read<uint16_t>(h);return s;}
bool FileMove(string from,int,string to,int){if(failMove||!files.count(from))return false;files[to]=files[from];files.erase(from);return true;}
ulong ticks=0;bool stopped=false;ulong GetTickCount64(){return ++ticks;}bool IsStopped(){return stopped;}
template<class T>int CheckPointer(T*p){return p?POINTER_DYNAMIC:0;}
int checks=0;
#define CHECK(x) do{++checks;if(!(x)){std::cerr<<"FAIL line "<<__LINE__<<": "<<#x<<"\n";std::exit(1);}}while(0)
'''
mock_instance=r'''
struct Frame{datetime at;bool active=true,mitigated=false,entry=false;};
struct Context{int i=0;bool prepared=false;};
class CMarcoBacktestInstance {public:
 static CMarcoLBEntryClusters s_clusters;
 Context *m_sim=nullptr;bool m_simComplete=false,m_simFailed=false,failInit=false;
 int tf;string id;std::vector<Frame> frames;double lo=100,hi=110;int side=-1;
 int entries=0,prepares=0;std::vector<datetime> executed;
 CMarcoBacktestInstance(int t,string s,std::vector<Frame> f):tf(t),id(s),frames(f){}
 ~CMarcoBacktestInstance(){delete m_sim;}
 datetime NextSimulationTime(){return m_sim&&!m_simComplete?frames[m_sim->i].at:0;}
 void RegisterPreparedClusters(datetime now){if(m_sim&&m_sim->prepared){auto f=frames[m_sim->i];if(f.active&&!f.mitigated)s_clusters.Observe("S",tf,id,side,lo,hi,now,false);}}
 bool RunSimulation(bool,bool,int,double,bool,bool,double,bool,bool,bool,bool,bool,bool,datetime through,bool initialize,bool prepare){
  if(!m_sim)m_sim=new Context();
  if(initialize)return !failInit;
  auto f=frames[m_sim->i];CHECK(f.at==through);
  if(prepare){CHECK(!m_sim->prepared);++prepares;m_sim->prepared=true;if(f.mitigated)s_clusters.Observe("S",tf,id,side,lo,hi,through,true);return true;}
  CHECK(m_sim->prepared);m_sim->prepared=false;
  if(f.entry&&s_clusters.Consume("S",tf,id,through)){entries++;executed.push_back(through);}
  if(++m_sim->i==(int)frames.size()){m_simComplete=true;delete m_sim;m_sim=nullptr;}
  return true;
 }
};
CMarcoLBEntryClusters CMarcoBacktestInstance::s_clusters;
'''
cases=r'''
bool blocked(CMarcoLBEntryClusters &b,int tf,string id,datetime t=100){string s;datetime u;return b.Blocked("S",tf,id,t,s,u);}
void observe(CMarcoLBEntryClusters &b,int tf,string id,double lo,double hi,datetime at=100,bool mitigated=false,int side=-1){b.Observe("S",tf,id,side,lo,hi,at,mitigated);}
void pump(std::vector<CMarcoBacktestInstance*> v,int budget=1000){SMarcoSimulationConfig c{};int attempts=0;while(!CMarcoSimulationBatch::Pump(v,0,v.size(),c,budget))CHECK(++attempts<100);}
int main(){
 for(int side:{-1,1})for(int tf:{2,3,4,10,16385}){
  CMarcoLBEntryClusters b;observe(b,4,"IND",100,110,100,false,side);CHECK(b.Consume("S",4,"IND",100));
  for(auto range:std::vector<std::pair<double,double>>{{100,110},{102,108},{99,111},{105,120},{110,120},{90,100}}){
   string id="SSL_BSL"+std::to_string(b.nodes.size());observe(b,tf,id,range.first,range.second,101,false,side);CHECK(blocked(b,tf,id,101));CHECK(!b.Consume("S",tf,id,101));
  }
  observe(b,tf,"disjoint",200,210,101,false,side);CHECK(!blocked(b,tf,"disjoint"));
  observe(b,tf,"opposite",100,110,101,false,-side);CHECK(!blocked(b,tf,"opposite"));
  b.Observe("OTHER",tf,"IND",side,100,110,101,false);string src;datetime used;CHECK(!b.Blocked("OTHER",tf,"IND",101,src,used));
 }
 CMarcoLBEntryClusters b;
 observe(b,4,"first",100,110);CHECK(b.Consume("S",4,"first",100));
 observe(b,3,"second",108,120);observe(b,10,"third",119,130);CHECK(blocked(b,10,"third"));
 observe(b,4,"first",100,110,101,true);b.RetireCompleted();CHECK(blocked(b,3,"second"));CHECK(!b.Eligible("S",4,"first",101));
 observe(b,3,"second",108,120,102,true);b.RetireCompleted();CHECK(blocked(b,10,"third"));
 // Mitigated connecting members still connect the cluster until the final member expires.
 observe(b,2,"fourth",100,101,103);CHECK(blocked(b,2,"fourth"));
 observe(b,10,"third",119,130,104,true);b.RetireCompleted();CHECK(blocked(b,2,"fourth"));
 observe(b,2,"fourth",100,101,105,true);b.RetireCompleted();CHECK(!blocked(b,2,"fourth"));
 observe(b,4,"first",100,110,106);CHECK(!b.Eligible("S",4,"first",106));
 observe(b,5,"fresh",100,110,107);CHECK(b.Consume("S",5,"fresh",107));
 observe(b,5,"fresh",100,110,86400+1);CHECK(!blocked(b,5,"fresh",86401));CHECK(b.Consume("S",5,"fresh",86401));
 // Expansion and a later bridge merge previously separate components.
 b.Clear();observe(b,3,"A",100,110);observe(b,5,"B",120,130);CHECK(b.Consume("S",5,"B",100));
 observe(b,4,"bridge",110,120);CHECK(blocked(b,3,"A"));
 b.Clear();observe(b,3,"A",100,110);observe(b,5,"B",120,130);CHECK(b.Consume("S",5,"B",100));observe(b,3,"A",100,120);CHECK(blocked(b,3,"A"));
 b.Clear();observe(b,4,"rejected",100,110);CHECK(b.Consume("S",4,"rejected",100));b.ReleaseReservation("S",4,"rejected",101);CHECK(blocked(b,4,"rejected"));b.ReleaseReservation("S",4,"rejected",100);CHECK(!blocked(b,4,"rejected"));
 CHECK(b.Consume("S",4,"rejected",102));CHECK(!b.Consume("S",4,"missing",102));
 // Persistence, exclusive submission lock, rejection rollback, scope/day isolation, corruption.
 files.clear();CMarcoLiveLBClusters a,c;CHECK(a.Open("S",100));observe(a.book,4,"first",100,110);CHECK(a.book.Consume("S",4,"first",100));CHECK(a.Save());CHECK(!c.Open("S",100));a.Close();CHECK(c.Open("S",101));CHECK(blocked(c.book,4,"first",101));observe(c.book,3,"later",108,120,101);CHECK(blocked(c.book,3,"later",101));CHECK(c.Save());c.Close();
 CHECK(a.Open("S",102));observe(a.book,4,"first",100,110,102,true);a.book.RetireCompleted();CHECK(blocked(a.book,3,"later",102));CHECK(a.Save());a.Close();CHECK(c.Open("S",103));CHECK(blocked(c.book,3,"later",103));observe(c.book,3,"later",108,120,103,true);c.book.RetireCompleted();CHECK(c.Save());c.Close();CHECK(a.Open("S",104));observe(a.book,2,"fresh",100,110,104);CHECK(a.book.Consume("S",2,"fresh",104));a.book.ReleaseReservation("S",2,"fresh",104);CHECK(a.Save());a.Close();CHECK(c.Open("S",105));CHECK(!blocked(c.book,2,"fresh",105));c.Close();
 CHECK(a.Open("S",86401));CHECK(a.book.nodes.empty());a.Close();account++;CHECK(a.Open("S",105));CHECK(a.book.nodes.empty());a.Close();account--;server="other";CHECK(a.Open("S",105));CHECK(a.book.nodes.empty());a.Close();server="broker";
 string state;for(auto &f:files)if(f.first.size()>4&&f.first.substr(f.first.size()-4)==".bin")state=f.first;
 auto good=files[state];files[state].pop_back();CHECK(!a.Open("S",106));files[state]=good;
 files[state][0]^=1;CHECK(!a.Open("S",106));files[state]=good;
 CHECK(a.Open("S",106));failMove=true;CHECK(!a.Save());failMove=false;a.Close();CHECK(c.Open("S",106));c.Close();
 // Scheduler gives the earliest trade priority even if its timeframe appears last.
 for(int budget:{1,3,1000}){
  CMarcoBacktestInstance::s_clusters.Clear();
  CMarcoBacktestInstance late(3,"SSL",{{160,true,false,false},{200,true,false,true}}), early(4,"IND",{{100,true,false,true},{200,true,false,false}});
  pump({&late,&early},budget);CHECK(early.entries==1);CHECK(late.entries==0);CHECK(early.prepares==2);CHECK(late.prepares==2);
 }
 // All mitigations commit before any newly born overlapping member joins.
 CMarcoBacktestInstance::s_clusters.Clear();
 CMarcoBacktestInstance oldA(4,"oldA",{{100,true,false,true},{200,true,true,false}}),oldB(3,"oldB",{{100,true,false,false},{200,true,true,false}}),fresh(2,"new",{{100,false,false,false},{200,true,false,true}});
 pump({&fresh,&oldB,&oldA});CHECK(oldA.entries==1);CHECK(fresh.entries==1);
 // A same-timestamp bridge must be registered before the first entry phase.
 CMarcoBacktestInstance::s_clusters.Clear();
 CMarcoBacktestInstance used(4,"used",{{100,true,false,true},{200,true,false,false}}),candidate(3,"candidate",{{200,true,false,true}}),bridge(2,"bridge",{{200,true,false,false}});
 candidate.lo=120;candidate.hi=130;bridge.lo=110;bridge.hi=120;
 pump({&candidate,&used,&bridge});CHECK(used.entries==1);CHECK(candidate.entries==0);
 CMarcoBacktestInstance::s_clusters.Clear();CMarcoBacktestInstance bad(2,"bad",{{100,true,false,true}}),goodInstance(4,"good",{{100,true,false,true}});bad.failInit=true;pump({&bad,&goodInstance});CHECK(bad.m_simFailed&&bad.m_simComplete&&bad.m_sim==nullptr);CHECK(goodInstance.entries==1);
 std::cout<<"PASS: "<<checks<<" LB cluster, persistence and chronological scheduling checks\n";
}
'''
# Wiring guards ensure tests cover the policy actually consulted before order admission.
assert back.index('s_clusters.Blocked(', back.index('// 3. SCAN NEW ENTRY')) < back.index('m_trades[t_idx].ticket')
assert back.index('brokerRejection!=0') < back.index('s_clusters.Consume(')
assert 'if(!s_clusters.Eligible(' in back
assert 'PrepareSymbolClusters(symbol)' in live
assert live.index('clusterState.book.Consume(') < live.index('bool entrySent=SendCheckedEntry(')
assert '!CTradeRejection::ConsumeOrderResult(entryResult.retcode)' in live
assert 'ReleaseReservation(' in live
observer=back[back.index('   void ObserveEntryClusters('):back.index('   void RegisterPreparedClusters(')]
observer=adapt(observer).replace('m_sim.','m_sim->').replace('logic.','logic->').replace('lb.','lb->')
observer_mocks=r'''
struct CLiquidityBlock{string id;bool isMitigated=false,isBullish=false;double zoneLow=100,zoneHigh=110;datetime createdTime=100;};
struct Blocks{std::vector<CLiquidityBlock*> values;int Total(){return values.size();}CLiquidityBlock* At(int i){return values[i];}};
struct CLiquidityBlockLogic{Blocks m_liquidity_blocks;};
struct CachedLB{string id;datetime createdTime=100,entryTriggerTime=101;bool isMitigated=true;};
struct ObserverState{std::vector<datetime> htf_time;std::vector<double> htf_high,htf_low;int nextHtf=0;};
int PeriodSeconds(int tf){return tf*60;}
class CTradeRejection{public:static bool BoundaryBroken(bool b,double l,double h,double zl,double zh,double buffer){return b?l<zl-buffer:h>zh+buffer;}};
class ProductionObserver{public:
 CMarcoLBEntryClusters &s_clusters;string m_symbol="S";int m_tradeTF=4,m_htf_lb_count=1;
 std::vector<CachedLB> m_htf_lbs;ObserverState state;ObserverState *m_sim=&state;
 ProductionObserver(CMarcoLBEntryClusters &b):s_clusters(b){m_htf_lbs={{"A"}};}
'''+observer+'};\n'
observer_cases=r'''
void checkProductionObservation(){
 CMarcoLBEntryClusters b;ProductionObserver p(b);CLiquidityBlock raw;raw.id="A";
 CLiquidityBlockLogic logic;logic.m_liquidity_blocks.values={&raw};
 p.ObserveEntryClusters(400,&logic,1);CHECK(b.Eligible("S",4,"A",400));CHECK(b.Consume("S",4,"A",400));
 // Cached retirement from a trade/touch is not physical LB mitigation.
 p.ObserveEntryClusters(401,&logic,0);b.RetireCompleted();CHECK(b.Eligible("S",4,"A",401));
 string source;datetime used;CHECK(b.Blocked("S",4,"A",401,source,used));
 // If reclassification removes the source, ignore candles before formation and
 // any not yet closed. Touching the outer boundary is not a break.
 logic.m_liquidity_blocks.values.clear();p.state.htf_time={50,200,500};p.state.htf_high={120,110,111};p.state.htf_low={90,100,100};p.state.nextHtf=3;
 p.ObserveEntryClusters(700,&logic,0);b.RetireCompleted();CHECK(b.Eligible("S",4,"A",700));
 p.ObserveEntryClusters(740,&logic,0);b.RetireCompleted();CHECK(!b.Eligible("S",4,"A",740));
 // With a valid source, its authoritative mitigation flag releases the member.
 b.Clear();logic.m_liquidity_blocks.values={&raw};p.ObserveEntryClusters(400,&logic,1);raw.isMitigated=true;
 p.ObserveEntryClusters(401,&logic,0);b.RetireCompleted();CHECK(!b.Eligible("S",4,"A",401));
}
'''
cases=cases.replace('int main(){','int main(){\n checkProductionObservation();')
source=mock+adapt(core)+adapt(journal)+observer_mocks+observer_cases+mock_instance+adapt(scheduler)+cases
compiler=shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
with tempfile.TemporaryDirectory(prefix='marco_clusters_') as td:
 cpp=Path(td)/'clusters.cpp';exe=Path(td)/'clusters.exe';cpp.write_text(source)
 subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
 # The all-member requirement must be observed by the suite.
 broken=source.replace('if(!active)','if(true)');assert broken!=source
 cpp.write_text(broken);subprocess.run([compiler,'-std=c++17','-O2',str(cpp),'-o',str(exe)],check=True)
 result=subprocess.run([str(exe)],capture_output=True,text=True);assert result.returncode!=0
 print('PASS: premature cluster retirement mutation rejected')
