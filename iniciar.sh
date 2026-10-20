#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ ${XDG_SESSION_TYPE:-x11} == x11 ]] || { echo 'Print RC 0.1.0 so funciona em X11.' >&2; exit 2; }
export PRINT_RC_CONFIG="$BASE/config/opcoes.conf"
exec "$BASE/bin/print-rc" "$@"
