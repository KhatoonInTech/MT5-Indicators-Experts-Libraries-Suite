//+------------------------------------------------------------------+
//|                                     Include\Custom\ZigZag\liquidity.mqh |
//|                             Dynamic Projection Liquidity Engine  |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.00"

#ifndef LIQUIDITY_MQH
#define LIQUIDITY_MQH

#include <Custom\ZigZag\ZigZag.mqh>
#include <Custom\General\mql_plotting.mqh>
#include <Arrays\ArrayObj.mqh>

// =============================================================================
// LIQUIDITY LEVEL CLASS FOR ACTIVE TRACKING
// =============================================================================
class CLiquidityLevel : public CObject
  {
public:
   string            id;
   int               st_x;
   double            st_y;
   int               cur_x;
   double            cur_y;
   bool              isHighSide;
   int               category;
   double            slope;
   string            typeText;
   color             lineCol;
   color             dotCol;
   bool              isSwept;
   int               sweep_x;
   datetime          startTime;
   datetime          curTime;
   datetime          sweepTime;

                     CLiquidityLevel()
     {
      id = "";
      st_x = 0;
      st_y = 0.0;
      cur_x = 0;
      cur_y = 0.0;
      isHighSide = false;
      category = 0;
      slope = 0.0;
      typeText = "";
      lineCol = clrNONE;
      dotCol = clrNONE;
      isSwept = false;
      sweep_x = 0;
      startTime = 0;
      curTime = 0;
      sweepTime = 0;
     }
  };

// =============================================================================
// CENTRALIZED LIQUIDITY DETECTION CLASS
// =============================================================================
class CLiquidityLogic
  {
private:
   double            m_threshold;
   double            m_slope_tol;
   color             m_bslColor;
   color             m_sslColor;

   int               last_processed_ph_index;
   int               last_processed_pl_index;

   int               lph_x;
   double            lph_y;
   int               pph_x;
   double            pph_y;

   int               lpl_x;
   double            lpl_y;
   int               ppl_x;
   double            ppl_y;

   long              m_id_counter;

public:
   CArrayObj         active_levels;

                     CLiquidityLogic()
     {
      m_threshold = 0.0005;
      m_slope_tol = 0.1;
      m_bslColor  = clrRed;
      m_sslColor  = clrBlue;

      ResetState();
     }

                    ~CLiquidityLogic()
     {
      Cleanup();
     }

   void              ResetState()
     {
      last_processed_ph_index = -1;
      last_processed_pl_index = -1;

      lph_x = 0;
      lph_y = 0.0;
      pph_x = 0;
      pph_y = 0.0;
      lpl_x = 0;
      lpl_y = 0.0;
      ppl_x = 0;
      ppl_y = 0.0;

      m_id_counter = 0;
      active_levels.Clear();
     }

   void              Init(double threshold, double slope_tol, color bslColor, color sslColor)
     {
      m_threshold = threshold;
      m_slope_tol = slope_tol;
      m_bslColor  = bslColor;
      m_sslColor  = sslColor;
     }

   void              Cleanup()
     {
      active_levels.Clear();
      ObjectsDeleteAll(0, "Liq_");
     }

   void              CreateLiquidityLevel(int cur_x, double cur_y, int st_x, double st_y, bool isHighSide, int cat,
                                          const datetime &time[], const double &high[], const double &low[], int current_i)
     {
      m_id_counter++;
      string id_str = IntegerToString(m_id_counter) + "_" + IntegerToString(cur_x);

      CLiquidityLevel* lvl = new CLiquidityLevel();
      lvl.id = id_str;
      lvl.st_x = st_x;
      lvl.st_y = st_y;
      lvl.cur_x = cur_x;
      lvl.cur_y = cur_y;
      lvl.isHighSide = isHighSide;
      lvl.category = cat;
      lvl.isSwept = false;
      lvl.startTime = time[st_x];
      lvl.curTime = time[cur_x];

      if(isHighSide)
        {
         lvl.typeText = (cat == 2) ? "TL-BSL" : (cat == 1 ? "EQH-BSL" : "BSL");
         lvl.lineCol = m_bslColor;
         lvl.dotCol = m_bslColor;
        }
      else
        {
         lvl.typeText = (cat == 2) ? "TL-SSL" : (cat == 1 ? "EQL-SSL" : "SSL");
         lvl.lineCol = m_sslColor;
         lvl.dotCol = m_sslColor;
        }

      // Calculate Slope
      lvl.slope = 0.0;
      if(cat == 2 && cur_x != st_x)
        {
         lvl.slope = (cur_y - st_y) / (double)(cur_x - st_x);
        }

      // Check Backcheck Sweeps
      bool already_swept = false;
      int sweep_x = cur_x;

      if(cur_x < current_i)
        {
         for(int b = cur_x + 1; b <= current_i; b++)
           {
            double price_at_b = cur_y + lvl.slope * (b - cur_x);
            if(isHighSide)
              {
               if(high[b] >= price_at_b)
                 {
                  already_swept = true;
                  sweep_x = b;
                  break;
                 }
              }
            else
              {
               if(low[b] <= price_at_b)
                 {
                  already_swept = true;
                  sweep_x = b;
                  break;
                 }
              }
           }
        }

      int end_x = already_swept ? sweep_x : current_i;
      double end_y = cur_y + lvl.slope * (end_x - cur_x);

      // --- Draw Base Line ---
      string line_id = "Liq_Line_" + id_str;
      int style = (cat > 0) ? STYLE_SOLID : STYLE_DASH;
      Plotter::DrawLine(line_id, lvl.startTime, lvl.st_y, lvl.curTime, lvl.cur_y, lvl.lineCol, style, 1, false);

      // --- Draw Label ---
      string lbl_id = "Liq_Lbl_" + id_str;
      ENUM_ANCHOR_POINT anchor = isHighSide ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER;
      Plotter::DrawLabel(lbl_id, lvl.curTime, lvl.cur_y, lvl.typeText, lvl.lineCol, anchor, 8);

      // --- Draw Dotted Projection Line (cat == 2 only) ---
      if(cat == 2)
        {
         string proj_id = "Liq_Proj_" + id_str;
         Plotter::DrawLine(proj_id, lvl.curTime, lvl.cur_y, time[end_x], end_y, lvl.dotCol, STYLE_DOT, 1, false);
        }

      if(!already_swept)
        {
         active_levels.Add(lvl);
        }
      else
        {
         delete lvl;
        }
     }

   void              UpdateActiveLevels(int current_i, const datetime &time[], const double &high[], const double &low[], const double &close[])
     {
      for(int i = active_levels.Total() - 1; i >= 0; i--)
        {
         CLiquidityLevel* lvl = (CLiquidityLevel*)active_levels.At(i);
         if(lvl == NULL)
            continue;

         int end_x = current_i;
         double end_y = lvl.cur_y + lvl.slope * (end_x - lvl.cur_x);

         // Update projection dotted line on chart
         if(lvl.category == 2)
           {
            string proj_id = "Liq_Proj_" + lvl.id;
            Plotter::DrawLine(proj_id, lvl.curTime, lvl.cur_y, time[end_x], end_y, lvl.dotCol, STYLE_DOT, 1, false);
           }

         // Check for sweep on this bar
         bool swept = false;
         if(lvl.isHighSide)
           {
            swept = (high[current_i] >= end_y);
           }
         else
           {
            swept = (low[current_i] <= end_y);
           }

         if(swept)
           {
            lvl.isSwept = true;
            lvl.sweep_x = current_i;
            lvl.sweepTime = time[current_i];

            // Lock the dotted line exactly to the sweep bar
            if(lvl.category == 2)
              {
               string proj_id = "Liq_Proj_" + lvl.id;
               Plotter::DrawLine(proj_id, lvl.curTime, lvl.cur_y, time[current_i], end_y, lvl.dotCol, STYLE_DOT, 1, false);
              }

            active_levels.Delete(i);
           }
        }
     }

   void              DetectLiquidity(int current_i, const datetime &time[], const double &high[], const double &low[], ZigZag* zigZag)
     {
      int pn = zigZag.pivots.Total();
      if(current_i > 100 && pn > 1)
        {
         int start_p = MathMax(0, pn - 5);
         int end_p = MathMax(0, pn - 2);

         for(int p_i = start_p; p_i <= end_p; p_i++)
           {
            Pivot* p = (Pivot*)zigZag.pivots.At(p_i);
            if(p == NULL || (zigZag.projection != NULL && p == zigZag.projection))
               continue;

            int p_idx = p.end.index;
            double p_prc = p.end.price;
            bool p_isHigh = p.isHigh;

            if(p_isHigh)
              {
               if(p_idx > last_processed_ph_index)
                 {
                  last_processed_ph_index = p_idx;

                  int cur_x = p_idx;
                  double ph = p_prc;
                  int cat = 0;
                  int st_x = cur_x;
                  double st_y = ph;

                  // EQUAL HIGH LIQUIDITY (EQH-BSL)
                  if(lph_x > 0 && MathAbs(ph - lph_y) <= (ph * m_threshold))
                    {
                     cat = 1;
                     st_x = lph_x;
                    }
                  // TRENDLINE HIGH LIQUIDITY (TL-BSL)
                  else
                     if(pph_x > 0 && lph_x > pph_x)
                       {
                        double expected_y = lph_y + ((lph_y - pph_y) / (double)(lph_x - pph_x)) * (cur_x - lph_x);
                        if((ph < lph_y) && MathAbs(ph - expected_y) <= (ph * (m_slope_tol / 100.0)))
                          {
                           cat = 2;
                           st_x = pph_x;
                           st_y = pph_y;
                          }
                       }

                  pph_x = lph_x;
                  pph_y = lph_y;
                  lph_x = cur_x;
                  lph_y = ph;

                  CreateLiquidityLevel(cur_x, ph, st_x, st_y, true, cat, time, high, low, current_i);
                 }
              }
            else
              {
               if(p_idx > last_processed_pl_index)
                 {
                  last_processed_pl_index = p_idx;

                  int cur_x = p_idx;
                  double pl = p_prc;
                  int cat = 0;
                  int st_x = cur_x;
                  double st_y = pl;

                  // EQUAL LOW LIQUIDITY (EQL-SSL)
                  if(lpl_x > 0 && MathAbs(pl - lpl_y) <= (pl * m_threshold))
                    {
                     cat = 1;
                     st_x = lpl_x;
                    }
                  // TRENDLINE LOW LIQUIDITY (TL-SSL)
                  else
                     if(ppl_x > 0 && lpl_x > ppl_x)
                       {
                        double expected_y = lpl_y + ((lpl_y - ppl_y) / (double)(lpl_x - ppl_x)) * (cur_x - lpl_x);
                        if((pl > lpl_y) && MathAbs(pl - expected_y) <= (pl * (m_slope_tol / 100.0)))
                          {
                           cat = 2;
                           st_x = ppl_x;
                           st_y = ppl_y;
                          }
                       }

                  ppl_x = lpl_x;
                  ppl_y = lpl_y;
                  lpl_x = cur_x;
                  lpl_y = pl;

                  CreateLiquidityLevel(cur_x, pl, st_x, st_y, false, cat, time, high, low, current_i);
                 }
              }
           }
        }
     }
  };

#endif
//+------------------------------------------------------------------+

// END FILE: Include\Custom\ZigZag\liquidity.mqh

// END FILE: Include\Custom\ZigZag\liquidity.mqh
