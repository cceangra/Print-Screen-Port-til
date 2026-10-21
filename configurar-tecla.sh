#!/usr/bin/env bash
# Print RC: consultar e configurar a tecla Print sem reinstalar.
set -Eeuo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DESKTOP="${XDG_CURRENT_DESKTOP:-}"
DESKTOP="${DESKTOP,,}"
BIN="$BASE/bin/print-rc"

header() {
    printf '\n===========================================\n'
    printf '  PRINT RC - CONFIGURADOR DE TECLA v0.5.2\n'
    printf '===========================================\n'
    printf 'Ambiente: %s | Sessao: %s\n' "${XDG_CURRENT_DESKTOP:-desconhecido}" "${XDG_SESSION_TYPE:-desconhecida}"
}
sim() {
    local resposta
    printf '%s [s/N]: ' "$1"
    IFS= read -r resposta || return 1
    case "${resposta,,}" in s|sim) return 0 ;; *) return 1 ;; esac
}
verificar() {
    header
    echo
    echo '[1] Registro de atalhos do desktop (somente leitura)'
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" inspect --base "$BASE"
    elif [[ "$DESKTOP" == *xfce* ]]; then
        python3 -B "$BASE/scripts/atalho_xfce.py" inspect --base "$BASE"
    else
        echo 'Este desktop ainda nao tem integracao automatica.'
        echo 'Consulte as preferencias de atalhos do seu ambiente.'
    fi
    echo
    echo '[2] Reserva da tecla Print no X11 (teste curto, nao destrutivo)'
    local status=0
    "$BIN" --verificar-tecla || status=$?
    case "$status" in
      0) echo 'Nenhum bloqueio observado pela sonda X11.' ;;
      6) echo 'A tecla esta reservada por algum cliente X11.' ;;
      *) echo 'Nao foi possivel determinar se existe reserva X11.' ;;
    esac
    echo 'A sonda NAO informa o dono nem garante que a tecla esteja livre em todo o sistema.'
    echo 'Reservas de outros processos nao podem ser liberadas a forca pelo Print RC.'
}
ler_tecla() {
    # Apenas o nome da tecla sai em stdout para nao confundir $(...).
    local bruto codigo tent=1 resposta
    while true; do
        printf '\nPressione PRINT SCREEN (tentativa %d; ate 60 segundos; Esc cancela).\n' "$tent" >&2
        if bruto="$("$BIN" --detectar-print)"; then
            case "$bruto" in
              PRINT_RC_KEY=Print) printf 'Print\n'; return 0 ;;
              PRINT_RC_KEY=Sys_Req) printf 'Sys_Req\n'; return 0 ;;
              *) echo 'Resposta invalida do leitor X11.' >&2; return 3 ;;
            esac
        else
            codigo=$?
        fi
        case "$codigo" in
          4)
             printf 'Tempo esgotado. Tentar novamente? [s/N]: ' >&2
             resposta=''
             if ! IFS= read -r resposta; then
                 echo 'Nenhuma resposta; cancelado.' >&2
                 return 4
             fi
             case "${resposta,,}" in
               s|sim) ((tent+=1)); continue ;;
               *) echo 'Nenhum atalho alterado.' >&2; return 4 ;;
             esac ;;
          5) echo 'Cancelado com Esc; nenhum atalho alterado.' >&2; return 5 ;;
          *) echo 'Nao foi possivel ler o teclado. Atalho nao alterado.' >&2; return "$codigo" ;;
        esac
    done
}
configurar() {
    header
    if [[ "${XDG_SESSION_TYPE:-x11}" != x11 ]]; then
        echo 'O Print RC atual so captura telas em X11. Wayland nao e suportado.'
        return 2
    fi
    if [[ "$DESKTOP" != *trinity* && "$DESKTOP" != *xfce* ]]; then
        echo 'Cadastro automatico disponivel somente para Trinity e Xfce.'
        echo "Comando para registrar manualmente: /bin/bash \"$BASE/iniciar.sh\""
        return 2
    fi
    local tecla
    if ! tecla="$(ler_tecla)"; then return 1; fi
    echo
    echo "Tecla detectada: $tecla"
    echo 'O Print RC tentara assumir a tecla no gerenciador de atalhos deste desktop.'
    echo 'Atalhos conflitantes reconhecidos serao substituidos, com registro para restauracao.'
    if [[ "$DESKTOP" == *xfce* && "$tecla" != Print ]]; then
        echo 'Xfce nao permite registrar automaticamente este keysym pela integracao atual.'
        return 2
    fi
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh" --key "$tecla"
    else
        python3 -B "$BASE/scripts/atalho_xfce.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh"
    fi
    echo
    echo 'Solicitacao concluida. Aperte Print para testar se o capturador abre.'
}
liberar() {
    header
    echo 'Remove SOMENTE a atribuicao gerenciada pelo Print RC.'
    echo 'Se o app substituiu um atalho anterior, tenta restaura-lo.'
    echo 'Nao encerra aplicativos nem remove reservas de clientes externos.'
    if ! sim 'Confirma desfazer o atalho do Print RC?'; then
        echo 'Cancelado.'
        return 0
    fi
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" remove --base "$BASE"
    elif [[ "$DESKTOP" == *xfce* ]]; then
        python3 -B "$BASE/scripts/atalho_xfce.py" remove --base "$BASE"
    else
        echo 'Este desktop nao possui atalho gerenciado pelo Print RC.'
        return 2
    fi
}
if [[ $EUID == 0 ]]; then
    echo 'Execute como usuario normal, nao como root.' >&2
    exit 2
fi
if [[ ! -x "$BIN" || ! -f "$BASE/iniciar.sh" ]]; then
    echo 'Pasta do Print RC incompleta: binario ou inicializador ausente.' >&2
    exit 2
fi
case "${1:-}" in
    --status) verificar; exit ;;
    --configurar) configurar; exit ;;
    --liberar) liberar; exit ;;
    --help|-h) echo 'Uso: bash configurar-tecla.sh [--status|--configurar|--liberar]'; exit ;;
    '') ;;
    *) echo 'Opcao invalida. Use --help.' >&2; exit 2 ;;
esac
while true; do
    header
    echo '1) Verificar situacao da tecla Print'
    echo '2) Configurar / assumir tecla Print Screen'
    echo '3) Liberar atribuicao gerenciada pelo Print RC'
    echo '0) Sair'
    printf 'Escolha [0-3]: '
    escolha=''
    IFS= read -r escolha || break
    case "$escolha" in
        1) verificar || true ;;
        2) configurar || true ;;
        3) liberar || true ;;
        0) break ;;
        *) echo 'Opcao invalida.' ;;
    esac
done
echo 'Configurador encerrado.'
