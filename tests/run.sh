#!/usr/bin/env bash
# Run as an ordinary user on an isolated build/test machine, never a live desktop.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$ROOT"
export PRINT_RC_LANG=pt-BR PYTHONDONTWRITEBYTECODE=1 XDG_SESSION_TYPE=x11
bash -n ./*.sh scripts/*.sh tests/*.sh
python3 -B -m unittest discover -s tests -v
./bin/print-rc --self-test
./bin/print-rc --version
bash tests/test_launcher.sh
for test in test_instalacao test_configurar_tecla test_prova_atalho test_xfce_integracao test_desinstalacao test_packaged_ownership test_configuracao; do
    bash "tests/$test.sh"
done
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
mkdir -p "$TEMP/images"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$TEMP/images" > "$TEMP/options"
export PRINT_RC_CONFIG="$TEMP/options"
g++ -std=c++17 -O2 -Wall -Wextra tests/test_settings.cpp -o "$TEMP/settings"
"$TEMP/settings"
g++ -std=c++17 -O2 -Wall -Wextra tests/test_keyboard_grab.cpp -o "$TEMP/keyboard" $(pkg-config --cflags --libs x11)
g++ -std=c++17 -O2 -Wall -Wextra tests/test_overlay_ready.cpp -o "$TEMP/overlay" $(pkg-config --cflags --libs x11)
for depth in 16 24; do
    for locale in en-US pt-BR; do
        PRINT_RC_LANG="$locale" timeout 20s xvfb-run -a -s "-screen 0 1024x768x$depth" "$TEMP/overlay" "$ROOT/bin/print-rc"
    done
done
for depth in 16 24; do
    timeout 25s xvfb-run -a -s "-screen 0 301x173x$depth" bash tests/test_visual_png.sh
done
# 32-bit root depth is not offered by all Xvfb builds. 24-depth/32-bpp is exercised above.
for test in test_gui_x11 test_undo_x11 test_clipboard_x11 test_clipboard_limits_x11 test_detectar_print_x11 test_desinstalacao_processo_x11; do
    timeout 90s xvfb-run -a -s '-screen 0 1024x768x24' bash "tests/$test.sh"
done
timeout 25s xvfb-run -a -s '-screen 0 1024x768x24' "$TEMP/keyboard" "$ROOT/bin/print-rc"
echo 'PASS: packaged X11 core and simulated desktop regressions; real desktop acceptance remains separate'
