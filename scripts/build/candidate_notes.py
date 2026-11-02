#!/usr/bin/env python3
"""Check the tested archive before publishing an explicitly experimental download.

This does not satisfy or bypass release_gate.py's real-desktop stable release gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

BINARIES=('Instalar','Configurar','Print-RC','bin/print-rc','bin/print-rc-launcher')

def validate(archive,manifest_path,source):
    manifest=json.loads(manifest_path.read_text())
    if not re.fullmatch(r'[0-9a-f]{40}',source) or manifest.get('git_commit')!=source:
        raise ValueError('Archive source does not match the checked main commit')
    if manifest.get('source_dirty') is not False:
        raise ValueError('Candidate source must be clean and committed')
    if (manifest.get('architecture'),manifest.get('libc_family'),manifest.get('backend'))!=('x86_64','glibc','x11'):
        raise ValueError('No candidate publication is defined for this target')
    binaries={item['path']:item for item in manifest['binaries']}
    if len(manifest['binaries'])!=len(BINARIES) or set(binaries)!=set(BINARIES):
        raise ValueError('The five audited executables are required')
    with zipfile.ZipFile(archive) as package:
        names=package.namelist()
        if len(set(names))!=len(names) or any(not name.startswith('Print-RC/') or '..' in Path(name).parts for name in names):
            raise ValueError('Archive must contain one unambiguous application folder')
        if package.read('Print-RC/build-manifest.json')!=manifest_path.read_bytes():
            raise ValueError('The archive and uploaded manifest differ')
        for relative,item in binaries.items():
            info=package.getinfo('Print-RC/'+relative)
            data=package.read(info)
            if data[:6]!=b'\x7fELF\x02\x01' or data[18:20]!=b'\x3e\x00' or not (info.external_attr>>16)&0o111:
                raise ValueError('Missing executable x86_64 ELF: '+relative)
            if hashlib.sha256(data).hexdigest()!=item['sha256']:
                raise ValueError('Binary hash mismatch: '+relative)
            if not item.get('interpreter') or 'libc.so.6' not in item.get('needed',[]):
                raise ValueError('GNU candidates require dynamic glibc')
            for prefix,ceiling in (('GLIBC','2.31'),('GLIBCXX','3.4.28')):
                actual=item['symbol_requirements'].get(prefix)
                if actual and tuple(map(int,actual.split('.')))>tuple(map(int,ceiling.split('.'))):
                    raise ValueError('ABI exceeds '+prefix+' baseline')
        for name in ('Instalar.desktop','Configurar.desktop','instalar.sh','iniciar.sh','scripts/desktop_install.py',
                     'src/main.cpp','LICENSE','package-files.json'):
            package.getinfo('Print-RC/'+name)
    return manifest,hashlib.sha256(archive.read_bytes()).hexdigest()

def notes(manifest,digest,repository,run_id):
    source=manifest['git_commit']
    return f'''## Português

**Versão de teste {manifest['version']} — GNU/Linux Intel/AMD de 64 bits, glibc e X11.** Não é uma versão estável nem uma edição para todo Linux.

1. Em **Assets**, baixe **Print-RC-Linux-x86_64.zip**. Os links “Source code” são para desenvolvedores.
2. Extraia o ZIP. Abra a pasta **Print-RC** e dê duplo clique em **Instalar** (ou **Instalar.desktop**, exibido como **Instalar Print RC**).
3. O terminal abre automaticamente. Escolha a pasta e a tecla, leia o resumo e confirme. Depois use a tecla para capturar ou abra **Configurar** para mudar as opções.

Captura de área/tela, anotação, PNG e Ctrl+V preservados. Pasta única, sem sudo, download de dependências ou serviço de teclado residente. Imagens pessoais são preservadas na desinstalação.

Núcleo e pacote testados no CI em Ubuntu 20.04/22.04 e Debian 13 com Xvfb; serviços XFCE e Sakura também exercitados. **Zorin 17.3 e Q4OS/Trinity reais continuam pendentes**. Outros desktops X11 exigem configuração manual da tecla. **Wayland, ARM, 32 bits e Alpine/musl não são atendidos por este pacote.** Bibliotecas do sistema, Bash e Python 3.8+ são necessários.

## English

**Experimental {manifest['version']} — GNU/Linux x86_64, glibc and X11.** Download **Print-RC-Linux-x86_64.zip** under **Assets**, extract it and open **Instalar** / **Instalar.desktop** inside **Print-RC**. A terminal opens automatically; no commands need typing. **Configurar** opens the settings menu.

CI uses Ubuntu 20.04/22.04 and Debian 13 with Xvfb, plus isolated XFCE and Sakura services. Actual Zorin/Q4OS desktop acceptance is still pending. Other X11 desktops require manual shortcut association. No Wayland, ARM, 32-bit or musl edition. Compatible system libraries, Bash and Python 3.8+ required; runtime libraries are not bundled. The stable release gate remains separate.

Source: `{source}` · [Checks](https://github.com/{repository}/actions/runs/{run_id}) · [Compatibility](https://github.com/{repository}/blob/{source}/docs/pt-BR/COMPATIBILITY.md)

SHA-256 (`Print-RC-Linux-x86_64.zip`): `{digest}`
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--manifest',type=Path,required=True)
    parser.add_argument('--source',required=True)
    parser.add_argument('--repository',required=True)
    parser.add_argument('--run-id',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    manifest,digest=validate(args.archive,args.manifest,args.source)
    args.output.write_text(notes(manifest,digest,args.repository,args.run_id))
    print('Verified candidate:',args.source,digest)

if __name__=='__main__':main()
