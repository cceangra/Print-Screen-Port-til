#!/usr/bin/env bash
# Ensaio X11 real em Xvfb, sem observar teclado real de nenhuma pessoa.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
BIN="$ROOT/bin/print-rc"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

echo '[1] Capturar Print realmente enviado pelo servidor X11 virtual'
"$BIN" --detectar-print > "$TMP/print.txt" 2> "$TMP/print.err" &
PID=$!
sleep 0.5
xdotool key Print
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/print.txt"

echo '[2] Tecla diferente nao pode virar Print; aceitar Print em seguida'
"$BIN" --detectar-print > "$TMP/diferente.txt" 2> "$TMP/diferente.err" &
PID=$!
sleep 0.5
xdotool key F12
sleep 0.2
xdotool key Print
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/diferente.txt"
grep -F 'tecla lida: F12' "$TMP/diferente.err"

echo '[3] Cancelar com Esc sem emitir tecla nem manter keyboard grab'
"$BIN" --detectar-print > "$TMP/esc.txt" 2> "$TMP/esc.err" &
PID=$!
sleep 0.5
xdotool key Escape
if wait "$PID"; then
    echo 'ERRO: Esc deveria cancelar com retorno de erro.'
    exit 1
fi
test ! -s "$TMP/esc.txt"
grep -F 'cancelada com Esc' "$TMP/esc.err"

echo '[4] Tecla Print pode ser lida novamente apos cancelamento'
"$BIN" --detectar-print > "$TMP/retorno.txt" 2> "$TMP/retorno.err" &
PID=$!
sleep 0.5
xdotool key Print
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/retorno.txt"
echo 'OK: deteccao da tecla fisica simulada em X11, Esc, recuperacao e sem servico residente.'
