#!/usr/bin/env bash
set -Eeuo pipefail
PRC_ENTRY="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)/scripts/i18n.sh"
source "$PRC_APP_ROOT/scripts/prompts.sh"
export PRINT_RC_SETUP_SIMPLE=1

if [[ ${EUID} -eq 0 ]]; then
    prc_message shell.001
    exit 1
fi

source_dir="$(cd -- "$(dirname -- "$PRC_ENTRY")" && pwd -P)"

# Nao seguir links inesperados que possam escapar da pasta portatil.
# Executar essa verificacao TAMBEM apos mover a pasta (--continuar).
for relative in \
    Print-RC Instalar Configurar bin bin/print-rc bin/print-rc-launcher config config/opcoes.conf \
    config/atalho-state.json config/atalho-xfce.json config/arquivos-instalados.sha256 config/installation-manifest.json \
    backups backups/khotkeysrc.antes capturas scripts \
    scripts/inventario.sh scripts/atalho.py \
    .print-rc-installation iniciar.sh configurar.sh desinstalar.sh; do
    if [[ -L "$source_dir/$relative" ]]; then
        prc_message shell.002 "$source_dir" "$relative"
        prc_message shell.003
        exit 2
    fi
done

echo '========================================'
prc_message shell.004
prc_message shell.005
echo '========================================'
prc_message shell.006
prc_message shell.007
prc_message shell.008
echo

[[ "${XDG_SESSION_TYPE:-x11}" == x11 ]] || { prc_message shell.009; exit 2; }
[[ "$(uname -m)" == x86_64 ]] || { prc_message shell.010; exit 2; }
if ! command -v python3 >/dev/null 2>&1 || ! python3 -B -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 2)'; then
    prc_message shell.python_required; exit 2;
fi
# Repair execution bits before testing; ZIP extractors can discard Unix modes.
# Never chmod a symlink or an external file.
for relative in Print-RC Instalar Configurar Instalar.desktop Configurar.desktop bin/print-rc bin/print-rc-launcher; do
    if [[ -f "$source_dir/$relative" && ! -L "$source_dir/$relative" && ! -x "$source_dir/$relative" ]]; then
        chmod u+x -- "$source_dir/$relative" || { prc_message shell.045; exit 2; }
    fi
done
[[ -x "$source_dir/bin/print-rc" && -x "$source_dir/bin/print-rc-launcher" ]] || {
    prc_message shell.011
    prc_message shell.012
    prc_message shell.013
    exit 2
}
# This also detects a missing loader/library for the supervisor before any move,
# preferences, directory creation or desktop shortcut transaction.
"$source_dir/bin/print-rc-launcher" "$source_dir/bin/print-rc" --self-test || {
    prc_message shell.014
    exit 2
}

if [[ "${1:-}" != '--continuar' ]]; then
    echo
    prc_message shell.015 "$source_dir"
    while true; do
        target=''
        IFS= read -r -p "$(prc_text shell.016)" target || { prc_message shell.029;exit 1; }
        case "$target" in
            ''|1) target="$source_dir";break ;;
            2) IFS= read -r -p "$(prc_text shell.install_path)" target || { prc_message shell.029;exit 1; }
               [[ -n "$target" ]] || { prc_message shell.029;exit 1; };break ;;
            /*|"~/"*) break ;; # Preserve the legacy absolute-path input.
            *) prc_message shell.215 ;;
        esac
    done
    if [[ "$target" == "~/"* ]]; then target="$HOME/${target:2}"; fi
    if [[ "$target" == "~" ]]; then target="$HOME"; fi
    [[ "$target" != *$'\n'* && "$target" != *$'\r'* ]] || {
        prc_message shell.017; exit 2;
    }
    dest="$(realpath -m -- "$target")"
    case "$dest" in
        /|"$HOME"|/home|/usr|/usr/local|/tmp|/var)
            prc_message shell.018; exit 2;;
    esac
    if [[ "$dest" != "$source_dir" ]]; then
        case "$dest/" in "$source_dir/"*)
            prc_message shell.019; exit 2;;
        esac
        case "$source_dir/" in "$dest/"*)
            prc_message shell.020; exit 2;;
        esac
        if [[ -e "$dest" || -L "$dest" ]]; then
            [[ -d "$dest" && ! -L "$dest" ]] || {
                prc_message shell.021; exit 2;
            }
            # Reinstalacao apos desinstalar: o destino pode conter capturas pessoais.
            # Verificar TODOS os caminhos antes de mover qualquer arquivo.
            mapfile -d '' -t contents < <(find "$source_dir" -mindepth 1 -print0)
            for item in "${contents[@]}"; do
                rel="${item#"$source_dir"/}"
                target_path="$dest/$rel"
                if [[ -d "$item" && ! -L "$item" ]]; then
                    if [[ -e "$target_path" || -L "$target_path" ]]; then
                        [[ -d "$target_path" && ! -L "$target_path" ]] || {
                            prc_message shell.022 "$target_path"
                            prc_message shell.023; exit 2;
                        }
                    fi
                else
                    if [[ -e "$target_path" || -L "$target_path" ]]; then
                        prc_message shell.024 "$target_path"
                        prc_message shell.023; exit 2;
                    fi
                fi
            done
            prc_message shell.025 "$dest"
            prc_message shell.026
            prc_message shell.027
            prc_confirm "$(prc_text shell.028)" || {
                prc_message shell.029; exit 1;
            }
            for item in "${contents[@]}"; do
                rel="${item#"$source_dir"/}"
                target_path="$dest/$rel"
                if [[ -d "$item" && ! -L "$item" ]]; then
                    mkdir -p -- "$target_path"
                else
                    if [[ -e "$target_path" || -L "$target_path" ]]; then
                        prc_message shell.030 "$target_path"
                        prc_message shell.031
                        exit 2
                    fi
                    mv -n -- "$item" "$target_path"
                    [[ ! -e "$item" && ! -L "$item" ]] || {
                        prc_message shell.032 "$item"
                        exit 2
                    }
                fi
            done
            find "$source_dir" -depth -type d -empty -delete
            exec bash "$dest/instalar.sh" --continuar
        fi
        echo
        prc_message shell.033 "$source_dir"
        prc_message shell.034 "$dest"
        prc_message shell.035
        prc_confirm "$(prc_text shell.036)" || {
            prc_message shell.037; exit 0;
        }
        # Do not create untracked parent directories outside the application.
        [[ -d "$(dirname -- "$dest")" ]] || {
            prc_message shell.parent_missing "$(dirname -- "$dest")";exit 2;
        }
        mv -- "$source_dir" "$dest" || {
            prc_message shell.038
            exit 2
        }
        exec bash "$dest/instalar.sh" --continuar
    fi
fi

dest="$source_dir"
if [[ -f "$dest/Print-RC" && ! -L "$dest/Print-RC" ]]; then chmod u+x -- "$dest/Print-RC"; fi
FRESH_INSTALL=1
if [[ -f "$dest/.print-rc-installation" ]]; then
    FRESH_INSTALL=0
    [[ "$(sed -n '1p' "$dest/.print-rc-installation")" == PRINT-RC &&
       "$(sed -n '2p' "$dest/.print-rc-installation")" == "$dest" ]] || {
        prc_message shell.039; exit 2;
    }
    if [[ ! -f "$dest/config/arquivos-instalados.sha256" ]]; then
        prc_message shell.040
        prc_message shell.041
        prc_message shell.042
        exit 2
    fi
fi

# Corrigir SOMENTE a permissao do inicializador, dentro da pasta do app.
# O Trinity tambem usara /bin/bash explicitamente caso ZIP perca o bit +x.
if [[ ! -f "$dest/iniciar.sh" || -L "$dest/iniciar.sh" ]]; then
    prc_message shell.043
    exit 2
fi
if [[ ! -x "$dest/iniciar.sh" ]]; then
    prc_message shell.044
    chmod u+x -- "$dest/iniciar.sh" || {
        prc_message shell.045
        exit 2
    }
fi
mkdir -p -- "$dest/config" "$dest/backups" "$dest/capturas"
echo
prc_message shell.046
prc_message shell.047
prc_message shell.048
if ! bash "$dest/configurar.sh"; then
    prc_message shell.049
    prc_message shell.050 "$dest"
    prc_message shell.051 "$dest"
    exit 1
fi
echo
prc_message shell.052
prc_message shell.053 "${XDG_CURRENT_DESKTOP:-$(prc_text common.unknown)}" "${XDG_SESSION_TYPE:-$(prc_text common.unknown)}"
prc_message shell.054
prc_message shell.055
prc_message shell.056
prc_message shell.057
prc_message shell.058
prc_message shell.060
print_rc_launcher="/bin/bash $(printf '%q' "$dest/iniciar.sh")"

# Em stdout, devolver exclusivamente "Print" ou "Sys_Req".
# As mensagens e a pergunta de nova tentativa vao para stderr,
# inclusive quando o instalador captura o resultado por $(...).
print_rc_detectar() {
    local raw codigo resposta chave tentativa=1
    while true; do
        prc_format shell.061 "$tentativa" >&2
        if raw="$("$dest/bin/print-rc" --detectar-print)"; then
            if [[ "$raw" =~ ^PRINT_RC_KEY=([A-Za-z0-9_]{1,64})$ ]]; then
                chave="${BASH_REMATCH[1]}"
                case "$chave" in
                    Escape|Shift_L|Shift_R|Control_L|Control_R|Alt_L|Alt_R|Meta_L|Meta_R|Super_L|Super_R|Hyper_L|Hyper_R|ISO_Level3_Shift|Mode_switch)
                        prc_message shell.062 >&2
                        return 3 ;;
                esac
            else
                prc_message shell.063 >&2
                return 3
            fi
            prc_format shell.064 "$chave" >&2
            printf '%s\n' "$chave"
            return 0
        else
            codigo=$?
        fi
        if [[ "$codigo" == 4 ]]; then
            prc_message shell.065 >&2
            if prc_confirm "$(prc_text shell.066)"; then ((tentativa+=1));continue; fi
            prc_message shell.068 >&2;return 4
        elif [[ "$codigo" == 5 ]]; then
            prc_message shell.069 >&2
            return 5
        else
            prc_message shell.070 >&2
            return "$codigo"
        fi
    done
}
desktop_id="${XDG_CURRENT_DESKTOP:-}"
desktop_id="${desktop_id,,}"
atalho_registrado=0
overlay_state=pending
recovery_state=''
print_rc_partial_recovery() {
    local result=$?
    trap - EXIT
    # A prepared external transaction must remain uninstallable after failure
    # or interruption. An ownership receipt does not mean activation succeeded.
    if [[ "$result" != 0 && -n "$recovery_state" && -f "$recovery_state" && ! -L "$recovery_state" &&
          ! -e "$dest/.print-rc-installation" && ! -L "$dest/.print-rc-installation" &&
          ! -e "$dest/config/arquivos-instalados.sha256" && ! -L "$dest/config/arquivos-instalados.sha256" ]]; then
        if python3 -B "$dest/scripts/lifecycle.py" record --base "$dest" --overlay-state pending &&
           (set -C; printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"); then
            source "$dest/scripts/inventario.sh"
            if print_rc_criar_inventario "$dest"; then prc_message shell.partial_recorded "$dest"; fi
        fi
    fi
    return "$result"
}
trap print_rc_partial_recovery EXIT
if [[ "$desktop_id" == *trinity* ]]; then
    prc_message shell.071 "${TDEHOME:-$HOME/.trinity}"
    if ! command -v python3 >/dev/null 2>&1; then
        prc_message shell.072
    elif key_name="$(print_rc_detectar)"; then
        [[ -e "$dest/config/atalho-state.json" || -L "$dest/config/atalho-state.json" ]] || recovery_state="$dest/config/atalho-state.json"
        if python3 -B "$dest/scripts/atalho.py" install --base "$dest" --launcher "$dest/iniciar.sh" --key "$key_name"; then
            atalho_registrado=1
        else
            prc_message shell.073
            prc_message shell.074
            prc_message shell.shortcut_next "$dest"
            exit 1
        fi
    else
        prc_message shell.075
    fi
elif [[ "$desktop_id" == *xfce* ]]; then
    prc_message shell.076
    if ! command -v python3 >/dev/null 2>&1 || ! command -v xfconf-query >/dev/null 2>&1; then
        prc_message shell.077
        prc_message shell.078
        prc_message shell.079 "$print_rc_launcher"
    elif key_name="$(print_rc_detectar)"; then
        prc_message shell.080 "$key_name"
        [[ -e "$dest/config/atalho-xfce.json" || -L "$dest/config/atalho-xfce.json" ]] || recovery_state="$dest/config/atalho-xfce.json"
        if python3 -B "$dest/scripts/atalho_xfce.py" install --base "$dest" --launcher "$dest/iniciar.sh" --key "$key_name"; then
            atalho_registrado=1
        else
            prc_message shell.081
            prc_message shell.074
            prc_message shell.shortcut_next "$dest"
            exit 1
        fi
    else
        prc_message shell.075
    fi
else
    prc_message shell.082
    case "$desktop_id" in
        *gnome*)
            prc_message shell.083
            prc_message shell.084
            prc_message shell.085
            ;;
        *kde*|*plasma*)
            prc_message shell.086
            prc_message shell.087
            ;;
        *cinnamon*)
            prc_message shell.088
            ;;
        *mate*)
            prc_message shell.089
            ;;
        *lxqt*)
            prc_message shell.090
            ;;
        *lxde*|*openbox*)
            prc_message shell.091
            prc_message shell.092
            ;;
        *budgie*) prc_message shell.093 ;;
        *i3*|*sway*|*hyprland*|*awesome*)
            prc_message shell.094
            prc_message shell.095
            ;;
        *) prc_message shell.096 ;;
    esac
    prc_message shell.097
    prc_message shell.098 "$print_rc_launcher"
    prc_message shell.099
    prc_message shell.100
    prc_message shell.101
fi
if [[ "$atalho_registrado" == 1 ]]; then
    prc_message shell.102 "${key_name:-$(prc_text common.unknown)}"
    if [[ -n "${DISPLAY:-}" && -t 0 && -f "$dest/scripts/provar-atalho.sh" ]]; then
        if bash "$dest/scripts/provar-atalho.sh" "$key_name"; then
            overlay_state=verified
            prc_message shell.103
        else
            prc_message shell.104
            prc_message shell.105
            prc_message shell.106
            prc_message shell.107 "$dest"
        fi
    else
        prc_message shell.108
        prc_message shell.109 "$dest"
    fi
else
    prc_message shell.110
fi
prc_message shell.shortcut_next "$dest"
prc_message shell.111
echo '=========================================='
python3 -B "$dest/scripts/lifecycle.py" record --base "$dest" --overlay-state "$overlay_state"
if [[ "$FRESH_INSTALL" == 1 ]]; then
    # O marcador so e criado ao FINAL do fluxo interativo. Assim Ctrl+C
    # no momento de cadastrar Print nao deixa falso registro instalado.
    # Inventario preexistente sem marcador e ambiguo: nao confiar nele.
    if [[ -e "$dest/config/arquivos-instalados.sha256" || -L "$dest/config/arquivos-instalados.sha256" ]]; then
        prc_message shell.112
        exit 2
    fi
    printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"
    # Registrar o checksum de CADA arquivo original antes de permitir desinstalar.
    # Nunca registrar capturas, documentos desconhecidos nem subpastas do usuario.
    if [[ -r "$dest/scripts/inventario.sh" ]]; then
        source "$dest/scripts/inventario.sh"
        print_rc_criar_inventario "$dest" || {
            prc_message shell.113
            prc_message shell.114
            exit 1
        }
    else
        prc_message shell.115
        exit 1
    fi
else
    prc_message shell.116
    prc_message shell.117
fi
echo
prc_message shell.118
prc_message shell.119 "$dest"
prc_message shell.120 "$dest"
prc_message shell.121
