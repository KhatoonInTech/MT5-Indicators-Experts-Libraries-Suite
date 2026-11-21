//+------------------------------------------------------------------+
//|                       Include/Custom/General/mq5_dashboard.mqh   |
//|                       SMC Trading Dashboard API Client           |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.11"

// =========================================================================
// SAFE STANDALONE CLEAN SYMBOL PREPROCESSOR GUARD
// =========================================================================
#ifndef CLEAN_SYMBOL_FN
#define CLEAN_SYMBOL_FN
string CleanSymbol(string sym)
  {
   int len = StringLen(sym);
   if(len > 1 && StringSubstr(sym, len - 1, 1) == "m")
     {
      return StringSubstr(sym, 0, len - 1);
     }
   return sym;
  }
#endif

// =========================================================================
// API CONFIGURATION
// =========================================================================
#define DASHBOARD_BASE_URL "https://mq5-dashboard.vercel.app/api"
#define DASHBOARD_API_KEY  "aye$h@-m012-01777721"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDashboardAPI
  {
private:
   static string     CleanType(string label)
     {
      string upper = label;
      StringToUpper(upper);
      if(StringFind(upper, "ORDER-BLOCK") >= 0 || StringFind(upper, "OB") >= 0)
         return "ORDER-BLOCK";
      if(StringFind(upper, "POI") >= 0)
         return "POI";
      if(StringFind(upper, "BREAKER") >= 0)
         return "BREAKER";
      if(StringFind(upper, "FLIP") >= 0)
         return "FLIP";
      if(StringFind(upper, "ZONE") >= 0 || StringFind(upper, "DEMAND") >= 0 || StringFind(upper, "SUPPLY") >= 0)
         return "ZONE";
      return "MSS";
     }

   static string     EscapeJSON(string text)
     {
      string res = text;
      StringReplace(res, "\\", "\\\\");
      StringReplace(res, "\"", "\\\"");
      StringReplace(res, "\n", "\\n");
      StringReplace(res, "\r", "\\r");
      StringReplace(res, "\t", "\\t");
      return res;
     }

public:
   // --- Utility to get ISO-8601 formatting for Supabase mapping ---
   static string     GetISODatetime()
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d.000Z", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
     }

   // --- 1. Synchronize individual Trading Alerts (POST /alerts) ---
   static void       SendAlert(string symbol, ENUM_TIMEFRAMES tf, string direction, string rawType, double entryPrice, double sl, double tp, int quality, string recommendation, string reasoning)
     {
      if(DASHBOARD_BASE_URL == "" || StringFind(DASHBOARD_BASE_URL, "http") < 0)
         return;

      string tfStr = StringSubstr(EnumToString(tf), 7);
      string cleanType = CleanType(rawType);
      string cleanSym = CleanSymbol(symbol);

      string json = "{";
      json += "\"symbol\":\"" + cleanSym + "\",";
      json += "\"timeframe\":\"" + tfStr + "\",";
      json += "\"type\":\"" + cleanType + "\",";
      json += "\"direction\":\"" + direction + "\",";
      json += "\"entryPrice\":" + DoubleToString(entryPrice, 5) + ",";
      json += "\"slPrice\":" + DoubleToString(sl, 5) + ",";
      json += "\"tpPrice\":" + DoubleToString(tp, 5) + ",";
      json += "\"setupQuality\":" + IntegerToString(quality) + ",";
      json += "\"recommendation\":\"" + EscapeJSON(recommendation) + "\",";
      json += "\"reasoning\":\"" + EscapeJSON(reasoning) + "\"";
      json += "}";

      char data[], result[];
      string result_headers;
      string headers = "Content-Type: application/json\r\n";
      headers += "X-SMC-Key: " + DASHBOARD_API_KEY + "\r\n";

      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      int res = WebRequest("POST", DASHBOARD_BASE_URL + "/alerts", headers, 10000, data, result, result_headers);
      if(res >= 200 && res <= 299)
         Print("+++ 🌐 Dashboard Alert Synced: ", cleanSym, " ", direction, " ", cleanType);
      else
         Print("--- ❌ Dashboard Alert Sync Failed: HTTP ", res, " | ", CharArrayToString(result));
     }

   // --- 2. Synchronize Daily CSV Reports (POST /webhook/report) ---
   static void       SendReport(string fileName, string csvData)
     {
      if(DASHBOARD_BASE_URL == "" || StringFind(DASHBOARD_BASE_URL, "http") < 0)
         return;

      string cleaned_filename = fileName;
      StringReplace(cleaned_filename, "m_alert", "_alert");
      StringReplace(cleaned_filename, "m_mitigation", "_mitigation");
      StringReplace(cleaned_filename, "m_touch", "_touch");

      string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
      headers += "accept: application/json\r\n";
      headers += "X-SMC-Key: " + DASHBOARD_API_KEY + "\r\n";

      string body = "--" + boundary + "\r\n";
      body += "Content-Disposition: form-data; name=\"file\"; filename=\"" + cleaned_filename + "\"\r\n";
      body += "Content-Type: text/csv\r\n\r\n";
      body += csvData;

      if(StringSubstr(body, StringLen(body)-2) != "\r\n")
         body += "\r\n";

      body += "--" + boundary + "--\r\n";

      char data[], result[];
      string result_headers;

      StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      int res = WebRequest("POST", DASHBOARD_BASE_URL + "/webhook/report", headers, 15000, data, result, result_headers);
      if(res == 200)
         Print("+++ 🌐 Dashboard Report CSV Synced successfully: ", cleaned_filename);
      else
         Print("--- ❌ Dashboard Report Sync Failed: HTTP ", res, " | ", CharArrayToString(result));
     }

   // --- 3. Synchronize Swing POI Proximity Alerts as a CSV Batch (POST /webhook/swing-poi) ---
   static void       SendSwingPOIBatch(string fileName, string csvData)
     {
      if(DASHBOARD_BASE_URL == "" || StringFind(DASHBOARD_BASE_URL, "http") < 0)
         return;

      string cleaned_filename = fileName;
      StringReplace(cleaned_filename, "m_alert", "_alert");
      StringReplace(cleaned_filename, "m_proximity", "_proximity");

      string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
      headers += "accept: application/json\r\n";
      headers += "X-SMC-Key: " + DASHBOARD_API_KEY + "\r\n";

      string body = "--" + boundary + "\r\n";
      body += "Content-Disposition: form-data; name=\"file\"; filename=\"" + cleaned_filename + "\"\r\n";
      body += "Content-Type: text/csv\r\n\r\n";
      body += csvData;

      if(StringSubstr(body, StringLen(body)-2) != "\r\n")
         body += "\r\n";

      body += "--" + boundary + "--\r\n";

      char data[], result[];
      string result_headers;

      StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      int res = WebRequest("POST", DASHBOARD_BASE_URL + "/webhook/swing-poi", headers, 15000, data, result, result_headers);
      if(res >= 200 && res <= 299)
         Print("+++ 🌐 Dashboard Swing POI CSV Batch Synced successfully: ", cleaned_filename);
      else
         Print("--- ❌ Dashboard Swing POI CSV Batch Sync Failed: HTTP ", res, " | ", CharArrayToString(result));
     }
  };
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\mq5_dashboard.mqh

// END FILE: Include\Custom\General\mq5_dashboard.mqh
