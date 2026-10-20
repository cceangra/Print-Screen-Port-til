#!/usr/bin/env bash
# Testes de remocao, SEM qualquer acesso ao HOME real do usuario.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
HOME="$TEMP/home"
export HOME
mkdir -p "$HOME"
make_app() {
    local app="$1"
    mkdir -p -- "$app/bin" "$app/src" "$app/scripts" "$app/config" "$app/capturas" "$app/backups"
    cp "$ROOT/desinstalar.sh" "$app/desinstalar.sh"
    cp "$ROOT/scripts/atalho.py" "$app/scripts/atalho.py"
    printf 'binario\n' > "$app/bin/print-rc"
    printf 'fonte\n' > "$app/src/main.cpp"
    printf 'PRINT-RC\n%s\n' "$app" > "$app/.print-rc-installation"
    printf 'save_dir=%s\ncopy_clipboard=0\n' "$app/capturas" > "$app/config/opcoes.conf"
}
echo '[1] Remocao preserva capturas INTERNAS, inclusive fotos antigas e outros arquivos'
APP="$TEMP/teste interno/Print-RC"
make_app "$APP"
printf 'foto1\n' > "$APP/capturas/Print-RC_2026-10-20.png"
printf 'foto2\n' > "$APP/capturas/print-antigo.jpg"
printf 'foto3\n' > "$APP/src/arquivo-importante.png"
printf 'dados\n' > "$APP/minhas-anotacoes.txt"
printf 'DESINSTALAR\n' | bash "$APP/desinstalar.sh"
test ! -e "$APP/bin/print-rc"
test ! -e "$APP/desinstalar.sh"
test ! -e "$APP/config/opcoes.conf"
test -f "$APP/capturas/Print-RC_2026-10-20.png"
test -f "$APP/capturas/print-antigo.jpg"
test -f "$APP/src/arquivo-importante.png"
test -f "$APP/minhas-anotacoes.txt"
test "$(cat "$APP/capturas/Print-RC_2026-10-20.png")" = foto1
echo 'OK: imagens internas e arquivos desconhecidos preservados.'

echo '[2] Remocao de app SEM imagens deixa ZERO arquivos internos'
APP2="$TEMP/teste vazio/Print-RC"
make_app "$APP2"
printf 'DESINSTALAR\n' | bash "$APP2/desinstalar.sh"
test ! -e "$APP2"
echo 'OK: pasta realmente vazia removida.'

echo '[3] Capturas EXTERNAS continuam no disco e atalho anterior e restaurado'
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
grep -q 'Name=Print RC' "$KEYFILE"
printf 'DESINSTALAR\n' | bash "$APP3/desinstalar.sh"
test -f "$EXTERNAL_DIR/foto.png"
test "$(cat "$EXTERNAL_DIR/foto.png")" = 'imagens externas'
grep -q 'Name=Print anterior' "$KEYFILE"
grep -q 'Key=Print' "$KEYFILE"
! grep -q 'Name=Print RC' "$KEYFILE"
test ! -e "$APP3"
echo 'OK: capturas externas intactas e atalho original restaurado.'

echo '[4] Link simbolico apontando para fora interrompe desinstalacao ANTES de apagar app'
APP4="$TEMP/teste link/Print-RC"
make_app "$APP4"
mkdir -p "$TEMP/outside"
printf 'nao mexa\n' > "$TEMP/outside/imagem.png"
rmdir "$APP4/capturas"
ln -s "$TEMP/outside" "$APP4/capturas"
if printf 'DESINSTALAR\n' | bash "$APP4/desinstalar.sh"; then
    echo 'ERRO: desinstalacao aceitou diretorio simbolico inesperado.'
    exit 1
fi
test -f "$APP4/bin/print-rc"
test -f "$TEMP/outside/imagem.png"
test "$(cat "$TEMP/outside/imagem.png")" = 'nao mexa'
echo 'OK: recusa links simbolicos perigosos.'
echo 'TODOS OS TESTES PASSARAM: NENHUMA FOTO FOI APAGADA.'
