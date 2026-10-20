#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID} -ne 0 ]] || { echo 'Nao execute como root.'; exit 1; }
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ ! -f "$BASE/.print-rc-installation" ]]; then
    echo 'Pasta sem marcador de instalacao. Remocao recusada.'; exit 2
fi
mapfile -t marker < "$BASE/.print-rc-installation"
if [[ ${marker[0]:-} != PRINT-RC || ${marker[1]:-} != "$BASE" ]]; then
    echo 'Marcador nao corresponde a este caminho. Remocao recusada.'; exit 2
fi
case "$BASE" in
    /|"$HOME"|/home|/usr|/usr/local)
        echo 'Destino protegido. Remocao recusada.'; exit 2;;
esac

STATE="$BASE/config/atalho-state.json"
EXTERNAL="$HOME/.trinity/share/config/khotkeysrc"
OPTIONS="$BASE/config/opcoes.conf"
IMAGE_DIR=''
if [[ -f "$OPTIONS" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in save_dir=*) IMAGE_DIR="${line#save_dir=}" ;; esac
    done < "$OPTIONS"
fi

echo '========================================================'
echo '          DESINSTALADOR PRINT RC'
echo '========================================================'
echo "Pasta interna que sera APAGADA: $BASE"
echo 'Arquivos externos do Linux:'
if [[ -f "$STATE" ]]; then
    echo "  $EXTERNAL"
    if grep -Eq '"created_file"[[:space:]]*:[[:space:]]*true' "$STATE"; then
        echo '  OPERACAO: EXCLUIR se foi criado pelo Print RC e nao recebeu outros dados.'
    else
        echo '  OPERACAO: MANTER o arquivo original e remover apenas as alteracoes do Print RC.'
    fi
    echo '  Se nao for seguro restaurar/excluir, a desinstalacao para e conserva backups.'
else
    echo '  NENHUM registrado por esta instalacao: nada sera alterado fora da pasta.'
fi
echo '---------------- IMAGENS SALVAS ----------------'
if [[ -n "$IMAGE_DIR" ]]; then
    echo "Pasta de imagens configurada: $IMAGE_DIR"
    if [[ "$IMAGE_DIR" == "$BASE/"* ]]; then
        echo 'INTERNA: dentro da pasta do aplicativo.'
        echo 'A desinstalacao pode APAGAR estas imagens; exigirei confirmacao separada.'
    else
        echo 'EXTERNA: imagens e diretorio serao PRESERVADOS na desinstalacao.'
    fi
else
    echo 'Nenhuma pasta de imagem registrada nesta instalacao.'
fi
echo '-----------------------------------------------'
echo 'O Linux/X11, outros programas e dependencias do sistema NAO serao removidos.'
echo '========================================================'
mapfile -d '' -t IMGFILES < <(find "$BASE" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) -print0)
if (( ${#IMGFILES[@]} > 0 )); then
    echo "ATENCAO: ${#IMGFILES[@]} imagem(ns) encontrada(s) na pasta INTEIRA do Print RC."
    echo 'Inclui capturas anteriores, mesmo se a configuracao mudou.'
    for ((i=0; i<${#IMGFILES[@]} && i<15; i++)); do printf '  %s\n' "${IMGFILES[i]}"; done
    if (( ${#IMGFILES[@]} > 15 )); then echo "  e mais $(("${#IMGFILES[@]}"-15)) imagem(ns)"; fi
    echo 'Cancele para mover suas imagens a um local seguro antes de desinstalar.'
    read -r -p 'Para apagar essas imagens digite APAGAR IMAGENS: ' imgs || true
    [[ "$imgs" == 'APAGAR IMAGENS' ]] || {
        echo 'Desinstalacao CANCELADA. Suas imagens foram preservadas.'
        exit 1
    }
fi
read -r -p 'Para confirmar a desinstalacao digite exatamente REMOVER: ' answer || true
[[ "$answer" == REMOVER ]] || { echo 'Cancelado. Nada removido.'; exit 1; }

if [[ -f "$STATE" ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo 'Python3 indisponivel para restaurar o atalho.'
        echo 'Pasta e backup mantidos. Nenhum arquivo externo foi apagado.'
        exit 1
    fi
    python3 "$BASE/scripts/atalho.py" remove --base "$BASE" || {
        echo 'Nao consegui restaurar o atalho com seguranca. Pasta e backup preservados.'
        exit 1
    }
fi
cd -- "$HOME"
rm -rf -- "$BASE"
echo 'PASTA PRINT RC EXCLUIDA.'
echo 'Encerre a sessao Trinity e entre novamente para aplicar o atalho.'
