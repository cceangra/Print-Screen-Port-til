#!/usr/bin/env bash
# Testes isolados de configuracao, sem tocar no HOME do usuario.
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT

echo '[1] Pasta interna padrao + Ctrl+V ligado'
mkdir -p "$TEMP/app1"
cp "$ROOT/configurar.sh" "$TEMP/app1/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app1/"
printf '\n\ns\n' | bash "$TEMP/app1/configurar.sh"
grep -Fx "save_dir=$TEMP/app1/capturas" "$TEMP/app1/config/opcoes.conf"
grep -Fx 'copy_clipboard=1' "$TEMP/app1/config/opcoes.conf"
test -d "$TEMP/app1/capturas"
PRINT_RC_CONFIG="$TEMP/app1/config/opcoes.conf" "$ROOT/bin/print-rc" --show-config | grep -F 'Copiar para Ctrl+V: SIM'

echo '[2] Diretorio externo com espacos + Ctrl+V desligado'
mkdir -p "$TEMP/app2" "$TEMP/imagens externas"
cp "$ROOT/configurar.sh" "$TEMP/app2/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app2/"
printf '%s\ns\nn\ns\n' "$TEMP/imagens externas" | bash "$TEMP/app2/configurar.sh"
grep -Fx "save_dir=$TEMP/imagens externas" "$TEMP/app2/config/opcoes.conf"
grep -Fx 'copy_clipboard=0' "$TEMP/app2/config/opcoes.conf"
PRINT_RC_CONFIG="$TEMP/app2/config/opcoes.conf" "$ROOT/bin/print-rc" --show-config | grep -F 'Copiar para Ctrl+V: NAO'

echo '[3] Cancelar diretorio externo novo NAO deixa residuo'
mkdir -p "$TEMP/app3"
cp "$ROOT/configurar.sh" "$TEMP/app3/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app3/"
if printf '%s\ns\nn\nn\n' "$TEMP/external naocriar" | bash "$TEMP/app3/configurar.sh"; then
  echo 'ERRO: configuracao aceita com resposta NAO';exit 1
fi
test ! -e "$TEMP/external naocriar"
test ! -e "$TEMP/app3/config/opcoes.conf"

echo '[4] Nao aceitar caminho relativo nem criar pastas'
mkdir -p "$TEMP/app4"
cp "$ROOT/configurar.sh" "$TEMP/app4/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app4/"
if printf 'Imagens/Print\n' | bash "$TEMP/app4/configurar.sh"; then
  echo 'ERRO: aceitou caminho relativo';exit 1
fi
test ! -e "$TEMP/app4/config/opcoes.conf"

echo '[5] Enter conserva pasta e Ctrl+V de configuracao anterior'
mkdir -p "$TEMP/app5" "$TEMP/minhas imagens anteriores"
cp "$ROOT/configurar.sh" "$TEMP/app5/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app5/"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$TEMP/minhas imagens anteriores" > "$TEMP/app5/config-before"
mkdir -p "$TEMP/app5/config"
cp "$TEMP/app5/config-before" "$TEMP/app5/config/opcoes.conf"
printf '\ns\n\ns\n' | bash "$TEMP/app5/configurar.sh"
grep -Fx "save_dir=$TEMP/minhas imagens anteriores" "$TEMP/app5/config/opcoes.conf"
grep -Fx 'copy_clipboard=0' "$TEMP/app5/config/opcoes.conf"
echo '[6] Nao escrever em configuracao apontando para pasta externa'
mkdir -p "$TEMP/app6" "$TEMP/externa-app6"
cp "$ROOT/configurar.sh" "$TEMP/app6/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app6/"
printf 'DOCUMENTO INTACTO\n' > "$TEMP/externa-app6/pessoal.txt"
ln -s -- "$TEMP/externa-app6" "$TEMP/app6/config"
if bash "$TEMP/app6/configurar.sh"; then
  echo 'ERRO: permitiu configuracao simbolica externa.'; exit 1
fi
test ! -e "$TEMP/externa-app6/opcoes.conf"
test "$(cat "$TEMP/externa-app6/pessoal.txt")" = 'DOCUMENTO INTACTO'

echo 'OK: diretório interno/externo, Ctrl+V, caminhos e cancelamento testados.'
