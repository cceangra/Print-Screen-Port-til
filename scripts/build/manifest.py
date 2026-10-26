#!/usr/bin/env python3
"""Build-time ELF audit. Never execute an untrusted ELF to discover dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def command(*args):
    result=subprocess.run(args,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
    if result.returncode:
        raise RuntimeError(f'{args[0]} exited {result.returncode}: {result.stdout.strip()}')
    return result.stdout.strip()

def version(value):
    return tuple(map(int, value.split('.')))

def inspect_elf(path, max_glibc=None, max_glibcxx=None):
    header = command('readelf', '-Wh', str(path))
    program = command('readelf', '-Wl', str(path))
    dynamic = command('readelf', '-Wd', str(path))
    symbols = command('readelf', '-WV', str(path))
    notes = command('readelf', '-Wn', str(path))
    if 'INTERP' not in program or 'libc.so.6' not in dynamic:
        raise ValueError(f'{path.name}: GNU releases require dynamic glibc and an interpreter')
    requirements = {}
    for prefix in ('GLIBC', 'GLIBCXX', 'CXXABI'):
        values = set(re.findall(r'\b' + prefix + r'_(\d+(?:\.\d+)+)', symbols))
        requirements[prefix] = max(values, key=version) if values else None
    for prefix, maximum in (('GLIBC', max_glibc), ('GLIBCXX', max_glibcxx)):
        actual = requirements[prefix]
        if maximum and actual and version(actual) > version(maximum):
            raise ValueError(f'{path.name}: {prefix}_{actual} exceeds declared baseline {maximum}')
    interpreter = re.search(r'Requesting program interpreter: ([^\]]+)', program)
    machine = re.search(r'Machine:\s*(.*)', header)
    build_id = re.search(r'Build ID:\s*(\w+)', notes)
    return {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size, 'machine': machine.group(1) if machine else None,
            'interpreter': interpreter.group(1) if interpreter else None,
            'build_id': build_id.group(1) if build_id else None,
            'needed': re.findall(r'Shared library: \[([^\]]+)\]', dynamic),
            'symbol_requirements': requirements}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--max-glibc', default='2.31')
    parser.add_argument('--max-glibcxx', default='3.4.28')
    args = parser.parse_args()
    binaries=[]
    for relative in ('Print-RC','Instalar','bin/print-rc','bin/print-rc-launcher'):
        binary=inspect_elf(ROOT/relative,args.max_glibc,args.max_glibcxx)
        binary['path']=relative
        binaries.append(binary)
    data = {'schema': 1, 'version': (ROOT/'VERSION').read_text().strip(),
            'git_commit': command('git', '-c', 'safe.directory='+str(ROOT), '-C', str(ROOT), 'rev-parse', 'HEAD'),
            'source_dirty': bool(command('git', '-c', 'safe.directory='+str(ROOT), '-C', str(ROOT), 'status', '--porcelain')),
            'source_date_epoch': int(command('git', '-c', 'safe.directory='+str(ROOT), '-C', str(ROOT), 'show', '-s', '--format=%ct', 'HEAD')),
            'architecture': platform.machine(), 'libc_family': 'glibc', 'backend': 'x11',
            'builder_os': Path('/etc/os-release').read_text(),
            'builder_libc': command('getconf', 'GNU_LIBC_VERSION'),
            'compiler': command(*shlex.split(os.environ.get('CXX', 'g++')), '--version'),
            'linker': command('ld', '--version'),
            'build_flags': os.environ.get('CXXFLAGS', '-O2 -pipe -std=c++17 -Wall -Wextra -Wpedantic'),
            'abi_ceiling': {'GLIBC': args.max_glibc, 'GLIBCXX': args.max_glibcxx},
            'locales': ['en-US', 'pt-BR'], 'binaries': binaries,
            'desktop_acceptance': 'PENDING: see compat/linux-targets.json'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2)+'\n')

if __name__ == '__main__':
    main()
