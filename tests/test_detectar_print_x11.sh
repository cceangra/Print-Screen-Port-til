#!/usr/bin/env bash
# Ensaio X11 real em Xvfb, sem observar teclado real de nenhuma pessoa.
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
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
grep -F 'Voce tem ate 60 segundos' "$TMP/print.err"

echo '[2] Qualquer tecla: F12 deve ser registrada imediatamente'
"$BIN" --detectar-print > "$TMP/diferente.txt" 2> "$TMP/diferente.err" &
PID=$!
sleep 0.5
xdotool key F12
wait "$PID"
grep -Fx 'PRINT_RC_KEY=F12' "$TMP/diferente.txt"
grep -F 'tecla escolhida: F12' "$TMP/diferente.err"

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
echo '[5] Esgotar a espera em teste acelerado, confirmar codigo 4 e liberar grab'
# Somente este executavel de teste usa um segundo; o ZIP real usa 60 segundos.
g++ -std=c++17 -O1 -DPRINT_RC_DETECT_SECONDS=1 \
    "$ROOT/src/main.cpp" -o "$TMP/print-rc-timeout" \
    $(pkg-config --cflags --libs x11 libpng)
"$TMP/print-rc-timeout" --detectar-print > "$TMP/timeout.txt" 2> "$TMP/timeout.err" &
PID=$!
CODIGO=0
wait "$PID" || CODIGO=$?
test "$CODIGO" -eq 4
test ! -s "$TMP/timeout.txt"
grep -F '1 segundos esgotados' "$TMP/timeout.err"

echo '[6] Detector normal ainda captura Print apos timeout (grab liberado)'
"$BIN" --detectar-print > "$TMP/apos-timeout.txt" 2> "$TMP/apos-timeout.err" &
PID=$!
sleep 0.5
xdotool key Print
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/apos-timeout.txt"
echo 'OK: Print fisico simulado, prazo de 60 s no binario final, timeout testado, cancelamento e liberacao do teclado.'
echo '[7] Sonda X11 sem outros programas: nao observar bloqueio'
"$BIN" --verificar-tecla > "$TMP/grab-free.txt"
grep -Fx 'PRINT_RC_GRAB=sem_bloqueio_x11' "$TMP/grab-free.txt"

echo '[8] Sonda X11 com outro cliente reservando Print: nao pode liberar o terceiro'
cat > "$TMP/grab-other.cpp" <<'CPP'
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <unistd.h>
#include <cstdio>
int main(int argc,char** argv) {
    Display* d=XOpenDisplay(nullptr);
    if(!d) return 2;
    KeyCode k=XKeysymToKeycode(d,argc>1?XStringToKeysym(argv[1]):XK_Print);
    if(!k) return 3;
    XGrabKey(d,k,0,DefaultRootWindow(d),False,GrabModeAsync,GrabModeAsync);
    XSync(d,False);
    puts("READY");
    fflush(stdout);
    sleep(8);
    XUngrabKey(d,k,0,DefaultRootWindow(d));
    XSync(d,False);
    XCloseDisplay(d);
}
CPP
g++ -O2 "$TMP/grab-other.cpp" -o "$TMP/grab-other" $(pkg-config --cflags --libs x11)
"$TMP/grab-other" > "$TMP/other-ready.txt" &
OTHER=$!
for _ in $(seq 1 30); do
    grep -q READY "$TMP/other-ready.txt" && break
    sleep 0.1
done
grep -q READY "$TMP/other-ready.txt"
CODE=0
"$BIN" --verificar-tecla > "$TMP/grab-occupied.txt" || CODE=$?
test "$CODE" -eq 6
grep -Fx 'PRINT_RC_GRAB=ocupada' "$TMP/grab-occupied.txt"
# Repetir prova que a sonda nao removeu o grab pertencente ao outro cliente.
CODE=0
"$BIN" --verificar-tecla > "$TMP/grab-still-occupied.txt" || CODE=$?
test "$CODE" -eq 6
kill "$OTHER" 2>/dev/null || true
wait "$OTHER" 2>/dev/null || true
"$BIN" --verificar-tecla > "$TMP/grab-released.txt"
grep -Fx 'PRINT_RC_GRAB=sem_bloqueio_x11' "$TMP/grab-released.txt"
echo 'OK: teste de sonda mostra reserva externa, sem tomar atalhos de outro processo.'

echo '[9] BUG REAL XFCE: receber Insert e aceitar como tecla escolhida'
# Reproduz o evento X11 do screenshot: a tecla foi recebida como Insert.
# Usar o mapeamento NATIVO Insert do servidor Xvfb; remapear com xmodmap
# nao e confiavel, pois o XKB virtual pode restaurar Print/Sys_Req.
timeout 7s "$BIN" --detectar-print > "$TMP/insert.txt" 2> "$TMP/insert.err" &
PID=$!
sleep 0.5
xdotool key Insert
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Insert' "$TMP/insert.txt"
grep -F 'tecla escolhida: Insert' "$TMP/insert.err"
! grep -q 'segundos esgotados' "$TMP/insert.err"
echo 'OK: Pressionar Insert encerra a deteccao imediatamente sem timeout.'

echo '[10] Tecla alfanumerica e tecla especial Return'
for sym in a Return; do
    "$BIN" --detectar-print > "$TMP/${sym}.out" 2> "$TMP/${sym}.err" &
    PID=$!
    sleep 0.5
    xdotool key "$sym"
    wait "$PID"
    grep -Fx "PRINT_RC_KEY=$sym" "$TMP/${sym}.out"
done

echo '[11] Shift sozinho nao vira atalho; F9 subsequente conclui'
"$BIN" --detectar-print > "$TMP/shift-and-f9.txt" 2> "$TMP/shift-and-f9.err" &
PID=$!
sleep 0.5
xdotool key Shift_L
sleep 0.2
xdotool key F9
wait "$PID"
grep -Fx 'PRINT_RC_KEY=F9' "$TMP/shift-and-f9.txt"
grep -F 'modificador sozinho' "$TMP/shift-and-f9.err"
echo 'OK: F12, Insert, a, Return e F9 reconhecidos; modificador sozinho ignorado.'

echo '[12] Reserva F12 nao pode ser confundida com Print'
"$TMP/grab-other" F12 > "$TMP/f12-ready.txt" &
OTHER=$!
for _ in {1..30}; do grep -q READY "$TMP/f12-ready.txt" && break; sleep 0.1; done
CODE=0
"$BIN" --verificar-tecla F12 > "$TMP/f12-grab.txt" || CODE=$?
test "$CODE" -eq 6
"$BIN" --verificar-tecla Print > "$TMP/print-independent.txt"
grep -Fx 'PRINT_RC_GRAB=sem_bloqueio_x11' "$TMP/print-independent.txt"
kill "$OTHER";wait "$OTHER" || true
"$BIN" --verificar-tecla F12 > "$TMP/f12-released.txt"
grep -Fx 'PRINT_RC_GRAB=sem_bloqueio_x11' "$TMP/f12-released.txt"
