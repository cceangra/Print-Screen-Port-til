#!/usr/bin/env python3
"""Refuse publication without artifact-specific ABI, desktop and performance evidence."""
import argparse
import hashlib
import json
from pathlib import Path

REQUIRED = ('zorin-17.3-lite-x86_64-x11', 'q4os-trinity-x86_64-x11',
            'ubuntu-20.04-x86_64-x11', 'builder-ubuntu-20.04')
CHECKS = ('overlay_mapped', 'dimmed_pixels', 'input_ready', 'escape_cleanup',
          'area_png', 'fullscreen_png', 'annotation_undo', 'clipboard_incr',
          'shortcut_launch', 'shortcut_restore', 'uninstall_preserves_data')

def validate(archive, manifest, evidence_dir):
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if manifest.get('source_dirty') is not False:
        raise ValueError('Release source must be clean and committed')
    if manifest['version'].endswith('-dev'):
        raise ValueError('Development version: publication disabled')
    if manifest['architecture'] != 'x86_64' or manifest['backend'] != 'x11':
        raise ValueError('No release gate is defined for this target yet')
    def v(s): return tuple(map(int,s.split('.')))
    for binary in manifest['binaries']:
        if not binary.get('interpreter') or 'libc.so.6' not in binary['needed']:
            raise ValueError('Primary GNU binaries must use dynamic glibc')
        for prefix,ceiling in (('GLIBC','2.31'),('GLIBCXX','3.4.28')):
            actual=binary['symbol_requirements'].get(prefix)
            if actual and v(actual)>v(ceiling): raise ValueError('ABI exceeds '+prefix+' baseline')
    for target in REQUIRED:
        path=evidence_dir/(target+'.json')
        if not path.is_file() or path.is_symlink(): raise ValueError('Missing acceptance evidence: '+target)
        evidence=json.loads(path.read_text())
        if evidence.get('target')!=target or evidence.get('archive_sha256')!=digest or evidence.get('git_commit')!=manifest['git_commit']:
            raise ValueError('Evidence does not match this archive/source: '+target)
        host=evidence.get('environment',{})
        for key in ('os_release','architecture','protocol','desktop','libc','libc_version','libX11'):
            if not host.get(key): raise ValueError('Missing measured environment '+key+': '+target)
        if host['architecture']!='x86_64' or host['protocol']!='x11' or host['libc']!='glibc':
            raise ValueError('Wrong environment: '+target)
        if target.startswith('zorin-') and (host['libc_version']!='2.35' or host['desktop'].casefold()!='xfce' or '17.3' not in host['os_release']):
            raise ValueError('Zorin regression requires the actual 17.3 XFCE/glibc 2.35 host')
        if target.startswith('q4os-') and (host['desktop'].casefold()!='trinity' or 'q4os' not in host['os_release'].casefold()):
            raise ValueError('Q4OS regression requires a Q4OS/Trinity host')
        if target.startswith(('zorin-','q4os-')) and evidence.get('test_kind') not in ('physical-desktop','virtual-machine-desktop'):
            raise ValueError('Xvfb is not full desktop acceptance: '+target)
        if not all(evidence.get('checks',{}).get(check) is True for check in CHECKS):
            raise ValueError('Failed/incomplete acceptance checks: '+target)
        perf=evidence.get('performance',{})
        for key in ('repetitions','latency_median_ms','latency_p95_ms','peak_rss_kib','peak_pss_kib','cpu_seconds','baseline_peak_pss_kib','baseline_latency_p95_ms'):
            if not isinstance(perf.get(key),(int,float)) or isinstance(perf.get(key),bool) or perf[key]<=0:
                raise ValueError('Missing measured performance '+key+': '+target)
        if perf['repetitions']<5: raise ValueError('At least five performance repetitions required')
        if (perf['peak_pss_kib']>1.2*perf['baseline_peak_pss_kib'] or perf['latency_p95_ms']>1.2*perf['baseline_latency_p95_ms']) and not perf.get('regression_justification'):
            raise ValueError('Unexplained >20% performance regression: '+target)
        if not evidence.get('tested_at') or not evidence.get('evidence_files'):
            raise ValueError('Timestamp and hashed test logs/screenshots required: '+target)
        for item in evidence['evidence_files']:
            rel=Path(item['path'])
            if rel.is_absolute() or '..' in rel.parts: raise ValueError('Unsafe evidence path')
            data=evidence_dir/rel
            if data.is_symlink() or not data.is_file() or hashlib.sha256(data.read_bytes()).hexdigest()!=item['sha256']:
                raise ValueError('Evidence file checksum mismatch')
    return digest

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive',required=True,type=Path)
    p.add_argument('--manifest',required=True,type=Path)
    p.add_argument('--evidence-dir',required=True,type=Path)
    args=p.parse_args()
    print(validate(args.archive,json.loads(args.manifest.read_text()),args.evidence_dir))

if __name__=='__main__': main()
