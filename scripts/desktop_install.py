#!/usr/bin/env python3
"""Short-lived desktop-entry bootstrap; writes only the installer's execute bit."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
sys.dont_write_bytecode=True
from print_rc_i18n import tr

ROOT=Path(__file__).resolve().parent.parent

def main():
    if sys.argv[1:] not in ([],['--configure']):return 2
    settings=bool(sys.argv[1:])
    installer=ROOT/('Configurar' if settings else 'Instalar')
    try:
        mode=installer.lstat().st_mode
        if not stat.S_ISREG(mode):raise OSError(tr('shell.unsafe_path'))
        if not mode & stat.S_IXUSR:installer.chmod(stat.S_IMODE(mode)|stat.S_IXUSR)
        os.execv(str(installer),[str(installer)] if settings else [str(installer),'--install'])
    except OSError as error:
        message=(tr('native.entry_exec_failed') % str(error))+'\n'+tr('shell.012')
        print(message,file=sys.stderr)
        for program,arguments in (
            ('zenity',['--error','--title=Print RC','--text='+message]),
            ('kdialog',['--title','Print RC','--error',message]),
            ('/opt/trinity/bin/kdialog',['--title','Print RC','--error',message]),
            ('xmessage',['-center','-buttons','OK:0',message])):
            executable=shutil.which(program)
            if not executable:continue
            try:
                subprocess.run([executable,*arguments],check=False)
                break
            except OSError:continue
        return 2

if __name__=='__main__':raise SystemExit(main())
