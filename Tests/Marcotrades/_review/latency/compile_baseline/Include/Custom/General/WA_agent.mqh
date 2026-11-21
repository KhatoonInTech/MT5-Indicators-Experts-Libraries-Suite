//+------------------------------------------------------------------+
//|                                                     WA_agent.mqh |
//|                             WhatsApp Agent Platform API Client   |
//|                                      Build: MT5 WebRequest       |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "2.02"

// --- HARDCODED WHATSAPP AGENT CREDENTIALS ---
#define WA_AGENT_API_TOKEN "WAAVjJf2WhPLTONrfg5MLOQZBGnHAr4WErf0ZAEYcZAEno4V0XkJTVMS6IJNZCq3rzUA9POPZCj0iP5ZAtKvBHJ4rz5zPUZCd3FyVTClCi5eUmnZCJfFzAcTVZBBZAtnDBY902uoEf6HNNu9EwolGDTy0ZBX4C3qzExhZBnhQI6SrBbu8GZBmW3ZC8wZD"

// --- HARDCODED RECIPIENT ID ---
#define WA_AGENT_RECIPIENT "user:272623233679401"

//+------------------------------------------------------------------+
//| Class CWhatsAppAgent                                             |
//| Handles Text, Media Uploads, and File+Caption Messaging          |
//+------------------------------------------------------------------+
class CWhatsAppAgent
  {
private:
   string            m_access_token;
   string            m_base_url;

   //+------------------------------------------------------------------+
   //| Helper: Safely escape strings for JSON formatting                |
   //+------------------------------------------------------------------+
   string            EscapeJSON(string text)
     {
      string res = text;
      StringReplace(res, "\\", "\\\\");
      StringReplace(res, "\"", "\\\"");
      StringReplace(res, "\n", "\\n");
      StringReplace(res, "\r", "\\r");
      StringReplace(res, "\t", "\\t");
      return res;
     }

   //+------------------------------------------------------------------+
   //| Helper: Append a string to a dynamic char array                  |
   //+------------------------------------------------------------------+
   void              AppendString(char &arr[], string text)
     {
      uchar temp[];
      int len = StringToCharArray(text, temp, 0, WHOLE_ARRAY, CP_UTF8) - 1;
      if(len > 0)
        {
         int current_size = ArraySize(arr);
         ArrayResize(arr, current_size + len);
         ArrayCopy(arr, temp, current_size, 0, len);
        }
     }

   //+------------------------------------------------------------------+
   //| Helper: Append a binary byte array to a dynamic char array       |
   //+------------------------------------------------------------------+
   void              AppendBinary(char &arr[], const char &bin[])
     {
      int len = ArraySize(bin);
      if(len > 0)
        {
         int current_size = ArraySize(arr);
         ArrayResize(arr, current_size + len);
         ArrayCopy(arr, bin, current_size, 0, len);
        }
     }

   //+------------------------------------------------------------------+
   //| Helper: Extract JSON value for Media ID                          |
   //+------------------------------------------------------------------+
   string            ExtractJSONString(string json, string key)
     {
      string search = "\"" + key + "\":\"";
      int start = StringFind(json, search);
      if(start < 0)
         return "";
      start += StringLen(search);
      int end = StringFind(json, "\"", start);
      if(end < 0)
         return "";
      return StringSubstr(json, start, end - start);
     }

public:
                     CWhatsAppAgent() {}
                    ~CWhatsAppAgent() {}

   //+------------------------------------------------------------------+
   //| Initialize the WhatsApp Agent Credentials                        |
   //+------------------------------------------------------------------+
   void              Init()
     {
      m_access_token = WA_AGENT_API_TOKEN;
      m_base_url     = "https://api.whatsapp.com/agent/v1";

      Print("📱 WhatsApp Agent Platform Initialized.");
     }

   //+------------------------------------------------------------------+
   //| 1. SEND STANDARD TEXT MESSAGE (Uses Hardcoded Recipient)         |
   //+------------------------------------------------------------------+
   bool              SendMessage(string text)
     {
      string url = m_base_url + "/messages";
      string headers = "Authorization: Bearer " + m_access_token + "\r\n" +
                       "Content-Type: application/json\r\n";

      string json = "{"
                    "\"messaging_product\": \"whatsapp\","
                    "\"to\": \"" + WA_AGENT_RECIPIENT + "\","
                    "\"type\": \"text\","
                    "\"text\": { \"body\": \"" + EscapeJSON(text) + "\" }"
                    "}";

      char data[], result[];
      string result_headers;
      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      Print("Sending WhatsApp Message to: ", WA_AGENT_RECIPIENT);
      int res = WebRequest("POST", url, headers, 10000, data, result, result_headers);

      if(res >= 200 && res <= 299)
        {
         Print("✅ WhatsApp Message Sent Successfully.");
         return true;
        }
      else
        {
         Print("❌ WhatsApp Message Failed. HTTP Code: ", res, " | Response: ", CharArrayToString(result));
         return false;
        }
     }

   //+------------------------------------------------------------------+
   //| 2. UPLOAD LOCAL MEDIA (Returns Media ID)                         |
   //+------------------------------------------------------------------+
   string            UploadLocalFile(string file_name, string mime_type = "application/pdf")
     {
      int fh = FileOpen(file_name, FILE_READ | FILE_BIN);
      if(fh == INVALID_HANDLE)
        {
         Print("❌ Failed to open file for WA upload: ", file_name);
         return "";
        }

      int file_size = (int)FileSize(fh);
      char file_data[];
      ArrayResize(file_data, file_size);
      FileReadArray(fh, file_data, 0, file_size);
      FileClose(fh);

      string url = m_base_url + "/media";
      string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      string headers = "Authorization: Bearer " + m_access_token + "\r\n" +
                       "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

      char payload[];

      AppendString(payload, "--" + boundary + "\r\n");
      AppendString(payload, "Content-Disposition: form-data; name=\"messaging_product\"\r\n\r\n");
      AppendString(payload, "whatsapp\r\n");

      AppendString(payload, "--" + boundary + "\r\n");
      AppendString(payload, "Content-Disposition: form-data; name=\"type\"\r\n\r\n");
      AppendString(payload, mime_type + "\r\n");

      AppendString(payload, "--" + boundary + "\r\n");
      AppendString(payload, "Content-Disposition: form-data; name=\"file\"; filename=\"" + file_name + "\"\r\n");
      AppendString(payload, "Content-Type: " + mime_type + "\r\n\r\n");
      AppendBinary(payload, file_data);
      AppendString(payload, "\r\n");

      AppendString(payload, "--" + boundary + "--\r\n");

      char result[];
      string result_headers;
      Print("Uploading file to WhatsApp Agent Platform: ", file_name, " (", file_size, " bytes)");

      int res = WebRequest("POST", url, headers, 30000, payload, result, result_headers);
      string responseStr = CharArrayToString(result);

      if(res >= 200 && res <= 299)
        {
         string media_id = ExtractJSONString(responseStr, "id");
         Print("✅ WhatsApp File Uploaded. Media ID: ", media_id);
         return media_id;
        }
      else
        {
         Print("❌ WhatsApp File Upload Failed. HTTP Code: ", res, " | Response: ", responseStr);
         return "";
        }
     }

   //+------------------------------------------------------------------+
   //| 3. SEND MEDIA USING MEDIA ID (Uses Hardcoded Recipient)          |
   //+------------------------------------------------------------------+
   bool              SendMediaByID(string media_id, string file_name, string media_type = "document", string caption = "")
     {
      string url = m_base_url + "/messages";
      string headers = "Authorization: Bearer " + m_access_token + "\r\n" +
                       "Content-Type: application/json\r\n";

      string json = "{"
                    "\"messaging_product\": \"whatsapp\","
                    "\"to\": \"" + WA_AGENT_RECIPIENT + "\","
                    "\"type\": \"" + media_type + "\","
                    "\"" + media_type + "\": { "
                    "\"id\": \"" + media_id + "\"";

      if(media_type == "document" && file_name != "")
         json += ", \"filename\": \"" + EscapeJSON(file_name) + "\"";

      if(caption != "")
         json += ", \"caption\": \"" + EscapeJSON(caption) + "\"";

      json += "} }";

      char data[], result[];
      string result_headers;
      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(data, ArraySize(data) - 1);

      Print("Sending Media Message to: ", WA_AGENT_RECIPIENT);
      int res = WebRequest("POST", url, headers, 15000, data, result, result_headers);

      if(res >= 200 && res <= 299)
        {
         Print("✅ WhatsApp Media Message Sent Successfully.");
         return true;
        }
      else
        {
         Print("❌ WhatsApp Media Message Failed. HTTP Code: ", res, " | Response: ", CharArrayToString(result));
         return false;
        }
     }

   //+------------------------------------------------------------------+
   //| 4. COMBINED: UPLOAD AND SEND A FILE WITH CAPTION                 |
   //+------------------------------------------------------------------+
   bool              SendMessageWithFile(string file_name, string caption = "", string media_type = "document", string mime_type = "application/pdf")
     {
      string media_id = UploadLocalFile(file_name, mime_type);

      if(media_id == "")
        {
         Print("❌ Aborting SendMessageWithFile because upload failed.");
         return false;
        }

      return SendMediaByID(media_id, file_name, media_type, caption);
     }
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\WA_agent.mqh

// END FILE: Include\Custom\General\WA_agent.mqh
