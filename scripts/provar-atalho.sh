#!/usr/bin/env bash
# Print RC: prova REAL de acionamento do inicializador pelo atalho.
# Apos registro, pede uma segunda pressao de Print; nao captura imagens durante a prova.
# Arquivos temporarios ficam apenas na pasta do aplicativo, com limpeza por trap.
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/i18n.sh"
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FLAG="$BASE/config/.print-rc-prova-armada"
RESPONSE="$BASE/config/.print-rc-prova-resposta"
if [[ "${XDG_SESSION_TYPE:-x11}" != x11 || -z "${DISPLAY:-}" ]]; then
    prc_message shell.283
    exit 2
fi
if [[ -L "$BASE/config" || -L "$BASE/iniciar.sh" ]]; then
    prc_message shell.unsafe_path
    exit 2
fi
if [[ ! -d "$BASE/config" || ! -f "$BASE/iniciar.sh" ]]; then
    prc_message shell.284
    exit 2
fi
if [[ -e "$FLAG" || -L "$FLAG" || -e "$RESPONSE" || -L "$RESPONSE" ]]; then
    prc_message shell.285
    exit 2
fi
# Evitar que a rotina atinja qualquer arquivo pessoal pré-existente.
umask 077
TOKEN="print-rc-${BASHPID}-$(date +%s)"
EXPIRY="$(($(date +%s)+14))"
cleanup() {
    # Os caminhos eram inexistentes antes da prova e ficam dentro do aplicativo.
    local path first
    for path in "$FLAG" "$RESPONSE"; do
        if [[ -f "$path" && ! -L "$path" ]]; then
            first=''; IFS= read -r first < "$path" || true
            [[ "$first" == "$TOKEN" ]] && rm -f -- "$path"
        fi
    done
    return 0
}
trap cleanup EXIT INT TERM
(set -C; printf '%s\n%s\n' "$TOKEN" "$EXPIRY" > "$FLAG") || exit 2
echo
prc_message shell.286
prc_message shell.287
TECLA="${1:-}"
if [[ ! "$TECLA" =~ ^[A-Za-z0-9_]{1,64}$ ]]; then
    TECLA="$(prc_text common.configured_key)"
fi
prc_message shell.288 "$TECLA"
prc_message shell.289
prc_message shell.290
echo '===================================='
PASSOS="${PRINT_RC_PROVA_PASSOS:-60}"
if [[ ! "$PASSOS" =~ ^[0-9]+$ ]] || (( PASSOS<1 || PASSOS>60 )); then
    PASSOS=60
fi
for ((n=0;n<PASSOS;n++)); do
    if [[ -f "$RESPONSE" && ! -L "$RESPONSE" ]]; then
        IFS= read -r got < "$RESPONSE" || true
        if [[ "$got" == "$TOKEN" ]]; then
            prc_message shell.291
            prc_message shell.292 "$TECLA"
            exit 0
        fi
    fi
    sleep 0.2
done
prc_message shell.293
prc_message shell.294
prc_message shell.295
exit 1
