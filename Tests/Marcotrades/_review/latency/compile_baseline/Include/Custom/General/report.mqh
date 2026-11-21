//+------------------------------------------------------------------+
//|                                                       report.mqh |
//|                 SMC Bordered Excel HTML Report Engine            |
//|                 With Contracts, Rewards, Setup, Timeslots        |
//+------------------------------------------------------------------+
#property copyright "Custom SMC Architect"
#property version   "1.32"
#property strict

// Structure to buffer each timeframe scenario row before rendering
struct SReportScenarioRow
  {
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   int               trades;
   int               wins;
   int               losses;
   int               openTrades;
   double            winRate;
   double            contracts;     // Total lots traded
   double            rewards;       // Total R-multiple
   string            setup;         // Setup Nomenclature (e.g., H1-BL-LB-IND)
   string            timeSlots;     // Trade Timeslots (Open - Close)
   double            finalBalance;
   double            netProfit;
  };

//+------------------------------------------------------------------+
//| Class CBacktestReportManager                                     |
//| Handles grouping, cell merging (rowspan), styling & file writing |
//+------------------------------------------------------------------+
class CBacktestReportManager
  {
private:
   SReportScenarioRow m_rows[];
   int                m_total_trades;
   int                m_total_wins;
   int                m_total_losses;
   int                m_total_open;
   double             m_total_contracts;
   double             m_total_rewards;
   double             m_total_profit;
   double             m_starting_capital;
   string             m_execution_note;

   // Helper: Strip broker suffixes like 'c' (cent) or 'm' (micro) -> XAUUSDc becomes XAUUSD
   string             CleanSymbolName(string sym)
     {
      int len = StringLen(sym);
      if(len > 1)
        {
         string last = StringSubstr(sym, len - 1, 1);
         if(last == "c" || last == "m")
            return StringSubstr(sym, 0, len - 1);
        }
      return sym;
     }

public:
                     CBacktestReportManager()
     {
      Reset(0.0);
     }

                    ~CBacktestReportManager() {}

   void              Reset(double starting_capital)
     {
      ArrayResize(m_rows, 0);
      m_total_trades     = 0;
      m_total_wins       = 0;
      m_total_losses     = 0;
      m_total_open       = 0;
      m_total_contracts  = 0.0;
      m_total_rewards    = 0.0;
      m_total_profit     = 0.0;
      m_starting_capital = starting_capital;
      m_execution_note = "";
     }

   void              SetExecutionNote(string note)
     {
      StringReplace(note,"&","&amp;"); StringReplace(note,"<","&lt;"); StringReplace(note,">","&gt;");
      m_execution_note=note;
     }

   void              AddScenarioResult(string symbol, ENUM_TIMEFRAMES tf, int trades, int wins, int losses, int openTrades, double winRate, double contracts, double rewards, string setup, string timeSlots, double finalBalance, double netProfit)
     {
      int sz = ArraySize(m_rows);
      ArrayResize(m_rows, sz + 1);

      m_rows[sz].symbol       = symbol;
      m_rows[sz].tf           = tf;
      m_rows[sz].trades       = trades;
      m_rows[sz].wins         = wins;
      m_rows[sz].losses       = losses;
      m_rows[sz].openTrades   = openTrades;
      m_rows[sz].winRate      = winRate;
      m_rows[sz].contracts    = contracts;
      m_rows[sz].rewards      = rewards;
      m_rows[sz].setup        = setup;
      m_rows[sz].timeSlots    = timeSlots;
      m_rows[sz].finalBalance = finalBalance;
      m_rows[sz].netProfit    = netProfit;

      m_total_trades    += trades;
      m_total_wins      += wins;
      m_total_losses    += losses;
      m_total_open      += openTrades;
      m_total_contracts += contracts;
      m_total_rewards   += rewards;
      m_total_profit    += netProfit;
     }

   bool              GenerateAndSave(string subFolder, string basePrefix, datetime startWindow, datetime endWindow, string &outSavedFilePath, string &outWhatsAppCaption, string reportTitle = "Marcotrades SMC Dual-TF Backtest Report")
     {
      double portfolio_win_rate = (m_total_trades > 0) ? ((double)m_total_wins / m_total_trades) * 100.0 : 0.0;
      double portfolio_final_balance = m_starting_capital + m_total_profit;

      string startStr = TimeToString(startWindow, TIME_DATE | TIME_MINUTES);
      string endStr   = TimeToString(endWindow, TIME_DATE | TIME_MINUTES);

      // 1. Build Merged Table Rows (Grouping consecutive rows by Symbol)
      string table_rows_html = "";
      int total_rows = ArraySize(m_rows);
      int i = 0;

      while(i < total_rows)
        {
         int j = i;
         while(j < total_rows && m_rows[j].symbol == m_rows[i].symbol)
           {
            j++;
           }
         int span = j - i;

         for(int k = i; k < j; k++)
           {
            table_rows_html += "<tr>";

            // Merged Symbol Cell spanning all timeframes for this symbol
            if(k == i)
              {
               string cleanSym = CleanSymbolName(m_rows[k].symbol);
               table_rows_html += StringFormat(
                                     "<td rowspan=\"%d\" style=\"vertical-align:middle; text-align:center; font-weight:bold; font-size:11pt; background-color:#FFFFFF; border:1pt solid #708090;\">"
                                     "%s"
                                     "</td>",
                                     span, cleanSym
                                  );
              }

            // Formatting WinRate
            string winRateStyle = "";
            if(m_rows[k].trades > 0)
              {
               if(m_rows[k].winRate >= 70.0)
                  winRateStyle = " style=\"color:#008000; font-weight:bold; background-color:#E8F5E9;\"";
               else
                  if(m_rows[k].winRate < 50.0)
                     winRateStyle = " style=\"color:#D32F2F; font-weight:bold; background-color:#FFEBEE;\"";
              }

            // Formatting Rewards (R)
            string rewardStyle = "";
            if(m_rows[k].rewards > 0.0)
               rewardStyle = " style=\"color:#008000; font-weight:bold;\"";
            else
               if(m_rows[k].rewards < 0.0)
                  rewardStyle = " style=\"color:#D32F2F; font-weight:bold;\"";

            // Formatting Net Profit
            string profitStyle = (m_rows[k].netProfit > 0) ? " style=\"color:#008000; font-weight:bold;\"" : ((m_rows[k].netProfit < 0) ? " style=\"color:#D32F2F; font-weight:bold;\"" : "");

            // Columns order: Symbol | Timeframe | Trades | Wins | Losses | Open | WinRate | Contracts | Rewards | Setup | Timeslots | FinalBalance | NetProfit
            table_rows_html += StringFormat(
                                  "<td>%s</td>"
                                  "<td>%d</td>"
                                  "<td>%d</td>"
                                  "<td>%d</td>"
                                  "<td>%d</td>"
                                  "<td%s>%.2f%%</td>"
                                  "<td>%.2f L</td>"
                                  "<td%s>%+.2fR</td>"
                                  "<td style=\"font-size:9.5pt; text-align:center; font-weight:bold; color:#1A365D; white-space:nowrap;\">%s</td>"
                                  "<td style=\"font-size:9pt; text-align:left; white-space:nowrap;\">%s</td>"
                                  "<td>$%.2f</td>"
                                  "<td%s>$%.2f</td>"
                                  "</tr>\n",
                                  StringSubstr(EnumToString(m_rows[k].tf), 7),
                                  m_rows[k].trades,
                                  m_rows[k].wins,
                                  m_rows[k].losses,
                                  m_rows[k].openTrades,
                                  winRateStyle,
                                  m_rows[k].winRate,
                                  m_rows[k].contracts,
                                  rewardStyle,
                                  m_rows[k].rewards,
                                  m_rows[k].setup,
                                  m_rows[k].timeSlots,
                                  m_rows[k].finalBalance,
                                  profitStyle,
                                  m_rows[k].netProfit
                               );
           }
         i = j;
        }

      // 2. Build complete HTML document
      string full_excel_content =
         "<html xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\" xmlns=\"http://www.w3.org/TR/REC-html40\">\n"
         "<head>\n"
         "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n"
         "<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>"
         "<x:Name>Marcotrades Backtest</x:Name>"
         "<x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>"
         "</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->\n"
         "<style>\n"
         "  body { font-family: Segoe UI, Calibri, Arial, sans-serif; }\n"
         "  .header-card { background-color: #F0F4F8; border: 1.5pt solid #1A365D; padding: 12px; margin-bottom: 12px; border-radius: 4px; }\n"
         "  table { border-collapse: collapse; width: 100%; font-size: 10.5pt; }\n"
         "  th { background-color: #1A365D; color: #FFFFFF; font-weight: bold; text-align: center; border: 1.5pt solid #000000; padding: 8px 10px; }\n"
         "  td { border: 1pt solid #708090; padding: 6px 10px; text-align: center; vertical-align: middle; }\n"
         "  tr:nth-child(even) td:not([rowspan]) { background-color: #F7FAFC; }\n"
         "  .total_row { background-color: #EDF2F7; font-weight: bold; font-size: 11pt; border-top: 2pt solid #000000; border-bottom: 2pt solid #000000; }\n"
         "</style>\n"
         "</head>\n"
         "<body>\n"
         "<div class=\"header-card\">\n"
         "  <h2 style=\"margin:0 0 6px 0; color:#1A365D;\">" + reportTitle + "</h2>\n"
         "  <div style=\"font-size:10.5pt; color:#2D3748;\">\n"
         "    <b>📅 Report Window:</b> " + startStr + " &nbsp;&rarr;&nbsp; " + endStr + " &nbsp;|&nbsp; "
         "    <b>🪎Starting Capital:</b> $" + DoubleToString(m_starting_capital, 2) + " &nbsp;|&nbsp; "
         "    <b>🕒 Generated:</b> " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n"
         "  </div>\n" + (m_execution_note=="" ? "" : "  <div>"+m_execution_note+"</div>\n") +
         "</div>\n"
         "<table border=\"1\" cellspacing=\"0\" cellpadding=\"6\">\n"
         "<thead>\n"
         "  <tr>\n"
         "    <th>Symbol</th>\n"
         "    <th>Timeframe</th>\n"
         "    <th>Trades</th>\n"
         "    <th>Wins</th>\n"
         "    <th>Losses</th>\n"
         "    <th>Open</th>\n"
         "    <th>WinRate</th>\n"
         "    <th>Contracts</th>\n"
         "    <th>Rewards</th>\n"
         "    <th>Setup</th>\n"
         "    <th>Timeslots</th>\n"
         "    <th>FinalBalance</th>\n"
         "    <th>NetProfit</th>\n"
         "  </tr>\n"
         "</thead>\n"
         "<tbody>\n" +
         table_rows_html +
         StringFormat(
            "<tr class=\"total_row\">"
            "<td><b>TOTAL / SUMMARY</b></td>"
            "<td><b>ALL</b></td>"
            "<td>%d</td>"
             "<td>%d</td>"
             "<td>%d</td>"
             "<td>%d</td>"
             "<td style=\"color:#008000; font-weight:bold;\">%.2f%%</td>"
            "<td><b>%.2f L</b></td>"
            "<td style=\"color:%s; font-weight:bold;\"><b>%+.2fR</b></td>"
            "<td>-</td>"
            "<td>-</td>"
            "<td>$%.2f</td>"
            "<td style=\"color:#008000; font-weight:bold;\">$%.2f</td>"
            "</tr>\n",
            m_total_trades,
             m_total_wins,
             m_total_losses,
             m_total_open,
             portfolio_win_rate,
            m_total_contracts,
            (m_total_rewards >= 0 ? "#008000" : "#D32F2F"),
            m_total_rewards,
            portfolio_final_balance,
            m_total_profit
         ) +
         "</tbody>\n"
         "</table>\n"
         "</body>\n"
         "</html>";

      // 3. Ensure folder exists
      if(subFolder != "")
         FolderCreate(subFolder);

      // 4. Generate timestamped file path
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string timeStamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);

      if(subFolder != "")
         outSavedFilePath = StringFormat("%s\\%s_%s.xls", subFolder, basePrefix, timeStamp);
      else
         outSavedFilePath = StringFormat("%s_%s.xls", basePrefix, timeStamp);

      // 5. Save file
      int fh = FileOpen(outSavedFilePath, FILE_WRITE | FILE_TXT, 0, CP_UTF8);
      if(fh == INVALID_HANDLE)
        {
         PrintFormat("❌  Failed to save report to %s. Error: %d", outSavedFilePath, GetLastError());
         return false;
        }

      FileWriteString(fh, full_excel_content);
      FileClose(fh);

      PrintFormat("💾 Master Bordered Report saved to MQL5/Files/%s", outSavedFilePath);
      Print(StringFormat("📊 PORTFOLIO SUMMARY: Trades: %d | Wins: %d | Losses: %d | Open: %d | WinRate: %.2f%% | Contracts: %.2f L | Rewards: %+.2fR | Total Profit: $%.2f | Final Balance: $%.2f",
                  m_total_trades, m_total_wins, m_total_losses, m_total_open, portfolio_win_rate, m_total_contracts, m_total_rewards, m_total_profit, portfolio_final_balance));

      // 6. Build WhatsApp text caption
      outWhatsAppCaption = StringFormat(
                              "\n📈 *PORTFOLIO SUMMARY:💹*\n"
                              "📅  %s ➔ %s\n\n"
                              "Trades: %d | Wins: %d | Losses: %d | Open: %d\n"
                              "WinRate: %.2f%%\n"
                              "Contracts: %.2f L | Rewards: %+.2fR\n"
                              "Total Profit: $%.2f\n"
                              "Final Balance: $%.2f\n\n",
                              startStr, endStr,
                              m_total_trades, m_total_wins, m_total_losses, m_total_open,
                              portfolio_win_rate, m_total_contracts, m_total_rewards,
                              m_total_profit, portfolio_final_balance
                           );

      return true;
     }

   // Metric Getters
   int               GetTotalTrades()    { return m_total_trades; }
   int               GetTotalWins()      { return m_total_wins; }
   int               GetTotalLosses()    { return m_total_losses; }
   int               GetTotalOpen()      { return m_total_open; }
   double            GetTotalContracts() { return m_total_contracts; }
   double            GetTotalRewards()   { return m_total_rewards; }
   double            GetTotalProfit()    { return m_total_profit; }
   double            GetWinRate()        { return (m_total_trades > 0) ? ((double)m_total_wins / m_total_trades) * 100.0 : 0.0; }
   double            GetFinalBalance()   { return m_starting_capital + m_total_profit; }
  };
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\report.mqh

//+------------------------------------------------------------------+

// END FILE: Include\Custom\General\report.mqh
