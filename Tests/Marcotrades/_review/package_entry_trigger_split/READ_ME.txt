Marcotrades entry-trigger split-policy build — 2026-11-14

Install the EX5 files into the same relative MQL5 folders shown in this archive,
then restart MetaTrader or refresh the Navigator.

Versions:
- marco_backtest_ea 1.58
- marco_live_auto_ea 1.37
- marco_backtest_trades 2.16
- liquduity_block 1.21, recompiled with liquidity_blocks 1.32

Entry-only behavior:
- BL/BR-LB-IND: valid mitigated same-side IND plus two consecutive same-side
  structures (BOS, CHoCH, or the matching sweep).
- BL-LB-BSL / BR-LB-SSL: no mitigated IND requirement; the first adjacent
  structure after the registered sweep must have the same direction.
- Combined IND-BSL / IND-SSL labels use the sweep-trigger policy.
- Entry prevention and open-position exits continue using the old raw-LB logic.

The trade indicator cache schema is now 16, so it will rebuild results once after
this update instead of loading records generated under the previous rule.
