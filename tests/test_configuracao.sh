#!/usr/bin/env bash
# Testes isolados de configuracao, sem tocar no HOME do usuario.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT

echo '[1] Pasta interna padrao + Ctrl+V ligado'
mkdir -p "$TEMP/app1"
cp "$ROOT/configurar.sh" "$TEMP/app1/"
printf '\n\ns\n' | bash "$TEMP/app1/configurar.sh"
grep -Fx "save_dir=$TEMP/app1/capturas" "$TEMP/app1/config/opcoes.conf"
grep -Fx 'copy_clipboard=1' "$TEMP/app1/config/opcoes.conf"
test -d "$TEMP/app1/capturas"
PRINT_RC_CONFIG="$TEMP/app1/config/opcoes.conf" "$ROOT/bin/print-rc" --show-config | grep -F 'Copiar para Ctrl+V: SIM'

echo '[2] Diretorio externo com espacos + Ctrl+V desligado'
mkdir -p "$TEMP/app2" "$TEMP/imagens externas"
cp "$ROOT/configurar.sh" "$TEMP/app2/"
printf '%s\ns\nn\ns\n' "$TEMP/imagens externas" | bash "$TEMP/app2/configurar.sh"
grep -Fx "save_dir=$TEMP/imagens externas" "$TEMP/app2/config/opcoes.conf"
grep -Fx 'copy_clipboard=0' "$TEMP/app2/config/opcoes.conf"
PRINT_RC_CONFIG="$TEMP/app2/config/opcoes.conf" "$ROOT/bin/print-rc" --show-config | grep -F 'Copiar para Ctrl+V: NAO'

echo '[3] Cancelar diretorio externo novo NAO deixa residuo'
mkdir -p "$TEMP/app3"
cp "$ROOT/configurar.sh" "$TEMP/app3/"
if printf '%s\ns\nn\nn\n' "$TEMP/external naocriar" | bash "$TEMP/app3/configurar.sh"; then
  echo 'ERRO: configuracao aceita com resposta NAO';exit 1
fi
test ! -e "$TEMP/external naocriar"
test ! -e "$TEMP/app3/config/opcoes.conf"

echo '[4] Nao aceitar caminho relativo nem criar pastas'
mkdir -p "$TEMP/app4"
cp "$ROOT/configurar.sh" "$TEMP/app4/"
if printf 'Imagens/Print\n' | bash "$TEMP/app4/configurar.sh"; then
  echo 'ERRO: aceitou caminho relativo';exit 1
fi
test ! -e "$TEMP/app4/config/opcoes.conf"

echo 'OK: diretório interno/externo, Ctrl+V, caminhos e cancelamento testados.'
