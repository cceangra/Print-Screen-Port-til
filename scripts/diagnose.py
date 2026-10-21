#!/usr/bin/env python3
"""Observe only. Never execute the capture binary, reserve keys or alter a desktop."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
from print_rc_i18n import tr, localize_argparse

ROOT=Path(__file__).resolve().parent.parent

def safe_file(path,root=ROOT):
    try:
        relative=path.relative_to(root)
        current=root
        for part in relative.parts:
            current=current/part
            if current.is_symlink():return False
        return path.is_file()
    except ValueError:return False

def read_config():
    path=ROOT/'config/opcoes.conf'
    if not safe_file(path):return {'status':'CONFIG_MISSING_OR_UNSAFE'}
    data={}
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):continue
        key,sep,value=line.partition('=')
        if key not in ('save_dir','save_dir_relative','copy_clipboard') or not sep:continue
        if key in data:return {'status':'CONFIG_INVALID','duplicate_key':key}
        data[key]=value
    image=data.get('save_dir','')
    if data.get('save_dir_relative'):
        rel=Path(data['save_dir_relative'])
        if rel.is_absolute() or '..' in rel.parts:return {'status':'CONFIG_INVALID'}
        image=str(ROOT/rel)
    valid=bool(image.startswith('/') and data.get('copy_clipboard') in ('0','1'))
    return {'status':'CONFIG_VALID' if valid else 'CONFIG_INVALID','save_dir':image,
            'directory_exists':Path(image).is_dir() if image else False,
            'copy_clipboard':data.get('copy_clipboard')=='1'}

def binary_info(path):
    if not safe_file(path):return {'status':'BINARY_MISSING_OR_UNSAFE'}
    data=path.read_bytes()
    if len(data)<20 or data[:4]!=b'\x7fELF':return {'status':'NOT_ELF'}
    order='<' if data[5]==1 else '>'
    machine=struct.unpack_from(order+'H',data,18)[0]
    result={'status':'ELF_FOUND','bits':64 if data[4]==2 else 32,'machine':machine,
            'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
    readelf=shutil.which('readelf')
    if readelf:
        info=subprocess.run([readelf,'-Wl',str(path)],capture_output=True,text=True,timeout=5,check=False)
        result['dynamic_interpreter']='INTERP' in info.stdout
        notes=subprocess.run([readelf,'-Wn',str(path)],capture_output=True,text=True,timeout=5,check=False)
        match=re.search(r'Build ID:\s*(\w+)',notes.stdout)
        result['build_id']=match.group(1) if match else None
    return result

def shortcut_info():
    result=[]
    for name in ('atalho-xfce.json','atalho-state.json'):
        path=ROOT/'config'/name
        if not safe_file(path):continue
        try:state=json.loads(path.read_text(encoding='utf-8'))
        except (ValueError,OSError):result.append({'record':name,'status':'INVALID'});continue
        item={'record':name,'status':state.get('status'),'key':state.get('key'),'backend':'xfce' if name=='atalho-xfce.json' else 'trinity'}
        if item['backend']=='trinity':
            home=Path(os.environ.get('TDEHOME',str(Path.home()/'.trinity')))
            external=home/'share/config/khotkeysrc'
            item['external_file_exists']=external.is_file() and not external.is_symlink()
            if item['external_file_exists']:
                text=external.read_text(encoding='utf-8')
                group=state.get('group','')
                # Inspect only the owned section; never print other user commands.
                match=re.search(r'(?ms)^\['+re.escape(group+'Actions0')+r'\]\s*\n(.*?)(?=^\[|\Z)',text)
                command=re.search(r'(?m)^CommandURL=(.*)$',match[1]) if match else None
                import shlex
                expected='/bin/bash '+shlex.quote(str(state.get('launcher','')))
                item['recorded_command_matches_file']=bool(command and command[1]==expected)
        else:
            external=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml'
            item['registry_file_exists']=external.is_file() and not external.is_symlink()
            item['live_registry']='NOT_QUERIED'
            item['live_registry_note']=tr('diagnostic.live_registry_note')
            if item['registry_file_exists']:
                try:
                    tree=ET.parse(external)
                    chosen=state.get('property','').strip('/').split('/')
                    node=tree.getroot()
                    for part in chosen:node=next((c for c in node if c.tag=='property' and c.get('name')==part),None) if node is not None else None
                    item['recorded_command_matches_file']=bool(node is not None and node.get('value')==state.get('command'))
                except (OSError,ET.ParseError):item['registry_parse']='INVALID'
        result.append(item)
    return result

def collect():
    os_release={}
    for line in Path('/etc/os-release').read_text(encoding='utf-8').splitlines():
        key,sep,value=line.partition('=')
        if sep and key in ('ID','NAME','PRETTY_NAME','VERSION_ID','VERSION_CODENAME'):
            os_release[key]=value.strip('"')
    libc_name,libc_version=platform.libc_ver()
    if not libc_name:
        libc_name='musl' if list(Path('/lib').glob('ld-musl-*.so.1')) else 'unknown'
    result={'schema':1,'mode':'READ_ONLY','title':tr('diagnostic.title'),
            'os_release':os_release,'architecture':platform.machine(),
            'session':{'protocol':os.environ.get('XDG_SESSION_TYPE','unknown'),'desktop':os.environ.get('XDG_CURRENT_DESKTOP','unknown'),
                       'display_configured':bool(os.environ.get('DISPLAY')),'wayland_display_configured':bool(os.environ.get('WAYLAND_DISPLAY'))},
            'libc':{'family':libc_name,'version':libc_version},
            'binary':binary_info(ROOT/'bin/print-rc'),'launcher':binary_info(ROOT/'bin/print-rc-launcher'),
            'configuration':read_config(),'shortcuts':shortcut_info(),
            'overlay_result':'NOT_RUN','capture_result':'NOT_RUN','shortcut_grab_probe':'NOT_RUN',
            'previous_log_files':[],'limits':tr('diagnostic.limits')}
    logs=ROOT/'logs'
    if logs.is_dir() and not logs.is_symlink():
        # Names only, bounded, no secret-bearing log contents or symlink traversal.
        result['previous_log_files']=[p.name for p in sorted(logs.iterdir())[:20] if p.is_file() and not p.is_symlink()]
    metadata=ROOT/'build-manifest.json'
    if safe_file(metadata):
        try:result['build_manifest']=json.loads(metadata.read_text(encoding='utf-8'))
        except (OSError,ValueError):result['build_manifest']='INVALID'
    arch=result['architecture'];expected={'x86_64':62,'aarch64':183}.get(arch)
    result['binary_arch_matches_host']=expected is not None and result['binary'].get('machine')==expected
    return result

def redact(text):
    for value,replacement in sorted(((str(ROOT),'<APP>'),(str(Path.home()),'<HOME>')),key=lambda item:-len(item[0])):
        if value!='/' and value:text=text.replace(value,replacement)
    # Avoid exposing another account's launcher/capture paths stored in old state.
    text=re.sub(r'/home/[^/\s"\\]+','/home/<USER>',text)
    return text

def main():
    localize_argparse();p=argparse.ArgumentParser(description=tr('diagnostic.description'))
    mode=p.add_mutually_exclusive_group()
    mode.add_argument('--read-only',action='store_true',help=tr('diagnostic.read_only'))
    mode.add_argument('--output',type=Path,help=tr('diagnostic.output'))
    args=p.parse_args()
    try:
        output=redact(json.dumps(collect(),ensure_ascii=False,indent=2)+'\n')
        if args.output:
            # Destination is explicit; O_EXCL/NOFOLLOW refuses existing files and links.
            fd=os.open(args.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL|getattr(os,'O_NOFOLLOW',0),0o600)
            with os.fdopen(fd,'w',encoding='utf-8') as report:report.write(output)
            print(tr('diagnostic.saved',str(args.output)))
        else:print(output,end='')
    except (OSError,ValueError,subprocess.TimeoutExpired) as error:
        print(tr('diagnostic.failed',redact(str(error))),file=sys.stderr);return 2
    return 0

if __name__=='__main__':raise SystemExit(main())
