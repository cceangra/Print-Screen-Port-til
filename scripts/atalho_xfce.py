#!/usr/bin/env python3
"""Atalho Print no Xfce/X11 via xfconf-query. Sem pacotes, daemon ou sudo."""
import argparse
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

CHANNEL = 'xfce4-keyboard-shortcuts'
PROPERTY = '/commands/custom/Print'
DEFAULT = '/commands/default/Print'
# Nomes de teclas X11 (keysym) sao enviados pelo detector C++.
# Nunca aceitar um nome que possa modificar outra propriedade do xfconf.
DISALLOWED_KEYS = {
    'Escape','Shift_L','Shift_R','Control_L','Control_R','Alt_L','Alt_R',
    'Meta_L','Meta_R','Super_L','Super_R','Hyper_L','Hyper_R',
    'ISO_Level3_Shift','Mode_switch',
}
def valid_key(key):
    return (isinstance(key,str) and re.fullmatch(r'[A-Za-z0-9_]{1,64}',key)
            and key not in DISALLOWED_KEYS)

def shortcut_property(key):
    if not valid_key(key):
        raise ValueError('Nome de tecla X11 invalido ou modificador sozinho: '+str(key))
    return '/commands/custom/'+key
STATE_FILE = 'config/atalho-xfce.json'
NAME = 'Print RC'

def desktop_is_xfce():
    return 'xfce' in os.environ.get('XDG_CURRENT_DESKTOP', '').casefold()

def app_command(launcher):
    return '/bin/bash ' + shlex.quote(str(launcher))

def call(*args):
    executable = shutil.which('xfconf-query')
    if not executable:
        raise RuntimeError('xfconf-query nao esta disponivel neste ambiente.')
    result = subprocess.run([executable, '-c', CHANNEL, '-p', *args],
                            capture_output=True, text=True, timeout=8, check=False)
    return result

def get(prop=PROPERTY):
    # Consultar a lista, e nao o texto de erros traduzidos por locale.
    executable = shutil.which('xfconf-query')
    if not executable:
        raise RuntimeError('xfconf-query indisponivel.')
    listed = subprocess.run([executable, '-c', CHANNEL, '-l'],
                            capture_output=True, text=True, timeout=8, check=False)
    if listed.returncode:
        raise RuntimeError('Falha consultando canal Xfce: ' + listed.stderr.strip())
    if prop not in listed.stdout.splitlines():
        return None
    result = call(prop)
    if result.returncode:
        raise RuntimeError('Falha lendo tecla Print do Xfce: ' + result.stderr.strip())
    return result.stdout.strip()

def set_key(command, existed, prop=PROPERTY):
    args = [prop]
    if not existed:
        args += ['-n', '-t', 'string']
    args += ['-s', command]
    result = call(*args)
    if result.returncode:
        raise RuntimeError('Xfce recusou configuracao: ' + result.stderr.strip())

def remove_key(prop=PROPERTY):
    result = call(prop, '-r')
    if result.returncode:
        raise RuntimeError('Xfce recusou remocao do atalho: ' + result.stderr.strip())

def safe_state(base):
    path = base / STATE_FILE
    if path.is_symlink():
        raise RuntimeError('Registro de atalho e link simbolico. Nenhuma alteracao.')
    if not path.exists():
        return None
    if not path.is_file():
        raise RuntimeError('Registro de atalho nao e arquivo regular.')
    state = json.loads(path.read_text(encoding='utf-8'))
    if (not isinstance(state, dict) or state.get('backend') != 'xfce'
            or not isinstance(state.get('key','Print'),str)
            or state.get('property') != shortcut_property(state.get('key','Print'))):
        raise RuntimeError('Registro de atalho inesperado: nenhuma alteracao.')
    return state

def write_state(base, data):
    path = base / STATE_FILE
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise RuntimeError('Registro de atalho nao e arquivo regular seguro.')
    if not path.parent.is_dir() or path.parent.is_symlink():
        raise RuntimeError('Diretorio interno config/ inexistente ou simbolico.')
    fd, tmp = tempfile.mkstemp(prefix='.atalho-xfce-', dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as output:
            json.dump(data, output, ensure_ascii=False, indent=2)
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.lexists(tmp):
            os.unlink(tmp)

def yes(question):
    try:
        return input(question + ' [s/N]: ').strip().casefold() in ('s', 'sim')
    except EOFError:
        return False

def check_environment():
    if not desktop_is_xfce():
        raise RuntimeError('O escritorio ativo nao e Xfce. Nenhuma alteracao.')
    if os.environ.get('XDG_SESSION_TYPE', 'x11').casefold() != 'x11':
        raise RuntimeError('Capturador atual e compativel somente com X11.')
    if not shutil.which('xfconf-query'):
        raise RuntimeError('xfconf-query ausente. Configure o atalho manualmente.')

def change_property(prop, current, desired):
    """Altera SOMENTE propriedade verificada, sem apagar a tecla de terceiros."""
    if desired is None:
        if current is not None:
            if prop==PROPERTY: remove_key()
            else: remove_key(prop)
    else:
        if prop==PROPERTY: set_key(desired,current is not None)
        else: set_key(desired,current is not None,prop)
    if get(prop)!=desired:
        raise RuntimeError('Xfce nao confirmou a atribuicao de '+prop)


def rebind(base, launcher, key, state, desired):
    """Trocar tecla ja atribuida mantendo diario de recuperacao durante as duas escritas."""
    old_prop=state.get('property')
    target_prop=shortcut_property(key)
    if (state.get('status')!='installed' or state.get('launcher')!=str(launcher)
            or state.get('command')!=desired or get(old_prop)!=desired):
        print('Atalho anterior nao corresponde ao registro. Nenhuma alteracao.')
        return False
    old_original=state.get('old_command')
    target_original=get(target_prop)
    if target_original==desired:
        print('Atalho novo ja tem o mesmo comando sem controle desta instalacao.')
        return False
    print('Tecla atual:',state.get('key','Print'),'-> nova tecla:',key)
    print('Novo atalho ocupado por:',repr(target_original))
    print('A antiga associacao sera restaurada; a nova substituida apos SIM.')
    if not yes('Confirma trocar a tecla do Print RC?'):
        return False
    if get(old_prop)!=desired or get(target_prop)!=target_original:
        print('Uma associacao mudou durante a confirmacao. Nada alterado.')
        return False
    recovery=dict(state)
    recovery['status']='moving'
    recovery['movement']={
        'target_property':target_prop,
        'target_old_command':target_original,
    }
    write_state(base,recovery)
    try:
        change_property(target_prop,target_original,desired)
        change_property(old_prop,desired,old_original)
        new_state=dict(state)
        new_state.update({'status':'installed','key':key,'property':target_prop,
                          'old_command':target_original,'created':target_original is None})
        write_state(base,new_state)
    except (OSError,subprocess.TimeoutExpired,RuntimeError) as exc:
        print('Troca nao concluida:',exc)
        print('Registro de recuperacao preservado. Use a opcao Liberar para desfazer.')
        return False
    print('Tecla',key,'cadastrada; atalho anterior restaurado.')
    return True


def install(base, launcher, key='Print'):
    check_environment()
    prop = shortcut_property(key)
    default_prop = '/commands/default/'+key
    previous_state = safe_state(base)
    desired = app_command(launcher)
    if previous_state is not None:
        if (previous_state.get('launcher') == str(launcher)
                and previous_state.get('status') == 'installed'):
            if previous_state.get('property') == prop and get(prop) == desired:
                print('Atalho Print RC do Xfce ja registrado corretamente.')
                return True
            if previous_state.get('property') != prop:
                return rebind(base,launcher,key,previous_state,desired)
        print('Existe registro anterior, inconsistente ou interrompido.')
        print('Nao sobrescrever atalhos de terceiros. Verifique antes de reinstalar.')
        return False
    old = get(prop)
    default = get(default_prop)
    print('\n===== INTEGRACAO PRINT RC NO XFCE =====')
    print('Gerenciador de atalhos: xfconf-query / ' + CHANNEL)
    print('Tecla fisica escolhida:',key)
    print('Propriedade externa:', prop)
    print('O Xfce pode gravar configuracoes em ~/.config/xfce4/xfconf/.')
    print('Comando Print RC:', desired)
    print('Atalho personalizado anterior:', repr(old))
    print('Atalho padrao do Xfce:', repr(default))
    if old is not None and old != desired:
        print('O uso personalizado anterior de Print sera substituido automaticamente.')
        print('O valor anterior ficara guardado para restauracao na desinstalacao.')
    if old == desired:
        print('Comando ja igual ao Print RC, mas nao registrado por esta instalacao.')
        print('Nao vou assumir atalho sem estado de recuperacao.')
        return False
    if not yes('Atribuir Print ao Print RC no Xfce, substituindo uso anterior?'):
        print('Cancelado: nenhuma associacao alterada.')
        return False
    if get(prop) != old:
        print('Outro aplicativo alterou a tecla durante a confirmacao. Cancelado.')
        return False
    state = {
        'backend':'xfce', 'property':prop, 'key':key, 'launcher':str(launcher),
        'command':desired, 'old_command':old, 'created':old is None,
        'status':'prepared'
    }
    write_state(base, state)
    try:
        if prop==PROPERTY:
            set_key(desired,old is not None)
        else:
            set_key(desired,old is not None,prop)
        if get(prop) != desired:
            raise RuntimeError('Xfce nao confirmou o novo valor.')
        state['status'] = 'installed'
        write_state(base, state)
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        print('Falha ao registrar atalho:', exc)
        print('Registro de recuperacao preservado em', base / STATE_FILE)
        return False
    print('Atalho registrado. Pressione',key,'para verificar no Xfce.')
    return True

def remove(base):
    state = safe_state(base)
    if state is None:
        print('Nenhum atalho Xfce criado pelo Print RC.')
        return True
    # Desinstalacao pode ocorrer em outra sessao; melhor preservar do que
    # mexer em atalhos XFCE quando estiver logado noutro desktop.
    check_environment()
    if state.get('status')=='moving':
        move=state.get('movement')
        if not isinstance(move,dict):
            print('Estado de troca inconsistente. Nao alterar atalhos.')
            return False
        target=move.get('target_property')
        try:
            if shortcut_property(target.rsplit('/',1)[-1])!=target:
                return False
            original_target=move.get('target_old_command')
            old_prop=state['property']
            old_original=state.get('old_command')
            desired=state['command']
            # Restaurar os dois atalhos apenas se ainda correspondem ao diario.
            for p,orig in ((target,original_target),(old_prop,old_original)):
                observed=get(p)
                if observed not in (desired,orig):
                    print('Outro programa alterou',p,'; recuperacao interrompida.')
                    return False
                if observed==desired:
                    change_property(p,desired,orig)
            (base / STATE_FILE).unlink()
            print('Troca interrompida recuperada; atribuicoes anteriores restauradas.')
            return True
        except (OSError,subprocess.TimeoutExpired,RuntimeError,ValueError,TypeError) as exc:
            print('Recuperacao incompleta:',exc)
            return False
    prop = state.get('property')
    current = get(prop)
    old = state.get('old_command')
    expected = state.get('command')
    if (state.get('launcher') is None or expected != app_command(state['launcher'])
            or (old is not None and not isinstance(old, str))):
        print('Registro Xfce inconsistente: nenhum atalho removido.')
        return False
    if current == old and state.get('status') == 'prepared':
        print('Integracao interrompida antes de alterar o atalho.')
    elif current != expected:
        print('A tecla Print foi alterada depois pelo usuario/desktop.')
        print('Atalho atual preservado; remocao automatica bloqueada.')
        return False
    else:
        print('Restaurando SOMENTE o atalho Xfce registrado pelo Print RC.')
        if old is None:
            if prop==PROPERTY: remove_key()
            else: remove_key(prop)
        else:
            if prop==PROPERTY: set_key(old,True)
            else: set_key(old,True,prop)
        if get(prop) != old:
            print('Nao foi possivel confirmar a restauracao. Estado interno mantido.')
            return False
    (base / STATE_FILE).unlink()
    print('Integracao Xfce removida/restaurada com sucesso.')
    return True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('install', 'remove', 'inspect'))
    parser.add_argument('--base', required=True, type=Path)
    parser.add_argument('--launcher', type=Path)
    parser.add_argument('--key', default='Print')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Nao execute como root.')
    base = args.base.resolve()
    try:
        if args.action == 'inspect':
            check_environment()
            state=safe_state(base)
            prop=state['property'] if isinstance(state,dict) else PROPERTY
            current=get(prop)
            default=get('/commands/default/'+prop.rsplit('/',1)[-1])
            print('Gerenciador: Xfce / xfconf-query')
            print('Tecla examinada:',prop.rsplit('/',1)[-1])
            print('Atalho personalizado:', current or '(nenhum)')
            print('Atalho padrao:', default or '(nenhum)')
            print('Tecla selecionada pelo Print RC:',state.get('key','Print') if isinstance(state,dict) else '(nao configurada)')
            if (isinstance(state,dict) and state.get('status')=='installed'
                    and state.get('command')==current):
                print('Print RC controla a associacao personalizada: SIM')
                print('Uso anterior salvo:',state.get('old_command') or '(sem atalho anterior)')
            else:
                print('Print RC controla a associacao personalizada: NAO ou indeterminado')
            print('Outros atalhos do gerenciador de janelas podem existir.')
            print('Ausencia aqui NAO confirma que a tecla esteja livre no X11.')
        elif args.action == 'install':
            if args.launcher is None:
                parser.error('--launcher obrigatorio.')
            if not install(base, args.launcher.resolve(),key=args.key):
                raise SystemExit(1)
        elif not remove(base):
            raise SystemExit(1)
    except (OSError, subprocess.TimeoutExpired, ValueError, RuntimeError) as exc:
        raise SystemExit('Print RC: integracao Xfce nao concluida: ' + str(exc))

if __name__ == '__main__':
    main()
