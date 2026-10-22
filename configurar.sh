#!/usr/bin/env bash
# Print RC: configuracao interativa SEM pacotes externos.
set -Eeuo pipefail
PRC_ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)/scripts/i18n.sh"
[[ ${EUID} -ne 0 ]] || { prc_message shell.122; exit 1; }

BASE="$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)"
CONFIG="$BASE/config/opcoes.conf"
DEFAULT_DIR="$BASE/capturas"

if [[ "${1:-}" == --language || "${1:-}" == --idioma ]]; then
    case "${2:-}" in en-US|en_US|en) chosen_language=en-US ;; pt-BR|pt_BR|pt) chosen_language=pt-BR ;;
      *) prc_message language.usage; exit 2 ;;
    esac
    [[ ! -L "$BASE/config" && ! -L "$BASE/config/language" ]] || { prc_message shell.124; exit 2; }
    umask 077
    mkdir -p -- "$BASE/config"
    language_temp="$(mktemp "$BASE/config/.language-XXXXXXXX")"
    printf '%s\n' "$chosen_language" > "$language_temp"
    mv -T -- "$language_temp" "$BASE/config/language"
    if [[ -f "$BASE/config/arquivos-instalados.sha256" ]]; then
        python3 -B "$BASE/scripts/lifecycle.py" track --base "$BASE" --file config/language
    fi
    PRC_LANGUAGE="$chosen_language"
    prc_message language.saved "$chosen_language"
    exit 0
fi

# Configuracao deve ficar dentro da pasta real do app.
# Links poderiam direcionar a gravacao de arquivos para locais externos.
for relative in config config/opcoes.conf capturas; do
    if [[ -L "$BASE/$relative" ]]; then
        prc_message shell.123 "$BASE" "$relative"
        prc_message shell.124
        exit 2
    fi
done

echo '===================================================='
prc_message shell.125
echo '===================================================='
prc_message shell.126
echo "  $CONFIG"
prc_message shell.127
prc_message shell.128
prc_message shell.129
echo
prc_message shell.130 "$DEFAULT_DIR"
PREVIOUS_DIR=''
PREVIOUS_CLIP=''
if [[ -f "$CONFIG" && ! -L "$CONFIG" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            save_dir=*) PREVIOUS_DIR="${line#save_dir=}"; prc_message shell.131 "$PREVIOUS_DIR" ;;
            copy_clipboard=1) PREVIOUS_CLIP=1; prc_message shell.132 ;;
            copy_clipboard=0) PREVIOUS_CLIP=0; prc_message shell.133 ;;
        esac
    done < "$CONFIG"
fi

prc_message shell.134
read -r -p "$(prc_text shell.135)" supplied || true
TARGET="${supplied:-${PREVIOUS_DIR:-$DEFAULT_DIR}}"
if [[ "$TARGET" != /* || "$TARGET" == *$'\n'* || "$TARGET" == *$'\r'* ]]; then
    prc_message shell.136
    prc_message shell.137
    exit 2
fi
DIR="$(realpath -m -- "$TARGET")"
case "$DIR" in
    /|"$HOME"|"$BASE")
        prc_message shell.138
        exit 2;;
esac
if [[ "$DIR" != "$BASE/"* ]]; then
    echo
    prc_message shell.139
    prc_message shell.140 "$DIR"
    prc_message shell.141
    read -r -p "$(prc_text shell.142)" confirm || true
    [[ "${confirm,,}" == s || "${confirm,,}" == sim || "${confirm,,}" == y || "${confirm,,}" == yes ]] || {
        prc_message shell.143; exit 1;
    }
else
    prc_message shell.144 "$DIR"
fi

CREATE_DIR=0
if [[ -e "$DIR" ]]; then
    [[ -d "$DIR" && -w "$DIR" && -x "$DIR" ]] || {
        prc_message shell.145 "$DIR"
        exit 2
    }
else
    prc_message shell.146 "$DIR"
    prc_message shell.147
    CREATE_DIR=1
fi

echo
prc_message shell.148
prc_message shell.149
prc_message shell.150
prc_message shell.151
while :; do
    read -r -p "$(prc_text shell.152)" choice || true
    case "${choice,,}" in
        '') CLIP="${PREVIOUS_CLIP:-1}"; break ;;
        s|sim|y|yes) CLIP=1; break ;;
        n|nao|não) CLIP=0; break ;;
        *) prc_message shell.153 ;;
    esac
done

echo
prc_message shell.154
prc_message shell.155 "$DIR"
if [[ "$CLIP" == 1 ]]; then prc_message shell.156; else prc_message shell.157; fi
prc_message shell.158 "$CONFIG"
prc_message shell.159
echo '============================================='
read -r -p "$(prc_text shell.160)" confirm || true
[[ "${confirm,,}" == s || "${confirm,,}" == sim || "${confirm,,}" == y || "${confirm,,}" == yes ]] || {
    prc_message shell.161; exit 1;
}
umask 077
if [[ "$CREATE_DIR" == 1 ]]; then
    mkdir -p -- "$DIR"
    prc_message shell.162 "$DIR"
fi
mkdir -p -- "$BASE/config"
temp="$(mktemp "$BASE/config/.opcoes-XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
printf 'save_dir=%s\ncopy_clipboard=%s\n' "$DIR" "$CLIP" > "$temp"
if [[ "$DIR" == "$BASE/"* ]]; then
    printf 'save_dir_relative=%s\n' "${DIR#"$BASE/"}" >> "$temp"
fi
# O inventario precisa acompanhar preferencias gravadas pelo PROPRIO app,
# senao a desinstalacao deixa config/opcoes.conf e a pasta principal para tras.
if [[ -f "$BASE/config/arquivos-instalados.sha256" ]]; then
    if [[ ! -f "$BASE/scripts/inventario.sh" || -L "$BASE/scripts/inventario.sh" ]]; then
        prc_message shell.163 >&2
        exit 2
    fi
    source "$BASE/scripts/inventario.sh"
fi
mv -f -- "$temp" "$CONFIG"
trap - EXIT
if [[ -f "$BASE/config/arquivos-instalados.sha256" ]]; then
    if ! print_rc_atualizar_inventario_opcoes "$BASE"; then
        prc_message shell.164 >&2
        prc_message shell.165 >&2
        exit 2
    fi
fi
echo
prc_message shell.166
prc_message shell.167 "$CONFIG"
prc_message shell.168 "$DIR"
prc_message shell.169
