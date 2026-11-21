//+------------------------------------------------------------------+
//|              Include\Guardrails\Guardrails_Core.mqh              |
//|             Role: Declares the CGuardrailsCore engine and        |
//|             includes its modular implementations.                |
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
   ZONE_SELECT_NEAREST_ALL,      // Nearest Active Zone (Any SMC Type)
   ZONE_SELECT_LIQUIDITY_BLOCKS, // Liquidity Blocks (LBs) Only
   ZONE_SELECT_INDUCEMENTS,      // Inducements Only
   ZONE_SELECT_SWING_POIS,       // Swing POIs Only
   ZONE_SELECT_ORDER_BLOCKS,     // Order Blocks Only
   ZONE_SELECT_DEMAND_SUPPLY,    // Demand / Supply Only
   ZONE_SELECT_BREAKER_BLOCKS,   // Breaker Blocks Only
   ZONE_SELECT_FLIP_ZONES        // Flip Zones Only   
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

// Core implementation modules
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core_Init.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core_SMC.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core_Risk.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core_Execution.mqh"
#include "C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Tests\Marcotrades\_review\latency\compile_baseline\Include\Custom\Guardrails\Guardrails_Core_Management.mqh"
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Guardrails\Guardrails_Core.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core.mqh
