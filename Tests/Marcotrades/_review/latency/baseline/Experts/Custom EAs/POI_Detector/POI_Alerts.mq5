//+------------------------------------------------------------------+
//|                                              TeamsAlertScanner.mq5|
//|                                  Copyright 2024, Trading AI Friend|
//+------------------------------------------------------------------+
#property strict

// --- INPUTS ---
input string   Teams_URL = "https://defaultf639f1dc24df479a92038fda25c195.21.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/25fe6d73be614334a9bd8ef29d1891e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=k5tAEUvI0fEXLjQyDiec16wMaSlUli1F2l1fbNWQ-jw";

// --- INITIALIZATION (Runs once when EA starts) ---
int OnInit() {
    Print("--- EA Started: Sending Test Message to Teams ---");
    
    // 🔥 TEST MESSAGE: This proves your MT5 can talk to your Power Automate URL
    SendToTeams("CONNECTION_TEST", "M1", "SUCCESSFUL_TEST", 0.00);

    EventSetTimer(60); // Start the 60-second scanning timer
    return(INIT_SUCCEEDED);
}

// --- SCANNER TIMER ---
void OnTimer() {
    // Regular scanning logic would go here
    Print("Scanner running in background...");
}

//+------------------------------------------------------------------+
//| REST REQUEST FUNCTION (The Webhook)                              |
//+------------------------------------------------------------------+
void SendToTeams(string sym, string tf, string type, double price) {
    char post[], result[];
    string result_headers;
    string headers = "Content-Type: application/json\r\n";
    
    // Create the JSON Payload exactly how Power Automate expects it
    string payload = "{\"symbol\":\"" + sym + "\",\"tf\":\"" + tf + "\",\"type\":\"" + type + "\",\"price\":\"" + DoubleToString(price, 5) + "\"}";
    
    StringToCharArray(payload, post);
    
    // Reset any previous errors
    ResetLastError();
    
    // Send the POST request
    int res = WebRequest("POST", Teams_URL, headers, 10000, post, result, result_headers);
    
    if(res == 200 || res == 202) {
        Print("🚀 SUCCESS: Test alert sent for ", sym);
    } else {
        Print("❌ ERROR: HTTP ", res, " - Last Error: ", _LastError);
        if(res == -1) {
            Print("Check: Tools -> Options -> Expert Advisors -> Allow WebRequest for URL.");
        }
    }
}