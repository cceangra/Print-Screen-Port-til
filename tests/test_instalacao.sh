#!/usr/bin/env bash
# Teste de instalacao portatil com pasta unica, sem instalar bibliotecas.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export XDG_SESSION_TYPE=x11

[[ -x "$ROOT/bin/print-rc" ]] || { echo 'Antes execute make portable'; exit 1; }
"$ROOT/bin/print-rc" --self-test

make_source() {
    local d="$1"
    mkdir -p -- "$d"
    cp -a -- "$ROOT/instalar.sh" "$ROOT/iniciar.sh" "$ROOT/desinstalar.sh" \
      "$ROOT/Makefile" "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/configurar.sh" \
      "$ROOT/src" "$ROOT/scripts" "$ROOT/bin" "$d/"
}
echo '[1] Mantendo a pasta extraida: nao instalar pacotes nem criar segunda copia'
make_source "$TEMP/origem1"
printf '\n\n\ns\nn\n' | bash "$TEMP/origem1/instalar.sh"
test -x "$TEMP/origem1/bin/print-rc"
test -f "$TEMP/origem1/.print-rc-installation"
test -f "$TEMP/origem1/config/opcoes.conf"
test -f "$TEMP/origem1/config/arquivos-instalados.sha256"
grep -F "desinstalar.sh" "$TEMP/origem1/config/arquivos-instalados.sha256"

grep -Fx "save_dir=$TEMP/origem1/capturas" "$TEMP/origem1/config/opcoes.conf"
grep -Fx "copy_clipboard=1" "$TEMP/origem1/config/opcoes.conf"
test "$(sed -n '2p' "$TEMP/origem1/.print-rc-installation")" = "$TEMP/origem1"

echo '[2] Movendo a pasta inteira para um destino com espacos'
make_source "$TEMP/origem2"
FINAL="$TEMP/pasta final/Print RC"
printf '%s\ns\n\n\ns\nn\n' "$FINAL" | bash "$TEMP/origem2/instalar.sh"
test ! -e "$TEMP/origem2"
test -x "$FINAL/bin/print-rc"
test -f "$FINAL/src/main.cpp"
test -f "$FINAL/instalar.sh"
test -f "$FINAL/configurar.sh"
test -f "$FINAL/config/opcoes.conf"
test -f "$FINAL/config/arquivos-instalados.sha256"
test "$(sed -n '2p' "$FINAL/.print-rc-installation")" = "$FINAL"

echo '[3] Recusar sobrescrever pasta existente'
make_source "$TEMP/origem3"
mkdir -p "$TEMP/existente"
printf 'usuario' > "$TEMP/existente/dados.txt"
if printf '%s\n' "$TEMP/existente" | bash "$TEMP/origem3/instalar.sh"; then
    echo 'ERRO: permitiu destino existente'; exit 1
fi
test -f "$TEMP/origem3/instalar.sh"
test "$(cat "$TEMP/existente/dados.txt")" = usuario

echo '[4] Recusar binario ausente sem mover arquivos'
make_source "$TEMP/origem4"
rm -f -- "$TEMP/origem4/bin/print-rc"
if bash "$TEMP/origem4/instalar.sh"; then
    echo 'ERRO: permitiu pacote incompleto'; exit 1
fi
test -e "$TEMP/origem4/instalar.sh"
echo '[5] Reinstalar em pasta preservada com prints, sem sobrescrever nada'
make_source "$TEMP/origem5"
FINAL5="$TEMP/pasta com fotos/Print-RC"
mkdir -p "$FINAL5/capturas" "$FINAL5/src" "$FINAL5/config"
printf 'PRINT IMPORTANTE\n' > "$FINAL5/capturas/print-antigo.png"
printf 'DESENHO PROPRIO\n' > "$FINAL5/src/arquivo-pessoal.png"
printf 'CONFIG PESSOAL\n' > "$FINAL5/config/meus-dados.txt"
printf '%s\ns\n\n\ns\nn\n' "$FINAL5" | bash "$TEMP/origem5/instalar.sh"
test ! -e "$TEMP/origem5"
test -x "$FINAL5/bin/print-rc"
test -f "$FINAL5/config/arquivos-instalados.sha256"
test "$(cat "$FINAL5/capturas/print-antigo.png")" = 'PRINT IMPORTANTE'
test "$(cat "$FINAL5/src/arquivo-pessoal.png")" = 'DESENHO PROPRIO'
test "$(cat "$FINAL5/config/meus-dados.txt")" = 'CONFIG PESSOAL'

echo '[6] Conflito com arquivo pessoal de mesmo nome bloqueia reinstalacao'
make_source "$TEMP/origem6"
FINAL6="$TEMP/pasta com conflito/Print-RC"
mkdir -p "$FINAL6"
printf 'README PESSOAL\n' > "$FINAL6/README.md"
if printf '%s\n' "$FINAL6" | bash "$TEMP/origem6/instalar.sh"; then
    echo 'ERRO: reinstalacao sobrescreveu arquivo pessoal.'
    exit 1
fi
test "$(cat "$FINAL6/README.md")" = 'README PESSOAL'
test -f "$TEMP/origem6/README.md"
echo 'OK: instalacao sem compilar, mover pasta completa, recusa sobrescrita.'
