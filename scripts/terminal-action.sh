#!/usr/bin/env bash
# Used only by the native entrypoint's interactive setup/configuration actions.
set -uo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$BASE/scripts/i18n.sh"
action="${1:-}"
shift || exit 2
case "$action" in
    "$BASE/instalar.sh"|"$BASE/configurar.sh"|"$BASE/configurar-tecla.sh"|"$BASE/desinstalar.sh"|"$BASE/iniciar.sh") ;;
    *) exit 2 ;;
esac
bash "$action" "$@"
result=$?
if [[ -t 0 ]]; then
    prc_message shell.terminal_finished "$result"
    read -r -p "$(prc_text shell.terminal_close)" ignored || true
fi
exit "$result"
