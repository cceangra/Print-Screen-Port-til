#!/usr/bin/env bash
set -Eeuo pipefail
LC_ALL=C

if [[ ${EUID} -eq 0 ]]; then
    echo 'Execute como usuario, sem sudo.'
    exit 1
fi

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Nao seguir links inesperados que possam escapar da pasta portatil.
# Executar essa verificacao TAMBEM apos mover a pasta (--continuar).
for relative in \
    bin bin/print-rc config config/opcoes.conf \
    config/atalho-state.json config/arquivos-instalados.sha256 \
    backups backups/khotkeysrc.antes capturas scripts \
    scripts/inventario.sh scripts/atalho.py \
    .print-rc-installation iniciar.sh configurar.sh desinstalar.sh; do
    if [[ -L "$source_dir/$relative" ]]; then
        echo "ATENCAO: link simbolico nao esperado: $source_dir/$relative"
        echo 'Instalacao recusada: nao escreveremos em diretorios/arquivos externos.'
        exit 2
    fi
done

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
        case "$dest/" in "$source_dir/"*)
            echo 'O destino nao pode estar dentro da pasta original.'; exit 2;;
        esac
        case "$source_dir/" in "$dest/"*)
            echo 'A pasta extraida nao pode estar dentro do destino escolhido.'; exit 2;;
        esac
        if [[ -e "$dest" || -L "$dest" ]]; then
            [[ -d "$dest" && ! -L "$dest" ]] || {
                echo 'Destino ja existe e nao e uma pasta comum. Nenhuma mudanca.'; exit 2;
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
                            echo "CONFLITO: $target_path (arquivo do usuario preservado)."
                            echo 'Reinstalacao cancelada sem mover arquivos.'; exit 2;
                        }
                    fi
                else
                    if [[ -e "$target_path" || -L "$target_path" ]]; then
                        echo "CONFLITO: $target_path (arquivo existente preservado)."
                        echo 'Reinstalacao cancelada sem mover arquivos.'; exit 2;
                    fi
                fi
            done
            echo "REINSTALAR em pasta EXISTENTE preservando dados: $dest"
            echo 'O Print RC NAO sobrescrevera, movera ou excluira capturas anteriores.'
            echo 'Somente novos arquivos do aplicativo serao acrescentados.'
            read -r -p 'Confirma reinstalacao sem sobrescrever arquivos? [s/N]: ' conf || true
            [[ "${conf,,}" == s || "${conf,,}" == sim ]] || {
                echo 'Cancelado; nenhuma mudanca.'; exit 1;
            }
            for item in "${contents[@]}"; do
                rel="${item#"$source_dir"/}"
                target_path="$dest/$rel"
                if [[ -d "$item" && ! -L "$item" ]]; then
                    mkdir -p -- "$target_path"
                else
                    if [[ -e "$target_path" || -L "$target_path" ]]; then
                        echo "CONFLITO SURGIU DURANTE A REINSTALACAO: $target_path"
                        echo 'Processo interrompido. Nenhum arquivo existente foi sobrescrito.'
                        exit 2
                    fi
                    mv -n -- "$item" "$target_path"
                    [[ ! -e "$item" && ! -L "$item" ]] || {
                        echo "Falha ao mover $item. Arquivos pessoais continuam preservados."
                        exit 2
                    }
                fi
            done
            find "$source_dir" -depth -type d -empty -delete
            exec bash "$dest/instalar.sh" --continuar
        fi
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
FRESH_INSTALL=1
if [[ -f "$dest/.print-rc-installation" ]]; then
    FRESH_INSTALL=0
    [[ "$(sed -n '1p' "$dest/.print-rc-installation")" == PRINT-RC &&
       "$(sed -n '2p' "$dest/.print-rc-installation")" == "$dest" ]] || {
        echo 'Marcador de instalacao pertence a outro caminho. Cancelado.'; exit 2;
    }
fi

# Corrigir SOMENTE a permissao do inicializador, dentro da pasta do app.
# O Trinity tambem usara /bin/bash explicitamente caso ZIP perca o bit +x.
if [[ ! -f "$dest/iniciar.sh" || -L "$dest/iniciar.sh" ]]; then
    echo 'Inicializador ausente ou simbolico. Instalacao cancelada sem altera-lo.'
    exit 2
fi
if [[ ! -x "$dest/iniciar.sh" ]]; then
    echo 'Autorizando execucao somente do iniciar.sh dentro do aplicativo.'
    chmod u+x -- "$dest/iniciar.sh" || {
        echo 'Nao foi possivel tornar o inicializador executavel.'
        exit 2
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
echo "Teste agora: \"$dest/iniciar.sh\""
echo
echo '====== RESUMO DOS ARQUIVOS EXTERNOS ======'
echo 'Sem configurar tecla Print: NENHUM arquivo externo sera criado/modificado.'
TRINITY_HOME="${TDEHOME:-$HOME/.trinity}"
echo "Com tecla Print: $TRINITY_HOME/share/config/khotkeysrc"
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
if [[ "$FRESH_INSTALL" == 1 ]]; then
    # Registrar o checksum de CADA arquivo original antes de permitir desinstalar.
    # Nunca registrar capturas, documentos desconhecidos nem subpastas do usuario.
    if [[ -r "$dest/scripts/inventario.sh" ]]; then
        source "$dest/scripts/inventario.sh"
        print_rc_criar_inventario "$dest" || {
            echo 'FALHA: nao consegui registrar integridade dos arquivos.'
            echo 'Nada sera removido automaticamente sem inventario verificavel.'
            exit 1
        }
    else
        echo 'Inventario de seguranca indisponivel. Instalacao incompleta.'
        exit 1
    fi
else
    echo 'Reconfiguracao de instalacao existente: inventario anterior preservado.'
    echo 'Se esta e uma versao antiga sem inventario, a desinstalacao sera conservadora.'
fi
echo 'O ZIP original baixado fora da pasta e independente: guarde-o ou apague-o manualmente.'
