#!/usr/bin/env bash
# Print RC - remocao seletiva; NUNCA remove capturas nem dados pessoais.
set -Eeuo pipefail
PRC_ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)/scripts/i18n.sh"
[[ $EUID -ne 0 ]] || { prc_message shell.217; exit 1; }

BASE="$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)"
MARKER="$BASE/.print-rc-installation"
if [[ ! -f "$MARKER" || -L "$MARKER" ]]; then
    prc_message shell.218; exit 2
fi
mapfile -t marker < "$MARKER"
if [[ ${marker[0]:-} != PRINT-RC || ${marker[1]:-} != "$BASE" ]]; then
    prc_message shell.219; exit 2
fi
case "$BASE" in
    /|"$HOME"|/home|/usr|/usr/local|/tmp|/var)
        prc_message shell.220; exit 2;;
esac

# Um diretorio simbolico poderia apontar para dados externos. Recusar.
for dir in bin config backups capturas src scripts tests .github .github/workflows; do
    if [[ -L "$BASE/$dir" ]]; then
        prc_message shell.221 "$BASE" "$dir"
        prc_message shell.222
        exit 2
    fi
done
STATE="$BASE/config/atalho-state.json"
STATE_XFCE="$BASE/config/atalho-xfce.json"
if [[ -L "$STATE_XFCE" ]]; then
    prc_message shell.223
    exit 2
fi
if [[ -L "$STATE" ]]; then
    prc_message shell.224
    exit 2
fi
TRINITY_HOME="${TDEHOME:-$HOME/.trinity}"
EXTERNAL="$TRINITY_HOME/share/config/khotkeysrc"
OPTIONS="$BASE/config/opcoes.conf"
IMAGE_DIR=''
if [[ -f "$OPTIONS" && ! -L "$OPTIONS" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in save_dir=*) IMAGE_DIR="${line#save_dir=}" ;; esac
    done < "$OPTIONS"
fi

echo '======================================================'
prc_message shell.225
echo '======================================================'
prc_message shell.226 "$BASE"
python3 -B "$BASE/scripts/lifecycle.py" external-summary --base "$BASE" || exit 2
echo
prc_message shell.227
prc_message shell.228
prc_message shell.229
prc_message shell.230
if [[ -n "$IMAGE_DIR" ]]; then
    prc_message shell.231 "$IMAGE_DIR"
    prc_message shell.232
fi
if [[ -f "$STATE_XFCE" ]]; then
    prc_message shell.233
    prc_message shell.234
fi
if [[ -f "$STATE" ]]; then
    prc_message shell.235 "$EXTERNAL"
    prc_message shell.236
else
    prc_message shell.237
    prc_message shell.238
fi
echo
prc_message shell.239
prc_message shell.240
prc_message shell.241
prc_message shell.242
echo '======================================================'
read -r -p "$(prc_text shell.243)" response || true
[[ "$response" == DESINSTALAR || "$response" == UNINSTALL ]] || { prc_message shell.244; exit 1; }

if [[ -f "$BASE/scripts/lifecycle.py" && ! -L "$BASE/scripts/lifecycle.py" ]]; then
    python3 -B "$BASE/scripts/lifecycle.py" verify --base "$BASE" || exit 2
fi

# Encerrar somente processos deste executavel instalado, NUNCA processos de
# outros programas ou de outra copia do Print RC. Sem kill -9.
# Em Linux, /proc/PID/exe identifica o executavel carregado.
# Isso evita apagar binario ainda em uso e libera o clipboard mantido pelo app.
for proc_exe in /proc/[0-9]*/exe; do
    [[ -L "$proc_exe" ]] || continue
    if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" != "$BASE/bin/print-rc" ]]; then
        continue
    fi
    pid="${proc_exe#/proc/}"
    pid="${pid%%/*}"
    [[ -O "/proc/$pid" ]] || continue
    prc_message shell.245 "$pid"
    kill -TERM -- "$pid" 2>/dev/null || continue
    for attempt in {1..20}; do
        if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" != "$BASE/bin/print-rc" ]]; then
            break
        fi
        sleep 0.1
    done
    if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" == "$BASE/bin/print-rc" ]]; then
        prc_message shell.246
        exit 1
    fi
done

# Restaurar SOMENTE atalhos criados por esta instalacao, antes de
# remover os respectivos registros. Nunca apagar atalhos configurados a mao.
if [[ -f "$STATE_XFCE" ]]; then
    command -v python3 >/dev/null 2>&1 || {
        prc_message shell.247
        exit 1
    }
    if [[ ! -f "$BASE/scripts/atalho_xfce.py" || -L "$BASE/scripts/atalho_xfce.py" ]]; then
        prc_message shell.248
        exit 1
    fi
    python3 -B "$BASE/scripts/atalho_xfce.py" remove --base "$BASE" || {
        prc_message shell.249
        exit 1
    }
fi
if [[ -f "$STATE" ]]; then
    command -v python3 >/dev/null 2>&1 || {
        prc_message shell.250
        exit 1
    }
    if [[ ! -f "$BASE/scripts/atalho.py" || -L "$BASE/scripts/atalho.py" ]]; then
        prc_message shell.251
        exit 1
    fi
    python3 -B "$BASE/scripts/atalho.py" remove --base "$BASE" || {
        prc_message shell.252
        prc_message shell.253
        exit 1
    }
fi

# Somente arquivos com hash registrado na primeira instalacao podem ser excluidos.
# Se um arquivo mudou (ou foi substituido por foto/documento), permanece intocado.
MANIFEST="$BASE/config/arquivos-instalados.sha256"
if [[ ! -f "$MANIFEST" || -L "$MANIFEST" ]]; then
    prc_message shell.254
    prc_message shell.255
    prc_message shell.256
    exit 2
fi
if [[ ! -f "$BASE/scripts/inventario.sh" || -L "$BASE/scripts/inventario.sh" ]]; then
    prc_message shell.257
    exit 2
fi
source "$BASE/scripts/inventario.sh"
declare -A ALLOWED=()
declare -A EXPECTED=()
for rel in "${PRINT_RC_KNOWN[@]}"; do ALLOWED["$rel"]=1; done

# Derivar as pastas somente da lista fixa de arquivos conhecidos.
# Inclui diretorios ocultos (.github) e subdiretorios futuros.
# Nunca entrar em pastas externas nem seguir links simbolicos.
declare -A KNOWN_DIRS=([capturas]=1 [config]=1 [backups]=1)
for rel in "${PRINT_RC_KNOWN[@]}"; do
    parent="$rel"
    while [[ "$parent" == */* ]]; do
        parent="${parent%/*}"
        KNOWN_DIRS["$parent"]=1
    done
done
for dir in "${!KNOWN_DIRS[@]}"; do
    if [[ -L "$BASE/$dir" ]]; then
        prc_message shell.258 "$BASE" "$dir"
        prc_message shell.259
        exit 2
    fi
done

while IFS=$'\t' read -r checksum rel || [[ -n "${checksum:-}${rel:-}" ]]; do
    [[ -z "${checksum:-}" && -z "${rel:-}" ]] && continue
    if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ || ! -v 'ALLOWED[$rel]' || -v 'EXPECTED[$rel]' ]]; then
        prc_message shell.260 "$rel"
        exit 2
    fi
    EXPECTED["$rel"]="$checksum"
done < "$MANIFEST"
if [[ ! -v 'EXPECTED[desinstalar.sh]' || ! -v 'EXPECTED[.print-rc-installation]' ]]; then
    prc_message shell.261
    exit 2
fi

for rel in "${PRINT_RC_KNOWN[@]}"; do
    file="$BASE/$rel"
    if [[ -L "$file" ]]; then
        prc_message shell.262 "$file"
        continue
    fi
    if [[ ! -f "$file" ]]; then continue; fi
    if [[ ! -v 'EXPECTED[$rel]' ]]; then
        prc_message shell.263 "$file"
        continue
    fi
    if ! current="$(sha256sum -- "$file")"; then
        prc_message shell.264 "$file"
        continue
    fi
    current="${current%% *}"
    if [[ "$current" != "${EXPECTED[$rel]}" ]]; then
        prc_message shell.265 "$file"
        continue
    fi
    rm -- "$file" || {
        prc_message shell.266 "$file"
        prc_message shell.267
        exit 1
    }
done

# Este inventario tambem pertence ao Print RC e fica somente dentro da pasta.
rm -- "$MANIFEST" || { prc_message shell.268; exit 1; }

# Apagar SOMENTE diretorios conhecidos e VAZIOS, dos mais profundos
# para os pais. Isso inclui .github, tests e novos caminhos da lista fixa.
# Nenhum rm -rf, nenhuma exclusao recursiva nem seguimento de symlinks.
mapfile -t ORDERED_DIRS < <(
    printf '%s\n' "${!KNOWN_DIRS[@]}" |
        awk '{ print length($0) "\t" $0 }' |
        LC_ALL=C sort -rn | cut -f2-
)
for dir in "${ORDERED_DIRS[@]}"; do
    rmdir -- "$BASE/$dir" 2>/dev/null || true
done
cd -- "$HOME"
rmdir -- "$BASE" 2>/dev/null || true
if [[ -d "$BASE" ]]; then
    echo
    prc_message shell.269 "$BASE"
    prc_message shell.270
else
    prc_message shell.271
fi
if [[ -n "$IMAGE_DIR" && "$IMAGE_DIR" != "$BASE/"* ]]; then
    prc_message shell.272 "$IMAGE_DIR"
fi
prc_message shell.273
prc_message shell.274
prc_message shell.275
