"""Wire custom MQL programs into daily logging; preserve Print formatting."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\b(PrintFormat|Print)\s*\(')

def calls(text):
    for match in TOKEN.finditer(text):
        if not match.group(1):
            continue
        start = match.end()
        depth, parts, part, i = 1, [], start, start
        while depth:
            if text[i] == '"':
                i += 1
                while text[i] != '"':
                    i += 2 if text[i] == '\\' else 1
            elif text.startswith('//', i):
                i = text.index('\n', i)
            elif text.startswith('/*', i):
                i = text.index('*/', i + 2) + 1
            elif text[i] == '(':
                depth += 1
            elif text[i] == ')':
                depth -= 1
            elif text[i] == ',' and depth == 1:
                parts.append(text[part:i]); part = i + 1
            i += 1
        parts.append(text[part:i-1])
        yield match.start(), i, match.group(1), parts

if __name__ == '__main__':
    import sys
    if '--apply' in sys.argv:
        header = ROOT/'Include/Custom/General/daily_log.mqh'
        overloads = ['void MarcoDailyPrintFormat(string format) { string message=format; Print(message); g_marcoDailyLog.Write(message); }']
        for n in range(1,9):
            template = 'template<'+','.join(f'typename T{i}' for i in range(n))+'>'
            params = ','.join(f'T{i} a{i}' for i in range(n))
            args = ','.join(f'a{i}' for i in range(n))
            joined = '+'.join(f'MarcoLogText(a{i})' for i in range(n))
            overloads.append(f'{template}\nvoid MarcoDailyPrint({params}) {{ Print({args}); g_marcoDailyLog.Write({joined}); }}')
            overloads.append(f'{template}\nvoid MarcoDailyPrintFormat(string format,{params}) {{ string message=StringFormat(format,{args}); Print(message); g_marcoDailyLog.Write(message); }}')
        text=header.read_text(encoding='utf-8')
        text=text.replace('// DAILY_LOG_OVERLOADS','\n'.join(overloads))
        header.write_text(text,encoding='utf-8')
        programs=list((ROOT/'Experts/Custom EAs').rglob('*.mq5'))+list((ROOT/'Indicators/Custom').rglob('*.mq5'))
        for path in programs+list((ROOT/'Include/Custom').rglob('*.mqh')):
            if path==header: continue
            raw=path.read_bytes()
            encoding='utf-8-sig' if raw.startswith(b'\xef\xbb\xbf') else 'utf-8'
            text=raw.decode(encoding)
            original=text
            # MQL permits eight template type parameters. Larger formatted calls
            # keep all their original typed arguments in native StringFormat.
            for start,end,name,args in reversed(list(calls(text))):
                if name=='PrintFormat' and len(args)>9:
                    text=text[:start]+'Print(StringFormat('+','.join(args)+'))'+text[end:]
            if path in programs and '#include <Custom\\General\\daily_log.mqh>' not in text:
                text='#define MARCO_LOG_PROGRAM "'+path.stem+'"\n#include <Custom\\General\\daily_log.mqh>\n'+text
                init=re.search(r'\b(?:int|void)\s+OnInit\s*\([^)]*\)\s*\{',text)
                if init:
                    text=text[:init.end()]+'\n   g_marcoDailyLog.Start();'+text[init.end():]
                else:
                    text+='\nint OnInit() { g_marcoDailyLog.Start(); return INIT_SUCCEEDED; }\n'
                for event in ('OnTick','OnTimer','OnCalculate','OnChartEvent'):
                    match=re.search(r'\b(?:int|void)\s+'+event+r'\s*\([^)]*\)\s*\{',text)
                    if match: text=text[:match.end()]+'\n   g_marcoDailyLog.Pulse();'+text[match.end():]
                match=re.search(r'\bvoid\s+OnDeinit\s*\(const int (\w+)\)\s*\{',text)
                if match: text=text[:match.end()]+'\n   g_marcoDailyLog.Write("[LIFECYCLE] Deinit reason="+(string)'+match[1]+');'+text[match.end():]
            if path in programs and '#define MARCO_LOG_PROGRAM ' not in text:
                text='#define MARCO_LOG_PROGRAM "'+path.stem+'"\n'+text
            if text!=original:
                path.write_bytes(text.encode(encoding))
                print(path.relative_to(ROOT))
        raise SystemExit(0)
    paths = list((ROOT/'Experts/Custom EAs').rglob('*.mq5')) + list((ROOT/'Indicators/Custom').rglob('*.mq5')) + list((ROOT/'Include/Custom').rglob('*.mqh'))
    counts = []
    for path in paths:
        text = path.read_text(encoding='utf-8-sig')
        for _, _, name, args in calls(text):
            counts.append((len(args), name, str(path.relative_to(ROOT))))
    for row in sorted(counts, reverse=True)[:20]:
        print(row)
    print('Print max', max(c[0] for c in counts if c[1]=='Print'))
