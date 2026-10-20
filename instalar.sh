#!/usr/bin/env bash
set -Eeuo pipefail
LC_ALL=C

if [[ ${EUID} -eq 0 ]]; then
    echo 'Nao execute como root (nem com sudo).'
    exit 1
fi

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
dest="$source_dir"

echo '========================================'
echo '      PRINT RC — PASTA UNICA'
echo '         C++ / X11 / TRINITY'
echo '========================================'
echo 'Sem copia duplicada: usamos esta pasta ou movemos a pasta INTEIRA.'
echo 'Nao instala pacotes automaticamente nem cria servico em segundo plano.'
echo 'Apenas o atalho global opcional pode ser registrado fora da pasta.'
echo

[[ "${XDG_SESSION_TYPE:-x11}" == x11 ]] || { echo 'Esta versao requer X11.'; exit 2; }

# Detecte primeiro dependencias, antes de mover ou criar qualquer instalacao.
for tool in bash python3 make g++ pkg-config; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "DEPENDENCIA AUSENTE: $tool"
        echo 'Nada foi movido. Opcional no Debian: build-essential pkg-config python3.'
        exit 2
    fi
done
if ! pkg-config --exists x11 libpng; then
    echo 'DEPENDENCIAS AUSENTES: x11 e/ou libpng para compilacao.'
    echo 'Nada foi movido. Opcional no Debian: libx11-dev libpng-dev.'
    echo 'Pacotes Debian NAO podem ficar totalmente confinados na pasta do app.'
    exit 2
fi

# --continuar somente para reiniciar o proprio instalador depois de mover a pasta.
if [[ "${1:-}" != '--continuar' ]]; then
    if [[ -f "$source_dir/.print-rc-installation" ]]; then
        stored="$(sed -n '2p' "$source_dir/.print-rc-installation")"
        if [[ "$stored" != "$source_dir" ]]; then
            echo 'Esta pasta ja tinha instalacao em outro caminho. Nao vou movê-la.'
            exit 2
        fi
    fi

    echo "Pasta atual: $source_dir"
    read -r -p 'Nova pasta de destino (Enter = manter esta mesma pasta): ' target || true
    target="${target:-$source_dir}"

    if [[ "$target" == "~/"* ]]; then
        target="$HOME/${target:2}"
    fi
    if [[ "$target" == "~" ]]; then target="$HOME"; fi
    [[ "$target" != *$'\n'* && "$target" != *$'\r'* ]] || {
        echo 'Caminho invalido.'; exit 2;
    }

    dest="$(realpath -m -- "$target")"
    case "$dest" in
        /|"$HOME"|/home|/usr|/usr/local|/tmp|/var)
            echo 'Pasta de destino muito ampla. Escolha uma subpasta exclusiva.'
            exit 2;;
    esac

    if [[ "$dest" != "$source_dir" ]]; then
        if [[ -e "$dest" || -L "$dest" ]]; then
            echo "DESTINO JA EXISTE: $dest"
            echo 'Nada foi sobrescrito ou copiado. Escolha uma pasta nova e exclusiva.'
            exit 2
        fi
        case "$dest/" in "$source_dir/"*)
            echo 'O destino nao pode ficar dentro da pasta que sera movida.'
            exit 2;;
        esac
        echo
        echo "Mover pasta COMPLETA:"
        echo "  DE:   $source_dir"
        echo "  PARA: $dest"
        echo 'A pasta original deixara de existir; nao sera criada uma segunda copia.'
        read -r -p 'Confirma a movimentacao? [s/N]: ' confirm || true
        [[ "${confirm,,}" == s || "${confirm,,}" == sim ]] || {
            echo 'Cancelado sem alterar nada.'; exit 0;
        }
        mkdir -p -- "$(dirname -- "$dest")"
        mv -- "$source_dir" "$dest" || {
            echo 'Nao foi possivel mover. Verifique o caminho original e o destino.'
            exit 2
        }
        # Reiniciar do novo caminho, sem depender da pasta antiga.
        exec bash "$dest/instalar.sh" --continuar
    fi
fi

dest="$source_dir"
if [[ -f "$dest/.print-rc-installation" ]]; then
    marker="$(sed -n '2p' "$dest/.print-rc-installation")"
    [[ "$marker" == "$dest" ]] || {
        echo 'Marcador de instalacao nao corresponde a esta pasta. Cancelado.'
        exit 2
    }
fi
mkdir -p -- "$dest/bin" "$dest/config" "$dest/backups" "$dest/capturas"

echo
echo "Compilando DENTRO DE: $dest"
# Arquivos temporarios do compilador tambem ficam na pasta do Print RC.
build_tmp="$(mktemp -d -- "$dest/.compilacao-XXXXXXXX")"
trap 'rm -rf -- "$build_tmp"' EXIT
TMPDIR="$build_tmp" make -C "$dest" all
"$dest/bin/print-rc" --self-test

printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"
echo
echo 'INSTALACAO CONCLUIDA.'
echo "Toda a pasta do projeto: $dest"
echo "Para testar: bash \"$dest/iniciar.sh\""
echo
read -r -p 'Registrar a tecla Print globalmente no Trinity? [s/N]: ' answer || true
if [[ "${answer,,}" == s || "${answer,,}" == sim ]]; then
    python3 "$dest/scripts/atalho.py" install --base "$dest" --launcher "$dest/iniciar.sh"
else
    echo 'Nenhum atalho do sistema foi modificado.'
fi

echo
echo 'Caso voce tenha baixado um ZIP fora da pasta, ele continua onde foi baixado.'
echo 'Voce pode move-lo para dentro desta pasta ou exclui-lo manualmente.'
echo 'O instalador nao apaga downloads sem sua autorizacao.'
