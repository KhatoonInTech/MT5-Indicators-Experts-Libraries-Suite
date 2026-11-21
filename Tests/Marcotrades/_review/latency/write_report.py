from pathlib import Path
import hashlib,json,re,zipfile

out=Path(__file__).resolve().parent
root=out.parents[3]
tests=json.loads((out/'final_results.json').read_text())
replays=json.loads((out/'replay_benchmark.json').read_text())
assert len(replays)==8 and all(r['identical_trace_sha256'] for r in replays)
assert len(tests)==23 and all(r['code']==0 for r in tests)
timing=json.loads((out/'seven_run_timing.json').read_text())
metrics=json.loads((out/'latency_metrics.json').read_text())
preservation=json.loads((out/'preservation_checks.json').read_text())
builds=json.loads((out/'build_results.json').read_text())
for build in builds:
    log=Path(build['Log']).read_text(encoding='utf-16')
    build['Result']=log.splitlines()[-1]
    build['errors']=int(re.search(r'Result: (\d+) errors',build['Result'])[1])
    build['warnings']=int(re.search(r', (\d+) warnings',build['Result'])[1])
(out/'build_results.json').write_text(json.dumps(builds,indent=2))
changed=[];known=set()
with zipfile.ZipFile(out/'baseline_sources.zip') as archive:
    for name in archive.namelist():
        known.add(name);p=root/name
        if p.exists() and archive.read(name)!=p.read_bytes():
            changed.append({'file':name,'kind':'modified','sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for folder in ['Include/Custom','Tests/Marcotrades','Tools']:
    for p in (root/folder).rglob('*'):
        name=p.relative_to(root).as_posix()
        if p.is_file() and p.suffix in ['.mqh','.py','.cpp'] and '_review' not in p.parts and name not in known:
            changed.append({'file':name,'kind':'new','sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
binaries=[]
for build in builds:
    if build['errors']:continue
    p=root/Path(build['File']).with_suffix('.ex5')
    binaries.append({'file':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
changed.sort(key=lambda r:r['file'])
(out/'changed_files.json').write_text(json.dumps({'source_files':changed,'rebuilt_binaries':binaries,'generated_evidence':'Tests/Marcotrades/_review/latency/ and existing regression outputs in Tests/Marcotrades/_review/'},indent=2))
lines=[
'LATENCY IMPLEMENTATION REPORT — 2026-11-18',
'',
'Result: verified optimizations implemented; 23 regression suites passed, and all 8 per-candle replay comparisons match the baseline.',
'',
'WHAT CHANGED',
'- Inducement registration uses a sorted identity index and checks registered IDs before repeating pivot-origin validation. Unregistered candidates still receive the original validation.',
'- Rejection histories use indexed identities and version links. Event/zone append order, historical availability, reclassification and opposing-chain decisions are preserved.',
'- A program-local pool reuses immutable closed-candle snapshots and OHLC/volume column decomposition within each processing cycle. It expires at event/pump boundaries and when server time advances. Open candles, failed/partial loads and unsynchronized history are not cached. Its stored working set is capped at 131,072 candles.',
'- Live symbol grouping preserves instance and round-robin order. Completed-bar availability is checked once per compatible cycle/context; bid/ask checks, position management and broker retries remain active. History arrays reserve append capacity.',
'- The backtest indicator uses a 100 ms timer and a 50 ms soft calculation budget. Both chronological phases finish before yielding. History retry attempts remain one second apart.',
'- Backtest progress refresh is capped at four times per second; finished results draw immediately. Unchanged trade drawings are retained. Liquidity drawings skip unchanged frames and invalidate on new calculations, anchor/chart changes, object edits and right-edge changes.',
'- Only [IND STRUCTURE REJECT] and [CHOCH AUDIT] file messages use buffered flushing: up to one second or 64 KiB. Other messages flush immediately. Contents/order/timestamps and program/date naming remain unchanged. Close/rollover flush pending records. Callback delays can postpone timer servicing.',
'',
'PRESERVATION CHOICES / LIMITS',
'- ZigZag.mqh was not edited. SHA-256: '+preservation['zigzag_sha256'],
'- Input declarations match the baseline in all 50 custom programs.',
'- Mutable ZigZag/M1/zone engines are NOT pooled. They contain per-consumer catch-up state and participate in setup-specific pivot/touch audits. The plan allowed independent contexts when equivalence was not established. The implemented pool shares candle snapshots/column calculations; it does not claim to calculate ZigZag once across every setup timeframe.',
'- Raw candle cache keys use symbol, timeframe, range and processing-cycle lifetime; calculation settings remain attached to independent engines. No cross-program or daily-file calculation producer was introduced.',
'- TP allocations, SL/breakeven rules, risk sizing, entry waits, rejection rules, opposing exits, order admission, broker retry logic and durable trade/cluster saves were not changed.',
'- End-to-end MT5 broker fills and native chart screenshot equality were not measured. Evidence consists of production-code offline replay, regression tests, drawing/cache lifecycle tests and native compilation.',
'',
'MEASUREMENTS',
f"- Seven-run offline US30 M1 calculation median: {timing['baseline_median_ms']/1000:.3f} s -> {timing['optimized_median_ms']/1000:.3f} s ({timing['baseline_median_ms']/timing['optimized_median_ms']:.2f}x faster).",
'- These are C++ adaptations of production MQL calculations using exported candles, not a promise of the same live-terminal or broker speedup. Host load varied during testing.',
f"- Separate per-candle sample: median {metrics['baseline']['median_candle_ms']:.3f} -> {metrics['optimized']['median_candle_ms']:.3f} ms; p95 {metrics['baseline']['p95_candle_ms']:.3f} -> {metrics['optimized']['p95_candle_ms']:.3f} ms; maximum {metrics['baseline']['max_candle_ms']:.3f} -> {metrics['optimized']['max_candle_ms']:.3f} ms.",
f"- Offline process peak working set: {metrics['baseline']['peak_process_working_set_bytes']} -> {metrics['optimized']['peak_process_working_set_bytes']} bytes. This does not measure the native MQL candle-pool working set.",
'- Logger regression: 100 routine messages generate one timed flush rather than 100 per-message flushes. Critical messages flush immediately.',
'- Pool regression: repeated compatible requests use one candle load and one column build; consumers cannot mutate cached snapshots.',
'- Repeated unchanged drawing calls do not redraw trade objects (cache/lifecycle regression).',
'',
'VALIDATION',
'- 23 test suites passed. Indexed histories matched the frozen original in 1,963,236 assertions. Symbol grouping passed 20,775 ordering assertions; history/rollover passed 3,895 assertions. Full suite outputs are in final_run_*.txt.',
'- Two stale checks already failed in the untouched baseline: daily-log checks assumed every unrelated custom program was instrumented; the IND test expected an obsolete loop bound. Those checks were corrected. Additional adapters were updated for the new pool/drawing implementation without dropping their behavioral checks.',
'- Live and backtest CMarcoM1LBContext implementations are identical.',
'- Replay fixtures: November 12 and November 17 US30 M1 exports; clustering off/on crossed with entry-policy enforcement off/on. Every candle compares pivots, zone state, event histories and IND inclusion. Opposing-entry decisions are additionally sampled at the recorded decision_stride (1 for the first fixture, 10 for the second); the separate differential-history suite checks 1,963,236 assertions. Equal serialized-state hashes follow:',
]
lines.extend(f"  {r['fixture']} clustering={r['merge']} entry_policy={r['entry_policy']}: {r['identical_trace_sha256']}" for r in replays)
lines+=['','NATIVE BUILDS',f"- {sum(b['errors']==0 for b in builds)}/{len(builds)} affected consumers compiled successfully, including all four main programs.",'- Main versions: marco_backtest_trades 2.29 (cache schema 29), marco_backtest_ea 1.71, marco_live_auto_ea 1.50, liquiduity_block 1.27.','- Three existing failures were reproduced by compiling the untouched baseline sources:']
for b in builds:
    if b['errors']:lines.append(f"  {b['File']}: {b['errors']} errors. See build_results.json and baseline_error_*.log.")
lines+=['  liquidity_swept: obsolete LB_TRIGGER_BL_SSL / LB_TRIGGER_BR_BSL enum names.','  xauusd_heatmap: missing Include/General/xauusd_heatmap.mqh and consequently no OnCalculate.','  Inducements indicator: stale Init/Process signatures and missing SyncInducementStatus.','  These unrelated strategies were not rewritten to force a build.','', 'EXACT SOURCE / TEST FILE LIST']
lines.extend(f"- {r['kind']}: {r['file']}" for r in changed)
lines+=['','REBUILT BINARIES']
lines.extend('- '+b['file'] for b in binaries)
lines+=['','PACKAGING','- MLQ2mlqhFiles.ps1 and ps12mlq.ps1 were inspected. Their existing recursive Include/Custom selection and restore allowlist already include both new MQH files, so neither script needed editing.','- The baseline source ZIP and generated benchmark/compile/test evidence are under Tests/Marcotrades/_review/latency/. No .bak source files were created.','- Exact source and binary SHA-256 values are in changed_files.json.']
(out/'REPORT.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Report and exact changed-file manifest written.')
