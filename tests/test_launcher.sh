#!/usr/bin/env bash
set -euo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
cat > "$TEMP/fatal" <<'SH'
#!/bin/bash
kill -FPE "$$"
SH
chmod +x "$TEMP/fatal"
ulimit -c 0
status=0
"$ROOT/bin/print-rc-launcher" "$TEMP/fatal" > "$TEMP/output" 2>&1 || status=$?
test "$status" -eq 136
grep -F 'FATAL_SIGNAL=8' "$TEMP/output"
grep -F 'OVERLAY_READY=no' "$TEMP/output"
status=0
"$ROOT/bin/print-rc-launcher" "$TEMP/missing" > "$TEMP/output" 2>&1 || status=$?
test "$status" -eq 127
grep -F 'EARLY_PROCESS_TERMINATION' "$TEMP/output"
mkdir "$TEMP/commands"
printf '#!/bin/bash\nprintf "DIALOG:%%s\\n" "$@"\n' > "$TEMP/commands/zenity"
chmod +x "$TEMP/commands/zenity"
status=0
DISPLAY=:test PRINT_RC_GUI_ERRORS=1 PATH="$TEMP/commands:$PATH" "$ROOT/bin/print-rc-launcher" "$TEMP/missing" > "$TEMP/output" 2>&1 || status=$?
test "$status" -eq 127
grep -F 'DIALOG:' "$TEMP/output"
grep -F '127' "$TEMP/output"
echo 'PASS: native launcher reports actual signals and exec failure'
