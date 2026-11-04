#!/usr/bin/env python3
"""Complete a source-only download, with consent, without changing its files.

Only a whole, verified candidate from this project's public GitHub releases is
accepted. Download/extraction stays inside the chosen folder. No apt or build.
"""
import hashlib
import ctypes
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
sys.dont_write_bytecode=True
from print_rc_i18n import confirm, tr

ROOT=Path(__file__).resolve().parent.parent
REPOSITORY='cceangra/Print-Screen-Port-til'
RELEASES='https://github.com/'+REPOSITORY+'/releases'
API='https://api.github.com/repos/'+REPOSITORY+'/releases?per_page=20'
ARCHIVE='Print-RC-Linux-x86_64.zip'
BINARIES=('Instalar','Configurar','Print-RC','bin/print-rc','bin/print-rc-launcher')

def read_url(url,limit):
    request=urllib.request.Request(url,headers={'User-Agent':'Print-RC-setup','Accept':'application/vnd.github+json' if url==API else 'application/octet-stream'})
    with urllib.request.urlopen(request,timeout=20) as response:
        if not response.geturl().startswith('https://'):raise ValueError('HTTPS required')
        data=response.read(limit+1)
        if len(data)>limit:raise ValueError('Download exceeds its size limit')
        return data

def platform_check():
    if platform.system()!='Linux' or platform.machine().lower() not in ('x86_64','amd64'):
        raise ValueError(tr('bootstrap.platform'))
    if os.environ.get('XDG_SESSION_TYPE','x11').lower()!='x11':
        raise ValueError(tr('bootstrap.session'))
    try:libc=os.confstr('CS_GNU_LIBC_VERSION') or ''
    except (ValueError,OSError):libc=''
    match=re.fullmatch(r'glibc (\d+)\.(\d+)',libc)
    if not match or tuple(map(int,match.groups()))<(2,31) or not os.access('/bin/bash',os.X_OK):
        raise ValueError(tr('bootstrap.platform'))

def latest_candidate():
    releases=json.loads(read_url(API,2*1024*1024))
    for release in releases:
        tag=release.get('tag_name','')
        if release.get('draft') or not release.get('prerelease') or not re.fullmatch(r'candidate-[0-9a-f]{40}',tag):continue
        assets={item['name']:item for item in release.get('assets',[])}
        if not all(name in assets for name in (ARCHIVE,ARCHIVE+'.sha256','build-manifest.json')):continue
        prefix='https://github.com/'+REPOSITORY+'/releases/download/'+tag+'/'
        if any(assets[name].get('browser_download_url')!=prefix+name for name in (ARCHIVE,ARCHIVE+'.sha256','build-manifest.json')):continue
        return tag[len('candidate-'):],prefix
    raise ValueError(tr('bootstrap.no_candidate'))

def check_files(base):
    """Check critical files on a retry. Never overwrite an existing destination."""
    if base.is_symlink() or not base.is_dir():raise ValueError(tr('bootstrap.destination',str(base)))
    index=base/'package-files.json'
    if index.is_symlink() or not index.is_file():raise ValueError(tr('bootstrap.destination',str(base)))
    files=json.loads(index.read_text())['files']
    critical=set(BINARIES)
    critical.update(name for name in files if name.endswith(('.sh','.py','.json')) or name=='scripts/messages.bash')
    for name in critical:
        relative=PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts:raise ValueError(tr('bootstrap.destination',str(base)))
        path=base
        for part in relative.parts:
            path=path/part
            if path.is_symlink():raise ValueError(tr('bootstrap.destination',str(base)))
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=files.get(name):
            raise ValueError(tr('bootstrap.destination',str(base)))
    return base

def archive_entries(package):
    entries=package.infolist();names=[entry.filename for entry in entries]
    if len(names)!=len(set(names)) or sum(entry.file_size for entry in entries)>64*1024*1024:
        raise ValueError(tr('bootstrap.archive'))
    # Validate the entire directory before extracting a single entry.
    for entry in entries:
        relative=PurePosixPath(entry.filename);mode=entry.external_attr>>16
        if (relative.is_absolute() or '..' in relative.parts or '\\' in entry.filename or
            not relative.parts or relative.parts[0]!='Print-RC' or
            stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0,stat.S_IFREG,stat.S_IFDIR)) or
            entry.file_size>8*1024*1024):raise ValueError(tr('bootstrap.archive'))
    return entries

def unpack(archive,destination):
    with zipfile.ZipFile(archive) as package:
        entries=archive_entries(package)
        for entry in entries:
            path=destination.joinpath(*PurePosixPath(entry.filename).parts)
            if entry.is_dir():path.mkdir(parents=True,exist_ok=True);continue
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open('xb') as output:output.write(package.read(entry))
            path.chmod(0o755 if (entry.external_attr>>16)&0o111 else 0o644)
    return check_files(destination/'Print-RC')

def publish(prepared,target):
    # GNU/glibc >=2.31 provides renameat2. Same-filesystem atomic publication:
    # never replace even an empty directory created concurrently by the user.
    libc=ctypes.CDLL(None,use_errno=True)
    try:rename=libc.renameat2
    except AttributeError as error:raise ValueError(tr('bootstrap.platform')) from error
    rename.argtypes=(ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint)
    rename.restype=ctypes.c_int
    if rename(-100,os.fsencode(prepared),-100,os.fsencode(target),1):
        code=ctypes.get_errno()
        raise OSError(code,os.strerror(code),str(target))

def prepare(base,ask):
    platform_check()
    base=Path(base)
    if any((base/name).exists() or (base/name).is_symlink() for name in ('package-files.json','.print-rc-installation')):
        raise ValueError(tr('bootstrap.existing_install'))
    target=base/'Print-RC'
    if target.exists() or target.is_symlink():
        check_files(target)
        return target if ask(tr('bootstrap.reuse',str(target))) else None
    if not ask(tr('bootstrap.question',str(target))):return None
    print(tr('bootstrap.downloading'),file=sys.stderr,flush=True)
    source,prefix=latest_candidate()
    checksum=read_url(prefix+ARCHIVE+'.sha256',512).decode().split()
    if len(checksum)!=2 or not re.fullmatch('[0-9a-f]{64}',checksum[0]) or checksum[1]!=ARCHIVE:
        raise ValueError(tr('bootstrap.archive'))
    # A private staging directory inside the source folder is removed on every failure.
    with tempfile.TemporaryDirectory(prefix='.print-rc-download-',dir=str(base)) as temporary:
        stage=Path(temporary);archive=stage/ARCHIVE
        data=read_url(prefix+ARCHIVE,16*1024*1024)
        if hashlib.sha256(data).hexdigest()!=checksum[0]:raise ValueError(tr('bootstrap.archive'))
        archive.write_bytes(data);del data
        manifest=stage/'build-manifest.json'
        with zipfile.ZipFile(archive) as package:
            archive_entries(package)
            manifest.write_bytes(package.read('Print-RC/build-manifest.json'))
        spec=importlib.util.spec_from_file_location('candidate_validator',ROOT/'scripts/build/candidate_notes.py')
        validator=importlib.util.module_from_spec(spec);spec.loader.exec_module(validator)
        validator.validate(archive,manifest,source)
        prepared=unpack(archive,stage)
        try:
            result=subprocess.run([str(prepared/'bin/print-rc-launcher'),str(prepared/'bin/print-rc'),'--self-test'],
                                  stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
        except (OSError,subprocess.TimeoutExpired) as error:
            raise ValueError(tr('bootstrap.runtime',str(error))) from error
        if result.returncode:raise ValueError(tr('bootstrap.runtime',result.stdout[-1500:]))
        publish(prepared,target)
    print(tr('bootstrap.ready',str(target)),file=sys.stderr,flush=True)
    return target

def main():
    if sys.argv[1:]!=['--install']:return 2
    try:
        target=prepare(ROOT,confirm)
        if target is None:
            print(tr('bootstrap.cancelled'));return 2
        os.execv(str(target/'Instalar'),[str(target/'Instalar'),'--install'])
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile) as error:
        print(tr('bootstrap.failed',str(error),RELEASES),file=sys.stderr)
        return 2

if __name__=='__main__':raise SystemExit(main())
