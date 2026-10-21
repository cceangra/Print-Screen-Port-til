#!/usr/bin/env bash
set -euo pipefail
PRC_ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)/scripts/i18n.sh"
BASE="$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)"
case "${1:-}" in
  --diagnose) shift; exec bash "$BASE/diagnosticar.sh" "$@" ;;
  --version|--help|--self-test|--show-config|--build-info) ;;
  *) [[ ${XDG_SESSION_TYPE:-x11} == x11 ]] || { prc_message shell.296 >&2; exit 2; } ;;
esac
[[ "$(uname -m)" == x86_64 ]] || { prc_message shell.unsupported_arch >&2; exit 2; }
for rel in bin bin/print-rc bin/print-rc-launcher config config/opcoes.conf config/language; do
    [[ ! -L "$BASE/$rel" ]] || { prc_message shell.unsafe_path >&2; exit 2; }
done
if [[ -f "$BASE/runtime-target.conf" && ! -L "$BASE/runtime-target.conf" ]]; then
    required_glibc=''
    while IFS='=' read -r key value; do
        [[ "$key" != minimum_glibc ]] || required_glibc="$value"
    done < "$BASE/runtime-target.conf"
    if [[ "$required_glibc" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)*$ ]]; then
        need_major="${BASH_REMATCH[1]}";need_minor="${BASH_REMATCH[2]}"
        host_libc="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
        if [[ ! "$host_libc" =~ ^glibc[[:space:]]([0-9]+)\.([0-9]+) ]] ||
           (( BASH_REMATCH[1] < need_major || (BASH_REMATCH[1] == need_major && BASH_REMATCH[2] < need_minor) )); then
            prc_message shell.library_incompatible "$required_glibc" >&2;exit 2
        fi
    fi
fi
export PRINT_RC_CONFIG="$BASE/config/opcoes.conf"

# Resposta de prova SOMENTE quando a pessoa acabou de pedir teste de atalho.
# Marcador expira automaticamente: uma interrupcao nao bloqueia capturas futuras.
# Prova que o launcher foi executado, nao que a GUI de captura ficou visivel.
PROVA="$BASE/config/.print-rc-prova-armada"
RESPOSTA="$BASE/config/.print-rc-prova-resposta"
if [[ -f "$PROVA" && ! -L "$PROVA" && ! -e "$RESPOSTA" && ! -L "$RESPOSTA" ]]; then
    TOKEN=''
    VALIDADE=''
    { IFS= read -r TOKEN; IFS= read -r VALIDADE; } < "$PROVA" || true
    AGORA="$(date +%s)"
    if [[ "$TOKEN" == print-rc-* && "$VALIDADE" =~ ^[0-9]+$ ]] &&
       (( AGORA <= VALIDADE )); then
        # noclobber: nao sobrescreve arquivos externos nem respostas preexistentes.
        # A successful process exit alone is not proof of a rendered overlay.
        if ! OUTPUT="$("$BASE/bin/print-rc-launcher" "$BASE/bin/print-rc" --probe-overlay "$TOKEN")"; then
            exit 1
        fi
        [[ "$OUTPUT" == "PRINT_RC_OVERLAY_READY=$TOKEN" ]] || exit 1
        if (set -C; umask 077; printf '%s\n' "$TOKEN" > "$RESPOSTA") 2>/dev/null; then
            exit 0
        fi
    fi
fi
exec "$BASE/bin/print-rc-launcher" "$BASE/bin/print-rc" "$@"
