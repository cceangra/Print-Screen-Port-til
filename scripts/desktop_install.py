#!/usr/bin/env python3
"""Short-lived click launcher. Never download or execute a replacement program."""
import errno
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
sys.dont_write_bytecode=True
from print_rc_i18n import tr

ROOT=Path(__file__).resolve().parent.parent
DOWNLOAD_URL='https://github.com/cceangra/Print-Screen-Port-til/releases'

def dialog(message,question=False):
    """Ask before opening a browser; closing/cancelling never means Yes."""
    print(message,file=sys.stderr)
    choices=(
        ('zenity',['--question' if question else '--error','--no-markup','--title=Print RC','--text='+message]+
         (['--ok-label='+tr('desktop.download_button'),'--cancel-label='+tr('desktop.cancel_button'),'--default-cancel'] if question else [])),
        ('kdialog',['--title','Print RC','--yesno' if question else '--error',message]),
        ('/opt/trinity/bin/kdialog',['--title','Print RC','--yesno' if question else '--error',message]),
        ('xmessage',['-center','-buttons',tr('desktop.download_button')+':0,'+tr('desktop.cancel_button')+':1' if question else 'OK:0',
                     '-default',tr('desktop.cancel_button') if question else 'OK',message]))
    for program,arguments in choices:
        executable=shutil.which(program)
        if not executable:continue
        try:
            result=subprocess.run([executable,*arguments],check=False)
            # 1 is a declined/closed dialog. Other errors permit another toolkit.
            if result.returncode in (0,1):return question and result.returncode==0
        except OSError:continue
    return False

def offer_download():
    if not dialog(tr('desktop.source_download'),question=True):return 2
    for program,arguments in (('xdg-open',[]),('gio',['open']),
                              ('/opt/trinity/bin/kfmclient',['exec'])):
        executable=shutil.which(program)
        if not executable:continue
        try:
            result=subprocess.run([executable,*arguments,DOWNLOAD_URL],check=False)
            if result.returncode==0:return 2 # The app is still not installed.
        except OSError:continue
    dialog(tr('desktop.browser_failed',DOWNLOAD_URL))
    return 2

def main():
    if sys.argv[1:] not in ([],['--configure']):return 2
    settings=bool(sys.argv[1:])
    installer=ROOT/('Configurar' if settings else 'Instalar')
    try:
        mode=installer.lstat().st_mode
    except FileNotFoundError:
        # Source ZIPs contain the desktop entry, but none of the compiled ELFs.
        # Do not run shell setup or change preferences in this incomplete folder.
        return offer_download()
    except OSError as error:
        dialog(tr('desktop.folder_failed',str(error)))
        return 2
    try:
        if not stat.S_ISREG(mode):raise OSError(tr('shell.unsafe_path'))
        if not mode & stat.S_IXUSR:installer.chmod(stat.S_IMODE(mode)|stat.S_IXUSR)
        os.execv(str(installer),[str(installer)] if settings else [str(installer),'--install'])
    except OSError as error:
        if error.errno in (errno.ENOEXEC,errno.ENOENT):
            message=tr('desktop.runtime_failed')
        elif error.errno==errno.EACCES:
            message=tr('desktop.permission_failed')
        else:message=tr('desktop.folder_failed',str(error))
        dialog(message)
        return 2

if __name__=='__main__':raise SystemExit(main())
