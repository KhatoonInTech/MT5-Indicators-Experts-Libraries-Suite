//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//|                               Include\ZigZag\Guardrails_Core.mqh |
//|                  Role: Handles pre-trade blocking, zone SL sizing,|
//|                  10x spread candle-close breakeven, and partials.|
//|                  Advanced Profit Saving & Auto Continuation.     |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "46.00"
#property description "Guardrails Engine - Dynamic Parameter Tracking & SMC Shield"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Include SMC Zone Libraries
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\ZigZag.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\market_structure.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\General\mql_plotting.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\demand_supply.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\swing_pois.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\order_blocks.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\flipzone.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\ZigZag\breaker_blocks.mqh"

// Data struct for violations and trade events
struct OrderLog
  {
   datetime          time;
   ulong             ticket;
   string            symbol;
   double            volume;
   double            max_allowed;
   double            loss;
   string            violation;
   string            status;
  };

// Asset Classification Enum
enum ENUM_ASSET_TYPE
  {
   ASSET_TYPE_AUTO,
   ASSET_TYPE_FOREX,
   ASSET_TYPE_METALS,
   ASSET_TYPE_CRYPTO
  };

// Zone Selection Filter for 1% Risk SL Calculation
enum ENUM_ZONE_SELECTION
  {
   ZONE_SELECT_NEAREST_ALL,     // Nearest Active Zone (Any SMC Type)
   ZONE_SELECT_ORDER_BLOCKS,    // Order Blocks Only
   ZONE_SELECT_DEMAND_SUPPLY,   // Demand / Supply Only
   ZONE_SELECT_BREAKER_BLOCKS,  // Breaker Blocks Only
   ZONE_SELECT_FLIP_ZONES,      // Flip Zones Only
   ZONE_SELECT_SWING_POIS       // Swing POIs Only
  };

// ZigZag Parameters Package Struct
struct SZigZagParams
  {
   int               fx_maxLookback;
   double            fx_dev_D1;
   int               fx_dep_D1;
   double            fx_dev_H4;
   int               fx_dep_H4;
   double            fx_dev_H1;
   int               fx_dep_H1;
   double            fx_dev_M15;
   int               fx_dep_M15;
   double            fx_dev_M1;
   int               fx_dep_M1;

   int               met_maxLookback;
   double            met_dev_D1;
   int               met_dep_D1;
   double            met_dev_H4;
   int               met_dep_H4;
   double            met_dev_H1;
   int               met_dep_H1;
   double            met_dev_M15;
   int               met_dep_M15;
   double            met_dev_M1;
   int               met_dep_M1;

   int               cry_maxLookback;
   double            cry_dev_D1;
   int               cry_dep_D1;
   double            cry_dev_H4;
   int               cry_dep_H4;
   double            cry_dev_H1;
   int               cry_dep_H1;
   double            cry_dev_M15;
   int               cry_dep_M15;
   double            cry_dev_M1;
   int               cry_dep_M1;
  };

// Profit Protection Tracking Struct (With Recursive Partial Close State)
struct SPositionProfitTracker
  {
   ulong             ticket;
   string            symbol;
   double            peak_profit;
   double            peak_price;          // Price level where peak_profit was recorded
   bool              activated;
   datetime          last_processed_bar;

   bool              has_partial_closed;
   double            net_profit_full;
   double            gross_profit_full;
   double            net_profit_remain;
   double            gross_profit_remain;
   int               partial_close_count;

   double            first_peak_price;    // The exact price level of the very first peak (pl_0)
   bool              auto_trade_triggered;// Prevents infinite auto-trade loops
  };

//+------------------------------------------------------------------+
//| Base Core Engine Class                                           |
//+------------------------------------------------------------------+
class CGuardrailsCore
  {
protected:
   bool                 m_manageAllSymbols;
   double               GetSymbolTickValue(string sym);

   // User Configurations
   bool                 m_blockShortsInBullish;
   bool                 m_blockLongsInBearish;
   ENUM_ZONE_SELECTION  m_zoneRiskSource;
   bool                 m_useDemandSupply;
   bool                 m_useOrderBlocks;
   bool                 m_useFlipZones;
   bool                 m_useBreakerBlocks;
   bool                 m_useSwingPOIs;

   // Draw Settings & ZigZag Visual Controls
   bool                 m_drawZigZag;
   color                m_zzLineColor;
   bool                 m_zzExtend;
   bool                 m_zzShowPrice;
   bool                 m_zzShowVol;
   bool                 m_zzShowChg;
   string               m_zzPriceDiff;

   bool                 m_drawMarketStructure;
   bool                 m_drawZones;
   ulong                m_magicNumber;
   bool                 m_enforceMaxLot;
   double               m_maxSpreadShare;
   bool                 m_showHUD;
   bool                 m_showOrderPanel;
   bool                 m_excludeSpread;
   double               m_maxRiskPercent;
   bool                 m_emergencyCircuitBreaker;
   bool                 m_autoBreakeven;
   int                  m_breakevenBuffer;
   bool                 m_waitCandleCloseForBE;
   double               m_beSpreadMultiplier;

   // Profit Protection Settings
   bool                 m_enableProfitGuard;
   double               m_tpActivationPercent;
   double               m_maxProfitGivebackPercent;
   double               m_partialClosePercent;
   bool                 m_advancedProfitSaving;
   bool                 m_autoTradeContinuation;

   // Toggle State for Auto 1% Lot
   bool                 m_auto_lot_enabled;

   // 10-Second Violated Zone Highlight Tracker
   bool                 m_flash_zone_active;
   datetime             m_flash_zone_expire;
   string               m_flash_zone_name;

   // ZigZag Multi-Asset Settings
   ENUM_ASSET_TYPE      m_assetCategory;
   SZigZagParams        m_zzParams;

   // Dynamic Input Change Tracking
   double               m_last_dev;
   int                  m_last_dep;

   // Trade Engine Objects
   CTrade               m_trade;
   CPositionInfo        m_position;

   // Active Lot Size selected in panel
   double               m_panel_lot;

   // SMC Engine Instances
   ZigZag*              m_zigZag;
   CMarketStructure*    m_ms;
   CDemandSupplyLogic*  m_dsLogic;
   CSwingPOILogic*      m_spLogic;
   COrderBlockLogic*    m_obLogic;
   CFlipZoneLogic*      m_fzLogic;
   CBreakerBlockLogic*  m_bbLogic;

   // Internal Data Streams
   datetime             m_chart_times[];
   double               m_chart_highs[];
   double               m_chart_lows[];
   double               m_chart_closes[];
   int                  m_chart_bars_loaded;

   // Incremental Engine State
   bool                 m_smc_initialized;
   datetime             m_last_smc_bar_time;
   ENUM_TIMEFRAMES      m_last_period;

   // Audited Tickets Registry
   ulong                m_audited_tickets[];

   // Profit Protection Trackers
   datetime               m_last_tp_bar_time;
   SPositionProfitTracker m_profitTrackers[];

   // Multi-Symbol Methods
   ENUM_ASSET_TYPE      DetectAssetType(string sym);
   void                 GetActiveZigZagParams(double &outDev, int &outDep, int &outLookback);
   void                 UpdateSMCZones();
   void                 DrawActiveSMCZones();
   void                 DrawZoneBox(string boxName, datetime t1, double high_p, datetime t2, double low_p, color bgClr, color borderClr, string labelText, color textClr);
   void                 EnforceDrawingsBackground();
   bool                 IsInBullishZone(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time = 0);
   bool                 IsInBearishZone(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time = 0);
   double               CalculateCurrentLoss(double volume, string sym);
   void                 HighlightViolatedZone(string zoneType, double zLow, double zHigh, datetime zTime, bool isBullish);
   void                 CheckViolatedZoneExpiration();

   // Structural Boundary Seekers
   bool                 GetNearestBullishBoundary(string sym, double price, double &outBoundary, string &outName, datetime at_time = 0);
   bool                 GetNearestBearishBoundary(string sym, double price, double &outBoundary, string &outName, datetime at_time = 0);

   // External / Mobile Trade Audit Engine
   bool                 IsTicketAudited(ulong ticket);
   void                 MarkTicketAudited(ulong ticket);
   void                 AuditRunningPositions();

   // Persistent Profit Guard Methods
   int                  GetOrCreateProfitTracker(ulong ticket, string sym);
   void                 CleanProfitTrackers();
   void                 CheckProfitProtectionGuard();
   void                 SaveProfitTrackerToGV(const SPositionProfitTracker &tracker);
   bool                 LoadProfitTrackerFromGV(ulong ticket, SPositionProfitTracker &tracker);
   void                 DeleteProfitTrackerGV(ulong ticket);
   bool                 ReconstructTrackerFromChartHistory(ulong ticket, string sym, SPositionProfitTracker &tracker);

   // Safe Running Trade Management
   void                 CheckAndSetBreakevenSL(string sym);
   void                 CheckEmergencyLossCut(string sym);
   void                 ExecuteAutoTrade(string sym, int direction);

   virtual void         TriggerGuardrailViolation(ulong ticket, string sym, double volume, double max_allowed, double loss, string violation, string status) {}
   virtual void         OnPreTradeExecuted(double executedLot) {}

public:
                     CGuardrailsCore();
   virtual             ~CGuardrailsCore();

   double               CalculateMaxAllowedLot(string sym, int direction = 0, double custom_price = 0.0, datetime at_time = 0);
   void                 ExecutePreTradeBuy();
   void                 ExecutePreTradeSell();
   void                 RunMasterShield();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGuardrailsCore::CGuardrailsCore()
  {
   m_manageAllSymbols          = true;
   m_panel_lot                 = 0.10;
   m_waitCandleCloseForBE      = true;
   m_beSpreadMultiplier       = 10.0;
   m_assetCategory             = ASSET_TYPE_AUTO;
   m_zoneRiskSource            = ZONE_SELECT_NEAREST_ALL;
   m_auto_lot_enabled          = false;

   m_useDemandSupply           = true;
   m_useOrderBlocks            = true;
   m_useFlipZones              = true;
   m_useBreakerBlocks          = true;
   m_useSwingPOIs              = true;

   m_drawZigZag                = true;
   m_zzLineColor               = clrGold;
   m_zzExtend                  = true;
   m_zzShowPrice               = false;
   m_zzShowVol                 = false;
   m_zzShowChg                 = false;
   m_zzPriceDiff               = "Percent";

   m_drawMarketStructure       = true;
   m_drawZones                 = true;

   m_smc_initialized           = false;
   m_last_smc_bar_time         = 0;
   m_last_period               = PERIOD_CURRENT;
   m_chart_bars_loaded         = 0;
   m_last_dev                  = -1.0;
   m_last_dep                  = -1;

   m_flash_zone_active         = false;
   m_flash_zone_expire         = 0;
   m_flash_zone_name           = "RG_Violated_Zone";

   m_enableProfitGuard         = true;
   m_tpActivationPercent       = 1.0;
   m_maxProfitGivebackPercent  = 30.0;
   m_partialClosePercent       = 50.0;
   m_advancedProfitSaving      = true;
   m_autoTradeContinuation     = true;
   m_last_tp_bar_time          = 0;

   m_zigZag  = NULL;
   m_ms      = new CMarketStructure();
   m_dsLogic = new CDemandSupplyLogic();
   m_spLogic = new CSwingPOILogic();
   m_obLogic = new COrderBlockLogic();
   m_fzLogic = new CFlipZoneLogic();
   m_bbLogic = new CBreakerBlockLogic();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGuardrailsCore::~CGuardrailsCore()
  {
   if(CheckPointer(m_zigZag) == POINTER_DYNAMIC)
      delete m_zigZag;
   if(CheckPointer(m_ms) == POINTER_DYNAMIC)
      delete m_ms;
   if(CheckPointer(m_dsLogic) == POINTER_DYNAMIC)
      delete m_dsLogic;
   if(CheckPointer(m_spLogic) == POINTER_DYNAMIC)
      delete m_spLogic;
   if(CheckPointer(m_obLogic) == POINTER_DYNAMIC)
      delete m_obLogic;
   if(CheckPointer(m_fzLogic) == POINTER_DYNAMIC)
      delete m_fzLogic;
   if(CheckPointer(m_bbLogic) == POINTER_DYNAMIC)
      delete m_bbLogic;

   ObjectsDeleteAll(0, "ZZ_Ln_");
   ObjectsDeleteAll(0, "ZZ_Lbl_");
   ObjectsDeleteAll(0, "ZZ_Proj_");
   ObjectsDeleteAll(0, "BOSCHoCH_");
   ObjectsDeleteAll(0, "SWING_");
   ObjectsDeleteAll(0, "SMC_");
   ObjectsDeleteAll(0, "RG_Violated_");
  }

//+------------------------------------------------------------------+
//| Audited Registry Checks                                          |
//+------------------------------------------------------------------+
bool CGuardrailsCore::IsTicketAudited(ulong ticket)
  {
   string gv_name = "RG_Audited_" + IntegerToString(ticket);
   if(GlobalVariableCheck(gv_name))
      return true;

   int sz = ArraySize(m_audited_tickets);
   for(int i = 0; i < sz; i++)
     {
      if(m_audited_tickets[i] == ticket)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGuardrailsCore::MarkTicketAudited(ulong ticket)
  {
   string gv_name = "RG_Audited_" + IntegerToString(ticket);
   GlobalVariableSet(gv_name, 1.0);

   int sz = ArraySize(m_audited_tickets);
   ArrayResize(m_audited_tickets, sz + 1);
   m_audited_tickets[sz] = ticket;
  }

//+------------------------------------------------------------------+
//| Audit External / Mobile Trades at Historical Entry Coordinates   |
//+------------------------------------------------------------------+
void CGuardrailsCore::AuditRunningPositions()
  {
   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         ulong ticket = m_position.Ticket();
         string pos_sym = m_position.Symbol();

         if(!m_manageAllSymbols && pos_sym != _Symbol)
            continue;

         if(m_magicNumber != 0 && m_position.Magic() != m_magicNumber)
            continue;

         if(IsTicketAudited(ticket))
            continue;

         string comment = m_position.Comment();
         if(StringFind(comment, "Guardrail Safe") >= 0)
           {
            MarkTicketAudited(ticket);
            continue;
           }

         datetime           open_time  = (datetime)m_position.Time();
         double             open_price = m_position.PriceOpen();
         double             volume     = m_position.Volume();
         ENUM_POSITION_TYPE pos_type   = m_position.PositionType();
         int                dir        = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;

         string   zDetail = "";
         double   zLow = 0.0, zHigh = 0.0;
         datetime zTime = 0;

         if(pos_type == POSITION_TYPE_BUY && m_blockLongsInBearish)
           {
            if(IsInBearishZone(open_price, zDetail, zLow, zHigh, zTime, open_time))
              {
               double cur_loss = CalculateCurrentLoss(volume, pos_sym);
               m_trade.SetAsyncMode(false);
               m_trade.PositionClose(ticket);
               TriggerGuardrailViolation(ticket, pos_sym, volume, 0.0, cur_loss, zDetail, "Killed (Zone)");
               HighlightViolatedZone(zDetail, zLow, zHigh, zTime, false);
               PrintFormat("🚨 EXTERNAL BUY KILLED: Position #%d opened on Mobile inside %s (%.5f - %.5f)!",
                           ticket, zDetail, zLow, zHigh);
               continue;
              }
           }
         else
            if(pos_type == POSITION_TYPE_SELL && m_blockShortsInBullish)
              {
               if(IsInBullishZone(open_price, zDetail, zLow, zHigh, zTime, open_time))
                 {
                  double cur_loss = CalculateCurrentLoss(volume, pos_sym);
                  m_trade.SetAsyncMode(false);
                  m_trade.PositionClose(ticket);
                  TriggerGuardrailViolation(ticket, pos_sym, volume, 0.0, cur_loss, zDetail, "Killed (Zone)");
                  HighlightViolatedZone(zDetail, zLow, zHigh, zTime, true);
                  PrintFormat("🚨 EXTERNAL SELL KILLED: Position #%d opened on Mobile inside %s (%.5f - %.5f)!",
                              ticket, zDetail, zLow, zHigh);
                  continue;
                 }
              }

         if(m_enforceMaxLot)
           {
            double max_safe_at_entry = CalculateMaxAllowedLot(pos_sym, dir, open_price, open_time);
            if(volume > (max_safe_at_entry + 0.009))
              {
               double cur_loss = CalculateCurrentLoss(volume, pos_sym);
               m_trade.SetAsyncMode(false);
               m_trade.PositionClose(ticket);
               double oversize = volume - max_safe_at_entry;
               TriggerGuardrailViolation(ticket, pos_sym, volume, max_safe_at_entry, cur_loss,
                                         StringFormat("+%.2f L Over", oversize), "Killed (Oversized)");
               PrintFormat("🚨 EXTERNAL TRADE KILLED: Position #%d opened on Mobile with %.2f L exceeds 1%% limit (%.2f L)!",
                           ticket, volume, max_safe_at_entry);
               continue;
              }
           }

         MarkTicketAudited(ticket);
         PrintFormat("✅ EXTERNAL TRADE APPROVED: Position #%d (%s %.2f L at %.5f) verified compliant with entry risk.",
                     ticket, (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), volume, open_price);
        }
     }
  }

//+------------------------------------------------------------------+
//| Save Profit Tracker to Persistent GlobalVariables                |
//+------------------------------------------------------------------+
void CGuardrailsCore::SaveProfitTrackerToGV(const SPositionProfitTracker &tracker)
  {
   string pfx = "RG_PG_" + IntegerToString(tracker.ticket) + "_";
   GlobalVariableSet(pfx + "peak", tracker.peak_profit);
   GlobalVariableSet(pfx + "pk_prc", tracker.peak_price);
   GlobalVariableSet(pfx + "armed", tracker.activated ? 1.0 : 0.0);
   GlobalVariableSet(pfx + "bar", (double)tracker.last_processed_bar);
   GlobalVariableSet(pfx + "has_part", tracker.has_partial_closed ? 1.0 : 0.0);
   GlobalVariableSet(pfx + "net_full", tracker.net_profit_full);
   GlobalVariableSet(pfx + "gross_full", tracker.gross_profit_full);
   GlobalVariableSet(pfx + "net_rem", tracker.net_profit_remain);
   GlobalVariableSet(pfx + "gross_rem", tracker.gross_profit_remain);
   GlobalVariableSet(pfx + "part_cnt", (double)tracker.partial_close_count);
   GlobalVariableSet(pfx + "fpk_prc", tracker.first_peak_price);
   GlobalVariableSet(pfx + "auto_trg", tracker.auto_trade_triggered ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| Load Profit Tracker from Persistent GlobalVariables              |
//+------------------------------------------------------------------+
bool CGuardrailsCore::LoadProfitTrackerFromGV(ulong ticket, SPositionProfitTracker &tracker)
  {
   string pfx = "RG_PG_" + IntegerToString(ticket) + "_";
   if(!GlobalVariableCheck(pfx + "peak"))
      return false;

   tracker.peak_profit         = GlobalVariableGet(pfx + "peak");
   tracker.peak_price          = GlobalVariableGet(pfx + "pk_prc");
   tracker.activated           = (GlobalVariableGet(pfx + "armed") > 0.5);
   tracker.last_processed_bar  = (datetime)GlobalVariableGet(pfx + "bar");
   tracker.has_partial_closed  = (GlobalVariableGet(pfx + "has_part") > 0.5);
   tracker.net_profit_full     = GlobalVariableGet(pfx + "net_full");
   tracker.gross_profit_full   = GlobalVariableGet(pfx + "gross_full");
   tracker.net_profit_remain   = GlobalVariableGet(pfx + "net_rem");
   tracker.gross_profit_remain = GlobalVariableGet(pfx + "gross_rem");
   tracker.partial_close_count = (int)GlobalVariableGet(pfx + "part_cnt");
   tracker.first_peak_price    = GlobalVariableGet(pfx + "fpk_prc");
   tracker.auto_trade_triggered= (GlobalVariableGet(pfx + "auto_trg") > 0.5);
   return true;
  }

//+------------------------------------------------------------------+
//| Delete Persistent GlobalVariables on Position Closure            |
//+------------------------------------------------------------------+
void CGuardrailsCore::DeleteProfitTrackerGV(ulong ticket)
  {
   string pfx = "RG_PG_" + IntegerToString(ticket) + "_";
   GlobalVariableDel(pfx + "peak");
   GlobalVariableDel(pfx + "pk_prc");
   GlobalVariableDel(pfx + "armed");
   GlobalVariableDel(pfx + "bar");
   GlobalVariableDel(pfx + "has_part");
   GlobalVariableDel(pfx + "net_full");
   GlobalVariableDel(pfx + "gross_full");
   GlobalVariableDel(pfx + "net_rem");
   GlobalVariableDel(pfx + "gross_rem");
   GlobalVariableDel(pfx + "part_cnt");
   GlobalVariableDel(pfx + "fpk_prc");
   GlobalVariableDel(pfx + "auto_trg");
   GlobalVariableDel("RG_Audited_" + IntegerToString(ticket));
  }

//+------------------------------------------------------------------+
//| Reconstruct Tracker from Trade Deal History & Chart Coordinates  |
//+------------------------------------------------------------------+
bool CGuardrailsCore::ReconstructTrackerFromChartHistory(ulong ticket, string sym, SPositionProfitTracker &tracker)
  {
   if(!m_position.SelectByTicket(ticket))
      return false;

   datetime           pos_open_time = (datetime)m_position.Time();
   double             open_price    = m_position.PriceOpen();
   double             current_vol   = m_position.Volume();
   ENUM_POSITION_TYPE pos_type      = m_position.PositionType();
   long               pos_id        = m_position.Identifier();

   double balance          = AccountInfoDouble(ACCOUNT_BALANCE);
   double activation_money = balance * (m_tpActivationPercent / 100.0);

   HistorySelect(pos_open_time - 10, TimeCurrent() + 60);
   int deals_total = HistoryDealsTotal();

   double   initial_volume = 0.0;
   int      exit_deals     = 0;
   datetime last_exit_time = 0;

   for(int d = 0; d < deals_total; d++)
     {
      ulong d_ticket = HistoryDealGetTicket(d);
      if(d_ticket > 0 && HistoryDealGetInteger(d_ticket, DEAL_POSITION_ID) == pos_id)
        {
         long d_entry = HistoryDealGetInteger(d_ticket, DEAL_ENTRY);
         double d_vol = HistoryDealGetDouble(d_ticket, DEAL_VOLUME);

         if(d_entry == DEAL_ENTRY_IN)
           {
            initial_volume += d_vol;
           }
         else
            if(d_entry == DEAL_ENTRY_OUT || d_entry == DEAL_ENTRY_INOUT)
              {
               exit_deals++;
               last_exit_time = (datetime)HistoryDealGetInteger(d_ticket, DEAL_TIME);
              }
        }
     }

   if(initial_volume <= 0.0)
      initial_volume = current_vol;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(sym, _Period, pos_open_time, TimeCurrent(), rates);
   if(copied < 2)
     {
      SaveProfitTrackerToGV(tracker);
      return true;
     }

   for(int c = 0; c < copied - 1; c++)
     {
      datetime bar_time  = rates[c].time;
      double   bar_open  = rates[c].open;
      double   bar_close = rates[c].close;

      if(bar_time + PeriodSeconds(_Period) <= pos_open_time)
         continue;

      double vol_at_bar = (last_exit_time > 0 && bar_time < last_exit_time) ? initial_volume : current_vol;

      double profit_at_close = 0.0;
      OrderCalcProfit(pos_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                      sym, vol_at_bar, open_price, bar_close, profit_at_close);

      if(!tracker.has_partial_closed)
        {
         if(!tracker.activated)
           {
            if(profit_at_close >= activation_money)
              {
               tracker.activated   = true;
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }
           }
         else
           {
            if(profit_at_close > tracker.peak_profit)
              {
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }

            bool is_opposing = (pos_type == POSITION_TYPE_BUY) ? (bar_close < bar_open) : (bar_close > bar_open);
            if(is_opposing && tracker.peak_profit > 0.0)
              {
               double giveback = ((tracker.peak_profit - profit_at_close) / tracker.peak_profit) * 100.0;
               if(giveback >= m_maxProfitGivebackPercent)
                 {
                  if(tracker.partial_close_count == 0)
                     tracker.first_peak_price = tracker.peak_price;

                  tracker.has_partial_closed  = true;
                  tracker.partial_close_count++;
                  tracker.net_profit_full     = tracker.peak_profit;
                  tracker.gross_profit_full   = profit_at_close;
                  tracker.net_profit_remain   = tracker.net_profit_full * (current_vol / vol_at_bar);
                  tracker.gross_profit_remain = tracker.gross_profit_full * (current_vol / vol_at_bar);
                  tracker.peak_profit         = tracker.gross_profit_remain;
                  tracker.peak_price          = bar_close;
                  tracker.activated           = m_advancedProfitSaving;
                 }
              }
           }
        }
      else
        {
         if(!tracker.activated)
           {
            if(m_advancedProfitSaving || profit_at_close > tracker.net_profit_remain)
              {
               tracker.activated   = true;
               tracker.peak_profit = MathMax(tracker.gross_profit_remain, profit_at_close);
               tracker.peak_price  = bar_close;
              }
           }
         else
           {
            if(profit_at_close > tracker.peak_profit)
              {
               tracker.peak_profit = profit_at_close;
               tracker.peak_price  = bar_close;
              }

            bool is_opposing = (pos_type == POSITION_TYPE_BUY) ? (bar_close < bar_open) : (bar_close > bar_open);
            if(is_opposing && tracker.peak_profit > 0.0)
              {
               double giveback = ((tracker.peak_profit - profit_at_close) / tracker.peak_profit) * 100.0;
               if(giveback >= m_maxProfitGivebackPercent)
                 {
                  tracker.partial_close_count++;
                  tracker.net_profit_full     = tracker.peak_profit;
                  tracker.gross_profit_full   = profit_at_close;
                  tracker.net_profit_remain   = tracker.net_profit_full * (current_vol / vol_at_bar);
                  tracker.gross_profit_remain = tracker.gross_profit_full * (current_vol / vol_at_bar);
                  tracker.peak_profit         = tracker.gross_profit_remain;
                  tracker.peak_price          = bar_close;
                  tracker.activated           = m_advancedProfitSaving;
                 }
              }
           }
        }

      // Auto-Trade Continuation Check
      if(m_autoTradeContinuation && tracker.has_partial_closed && !tracker.auto_trade_triggered && tracker.first_peak_price > 0.0)
        {
         if(pos_type == POSITION_TYPE_BUY && bar_close > tracker.first_peak_price)
            tracker.auto_trade_triggered = true;
         else
            if(pos_type == POSITION_TYPE_SELL && bar_close < tracker.first_peak_price)
               tracker.auto_trade_triggered = true;
        }

      tracker.last_processed_bar = bar_time;
     }

   SaveProfitTrackerToGV(tracker);
   PrintFormat("🔄 RESTORED TRADE HISTORY: %s #%d | Peak: $%.2f | Armed: %s | Partials: %d | NetRemain: $%.2f",
               sym, ticket, tracker.peak_profit, tracker.activated ? "YES" : "NO", tracker.partial_close_count, tracker.net_profit_remain);
   return true;
  }

//+------------------------------------------------------------------+
//| Get or Create Profit Tracker (Persistent State Resolver)         |
//+------------------------------------------------------------------+
int CGuardrailsCore::GetOrCreateProfitTracker(ulong ticket, string sym)
  {
   int total = ArraySize(m_profitTrackers);
   for(int i = 0; i < total; i++)
     {
      if(m_profitTrackers[i].ticket == ticket)
         return i;
     }

   ArrayResize(m_profitTrackers, total + 1);
   m_profitTrackers[total].ticket              = ticket;
   m_profitTrackers[total].symbol              = sym;
   m_profitTrackers[total].peak_profit         = 0.0;
   m_profitTrackers[total].peak_price          = 0.0;
   m_profitTrackers[total].activated           = false;
   m_profitTrackers[total].last_processed_bar  = 0;
   m_profitTrackers[total].has_partial_closed  = false;
   m_profitTrackers[total].net_profit_full     = 0.0;
   m_profitTrackers[total].gross_profit_full   = 0.0;
   m_profitTrackers[total].net_profit_remain   = 0.0;
   m_profitTrackers[total].gross_profit_remain = 0.0;
   m_profitTrackers[total].partial_close_count = 0;
   m_profitTrackers[total].first_peak_price    = 0.0;
   m_profitTrackers[total].auto_trade_triggered= false;

   if(!LoadProfitTrackerFromGV(ticket, m_profitTrackers[total]))
     {
      ReconstructTrackerFromChartHistory(ticket, sym, m_profitTrackers[total]);
     }

   return total;
  }

//+------------------------------------------------------------------+
//| Clean Closed Trackers and Delete Stored GlobalVariables          |
//+------------------------------------------------------------------+
void CGuardrailsCore::CleanProfitTrackers()
  {
   int total = ArraySize(m_profitTrackers);
   for(int i = total - 1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(m_profitTrackers[i].ticket))
        {
         DeleteProfitTrackerGV(m_profitTrackers[i].ticket);
         for(int j = i; j < total - 1; j++)
            m_profitTrackers[j] = m_profitTrackers[j + 1];
         total--;
         ArrayResize(m_profitTrackers, total);
        }
     }

   int a_sz = ArraySize(m_audited_tickets);
   for(int i = a_sz - 1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(m_audited_tickets[i]))
        {
         GlobalVariableDel("RG_Audited_" + IntegerToString(m_audited_tickets[i]));
         for(int j = i; j < a_sz - 1; j++)
            m_audited_tickets[j] = m_audited_tickets[j + 1];
         a_sz--;
         ArrayResize(m_audited_tickets, a_sz);
        }
     }
  }

//+------------------------------------------------------------------+
//| Find Nearest Bullish Zone Lower Boundary Below Price             |
//+------------------------------------------------------------------+
bool CGuardrailsCore::GetNearestBullishBoundary(string sym, double price, double &outBoundary, string &outName, datetime at_time)
  {
   outBoundary = 0.0;
   outName     = "";
   double min_dist = DBL_MAX;

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_DEMAND_SUPPLY) && m_dsLogic != NULL)
     {
      for(int i = 0; i < m_dsLogic.poi_demandTime.Total(); i++)
        {
         datetime zTime = (datetime)m_dsLogic.poi_demandTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_dsLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow = m_dsLogic.poi_demandZoneLow.At(i);
            if(zLow < price && (price - zLow) < min_dist)
              {
               min_dist    = price - zLow;
               outBoundary = zLow;
               outName     = "Demand Zone";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_ORDER_BLOCKS) && m_obLogic != NULL)
     {
      for(int i = 0; i < m_obLogic.poi_demandTime.Total(); i++)
        {
         datetime zTime = (datetime)m_obLogic.poi_demandTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_obLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow = m_obLogic.poi_demandZoneLow.At(i);
            if(zLow < price && (price - zLow) < min_dist)
              {
               min_dist    = price - zLow;
               outBoundary = zLow;
               outName     = "Order Block";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_BREAKER_BLOCKS) && m_bbLogic != NULL)
     {
      for(int i = 0; i < m_bbLogic.bb_time.Total(); i++)
        {
         datetime zTime = (datetime)m_bbLogic.bb_time.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_bbLogic.bb_mitigated.At(i) == 0 && m_bbLogic.bb_type.At(i) == 1)
           {
            double zLow = m_bbLogic.bb_zoneLow.At(i);
            if(zLow < price && (price - zLow) < min_dist)
              {
               min_dist    = price - zLow;
               outBoundary = zLow;
               outName     = "Bullish Breaker";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_FLIP_ZONES) && m_fzLogic != NULL)
     {
      for(int i = 0; i < m_fzLogic.fz_time.Total(); i++)
        {
         datetime zTime = (datetime)m_fzLogic.fz_time.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_fzLogic.fz_mitigated.At(i) == 0 && m_fzLogic.fz_type.At(i) == 1)
           {
            double zLow = m_fzLogic.fz_zoneLow.At(i);
            if(zLow < price && (price - zLow) < min_dist)
              {
               min_dist    = price - zLow;
               outBoundary = zLow;
               outName     = "Bullish Flip";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_SWING_POIS) && m_spLogic != NULL)
     {
      for(int i = 0; i < m_spLogic.poi_demandTime.Total(); i++)
        {
         datetime zTime = (datetime)m_spLogic.poi_demandTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_spLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow = m_spLogic.poi_demandZoneLow.At(i);
            if(zLow < price && (price - zLow) < min_dist)
              {
               min_dist    = price - zLow;
               outBoundary = zLow;
               outName     = "Swing POI";
              }
           }
        }
     }

   return (outBoundary > 0.0);
  }

//+------------------------------------------------------------------+
//| Find Nearest Bearish Zone Upper Boundary Above Price             |
//+------------------------------------------------------------------+
bool CGuardrailsCore::GetNearestBearishBoundary(string sym, double price, double &outBoundary, string &outName, datetime at_time)
  {
   outBoundary = 0.0;
   outName     = "";
   double min_dist = DBL_MAX;

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_DEMAND_SUPPLY) && m_dsLogic != NULL)
     {
      for(int i = 0; i < m_dsLogic.poi_supplyTime.Total(); i++)
        {
         datetime zTime = (datetime)m_dsLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_dsLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zHigh = m_dsLogic.poi_supplyZoneHigh.At(i);
            if(zHigh > price && (zHigh - price) < min_dist)
              {
               min_dist    = zHigh - price;
               outBoundary = zHigh;
               outName     = "Supply Zone";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_ORDER_BLOCKS) && m_obLogic != NULL)
     {
      for(int i = 0; i < m_obLogic.poi_supplyTime.Total(); i++)
        {
         datetime zTime = (datetime)m_obLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_obLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zHigh = m_obLogic.poi_supplyZoneHigh.At(i);
            if(zHigh > price && (zHigh - price) < min_dist)
              {
               min_dist    = zHigh - price;
               outBoundary = zHigh;
               outName     = "Bearish OB";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_BREAKER_BLOCKS) && m_bbLogic != NULL)
     {
      for(int i = 0; i < m_bbLogic.bb_time.Total(); i++)
        {
         datetime zTime = (datetime)m_bbLogic.bb_time.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_bbLogic.bb_mitigated.At(i) == 0 && m_bbLogic.bb_type.At(i) == -1)
           {
            double zHigh = m_bbLogic.bb_zoneHigh.At(i);
            if(zHigh > price && (zHigh - price) < min_dist)
              {
               min_dist    = zHigh - price;
               outBoundary = zHigh;
               outName     = "Bearish Breaker";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_FLIP_ZONES) && m_fzLogic != NULL)
     {
      for(int i = 0; i < m_fzLogic.fz_time.Total(); i++)
        {
         datetime zTime = (datetime)m_fzLogic.fz_time.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_fzLogic.fz_mitigated.At(i) == 0 && m_fzLogic.fz_type.At(i) == -1)
           {
            double zHigh = m_fzLogic.fz_zoneHigh.At(i);
            if(zHigh > price && (zHigh - price) < min_dist)
              {
               min_dist    = zHigh - price;
               outBoundary = zHigh;
               outName     = "Bearish Flip";
              }
           }
        }
     }

   if((m_zoneRiskSource == ZONE_SELECT_NEAREST_ALL || m_zoneRiskSource == ZONE_SELECT_SWING_POIS) && m_spLogic != NULL)
     {
      for(int i = 0; i < m_spLogic.poi_supplyTime.Total(); i++)
        {
         datetime zTime = (datetime)m_spLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zTime > at_time)
            continue;

         if(m_spLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zHigh = m_spLogic.poi_supplyZoneHigh.At(i);
            if(zHigh > price && (zHigh - price) < min_dist)
              {
               min_dist    = zHigh - price;
               outBoundary = zHigh;
               outName     = "Swing POI";
              }
           }
        }
     }

   return (outBoundary > 0.0);
  }

//+------------------------------------------------------------------+
//| Universal Broker-Proof Tick Value Resolver                       |
//+------------------------------------------------------------------+
double CGuardrailsCore::GetSymbolTickValue(string sym)
  {
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(tv <= 0.0)
      tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0)
      tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_PROFIT);

   if(tv <= 0.0)
     {
      double bid     = SymbolInfoDouble(sym, SYMBOL_BID);
      double tick_sz = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tick_sz <= 0.0)
         tick_sz = SymbolInfoDouble(sym, SYMBOL_POINT);

      if(bid > 0.0 && tick_sz > 0.0)
        {
         double profit = 0.0;
         if(OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, bid, bid + tick_sz, profit))
            tv = MathAbs(profit);
        }
     }

   if(tv <= 0.0)
     {
      double contract_sz = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      double tick_sz     = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tick_sz <= 0.0)
         tick_sz = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(contract_sz > 0.0 && tick_sz > 0.0)
         tv = contract_sz * tick_sz;
     }

   return (tv > 0.0) ? tv : 1.0;
  }

//+------------------------------------------------------------------+
//| Calculate Max Safe Lot Size from Structural Zone Distance & Margin|
//+------------------------------------------------------------------+
double CGuardrailsCore::CalculateMaxAllowedLot(string sym, int direction, double custom_price, datetime at_time)
  {
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free_margin <= 0.0)
      free_margin = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0 || free_margin <= 0.0)
      return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   double max_risk_money = balance * (m_maxRiskPercent / 100.0);

   double ask       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid       = (custom_price > 0.0) ? custom_price : SymbolInfoDouble(sym, SYMBOL_BID);
   double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = point;
   double tick_val  = GetSymbolTickValue(sym);

   double price_distance = 0.0;
   string zName          = "";
   double zBoundary      = 0.0;

   if(direction == -1)
     {
      if(GetNearestBearishBoundary(sym, bid, zBoundary, zName, at_time))
         price_distance = MathAbs(zBoundary - bid);
     }
   else
      if(direction == 1)
        {
         if(GetNearestBullishBoundary(sym, ask, zBoundary, zName, at_time))
            price_distance = MathAbs(ask - zBoundary);
        }
      else
        {
         double buy_dist = 0.0, sell_dist = 0.0;
         if(GetNearestBearishBoundary(sym, bid, zBoundary, zName, at_time))
            sell_dist = MathAbs(zBoundary - bid);
         if(GetNearestBullishBoundary(sym, ask, zBoundary, zName, at_time))
            buy_dist = MathAbs(ask - zBoundary);

         if(buy_dist > 0.0 && sell_dist > 0.0)
            price_distance = MathMin(buy_dist, sell_dist);
         else
            price_distance = MathMax(buy_dist, sell_dist);
        }

   if(price_distance <= 0.0)
      price_distance = 100.0 * point * 10;

   if(!m_excludeSpread)
     {
      long sp_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
      price_distance += (sp_pts * point);
     }

   double loss_per_lot = (price_distance / tick_size) * tick_val;
   double max_lot_by_risk = (loss_per_lot > 0.0) ? (max_risk_money / loss_per_lot) : 0.01;

   double margin_1_lot = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ask, margin_1_lot) || margin_1_lot <= 0.0)
     {
      long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(lev <= 0)
         lev = 100;
      double csz = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      margin_1_lot = (1.0 * csz * ask) / (double)lev;
     }

   double max_lot_by_margin = max_lot_by_risk;
   if(margin_1_lot > 0.0)
      max_lot_by_margin = (free_margin * 0.90) / margin_1_lot;

   double max_lot = MathMin(max_lot_by_risk, max_lot_by_margin);

   double lot_step       = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double min_lot        = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot_broker = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);

   if(lot_step > 0.0)
      max_lot = MathFloor(max_lot / lot_step) * lot_step;

   max_lot = MathMax(min_lot, MathMin(max_lot, max_lot_broker));
   int lot_digits = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step > 0.0 ? lot_step : 0.01)));

   return NormalizeDouble(max_lot, lot_digits);
  }

//+------------------------------------------------------------------+
//| Auto-Breakeven: Candle-Close in Desired Dir + 10x Spread Distance|
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckAndSetBreakevenSL(string sym)
  {
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   long stops_level = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_dist = stops_level * point;

   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double open_price = m_position.PriceOpen();
   double current_sl = m_position.StopLoss();
   double current_tp = m_position.TakeProfit();

   datetime pos_open_time    = (datetime)m_position.Time();
   datetime current_bar_time = iTime(sym, _Period, 0);

   if(m_waitCandleCloseForBE && pos_open_time >= current_bar_time)
      return;

   double closed_price = iClose(sym, _Period, 1);
   double open_price_1 = iOpen(sym, _Period, 1);
   if(closed_price == 0.0 || open_price_1 == 0.0)
      return;

   long spread_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spread_pts <= 0)
     {
      if(point > 0.0 && ask > bid)
         spread_pts = (long)MathRound((ask - bid) / point);
      else
         spread_pts = 10;
     }
   double spread_distance = spread_pts * point;
   double min_be_distance = m_beSpreadMultiplier * spread_distance;

   if(m_position.PositionType() == POSITION_TYPE_BUY)
     {
      bool candle_in_desired_dir = (closed_price > open_price_1);
      bool reached_10x_spread    = (closed_price >= (open_price + min_be_distance));

      if(candle_in_desired_dir && reached_10x_spread)
        {
         double target_sl = NormalizeDouble(open_price + (m_breakevenBuffer * point), digits);
         if(current_sl < target_sl && bid >= target_sl + min_stop_dist)
           {
            m_trade.SetAsyncMode(false);
            if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
               Print("🛡️ AUTO-SL: Shifted SL to BREAKEVEN for ", sym, " BUY #", m_position.Ticket(), " at: ", target_sl);
           }
        }
     }
   else
      if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
         bool candle_in_desired_dir = (closed_price < open_price_1);
         bool reached_10x_spread    = (closed_price <= (open_price - min_be_distance));

         if(candle_in_desired_dir && reached_10x_spread)
           {
            double target_sl = NormalizeDouble(open_price - (m_breakevenBuffer * point), digits);
            if((current_sl == 0.0 || current_sl > target_sl) && ask <= target_sl - min_stop_dist)
              {
               m_trade.SetAsyncMode(false);
               if(m_trade.PositionModify(m_position.Ticket(), target_sl, current_tp))
                  Print("🛡️ AUTO-SL: Shifted SL to BREAKEVEN for ", sym, " SELL #", m_position.Ticket(), " at: ", target_sl);
              }
           }
        }
  }

//+------------------------------------------------------------------+
//| Execute Auto Trade Continuation                                  |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecuteAutoTrade(string sym, int direction)
  {
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double zBoundary = 0.0;
   string zName = "";
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   if(direction == 1)
     {
      if(!GetNearestBullishBoundary(sym, ask, zBoundary, zName))
         zBoundary = ask - (100 * point * 10);
      double sl = NormalizeDouble(zBoundary, digits);
      double lot = CalculateMaxAllowedLot(sym, 1);

      double req_margin = 0.0;
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(OrderCalcMargin(ORDER_TYPE_BUY, sym, lot, ask, req_margin) && req_margin > free_margin)
        {
         PrintFormat("🛑 AUTO BUY BLOCKED: Not enough free margin! Req: $%.2f | Free: $%.2f", req_margin, free_margin);
         return;
        }
      m_trade.SetAsyncMode(false);
      m_trade.Buy(lot, sym, ask, sl, 0.0, "Guardrail Safe Auto");
      PrintFormat("🚀 AUTO TRADE EXECUTED: BUY %.2f L on %s at %.5f (SL: %.5f)", lot, sym, ask, sl);
     }
   else
      if(direction == -1)
        {
         if(!GetNearestBearishBoundary(sym, bid, zBoundary, zName))
            zBoundary = bid + (100 * point * 10);
         double sl = NormalizeDouble(zBoundary, digits);
         double lot = CalculateMaxAllowedLot(sym, -1);

         double req_margin = 0.0;
         double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(OrderCalcMargin(ORDER_TYPE_SELL, sym, lot, bid, req_margin) && req_margin > free_margin)
           {
            PrintFormat("🛑 AUTO SELL BLOCKED: Not enough free margin! Req: $%.2f | Free: $%.2f", req_margin, free_margin);
            return;
           }
         m_trade.SetAsyncMode(false);
         m_trade.Sell(lot, sym, bid, sl, 0.0, "Guardrail Safe Auto");
         PrintFormat("🚀 AUTO TRADE EXECUTED: SELL %.2f L on %s at %.5f (SL: %.5f)", lot, sym, bid, sl);
        }
  }

//+------------------------------------------------------------------+
//| DYNAMIC TAKE PROFIT: Advanced Recursive Profit Protection Engine |
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckProfitProtectionGuard()
  {
   if(!m_enableProfitGuard)
      return;

   CleanProfitTrackers();

   int total = PositionsTotal();
   if(total == 0)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double activation_money = balance * (m_tpActivationPercent / 100.0);

   for(int i = total - 1; i >= 0; i--)
     {
      if(!m_position.SelectByIndex(i))
         continue;

      string pos_sym = m_position.Symbol();

      if(!m_manageAllSymbols && pos_sym != _Symbol)
         continue;

      if(m_magicNumber != 0 && m_position.Magic() != m_magicNumber)
         continue;

      ulong              ticket      = m_position.Ticket();
      double             open_price  = m_position.PriceOpen();
      double             current_sl  = m_position.StopLoss();
      double             volume      = m_position.Volume();
      ENUM_POSITION_TYPE pos_type    = m_position.PositionType();
      datetime           pos_time    = (datetime)m_position.Time();

      datetime bar_time_1 = iTime(pos_sym, _Period, 1);
      double   open_1     = iOpen(pos_sym, _Period, 1);
      double   close_1    = iClose(pos_sym, _Period, 1);

      if(bar_time_1 == 0 || open_1 == 0.0 || close_1 == 0.0)
         continue;

      if(bar_time_1 + PeriodSeconds(_Period) <= pos_time)
         continue;

      bool is_at_be = false;
      if(pos_type == POSITION_TYPE_BUY)
         is_at_be = (current_sl >= open_price && current_sl > 0.0);
      else
         if(pos_type == POSITION_TYPE_SELL)
            is_at_be = (current_sl <= open_price && current_sl > 0.0);

      if(!is_at_be)
         continue;

      int t_idx = GetOrCreateProfitTracker(ticket, pos_sym);

      if(m_profitTrackers[t_idx].last_processed_bar == bar_time_1)
         continue;

      double profit_at_close = 0.0;
      if(!OrderCalcProfit(pos_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                          pos_sym, volume, open_price, close_1, profit_at_close))
        {
         profit_at_close = m_position.Profit();
        }
      profit_at_close += (m_position.Swap() + m_position.Commission());

      // -------------------------------------------------------------
      // STAGE 0: Fresh position before any partial close has occurred
      // -------------------------------------------------------------
      if(!m_profitTrackers[t_idx].has_partial_closed)
        {
         if(!m_profitTrackers[t_idx].activated)
           {
            if(profit_at_close >= activation_money)
              {
               m_profitTrackers[t_idx].activated   = true;
               m_profitTrackers[t_idx].peak_profit = profit_at_close;
               m_profitTrackers[t_idx].peak_price  = close_1;
               SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
               PrintFormat("🎯 PROFIT GUARD ARMED: %s #%d closed candle with $%.2f profit (>= 1%% balance: $%.2f).",
                           pos_sym, ticket, profit_at_close, activation_money);
              }
           }
        }
      // -------------------------------------------------------------
      // STAGE 1+: Recursive Scale-Out Mode (Advanced Profit Saving)
      // -------------------------------------------------------------
      else
        {
         if(!m_profitTrackers[t_idx].activated)
           {
            if(m_advancedProfitSaving)
              {
               m_profitTrackers[t_idx].activated   = true;
               m_profitTrackers[t_idx].peak_profit = MathMax(m_profitTrackers[t_idx].gross_profit_remain, profit_at_close);
               m_profitTrackers[t_idx].peak_price  = close_1;
               SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
              }
            else
              {
               if(profit_at_close > m_profitTrackers[t_idx].net_profit_remain)
                 {
                  m_profitTrackers[t_idx].activated   = true;
                  m_profitTrackers[t_idx].peak_profit = profit_at_close;
                  m_profitTrackers[t_idx].peak_price  = close_1;
                  SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
                  PrintFormat("🎯 PROFIT GUARD RE-ARMED: %s #%d remaining profit ($%.2f) > net_profit_remain ($%.2f).",
                              pos_sym, ticket, profit_at_close, m_profitTrackers[t_idx].net_profit_remain);
                 }
              }
           }
        }

      // Track new peak profit
      if(m_profitTrackers[t_idx].activated && profit_at_close > m_profitTrackers[t_idx].peak_profit)
        {
         m_profitTrackers[t_idx].peak_profit = profit_at_close;
         m_profitTrackers[t_idx].peak_price  = close_1;
         SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
        }

      // Check for opposing candle close
      bool is_opposing_candle = false;
      if(pos_type == POSITION_TYPE_BUY)
         is_opposing_candle = (close_1 < open_1);
      else
         if(pos_type == POSITION_TYPE_SELL)
            is_opposing_candle = (close_1 > open_1);

      if(is_opposing_candle && m_profitTrackers[t_idx].peak_profit > 0.0)
        {
         double profit_erased = m_profitTrackers[t_idx].peak_profit - profit_at_close;
         double giveback_pct  = (profit_erased / m_profitTrackers[t_idx].peak_profit) * 100.0;

         if(giveback_pct >= m_maxProfitGivebackPercent)
           {
            double lot_step   = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_STEP);
            double min_lot    = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_MIN);
            double max_lot    = SymbolInfoDouble(pos_sym, SYMBOL_VOLUME_MAX);
            if(lot_step <= 0.0)
               lot_step = 0.01;
            if(min_lot <= 0.0)
               min_lot  = 0.01;
            int lot_digits    = (int)MathMax(0.0, MathCeil(-MathLog10(lot_step)));

            double close_vol = NormalizeDouble(volume * (m_partialClosePercent / 100.0), lot_digits);
            if(lot_step > 0.0)
               close_vol = MathFloor(close_vol / lot_step) * lot_step;
            close_vol = NormalizeDouble(close_vol, lot_digits);

            double remain_vol = NormalizeDouble(volume - close_vol, lot_digits);

            bool allow_partial = (close_vol >= min_lot && remain_vol >= min_lot && close_vol <= max_lot);

            if(!allow_partial)
              {
               PrintFormat("🛑 PROFIT GUARD: Broker limits do not allow partial close of %.2f L on %s #%d. Closing full position!",
                           close_vol, pos_sym, ticket);

               m_trade.SetAsyncMode(false);
               if(m_trade.PositionClose(ticket))
                 {
                  DeleteProfitTrackerGV(ticket);
                  string vi_msg = StringFormat("-%.0f%% Giveback", giveback_pct);
                  TriggerGuardrailViolation(ticket, pos_sym, volume, CalculateMaxAllowedLot(pos_sym, 0),
                                            profit_at_close, vi_msg, "Full TP Close");
                 }
              }
            else
              {
               m_trade.SetAsyncMode(false);
               if(m_trade.PositionClosePartial(ticket, close_vol))
                 {
                  double remain_ratio = remain_vol / volume;

                  if(m_profitTrackers[t_idx].partial_close_count == 0)
                     m_profitTrackers[t_idx].first_peak_price = m_profitTrackers[t_idx].peak_price;

                  m_profitTrackers[t_idx].net_profit_full     = m_profitTrackers[t_idx].peak_profit;
                  m_profitTrackers[t_idx].gross_profit_full   = profit_at_close;
                  m_profitTrackers[t_idx].net_profit_remain   = m_profitTrackers[t_idx].net_profit_full * remain_ratio;
                  m_profitTrackers[t_idx].gross_profit_remain = m_profitTrackers[t_idx].gross_profit_full * remain_ratio;
                  m_profitTrackers[t_idx].has_partial_closed  = true;
                  m_profitTrackers[t_idx].partial_close_count++;

                  m_profitTrackers[t_idx].peak_profit = m_profitTrackers[t_idx].gross_profit_remain;
                  m_profitTrackers[t_idx].peak_price  = close_1;
                  m_profitTrackers[t_idx].activated   = m_advancedProfitSaving;

                  SaveProfitTrackerToGV(m_profitTrackers[t_idx]);

                  PrintFormat("🎯 PARTIAL CLOSE #%d SUCCESS: %s #%d | Closed: %.2f L (%.0f%%), Remaining: %.2f L",
                              m_profitTrackers[t_idx].partial_close_count, pos_sym, ticket, close_vol, m_partialClosePercent, remain_vol);
                  PrintFormat("   -> net_profit_full   = $%.4f", m_profitTrackers[t_idx].net_profit_full);
                  PrintFormat("   -> gross_profit_full = $%.4f", m_profitTrackers[t_idx].gross_profit_full);
                  PrintFormat("   -> net_profit_remain = $%.4f", m_profitTrackers[t_idx].net_profit_remain);
                  PrintFormat("   -> gross_profit_rem  = $%.4f", m_profitTrackers[t_idx].gross_profit_remain);

                  double realized_profit = profit_at_close * (close_vol / volume);
                  string vi_msg = StringFormat("-%.0f%% Retrace", giveback_pct);
                  TriggerGuardrailViolation(ticket, pos_sym, close_vol, CalculateMaxAllowedLot(pos_sym, 0),
                                            realized_profit, vi_msg, StringFormat("Partial %.0f%%", m_partialClosePercent));
                 }
              }
           }
        }

      // -------------------------------------------------------------
      // AUTO-TRADE CONTINUATION CHECK
      // -------------------------------------------------------------
      if(m_autoTradeContinuation && m_profitTrackers[t_idx].has_partial_closed && !m_profitTrackers[t_idx].auto_trade_triggered && m_profitTrackers[t_idx].first_peak_price > 0.0)
        {
         bool trigger_auto = false;
         if(pos_type == POSITION_TYPE_BUY && close_1 > m_profitTrackers[t_idx].first_peak_price)
            trigger_auto = true;
         else
            if(pos_type == POSITION_TYPE_SELL && close_1 < m_profitTrackers[t_idx].first_peak_price)
               trigger_auto = true;

         if(trigger_auto)
           {
            m_profitTrackers[t_idx].auto_trade_triggered = true;
            SaveProfitTrackerToGV(m_profitTrackers[t_idx]);
            ExecuteAutoTrade(pos_sym, (pos_type == POSITION_TYPE_BUY) ? 1 : -1);
           }
        }

      m_profitTrackers[t_idx].last_processed_bar = bar_time_1;
     }
  }

//+------------------------------------------------------------------+
//| MASTER SHIELD LOOP (Safe Running Mode + External Trade Auditor)  |
//+------------------------------------------------------------------+
void CGuardrailsCore::RunMasterShield()
  {
   UpdateSMCZones();

// Audit unverified / mobile trades once against entry coordinates
   AuditRunningPositions();

// Dynamic TP Partial Close Guardrail
   CheckProfitProtectionGuard();

   int total = PositionsTotal();
   if(total == 0)
      return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         string pos_sym = m_position.Symbol();

         if(!m_manageAllSymbols && pos_sym != _Symbol)
            continue;

         if(m_magicNumber == 0 || m_position.Magic() == m_magicNumber)
           {
            if(m_emergencyCircuitBreaker)
               CheckEmergencyLossCut(pos_sym);

            if(m_autoBreakeven)
               CheckAndSetBreakevenSL(pos_sym);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Current Loss on Position                               |
//+------------------------------------------------------------------+
double CGuardrailsCore::CalculateCurrentLoss(double volume, string sym)
  {
   double cur_loss = m_position.Profit() + m_position.Swap();
   if(cur_loss >= 0.0)
     {
      double tick_sz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double pt       = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(tick_sz <= 0.0)
         tick_sz = pt;
      double tick_val = GetSymbolTickValue(sym);
      long   sp_pts   = SymbolInfoInteger(sym, SYMBOL_SPREAD);
      if(sp_pts <= 0)
        {
         double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
         double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         if(pt > 0 && ask > bid)
            sp_pts = (long)MathRound((ask - bid) / pt);
        }
      if(tick_sz > 0 && pt > 0)
         cur_loss = -((sp_pts * pt / tick_sz) * tick_val * volume);
     }
   return cur_loss;
  }

//+------------------------------------------------------------------+
//| Circuit Breaker Loss Cut                                         |
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckEmergencyLossCut(string sym)
  {
   ulong ticket = m_position.Ticket();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_risk_money = balance * (m_maxRiskPercent / 100.0);
   double volume = m_position.Volume();

   double current_profit = m_position.Profit() + m_position.Swap();

   if(current_profit <= -max_risk_money)
     {
      m_trade.SetAsyncMode(true);
      m_trade.PositionClose(ticket);
      TriggerGuardrailViolation(ticket, sym, volume, volume, current_profit, "1% Circuit Cut", "Emergency");
     }
  }

//+------------------------------------------------------------------+
//| Pre-Trade Buy                                                    |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecutePreTradeBuy()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockLongsInBearish && IsInBearishZone(ask, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, false);
      Print("🛑 BUY BLOCKED: Price is currently inside a Bearish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBullishBoundary(_Symbol, ask, zBoundary, zName))
      zBoundary = ask - (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_buy = CalculateMaxAllowedLot(_Symbol, 1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_buy : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_buy)
     {
      double oversize = lot_to_trade - max_safe_buy;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 BUY BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_buy));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot_to_trade, ask, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 BUY BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_buy, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Buy(lot_to_trade, _Symbol, ask, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

//+------------------------------------------------------------------+
//| Pre-Trade Sell                                                   |
//+------------------------------------------------------------------+
void CGuardrailsCore::ExecutePreTradeSell()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("⚠️ Please click 'Algo Trading' on your MT5 toolbar to allow panel orders!");
      return;
     }

   double   bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double   zBoundary = 0.0;
   string   zName     = "";
   double   zLow = 0.0, zHigh = 0.0;
   datetime zTime     = 0;

   if(m_blockShortsInBullish && IsInBullishZone(bid, zName, zLow, zHigh, zTime))
     {
      TriggerGuardrailViolation(0, _Symbol, m_panel_lot, 0.0, 0.0, zName, "Blocked");
      HighlightViolatedZone(zName, zLow, zHigh, zTime, true);
      Print("🛑 SELL BLOCKED: Price is currently inside a Bullish Zone (", zName, ")!");
      return;
     }

   if(!GetNearestBearishBoundary(_Symbol, bid, zBoundary, zName))
      zBoundary = bid + (100 * _Point * 10);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl  = NormalizeDouble(zBoundary, digits);

   double max_safe_sell = CalculateMaxAllowedLot(_Symbol, -1);
   double lot_to_trade = m_auto_lot_enabled ? max_safe_sell : m_panel_lot;

   if(m_enforceMaxLot && lot_to_trade > max_safe_sell)
     {
      double oversize = lot_to_trade - max_safe_sell;
      TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, StringFormat("+%.2f L Over", oversize), "Blocked");
      Print(StringFormat("🛑 SELL BLOCKED: Lot size %.2f L exceeds 1%% zone limit (Max Safe: %.2f L)!", lot_to_trade, max_safe_sell));
      return;
     }

   double req_margin  = 0.0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lot_to_trade, bid, req_margin))
     {
      if(req_margin > free_margin)
        {
         Print(StringFormat("🛑 SELL BLOCKED: Not enough free margin! Required: $%.2f | Free: $%.2f", req_margin, free_margin));
         TriggerGuardrailViolation(0, _Symbol, lot_to_trade, max_safe_sell, 0.0, "No Margin", "Blocked");
         return;
        }
     }

   m_trade.SetAsyncMode(false);
   if(m_trade.Sell(lot_to_trade, _Symbol, bid, sl, 0.0, "Guardrail Safe"))
     {
      OnPreTradeExecuted(lot_to_trade);
     }
  }

//+------------------------------------------------------------------+
//| Violated Zone Highlighting (10-Second Flash)                     |
//+------------------------------------------------------------------+
void CGuardrailsCore::HighlightViolatedZone(string zoneType, double zLow, double zHigh, datetime zTime, bool isBullish)
  {
   if(zLow <= 0 || zHigh <= 0)
      return;

   m_flash_zone_active = true;
   m_flash_zone_expire = TimeLocal() + 10;

   string boxName = m_flash_zone_name + "_Box";
   string lblName = m_flash_zone_name + "_Lbl";

   ObjectDelete(0, boxName);
   ObjectDelete(0, lblName);

   datetime t1 = (zTime > 0) ? zTime : (TimeCurrent() - (PeriodSeconds() * 20));
   datetime t2 = TimeCurrent() + (PeriodSeconds() * 30);

   color zoneClr   = isBullish ? clrMediumSeaGreen : clrIndianRed;
   color borderClr = isBullish ? clrLime : clrRed;

   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, t1, zHigh, t2, zLow);
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, borderClr);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, zoneClr);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_ZORDER, 1);

   datetime midTime = t1 + (datetime)((t2 - t1) / 2);
   double midPrice  = zLow + (zHigh - zLow) / 2.0;

   ObjectCreate(0, lblName, OBJ_TEXT, 0, midTime, midPrice);
   ObjectSetString(0, lblName, OBJPROP_TEXT, "VIOLATED: " + zoneType);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, lblName, OBJPROP_BACK, true);
   ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 2);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Expire Violated Zone                                             |
//+------------------------------------------------------------------+
void CGuardrailsCore::CheckViolatedZoneExpiration()
  {
   if(!m_flash_zone_active)
      return;

   if(TimeLocal() >= m_flash_zone_expire)
     {
      m_flash_zone_active = false;
      ObjectDelete(0, m_flash_zone_name + "_Box");
      ObjectDelete(0, m_flash_zone_name + "_Lbl");
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//| Zone Collision Detection (Supports Historical Entry Inspection)   |
//+------------------------------------------------------------------+
bool CGuardrailsCore::IsInBullishZone(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time)
  {
   outLow  = 0.0;
   outHigh = 0.0;
   outTime = 0;

   if(m_useDemandSupply && m_dsLogic != NULL)
     {
      for(int i = 0; i < m_dsLogic.poi_demandTime.Total(); i++)
        {
         datetime zT = (datetime)m_dsLogic.poi_demandTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_dsLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow  = m_dsLogic.poi_demandZoneLow.At(i);
            double zHigh = m_dsLogic.poi_demandZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Demand Zone";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useFlipZones && m_fzLogic != NULL)
     {
      for(int i = 0; i < m_fzLogic.fz_time.Total(); i++)
        {
         datetime zT = (datetime)m_fzLogic.fz_time.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_fzLogic.fz_mitigated.At(i) == 0 && m_fzLogic.fz_type.At(i) == 1)
           {
            double zLow  = m_fzLogic.fz_zoneLow.At(i);
            double zHigh = m_fzLogic.fz_zoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bullish Flip Zone";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useBreakerBlocks && m_bbLogic != NULL)
     {
      for(int i = 0; i < m_bbLogic.bb_time.Total(); i++)
        {
         datetime zT = (datetime)m_bbLogic.bb_time.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_bbLogic.bb_mitigated.At(i) == 0 && m_bbLogic.bb_type.At(i) == 1)
           {
            double zLow  = m_bbLogic.bb_zoneLow.At(i);
            double zHigh = m_bbLogic.bb_zoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bullish Breaker";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useOrderBlocks && m_obLogic != NULL)
     {
      for(int i = 0; i < m_obLogic.poi_demandTime.Total(); i++)
        {
         datetime zT = (datetime)m_obLogic.poi_demandTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_obLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow  = m_obLogic.poi_demandZoneLow.At(i);
            double zHigh = m_obLogic.poi_demandZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bullish Order Block";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useSwingPOIs && m_spLogic != NULL)
     {
      for(int i = 0; i < m_spLogic.poi_demandTime.Total(); i++)
        {
         datetime zT = (datetime)m_spLogic.poi_demandTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_spLogic.poi_demandMitigated.At(i) == 0)
           {
            double zLow  = m_spLogic.poi_demandZoneLow.At(i);
            double zHigh = m_spLogic.poi_demandZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bullish Swing POI";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CGuardrailsCore::IsInBearishZone(double price, string &zoneType, double &outLow, double &outHigh, datetime &outTime, datetime at_time)
  {
   outLow  = 0.0;
   outHigh = 0.0;
   outTime = 0;

   if(m_useDemandSupply && m_dsLogic != NULL)
     {
      for(int i = 0; i < m_dsLogic.poi_supplyTime.Total(); i++)
        {
         datetime zT = (datetime)m_dsLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_dsLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zLow  = m_dsLogic.poi_supplyZoneLow.At(i);
            double zHigh = m_dsLogic.poi_supplyZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Supply Zone";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useFlipZones && m_fzLogic != NULL)
     {
      for(int i = 0; i < m_fzLogic.fz_time.Total(); i++)
        {
         datetime zT = (datetime)m_fzLogic.fz_time.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_fzLogic.fz_mitigated.At(i) == 0 && m_fzLogic.fz_type.At(i) == -1)
           {
            double zLow  = m_fzLogic.fz_zoneLow.At(i);
            double zHigh = m_fzLogic.fz_zoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bearish Flip Zone";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useBreakerBlocks && m_bbLogic != NULL)
     {
      for(int i = 0; i < m_bbLogic.bb_time.Total(); i++)
        {
         datetime zT = (datetime)m_bbLogic.bb_time.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_bbLogic.bb_mitigated.At(i) == 0 && m_bbLogic.bb_type.At(i) == -1)
           {
            double zLow  = m_bbLogic.bb_zoneLow.At(i);
            double zHigh = m_bbLogic.bb_zoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bearish Breaker";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useOrderBlocks && m_obLogic != NULL)
     {
      for(int i = 0; i < m_obLogic.poi_supplyTime.Total(); i++)
        {
         datetime zT = (datetime)m_obLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_obLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zLow  = m_obLogic.poi_supplyZoneLow.At(i);
            double zHigh = m_obLogic.poi_supplyZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bearish Order Block";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   if(m_useSwingPOIs && m_spLogic != NULL)
     {
      for(int i = 0; i < m_spLogic.poi_supplyTime.Total(); i++)
        {
         datetime zT = (datetime)m_spLogic.poi_supplyTime.At(i);
         if(at_time > 0 && zT > at_time)
            continue;

         if(m_spLogic.poi_supplyMitigated.At(i) == 0)
           {
            double zLow  = m_spLogic.poi_supplyZoneLow.At(i);
            double zHigh = m_spLogic.poi_supplyZoneHigh.At(i);
            if(price >= zLow && price <= zHigh)
              {
               zoneType = "Bearish Swing POI";
               outLow   = zLow;
               outHigh  = zHigh;
               outTime  = zT;
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| PineBox Drawing Helper for Zones                                 |
//+------------------------------------------------------------------+
void CGuardrailsCore::DrawZoneBox(string boxName, datetime t1, double high_p, datetime t2, double low_p, color bgClr, color borderClr, string labelText, color textClr)
  {
   if(ObjectFind(0, boxName) < 0)
      ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, t1, high_p, t2, low_p);
   else
     {
      ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, high_p);
      ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, low_p);
     }
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, bgClr);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);

   string lblName = boxName + "_lbl";
   if(labelText != "")
     {
      datetime midTime  = t1 + (datetime)((t2 - t1) / 2);
      double   midPrice = low_p + (high_p - low_p) / 2.0;

      if(ObjectFind(0, lblName) < 0)
         ObjectCreate(0, lblName, OBJ_TEXT, 0, midTime, midPrice);
      else
        {
         ObjectSetInteger(0, lblName, OBJPROP_TIME, midTime);
         ObjectSetDouble(0, lblName, OBJPROP_PRICE, midPrice);
        }
      ObjectSetString(0, lblName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, textClr);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, lblName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectDelete(0, lblName);
     }
  }

//+------------------------------------------------------------------+
//| Draw Active SMC Zones with Full PineScript Hierarchy & Colors    |
//+------------------------------------------------------------------+
void CGuardrailsCore::DrawActiveSMCZones()
  {
   ObjectsDeleteAll(0, "SMC_");
   if(!m_drawZones)
      return;

   datetime extend_right = TimeCurrent() + (PeriodSeconds() * 35);
   string tf_prefix = (m_ms != NULL) ? m_ms.tf_str() : "";

   color POI_DEMAND_COLOR    = ColorToARGB_Custom(clrGreen, 46);
   color POI_SUPPLY_COLOR    = ColorToARGB_Custom(clrRed, 46);
   color OB_BULL_FILL        = ColorToARGB_Custom(C'10,123,167', 51);
   color OB_BULL_TEXT        = C'10,123,167';
   color OB_BEAR_FILL        = ColorToARGB_Custom(C'173,86,145', 51);
   color OB_BEAR_TEXT        = C'173,86,145';
   color POI_SWING_BULL_FILL = ColorToARGB_Custom(C'0,100,0', 51);
   color POI_SWING_BULL_TEXT = C'0,100,0';
   color POI_SWING_BEAR_FILL = ColorToARGB_Custom(C'128,0,0', 51);
   color POI_SWING_BEAR_TEXT = C'128,0,0';
   color FLIP_DEMAND_COLOR   = ColorToARGB_Custom(clrGreen, 46);
   color FLIP_SUPPLY_COLOR   = ColorToARGB_Custom(clrRed, 46);
   color BB_BULL_COLOR       = ColorToARGB_Custom(clrGreen, 46);
   color BB_BEAR_COLOR       = ColorToARGB_Custom(clrRed, 46);

// 1. Demand & Derived Zones (Order Blocks, Swing POIs, Demand)
   if(m_dsLogic != NULL)
     {
      for(int i = 0; i < m_dsLogic.poi_demandTime.Total(); i++)
        {
         if(m_dsLogic.poi_demandMitigated.At(i) == 0)
           {
            datetime p_time = (datetime)m_dsLogic.poi_demandTime.At(i);
            double zHigh    = m_dsLogic.poi_demandZoneHigh.At(i);
            double zLow     = m_dsLogic.poi_demandZoneLow.At(i);

            bool is_bull_poi = (m_spLogic != NULL) && m_spLogic.ob_time_found(&m_ms.ob_bull_struct_times, p_time);
            bool is_bull_ob  = false;

            if(is_bull_poi && m_obLogic != NULL)
              {
               if(m_obLogic.ob_time_found(&m_obLogic.ob_bull_valid_times, p_time))
                  is_bull_ob = true;
              }

            if(is_bull_ob && m_useOrderBlocks)
              {
               DrawZoneBox("SMC_OB_D_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                           OB_BULL_FILL, OB_BULL_TEXT, tf_prefix + " BULLISH ORDER-BLOCK", OB_BULL_TEXT);
              }
            else
               if(is_bull_poi && m_useSwingPOIs)
                 {
                  DrawZoneBox("SMC_POI_D_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                              POI_SWING_BULL_FILL, POI_SWING_BULL_TEXT, tf_prefix + " BULLISH POI", POI_SWING_BULL_TEXT);
                 }
               else
                  if(m_useDemandSupply)
                    {
                     DrawZoneBox("SMC_DS_D_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                                 POI_DEMAND_COLOR, clrGreen, tf_prefix + "-DemandZone", clrGreen);
                    }
           }
        }

      // Supply & Derived Zones
      for(int i = 0; i < m_dsLogic.poi_supplyTime.Total(); i++)
        {
         if(m_dsLogic.poi_supplyMitigated.At(i) == 0)
           {
            datetime p_time = (datetime)m_dsLogic.poi_supplyTime.At(i);
            double zHigh    = m_dsLogic.poi_supplyZoneHigh.At(i);
            double zLow     = m_dsLogic.poi_supplyZoneLow.At(i);

            bool is_bear_poi = (m_spLogic != NULL) && m_spLogic.ob_time_found(&m_ms.ob_bear_struct_times, p_time);
            bool is_bear_ob  = false;

            if(is_bear_poi && m_obLogic != NULL)
              {
               if(m_obLogic.ob_time_found(&m_obLogic.ob_bear_valid_times, p_time))
                  is_bear_ob = true;
              }

            if(is_bear_ob && m_useOrderBlocks)
              {
               DrawZoneBox("SMC_OB_S_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                           OB_BEAR_FILL, OB_BEAR_TEXT, tf_prefix + " BEARISH ORDER-BLOCK", OB_BEAR_TEXT);
              }
            else
               if(is_bear_poi && m_useSwingPOIs)
                 {
                  DrawZoneBox("SMC_POI_S_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                              POI_SWING_BEAR_FILL, POI_SWING_BEAR_TEXT, tf_prefix + " BEARISH POI", POI_SWING_BEAR_TEXT);
                 }
               else
                  if(m_useDemandSupply)
                    {
                     DrawZoneBox("SMC_DS_S_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                                 POI_SUPPLY_COLOR, clrRed, tf_prefix + "-SupplyZone", clrRed);
                    }
           }
        }
     }

// 2. Flip Zones
   if(m_useFlipZones && m_fzLogic != NULL)
     {
      for(int i = 0; i < m_fzLogic.fz_time.Total(); i++)
        {
         if(m_fzLogic.fz_mitigated.At(i) == 0)
           {
            datetime p_time = (datetime)m_fzLogic.fz_time.At(i);
            double zHigh    = m_fzLogic.fz_zoneHigh.At(i);
            double zLow     = m_fzLogic.fz_zoneLow.At(i);
            int zType       = m_fzLogic.fz_type.At(i);

            if(zType == 1)
              {
               DrawZoneBox("SMC_FLIP_D_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                           FLIP_DEMAND_COLOR, clrGreen, tf_prefix + " DEMAND FLIP", clrGreen);
              }
            else
               if(zType == -1)
                 {
                  DrawZoneBox("SMC_FLIP_S_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                              FLIP_SUPPLY_COLOR, clrRed, tf_prefix + " SUPPLY FLIP", clrRed);
                 }
           }
        }
     }

// 3. Breaker Blocks
   if(m_useBreakerBlocks && m_bbLogic != NULL)
     {
      for(int i = 0; i < m_bbLogic.bb_time.Total(); i++)
        {
         if(m_bbLogic.bb_mitigated.At(i) == 0)
           {
            datetime p_time = (datetime)m_bbLogic.bb_time.At(i);
            double zHigh    = m_bbLogic.bb_zoneHigh.At(i);
            double zLow     = m_bbLogic.bb_zoneLow.At(i);
            int zType       = m_bbLogic.bb_type.At(i);

            if(zType == 1)
              {
               DrawZoneBox("SMC_BB_BULL_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                           BB_BULL_COLOR, clrGreen, tf_prefix + "-Bullish-Breaker", clrGreen);
              }
            else
               if(zType == -1)
                 {
                  DrawZoneBox("SMC_BB_BEAR_" + IntegerToString(p_time), p_time, zHigh, extend_right, zLow,
                              BB_BEAR_COLOR, clrRed, tf_prefix + "-Bearish-Breaker", clrRed);
                 }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Send Drawings to Background & Disable Mouse Selection            |
//+------------------------------------------------------------------+
void CGuardrailsCore::EnforceDrawingsBackground()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "ZZ_") == 0 ||
         StringFind(name, "BOSCHoCH_") == 0 ||
         StringFind(name, "SWING_") == 0 ||
         StringFind(name, "SMC_") == 0 ||
         StringFind(name, "RG_Violated_") == 0)
        {
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
     }
  }

//+------------------------------------------------------------------+
//| Master SMC & ZigZag Synchronization Module (Ticks + New Bars)    |
//+------------------------------------------------------------------+
void CGuardrailsCore::UpdateSMCZones()
  {
   datetime cur_time  = iTime(_Symbol, _Period, 0);
   double   cur_bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double   cur_ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

// Update real-time mitigation levels on every incoming tick
   if(m_dsLogic != NULL)
      m_dsLogic.UpdateMitigation(cur_bid);
   if(m_fzLogic != NULL)
      m_fzLogic.UpdateMitigation(cur_bid);
   if(m_obLogic != NULL)
      m_obLogic.UpdateMitigation(cur_bid);
   if(m_spLogic != NULL)
      m_spLogic.UpdateMitigation(cur_bid);
   if(m_bbLogic != NULL)
      m_bbLogic.UpdateMitigation(cur_ask, cur_bid, TimeCurrent());

   CheckViolatedZoneExpiration();

   double activeDev = 0.5;
   int    activeDep = 10;
   int    activeLookback = 3000;
   GetActiveZigZagParams(activeDev, activeDep, activeLookback);

// TRIGGER FULL RE-INITIALIZATION IF INPUTS CHANGED OR TIMEFRAME CHANGED
   if(!m_smc_initialized || m_last_period != _Period || activeDev != m_last_dev || activeDep != m_last_dep)
     {
      m_last_dev    = activeDev;
      m_last_dep    = activeDep;
      m_last_period = _Period;

      int rates_total = Bars(_Symbol, _Period);
      if(rates_total < activeDep * 2)
         return;

      int bars_to_load = (int)MathMax(50, MathMin(activeLookback, rates_total));

      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      int copied = CopyRates(_Symbol, _Period, 0, bars_to_load, rates);
      if(copied < activeDep * 2)
         return;

      ArrayResize(m_chart_times, copied);
      ArrayResize(m_chart_highs, copied);
      ArrayResize(m_chart_lows, copied);
      ArrayResize(m_chart_closes, copied);
      m_chart_bars_loaded = copied;

      for(int j = 0; j < copied; j++)
        {
         m_chart_times[j]  = rates[j].time;
         m_chart_highs[j]  = rates[j].high;
         m_chart_lows[j]   = rates[j].low;
         m_chart_closes[j] = rates[j].close;
        }

      // Cleanup prior drawings
      ObjectsDeleteAll(0, "ZZ_Ln_");
      ObjectsDeleteAll(0, "ZZ_Lbl_");
      ObjectsDeleteAll(0, "ZZ_Proj_");
      ObjectsDeleteAll(0, "BOSCHoCH_");
      ObjectsDeleteAll(0, "SWING_");
      ObjectsDeleteAll(0, "SMC_");

      m_dsLogic.ResetState();
      m_spLogic.ResetState();
      m_obLogic.ResetState();
      m_fzLogic.ResetState();
      m_bbLogic.ResetState();
      m_ms.ResetState();
      m_ms.Init(m_drawMarketStructure, m_drawMarketStructure);

      if(CheckPointer(m_zigZag) == POINTER_DYNAMIC)
         delete m_zigZag;

      Settings* s = new Settings(activeDev, activeDep, m_zzLineColor, m_zzExtend, m_zzShowPrice, m_zzShowVol, m_zzShowChg, m_zzPriceDiff);
      s.draw = m_drawZigZag;
      m_zigZag = newInstance(s);

      for(int i = 0; i < copied; i++)
        {
         bool is_last = (i == copied - 1);
         m_zigZag.update(m_chart_highs[i], m_chart_lows[i], m_chart_times[i], rates[i].tick_volume, i, !is_last, is_last);
         m_ms.Update(i, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag);

         m_dsLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_dsLogic.UpdateMitigation(m_chart_closes[i]);

         m_spLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_spLogic.UpdateMitigation(m_chart_closes[i]);

         m_obLogic.DetectPOIs(i, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
         m_obLogic.UpdateMitigation(m_chart_closes[i]);

         if(m_obLogic.poi_demandTime.Total() > 0)
           {
            datetime tz = (datetime)m_obLogic.poi_demandTime.At(m_obLogic.poi_demandTime.Total() - 1);
            if(m_obLogic.ob_time_found(&m_ms.ob_bull_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bull_valid_times, tz))
               if(m_obLogic.CheckBullishOB(tz, i, m_chart_times, m_chart_highs, m_chart_lows))
                  m_obLogic.ob_bull_valid_times.Add((long)tz);
           }
         if(m_obLogic.poi_supplyTime.Total() > 0)
           {
            datetime tz = (datetime)m_obLogic.poi_supplyTime.At(m_obLogic.poi_supplyTime.Total() - 1);
            if(m_obLogic.ob_time_found(&m_ms.ob_bear_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bear_valid_times, tz))
               if(m_obLogic.CheckBearishOB(tz, i, m_chart_times, m_chart_highs, m_chart_lows))
                  m_obLogic.ob_bear_valid_times.Add((long)tz);
           }

         m_fzLogic.DetectFlipZones(i, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag, m_ms, m_dsLogic);
         m_fzLogic.UpdateMitigation(m_chart_closes[i]);

         m_bbLogic.DetectBreakers(m_zigZag, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic);
         m_bbLogic.UpdateMitigation(m_chart_highs[i], m_chart_lows[i], m_chart_times[i]);
        }

      DrawActiveSMCZones();
      EnforceDrawingsBackground();
      ChartRedraw(0);

      m_smc_initialized   = true;
      m_last_smc_bar_time = cur_time;
      return;
     }

// Real-time tick & new bar maintenance
   MqlRates current_rates[];
   ArraySetAsSeries(current_rates, false);
   if(CopyRates(_Symbol, _Period, 0, 2, current_rates) < 2)
      return;

   int last_idx = m_chart_bars_loaded - 1;

   if(cur_time > m_last_smc_bar_time)
     {
      // New bar opened: append into buffer
      m_last_smc_bar_time = cur_time;
      m_chart_bars_loaded++;
      last_idx = m_chart_bars_loaded - 1;

      ArrayResize(m_chart_times, m_chart_bars_loaded);
      ArrayResize(m_chart_highs, m_chart_bars_loaded);
      ArrayResize(m_chart_lows, m_chart_bars_loaded);
      ArrayResize(m_chart_closes, m_chart_bars_loaded);

      m_chart_times[last_idx]  = current_rates[1].time;
      m_chart_highs[last_idx]  = current_rates[1].high;
      m_chart_lows[last_idx]   = current_rates[1].low;
      m_chart_closes[last_idx] = current_rates[1].close;
     }
   else
     {
      // Ongoing tick: update current bar's values
      m_chart_highs[last_idx]  = current_rates[1].high;
      m_chart_lows[last_idx]   = current_rates[1].low;
      m_chart_closes[last_idx] = current_rates[1].close;
     }

// Update ZigZag and Market Structure live
   m_zigZag.update(m_chart_highs[last_idx], m_chart_lows[last_idx], m_chart_times[last_idx], current_rates[1].tick_volume, last_idx, false, true);
   m_ms.Update(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag);

   m_dsLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
   m_spLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);
   m_obLogic.DetectPOIs(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_zigZag);

   if(m_obLogic.poi_demandTime.Total() > 0)
     {
      datetime tz = (datetime)m_obLogic.poi_demandTime.At(m_obLogic.poi_demandTime.Total() - 1);
      if(m_obLogic.ob_time_found(&m_ms.ob_bull_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bull_valid_times, tz))
         if(m_obLogic.CheckBullishOB(tz, last_idx, m_chart_times, m_chart_highs, m_chart_lows))
            m_obLogic.ob_bull_valid_times.Add((long)tz);
     }
   if(m_obLogic.poi_supplyTime.Total() > 0)
     {
      datetime tz = (datetime)m_obLogic.poi_supplyTime.At(m_obLogic.poi_supplyTime.Total() - 1);
      if(m_obLogic.ob_time_found(&m_ms.ob_bear_struct_times, tz) && !m_obLogic.ob_time_found(&m_obLogic.ob_bear_valid_times, tz))
         if(m_obLogic.CheckBearishOB(tz, last_idx, m_chart_times, m_chart_highs, m_chart_lows))
            m_obLogic.ob_bear_valid_times.Add((long)tz);
     }

   m_fzLogic.DetectFlipZones(last_idx, m_chart_times, m_chart_highs, m_chart_lows, m_chart_closes, m_zigZag, m_ms, m_dsLogic);
   m_bbLogic.DetectBreakers(m_zigZag, m_dsLogic, m_spLogic, m_obLogic, m_fzLogic);

   DrawActiveSMCZones();
   EnforceDrawingsBackground();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Asset Classification Detection                                   |
//+------------------------------------------------------------------+
ENUM_ASSET_TYPE CGuardrailsCore::DetectAssetType(string sym)
  {
   string upper = sym;
   StringToUpper(upper);

   if(StringFind(upper, "XAU") >= 0 || StringFind(upper, "GOLD") >= 0 ||
      StringFind(upper, "XAG") >= 0 || StringFind(upper, "SILVER") >= 0 ||
      StringFind(upper, "XPT") >= 0 || StringFind(upper, "XPD") >= 0)
      return ASSET_TYPE_METALS;

   if(StringFind(upper, "BTC") >= 0 || StringFind(upper, "ETH") >= 0 ||
      StringFind(upper, "USDT") >= 0 || StringFind(upper, "SOL") >= 0 ||
      StringFind(upper, "XRP") >= 0 || StringFind(upper, "DOGE") >= 0 ||
      StringFind(upper, "LTC") >= 0 || StringFind(upper, "CRYPTO") >= 0)
      return ASSET_TYPE_CRYPTO;

   return ASSET_TYPE_FOREX;
  }

//+------------------------------------------------------------------+
//| ZigZag Params Resolver                                           |
//+------------------------------------------------------------------+
void CGuardrailsCore::GetActiveZigZagParams(double &outDev, int &outDep, int &outLookback)
  {
   ENUM_ASSET_TYPE asset = (m_assetCategory == ASSET_TYPE_AUTO) ? DetectAssetType(_Symbol) : m_assetCategory;

   if(asset == ASSET_TYPE_METALS)
     {
      outLookback = m_zzParams.met_maxLookback;
      switch(_Period)
        {
         case PERIOD_D1:
            outDev = m_zzParams.met_dev_D1;
            outDep = (int)m_zzParams.met_dep_D1;
            break;
         case PERIOD_H4:
            outDev = m_zzParams.met_dev_H4;
            outDep = (int)m_zzParams.met_dep_H4;
            break;
         case PERIOD_H1:
            outDev = m_zzParams.met_dev_H1;
            outDep = (int)m_zzParams.met_dep_H1;
            break;
         case PERIOD_M15:
            outDev = m_zzParams.met_dev_M15;
            outDep = (int)m_zzParams.met_dep_M15;
            break;
         case PERIOD_M1:
            outDev = m_zzParams.met_dev_M1;
            outDep = (int)m_zzParams.met_dep_M1;
            break;
         default:
            if(_Period < PERIOD_M15)
              {
               outDev = m_zzParams.met_dev_M1;
               outDep = (int)m_zzParams.met_dep_M1;
              }
            else
               if(_Period < PERIOD_H1)
                 {
                  outDev = m_zzParams.met_dev_M15;
                  outDep = (int)m_zzParams.met_dep_M15;
                 }
               else
                  if(_Period < PERIOD_H4)
                    {
                     outDev = m_zzParams.met_dev_H1;
                     outDep = (int)m_zzParams.met_dep_H1;
                    }
                  else
                     if(_Period < PERIOD_D1)
                       {
                        outDev = m_zzParams.met_dev_H4;
                        outDep = (int)m_zzParams.met_dep_H4;
                       }
                     else
                       {
                        outDev = m_zzParams.met_dev_D1;
                        outDep = (int)m_zzParams.met_dep_D1;
                       }
            break;
        }
     }
   else
      if(asset == ASSET_TYPE_CRYPTO)
        {
         outLookback = m_zzParams.cry_maxLookback;
         switch(_Period)
           {
            case PERIOD_D1:
               outDev = m_zzParams.cry_dev_D1;
               outDep = (int)m_zzParams.cry_dep_D1;
               break;
            case PERIOD_H4:
               outDev = m_zzParams.cry_dev_H4;
               outDep = (int)m_zzParams.cry_dep_H4;
               break;
            case PERIOD_H1:
               outDev = m_zzParams.cry_dev_H1;
               outDep = (int)m_zzParams.cry_dep_H1;
               break;
            case PERIOD_M15:
               outDev = m_zzParams.cry_dev_M15;
               outDep = (int)m_zzParams.cry_dep_M15;
               break;
            case PERIOD_M1:
               outDev = m_zzParams.cry_dev_M1;
               outDep = (int)m_zzParams.cry_dep_M1;
               break;
            default:
               if(_Period < PERIOD_M15)
                 {
                  outDev = m_zzParams.cry_dev_M1;
                  outDep = (int)m_zzParams.cry_dep_M1;
                 }
               else
                  if(_Period < PERIOD_H1)
                    {
                     outDev = m_zzParams.cry_dev_M15;
                     outDep = (int)m_zzParams.cry_dep_M15;
                    }
                  else
                     if(_Period < PERIOD_H4)
                       {
                        outDev = m_zzParams.cry_dev_H1;
                        outDep = (int)m_zzParams.cry_dep_H1;
                       }
                     else
                        if(_Period < PERIOD_D1)
                          {
                           outDev = m_zzParams.cry_dev_H4;
                           outDep = (int)m_zzParams.cry_dep_H4;
                          }
                        else
                          {
                           outDev = m_zzParams.cry_dev_D1;
                           outDep = (int)m_zzParams.cry_dep_D1;
                          }
               break;
           }
        }
      else
        {
         outLookback = m_zzParams.fx_maxLookback;
         switch(_Period)
           {
            case PERIOD_D1:
               outDev = m_zzParams.fx_dev_D1;
               outDep = (int)m_zzParams.fx_dep_D1;
               break;
            case PERIOD_H4:
               outDev = m_zzParams.fx_dev_H4;
               outDep = (int)m_zzParams.fx_dep_H4;
               break;
            case PERIOD_H1:
               outDev = m_zzParams.fx_dev_H1;
               outDep = (int)m_zzParams.fx_dep_H1;
               break;
            case PERIOD_M15:
               outDev = m_zzParams.fx_dev_M15;
               outDep = (int)m_zzParams.fx_dep_M15;
               break;
            case PERIOD_M1:
               outDev = m_zzParams.fx_dev_M1;
               outDep = (int)m_zzParams.fx_dep_M1;
               break;
            default:
               if(_Period < PERIOD_M15)
                 {
                  outDev = m_zzParams.fx_dev_M1;
                  outDep = (int)m_zzParams.fx_dep_M1;
                 }
               else
                  if(_Period < PERIOD_H1)
                    {
                     outDev = m_zzParams.fx_dev_M15;
                     outDep = (int)m_zzParams.fx_dep_M15;
                    }
                  else
                     if(_Period < PERIOD_H4)
                       {
                        outDev = m_zzParams.fx_dev_H1;
                        outDep = (int)m_zzParams.fx_dep_H1;
                       }
                     else
                        if(_Period < PERIOD_D1)
                          {
                           outDev = m_zzParams.fx_dev_H4;
                           outDep = (int)m_zzParams.fx_dep_H4;
                          }
                        else
                          {
                           outDev = m_zzParams.fx_dev_D1;
                           outDep = (int)m_zzParams.fx_dep_D1;
                          }
               break;
           }
        }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Guardrails\Guardrails_Core_OLD.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_OLD.mqh
