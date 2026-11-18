"""Import explicit rejected entry attempts from an MT5 Experts log.

Usage: python import_broker_rejections.py LOG --output MQL5/Files/.../imported_rejections.csv
Use --date YYYY-MM-DD if the log has no daily-journal or M1 signal date.
Unscoped imports apply only when the user selects this file in the simulator.
"""
import argparse
import calendar
from datetime import datetime
from pathlib import Path
import re

SUPPORTED = {10014, 10034, 10017, 10018, 10042, 10043, 10044}
VOLUME_SPECIFIC = {10014, 10034}
HEADER = 'version;server;account;symbol;tf;lb_id;side;minute;code;volume'


def timeframe(name):
    if name == 'MN1':
        return 49153
    if name.startswith('M'):
        return int(name[1:])
    if name.startswith('H'):
        return 16384 + int(name[1:])
    return {'D1': 16408, 'W1': 32769, 'MN1': 49153}[name]


def parse_log(text, day=None):
    current_day = datetime.strptime(day, '%Y-%m-%d').date() if day else None
    signals, records = {}, set()
    for number, line in enumerate(text.splitlines(), 1):
        dated = re.search(r'journal initiated for (\d{4}\.\d{2}\.\d{2})', line)
        if dated:
            current_day = datetime.strptime(dated[1], '%Y.%m.%d').date()
        signal = re.search(r'\[M1 (?:ARMED|CONFIRMED)\] (\S+) PERIOD_(\w+) LB=(\S+).*?(?:touch|confirmed)=(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})', line)
        if signal:
            when = datetime.strptime(signal[4], '%Y.%m.%d %H:%M:%S')
            current_day = when.date()
            side = 1 if signal[3].startswith('LB_BULL_') else -1 if signal[3].startswith('LB_BEAR_') else 0
            if side:
                signals[(signal[1], timeframe(signal[2]))] = (signal[3], side, calendar.timegm(when.timetuple()))
        rejection = re.search(r'\[(?:ORDER CHECK FAILED|FINAL CHECK FAILED|ENTRY RESULT|BROKER ENTRY BLOCK)\] (\S+?)(?=\s|:).*?code=(\d+)', line)
        if not rejection or int(rejection[2]) not in SUPPORTED:
            continue
        stamp = re.search(r'\b(\d{2}:\d{2}:\d{2})(?:\.\d+)?\b', line)
        if not current_day or not stamp:
            raise ValueError(f'Line {number}: missing rejection date/time; specify --date.')
        at = datetime.combine(current_day, datetime.strptime(stamp[1], '%H:%M:%S').time())
        seconds = calendar.timegm(at.timetuple())
        code, symbol = int(rejection[2]), rejection[1]
        side_hint = 1 if 'ORDER_TYPE_BUY' in line else -1 if 'ORDER_TYPE_SELL' in line else 0
        candidates = [(tf, lb, side) for (sym, tf), (lb, side, seen) in signals.items()
                      if sym == symbol and 0 <= seconds-seen <= 120 and (not side_hint or side == side_hint)]
        if len(candidates) != 1:
            raise ValueError(f'Line {number}: cannot uniquely identify the rejected LB/TF; use native EA records for this log.')
        tf, lb, side = candidates[0]
        match = re.search(r'volume=([0-9.]+)', line)
        volume = float(match[1]) if match and code in VOLUME_SPECIFIC else 0.0
        if code in VOLUME_SPECIFIC and volume <= 0:
            raise ValueError(f'Line {number}: rejected volume is missing.')
        records.add((symbol, tf, lb, side, seconds-seconds % 60, code, volume))
    return sorted(records, key=lambda row: (row[4], row[0], row[1], row[6]))


def encode(records):
    return HEADER + '\n' + ''.join(
        f'1;;0;{symbol};{tf};{lb};{side};{minute};{code};{volume:.8f}\n'
        for symbol, tf, lb, side, minute, code, volume in records)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--date')
    args = parser.parse_args()
    data = args.log.read_bytes()
    text = data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    rows = parse_log(text, args.date)
    if not rows:
        raise SystemExit('No supported rejected entries found; output not written.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(encode(rows), encoding='utf-8', newline='\n')
    print(f'Imported {len(rows)} unique rejection records into {args.output}')
