#!/usr/bin/env bash
# Print RC: configuracao interativa SEM pacotes externos.
set -Eeuo pipefail
[[ ${EUID} -ne 0 ]] || { echo 'Nao execute com sudo.'; exit 1; }

BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG="$BASE/config/opcoes.conf"
DEFAULT_DIR="$BASE/capturas"

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
if [[ -f "$CONFIG" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            save_dir=*) echo "Pasta atualmente configurada: ${line#save_dir=}" ;;
            copy_clipboard=1) echo 'Copia para area de transferencia: SIM' ;;
            copy_clipboard=0) echo 'Copia para area de transferencia: NAO' ;;
        esac
    done < "$CONFIG"
fi

read -r -p 'Digite o CAMINHO COMPLETO da pasta das imagens (Enter = padrao): ' supplied || true
TARGET="${supplied:-$DEFAULT_DIR}"
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

if [[ -e "$DIR" ]]; then
    [[ -d "$DIR" && -w "$DIR" && -x "$DIR" ]] || {
        echo "Pasta nao e um diretorio gravavel: $DIR"
        exit 2
    }
else
    echo "Esta pasta ainda nao existe: $DIR"
    read -r -p 'Deseja CRIAR esta pasta? [s/N]: ' confirm || true
    [[ "${confirm,,}" == s || "${confirm,,}" == sim ]] || {
        echo 'Cancelado, nenhuma pasta criada.'; exit 1;
    }
    mkdir -p -- "$DIR"
fi

echo
echo 'Copiar CADA captura para a AREA DE TRANSFERENCIA?'
echo 'SIM: tambem permite colar a imagem com Ctrl+V.'
echo 'NAO: salva apenas o arquivo PNG, sem manter o processo de clipboard.'
while :; do
    read -r -p 'Deseja copiar automaticamente para Ctrl+V? [S/n]: ' choice || true
    case "${choice,,}" in
        ''|s|sim) CLIP=1; break ;;
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
mkdir -p -- "$BASE/config"
temp="$(mktemp "$BASE/config/.opcoes-XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
printf 'save_dir=%s\ncopy_clipboard=%s\n' "$DIR" "$CLIP" > "$temp"
mv -f -- "$temp" "$CONFIG"
trap - EXIT
echo
echo 'PREFERENCIAS SALVAS COM SUCESSO.'
echo "Arquivo: $CONFIG"
echo "Capturas PNG: $DIR"
echo 'Para alterar depois, execute: bash configurar.sh'
