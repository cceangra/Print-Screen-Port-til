#!/usr/bin/env bash
# Native Bash lookup for short-lived setup helpers. No eval or Python subprocess.
if [[ ${PRC_I18N_LOADED:-0} != 1 ]]; then
    PRC_I18N_LOADED=1
    PRC_APP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
    source "$PRC_APP_ROOT/scripts/messages.bash"
    PRC_LANGUAGE="${PRINT_RC_LANG:-}"
    if [[ -z "$PRC_LANGUAGE" && -f "$PRC_APP_ROOT/config/language" && ! -L "$PRC_APP_ROOT/config/language" && ! -L "$PRC_APP_ROOT/config" ]]; then
        IFS= read -r PRC_LANGUAGE < "$PRC_APP_ROOT/config/language" || true
    fi
    PRC_LANGUAGE="${PRC_LANGUAGE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en-US}}}}"
    case "${PRC_LANGUAGE,,}" in pt|pt_*|pt-*|pt.*) PRC_LANGUAGE=pt-BR ;; *) PRC_LANGUAGE=en-US ;; esac
    export PRINT_RC_LANG="$PRC_LANGUAGE"
fi
prc_text() {
    local key="$1" value part index=0 token
    shift
    if [[ "$PRC_LANGUAGE" == pt-BR ]]; then value="${PRC_MESSAGES_PT[$key]:-$key}"
    else value="${PRC_MESSAGES_EN[$key]:-$key}"; fi
    for part in "$@"; do
        token="{$index}"
        value="${value//"$token"/"$part"}"
        ((index+=1))
    done
    printf '%s' "$value"
}
prc_message() { prc_text "$@"; printf '\n'; }
prc_format() { local format;format="$(prc_text "$1")";shift;printf -- "$format" "$@"; }
prc_yes() { case "${1,,}" in 1|y|yes|s|sim) return 0 ;; *) return 1 ;; esac; }
