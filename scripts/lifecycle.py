#!/usr/bin/env python3
"""App-owned installation metadata and compare-before-write lifecycle operations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from print_rc_i18n import tr, localize_argparse

METADATA='config/installation-manifest.json'
GENERATED={'config/opcoes.conf','config/language',METADATA,'.print-rc-installation'}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def safe(base,relative):
    rel=Path(relative)
    if rel.is_absolute() or '..' in rel.parts:raise ValueError(tr('lifecycle.unsafe'))
    current=base
    for part in rel.parts:
        current=current/part
        if current.is_symlink():raise ValueError(tr('lifecycle.unsafe'))
    return current

def atomic(path,data):
    replace=path.exists()
    fd,temp=tempfile.mkstemp(prefix='.print-rc-state-',dir=path.parent)
    try:
        os.fchmod(fd,0o600)
        with os.fdopen(fd,'w',encoding='utf-8') as out:out.write(data);out.flush();os.fsync(out.fileno())
        if replace:os.replace(temp,path)
        else:os.link(temp,path)
    finally:
        if os.path.lexists(temp):os.unlink(temp)

def inventory(base):
    path=safe(base,'config/arquivos-instalados.sha256')
    if not path.exists():return {}
    found={}
    for line in path.read_text(encoding='utf-8').splitlines():
        hash,sep,rel=line.partition('\t')
        if not sep or len(hash)!=64 or any(c not in '0123456789abcdefABCDEF' for c in hash) or rel in found:
            raise ValueError(tr('lifecycle.inventory_invalid'))
        safe(base,rel);found[rel]=hash
    return found

def track_generated(base,relative,existed=False):
    if relative not in GENERATED:raise ValueError(tr('lifecycle.unsafe'))
    path=safe(base,'config/arquivos-instalados.sha256')
    if not path.exists():return
    before=path.read_bytes()
    values=inventory(base)
    if path.read_bytes()!=before:raise ValueError(tr('lifecycle.concurrent'))
    if '.print-rc-installation' not in values or 'desinstalar.sh' not in values:raise ValueError(tr('lifecycle.inventory_invalid'))
    values[relative]=digest(safe(base,relative))
    data=''.join(f'{hash}\t{rel}\n' for rel,hash in values.items())
    if path.read_bytes()!=before:raise ValueError(tr('lifecycle.concurrent'))
    atomic(path,data)

def record(base,overlay='pending'):
    safe(base,'config').mkdir(mode=0o700,exist_ok=True)
    path=safe(base,METADATA);values=inventory(base)
    if path.exists() and (values.get(METADATA)!=digest(path)):
        raise ValueError(tr('lifecycle.modified'))
    integrations=[]
    for statefile in ('config/atalho-xfce.json','config/atalho-state.json'):
        statepath=safe(base,statefile)
        if not statepath.is_file():continue
        state=json.loads(statepath.read_text(encoding='utf-8'))
        integrations.append({'state_file':statefile,'state_sha256':digest(statepath),
                             'backend':state.get('backend','trinity'),'key':state.get('key','Print'),
                             'external_resource':state.get('property',state.get('file')),
                             'restoration':'compare current ownership before restoring recorded prior values'})
    config=safe(base,'config/opcoes.conf')
    settings=dict(line.split('=',1) for line in config.read_text(encoding='utf-8').splitlines() if '=' in line) if config.is_file() else {}
    output=settings.get('save_dir','')
    inside=bool(settings.get('save_dir_relative') or output.startswith(str(base)+'/'))
    data={'schema':1,'app_id':'Print RC','root':str(base),'state':'OVERLAY_VERIFIED' if overlay=='verified' else 'FILES_CONFIGURED',
          'overlay_verified':overlay=='verified','capture_verified':False,'ready':False,
          'owned_file_inventory':'config/arquivos-instalados.sha256','external_integrations':integrations,
          'capture_destination':{'path':output,'inside_application':inside,'user_owned':True,'delete_on_uninstall':False},
          'other_external_files':[],'background_service':'clipboard owner only, up to 1800 seconds'}
    atomic(path,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    track_generated(base,METADATA)
    return data

def verify(base):
    values=inventory(base)
    if not values or 'desinstalar.sh' not in values or '.print-rc-installation' not in values:
        raise ValueError(tr('lifecycle.inventory_invalid'))
    # Missing/changed app files are preserved by the uninstaller; no claim of ownership over replacements.
    for rel in values:safe(base,rel)
    return values

def main():
    localize_argparse();p=argparse.ArgumentParser(description=tr('lifecycle.description'))
    p.add_argument('action',choices=('record','verify','track','package-entries'))
    p.add_argument('--base',type=Path,required=True,help=tr('cli.base'))
    p.add_argument('--overlay-state',choices=('pending','verified'),default='pending')
    p.add_argument('--file',choices=sorted(GENERATED))
    args=p.parse_args();base=args.base.resolve()
    try:
        if args.action=='package-entries':
            package=safe(base,'package-files.json')
            data=json.loads(package.read_text(encoding='utf-8'))
            if data.get('schema')!=1 or not isinstance(data.get('files'),dict):raise ValueError(tr('lifecycle.inventory_invalid'))
            for rel,hash in data['files'].items():
                safe(base,rel)
                if not isinstance(hash,str) or len(hash)!=64 or any(c not in '0123456789abcdef' for c in hash):raise ValueError(tr('lifecycle.inventory_invalid'))
                print(hash+'\t'+rel)
            print('COMPLETE\tpackage-index')
        elif args.action=='record':record(base,args.overlay_state)
        elif args.action=='track':track_generated(base,args.file)
        else:verify(base)
    except (OSError,ValueError) as error:
        print(tr('lifecycle.failed',str(error)));return 2
    return 0

if __name__=='__main__':raise SystemExit(main())
