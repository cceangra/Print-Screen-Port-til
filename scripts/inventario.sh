#!/usr/bin/env bash
# Lista FIXA de arquivos criados/distribuidos pelo Print RC.
# Capturas (PNG/JPG e qualquer arquivo desconhecido) NUNCA entram nesta lista.
PRINT_RC_KNOWN=(
  'bin/print-rc'
  'src/main.cpp' 'src/settings.hpp'
  'scripts/atalho.py' 'scripts/inventario.sh'
  'tests/test_atalho.py' 'tests/test_settings.cpp'
  'tests/test_configuracao.sh' 'tests/test_instalacao.sh'
  'tests/test_desinstalacao.sh' 'tests/test_gui_x11.sh'
  'tests/test_keyboard_grab.cpp'
  'tests/test_clipboard_x11.sh'
  'tests/paint_test_pattern.cpp'
  'tests/test_desinstalacao_processo_x11.sh'
  '.github/release-0.4.2.ready'
  '.github/release-0.4.3.ready'
  '.github/release-0.4.4.ready'
  '.github/release-0.4.5.ready'
  '.github/workflows/testar.yml'
  'config/opcoes.conf' 'config/atalho-state.json'
  'backups/khotkeysrc.antes'
  'README.md' 'LICENSE' 'Makefile' '.gitignore'
  'instalar.sh' 'iniciar.sh' 'configurar.sh'
  '.print-rc-installation' 'desinstalar.sh'
)

print_rc_criar_inventario() {
    local base="$1" manifest="$1/config/arquivos-instalados.sha256" path hash temp rel
    if [[ -e "$manifest" || -L "$manifest" ]]; then
        echo "Inventario existente: $manifest. Nao sera sobrescrito."
        return 0
    fi
    command -v sha256sum >/dev/null 2>&1 || {
        echo 'sha256sum indisponivel; o inventario nao sera criado.'
        return 1
    }
    umask 077
    temp="$(mktemp -- "$base/config/.inventario-XXXXXXXX")"
    for rel in "${PRINT_RC_KNOWN[@]}"; do
        path="$base/$rel"
        if [[ -f "$path" && ! -L "$path" ]]; then
            hash="$(sha256sum -- "$path")" || { rm -f -- "$temp"; return 1; }
            hash="${hash%% *}"
            printf '%s\t%s\n' "$hash" "$rel" >> "$temp"
        fi
    done
    # O arquivo fica dentro da pasta, nunca cria arquivos no HOME ou em /tmp.
    if [[ -e "$manifest" || -L "$manifest" ]]; then
        rm -f -- "$temp"
        echo 'Inventario passou a existir durante a criacao: nada sobrescrito.'
        return 1
    fi
    mv -- "$temp" "$manifest"
    echo "Inventario interno de arquivos criado: $manifest"
}

# Uma configuracao salva pelo configurar.sh passa a ser a versao ORIGINAL
# gerenciada do app. Atualizar SOMENTE seu checksum, nunca os demais arquivos.
# A desinstalacao ainda protege arquivos desconhecidos e personalizados.
print_rc_atualizar_inventario_opcoes() {
    local base="$1" manifest="$1/config/arquivos-instalados.sha256"
    local config="$1/config/opcoes.conf" old checksum rel newhash temp before
    [[ -f "$manifest" && ! -L "$manifest" && -f "$config" && ! -L "$config" ]] || return 1
    before="$(cat -- "$manifest")" || return 1
    newhash="$(sha256sum -- "$config")" || return 1
    newhash="${newhash%% *}"
    [[ "$newhash" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    declare -A allowed=() seen=()
    for rel in "${PRINT_RC_KNOWN[@]}"; do allowed["$rel"]=1; done
    temp="$(mktemp -- "$base/config/.inventario-novo-XXXXXXXX")" || return 1
    umask 077
    while IFS=$'\t' read -r checksum rel || [[ -n "${checksum:-}${rel:-}" ]]; do
        if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ || ! -v 'allowed[$rel]' || -v 'seen[$rel]' ]]; then
            rm -f -- "$temp"
            echo 'Inventario invalido: checksum das preferencias nao atualizado.' >&2
            return 1
        fi
        seen["$rel"]=1
        if [[ "$rel" == config/opcoes.conf ]]; then checksum="$newhash"; fi
        printf '%s\t%s\n' "$checksum" "$rel" >> "$temp" || {
            rm -f -- "$temp"; return 1;
        }
    done <<< "$before"
    if [[ ! -v 'seen[config/opcoes.conf]' || ! -v 'seen[desinstalar.sh]' ]]; then
        rm -f -- "$temp"; return 1
    fi
    if [[ "$(cat -- "$manifest")" != "$before" || -L "$manifest" ]]; then
        rm -f -- "$temp"
        echo 'Inventario mudou durante a configuracao: nao sobrescrevendo.' >&2
        return 1
    fi
    chmod 600 -- "$temp" && mv -T -- "$temp" "$manifest" || {
        rm -f -- "$temp"; return 1;
    }
    echo 'Inventario atualizado: preferencias do Print RC reconhecidas na desinstalacao.'
}
