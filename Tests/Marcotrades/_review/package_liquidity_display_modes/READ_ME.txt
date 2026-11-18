Liquidity Block Visualizer 1.22 — display-mode dropdown

Install:
Copy Indicators/Custom/Marcotrades/liquiduity_block.ex5 into the matching MQL5
folder, then refresh the MetaTrader Navigator or restart the terminal.

Input: InpLBDisplayMode

1. LB_DISPLAY_RAW_PREVENTION_EXITS
   Shows the complete raw LB context used by entry prevention and intra-position
   management. This includes accepted raw LBs plus m_exit_sources that were
   vetoed for new entries but retained for guardrail/exit decisions.

2. LB_DISPLAY_ENTRY_SETUP_ONLY
   Shows only accepted LBs whose entry policy has armed chronologically. IND LBs
   use valid mitigated IND plus two same-direction structures. BSL/SSL LBs use
   the first adjacent same-direction structure after their registered sweep.
   Guard-only m_exit_sources are excluded.

3. LB_DISPLAY_ALL
   Shows the complete raw context and identifies armed LBs in the label.

Label roles:
- [RAW]        raw context; entry setup is not armed
- [RAW-GUARD]  guard-only prevention/exit source
- [ENTRY]      entry-only view
- [ENTRY+RAW]  armed entry LB that also remains part of raw guardrail context

Entry eligibility is latched during chronological replay, matching the EA and
backtester behavior. A later IND mitigation cannot retroactively hide an LB that
was already armed.

Validation: 238 replay/warmup/display integration assertions passed; MetaEditor
compiled the indicator with 0 errors. Existing name-hiding warnings remain.
