#!/usr/bin/env python3
"""Create a deterministic, single-folder candidate from an audited build."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ROOT_FILES = ('.gitignore', 'VERSION', 'Makefile', 'LICENSE', 'README.md', 'README.pt-BR.md', 'Instalar.desktop',
              'CHANGELOG.md', 'CHANGELOG.pt-BR.md', 'iniciar.sh', 'instalar.sh',
              'configurar.sh', 'configurar-tecla.sh', 'diagnosticar.sh', 'desinstalar.sh')
DIRECTORIES = ('.github', 'src', 'scripts', 'packaging', 'i18n', 'docs', 'tests', 'compat')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    files = {}
    for name in ROOT_FILES:
        path = ROOT/name
        if path.is_file(): files[name] = path
    for directory in DIRECTORIES:
        for path in sorted((ROOT/directory).rglob('*')):
            if path.is_symlink(): raise ValueError(f'Unexpected source symlink: {path}')
            if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc' and 'test-results' not in path.parts:
                files[path.relative_to(ROOT).as_posix()] = path
    for binary in manifest['binaries']:
        name = binary['file']
        relative=binary.get('path','bin/'+name)
        if Path(relative).is_absolute() or '..' in Path(relative).parts:
            raise ValueError('Unsafe binary path')
        path = ROOT/relative
        if hashlib.sha256(path.read_bytes()).hexdigest() != binary['sha256']:
            raise ValueError('Binary changed since ELF audit: '+name)
        files[relative] = path
    payload = {name: path.read_bytes() for name, path in files.items()}
    payload['build-manifest.json'] = args.manifest.read_bytes()
    def version(s): return tuple(map(int,s.split('.')))
    floor=max((b['symbol_requirements']['GLIBC'] for b in manifest['binaries'] if b['symbol_requirements'].get('GLIBC')),key=version)
    payload['runtime-target.conf']=(f"architecture={manifest['architecture']}\nlibc=glibc\nminimum_glibc={floor}\nbackend=x11\n").encode()
    index = {name: hashlib.sha256(data).hexdigest() for name, data in payload.items()}
    payload['package-files.json'] = (json.dumps({'schema': 1, 'files': index}, indent=2)+'\n').encode()
    payload['SHA256SUMS'] = ''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n'
                                   for name, data in sorted(payload.items())).encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    date = time.gmtime(max(315532800, manifest['source_date_epoch']))[:6]
    with zipfile.ZipFile(args.output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo('Print-RC/'+name, date_time=date)
            info.create_system = 3
            mode = 0o755 if name in ('Print-RC','Instalar') or name.startswith('bin/') or name.endswith(('.sh','.desktop')) else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_suffix(args.output.suffix+'.sha256').write_text(f'{digest}  {args.output.name}\n')
    print(f'{digest}  {args.output.name}')

if __name__ == '__main__': main()
