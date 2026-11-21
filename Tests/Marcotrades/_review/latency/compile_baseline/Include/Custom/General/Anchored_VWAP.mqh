//+------------------------------------------------------------------+
//|                                                Anchored_VWAP.mqh |
//|                                  Exact TradingView Replica       |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""

//--- Enums matching TradingView
enum ENUM_BANDS_MODE
  {
   BANDS_STDDEV=0,  // Standard Deviation
   BANDS_PERCENT=1  // Percentage
  };

enum ENUM_VOL_TYPE
  {
   VOL_TICK, // Tick Volume (Standard for Forex)
   VOL_REAL  // Real Volume (Standard for Stocks/Crypto)
  };

//+------------------------------------------------------------------+
//| Class CAnchoredVWAP                                              |
//+------------------------------------------------------------------+
class CAnchoredVWAP
  {
private:
   string               m_dot_name;
   string               m_vline_name;
   string               m_hline_name;

   ENUM_BANDS_MODE      m_bands_mode;
   ENUM_APPLIED_PRICE   m_price_type;
   ENUM_VOL_TYPE        m_vol_type;

   bool                 m_show_b1, m_show_b2, m_show_b3;
   double               m_mult1, m_mult2, m_mult3;

   datetime             m_last_anchor_time;
   datetime             m_last_interaction_time;
   bool                 m_is_active;

   double               GetPrice(const double &open[], const double &high[], const double &low[], const double &close[], int i);
   void                 CheckAndCreateAnchorObjects(string sym, ENUM_TIMEFRAMES tf, double current_price);

public:
                     CAnchoredVWAP();
                    ~CAnchoredVWAP();

   void                 Init(string dot_name, ENUM_BANDS_MODE mode, ENUM_APPLIED_PRICE price_type, ENUM_VOL_TYPE vol_type,
                             bool sb1, double m1, bool sb2, double m2, bool sb3, double m3);
   void                 Deinit();

   void                 OnTimer();
   void                 OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

   int                  Calculate(const int rates_total, const int prev_calculated, const datetime &time[],
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  const long &tick_volume[], const long &volume[],
                                  double &VWAP[], double &Up1[], double &Dn1[], double &Up2[], double &Dn2[], double &Up3[], double &Dn3[],
                                  double &CumVol[], double &CumPV[], double &CumP2V[],
                                  string sym, ENUM_TIMEFRAMES tf);
  };

//+------------------------------------------------------------------+
CAnchoredVWAP::CAnchoredVWAP()
  {
   m_last_anchor_time      = 0;
   m_last_interaction_time = TimeLocal();
   m_is_active             = true;
  }
CAnchoredVWAP::~CAnchoredVWAP() {}

//+------------------------------------------------------------------+
void CAnchoredVWAP::Init(string dot_name, ENUM_BANDS_MODE mode, ENUM_APPLIED_PRICE price_type, ENUM_VOL_TYPE vol_type,
                         bool sb1, double m1, bool sb2, double m2, bool sb3, double m3)
  {
   m_dot_name   = dot_name;
   m_vline_name = dot_name + "_VLine";
   m_hline_name = dot_name + "_HLine";

   m_bands_mode = mode;
   m_price_type = price_type;
   m_vol_type   = vol_type;

   m_show_b1 = sb1;
   m_mult1 = m1;
   m_show_b2 = sb2;
   m_mult2 = m2;
   m_show_b3 = sb3;
   m_mult3 = m3;
  }

//+------------------------------------------------------------------+
//| Cleanup objects when indicator is removed                        |
//+------------------------------------------------------------------+
void CAnchoredVWAP::Deinit()
  {
   ObjectDelete(0, m_dot_name);
   ObjectDelete(0, m_vline_name);
   ObjectDelete(0, m_hline_name);
  }

//+------------------------------------------------------------------+
//| Timer: Handles the 10-second Dot Shrink effect                   |
//+------------------------------------------------------------------+
void CAnchoredVWAP::OnTimer()
  {
   if(ObjectFind(0, m_dot_name) >= 0)
     {
      bool is_selected = (bool)ObjectGetInteger(0, m_dot_name, OBJPROP_SELECTED);
      if(is_selected)
         m_last_interaction_time = TimeLocal(); // Keep active while selected

      if(TimeLocal() - m_last_interaction_time > 10)
        {
         if(m_is_active)
           {
            ObjectSetInteger(0, m_dot_name, OBJPROP_WIDTH, 2); // Shrink dot
            m_is_active = false;
            ChartRedraw(0);
           }
        }
      else
        {
         if(!m_is_active)
           {
            ObjectSetInteger(0, m_dot_name, OBJPROP_WIDTH, 5); // Enlarge dot
            m_is_active = true;
            ChartRedraw(0);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Chart Event: Tracks Dragging and Axis Coordinates                |
//+------------------------------------------------------------------+
void CAnchoredVWAP::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
// Extend timeout if user interacts with dot directly
   if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CLICK) && sparam == m_dot_name)
     {
      m_last_interaction_time = TimeLocal();
     }

// Track dragging in real-time to project coordinates to the axes
   if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CLICK)
     {
      if(ObjectFind(0, m_dot_name) >= 0)
        {
         bool is_selected = (bool)ObjectGetInteger(0, m_dot_name, OBJPROP_SELECTED);

         if(is_selected)
           {
            // Sync hidden lines to dot position to force axis highlighting
            datetime t = (datetime)ObjectGetInteger(0, m_dot_name, OBJPROP_TIME, 0);
            double   p = ObjectGetDouble(0, m_dot_name, OBJPROP_PRICE, 0);

            datetime old_t = (datetime)ObjectGetInteger(0, m_vline_name, OBJPROP_TIME, 0);
            double   old_p = ObjectGetDouble(0, m_hline_name, OBJPROP_PRICE, 0);
            color    old_c = (color)ObjectGetInteger(0, m_vline_name, OBJPROP_COLOR);

            bool changed = false;
            if(t != old_t)
              {
               ObjectSetInteger(0, m_vline_name, OBJPROP_TIME, 0, t);
               changed = true;
              }
            if(p != old_p)
              {
               ObjectSetDouble(0, m_hline_name, OBJPROP_PRICE, 0, p);
               changed = true;
              }
            if(old_c == clrNONE)
              {
               ObjectSetInteger(0, m_vline_name, OBJPROP_COLOR, clrDarkTurquoise);
               ObjectSetInteger(0, m_hline_name, OBJPROP_COLOR, clrDarkTurquoise);
               changed = true;
              }

            if(changed)
               ChartRedraw(0);
           }
         else
           {
            // Hide crosshairs immediately when dot is deselected
            color old_c = (color)ObjectGetInteger(0, m_vline_name, OBJPROP_COLOR);
            if(old_c != clrNONE)
              {
               ObjectSetInteger(0, m_vline_name, OBJPROP_COLOR, clrNONE);
               ObjectSetInteger(0, m_hline_name, OBJPROP_COLOR, clrNONE);
               ChartRedraw(0);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
void CAnchoredVWAP::CheckAndCreateAnchorObjects(string sym, ENUM_TIMEFRAMES tf, double current_price)
  {
   datetime spawn_time = iTime(sym, tf, 0);

// 1. The Draggable Dot
   if(ObjectFind(0, m_dot_name) < 0)
     {
      ObjectCreate(0, m_dot_name, OBJ_ARROW, 0, spawn_time, current_price);
      ObjectSetInteger(0, m_dot_name, OBJPROP_ARROWCODE, 159); // Solid Dot
      ObjectSetInteger(0, m_dot_name, OBJPROP_COLOR, clrDarkTurquoise);
      ObjectSetInteger(0, m_dot_name, OBJPROP_WIDTH, 5);
      ObjectSetInteger(0, m_dot_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, m_dot_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, m_dot_name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, m_dot_name, OBJPROP_SELECTED, true);
      ObjectSetString(0, m_dot_name, OBJPROP_TOOLTIP, "Drag me to anchor the VWAP!");
      m_last_interaction_time = TimeLocal();
     }

// 2. The Time Coordinate Line (V-Line for Bottom Scale Highlight)
   if(ObjectFind(0, m_vline_name) < 0)
     {
      ObjectCreate(0, m_vline_name, OBJ_VLINE, 0, spawn_time, 0);
      ObjectSetInteger(0, m_vline_name, OBJPROP_COLOR, clrNONE); // Hidden initially
      ObjectSetInteger(0, m_vline_name, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, m_vline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_vline_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_vline_name, OBJPROP_BACK, false); // Foreground guarantees axis labels are visible!
      ObjectSetInteger(0, m_vline_name, OBJPROP_HIDDEN, true); // Keep out of object list
      ObjectSetString(0, m_vline_name, OBJPROP_TOOLTIP, "\n");
     }

// 3. The Price Coordinate Line (H-Line for Right Scale Highlight)
   if(ObjectFind(0, m_hline_name) < 0)
     {
      ObjectCreate(0, m_hline_name, OBJ_HLINE, 0, 0, current_price);
      ObjectSetInteger(0, m_hline_name, OBJPROP_COLOR, clrNONE); // Hidden initially
      ObjectSetInteger(0, m_hline_name, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, m_hline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_hline_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_hline_name, OBJPROP_BACK, false); // Foreground guarantees axis labels are visible!
      ObjectSetInteger(0, m_hline_name, OBJPROP_HIDDEN, true); // Keep out of object list
      ObjectSetString(0, m_hline_name, OBJPROP_TOOLTIP, "\n");
     }
  }

//+------------------------------------------------------------------+
double CAnchoredVWAP::GetPrice(const double &open[], const double &high[], const double &low[], const double &close[], int i)
  {
   switch(m_price_type)
     {
      case PRICE_CLOSE:
         return close[i];
      case PRICE_OPEN:
         return open[i];
      case PRICE_HIGH:
         return high[i];
      case PRICE_LOW:
         return low[i];
      case PRICE_MEDIAN:
         return (high[i] + low[i]) / 2.0;
      case PRICE_TYPICAL:
         return (high[i] + low[i] + close[i]) / 3.0; // TV Default
      case PRICE_WEIGHTED:
         return (high[i] + low[i] + close[i] * 2.0) / 4.0;
     }
   return close[i];
  }

//+------------------------------------------------------------------+
int CAnchoredVWAP::Calculate(const int rates_total, const int prev_calculated, const datetime &time[],
                             const double &open[], const double &high[], const double &low[], const double &close[],
                             const long &tick_volume[], const long &volume[],
                             double &VWAP[], double &Up1[], double &Dn1[], double &Up2[], double &Dn2[], double &Up3[], double &Dn3[],
                             double &CumVol[], double &CumPV[], double &CumP2V[],
                             string sym, ENUM_TIMEFRAMES tf)
  {
   CheckAndCreateAnchorObjects(sym, tf, close[rates_total-1]);

   datetime current_anchor = (datetime)ObjectGetInteger(0, m_dot_name, OBJPROP_TIME);
   bool anchor_moved = false;

   if(current_anchor != m_last_anchor_time)
     {
      anchor_moved = true;
      m_last_anchor_time = current_anchor;
     }

   int start = 0;

   if(prev_calculated == 0 || anchor_moved)
     {
      start = 0;
      ArrayInitialize(VWAP, EMPTY_VALUE);
      ArrayInitialize(Up1, EMPTY_VALUE);
      ArrayInitialize(Dn1, EMPTY_VALUE);
      ArrayInitialize(Up2, EMPTY_VALUE);
      ArrayInitialize(Dn2, EMPTY_VALUE);
      ArrayInitialize(Up3, EMPTY_VALUE);
      ArrayInitialize(Dn3, EMPTY_VALUE);

      ArrayInitialize(CumVol, 0.0);
      ArrayInitialize(CumPV, 0.0);
      ArrayInitialize(CumP2V, 0.0);
     }
   else
     {
      start = prev_calculated - 1;
     }

   for(int i = start; i < rates_total; i++)
     {
      if(time[i] < current_anchor)
        {
         VWAP[i] = EMPTY_VALUE;
         Up1[i] = EMPTY_VALUE;
         Dn1[i] = EMPTY_VALUE;
         Up2[i] = EMPTY_VALUE;
         Dn2[i] = EMPTY_VALUE;
         Up3[i] = EMPTY_VALUE;
         Dn3[i] = EMPTY_VALUE;
         CumVol[i] = 0.0;
         CumPV[i] = 0.0;
         CumP2V[i] = 0.0;
         continue;
        }

      double price = GetPrice(open, high, low, close, i);
      double vol   = (m_vol_type == VOL_TICK) ? (double)tick_volume[i] : (double)volume[i];
      if(vol == 0)
         vol = 1.0;

      double prev_cum_vol = (i > 0 && time[i-1] >= current_anchor) ? CumVol[i-1] : 0.0;
      double prev_cum_pv  = (i > 0 && time[i-1] >= current_anchor) ? CumPV[i-1]  : 0.0;
      double prev_cum_p2v = (i > 0 && time[i-1] >= current_anchor) ? CumP2V[i-1] : 0.0;

      CumVol[i] = prev_cum_vol + vol;
      CumPV[i]  = prev_cum_pv + (price * vol);
      CumP2V[i] = prev_cum_p2v + (price * price * vol);

      if(CumVol[i] > 0)
        {
         VWAP[i] = CumPV[i] / CumVol[i];
         double offset = 0.0;
         double variance = (CumP2V[i] / CumVol[i]) - (VWAP[i] * VWAP[i]);
         if(variance < 0)
            variance = 0.0;
         double std_dev = MathSqrt(variance);

         // Band 1
         if(m_show_b1)
           {
            offset = (m_bands_mode == BANDS_STDDEV) ? (m_mult1 * std_dev) : (VWAP[i] * m_mult1 / 100.0);
            Up1[i] = VWAP[i] + offset;
            Dn1[i] = VWAP[i] - offset;
           }
         else
           {
            Up1[i] = EMPTY_VALUE;
            Dn1[i] = EMPTY_VALUE;
           }

         // Band 2
         if(m_show_b2)
           {
            offset = (m_bands_mode == BANDS_STDDEV) ? (m_mult2 * std_dev) : (VWAP[i] * m_mult2 / 100.0);
            Up2[i] = VWAP[i] + offset;
            Dn2[i] = VWAP[i] - offset;
           }
         else
           {
            Up2[i] = EMPTY_VALUE;
            Dn2[i] = EMPTY_VALUE;
           }

         // Band 3
         if(m_show_b3)
           {
            offset = (m_bands_mode == BANDS_STDDEV) ? (m_mult3 * std_dev) : (VWAP[i] * m_mult3 / 100.0);
            Up3[i] = VWAP[i] + offset;
            Dn3[i] = VWAP[i] - offset;
           }
         else
           {
            Up3[i] = EMPTY_VALUE;
            Dn3[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\Anchored_VWAP.mqh

// END FILE: Include\Custom\General\Anchored_VWAP.mqh
