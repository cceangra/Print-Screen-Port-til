#!/usr/bin/env bash
# Print RC: configuracao interativa SEM pacotes externos.
set -Eeuo pipefail
[[ ${EUID} -ne 0 ]] || { echo 'Nao execute com sudo.'; exit 1; }

BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG="$BASE/config/opcoes.conf"
DEFAULT_DIR="$BASE/capturas"

# Configuracao deve ficar dentro da pasta real do app.
# Links poderiam direcionar a gravacao de arquivos para locais externos.
for relative in config config/opcoes.conf capturas; do
    if [[ -L "$BASE/$relative" ]]; then
        echo "ERRO: link simbolico inesperado no aplicativo: $BASE/$relative"
        echo 'Nenhuma preferencia foi modificada.'
        exit 2
    fi
done

echo '===================================================='
echo '         PRINT RC - CONFIGURACAO'
echo '===================================================='
echo 'Todas as preferencias do aplicativo ficam em:'
echo "  $CONFIG"
echo 'As capturas serao arquivos PNG.'
echo 'Se escolher uma pasta FORA do Print RC, as imagens'
echo 'serao arquivos externos e nao serao apagadas na desinstalacao.'
echo
echo "Pasta padrao DENTRO do aplicativo: $DEFAULT_DIR"
PREVIOUS_DIR=''
PREVIOUS_CLIP=''
if [[ -f "$CONFIG" && ! -L "$CONFIG" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            save_dir=*) PREVIOUS_DIR="${line#save_dir=}"; echo "Pasta atualmente configurada: $PREVIOUS_DIR" ;;
            copy_clipboard=1) PREVIOUS_CLIP=1; echo 'Copia para area de transferencia: SIM' ;;
            copy_clipboard=0) PREVIOUS_CLIP=0; echo 'Copia para area de transferencia: NAO' ;;
        esac
    done < "$CONFIG"
fi

echo 'Enter mantem a pasta anterior, quando houver.'
read -r -p 'Digite o CAMINHO COMPLETO da pasta das imagens (Enter = manter anterior/padrao): ' supplied || true
TARGET="${supplied:-${PREVIOUS_DIR:-$DEFAULT_DIR}}"
if [[ "$TARGET" != /* || "$TARGET" == *$'\n'* || "$TARGET" == *$'\r'* ]]; then
    echo 'ERRO: informe um caminho ABSOLUTO iniciado por /, sem quebras de linha.'
    echo 'Nenhuma configuracao foi modificada.'
    exit 2
fi
DIR="$(realpath -m -- "$TARGET")"
case "$DIR" in
    /|"$HOME"|"$BASE")
        echo 'ERRO: informe uma pasta EXCLUSIVA para imagens, nao a raiz/home/pasta do app.'
        exit 2;;
esac
if [[ "$DIR" != "$BASE/"* ]]; then
    echo
    echo 'ATENCAO - DESTINO EXTERNO AO APLICATIVO'
    echo "As capturas criarao arquivos PNG em: $DIR"
    echo 'A desinstalacao NAO apagará essas imagens.'
    read -r -p 'Confirma salvar imagens FORA da pasta do Print RC? [s/N]: ' confirm || true
    [[ "${confirm,,}" == s || "${confirm,,}" == sim ]] || {
        echo 'Cancelado. Configuracao anterior preservada.'; exit 1;
    }
else
    echo "As imagens ficarao DENTRO do Print RC: $DIR"
fi

CREATE_DIR=0
if [[ -e "$DIR" ]]; then
    [[ -d "$DIR" && -w "$DIR" && -x "$DIR" ]] || {
        echo "Pasta nao e um diretorio gravavel: $DIR"
        exit 2
    }
else
    echo "Esta pasta ainda nao existe: $DIR"
    echo 'Ela SOMENTE sera criada depois de voce confirmar as preferencias.'
    CREATE_DIR=1
fi

echo
echo 'Copiar CADA captura para a AREA DE TRANSFERENCIA?'
echo 'SIM: tambem permite colar a imagem com Ctrl+V.'
echo 'NAO: salva apenas o arquivo PNG, sem manter o processo de clipboard.'
echo 'Enter mantem a escolha anterior; em instalacoes novas, o padrao e SIM.'
while :; do
    read -r -p 'Deseja copiar automaticamente para Ctrl+V? [s/n, Enter=manter]: ' choice || true
    case "${choice,,}" in
        '') CLIP="${PREVIOUS_CLIP:-1}"; break ;;
        s|sim) CLIP=1; break ;;
        n|nao|não) CLIP=0; break ;;
        *) echo 'Responda s (sim) ou n (nao).' ;;
    esac
done

echo
echo '================ CONFIRMACAO ================'
echo "Pasta das imagens: $DIR"
if [[ "$CLIP" == 1 ]]; then echo 'Copiar para Ctrl+V: SIM'; else echo 'Copiar para Ctrl+V: NAO'; fi
echo "Arquivo de configuracao: $CONFIG"
echo 'Nenhum programa do sistema sera instalado.'
echo '============================================='
read -r -p 'Salvar estas preferencias? [s/N]: ' confirm || true
[[ "${confirm,,}" == s || "${confirm,,}" == sim ]] || {
    echo 'Cancelado: opcoes anteriores mantidas.'; exit 1;
}
umask 077
if [[ "$CREATE_DIR" == 1 ]]; then
    mkdir -p -- "$DIR"
    echo "Diretorio de imagens CRIADO: $DIR"
fi
mkdir -p -- "$BASE/config"
temp="$(mktemp "$BASE/config/.opcoes-XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
printf 'save_dir=%s\ncopy_clipboard=%s\n' "$DIR" "$CLIP" > "$temp"
# O inventario precisa acompanhar preferencias gravadas pelo PROPRIO app,
# senao a desinstalacao deixa config/opcoes.conf e a pasta principal para tras.
if [[ -f "$BASE/config/arquivos-instalados.sha256" ]]; then
    if [[ ! -f "$BASE/scripts/inventario.sh" || -L "$BASE/scripts/inventario.sh" ]]; then
        echo 'ERRO: nao foi possivel atualizar inventario de seguranca.' >&2
        exit 2
    fi
    source "$BASE/scripts/inventario.sh"
fi
mv -f -- "$temp" "$CONFIG"
trap - EXIT
if [[ -f "$BASE/config/arquivos-instalados.sha256" ]]; then
    if ! print_rc_atualizar_inventario_opcoes "$BASE"; then
        echo 'AVISO: preferencias salvas, mas inventario nao atualizado.' >&2
        echo 'Ao desinstalar, pode ser necessario revisar config/opcoes.conf.' >&2
        exit 2
    fi
fi
echo
echo 'PREFERENCIAS SALVAS COM SUCESSO.'
echo "Arquivo: $CONFIG"
echo "Capturas PNG: $DIR"
echo 'Para alterar depois, execute: bash configurar.sh'
