#!/usr/bin/env bash
# Testes isolados da desinstalacao: imagens e arquivos pessoais NUNCA removidos.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
HOME="$TEMP/home"
export HOME
mkdir -p "$HOME"
source "$ROOT/scripts/inventario.sh"
make_app() {
    local app="$1"
    mkdir -p -- "$app/bin" "$app/src" "$app/scripts" "$app/config" "$app/capturas" "$app/backups"
    cp "$ROOT/desinstalar.sh" "$app/desinstalar.sh"
    cp "$ROOT/scripts/atalho.py" "$app/scripts/atalho.py"
    cp "$ROOT/scripts/inventario.sh" "$app/scripts/inventario.sh"
    printf 'binario\n' > "$app/bin/print-rc"
    printf 'fonte\n' > "$app/src/main.cpp"
    printf 'README ORIGINAL\n' > "$app/README.md"
    printf 'PRINT-RC\n%s\n' "$app" > "$app/.print-rc-installation"
    printf 'save_dir=%s\ncopy_clipboard=0\n' "$app/capturas" > "$app/config/opcoes.conf"
}
record() {
    print_rc_criar_inventario "$1"
    test -f "$1/config/arquivos-instalados.sha256"
}
echo '[1] Imagens internas e arquivos pessoais permanecem intactos'
APP="$TEMP/teste interno/Print-RC"
make_app "$APP"
record "$APP"
printf 'foto1\n' > "$APP/capturas/Print-RC_2026-10-20.png"
printf 'foto2\n' > "$APP/capturas/print-antigo.jpg"
printf 'foto3\n' > "$APP/src/arquivo-importante.png"
printf 'dados\n' > "$APP/minhas-anotacoes.txt"
printf 'DESINSTALAR\n' | bash "$APP/desinstalar.sh"
test ! -e "$APP/bin/print-rc"
test ! -e "$APP/desinstalar.sh"
test -f "$APP/capturas/Print-RC_2026-10-20.png"
test -f "$APP/capturas/print-antigo.jpg"
test -f "$APP/src/arquivo-importante.png"
test -f "$APP/minhas-anotacoes.txt"
test "$(cat "$APP/capturas/Print-RC_2026-10-20.png")" = foto1

echo '[2] Instalacao sem imagens nem arquivos pessoais e removida por completo'
APP2="$TEMP/teste vazio/Print-RC"
make_app "$APP2"
record "$APP2"
printf 'DESINSTALAR\n' | bash "$APP2/desinstalar.sh"
test ! -e "$APP2"

echo '[3] Prints externos e atalho anterior permanecem intocados'
APP3="$TEMP/teste com atalho/Print-RC"
make_app "$APP3"
EXTERNAL_DIR="$TEMP/fotos fora da instalacao"
mkdir -p "$EXTERNAL_DIR" "$HOME/.trinity/share/config"
printf 'imagens externas\n' > "$EXTERNAL_DIR/foto.png"
printf 'save_dir=%s\ncopy_clipboard=1\n' "$EXTERNAL_DIR" > "$APP3/config/opcoes.conf"
KEYFILE="$HOME/.trinity/share/config/khotkeysrc"
cat > "$KEYFILE" <<'CFG'
[Data]
DataCount=1

[Data_1]
Name=Print anterior
Type=SIMPLE_ACTION_DATA

[Data_1Actions0]
CommandURL=app-do-usuario

[Data_1Triggers0]
Key=Print
Type=SHORTCUT
CFG
printf 's\ns\n' | XDG_CURRENT_DESKTOP=Trinity python3 "$APP3/scripts/atalho.py" install --base "$APP3" --launcher "$APP3/iniciar.sh"
test -f "$APP3/config/atalho-state.json"
record "$APP3"
grep -q 'Name=Print RC' "$KEYFILE"
printf 'DESINSTALAR\n' | bash "$APP3/desinstalar.sh"
test -f "$EXTERNAL_DIR/foto.png"
test "$(cat "$EXTERNAL_DIR/foto.png")" = 'imagens externas'
grep -q 'Name=Print anterior' "$KEYFILE"
grep -q 'Key=Print' "$KEYFILE"
! grep -q 'Name=Print RC' "$KEYFILE"
test ! -e "$APP3"

echo '[4] Diretorio simbolico externo bloqueia a desinstalacao'
APP4="$TEMP/teste link/Print-RC"
make_app "$APP4"
record "$APP4"
mkdir -p "$TEMP/outside"
printf 'nao mexa\n' > "$TEMP/outside/imagem.png"
rmdir "$APP4/capturas"
ln -s "$TEMP/outside" "$APP4/capturas"
if printf 'DESINSTALAR\n' | bash "$APP4/desinstalar.sh"; then
    echo 'ERRO: aceitou link simbolico externo.'
    exit 1
fi
test -f "$APP4/bin/print-rc"
test "$(cat "$TEMP/outside/imagem.png")" = 'nao mexa'

echo '[5] Arquivos de mesmo nome alterados pelo usuario sao preservados'
APP5="$TEMP/teste arquivos modificados/Print-RC"
make_app "$APP5"
record "$APP5"
printf 'DOCUMENTO IMPORTANTE DO USUARIO\n' > "$APP5/README.md"
printf 'codigo personalizado\n' > "$APP5/src/main.cpp"
printf 'DESINSTALAR\n' | bash "$APP5/desinstalar.sh"
test -f "$APP5/README.md"
test -f "$APP5/src/main.cpp"
test "$(cat "$APP5/README.md")" = 'DOCUMENTO IMPORTANTE DO USUARIO'
test "$(cat "$APP5/src/main.cpp")" = 'codigo personalizado'
test ! -e "$APP5/bin/print-rc"

echo '[6] Instalacao legada sem inventario nao apaga arquivos desconhecidos'
APP6="$TEMP/teste versao antiga/Print-RC"
make_app "$APP6"
printf 'pessoal\n' > "$APP6/capturas/antigo.png"
if printf 'DESINSTALAR\n' | bash "$APP6/desinstalar.sh"; then
    echo 'ERRO: versao antiga sem inventario removida sem prova de origem.'
    exit 1
fi
test -f "$APP6/bin/print-rc"
test "$(cat "$APP6/capturas/antigo.png")" = pessoal
echo 'TODOS OS TESTES PASSARAM: prints e arquivos pessoais preservados.'
