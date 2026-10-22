#!/usr/bin/env python3
"""Explicit repair of an owned installation moved to another directory."""
import argparse
import json
import os
from pathlib import Path
import shlex
import sys
sys.dont_write_bytecode=True
from print_rc_i18n import tr, affirmative, localize_argparse
from lifecycle import safe, atomic, inventory, digest, track_generated, record, METADATA

def owned_file(base,relative,values):
    path=safe(base,relative)
    if not path.is_file() or values.get(relative)!=digest(path):raise ValueError(tr('lifecycle.modified'))
    return path

def relocate(base,confirm=None):
    values=inventory(base)
    marker=owned_file(base,'.print-rc-installation',values)
    lines=marker.read_text(encoding='utf-8').splitlines()
    if len(lines)!=2 or lines[0]!='PRINT-RC' or not Path(lines[1]).is_absolute():raise ValueError(tr('lifecycle.inventory_invalid'))
    old=Path(lines[1]);new=base
    if old==new:print(tr('lifecycle.no_move'));return True
    if METADATA in values:owned_file(base,METADATA,values)
    config=owned_file(base,'config/opcoes.conf',values)
    settings=config.read_text(encoding='utf-8')
    old_launcher=old/'iniciar.sh';new_launcher=new/'iniciar.sh'
    jobs=[]
    xfce=safe(base,'config/atalho-xfce.json');trinity=safe(base,'config/atalho-state.json')
    if xfce.is_file():
        import atalho_xfce as adapter
        adapter.check_environment();state=adapter.safe_state(base)
        if state.get('status')!='installed' or state.get('launcher')!=str(old_launcher) or state.get('command')!=adapter.app_command(old_launcher):raise ValueError(tr('lifecycle.modified'))
        if adapter.get(state['property'])!=state['command']:raise ValueError(tr('lifecycle.concurrent'))
        jobs.append(('xfce',adapter,state))
    if trinity.is_file():
        import atalho as adapter
        adapter.check_app_paths(base);state=json.loads(trinity.read_text(encoding='utf-8'))
        if state.get('status')!='installed' or state.get('launcher')!=str(old_launcher) or state.get('file')!=str(adapter.FILE):raise ValueError(tr('lifecycle.modified'))
        original=adapter.safe_current_text();sections=adapter.parse(original);group=state.get('group','')
        action=sections.get(group+'Actions0','')
        if adapter.get_value(sections.get(group,''),'Name')!=adapter.NAME or adapter.get_value(action,'CommandURL') not in (adapter.command_for_launcher(old_launcher),adapter.legacy_command_for_launcher(old_launcher)):
            raise ValueError(tr('lifecycle.concurrent'))
        jobs.append(('trinity',adapter,state))
    print(tr('lifecycle.relocate_preview',str(old),str(new)))
    if confirm is None:confirm=lambda:affirmative(input(tr('lifecycle.relocate_question')+tr('common.confirm')))
    if not confirm():print(tr('lifecycle.cancelled'));return False
    for backend,adapter,state in jobs:
        updated=dict(state)
        updated.update(status='relocating',launcher=str(new_launcher),relocation={'old_launcher':str(old_launcher)})
        if backend=='xfce':
            prop=state['property'];expected=adapter.app_command(old_launcher);desired=adapter.app_command(new_launcher)
            if adapter.get(prop)!=expected:raise ValueError(tr('lifecycle.concurrent'))
            updated['command']=desired;adapter.write_state(base,updated)
            adapter.change_property(prop,expected,desired)
            updated.pop('relocation');updated['status']='installed';adapter.write_state(base,updated)
        else:
            original=adapter.safe_current_text();sections=adapter.parse(original);section=state['group']+'Actions0'
            current=adapter.get_value(sections.get(section,''),'CommandURL')
            if current not in (adapter.command_for_launcher(old_launcher),adapter.legacy_command_for_launcher(old_launcher)):
                raise ValueError(tr('lifecycle.concurrent'))
            updated_text=adapter.replace_block(original,section,adapter.set_value(sections[section],'CommandURL',adapter.command_for_launcher(new_launcher)))
            if not adapter.check_unchanged(original):raise ValueError(tr('lifecycle.concurrent'))
            atomic(trinity,json.dumps(updated,ensure_ascii=False,indent=2)+'\n')
            if not adapter.check_unchanged(original):raise ValueError(tr('lifecycle.concurrent'))
            adapter.write_atomic(adapter.FILE,updated_text)
            updated.pop('relocation');updated['status']='installed';atomic(trinity,json.dumps(updated,ensure_ascii=False,indent=2)+'\n')
            adapter.reload_trinity_shortcuts()
    # Change only app-internal capture paths; an external destination stays unchanged.
    output=[];relative=None
    for line in settings.splitlines():
        if line.startswith('save_dir=') and line[9:].startswith(str(old)+'/'):
            relative=line[9:][len(str(old))+1:]
            safe(base,relative)
            line='save_dir='+str(base/relative)
        if not line.startswith('save_dir_relative='):output.append(line)
    previous=dict(line.split('=',1) for line in settings.splitlines() if '=' in line).get('save_dir_relative')
    relative=relative or previous
    if relative:output.append('save_dir_relative='+relative)
    owned_file(base,'config/opcoes.conf',values)
    atomic(config,'\n'.join(output)+'\n');track_generated(base,'config/opcoes.conf')
    # Only now move the ownership marker; incomplete external changes retain recovery state.
    owned_file(base,'.print-rc-installation',values)
    atomic(marker,'PRINT-RC\n'+str(base)+'\n');track_generated(base,'.print-rc-installation')
    record(base,'pending')
    print(tr('lifecycle.relocated'));return True

def main():
    localize_argparse();p=argparse.ArgumentParser(description=tr('lifecycle.relocate_description'))
    p.add_argument('--base',type=Path,required=True,help=tr('cli.base'));args=p.parse_args()
    try:return 0 if relocate(args.base.resolve()) else 1
    except (OSError,ValueError,RuntimeError,EOFError) as error:
        print(tr('lifecycle.failed',str(error)));return 2

if __name__=='__main__':raise SystemExit(main())
