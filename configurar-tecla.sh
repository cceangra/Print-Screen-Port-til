#!/usr/bin/env bash
# Print RC: consultar e configurar a tecla Print sem reinstalar.
set -Eeuo pipefail
PRC_ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)/scripts/i18n.sh"
BASE="$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)"
DESKTOP="${XDG_CURRENT_DESKTOP:-}"
DESKTOP="${DESKTOP,,}"
BIN="$BASE/bin/print-rc"

header() {
    printf '\n===========================================\n'
    prc_format shell.170
    printf '===========================================\n'
    prc_format shell.171 "${XDG_CURRENT_DESKTOP:-desconhecido}" "${XDG_SESSION_TYPE:-desconhecida}"
}
sim() {
    local resposta
    printf '%s%s' "$1" "$(prc_text common.confirm)"
    IFS= read -r resposta || return 1
    case "${resposta,,}" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}
verificar() {
    header
    echo
    prc_message shell.172
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" inspect --base "$BASE"
    elif [[ "$DESKTOP" == *xfce* ]]; then
        python3 -B "$BASE/scripts/atalho_xfce.py" inspect --base "$BASE"
    else
        prc_message shell.173
        prc_message shell.174
    fi
    echo
    prc_message shell.175
    local status=0
    "$BIN" --verificar-tecla || status=$?
    case "$status" in
      0) prc_message shell.176 ;;
      6) prc_message shell.177 ;;
      *) prc_message shell.178 ;;
    esac
    prc_message shell.179
    prc_message shell.180
}
ler_tecla() {
    # Apenas o nome da tecla sai em stdout para nao confundir $(...).
    local bruto codigo tent=1 resposta
    while true; do
        prc_format shell.181 "$tent" >&2
        if bruto="$("$BIN" --detectar-print)"; then
            if [[ "$bruto" =~ ^PRINT_RC_KEY=([A-Za-z0-9_]{1,64})$ ]]; then
                local escolhida="${BASH_REMATCH[1]}"
                case "$escolhida" in
                  Escape|Shift_L|Shift_R|Control_L|Control_R|Alt_L|Alt_R|Meta_L|Meta_R|Super_L|Super_R|Hyper_L|Hyper_R|ISO_Level3_Shift|Mode_switch)
                      prc_message shell.182 >&2
                      return 3 ;;
                esac
                printf '%s\n' "$escolhida"
                return 0
            fi
            prc_message shell.183 >&2
            return 3
        else
            codigo=$?
        fi
        case "$codigo" in
          4)
             prc_format shell.184 >&2
             resposta=''
             if ! IFS= read -r resposta; then
                 prc_message shell.185 >&2
                 return 4
             fi
             case "${resposta,,}" in
               s|sim|y|yes) ((tent+=1)); continue ;;
               *) prc_message shell.186 >&2; return 4 ;;
             esac ;;
          5) prc_message shell.187 >&2; return 5 ;;
          *) prc_message shell.188 >&2; return "$codigo" ;;
        esac
    done
}
configurar() {
    header
    if [[ "${XDG_SESSION_TYPE:-x11}" != x11 ]]; then
        prc_message shell.189
        return 2
    fi
    if [[ "$DESKTOP" != *trinity* && "$DESKTOP" != *xfce* ]]; then
        prc_message shell.190
        prc_message shell.191 "$BASE"
        return 2
    fi
    local tecla
    if ! tecla="$(ler_tecla)"; then return 1; fi
    echo
    prc_message shell.192 "$tecla"
    prc_message shell.193
    prc_message shell.194
    prc_message shell.195
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh" --key "$tecla"
    else
        python3 -B "$BASE/scripts/atalho_xfce.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh" --key "$tecla"
    fi
    echo
    prc_message shell.196 "$tecla"
    if [[ -n "${DISPLAY:-}" && -t 0 ]]; then
        if ! bash "$BASE/scripts/provar-atalho.sh" "$tecla"; then
            prc_message shell.197
        fi
    else
        prc_message shell.198
    fi
}
provar() {
    if [[ ! -f "$BASE/scripts/provar-atalho.sh" ]]; then
        prc_message shell.199
        return 2
    fi
    bash "$BASE/scripts/provar-atalho.sh"
}
liberar() {
    header
    prc_message shell.200
    prc_message shell.201
    prc_message shell.202
    if ! sim 'Confirma desfazer o atalho do Print RC?'; then
        prc_message shell.203
        return 0
    fi
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" remove --base "$BASE"
    elif [[ "$DESKTOP" == *xfce* ]]; then
        python3 -B "$BASE/scripts/atalho_xfce.py" remove --base "$BASE"
    else
        prc_message shell.204
        return 2
    fi
}
if [[ $EUID == 0 ]]; then
    prc_message shell.205 >&2
    exit 2
fi
if [[ ! -x "$BIN" || ! -f "$BASE/iniciar.sh" ]]; then
    prc_message shell.206 >&2
    exit 2
fi
case "${1:-}" in
    --relocate) python3 -B "$BASE/scripts/relocate.py" --base "$BASE"; exit ;;
    --status) verificar; exit ;;
    --configurar) configurar; exit ;;
    --liberar) liberar; exit ;;
    --provar) provar; exit ;;
    --help|-h) prc_message shell.207; exit ;;
    '') ;;
    *) prc_message shell.208 >&2; exit 2 ;;
esac
while true; do
    header
    prc_message shell.209
    prc_message shell.210
    prc_message shell.211
    prc_message shell.212
    prc_message shell.213
    prc_format shell.214
    escolha=''
    IFS= read -r escolha || break
    case "$escolha" in
        1) verificar || true ;;
        2) configurar || true ;;
        3) liberar || true ;;
        4) provar || true ;;
        0) break ;;
        *) prc_message shell.215 ;;
    esac
done
prc_message shell.216
