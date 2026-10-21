#!/usr/bin/env python3
"""Atalho Print no Xfce/X11 via xfconf-query. Sem pacotes, daemon ou sudo."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

CHANNEL = 'xfce4-keyboard-shortcuts'
PROPERTY = '/commands/custom/Print'
DEFAULT = '/commands/default/Print'
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
    result = call(prop)
    if result.returncode:
        # Somente status sem texto e interpretado como propriedade ausente.
        # Nao confundir falhas do servico xfconfd com ausencia do registro.
        message = (result.stderr or result.stdout).casefold()
        if ('does not exist' in message or 'does not exist on channel' in message
                or 'doesn\'t exist' in message):
            return None
        raise RuntimeError('Erro ao consultar atalho Xfce: ' + (result.stderr or result.stdout).strip())
    return result.stdout.strip()

def set_key(command, existed):
    args = [PROPERTY]
    if not existed:
        args += ['-n', '-t', 'string']
    args += ['-s', command]
    result = call(*args)
    if result.returncode:
        raise RuntimeError('Xfce recusou configuracao: ' + result.stderr.strip())

def remove_key():
    result = call(PROPERTY, '-r')
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
            or state.get('property') != PROPERTY):
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

def install(base, launcher):
    check_environment()
    previous_state = safe_state(base)
    desired = app_command(launcher)
    if previous_state is not None:
        if (previous_state.get('launcher') == str(launcher)
                and previous_state.get('status') == 'installed'
                and get() == desired):
            print('Atalho Print RC do Xfce ja registrado corretamente.')
            return True
        print('Existe registro anterior, inconsistente ou interrompido.')
        print('Nao sobrescrever atalhos de terceiros. Verifique antes de reinstalar.')
        return False
    old = get()
    default = get(DEFAULT)
    print('\n===== INTEGRACAO PRINT RC NO XFCE =====')
    print('Gerenciador de atalhos: xfconf-query / ' + CHANNEL)
    print('Propriedade externa:', PROPERTY)
    print('O Xfce pode gravar configuracoes em ~/.config/xfce4/xfconf/.')
    print('Comando Print RC:', desired)
    print('Atalho personalizado anterior:', repr(old))
    print('Atalho padrao do Xfce:', repr(default))
    if old is not None and old != desired:
        if not yes('Substituir SOMENTE o atalho personalizado Print, restaurando depois?'):
            print('Atalho antigo preservado.')
            return False
    if old == desired:
        print('Comando ja igual ao Print RC, mas nao registrado por esta instalacao.')
        print('Nao vou assumir a propriedade de atalho criado por outra pessoa.')
        return False
    if not yes('Cadastrar tecla Print no Xfce para executar Print RC?'):
        print('Sem alteracoes.')
        return False
    if get() != old:
        print('Outro aplicativo alterou Print durante a confirmacao. Cancelado.')
        return False
    state = {
        'backend':'xfce', 'property':PROPERTY, 'launcher':str(launcher),
        'command':desired, 'old_command':old, 'created':old is None,
        'status':'prepared'
    }
    write_state(base, state)
    try:
        set_key(desired, old is not None)
        if get() != desired:
            raise RuntimeError('Xfce nao confirmou o novo valor.')
        state['status'] = 'installed'
        write_state(base, state)
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        print('Falha ao registrar atalho:', exc)
        print('Registro de recuperacao preservado em', base / STATE_FILE)
        return False
    print('Atalho registrado. Pressione Print para verificar no Xfce.')
    return True

def remove(base):
    state = safe_state(base)
    if state is None:
        print('Nenhum atalho Xfce criado pelo Print RC.')
        return True
    # Desinstalacao pode ocorrer em outra sessao; melhor preservar do que
    # mexer em atalhos XFCE quando estiver logado noutro desktop.
    check_environment()
    current = get()
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
            remove_key()
        else:
            set_key(old, True)
        if get() != old:
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
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Nao execute como root.')
    base = args.base.resolve()
    try:
        if args.action == 'inspect':
            check_environment()
            print('Xfce Print custom:', get(), 'padrao:', get(DEFAULT))
        elif args.action == 'install':
            if args.launcher is None:
                parser.error('--launcher obrigatorio.')
            if not install(base, args.launcher.resolve()):
                raise SystemExit(1)
        elif not remove(base):
            raise SystemExit(1)
    except (OSError, subprocess.TimeoutExpired, ValueError, RuntimeError) as exc:
        raise SystemExit('Print RC: integracao Xfce nao concluida: ' + str(exc))

if __name__ == '__main__':
    main()
