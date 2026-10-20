#!/usr/bin/env bash
set -Eeuo pipefail
LC_ALL=C
if [[ ${EUID} -eq 0 ]]; then echo 'Nao execute como root (nem com sudo).'; exit 1; fi
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo '========================================'
echo '       INSTALADOR PRINT RC 0.1.0'
echo '       C++ / X11 / TRINITY'
echo '========================================'
echo 'Arquivos do app ficam na pasta que escolher.'
echo 'Excecao opcional: atalho do sistema Trinity.'
echo 'Dependencias de compilacao, se ausentes, sao externas.'
echo
[[ "${XDG_SESSION_TYPE:-x11}" == x11 ]] || { echo 'Atencao: esta versao requer X11.'; exit 2; }
for tool in bash python3 make g++ pkg-config; do
    command -v "$tool" >/dev/null || { echo "Falta: $tool. No Debian: sudo apt install build-essential pkg-config python3"; exit 2; }
done
if ! pkg-config --exists x11 libpng; then
    echo 'Faltam arquivos de desenvolvimento para compilar.'
    echo 'No Q4OS/Debian: sudo apt install libx11-dev libpng-dev'
    echo 'Esses pacotes sao instalados pelo sistema, FORA da pasta portable.'
    exit 2
fi
read -r -p "Pasta de destino [$HOME/Apps/Print-RC]: " target || true
target="${target:-$HOME/Apps/Print-RC}"
[[ "$target" != *$'\n'* ]] || { echo 'Caminho invalido'; exit 2; }
mkdir -p -- "$target"
dest="$(cd -- "$target" && pwd -P)"
case "$dest" in /|"$HOME") echo 'Destino perigoso, escolha subpasta.';exit 2;; esac
if [[ "$dest" == "$source_dir" ]]; then
    echo 'Usando a pasta extraida como instalacao.'
else
    if [[ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit)" && ! -f "$dest/.print-rc-installation" ]]; then
        echo 'Pasta nao vazia e nao pertence ao Print RC. Instalacao cancelada.'
        exit 2
    fi
    cp -a -- "$source_dir/src" "$source_dir/scripts" "$source_dir/Makefile" \
      "$source_dir/README.md" "$source_dir/LICENSE" "$source_dir/iniciar.sh" \
      "$source_dir/desinstalar.sh" "$source_dir/instalar.sh" "$dest/"
fi
mkdir -p -- "$dest/bin" "$dest/config" "$dest/backups" "$dest/capturas"
printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"
echo
printf 'Compilando em %s ...\n' "$dest"
make -C "$dest" all
"$dest/bin/print-rc" --self-test
printf '\nApp instalado em: %s\n' "$dest"
echo 'Teste agora: bash '"$dest/iniciar.sh"
echo
read -r -p 'Deseja configurar a tecla Print no Trinity agora? [s/N]: ' answer || true
if [[ "${answer,,}" == s || "${answer,,}" == sim ]]; then
    python3 "$dest/scripts/atalho.py" install --base "$dest" --launcher "$dest/iniciar.sh"
else
    echo 'Atalho nao modificado. Para testar: bash '"$dest/iniciar.sh"
fi
echo 'Instalacao finalizada.'
