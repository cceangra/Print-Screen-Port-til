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

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from print_rc_i18n import tr, affirmative, localize_argparse

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
        raise ValueError(tr('desktop.164')+str(key))
    return '/commands/custom/'+key
STATE_FILE = 'config/atalho-xfce.json'
NAME = tr('desktop.001')

def desktop_is_xfce():
    return 'xfce' in os.environ.get('XDG_CURRENT_DESKTOP', '').casefold()

def app_command(launcher):
    return '/bin/bash ' + shlex.quote(str(launcher))

def call(*args):
    executable = shutil.which('xfconf-query')
    if not executable:
        raise RuntimeError(tr('desktop.137'))
    result = subprocess.run([executable, '-c', CHANNEL, '-p', *args],
                            capture_output=True, text=True, timeout=8, check=False)
    return result

def get(prop=PROPERTY):
    # Consultar a lista, e nao o texto de erros traduzidos por locale.
    executable = shutil.which('xfconf-query')
    if not executable:
        raise RuntimeError(tr('desktop.138'))
    listed = subprocess.run([executable, '-c', CHANNEL, '-l'],
                            capture_output=True, text=True, timeout=8, check=False)
    if listed.returncode:
        raise RuntimeError(tr('desktop.165') + listed.stderr.strip())
    if prop not in listed.stdout.splitlines():
        return None
    result = call(prop)
    if result.returncode:
        raise RuntimeError(tr('desktop.166') + result.stderr.strip())
    return result.stdout.strip()

def set_key(command, existed, prop=PROPERTY):
    args = [prop]
    if not existed:
        args += ['-n', '-t', 'string']
    args += ['-s', command]
    result = call(*args)
    if result.returncode:
        raise RuntimeError(tr('desktop.167') + result.stderr.strip())

def remove_key(prop=PROPERTY):
    result = call(prop, '-r')
    if result.returncode:
        raise RuntimeError(tr('desktop.168') + result.stderr.strip())

def safe_state(base):
    path = base / STATE_FILE
    if path.is_symlink():
        raise RuntimeError(tr('desktop.139'))
    if not path.exists():
        return None
    if not path.is_file():
        raise RuntimeError(tr('desktop.140'))
    state = json.loads(path.read_text(encoding='utf-8'))
    if (not isinstance(state, dict) or state.get('backend') != 'xfce'
            or not isinstance(state.get('key','Print'),str)
            or state.get('property') != shortcut_property(state.get('key','Print'))):
        raise RuntimeError(tr('desktop.141'))
    return state

def write_state(base, data):
    path = base / STATE_FILE
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise RuntimeError(tr('desktop.142'))
    if not path.parent.is_dir() or path.parent.is_symlink():
        raise RuntimeError(tr('desktop.143'))
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
        return input(question + tr('common.confirm')).strip().casefold() in ('s', 'sim', 'y', 'yes')
    except EOFError:
        return False

def check_environment():
    if not desktop_is_xfce():
        raise RuntimeError(tr('desktop.144'))
    if os.environ.get('XDG_SESSION_TYPE', 'x11').casefold() != 'x11':
        raise RuntimeError(tr('desktop.145'))
    if not shutil.which('xfconf-query'):
        raise RuntimeError(tr('desktop.146'))

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
        raise RuntimeError(tr('desktop.169')+prop)


def rebind(base, launcher, key, state, desired):
    """Trocar tecla ja atribuida mantendo diario de recuperacao durante as duas escritas."""
    old_prop=state.get('property')
    target_prop=shortcut_property(key)
    if (state.get('status')!='installed' or state.get('launcher')!=str(launcher)
            or state.get('command')!=desired or get(old_prop)!=desired):
        print(tr('desktop.147'))
        return False
    old_original=state.get('old_command')
    target_original=get(target_prop)
    if target_original==desired:
        print(tr('desktop.148'))
        return False
    print(tr('desktop.122'),state.get('key','Print'),tr('desktop.123'),key)
    print(tr('desktop.124'),repr(target_original))
    print(tr('desktop.125'))
    if not yes(tr('desktop.149')):
        return False
    if get(old_prop)!=desired or get(target_prop)!=target_original:
        print(tr('desktop.150'))
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
        print(tr('desktop.170'),exc)
        print(tr('desktop.171'))
        return False
    print(tr('desktop.key'),key,tr('desktop.126'))
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
                print(tr('desktop.186'))
                return True
            if previous_state.get('property') != prop:
                return rebind(base,launcher,key,previous_state,desired)
        print(tr('desktop.151'))
        print(tr('desktop.152'))
        return False
    old = get(prop)
    default = get(default_prop)
    print(tr('desktop.127'))
    print(tr('desktop.153') + CHANNEL)
    print(tr('desktop.128'),key)
    print(tr('desktop.129'), prop)
    print(tr('desktop.130'))
    print(tr('desktop.131'), desired)
    print(tr('desktop.132'), repr(old))
    print(tr('desktop.133'), repr(default))
    if old is not None and old != desired:
        print(tr('desktop.154'))
        print(tr('desktop.155'))
    if old == desired:
        print(tr('desktop.156'))
        print(tr('desktop.157'))
        return False
    if not yes(tr('desktop.158')):
        print(tr('desktop.159'))
        return False
    if get(prop) != old:
        print(tr('desktop.160'))
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
            raise RuntimeError(tr('desktop.172'))
        state['status'] = 'installed'
        write_state(base, state)
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        print(tr('desktop.173'), exc)
        print(tr('desktop.174'), base / STATE_FILE)
        return False
    print(tr('desktop.134'),key,tr('desktop.135'))
    return True

def remove(base):
    state = safe_state(base)
    if state is None:
        print(tr('desktop.161'))
        return True
    # Desinstalacao pode ocorrer em outra sessao; melhor preservar do que
    # mexer em atalhos XFCE quando estiver logado noutro desktop.
    check_environment()
    if state.get('status')=='moving':
        move=state.get('movement')
        if not isinstance(move,dict):
            print(tr('desktop.175'))
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
                    print(tr('desktop.194'),p,tr('desktop.195'))
                    return False
                if observed==desired:
                    change_property(p,desired,orig)
            (base / STATE_FILE).unlink()
            print(tr('desktop.176'))
            return True
        except (OSError,subprocess.TimeoutExpired,RuntimeError,ValueError,TypeError) as exc:
            print(tr('desktop.187'),exc)
            return False
    prop = state.get('property')
    current = get(prop)
    old = state.get('old_command')
    expected = state.get('command')
    if (state.get('launcher') is None or expected != app_command(state['launcher'])
            or (old is not None and not isinstance(old, str))):
        print(tr('desktop.162'))
        return False
    if current == old and state.get('status') == 'prepared':
        print(tr('desktop.163'))
    elif current != expected:
        print(tr('desktop.177'))
        print(tr('desktop.178'))
        return False
    else:
        print(tr('desktop.179'))
        if old is None:
            if prop==PROPERTY: remove_key()
            else: remove_key(prop)
        else:
            if prop==PROPERTY: set_key(old,True)
            else: set_key(old,True,prop)
        if get(prop) != old:
            print(tr('desktop.188'))
            return False
    (base / STATE_FILE).unlink()
    print(tr('desktop.136'))
    return True

def main():
    localize_argparse()
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('install', 'remove', 'inspect'))
    parser.add_argument('--base', required=True, type=Path)
    parser.add_argument('--launcher', type=Path)
    parser.add_argument('--key', default='Print')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error(tr('desktop.093'))
    base = args.base.resolve()
    try:
        if args.action == 'inspect':
            check_environment()
            state=safe_state(base)
            prop=state['property'] if isinstance(state,dict) else PROPERTY
            current=get(prop)
            default=get('/commands/default/'+prop.rsplit('/',1)[-1])
            print(tr('desktop.manager_xfce'))
            print(tr('desktop.180'),prop.rsplit('/',1)[-1])
            print(tr('desktop.181'), current or tr('common.none'))
            print(tr('desktop.182'), default or tr('common.none'))
            print(tr('desktop.183'),state.get('key','Print') if isinstance(state,dict) else tr('desktop.189'))
            if (isinstance(state,dict) and state.get('status')=='installed'
                    and state.get('command')==current):
                print(tr('desktop.190'))
                print(tr('desktop.191'),state.get('old_command') or tr('desktop.196'))
            else:
                print(tr('desktop.192'))
            print(tr('desktop.184'))
            print(tr('desktop.185'))
        elif args.action == 'install':
            if args.launcher is None:
                parser.error(tr('desktop.197'))
            if not install(base, args.launcher.resolve(),key=args.key):
                raise SystemExit(1)
        elif not remove(base):
            raise SystemExit(1)
    except (OSError, subprocess.TimeoutExpired, ValueError, RuntimeError) as exc:
        raise SystemExit(tr('desktop.193') + str(exc))

if __name__ == '__main__':
    main()
