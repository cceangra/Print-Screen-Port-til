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
