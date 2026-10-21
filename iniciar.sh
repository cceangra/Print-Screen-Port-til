#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ ${XDG_SESSION_TYPE:-x11} == x11 ]] || { echo 'Print RC 0.5.4 requer uma sessao X11.' >&2; exit 2; }
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
        if (set -C; umask 077; printf '%s\n' "$TOKEN" > "$RESPOSTA") 2>/dev/null; then
            exit 0
        fi
    fi
fi
exec "$BASE/bin/print-rc" "$@"
