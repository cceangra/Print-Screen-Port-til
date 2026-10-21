#!/usr/bin/env bash
set -euo pipefail
ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
BASE="$(cd -- "$(dirname -- "$ENTRY")" && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1
exec python3 -B "$BASE/scripts/diagnose.py" "$@"
