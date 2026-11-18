ENTRY-ONLY TWO-STRUCTURE LB GATE - 2026-11-14

Extract this package into the terminal's MQL5 folder, preserving paths.

New entry setups wait for two consecutive same-direction BOS/CHoCH events on the
setup timeframe after mitigation of a valid same-side IND. This applies to BSL/SSL,
IND, and combined LB entry setup types.

Raw LBs remain immediately available to entry-prevention rules and all partial/full
position-exit and TP-management rules. The liquidity-zone indicator therefore keeps
its existing raw-zone display behavior.

Versions: live EA 1.36, backtest EA 1.57, trade indicator 2.15/cache 15,
liquidity visualizer 1.21. All four compile with zero errors.
