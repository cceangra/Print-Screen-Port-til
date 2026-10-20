#!/usr/bin/env bash
# Testa o instalador em pastas temporarias, sem acessar atalhos reais.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export XDG_SESSION_TYPE=x11
make_source() {
    local d="$1"
    mkdir -p -- "$d"
    cp -a -- "$ROOT/instalar.sh" "$ROOT/iniciar.sh" "$ROOT/desinstalar.sh" \
      "$ROOT/Makefile" "$ROOT/README.md" "$ROOT/LICENSE" \
      "$ROOT/src" "$ROOT/scripts" "$d/"
}
echo '[1] Instalar sem mover: nao criar outra pasta'
make_source "$TEMP/origem1"
printf '\nn\n' | bash "$TEMP/origem1/instalar.sh"
test -x "$TEMP/origem1/bin/print-rc"
test -f "$TEMP/origem1/.print-rc-installation"
test "$(sed -n '2p' "$TEMP/origem1/.print-rc-installation")" = "$TEMP/origem1"
test "$(find "$TEMP/origem1" -maxdepth 1 -name '.compilacao-*' | wc -l)" -eq 0

echo '[2] Mover pasta completa ao destino, inclusive caminhos com espacos'
make_source "$TEMP/origem2"
FINAL="$TEMP/pasta final/Print RC"
printf '%s\ns\nn\n' "$FINAL" | bash "$TEMP/origem2/instalar.sh"
test ! -e "$TEMP/origem2"
test -x "$FINAL/bin/print-rc"
test -f "$FINAL/src/main.cpp"
test -f "$FINAL/instalar.sh"
test "$(sed -n '2p' "$FINAL/.print-rc-installation")" = "$FINAL"
test "$(find "$FINAL" -maxdepth 1 -name '.compilacao-*' | wc -l)" -eq 0

echo '[3] Nao sobrescrever destino existente'
make_source "$TEMP/origem3"
mkdir -p "$TEMP/existente"
printf 'manter dados' > "$TEMP/existente/usuario.txt"
if printf '%s\n' "$TEMP/existente" | bash "$TEMP/origem3/instalar.sh"; then
    echo 'ERRO: instalador aceitou destino existente'; exit 1
fi
test -f "$TEMP/origem3/instalar.sh"
test "$(cat "$TEMP/existente/usuario.txt")" = 'manter dados'
echo 'OK: pasta unica, movimentacao e protecao contra sobrescrita.'
