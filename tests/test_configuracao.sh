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

echo '[7] Configuracao iniciante aceita escolhas numeradas'
mkdir -p "$TEMP/app7"
cp "$ROOT/configurar.sh" "$TEMP/app7/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app7/"
printf '1\n1\n1\n' | bash "$TEMP/app7/configurar.sh" > "$TEMP/numeros.log" 2>&1
grep -Fx "save_dir=$TEMP/app7/capturas" "$TEMP/app7/config/opcoes.conf"
grep -Fx 'copy_clipboard=1' "$TEMP/app7/config/opcoes.conf"

echo '[8] Resposta desconhecida na confirmacao pede novamente; NAO encerra sem salvar'
mkdir -p "$TEMP/app8"
cp "$ROOT/configurar.sh" "$TEMP/app8/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app8/"
if printf '1\n2\nresposta-invalida\n2\n' | bash "$TEMP/app8/configurar.sh" > "$TEMP/invalido.log" 2>&1; then
  echo 'ERRO: salvou sem confirmacao';exit 1
fi
grep -F 'Digite 1 para Sim ou 2 para Não' "$TEMP/invalido.log"
test ! -e "$TEMP/app8/config/opcoes.conf"
test ! -e "$TEMP/app8/capturas"

echo '[9] Fim da entrada antes da confirmacao nao cria preferencias'
mkdir -p "$TEMP/app9"
cp "$ROOT/configurar.sh" "$TEMP/app9/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app9/"
if printf '1\n1\n' | bash "$TEMP/app9/configurar.sh"; then
  echo 'ERRO: salvou sem uma resposta explicita';exit 1
fi
test ! -e "$TEMP/app9/config/opcoes.conf"

echo '[10] Menu permite trocar idioma sem digitar comandos nem mudar imagens'
mkdir -p "$TEMP/app10"
cp "$ROOT/configurar.sh" "$TEMP/app10/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app10/"
printf '3\n2\n0\n' | bash "$TEMP/app10/configurar.sh" --menu > "$TEMP/menu.log" 2>&1
grep -Fx en-US "$TEMP/app10/config/language"
grep -F 'WHAT WOULD YOU LIKE TO CHANGE?' "$TEMP/menu.log"
test ! -e "$TEMP/app10/config/opcoes.conf"

echo '[11] Manter pasta interna usa o local atual depois de mover o aplicativo'
mkdir -p "$TEMP/app11/config"
cp "$ROOT/configurar.sh" "$TEMP/app11/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app11/"
printf 'save_dir=%s\ncopy_clipboard=0\nsave_dir_relative=capturas\n' "$TEMP/pasta-antiga/capturas" > "$TEMP/app11/config/opcoes.conf"
printf '1\n\n1\n' | bash "$TEMP/app11/configurar.sh" > "$TEMP/movida.log" 2>&1
grep -Fx "save_dir=$TEMP/app11/capturas" "$TEMP/app11/config/opcoes.conf"
grep -Fx 'copy_clipboard=0' "$TEMP/app11/config/opcoes.conf"
test ! -e "$TEMP/pasta-antiga"

echo '[12] Alterar pasta atualiza o manifesto de uma instalacao existente'
mkdir -p "$TEMP/app12/config" "$TEMP/app12/capturas" "$TEMP/fotos12"
cp "$ROOT/configurar.sh" "$ROOT/desinstalar.sh" "$TEMP/app12/"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$TEMP/app12/"
printf 'PRINT-RC\n%s\n' "$TEMP/app12" > "$TEMP/app12/.print-rc-installation"
printf 'save_dir=%s\ncopy_clipboard=1\nsave_dir_relative=capturas\n' "$TEMP/app12/capturas" > "$TEMP/app12/config/opcoes.conf"
python3 -B "$TEMP/app12/scripts/lifecycle.py" record --base "$TEMP/app12"
source "$ROOT/scripts/inventario.sh"
print_rc_criar_inventario "$TEMP/app12"
printf '2\n%s\n1\n2\n1\n' "$TEMP/fotos12" | bash "$TEMP/app12/configurar.sh" > "$TEMP/manifesto.log" 2>&1
python3 -B - "$TEMP/app12" "$TEMP/fotos12" <<'PY'
import json,sys
from pathlib import Path
app=Path(sys.argv[1]);destination=json.loads((app/'config/installation-manifest.json').read_text())['capture_destination']
assert destination['path']==sys.argv[2]
assert destination['inside_application'] is False
assert destination['delete_on_uninstall'] is False
assert 'copy_clipboard=0' in (app/'config/opcoes.conf').read_text()
PY
