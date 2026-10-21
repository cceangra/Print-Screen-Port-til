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
        printf '\nPressione a tecla desejada (tentativa %d; ate 60 segundos; Esc cancela).\n' "$tent" >&2
        if bruto="$("$BIN" --detectar-print)"; then
            if [[ "$bruto" =~ ^PRINT_RC_KEY=([A-Za-z0-9_]{1,64})$ ]]; then
                local escolhida="${BASH_REMATCH[1]}"
                case "$escolhida" in
                  Escape|Shift_L|Shift_R|Control_L|Control_R|Alt_L|Alt_R|Meta_L|Meta_R|Super_L|Super_R|Hyper_L|Hyper_R|ISO_Level3_Shift|Mode_switch)
                      echo 'Nao e possivel usar um modificador sozinho.' >&2
                      return 3 ;;
                esac
                printf '%s\n' "$escolhida"
                return 0
            fi
            echo 'Resposta invalida do leitor X11.' >&2
            return 3
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
    echo 'A tecla fisica escolhida sera cadastrada para abrir o Print RC neste desktop.'
    echo 'Atalhos conflitantes reconhecidos serao substituidos, com registro para restauracao.'
    echo 'Se escolher uma letra, Enter ou espaco, o uso normal desta tecla pode ser afetado.'
    if [[ "$DESKTOP" == *trinity* ]]; then
        python3 -B "$BASE/scripts/atalho.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh" --key "$tecla"
    else
        python3 -B "$BASE/scripts/atalho_xfce.py" install --base "$BASE" \
            --launcher "$BASE/iniciar.sh" --key "$tecla"
    fi
    echo
    echo "REGISTRO_GRAVADO: $tecla associada; aguardando prova real."
    if [[ -n "${DISPLAY:-}" && -t 0 ]]; then
        if ! bash "$BASE/scripts/provar-atalho.sh" "$tecla"; then
            echo 'ATIVACAO_PENDENTE: o desktop ainda nao executou o Print RC durante o teste.'
        fi
    else
        echo 'ATIVACAO_PENDENTE: rode depois: bash scripts/provar-atalho.sh'
    fi
}
provar() {
    if [[ ! -f "$BASE/scripts/provar-atalho.sh" ]]; then
        echo 'Arquivo de teste nao encontrado; pacote incompleto.'
        return 2
    fi
    bash "$BASE/scripts/provar-atalho.sh"
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
    --provar) provar; exit ;;
    --help|-h) echo 'Uso: bash configurar-tecla.sh [--status|--configurar|--liberar|--provar]'; exit ;;
    '') ;;
    *) echo 'Opcao invalida. Use --help.' >&2; exit 2 ;;
esac
while true; do
    header
    echo '1) Verificar situacao da tecla Print'
    echo '2) Configurar / assumir qualquer tecla X11'
    echo '3) Liberar atribuicao gerenciada pelo Print RC'
    echo '4) Testar se Print realmente abre o aplicativo'
    echo '0) Sair'
    printf 'Escolha [0-4]: '
    escolha=''
    IFS= read -r escolha || break
    case "$escolha" in
        1) verificar || true ;;
        2) configurar || true ;;
        3) liberar || true ;;
        4) provar || true ;;
        0) break ;;
        *) echo 'Opcao invalida.' ;;
    esac
done
echo 'Configurador encerrado.'
