#!/usr/bin/env bash
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
TEMP="$(mktemp -d)"
PIDS=()
cleanup() {
    for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
    rm -rf -- "$TEMP"
}
trap cleanup EXIT
mkdir -p "$TEMP/fotos"
printf 'save_dir=%s\ncopy_clipboard=1\n' "$TEMP/fotos" > "$TEMP/settings"
export PRINT_RC_CONFIG="$TEMP/settings"
g++ -std=c++17 -O2 -Wall -Wextra "$ROOT/tests/paint_test_pattern.cpp" \
    -o "$TEMP/noise" $(pkg-config --libs x11)
"$TEMP/noise"
echo '[CLIP 1] Salvar PNG grande e colar bytes identicos de Ctrl+V'
"$ROOT/bin/print-rc" > "$TEMP/first.log" 2>&1 &
PID=$!
PIDS+=("$PID")
sleep 0.8
xdotool mousemove --sync 458 35 click 1
for i in {1..80}; do
    mapfile -t photos < <(find "$TEMP/fotos" -maxdepth 1 -name '*.png')
    if (( ${#photos[@]} == 1 )); then break; fi
    sleep 0.1
done
test "${#photos[@]}" -eq 1
size=$(stat -c %s -- "${photos[0]}")
if (( size <= 65536 )); then
    echo "ERRO: PNG tem so $size bytes, nao testou caminho X11 INCR."
    exit 1
fi
timeout 20s xclip -selection clipboard -t image/png -o > "$TEMP/colado.png"
cmp -s -- "${photos[0]}" "$TEMP/colado.png" || {
    echo 'ERRO: bytes colados diferentes do PNG salvo.'
    exit 1
}
echo "OK: PNG grande de $size bytes colado exatamente (INCR)."
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

echo '[CLIP 2] Sem permissao de salvar, Ctrl+V continua funcionando'
mkdir -p "$TEMP/sem-permissao"
printf 'save_dir=%s\ncopy_clipboard=1\n' "$TEMP/sem-permissao" > "$TEMP/settings"
"$ROOT/bin/print-rc" > "$TEMP/second.log" 2>&1 &
PID2=$!
PIDS+=("$PID2")
sleep 0.8
if [[ $EUID -eq 0 ]]; then
    rmdir "$TEMP/sem-permissao" # root bypasses permission bits; test unavailable destination instead
else
    chmod 500 "$TEMP/sem-permissao"
fi
xdotool mousemove --sync 458 35 click 1
for i in {1..80}; do
    if grep -q 'nao foi possivel salvar o PNG' "$TEMP/second.log"; then break; fi
    sleep 0.1
done
grep -q 'nao foi possivel salvar o PNG' "$TEMP/second.log" || {
    echo 'ERRO: nao foi identificada falha ao salvar.'
    cat "$TEMP/second.log";exit 1
}
if [[ -d "$TEMP/sem-permissao" ]]; then
    test -z "$(find "$TEMP/sem-permissao" -maxdepth 1 -name '*.png' -print -quit)"
fi
timeout 20s xclip -selection clipboard -t image/png -o > "$TEMP/colado-apos-falha.png"
test "$(head -c 8 "$TEMP/colado-apos-falha.png" | od -An -tx1 | tr -d ' \n')" = '89504e470d0a1a0a'
echo 'OK: PNG ainda esta disponivel no Ctrl+V apesar da falha de escrita.'
kill "$PID2" 2>/dev/null || true
wait "$PID2" 2>/dev/null || true
echo 'SUCESSO: clipboard X11 e falha de disco testados.'
