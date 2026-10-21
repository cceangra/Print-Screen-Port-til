#!/usr/bin/env python3
"""Registro conservador de Print no Trinity (X11). Nunca roda como root."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import uuid

NAME = 'Print RC'
FILE = Path(os.environ.get('TDEHOME') or (Path.home() / '.trinity')) / 'share/config/khotkeysrc'
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


def safe_current_text():
    """Leia somente um arquivo regular; nao siga links simbolicos para atalhos de terceiros."""
    if FILE.is_symlink():
        raise RuntimeError('Atalho do Trinity e um link simbolico; abortando.')
    if not FILE.exists():
        return ''
    if not FILE.is_file():
        raise RuntimeError('O arquivo de atalhos nao e arquivo regular.')
    return FILE.read_text(encoding='utf-8')


def check_unchanged(original):
    """Nunca sobrescrever mudancas feitas por outro processo durante as perguntas."""
    try:
        current = safe_current_text()
    except (OSError, UnicodeError, RuntimeError) as error:
        print('Erro ao verificar arquivo do Trinity:', error)
        return False
    if current != original:
        print('ATENCAO: outro aplicativo alterou o arquivo de atalhos enquanto voce respondia.')
        print('Print RC cancelou a instalacao para NAO sobrescrever configuracoes de terceiros.')
        print('Nenhum atalho foi alterado pelo Print RC. Execute o instalador novamente.')
        return False
    return True


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


def command_for_launcher(command):
    return '/bin/bash ' + shlex.quote(str(command))

def legacy_command_for_launcher(command):
    return shlex.quote(str(command))

def reload_trinity_shortcuts():
    """Notificar somente o servico de atalhos; nao reiniciar desktop."""
    dcop=shutil.which('dcop')
    if dcop is None:
        print('dcop nao encontrado: entre novamente na sessao Trinity para ativar.')
        return False
    try:
        result=subprocess.run(
            [dcop,'kded','khotkeysd','reread_configuration'],
            capture_output=True,text=True,timeout=5
        )
    except (OSError,subprocess.TimeoutExpired) as exc:
        print('Nao foi possivel recarregar atalhos:',exc)
        return False
    if result.returncode:
        print('Trinity nao confirmou recarga:',(result.stderr or result.stdout).strip()[:200])
        return False
    print('khotkeysd notificado para reler a tecla Print nesta sessao.')
    return True

def repair(base, command):
    """Corrige SOMENTE atalho proprio: tipo legacy invalido e launcher antigo.

    Usa o registro local para provar propriedade, valida tecla/comando/tipos e
    conserva todas as secoes alheias ao Print RC. Nao restaura backups antigos.
    """
    statepath=base/'config/atalho-state.json'
    if statepath.is_symlink() or not statepath.is_file():
        print('Registro de atalho ausente ou simbolico: nao reparar.')
        return False
    try:
        state=json.loads(statepath.read_text(encoding='utf-8'))
    except (OSError,ValueError) as exc:
        print('Registro de atalho indisponivel:',exc)
        return False
    if state.get('status')!='installed' or state.get('file')!=str(FILE):
        print('Registro nao pertence a uma integracao ativa neste Trinity.')
        return False
    if state.get('launcher')!=str(command):
        print('Inicializador registrado e diferente. Nada alterado.')
        return False
    try:
        original=safe_current_text()
    except (OSError,UnicodeError,RuntimeError) as exc:
        print('Nao foi possivel ler atalho com seguranca:',exc)
        return False
    sections=parse(original)
    root=state.get('group')
    if (not isinstance(root,str) or not re.fullmatch(r'Data_\d+',root)
            or get_value(sections.get(root,''),'Name')!=NAME):
        print('Atalho original ausente ou alterado por terceiros.')
        return False
    trigger=sections.get(root+'Triggers0','')
    action_section=root+'Actions0'
    action=sections.get(action_section,'')
    current_key=get_value(trigger,'Key')
    recorded_key=state.get('key','Print')
    if (recorded_key not in ('Print','Sys_Req') or current_key!=recorded_key
            or get_value(trigger,'Type')!='SHORTCUT'
            or get_value(action,'Type')!='COMMAND_URL'):
        print('Tecla ou tipos internos do atalho mudaram: preservando configuracao.')
        return False
    current_command=get_value(action,'CommandURL')
    desired=command_for_launcher(command)
    if current_command not in (desired,legacy_command_for_launcher(command)):
        print('Comando do atalho foi modificado pelo usuario. Nada alterado.')
        return False
    group_block=sections[root]
    kind=get_value(group_block,'Type')
    correct_type='COMMAND_URL_SHORTCUT_ACTION_DATA'
    if kind not in ('SIMPLE_ACTION_DATA',correct_type):
        print('Tipo de acao desconhecido ou alterado por terceiros:',kind)
        return False
    if current_command==desired and kind==correct_type:
        print('Atalho Trinity Print RC ja tem tipo e comando corretos.')
        reload_trinity_shortcuts()
        return True
    print('REPARO DO ATALHO PRINT RC (TRINITY)')
    print('Arquivo externo:',FILE)
    print('Tipo anterior:',kind)
    print('Tipo corrigido:',correct_type)
    print('Comando anterior:',current_command)
    print('Comando novo:',desired)
    print('Tecla preservada:',current_key)
    print('Outros atalhos e backup original serao mantidos sem alteracoes.')
    if not yes('Confirma corrigir SOMENTE a acao Print RC?'):
        print('Reparo cancelado.')
        return False
    if not check_unchanged(original):
        return False
    updated=replace_block(original,root,set_value(group_block,'Type',correct_type))
    if current_command!=desired:
        updated=replace_block(updated,action_section,
                              set_value(parse(updated)[action_section],'CommandURL',desired))
    if not check_unchanged(original):
        return False
    write_atomic(FILE,updated)
    print('Tipo e comando do atalho proprio corrigidos; outras secoes mantidas.')
    if not reload_trinity_shortcuts():
        print('Atalho salvo. Trinity nao confirmou recarga; teste apos novo login.')
    print('Pressione Print depois para confirmar que a captura abre.')
    return True

def install(base, command, key='Print'):
    # Tecla validada por X11 no instalador. Chamadas antigas continuam Print.
    if key not in ('Print', 'Sys_Req'):
        raise ValueError('Tecla nao reconhecida como Print Screen pelo X11.')
    statepath=base/'config/atalho-state.json'
    if statepath.exists():
        try:
            old_state=json.loads(statepath.read_text(encoding='utf-8'))
            if old_state.get('status')=='prepared':
                print('Existe registro de instalacao interrompida; nao farei nova alteracao.')
                print('Execute desinstalar.sh para recuperar o atalho com seguranca.')
                return
        except (ValueError,OSError):
            print('Registro do atalho nao pode ser lido; nao sobrescreverei.')
            return
        print('Atalho ja gerenciado; verificando se precisa de reparo.')
        return repair(base,command)
    if os.environ.get('XDG_CURRENT_DESKTOP','').casefold().find('trinity')<0:
        print('Desktop diferente de Trinity: configure manualmente a tecla Print para:')
        print(command_for_launcher(command))
        return
    # O caminho externo e informado ANTES de qualquer autorizacao.
    # Nao criar ~/.trinity nem seus subdiretorios: isso geraria residuos externos.
    if not FILE.parent.is_dir():
        print('Pasta de configuracao do Trinity nao existe:', FILE.parent)
        print('Registro automatico cancelado SEM criar arquivos ou diretorios externos.')
        return
    existed=FILE.exists()
    if existed and (not FILE.is_file() or FILE.is_symlink()):
        print('O caminho do atalho nao e arquivo regular seguro:', FILE)
        print('Registro cancelado.')
        return
    try:
        original=safe_current_text()
    except (OSError, UnicodeError, RuntimeError) as error:
        print('Nao foi possivel ler atalhos sem risco:', error)
        return
    print('\n'+'='*60)
    print('INTEGRACAO EXTERNA — LISTA COMPLETA DE ARQUIVOS')
    print(('MODIFICAR arquivo existente: ' if existed else 'CRIAR arquivo novo: ')+str(FILE))
    print('Arquivos novos fora da pasta: '+('NENHUM' if existed else str(FILE)))
    print('Outros arquivos externos modificados: NENHUM')
    print('Backup e registro de alteracoes: DENTRO de '+str(base))
    print('Na desinstalacao: '+('remover somente o atalho Print RC e restaurar teclas anteriores' if existed else 'APAGAR o arquivo criado, se nao tiver dados adicionados por terceiros'))
    print('Nada sera alterado sem confirmacao expressa.')
    print('='*60)
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
    print('AVISO: outros atalhos fora deste arquivo podem nao ser identificados.')
    if not yes('Registrar a tecla Print para executar o Print RC?'):
        print('Atalho nao alterado.')
        return
    # Perguntas podem demorar: impedir sobrescrita de mudancas externas feitas nesse intervalo.
    if not check_unchanged(original):
        return
    updated=original
    for conflict in entries:
        section=conflict['section']
        b=parse(updated)[section]
        updated=replace_block(updated,section,set_value(b,'Key',''))
    seen=parse(updated)
    # Evitar reutilizar indices mesmo se restar apenas Data_NTriggers0 sem Data_N.
    indices=[int(m.group(1)) for s in seen if (m:=re.match(r'Data_(\d+)(?:$|[A-Za-z])',s))]
    index=max(indices,default=0)+1
    root=f'Data_{index}'
    if 'Data' in seen:
        data_block=seen['Data']
        # O numero precisa corresponder ao numero de grupos principais presentes.
        updated=replace_block(updated,'Data',set_value(data_block,'DataCount',index))
    else:
        updated='[Data]\nDataCount='+str(index)+'\n\n'+updated
    # Usar o caminho sem interpretacao de shell quando nao ha espacos especiais.
    action=command_for_launcher(command)
    created=(
        f'[{root}]\nComment=Captura por area com o Print RC\nEnabled=true\n'
        f'Name={NAME}\nType=COMMAND_URL_SHORTCUT_ACTION_DATA\n\n'
        f'[{root}Actions]\nActionsCount=1\n\n'
        f'[{root}Actions0]\nCommandURL={action}\nType=COMMAND_URL\n\n'
        f'[{root}Conditions]\nComment=\nConditionsCount=0\n\n'
        f'[{root}Triggers]\nComment=Simple_action\nTriggersCount=1\n\n'
        f'[{root}Triggers0]\nKey={key}\nType=SHORTCUT\nUuid={{{uuid.uuid4()}}}\n\n'
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
        'created_file':not existed,
        'original_datacount':get_value(parse(original).get('Data',''),'DataCount') if 'Data' in parse(original) else None,
    }
    # Gravar PRIMEIRO o registro de recuperacao dentro da pasta.
    # Se a sessao cair na metade da escrita externa, o desinstalador sabera reverter.
    state['status']='prepared'
    state['launcher']=str(command)
    state['key']=key
    state['created_sections']=list(parse(created).keys())
    write_atomic(statepath,json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    if not check_unchanged(original):
        # Arquivo externo intacto pelo Print RC: limpar registros internos criados agora.
        statepath.unlink()
        backup.unlink()
        return
    write_atomic(FILE,updated)
    state['status']='installed'
    write_atomic(statepath,json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    print('\nOPERACAO EXTERNA REALIZADA:', 'CRIADO' if not existed else 'MODIFICADO', FILE)
    print('Backup interno:', backup)
    print('Na desinstalacao o proprio script vai desfazer a integracao.')
    reload_trinity_shortcuts()
    print('Pressione Print para testar. Se preciso, saia e entre na sessao.')
    print('Nao reinicie nem mate processos do desktop a forca.')
    return True


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
    if path.is_symlink() or not path.is_file():
        print('Arquivo externo inesperado (nao e arquivo regular). Nada removido.')
        return False
    content=path.read_text(encoding='utf-8')
    sections=parse(content)
    root=state['group']
    ours=sections.get(root,'')
    if not ours or get_value(ours,'Name')!=NAME:
        if state.get('status')=='prepared':
            # Nenhuma alteracao externa ocorreu: descartar apenas o estado interno.
            backup=base/'backups/khotkeysrc.antes'
            if backup.exists() and content==backup.read_text(encoding='utf-8'):
                print('Instalacao anterior parou ANTES de modificar o atalho externo.')
                statepath.unlink()
                return True
        print('Atalho mudou ou houve interrupcao ambigua.')
        print('Nada externo foi apagado. Verifique backups/khotkeysrc.antes.')
        return False
    # Nao remover um atalho que foi alterado pelo usuario apos o registro.
    current_key=get_value(sections.get(root+'Triggers0',''),'Key')
    if current_key!=state.get('key','Print'):
        print('A tecla original foi modificada; preservando atalho e backup.')
        return False
    ours_action=sections.get(root+'Actions0','')
    launcher=state.get('launcher')
    if launcher:
        allowed={command_for_launcher(launcher),legacy_command_for_launcher(launcher)}
        if get_value(ours_action,'CommandURL') not in allowed:
            print('Comando de inicializacao mudou; nenhuma secao sera removida.')
            return False
    elif 'print-rc' not in ours_action.casefold() and 'iniciar.sh' not in ours_action:
        # Compatibilidade com instalacoes anteriores ao 0.4.2.
        print('Comando do atalho foi modificado. Remocao automatica bloqueada.')
        return False
    owned=set(state.get('created_sections') or [
        root,root+'Actions',root+'Actions0',root+'Conditions',root+'Triggers',root+'Triggers0'
    ])
    # Remover APENAS as secoes criadas por esta instalacao.
    # Outras secoes com nomes parecidos pertencem a terceiros e devem permanecer.
    for m in reversed(list(BLOCK.finditer(content))):
        if m.group(1) in owned:
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
    if state['created_file']:
        # O arquivo nao existia antes da instalacao: apaga-lo por completo.
        # Se alguem acrescentou dados, NAO remover nem modificar: preservar o backup.
        remaining=content.strip()
        if not re.fullmatch(r'\[Data\]\s*DataCount=0\s*',remaining):
            print('NAO FOI POSSIVEL EXCLUIR COM SEGURANCA:', path)
            print('O arquivo foi criado pelo Print RC, mas recebeu outras configuracoes.')
            print('Nada foi apagado. A desinstalacao manterá a pasta e os backups.')
            return False
        path.unlink()
        print('ARQUIVO EXTERNO CRIADO PELO PRINT RC: EXCLUIDO:',path)
    else:
        # O arquivo ja existia: nunca apaga-lo.
        write_atomic(path,content)
        print('ARQUIVO EXTERNO ORIGINAL: MANTIDO. Atalho Print RC removido:',path)
    statepath.unlink()
    reload_trinity_shortcuts()
    print('Integracao removida. Saia e entre no Trinity se necessario.')
    return True


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=('install','remove','repair','inspect'))
    parser.add_argument('--base',required=True,type=Path)
    parser.add_argument('--launcher',type=Path)
    parser.add_argument('--key',choices=('Print','Sys_Req'),default='Print')
    args=parser.parse_args()
    if os.geteuid()==0:
        raise SystemExit('Nao execute como root.')
    base=args.base.resolve()
    if args.command=='inspect':
        text=FILE.read_text(encoding='utf-8') if FILE.exists() else ''
        for entry in conflicts(text): print(entry)
    elif args.command=='install':
        if args.launcher is None: parser.error('--launcher obrigatorio')
        if install(base,args.launcher.resolve(),key=args.key) is False:
            raise SystemExit(1)
    elif args.command=='repair':
        if args.launcher is None: parser.error('--launcher obrigatorio')
        if not repair(base,args.launcher.resolve()): raise SystemExit(1)
    else:
        if not remove(base): raise SystemExit(1)

if __name__=='__main__':
    main()
