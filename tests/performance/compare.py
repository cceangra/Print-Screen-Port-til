#!/usr/bin/env python3
"""Check the explicit same-host white-Xvfb cohort; not desktop acceptance."""
import argparse
import json
import math
from pathlib import Path


def compare(directory):
    for resolution in ('1366x768','1920x1080','3840x2160'):
        baseline=json.loads((directory/f'performance-original-dynamic-{resolution}.json').read_text())
        candidate=json.loads((directory/f'performance-candidate-{resolution}.json').read_text())
        for data in (baseline,candidate):
            if data['repetitions']<5 or len(data['runs'])<5:raise ValueError('Five samples required')
            for key in ('latency_p95_ms','median_cpu_seconds','sampled_peak_pss_kib'):
                value=data['summary'].get(key)
                if not isinstance(value,(int,float)) or not math.isfinite(value) or value<=0:raise ValueError('Missing measured '+key)
            if any(run['processes_after_capture']!=0 for run in data['runs']):raise ValueError('Capture process remained')
        for key in ('latency_p95_ms','median_cpu_seconds','sampled_peak_pss_kib'):
            if candidate['summary'][key]>1.2*baseline['summary'][key]:raise ValueError(f'{resolution}: >20% fixture regression: {key}')
        clipboard=candidate['clipboard']
        pss=clipboard.get('clipboard_pss_kib');ticks=clipboard.get('clipboard_idle_cpu_ticks_200ms')
        if not isinstance(pss,(int,float)) or not math.isfinite(pss) or not 0<pss<=8192+2*math.ceil(clipboard['png_bytes']/1024):
            raise ValueError(f'{resolution}: clipboard retained screen-sized memory or PSS unavailable: {pss}')
        if ticks is None or not 0<=ticks<=1 or clipboard['processes_after_capture']!=1:
            raise ValueError(f'{resolution}: clipboard idle/process measurement failed')
        print(f'PASS: {resolution} same-host core CPU/p95/PSS regression and bounded idle clipboard memory')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,required=True)
    compare(parser.parse_args().directory)

if __name__=='__main__':main()
