//+------------------------------------------------------------------+
//|           Include\Guardrails\Guardrails_Core_Init.mqh            |
//|             Role: Implements core construction, initialization,  |
//|             and deterministic resource cleanup.                  |
//+------------------------------------------------------------------+
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

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Init.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_Init.mqh
