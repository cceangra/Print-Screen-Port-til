#!/usr/bin/env bash
# Isolated CI terminal test. Never run against a user's live desktop/session.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 -B - "$ROOT" <<'PY'
import os,sys,subprocess,tempfile,shutil
from pathlib import Path
root=Path(sys.argv[1]);sakura=shutil.which('sakura');assert sakura
with tempfile.TemporaryDirectory() as temp:
    base=Path(temp);app=base/"Print ç ('quotes') $(literal)";app.mkdir()
    (app/'scripts').mkdir();(app/'commands').mkdir();(app/'home').mkdir()
    shutil.copy2(root/'Instalar',app/'Instalar')
    (app/'scripts/terminal-action.sh').write_text('exec /bin/bash "$@"\n')
    (app/'instalar.sh').write_text('printf "%s\\n" "$@" > "$PRC_SAKURA_RESULT"\n')
    (app/'commands/sakura').symlink_to(sakura)
    expected="literal $(not-a-command) with 'quotes' and \"double quotes\""
    for mode in ('direct','default-terminal-symlink'):
        link=app/'commands/x-terminal-emulator'
        if mode=='default-terminal-symlink':link.symlink_to(sakura)
        output=app/(mode+'.result')
        env={**os.environ,'PATH':str(app/'commands'),'HOME':str(app/'home'),
             'XDG_CONFIG_HOME':str(app/'home/config'),'XDG_CACHE_HOME':str(app/'home/cache'),
             'PRC_SAKURA_RESULT':str(output)}
        result=subprocess.run([str(app/'Instalar'),expected],env=env,stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=18)
        assert result.returncode==0,(mode,result.returncode,result.stderr)
        assert output.read_text()==expected+'\n',(mode,output.read_text())
        print('PASS: real Sakura,',mode,'preserves path and literal arguments')
PY
