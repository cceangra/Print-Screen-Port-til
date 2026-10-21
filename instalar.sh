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
    if [[ ! -f "$dest/config/arquivos-instalados.sha256" ]]; then
        echo 'Instalacao anterior incompleta ou muito antiga: falta inventario confiavel.'
        echo 'Nao vou tratar arquivos desta pasta como se fossem recem-instalados.'
        echo 'Escolha uma pasta nova para instalar com seguranca.'
        exit 2
    fi
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
echo
echo '====== INTEGRACAO COM A TECLA PRINT ======'
echo "Ambiente grafico identificado: ${XDG_CURRENT_DESKTOP:-desconhecido}"
echo "Tipo de sessao: ${XDG_SESSION_TYPE:-nao informado} (este capturador requer X11)"
echo 'A tecla Print e cadastrada pelo gerenciador de atalhos do desktop.'
echo 'Nao precisa apertar Print para que o programa conheca o nome da tecla.'
echo 'O instalador nunca usa capturador de teclas residente.'
print_rc_launcher="/bin/bash $(printf '%q' "$dest/iniciar.sh")"
desktop_id="${XDG_CURRENT_DESKTOP:-}"
desktop_id="${desktop_id,,}"
if [[ "$desktop_id" == *trinity* ]]; then
    echo "Trinity: arquivo de atalho: ${TDEHOME:-$HOME/.trinity}/share/config/khotkeysrc"
    echo 'O instalador verificara conflitos e pedira confirmacao antes de alterar.'
    read -r -p 'Deseja associar Print ao Print RC no Trinity? [s/N]: ' answer || true
    if [[ "${answer,,}" == s || "${answer,,}" == sim ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 "$dest/scripts/atalho.py" install --base "$dest" --launcher "$dest/iniciar.sh"
        else
            echo 'Python3 do sistema indisponivel: atalho nao modificado.'
        fi
    else
        echo 'Atalho Trinity nao modificado.'
    fi
elif [[ "$desktop_id" == *xfce* ]]; then
    echo 'Xfce: atalho /commands/custom/Print no canal xfce4-keyboard-shortcuts.'
    echo 'O Xfce pode armazenar essa preferencia fora da pasta, em ~/.config/xfce4/.'
    if ! command -v python3 >/dev/null 2>&1 || ! command -v xfconf-query >/dev/null 2>&1; then
        echo 'Python3 ou xfconf-query ausente: atalho automatico nao disponivel.'
        echo 'Xfce > Configuracoes > Teclado > Atalhos de aplicativos > Adicionar'
        echo "Comando: $print_rc_launcher"
        echo 'Tecla: Print. Libere o atalho existente no proprio Xfce, se necessario.'
    else
        read -r -p 'Deseja associar Print ao Print RC no Xfce? [s/N]: ' answer || true
        if [[ "${answer,,}" == s || "${answer,,}" == sim ]]; then
            python3 "$dest/scripts/atalho_xfce.py" install --base "$dest" --launcher "$dest/iniciar.sh"
        else
            echo 'Atalho Xfce nao modificado.'
        fi
    fi
else
    echo 'Integracao automatica conservadora disponivel para Trinity e Xfce.'
    case "$desktop_id" in
        *gnome*) echo 'GNOME: Configuracoes > Teclado > Atalhos > Atalhos personalizados.' ;;
        *kde*|*plasma*) echo 'KDE Plasma: Configuracoes do sistema > Atalhos > Adicionar comando.' ;;
        *cinnamon*) echo 'Cinnamon: Configuracoes do sistema > Teclado > Atalhos personalizados.' ;;
        *mate*) echo 'MATE: Central de Controle > Atalhos de Teclado > Adicionar.' ;;
        *lxqt*) echo 'LXQt: Configurador LXQt > Atalhos globais.' ;;
        *) echo 'Abra as configuracoes de atalhos de teclado do seu desktop.' ;;
    esac
    echo 'Cadastre manualmente: Nome = Print RC; tecla = Print.'
    echo "Comando a executar: $print_rc_launcher"
    echo 'Se Print estiver ocupado, libere a tecla pelo proprio gerenciador.'
    echo 'Nenhum arquivo de atalhos externo foi modificado.'
fi
echo 'Depois da instalacao, pressione Print para testar.'
echo '=========================================='
if [[ "$FRESH_INSTALL" == 1 ]]; then
    # O marcador so e criado ao FINAL do fluxo interativo. Assim Ctrl+C
    # no momento de cadastrar Print nao deixa falso registro instalado.
    # Inventario preexistente sem marcador e ambiguo: nao confiar nele.
    if [[ -e "$dest/config/arquivos-instalados.sha256" || -L "$dest/config/arquivos-instalados.sha256" ]]; then
        echo 'Inventario preexistente sem marcador valido. Instalacao cancelada.'
        exit 2
    fi
    printf 'PRINT-RC\n%s\n' "$dest" > "$dest/.print-rc-installation"
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
echo
echo 'PRONTO. Nenhuma dependencia foi instalada no Linux.'
echo "Pasta unica: $dest"
echo "Teste agora: \"$dest/iniciar.sh\""
echo 'O ZIP original baixado fora da pasta e independente: guarde-o ou apague-o manualmente.'
