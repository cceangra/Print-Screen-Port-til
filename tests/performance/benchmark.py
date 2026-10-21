#!/usr/bin/env python3
"""Explicit X11 benchmark: opens overlays and saves temporary captures. Never read-only."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile
import threading
import time

ROOT=Path(__file__).resolve().parents[2]

def stats(pid,expected_binary=None):
    try:
        if expected_binary is not None and Path(os.readlink(f'/proc/{pid}/exe')).resolve()!=expected_binary.resolve():return {}
        data=Path(f'/proc/{pid}/smaps_rollup').read_text()
        values={line.split(':')[0]:int(line.split()[1]) for line in data.splitlines() if line.startswith(('Pss:','Rss:'))}
        ticks=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
        values['cpu_ticks']=int(ticks[11])+int(ticks[12])
        return values
    except (OSError,ValueError):return {}

def machine_details():
    """Record the measurement host, without serial numbers or user identifiers."""
    cpu=Path('/proc/cpuinfo').read_text(errors='replace')
    model=next((line.split(':',1)[1].strip() for line in cpu.splitlines() if line.startswith('model name')),'unknown')
    memory=next((line.split(':',1)[1].strip() for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:')),'unknown')
    return {'kernel':platform.release(),'cpu_model':model,'logical_cpus':os.cpu_count(),'memory_total':memory}

def run_one(binary,driver,directory,clipboard=False):
    images=directory/'images';images.mkdir(exist_ok=True)
    config=directory/'options';config.write_text(f'save_dir={images}\ncopy_clipboard={int(clipboard)}\n')
    env={**os.environ,'PRINT_RC_CONFIG':str(config),'PRINT_RC_LANG':'en-US'}
    peaks={'Pss':0,'Rss':0};stop=threading.Event()
    with open(directory/'log','w') as log:
        start=time.perf_counter();process=subprocess.Popen([str(binary)],env=env,stdout=log,stderr=log)
        def sample():
            while not stop.wait(.005):
                value=stats(process.pid,binary)
                for key in peaks:peaks[key]=max(peaks[key],value.get(key,0))
        thread=threading.Thread(target=sample);thread.start()
        try:
            subprocess.run([str(driver),'wait'],check=True,stdout=subprocess.DEVNULL,timeout=12)
            ready=time.perf_counter()
            subprocess.run([str(driver),'full'],check=True,timeout=5)
            if clipboard:
                deadline=time.monotonic()+10
                while not list(images.glob('*.png')):
                    if time.monotonic()>deadline:raise RuntimeError('No saved capture')
                    time.sleep(.01)
                # Verify that the resident process actually serves an image.
                pasted=subprocess.check_output(['xclip','-selection','clipboard','-t','image/png','-o'],timeout=10)
                photo=next(images.glob('*.png'));assert pasted==photo.read_bytes()
                idle_start=stats(process.pid,binary);time.sleep(.2);idle_end=stats(process.pid,binary)
                process.terminate()
            pid,status,usage=os.wait4(process.pid,0);process.returncode=os.waitstatus_to_exitcode(status)
            end=time.perf_counter()
            if not clipboard and process.returncode!=0:raise RuntimeError((directory/'log').read_text())
        finally:
            stop.set();thread.join()
            if process.returncode is None:process.kill();process.wait()
    photos=list(images.glob('*.png'));assert len(photos)==1
    result={'overlay_latency_ms':(ready-start)*1000,'capture_wall_ms':(end-start)*1000,
            'cpu_seconds':usage.ru_utime+usage.ru_stime,'peak_rss_kib':usage.ru_maxrss,
            'sampled_peak_pss_kib':peaks['Pss'] or None,'png_bytes':photos[0].stat().st_size,
            'processes_after_capture':int(clipboard)}
    if clipboard:
        result.update(clipboard_pss_kib=idle_end.get('Pss'),clipboard_rss_kib=idle_end.get('Rss'),
                      clipboard_idle_cpu_ticks_200ms=(idle_end['cpu_ticks']-idle_start['cpu_ticks']) if 'cpu_ticks' in idle_end and 'cpu_ticks' in idle_start else None)
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary',required=True,type=Path);p.add_argument('--driver',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path);p.add_argument('--repetitions',type=int,default=5)
    p.add_argument('--label',required=True);args=p.parse_args()
    if args.repetitions<5:p.error('At least five repetitions required')
    dimensions=list(map(int,subprocess.check_output([str(args.driver),'dimensions'],text=True).split()))
    subprocess.run([str(args.driver),'paint'],check=True)
    runs=[]
    with tempfile.TemporaryDirectory() as temp:
        root=Path(temp)
        for i in range(args.repetitions):
            directory=root/str(i);directory.mkdir();runs.append(run_one(args.binary,args.driver,directory))
        directory=root/'clipboard';directory.mkdir();clipboard=run_one(args.binary,args.driver,directory,True)
    wall=sorted(x['capture_wall_ms'] for x in runs)
    result={'schema':1,'label':args.label,'test_kind':'Xvfb development benchmark, white root background',
            'limitations':'Core binary only; no real desktop/shortcut or low-power hardware certification. PSS sampled every 5 ms; RSS/CPU from wait4. Startup includes a separate test-driver process. Clipboard idle sample is 200 ms, not a long-term endurance test. Null PSS/ticks means /proc access was unavailable; never treat it as zero memory/CPU.',
            'environment':{'os_release':Path('/etc/os-release').read_text(),'architecture':platform.machine(),
                           'libc':platform.libc_ver(),'screen':dimensions,**machine_details()},
            'binary_sha256':hashlib.sha256(args.binary.read_bytes()).hexdigest(),
            'driver_sha256':hashlib.sha256(args.driver.read_bytes()).hexdigest(),
            'benchmark_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'binary_bytes':args.binary.stat().st_size,'repetitions':args.repetitions,'runs':runs,
            'summary':{'latency_median_ms':statistics.median(wall),'latency_p95_ms':wall[math.ceil(.95*len(wall))-1],
                       'peak_rss_kib':max(x['peak_rss_kib'] for x in runs),'sampled_peak_pss_kib':max((x['sampled_peak_pss_kib'] for x in runs if x['sampled_peak_pss_kib'] is not None),default=None),
                       'median_cpu_seconds':statistics.median(x['cpu_seconds'] for x in runs)},'clipboard':clipboard}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'label':args.label,'screen':dimensions,**result['summary'],'clipboard_pss_kib':clipboard['clipboard_pss_kib']}))

if __name__=='__main__':main()
