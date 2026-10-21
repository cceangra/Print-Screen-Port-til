#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/i18n.sh"
# Lista FIXA de arquivos criados/distribuidos pelo Print RC.
# Capturas (PNG/JPG e qualquer arquivo desconhecido) NUNCA entram nesta lista.
PRINT_RC_KNOWN=(
  'bin/print-rc' 'bin/print-rc-launcher'
  'src/app/launcher.cpp' 'src/app/runtime.hpp'
  'tests/test_overlay_ready.cpp' 'tests/test_launcher.sh'
  'src/main.cpp' 'src/settings.hpp'
  'scripts/atalho.py' 'scripts/atalho_xfce.py' 'scripts/provar-atalho.sh' 'scripts/inventario.sh'
  'tests/test_prova_atalho.sh' 'tests/test_configurar_tecla.sh' 'tests/test_atalho.py' 'tests/test_trinity_compat.py' 'tests/test_atalho_xfce.py' 'tests/test_xfce_integracao.sh' 'tests/test_settings.cpp'
  'tests/test_configuracao.sh' 'tests/test_instalacao.sh'
  'tests/test_desinstalacao.sh' 'tests/test_gui_x11.sh'
  'tests/test_keyboard_grab.cpp'
  'tests/test_detectar_print_x11.sh'
  'tests/test_clipboard_x11.sh'
  'tests/paint_test_pattern.cpp'
  'tests/test_desinstalacao_processo_x11.sh'
  '.github/release-0.4.2.ready'
  '.github/release-0.4.3.ready'
  '.github/release-0.4.4.ready'
  '.github/release-0.4.5.ready'
  '.github/release-0.4.6.ready'
  '.github/release-0.4.7.ready'
  '.github/release-0.4.8.ready'
  '.github/release-0.4.9.ready'
  '.github/release-0.5.0.ready'
  '.github/release-0.5.1.ready'
  '.github/release-0.5.2.ready'
  '.github/release-0.5.3.ready'
  '.github/release-0.5.4.ready'
  '.github/release-0.5.5.ready'
  '.github/release-0.5.6.ready'
  '.github/workflows/testar.yml'
  'config/opcoes.conf' 'config/atalho-state.json' 'config/atalho-xfce.json'
  'backups/khotkeysrc.antes'
  'README.md' 'LICENSE' 'Makefile' '.gitignore'
  'instalar.sh' 'iniciar.sh' 'configurar.sh' 'configurar-tecla.sh'
  '.print-rc-installation' 'desinstalar.sh'
  'src/clipboard/owner.hpp'
  'src/i18n/generated.hpp'
  'src/i18n/messages.hpp'
  'src/images/png.hpp'
  'src/input/keyboard.hpp'
  'src/ui/drawing.hpp'
  'src/ui/geometry.hpp'
  'scripts/build/locales.py'
  'scripts/build/manifest.py'
  'scripts/build/release_gate.py'
  'scripts/i18n.sh'
  'scripts/messages.bash'
  'scripts/print_rc_i18n.py'
  'i18n/en-US.json'
  'i18n/pt-BR.json'
  'VERSION'
  'config/language'
  'docs/en-US/COMPATIBILITY.md'
  'docs/en-US/DEVELOPMENT.md'
  'docs/en-US/INSTALL.md'
  'docs/en-US/PRIVACY.md'
  'docs/en-US/RELEASE.md'
  'docs/en-US/TROUBLESHOOTING.md'
  'docs/en-US/UNINSTALL.md'
  'docs/en-US/USER_GUIDE.md'
  'docs/pt-BR/COMPATIBILITY.md'
  'docs/pt-BR/DEVELOPMENT.md'
  'docs/pt-BR/INSTALL.md'
  'docs/pt-BR/PRIVACY.md'
  'docs/pt-BR/RELEASE.md'
  'docs/pt-BR/TROUBLESHOOTING.md'
  'docs/pt-BR/UNINSTALL.md'
  'docs/pt-BR/USER_GUIDE.md'
  'tests/run.sh'
  'tests/test_localization.py'
  'tests/test_release_gate.py'
  'packaging/portable/package.py'
  'README.pt-BR.md'
  'CHANGELOG.md'
  'CHANGELOG.pt-BR.md'
  'i18n/README.md'
  'compat/linux-targets.json'
  '.github/workflows/build.yml'
  '.github/workflows/test.yml'
  '.github/workflows/release.yml'
  'build-manifest.json'
  'package-files.json'
  'SHA256SUMS' 'runtime-target.conf'
  'src/config/settings.hpp'
  'scripts/diagnose.py'
  'scripts/lifecycle.py'
  'scripts/relocate.py'
  'tests/test_lifecycle.py'
  'diagnosticar.sh'
  'config/installation-manifest.json'
  'tests/performance/benchmark.py'
  'tests/performance/x11_driver.cpp'
  'tests/test_clipboard_limits.cpp'
  'tests/test_clipboard_limits_x11.sh'
  'tests/test_packaged_ownership.sh'
  'tests/test_undo_x11.sh'
  'tests/test_visual_png.sh'
  'tests/test_xfce_real.sh'
)

print_rc_criar_inventario() {
    local base="$1" manifest="$1/config/arquivos-instalados.sha256" path hash temp rel
    if [[ -e "$manifest" || -L "$manifest" ]]; then
        prc_message shell.276 "$manifest"
        return 0
    fi
    command -v sha256sum >/dev/null 2>&1 || {
        prc_message shell.277
        return 1
    }
    local package_index=0 complete=0 expected_hash expected_rel
    declare -A package_hashes=()
    if [[ -e "$base/package-files.json" || -L "$base/package-files.json" ]]; then
        [[ -f "$base/package-files.json" && ! -L "$base/package-files.json" ]] || return 1
        while IFS=$'\t' read -r expected_hash expected_rel; do
            if [[ "$expected_hash" == COMPLETE && "$expected_rel" == package-index ]]; then complete=1
            elif [[ "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then package_hashes["$expected_rel"]="$expected_hash"; fi
        done < <(python3 -B "$base/scripts/lifecycle.py" package-entries --base "$base")
        [[ "$complete" == 1 ]] || return 1
        package_index=1
    fi
    umask 077
    temp="$(mktemp -- "$base/config/.inventario-XXXXXXXX")"
    for rel in "${PRINT_RC_KNOWN[@]}"; do
        path="$base/$rel"
        if [[ -f "$path" && ! -L "$path" ]]; then
            hash="$(sha256sum -- "$path")" || { rm -f -- "$temp"; return 1; }
            hash="${hash%% *}"
            if [[ "$package_index" == 1 ]]; then
                case "$rel" in
                    config/opcoes.conf|config/language|config/installation-manifest.json|config/atalho-state.json|config/atalho-xfce.json|backups/khotkeysrc.antes|.print-rc-installation|package-files.json|SHA256SUMS) ;;
                    *) [[ "${package_hashes[$rel]:-}" == "$hash" ]] || continue ;;
                esac
            fi
            printf '%s\t%s\n' "$hash" "$rel" >> "$temp"
        fi
    done
    # O arquivo fica dentro da pasta, nunca cria arquivos no HOME ou em /tmp.
    if [[ -e "$manifest" || -L "$manifest" ]]; then
        rm -f -- "$temp"
        prc_message shell.278
        return 1
    fi
    mv -- "$temp" "$manifest"
    prc_message shell.279 "$manifest"
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
            prc_message shell.280 >&2
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
        prc_message shell.281 >&2
        return 1
    fi
    chmod 600 -- "$temp" && mv -T -- "$temp" "$manifest" || {
        rm -f -- "$temp"; return 1;
    }
    prc_message shell.282
}
