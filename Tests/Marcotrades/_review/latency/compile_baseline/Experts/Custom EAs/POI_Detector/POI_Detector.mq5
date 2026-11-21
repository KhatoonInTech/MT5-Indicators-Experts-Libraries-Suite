//+------------------------------------------------------------------+
//|                                              TeamsAlertScanner.mq5|
//|                                  Copyright 2024, Trading AI Friend|
//+------------------------------------------------------------------+
#property strict

#define TEAMS_URL "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/25fe6d73be614334a9bd8ef29d1891e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=k5tAEUvI0fEXLjQyDiec16wMaSlUli1F2l1fbNWQ-jw"

// --- INITIALIZATION (Runs once when EA starts) ---
int OnInit() {
    Print("--- EA Started: Sending Test Message to Teams ---");
    
    // 🔥 TEST MESSAGE: This proves your MT5 can talk to your Power Automate URL
    SendAlert("EURUSD", PERIOD_M15, "SUCCESSFUL_TEST");

    EventSetTimer(60); // Start the 60-second scanning timer
    return(INIT_SUCCEEDED);
}

// --- SCANNER TIMER ---
void OnTimer() {
    // Regular scanning logic would go here
    Print("Scanner running in background...");
}


// ════════════════════════════════════════════════════════════════
// SIMPLIFIED TEAMS ALERT: SEND SYMBOL, TF, TYPE ONLY
// ════════════════════════════════════════════════════════════════
void SendAlert(string symbol, ENUM_TIMEFRAMES tf, string type) {
    
    // 1. Convert Timeframe to a readable string (e.g., "M15", "H1")
    string timeframeStr = StringSubstr(EnumToString(tf), 7);
    
    // 2. Build the Simple JSON Payload
    // This matches the Power Automate schema we set up earlier
    string msg = "{";
    msg += "\"symbol\":\"" + symbol + "\",";
    msg += "\"tf\":\"" + timeframeStr + "\",";
    msg += "\"type\":\"" + type + "\"";
    msg += "}";

    // 3. Prepare WebRequest parameters
    char data[];
    char result[];
    string result_headers;
    string headers = "Content-Type: application/json\r\n";
    
    // Convert string to UTF-8 byte array
    ArrayResize(data, StringToCharArray(msg, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);
    
    // 4. Send the POST request to your TEAMS_URL
    ResetLastError();
    int res = WebRequest("POST", TEAMS_URL, headers, 10000, data, result, result_headers);
    
    // 5. Log the result in MT5 Experts Tab
    if(res >= 200 && res <= 299) {
        Print("+++ ✅ Alert Sent: ", symbol, " | ", timeframeStr, " | ", type);
    } else {
        Print("--- ❌ WebRequest Error: ", res, " | URL may be incorrect or missing from Allow List.");
        Print("--- Response: ", CharArrayToString(result));
    }
}