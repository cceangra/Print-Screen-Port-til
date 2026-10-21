#!/usr/bin/env bash
# Run only inside dbus-run-session + an isolated Xvfb, never an existing desktop.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP="$1";LEGACY="$2";ORIGINAL_DYNAMIC="$3";EVIDENCE="$4"
export XDG_CURRENT_DESKTOP=XFCE XDG_SESSION_TYPE=x11 PRINT_RC_LANG=en-US
mkdir -p "$APP/config" "$APP/capturas" "$EVIDENCE"
printf 'save_dir=%s\ncopy_clipboard=0\nsave_dir_relative=capturas\n' "$APP/capturas" > "$APP/config/opcoes.conf"
xfsettingsd --no-daemon > "$EVIDENCE/xfsettingsd.log" 2>&1 &
settings_pid=$!
trap 'kill "$settings_pid" 2>/dev/null || true' EXIT
# Wait for provider construction, which clones defaults before setting this flag.
# A queryable xfconfd channel alone is not proof that xfsettingsd finished startup.
for attempt in {1..100}; do
    if [[ "$(xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/override 2>/dev/null || true)" == true ]]; then break; fi
    sleep 0.1
done
test "$(xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/override)" = true
kill -0 "$settings_pid"
set_property() {
    if xfconf-query -c xfce4-keyboard-shortcuts -p "$1" >/dev/null 2>&1; then
        xfconf-query -c xfce4-keyboard-shortcuts -p "$1" -s "$2"
    else
        xfconf-query -c xfce4-keyboard-shortcuts -p "$1" -n -t string -s "$2"
    fi
}
set_property /commands/custom/Print user-print-preserved
set_property /commands/custom/Insert user-insert-preserved
printf 'y\n' | python3 -B "$APP/scripts/atalho_xfce.py" install --base "$APP" --launcher "$APP/iniciar.sh" --key Insert
# Existing Print must remain independent of Insert.
test "$(xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Print)" = user-print-preserved
sleep 1 # allow the isolated daemon to process its first configuration signals
bash "$APP/scripts/provar-atalho.sh" Insert > "$EVIDENCE/shortcut-proof.log" 2>&1 &
proof_pid=$!
for attempt in {1..100}; do
    [[ -f "$APP/config/.print-rc-prova-armada" ]] && break
    sleep 0.03
done
xdotool key Insert
wait "$proof_pid"
grep -F 'OVERLAY_VERIFIED:' "$EVIDENCE/shortcut-proof.log"
g++ -std=c++17 -O2 "$ROOT/tests/performance/x11_driver.cpp" -o "$EVIDENCE/driver" $(pkg-config --cflags --libs x11)
xdotool key Insert
"$EVIDENCE/driver" wait >/dev/null
"$EVIDENCE/driver" full
for attempt in {1..100}; do
    photos=("$APP/capturas/"*.png)
    [[ -f "${photos[0]}" ]] && break
    sleep 0.05
done
python3 - "$APP/capturas" <<'PY'
from pathlib import Path
import struct,sys
photos=list(Path(sys.argv[1]).glob('*.png'));assert len(photos)==1
png=photos[0].read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II',png[16:24])==(1024,768)
print('PASS: actual xfsettingsd Insert shortcut opened an overlay and saved a PNG')
PY
python3 -B "$APP/scripts/atalho_xfce.py" remove --base "$APP"
test "$(xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Insert)" = user-insert-preserved
test "$(xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Print)" = user-print-preserved
printf '%s\n' 'PASS: real xfsettingsd/xfconf Insert launch, nonce/render proof, PNG and restoration; Print preserved' > "$EVIDENCE/xfce-result.txt"
# Same-source dynamic original vs shipped static original, with host libXcursor present.
export PRINT_RC_CONFIG="$APP/config/opcoes.conf"
"$EVIDENCE/driver" paint
"$ORIGINAL_DYNAMIC" > "$EVIDENCE/original-dynamic.log" 2>&1 &
dynamic_pid=$!
"$EVIDENCE/driver" wait >/dev/null
"$EVIDENCE/driver" cancel
wait "$dynamic_pid"
printf '%s\n' 'PASS: unchanged v0.5.6 source dynamically linked on glibc 2.35 mapped/drew and cancelled' > "$EVIDENCE/original-dynamic-result.txt"
timeout 20s gdb -q -batch -ex 'set pagination off' -ex 'set debuginfod enabled off' -ex run -ex 'thread apply all bt' -ex 'info registers' -ex 'info sharedlibrary' --args "$LEGACY" > "$EVIDENCE/legacy-gdb.log" 2>&1 &
debug_pid=$!
if timeout 12s "$EVIDENCE/driver" wait >/dev/null 2>&1; then
    "$EVIDENCE/driver" cancel
fi
wait "$debug_pid" || true
if grep -q SIGFPE "$EVIDENCE/legacy-gdb.log"; then
    printf '%s\n' 'SIGFPE_REPRODUCED in the Ubuntu 22.04/Xvfb/xfsettingsd substitute; inspect legacy-gdb.log. This is not Zorin desktop certification.' > "$EVIDENCE/legacy-result.txt"
else
    printf '%s\n' 'SIGFPE_NOT_REPRODUCED_OR_DEBUGGER_UNAVAILABLE in this substitute. No exact Zorin repair claim.' > "$EVIDENCE/legacy-result.txt"
fi
cat "$EVIDENCE/xfce-result.txt" "$EVIDENCE/original-dynamic-result.txt" "$EVIDENCE/legacy-result.txt"
