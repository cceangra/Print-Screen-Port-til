#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
APP="$TEMP/Print RC (ç)"
mkdir -p "$APP"
cp -a "$ROOT/bin" "$ROOT/scripts" "$ROOT/i18n" "$ROOT/src" "$APP/"
cp "$ROOT/instalar.sh" "$ROOT/configurar.sh" "$ROOT/configurar-tecla.sh" "$ROOT/iniciar.sh" "$ROOT/desinstalar.sh" "$APP/"
# Explicit English override exercises all installer text and English confirmation words.
printf '\n\nn\ny\n' | PRINT_RC_LANG=en-US XDG_CURRENT_DESKTOP=Unknown XDG_SESSION_TYPE=x11 bash "$APP/instalar.sh" > "$TEMP/install.log" 2>&1
grep -F 'FILES CONFIGURED.' "$TEMP/install.log"
! grep -Fq 'Pasta das imagens:' "$TEMP/install.log"
PRINT_RC_LANG=en-US bash "$APP/configurar.sh" --language pt-BR
# The persisted locale must outrank an English process locale when no explicit override exists.
env -u PRINT_RC_LANG LANG=C.UTF-8 bash "$APP/iniciar.sh" --show-config > "$TEMP/pt.log"
grep -F 'Copiar para Ctrl+V: NAO' "$TEMP/pt.log"
PRINT_RC_LANG=en-US bash "$APP/iniciar.sh" --show-config > "$TEMP/en.log"
grep -F 'Copy for Ctrl+V: NO' "$TEMP/en.log"
# Saving a language preference must update ownership rather than orphaning config/language.
printf 'UNINSTALL\n' | PRINT_RC_LANG=en-US bash "$APP/desinstalar.sh" > "$TEMP/uninstall.log" 2>&1
test ! -e "$APP/config/language"
test ! -e "$APP/bin/print-rc"
echo 'PASS: English installer/uninstaller, Portuguese persistence, explicit English override and owned language cleanup'
