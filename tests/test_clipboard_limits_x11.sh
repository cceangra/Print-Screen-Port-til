#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)";PID=''
trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf -- "$TEMP"' EXIT
mkdir -p "$TEMP/images"
printf 'save_dir=%s\ncopy_clipboard=1\n' "$TEMP/images" > "$TEMP/options"
export PRINT_RC_CONFIG="$TEMP/options"
g++ -std=c++17 -O2 "$ROOT/tests/performance/x11_driver.cpp" -o "$TEMP/driver" $(pkg-config --cflags --libs x11)
g++ -std=c++17 -O2 "$ROOT/tests/paint_test_pattern.cpp" -o "$TEMP/noise" $(pkg-config --cflags --libs x11)
g++ -std=c++17 -O2 "$ROOT/tests/test_clipboard_limits.cpp" -o "$TEMP/limits" $(pkg-config --cflags --libs x11)
"$TEMP/noise"
"$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 & PID=$!
"$TEMP/driver" wait >/dev/null;"$TEMP/driver" full
for i in {1..100}; do
    files=("$TEMP/images/"*.png)
    [[ -f "${files[0]}" ]] && break
    sleep 0.1
done
test "$(stat -c %s "${files[0]}")" -gt 65536
"$TEMP/limits"
kill "$PID";wait "$PID" || true;PID=''
