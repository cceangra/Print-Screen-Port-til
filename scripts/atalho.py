#!/usr/bin/env python3
"""Registro conservador de Print no Trinity (X11). Nunca roda como root."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import tempfile
import uuid

NAME = 'Print RC'
FILE = Path.home() / '.trinity/share/config/khotkeysrc'
BLOCK = re.compile(r'(?ms)^\[([^\]\n]+)\]\r?\n.*?(?=^\[[^\]\n]+\]\r?\n|\Z)')


def parse(text):
    found = {}
    for m in BLOCK.finditer(text):
        found[m.group(1)] = m.group(0)
    return found


def get_value(block, key, default=''):
    match = re.search(r'(?m)^' + re.escape(key) + r'=(.*)$', block)
    return match.group(1).strip() if match else default


def set_value(block, key, value):
    pattern = re.compile(r'(?m)^' + re.escape(key) + r'=.*$')
    if pattern.search(block):
        return pattern.sub(lambda _: key+'='+str(value), block, count=1)
    return block.rstrip('\n')+'\n'+key+'='+str(value)+'\n\n'


def replace_block(text, name, value):
    for m in BLOCK.finditer(text):
        if m.group(1) == name:
            return text[:m.start()] + value + text[m.end():]
    raise ValueError('Secao esperada nao existe: '+name)


def write_atomic(path, content):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    mode=path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd,tmp=tempfile.mkstemp(prefix='.print-rc-',dir=path.parent)
    try:
        os.fchmod(fd,mode)
        with os.fdopen(fd,'w',encoding='utf-8',newline='\n') as out:
            out.write(content)
            out.flush()
            os.fsync(out.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def conflicts(text):
    sections=parse(text)
    result=[]
    for section, block in sections.items():
        if not re.fullmatch(r'Data_\d+(?:_\d+)*Triggers\d+', section):
            continue
        key=get_value(block,'Key').casefold().replace(' ','')
        if key not in ('print','sys_req','sysreq'):
            continue
        owner=section.split('Triggers')[0]
        info=sections.get('['+owner+']','') or sections.get(owner,'')
        name=get_value(info,'Name','Acao sem nome')
        action=sections.get(owner+'Actions0','')
        command=get_value(action,'CommandURL','(comando nao identificado)')
        result.append({'section':section,'old_key':get_value(block,'Key'),'name':name,'command':command})
    return result


def yes(question):
    try:
        return input(question+' [s/N]: ').strip().lower() in ('s','sim')
    except EOFError:
        return False


def install(base, command):
    statepath=base/'config/atalho-state.json'
    if statepath.exists():
        print('Atalho ja gerenciado por esta instalacao. Nenhuma alteracao adicional.')
        return
    if os.environ.get('XDG_CURRENT_DESKTOP','').casefold().find('trinity')<0:
        print('Desktop diferente de Trinity: configure manualmente a tecla Print para:')
        print(shlex.quote(str(command)))
        return
    original=FILE.read_text(encoding='utf-8') if FILE.exists() else ''
    entries=conflicts(original)
    if entries:
        print('\nATENCAO: atalhos que usam Print no arquivo do Trinity:')
        for conflict in entries:
            print('  -', conflict['name'],'|',conflict['command'],'|',conflict['section'])
        if not yes('Desativar SOMENTE a tecla Print dessas acoes (sem apagar os programas)?'):
            print('Atalho nao alterado. Voce pode configurar manualmente.')
            return
    else:
        print('Nenhum atalho Print reconhecido em khotkeysrc.')
    print('Arquivo externo que sera editado:', FILE)
    print('Backup integral dentro da pasta Print RC: backups/khotkeysrc.antes')
    print('AVISO: outros atalhos fora deste arquivo podem nao ser identificados.')
    if not yes('Registrar a tecla Print para executar o Print RC?'):
        print('Atalho nao alterado.')
        return
    updated=original
    for conflict in entries:
        section=conflict['section']
        b=parse(updated)[section]
        updated=replace_block(updated,section,set_value(b,'Key',''))
    seen=parse(updated)
    indices=[int(m.group(1)) for s in seen if (m:=re.fullmatch(r'Data_(\d+)',s))]
    index=max(indices,default=0)+1
    root=f'Data_{index}'
    if 'Data' in seen:
        data_block=seen['Data']
        # O numero precisa corresponder ao numero de grupos principais presentes.
        updated=replace_block(updated,'Data',set_value(data_block,'DataCount',index))
    else:
        updated='[Data]\nDataCount='+str(index)+'\n\n'+updated
    # Usar o caminho sem interpretacao de shell quando nao ha espacos especiais.
    action=shlex.quote(str(command))
    created=(
        f'[{root}]\nComment=Captura por area com o Print RC\nEnabled=true\n'
        f'Name={NAME}\nType=SIMPLE_ACTION_DATA\n\n'
        f'[{root}Actions]\nActionsCount=1\n\n'
        f'[{root}Actions0]\nCommandURL={action}\nType=COMMAND_URL\n\n'
        f'[{root}Conditions]\nComment=\nConditionsCount=0\n\n'
        f'[{root}Triggers]\nComment=Simple_action\nTriggersCount=1\n\n'
        f'[{root}Triggers0]\nKey=Print\nType=SHORTCUT\nUuid={{{uuid.uuid4()}}}\n\n'
    )
    updated=updated.rstrip('\n')+'\n\n'+created
    (base/'backups').mkdir(parents=True,exist_ok=True)
    (base/'config').mkdir(parents=True,exist_ok=True)
    backup=base/'backups/khotkeysrc.antes'
    if backup.exists():
        raise SystemExit('Ja existe um backup. Nao irei sobrescrever.')
    backup.write_text(original,encoding='utf-8')
    os.chmod(backup,0o600)
    state={
        'file':str(FILE),'group':root,'conflicts':entries,
        'created_file':not FILE.exists(),
        'original_datacount':get_value(parse(original).get('Data',''),'DataCount') if 'Data' in parse(original) else None,
    }
    write_atomic(FILE,updated)
    statepath.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    os.chmod(statepath,0o600)
    print('\nAtalho gravado no Trinity. Encerre a sessao e entre novamente para carregar.')
    print('Nao reinicie nem mate processos do desktop a forca.')


def remove(base):
    statepath=base/'config/atalho-state.json'
    if not statepath.exists():
        print('Nenhuma integracao de atalho registrada por esta instalacao.')
        return True
    state=json.loads(statepath.read_text(encoding='utf-8'))
    path=Path(state['file'])
    if path != FILE:
        print('Arquivo de outro usuario. Desinstalacao do atalho recusada.')
        return False
    if not path.exists():
        print('Arquivo Trinity ausente; integracao ja nao existe.')
        statepath.unlink()
        return True
    content=path.read_text(encoding='utf-8')
    sections=parse(content)
    root=state['group']
    ours=sections.get(root,'')
    if not ours or get_value(ours,'Name')!=NAME:
        print('Atalho mudou desde a instalacao. Restaure manualmente usando backups/khotkeysrc.antes.')
        return False
    ours_action=sections.get(root+'Actions0','')
    if 'print-rc' not in ours_action.casefold() and 'iniciar.sh' not in ours_action:
        print('Comando do atalho foi modificado. Remocao automatica bloqueada.')
        return False
    # Exclui exclusivamente as secoes criadas pelo Print RC.
    for m in reversed(list(BLOCK.finditer(content))):
        name=m.group(1)
        if name==root or name.startswith(root+'Actions') or name.startswith(root+'Conditions') or name.startswith(root+'Triggers'):
            content=content[:m.start()]+content[m.end():]
    sections=parse(content)
    # Restaurar apenas conflitos que continuam com o Key vazio.
    for item in state['conflicts']:
        section=item['section']
        if section not in sections:
            print('Atalho original nao existe mais:', section, '- ignorando.')
            continue
        block=sections[section]
        if get_value(block,'Key')=='':
            content=replace_block(content,section,set_value(block,'Key',item['old_key']))
            sections=parse(content)
        else:
            print('Atalho alterado pelo usuario:',section,'- nao sobrescrito.')
    sections=parse(content)
    indices=[int(m.group(1)) for s in sections if (m:=re.fullmatch(r'Data_(\d+)',s))]
    if 'Data' in sections:
        data=sections['Data']
        # Nao reduz contagens se outros atalhos tiverem sido adicionados depois.
        content=replace_block(content,'Data',set_value(data,'DataCount',max(indices,default=0)))
    if state['created_file'] and not indices:
        # Somente remova o arquivo se ele contiver apenas Data/DataCount.
        remaining=content.strip()
        if re.fullmatch(r'\[Data\]\s*DataCount=0\s*',remaining):
            path.unlink()
        else:
            write_atomic(path,content)
    else:
        write_atomic(path,content)
    statepath.unlink()
    print('Integracao removida. Reinicie a sessao Trinity para aplicar.')
    return True


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=('install','remove','inspect'))
    parser.add_argument('--base',required=True,type=Path)
    parser.add_argument('--launcher',type=Path)
    args=parser.parse_args()
    if os.geteuid()==0:
        raise SystemExit('Nao execute como root.')
    base=args.base.resolve()
    if args.command=='inspect':
        text=FILE.read_text(encoding='utf-8') if FILE.exists() else ''
        for entry in conflicts(text): print(entry)
    elif args.command=='install':
        if args.launcher is None: parser.error('--launcher obrigatorio')
        install(base,args.launcher.resolve())
    else:
        if not remove(base): raise SystemExit(1)

if __name__=='__main__':
    main()
