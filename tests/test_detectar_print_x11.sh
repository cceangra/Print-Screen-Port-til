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
grep -F 'Voce tem ate 60 segundos' "$TMP/print.err"

echo '[2] Tecla diferente nao pode virar Print; aceitar Print em seguida'
"$BIN" --detectar-print > "$TMP/diferente.txt" 2> "$TMP/diferente.err" &
PID=$!
sleep 0.5
xdotool key F12
sleep 0.2
xdotool key Print
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/diferente.txt"
grep -F 'mapeamento F12' "$TMP/diferente.err"
grep -F 'NAO corresponde a Print/Sys_Req' "$TMP/diferente.err"

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
int main() {
    Display* d=XOpenDisplay(nullptr);
    if(!d) return 2;
    KeyCode k=XKeysymToKeycode(d,XK_Print);
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

echo '[9] REGRESSAO: Print em segundo keysym; versao antiga ignorava a tecla ate timeout'
# xmodmap controla SOMENTE o servidor Xvfb descartavel deste teste.
# Testar uma tecla fisica que tem F13 como nivel 0 e Print no nivel 1.
xmodmap -e 'keycode 107 = F13 Print'
echo 'Mapa X11 virtual apos xmodmap (keycode 107):'
xmodmap -pke | grep -E '^keycode[[:space:]]+107[[:space:]]*=' || true
timeout 7s "$BIN" --detectar-print > "$TMP/second-level.txt" 2> "$TMP/second-level.err" &
PID=$!
sleep 0.5
xdotool key F13
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Print' "$TMP/second-level.txt"
grep -F 'tecla identificada: Print' "$TMP/second-level.err"

echo '[10] REGRESSAO: Sys_Req em nivel alternativo tambem deve ser aceito'
xmodmap -e 'keycode 107 = F13 Sys_Req'
timeout 7s "$BIN" --detectar-print > "$TMP/sysreq-level.txt" 2> "$TMP/sysreq-level.err" &
PID=$!
sleep 0.5
xdotool key F13
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Sys_Req' "$TMP/sysreq-level.txt"

echo '[11] Outra tecla sem Print/Sys_Req nunca deve ser cadastrada como Print'
xmodmap -e 'keycode 107 = F13 F14'
# Usa detector acelerado para nao esperar 60 s se o mapa esta diferente.
timeout 7s "$TMP/print-rc-timeout" --detectar-print > "$TMP/no-print.txt" 2> "$TMP/no-print.err" &
PID=$!
sleep 0.2
xdotool key F13
RETURN=0
wait "$PID" || RETURN=$?
test "$RETURN" -eq 4
test ! -s "$TMP/no-print.txt"
grep -F 'NAO corresponde a Print/Sys_Req' "$TMP/no-print.err"
echo 'OK: Print/Sys_Req em niveis alternativos reconhecidos e teclas estranhas recusadas.'

echo '[12] BUG REAL XFCE: tecla rotulada Print esta mapeada como Insert'
# Simular mapeamento que originou o bug do usuario no Xfce.
# O detector deve encerrar no PRIMEIRO Insert, nao aguardar o timeout.
xmodmap -e 'keycode 107 = Insert'
timeout 7s "$BIN" --detectar-print > "$TMP/insert.txt" 2> "$TMP/insert.err" &
PID=$!
sleep 0.5
xdotool key Insert
wait "$PID"
grep -Fx 'PRINT_RC_KEY=Insert' "$TMP/insert.txt"
grep -F 'tecla identificada: Insert' "$TMP/insert.err"
! grep -q 'segundos esgotados' "$TMP/insert.err"
echo 'OK: tecla fisica Insert cadastravel, sem esperar 60 segundos.'



