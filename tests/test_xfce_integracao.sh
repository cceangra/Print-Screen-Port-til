#!/usr/bin/env bash
# Fluxo integrado Xfce, simulando o xfconf-query em uma pasta temporaria.
# NUNCA utiliza o desktop, atalhos ou HOME reais.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
export TEST_XFCONF_STATE="$TMP/xfconf.json"
mkdir -p "$HOME" "$TMP/bin" "$TMP/Pasta com espacos/Print-RC"
cat > "$TMP/bin/xfconf-query" <<'PY'
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
state=Path(os.environ['TEST_XFCONF_STATE'])
data=json.loads(state.read_text()) if state.exists() else {}
args=sys.argv[1:]
if '-c' not in args or args[args.index('-c')+1]!='xfce4-keyboard-shortcuts':
    sys.exit(2)
if '-l' in args:
    for path in sorted(data):
        print(path)
    sys.exit(0)
if '-p' not in args:
    sys.exit(2)
prop=args[args.index('-p')+1]
if '-s' in args:
    data[prop]=args[args.index('-s')+1]
    state.write_text(json.dumps(data))
elif '-r' in args:
    data.pop(prop,None)
    state.write_text(json.dumps(data))
else:
    if prop not in data: sys.exit(1)
    print(data[prop])
PY
chmod +x "$TMP/bin/xfconf-query"
export PATH="$TMP/bin:$PATH"

APP="$TMP/Pasta com espacos/Print-RC"
cp -a "$ROOT/instalar.sh" "$ROOT/configurar.sh" "$ROOT/iniciar.sh" \
    "$ROOT/desinstalar.sh" "$ROOT/bin" "$ROOT/src" "$APP/"
mkdir -p "$APP/scripts"
# Nunca distribuir __pycache__ ou qualquer artefato gerado na CI.
cp -a "$ROOT/scripts/"*.py "$ROOT/scripts/inventario.sh" "$APP/scripts/"
# Atalho preexistente de outro aplicativo (deve ser restaurado ao remover).
python3 - <<'PY'
from pathlib import Path
import os, json
Path(os.environ['TEST_XFCONF_STATE']).write_text(json.dumps({
    '/commands/custom/Print':'xfce4-screenshooter -f',
    '/commands/default/Print':'xfce4-screenshooter'
}))
PY
ZIP="$TMP/arquivo-baixado.zip"
printf 'ZIP NAO APAGAR\n' > "$ZIP"
IMAGENS="$TMP/Minhas imagens"
mkdir -p "$IMAGENS"
printf 'IMAGEM ANTIGA\n' > "$IMAGENS/antiga.png"
# Destino atual [Enter]; imagens externas [caminho+s]; clipboard [Enter];
# salvar preferencias [s]; integrar Xfce [s]; substituir Print [s]; confirmar [s].
printf '\n%s\ns\n\ns\ns\ns\ns\n' "$IMAGENS" | bash "$APP/instalar.sh"
test -f "$APP/config/atalho-xfce.json"
test -f "$APP/config/arquivos-instalados.sha256"
python3 - <<'PY'
from pathlib import Path
import os, json
data=json.loads(Path(os.environ['TEST_XFCONF_STATE']).read_text())
cmd=data['/commands/custom/Print']
assert cmd.startswith('/bin/bash ')
assert 'iniciar.sh' in cmd
assert data['/commands/default/Print']=='xfce4-screenshooter'
PY
printf 'DESINSTALAR\n' | bash "$APP/desinstalar.sh"
if [[ -e "$APP" ]]; then
    echo 'TESTE XFCE: arquivos nao removidos pela desinstalacao:'
    find "$APP" -mindepth 1 -printf '%y %p\n'
    exit 1
fi
test "$(cat "$ZIP")" = 'ZIP NAO APAGAR'
test "$(cat "$IMAGENS/antiga.png")" = 'IMAGEM ANTIGA'
python3 - <<'PY'
from pathlib import Path
import os, json
data=json.loads(Path(os.environ['TEST_XFCONF_STATE']).read_text())
assert data['/commands/custom/Print']=='xfce4-screenshooter -f'
assert data['/commands/default/Print']=='xfce4-screenshooter'
PY
echo 'OK: Xfce simulado restaurou tecla anterior, apagou pasta do app, preservou ZIP e fotos.'
