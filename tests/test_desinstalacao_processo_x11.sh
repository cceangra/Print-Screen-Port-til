#!/usr/bin/env bash
# Executar em Xvfb. Testa encerramento seletivo de processo clipboard na desinstalacao.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
TEMP="$(mktemp -d)"
PID=''
cleanup() {
  if [[ -n "$PID" ]]; then kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; fi
  rm -rf -- "$TEMP"
}
trap cleanup EXIT
APP="$TEMP/Print-RC"
mkdir -p "$APP/config" "$APP/capturas"
cp -a "$ROOT/bin" "$ROOT/scripts" "$APP/"
cp "$ROOT/desinstalar.sh" "$ROOT/iniciar.sh" "$APP/"
printf 'PRINT-RC\n%s\n' "$APP" > "$APP/.print-rc-installation"
printf 'save_dir=%s\ncopy_clipboard=1\n' "$APP/capturas" > "$APP/config/opcoes.conf"
source "$ROOT/scripts/inventario.sh"
print_rc_criar_inventario "$APP"
"$APP/bin/print-rc" > "$TEMP/run.log" 2>&1 &
PID=$!
sleep 0.8
xdotool mousemove --sync 458 35 click 1
for i in {1..100}; do
  if [[ -n "$(find "$APP/capturas" -maxdepth 1 -name '*.png' -print -quit)" ]]; then break; fi
  sleep 0.1
done
test -n "$(find "$APP/capturas" -maxdepth 1 -name '*.png' -print -quit)"
kill -0 "$PID"
echo '[PROC] Desinstalar: encerrar exclusivamente Print RC em clipboard'
printf 'DESINSTALAR\n' | bash "$APP/desinstalar.sh"
wait "$PID" 2>/dev/null || true
PID=''
test ! -e "$APP/bin/print-rc"
test -n "$(find "$APP/capturas" -maxdepth 1 -name '*.png' -print -quit)"
echo 'OK: processo Print RC encerrado, executavel removido, imagens preservadas.'
