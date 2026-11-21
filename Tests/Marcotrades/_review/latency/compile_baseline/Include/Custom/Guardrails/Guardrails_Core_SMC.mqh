//+------------------------------------------------------------------+
//|            Include\Guardrails\Guardrails_Core_SMC.mqh            |
//|             Role: Handles SMC zones, ZigZag synchronization,     |
//|             collision detection, and chart drawing.              |
//+------------------------------------------------------------------+
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

// END FILE: Include\Custom\Guardrails\Guardrails_Core_SMC.mqh

// END FILE: Include\Custom\Guardrails\Guardrails_Core_SMC.mqh
