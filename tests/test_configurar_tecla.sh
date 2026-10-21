#!/usr/bin/env bash
# Integra configurar-tecla.sh e Trinity isolados, sem tocar no HOME real.
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
export XDG_CURRENT_DESKTOP=Trinity XDG_SESSION_TYPE=x11
export TEST_MODE=retry TEST_COUNT="$TMP/contagem"
mkdir -p "$HOME/.trinity/share/config"
APP="$TMP/Print RC/Print-RC"
mkdir -p "$APP/bin" "$APP/scripts" "$APP/config"
cp -a "$ROOT/i18n" "$APP/"
cp "$ROOT/scripts/i18n.sh" "$ROOT/scripts/messages.bash" "$ROOT/scripts/print_rc_i18n.py" "$APP/scripts/"
cp -- "$ROOT/configurar-tecla.sh" "$ROOT/iniciar.sh" "$APP/"
cp -- "$ROOT/scripts/atalho.py" "$APP/scripts/"
printf 'FOTO PESSOAL\n' > "$APP/minha-foto.png"
cat > "$APP/bin/print-rc" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  --verificar-tecla)
      echo 'PRINT_RC_GRAB=ocupada'
      exit 6
      ;;
  --detectar-print)
      case "$TEST_MODE" in
        retry)
          printf 'tentativa\n' >> "$TEST_COUNT"
          if [[ "$(wc -l < "$TEST_COUNT")" == 1 ]]; then
            exit 4
          fi
          echo 'PRINT_RC_KEY=Print' ;;
        sysreq) echo 'PRINT_RC_KEY=Sys_Req' ;;
        escape) exit 5 ;;
        never) exit 4 ;;
      esac ;;
  *) exit 0 ;;
esac
SH
chmod +x "$APP/bin/print-rc"
K="$HOME/.trinity/share/config/khotkeysrc"
cat > "$K" <<'CFG'
[Data]
DataCount=1

[Data_1]
Name=Outro capturador
Type=COMMAND_URL_SHORTCUT_ACTION_DATA
Enabled=true

[Data_1Actions0]
CommandURL=outro-app
Type=COMMAND_URL

[Data_1Triggers0]
Key=Print
Type=SHORTCUT

[DadosPessoais]
NaoApagar=sim
CFG
echo '[1] Status apresenta conflito, sonda e nao escreve nada'
cp -- "$K" "$TMP/antes"
bash "$APP/configurar-tecla.sh" --status > "$TMP/status.txt"
grep -F 'Outro capturador' "$TMP/status.txt"
grep -F 'PRINT_RC_GRAB=ocupada' "$TMP/status.txt"
cmp "$K" "$TMP/antes"

echo '[2] Timeout, SIM, Print, SIM: registra sem reinstalar'
printf '2\ns\ns\n0\n' | bash "$APP/configurar-tecla.sh" > "$TMP/install.txt" 2>&1
test "$(wc -l < "$TEST_COUNT")" -eq 2
grep -F 'Tentar novamente?' "$TMP/install.txt"
python3 -B - "$APP" "$K" <<'PY'
import json,sys
from pathlib import Path
app=Path(sys.argv[1]); f=Path(sys.argv[2])
state=json.loads((app/'config/atalho-state.json').read_text())
assert state['status']=='installed' and state['key']=='Print'
text=f.read_text()
assert 'Key=Print' in text and 'Name=Print RC' in text
assert 'Key=\nType=SHORTCUT' in text
assert 'NaoApagar=sim' in text
assert (app/'minha-foto.png').read_text()=='FOTO PESSOAL\n'
PY

echo '[3] Reassociar ao Sys_Req com confirmacao unica, mantendo backup'
export TEST_MODE=sysreq
printf '2\ns\n0\n' | bash "$APP/configurar-tecla.sh" > "$TMP/rebind.txt" 2>&1
python3 -B - "$APP" "$K" <<'PY'
import json,sys
from pathlib import Path
app=Path(sys.argv[1]); f=Path(sys.argv[2])
s=json.loads((app/'config/atalho-state.json').read_text())
assert s['key']=='Sys_Req'
assert 'Key=Sys_Req' in f.read_text()
assert len(s['conflicts'])==1
PY

echo '[4] Liberar Print RC; tecla do outro app restaurada'
printf 's\n' | bash "$APP/configurar-tecla.sh" --liberar > "$TMP/remove.txt" 2>&1
test ! -f "$APP/config/atalho-state.json"
grep -F 'Key=Print' "$K"
grep -F 'Outro capturador' "$K"
grep -F 'NaoApagar=sim' "$K"
test "$(cat "$APP/minha-foto.png")" = 'FOTO PESSOAL'

echo '[5] Esc nunca registra ou modifica o arquivo'
export TEST_MODE=escape
cp "$K" "$TMP/antes-esc"
if printf '2\n' | bash "$APP/configurar-tecla.sh" --configurar > "$TMP/esc.txt" 2>&1; then
    echo 'ERRO: Esc nao foi reportado como cancelamento.'
    exit 1
fi
cmp "$K" "$TMP/antes-esc"
test ! -e "$APP/config/atalho-state.json"

echo '[6] Timeout seguido de NAO nao altera nenhum atalho'
export TEST_MODE=never
if printf 'n\n' | bash "$APP/configurar-tecla.sh" --configurar > "$TMP/never.txt" 2>&1; then
    echo 'ERRO: timeout deveria retornar codigo de cancelamento.'
    exit 1
fi
cmp "$K" "$TMP/antes-esc"
test ! -e "$APP/config/atalho-state.json"
echo 'OK: diagnostico, associacao, retry, rebind, liberar, Esc e NAO.'
