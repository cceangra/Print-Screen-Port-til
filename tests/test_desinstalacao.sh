#!/usr/bin/env bash
# Testes isolados da desinstalacao: imagens e arquivos pessoais NUNCA removidos.
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
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
    cp -a "$ROOT/i18n" "$app/"
    cp "$ROOT/scripts/i18n.sh" "$ROOT/scripts/messages.bash" "$ROOT/scripts/prompts.sh" "$ROOT/scripts/print_rc_i18n.py" "$ROOT/scripts/lifecycle.py" "$app/scripts/"
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
# Copiar SOMENTE arquivos versionados do pacote.
# O checkout da CI pode ter __pycache__/ gerado por testes anteriores,
# que NAO faz parte do ZIP baixado e deve ser preservado, nao removido.
copy_dev_package_files() {
    local dest="$1" rel
    for rel in "${PRINT_RC_KNOWN[@]}"; do
        case "$rel" in
            .github/*|tests/*)
                if [[ -f "$ROOT/$rel" ]]; then
                    mkdir -p -- "$dest/${rel%/*}"
                    cp -a -- "$ROOT/$rel" "$dest/$rel"
                fi
                ;;
        esac
    done
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
echo '[7] Codigo-fonte completo: remove .github, tests e pasta inteira sem residuos'
APP7="$TEMP/source zip com espacos/Print-Screen-Port-til-main"
make_app "$APP7"
copy_dev_package_files "$APP7"
cp "$ROOT/.gitignore" "$APP7/.gitignore"
cp "$ROOT/LICENSE" "$APP7/LICENSE"
cp "$ROOT/Makefile" "$APP7/Makefile"
cp "$ROOT/instalar.sh" "$APP7/instalar.sh"
cp "$ROOT/iniciar.sh" "$APP7/iniciar.sh"
cp "$ROOT/configurar.sh" "$APP7/configurar.sh"
cp "$ROOT/src/settings.hpp" "$APP7/src/settings.hpp"
for leftover in '.github/release-0.4.2.ready' '.github/release-0.4.3.ready' '.github/release-0.4.4.ready' 'tests/test_clipboard_x11.sh' 'tests/paint_test_pattern.cpp' 'tests/test_desinstalacao_processo_x11.sh'; do
    test -f "$APP7/$leftover"
done
record "$APP7"
for leftover in '.github/release-0.4.2.ready' '.github/release-0.4.3.ready' '.github/release-0.4.4.ready' 'tests/test_clipboard_x11.sh' 'tests/paint_test_pattern.cpp' 'tests/test_desinstalacao_processo_x11.sh'; do
    grep -Fq -- "$(printf '\t%s' "$leftover")" "$APP7/config/arquivos-instalados.sha256"
done
ZIP7="$TEMP/Print-RC-original.zip"
printf 'ZIP PESSOAL NAO APAGAR\n' > "$ZIP7"
printf 'DESINSTALAR\n' | bash "$APP7/desinstalar.sh"
if [[ -e "$APP7" ]]; then
    echo 'TESTE FALHOU: ainda existem arquivos dentro da pasta:'
    find "$APP7" -mindepth 1 -print
    exit 1
fi
test "$(cat "$ZIP7")" = 'ZIP PESSOAL NAO APAGAR'

echo '[8] Preservar dados desconhecidos em .github e tests, sem apagar ZIP'
APP8="$TEMP/fonte com dados pessoais/Print-RC"
make_app "$APP8"
copy_dev_package_files "$APP8"
printf 'ARQUIVO PARTICULAR\n' > "$APP8/tests/anotacoes.txt"
printf 'CONFIGURACAO PARTICULAR\n' > "$APP8/.github/meu-projeto.txt"
record "$APP8"
printf 'DESINSTALAR\n' | bash "$APP8/desinstalar.sh"
test -f "$APP8/tests/anotacoes.txt"
test -f "$APP8/.github/meu-projeto.txt"
test "$(cat "$APP8/tests/anotacoes.txt")" = 'ARQUIVO PARTICULAR'
test "$(cat "$APP8/.github/meu-projeto.txt")" = 'CONFIGURACAO PARTICULAR'
test ! -e "$APP8/.github/release-0.4.2.ready"
test ! -e "$APP8/tests/test_clipboard_x11.sh"
test ! -e "$APP8/bin/print-rc"

echo '[9] Todos os arquivos versionados do GitHub constam da lista fixa de arquivos do app'
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    declare -A conhecidos=()
    for nome in "${PRINT_RC_KNOWN[@]}"; do conhecidos["$nome"]=1; done
    while IFS= read -r -d '' nome; do
        if [[ ! -v 'conhecidos[$nome]' ]]; then
            echo "ERRO: arquivo versionado ausente da lista de desinstalacao: $nome"
            exit 1
        fi
    done < <(git -C "$ROOT" ls-files -z)
fi
echo '[10] Alterar preferencias varias vezes e ainda remover a pasta do app'
APP10="$TEMP/preferencias editadas/Print-RC"
make_app "$APP10"
cp "$ROOT/configurar.sh" "$APP10/configurar.sh"
record "$APP10"
ORIGINAL="$(sha256sum "$APP10/config/opcoes.conf" | cut -d' ' -f1)"
# Mudar Ctrl+V de 0 para 1 e depois voltar a 0 para verificar duas atualizacoes.
printf '\ns\ns\n' | bash "$APP10/configurar.sh"
CHANGED="$(sha256sum "$APP10/config/opcoes.conf" | cut -d' ' -f1)"
test "$CHANGED" != "$ORIGINAL"
grep -Fq -- "$(printf '%s\tconfig/opcoes.conf' "$CHANGED")" "$APP10/config/arquivos-instalados.sha256"
printf '\nn\ns\n' | bash "$APP10/configurar.sh"
RESTORED="$(sha256sum "$APP10/config/opcoes.conf" | cut -d' ' -f1)"
grep -Fq -- "$(printf '%s\tconfig/opcoes.conf' "$RESTORED")" "$APP10/config/arquivos-instalados.sha256"
printf 'DESINSTALAR\n' | bash "$APP10/desinstalar.sh"
test ! -e "$APP10"

echo '[11] Inventario invalido nao deve ser aceito na reconfiguracao'
APP11="$TEMP/inventario inseguro/Print-RC"
make_app "$APP11"
cp "$ROOT/configurar.sh" "$APP11/configurar.sh"
record "$APP11"
printf 'hash-invalido\tconfig/opcoes.conf\n' >> "$APP11/config/arquivos-instalados.sha256"
BEFORE="$(cat "$APP11/config/arquivos-instalados.sha256")"
if printf '\nn\ns\n' | bash "$APP11/configurar.sh"; then
    echo 'ERRO: inventario invalido foi aceito.'
    exit 1
fi
test "$(cat "$APP11/config/arquivos-instalados.sha256")" = "$BEFORE"

echo 'TODOS OS TESTES PASSARAM: pastas do app limpas e dados pessoais/ZIP preservados.'
