"""Compile and exercise the production MQL policy/manager with a fake broker.

Requires g++ (PATH or C:/MinGW/bin/g++.exe). Never connects to MetaTrader.
"""
from pathlib import Path
import re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
compiler = shutil.which('g++') or r'C:\MinGW\bin\g++.exe'
parts = [(root/'Tests/Marcotrades/staged_tp_mocks.cpp').read_text()]
for name in ('staged_tp.mqh', 'staged_tp_live.mqh'):
    source = (root/'Include/Custom/Marcotrades'/name).read_text(encoding='utf-8-sig')
    source = re.sub(r'^#include.*$', '', source, flags=re.M)
    source = re.sub(r'\blong\b', 'long long', source)  # MQL long is always 64-bit.
    parts.append(source)
parts.append((root/'Tests/Marcotrades/staged_tp_cases.cpp').read_text())
with tempfile.TemporaryDirectory(prefix='marco_tp_tests_') as directory:
    source, binary = Path(directory)/'test.cpp', Path(directory)/'test.exe'
    source.write_text('\n'.join(parts), encoding='utf-8')
    subprocess.run([compiler, '-std=c++17', '-O2', '-Wall', '-Wextra', '-Wno-unused-parameter',
                    str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
