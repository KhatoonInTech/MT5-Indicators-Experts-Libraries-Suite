//+------------------------------------------------------------------+
//|                         Include\ZigZag\Guardrails_Protection.mqh |
//|             Role: Top-Level Wrapper Engine for MT5 Events,       |
//|             Lifecycle Management, and Multi-Asset Dispatching    |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "46.00"
#property description "Guardrails Protection - Master Event Engine with State Reset"

#include <Custom\Guardrails\Guardrails_GUI.mqh>

//+------------------------------------------------------------------+
//| Master Protection Class                                          |
//+------------------------------------------------------------------+
class CGuardrailsProtection : public CGuardrailsGUI
  {
private:
   bool              m_autoSaveTemplate;

public:
                     CGuardrailsProtection();
   virtual          ~CGuardrailsProtection();

   int               OnInit(bool manageAll, bool autoSaveTpl,
                            bool blockShortsBull, bool blockLongsBear,
                            bool useDS, bool useOB, bool useFZ, bool useBB, bool useSP,
                            bool drawZZ, color zzLineColor, bool zzExtend, bool zzShowPrice, bool zzShowVol, bool zzShowChg, string zzPriceDiff,
                            bool drawMS, bool drawZones,
                            ulong magic, bool enforceMaxLot, double maxSpreadShare,
                            bool showHUD, bool showPanel, bool excludeSpread,
                            double maxRiskPct, bool emergencyCut,
                            bool autoBE, int beBuffer, bool waitCandleClose, double beSpreadMult,
                            bool enableProfitGuard, double tpActivationPct, double maxGivebackPct, double partialClosePct, bool advancedProfitSaving, bool autoTrade,
                            ENUM_ZONE_SELECTION zoneSource,
                            ENUM_ASSET_TYPE assetCat, SZigZagParams &zz);

   void              OnDeinit(const int reason);
   void              OnTick();
   void              OnTimer();
   void              OnTrade();
   void              OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   void              OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGuardrailsProtection::CGuardrailsProtection()
  {
   m_autoSaveTemplate = true;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGuardrailsProtection::~CGuardrailsProtection()
  {
  }

//+------------------------------------------------------------------+
//| Master Initialization (Exact 39 Parameters Synchronized)         |
//+------------------------------------------------------------------+
int CGuardrailsProtection::OnInit(bool manageAll, bool autoSaveTpl,
                                  bool blockShortsBull, bool blockLongsBear,
                                  bool useDS, bool useOB, bool useFZ, bool useBB, bool useSP,
                                  bool drawZZ, color zzLineColor, bool zzExtend, bool zzShowPrice, bool zzShowVol, bool zzShowChg, string zzPriceDiff,
                                  bool drawMS, bool drawZones,
                                  ulong magic, bool enforceMaxLot, double maxSpreadShare,
                                  bool showHUD, bool showPanel, bool excludeSpread,
                                  double maxRiskPct, bool emergencyCut,
                                  bool autoBE, int beBuffer, bool waitCandleClose, double beSpreadMult,
                                  bool enableProfitGuard, double tpActivationPct, double maxGivebackPct, double partialClosePct, bool advancedProfitSaving, bool autoTrade,
                                  ENUM_ZONE_SELECTION zoneSource,
                                  ENUM_ASSET_TYPE assetCat, SZigZagParams &zz)
  {
   m_manageAllSymbols         = manageAll;
   m_autoSaveTemplate         = autoSaveTpl;
   m_blockShortsInBullish     = blockShortsBull;
   m_blockLongsInBearish      = blockLongsBear;
   m_useDemandSupply          = useDS;
   m_useOrderBlocks           = useOB;
   m_useFlipZones             = useFZ;
   m_useBreakerBlocks         = useBB;
   m_useSwingPOIs             = useSP;

   m_drawZigZag               = drawZZ;
   m_zzLineColor              = zzLineColor;
   m_zzExtend                 = zzExtend;
   m_zzShowPrice              = zzShowPrice;
   m_zzShowVol                = zzShowVol;
   m_zzShowChg                = zzShowChg;
   m_zzPriceDiff              = zzPriceDiff;

   m_drawMarketStructure      = drawMS;
   m_drawZones                = drawZones;
   m_magicNumber              = magic;
   m_enforceMaxLot            = enforceMaxLot;
   m_maxSpreadShare           = maxSpreadShare;
   m_showHUD                  = showHUD;
   m_showOrderPanel           = showPanel;
   m_excludeSpread            = excludeSpread;
   m_maxRiskPercent           = maxRiskPct;
   m_emergencyCircuitBreaker  = emergencyCut;
   m_autoBreakeven            = autoBE;
   m_breakevenBuffer          = beBuffer;
   m_waitCandleCloseForBE     = waitCandleClose;
   m_beSpreadMultiplier       = beSpreadMult;

   m_enableProfitGuard        = enableProfitGuard;
   m_tpActivationPercent      = tpActivationPct;
   m_maxProfitGivebackPercent = maxGivebackPct;
   m_partialClosePercent      = partialClosePct;
   m_advancedProfitSaving     = advancedProfitSaving;
   m_autoTradeContinuation    = autoTrade;

   m_zoneRiskSource           = zoneSource;
   m_assetCategory            = assetCat;
   m_zzParams                 = zz;

// Forces clean re-initialization of engine state on F7 parameter edits
   m_smc_initialized          = false;
   m_last_smc_bar_time        = 0;
   m_chart_bars_loaded        = 0;
   m_last_dev                 = -1.0;
   m_last_dep                 = -1;

   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   EventSetTimer(1);

   if(m_showOrderPanel)
      RenderPanel();

// Recalculate & redraw immediately with new inputs
   UpdateSMCZones();

   if(m_autoSaveTemplate)
      ChartSaveTemplate(0, "default.tpl");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Master Deinitialization                                          |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnDeinit(const int reason)
  {
   EventKillTimer();
   DestroyPanel();
   DestroyModal();

// Clean up all indicator & chart objects
   ObjectsDeleteAll(0, "ZZ_Ln_");
   ObjectsDeleteAll(0, "ZZ_Lbl_");
   ObjectsDeleteAll(0, "ZZ_Proj_");
   ObjectsDeleteAll(0, "BOSCHoCH_");
   ObjectsDeleteAll(0, "SWING_");
   ObjectsDeleteAll(0, "SMC_");
   ObjectsDeleteAll(0, "RG_Violated_");

// Reset cached engine indicators
   m_smc_initialized   = false;
   m_last_smc_bar_time = 0;
   m_chart_bars_loaded = 0;
   m_last_dev          = -1.0;
   m_last_dep          = -1;
  }

//+------------------------------------------------------------------+
//| Master OnTick                                                    |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTick()
  {
   RunMasterShield();
   UpdatePanelHUD();
  }

//+------------------------------------------------------------------+
//| Master OnTimer                                                   |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTimer()
  {
   RunMasterShield();
   UpdatePanelHUD();
  }

//+------------------------------------------------------------------+
//| Master OnTrade                                                   |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTrade()
  {
   RunMasterShield();
   UpdatePanelHUD();
  }

//+------------------------------------------------------------------+
//| Master OnTradeTransaction                                        |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   UpdatePanelHUD();
  }

//+------------------------------------------------------------------+
//| Master OnChartEvent                                              |
//+------------------------------------------------------------------+
void CGuardrailsProtection::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   ProcessChartEvents(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\Guardrails\Guardrails_Protection.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Protection.mqh
