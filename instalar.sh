#!/usr/bin/env bash
set -Eeuo pipefail
LC_ALL=C

if [[ ${EUID} -eq 0 ]]; then
    echo 'Execute como usuario, sem sudo.'
    exit 1
fi

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

echo '========================================'
echo '     PRINT RC — INSTALACAO PORTATIL'
echo '          PASTA UNICA / X11'
echo '========================================'
echo 'Nao instala pacotes; nao chama apt; nao compila.'
echo 'O binario e as bibliotecas necessarias estao juntos no pacote.'
echo 'Sistema Linux/X11 e atalho Trinity sao requisitos externos.'
echo

[[ "${XDG_SESSION_TYPE:-x11}" == x11 ]] || { echo 'Esta versao requer uma sessao X11.'; exit 2; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'Este pacote foi compilado para Linux x86_64.'; exit 2; }
[[ -x "$source_dir/bin/print-rc" ]] || {
    echo 'ERRO: executavel bin/print-rc ausente!'
    echo 'Baixe o ZIP ATUALIZADO com binario integrado, e nao a antiga versao de fonte.'
    echo 'Nenhuma pasta foi criada ou movida.'
    exit 2
}
"$source_dir/bin/print-rc" --self-test || {
    echo 'O executavel deste pacote nao passou no teste. Nenhuma pasta foi movida.'
    exit 2
}

if [[ "${1:-}" != '--continuar' ]]; then
    echo
    echo "Pasta extraida: $source_dir"
    read -r -p 'Destino (Enter = manter tudo nesta pasta): ' target || true
    target="${target:-$source_dir}"
    if [[ "$target" == "~/"* ]]; then target="$HOME/${target:2}"; fi
    if [[ "$target" == "~" ]]; then target="$HOME"; fi
    [[ "$target" != *$'\n'* && "$target" != *$'\r'* ]] || {
        echo 'Destino invalido.'; exit 2;
    }
    dest="$(realpath -m -- "$target")"
    case "$dest" in
        /|"$HOME"|/home|/usr|/usr/local|/tmp|/var)
            echo 'Destino amplo demais. Selecione uma subpasta exclusiva.'; exit 2;;
    esac
    if [[ "$dest" != "$source_dir" ]]; then
        [[ ! -e "$dest" && ! -L "$dest" ]] || {
            echo "A pasta de destino JA EXISTE: $dest"
            echo 'Nao sobrescrevo dados. Escolha uma pasta ainda inexistente.'
            exit 2
        }
        case "$dest/" in "$source_dir/"*)
            echo 'O destino nao pode estar dentro da pasta original.'; exit 2;;
        esac
        echo
        echo "MOVER A PASTA INTEIRA: $source_dir"
        echo "PARA: $dest"
        echo 'A pasta antiga nao sera mantida nem copiada.'
        read -r -p 'Confirma a movimentacao? [s/N]: ' conf || true
        [[ "${conf,,}" == s || "${conf,,}" == sim ]] || {
            echo 'Cancelado, sem movimentacao.'; exit 0;
        }
        mkdir -p -- "$(dirname -- "$dest")"
        mv -- "$source_dir" "$dest" || {
            echo 'Nao foi possivel mover. Confira os caminhos.'
            exit 2
        }
        exec bash "$dest/instalar.sh" --continuar
    fi
fi

dest="$source_dir"
if [[ -f "$dest/.print-rc-installation" ]]; then
    [[ "$(sed -n '2p' "$dest/.print-rc-installation")" == "$dest" ]] || {
        echo 'Marcador de instalacao pertence a outro caminho. Cancelado.'; exit 2;
    }
fi

mkdir -p -- "$dest/config" "$dest/backups" "$dest/capturas"
echo
echo 'A seguir, informe o CAMINHO COMPLETO da pasta das imagens'
echo 'e escolha se cada captura tambem deve ser copiada para Ctrl+V.'
echo 'As preferencias ficam dentro da pasta Print RC.'
if ! bash "$dest/configurar.sh"; then
    echo 'Configuracao cancelada. Nenhum atalho foi modificado.'
    echo "A pasta continua em: $dest"
    echo "Para configurar posteriormente: bash \"$dest/configurar.sh\""
    exit 1
fi
printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"

echo
echo 'PRONTO. Nenhuma dependencia foi instalada no Linux.'
echo "Pasta unica: $dest"
echo "Teste agora: bash \"$dest/iniciar.sh\""
echo
echo '====== RESUMO DOS ARQUIVOS EXTERNOS ======'
echo 'Sem configurar tecla Print: NENHUM arquivo externo sera criado/modificado.'
echo "Com tecla Print: $HOME/.trinity/share/config/khotkeysrc"
echo '  Se existe: modificar somente entradas de atalho, preservando as demais.'
echo '  Se nao existe: criar; na desinstalacao, excluir se for seguro.'
echo "  Backup e registro: $dest/backups e $dest/config"
echo '  O programa mostrara o caminho novamente antes da confirmacao final.'
echo '=========================================='
echo
read -r -p 'Deseja associar Print ao aplicativo no Trinity? [s/N]: ' answer || true
if [[ "${answer,,}" == s || "${answer,,}" == sim ]]; then
    # O atalho so funciona integrado ao gerenciador de teclas do Trinity.
    if command -v python3 >/dev/null 2>&1; then
        python3 "$dest/scripts/atalho.py" install --base "$dest" --launcher "$dest/iniciar.sh"
    else
        echo 'Python3 do sistema nao encontrado; nenhum atalho foi alterado.'
        echo 'Voce pode configurar Print manualmente nos atalhos do desktop.'
    fi
else
    echo 'Atalho do sistema nao modificado.'
fi
echo 'O ZIP original baixado fora da pasta e independente: guarde-o ou apague-o manualmente.'
