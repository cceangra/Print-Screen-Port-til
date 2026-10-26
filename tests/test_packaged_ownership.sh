#!/usr/bin/env bash
# Initial ownership must not claim a packaged file modified before installation.
set -euo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
APP="$TEMP/Print RC"
mkdir -p "$APP/config" "$APP/capturas" "$APP/bin"
cp -a "$ROOT/scripts" "$ROOT/i18n" "$APP/"
cp "$ROOT/desinstalar.sh" "$ROOT/Print-RC" "$ROOT/Instalar" "$ROOT/Instalar.desktop" "$APP/"
printf 'application binary\n' > "$APP/bin/print-rc"
printf 'original readme\n' > "$APP/README.md"
printf 'PRINT-RC\n%s\n' "$APP" > "$APP/.print-rc-installation"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$APP/capturas" > "$APP/config/opcoes.conf"
python3 - "$APP" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);entries={}
for path in root.rglob('*'):
 if path.is_file():entries[path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
(root/'package-files.json').write_text(json.dumps({'schema':1,'files':entries}))
PY
printf 'personal notes saved before installation\n' > "$APP/README.md"
printf 'personal photo\n' > "$APP/capturas/photo.png"
source "$ROOT/scripts/inventario.sh"
print_rc_criar_inventario "$APP"
if grep -Fq $'\tREADME.md' "$APP/config/arquivos-instalados.sha256"; then
    echo 'ERROR: initial inventory claimed a modified personal file';exit 1
fi
printf 'DESINSTALAR\n' | bash "$APP/desinstalar.sh"
test "$(cat "$APP/README.md")" = 'personal notes saved before installation'
test "$(cat "$APP/capturas/photo.png")" = 'personal photo'
test ! -e "$APP/bin/print-rc"
test ! -e "$APP/Print-RC"
test ! -e "$APP/Instalar"
test ! -e "$APP/Instalar.desktop"
echo 'PASS: pre-install modified files and images preserved; original packaged files removed'
