#!/usr/bin/env bash
# Print RC: prova REAL de acionamento do inicializador pelo atalho.
# Apos registro, pede uma segunda pressao de Print; nao captura imagens durante a prova.
# Arquivos temporarios ficam apenas na pasta do aplicativo, com limpeza por trap.
set -Eeuo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FLAG="$BASE/config/.print-rc-prova-armada"
RESPONSE="$BASE/config/.print-rc-prova-resposta"
if [[ "${XDG_SESSION_TYPE:-x11}" != x11 || -z "${DISPLAY:-}" ]]; then
    echo 'ATIVACAO_PENDENTE: nao existe sessao X11 para verificar.'
    exit 2
fi
if [[ ! -d "$BASE/config" || ! -f "$BASE/iniciar.sh" ]]; then
    echo 'ATIVACAO_PENDENTE: configuracao ou launcher ausente.'
    exit 2
fi
if [[ -e "$FLAG" || -L "$FLAG" || -e "$RESPONSE" || -L "$RESPONSE" ]]; then
    echo 'ATIVACAO_PENDENTE: existe arquivo de prova anterior; nao sera sobrescrito.'
    exit 2
fi
# Evitar que a rotina atinja qualquer arquivo pessoal pré-existente.
umask 077
TOKEN="print-rc-${BASHPID}-$(date +%s)"
EXPIRY="$(($(date +%s)+14))"
cleanup() {
    # Os caminhos eram inexistentes antes da prova e ficam dentro do aplicativo.
    rm -f -- "$FLAG" "$RESPONSE"
}
trap cleanup EXIT INT TERM
printf '%s\n%s\n' "$TOKEN" "$EXPIRY" > "$FLAG"
echo
echo '======= TESTE REAL DO ATALHO ======='
echo 'O atalho foi gravado no gerenciador.'
echo 'Agora pressione PRINT SCREEN mais uma vez para conferir se o sistema executa o Print RC.'
echo 'Esta pressao serve SOMENTE para o teste; a captura nao sera aberta.'
echo 'Prazo: 12 segundos. Nao precisa responder SIM novamente.'
echo '===================================='
for ((n=0;n<60;n++)); do
    if [[ -f "$RESPONSE" && ! -L "$RESPONSE" ]]; then
        IFS= read -r got < "$RESPONSE" || true
        if [[ "$got" == "$TOKEN" ]]; then
            echo 'ATIVACAO_CONFIRMADA: o atalho executou o inicializador Print RC.'
            echo 'Pressione Print novamente para abrir a captura normalmente.'
            exit 0
        fi
    fi
    sleep 0.2
done
echo 'ATIVACAO_NAO_CONFIRMADA: tecla identificada e atalho salvo, mas nao houve acionamento nesta sessao.'
echo 'No Trinity, o serviço khotkeysd pode precisar de reativacao pelo Gerenciador de servicos'
echo 'ou de um novo login. O aplicativo nao reinicia automaticamente o ambiente grafico.'
exit 1
