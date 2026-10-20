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
case "$BASE" in /|"$HOME"|/home|/usr|/usr/local) echo 'Destino protegido. Remocao recusada.'; exit 2;; esac
printf 'Pasta a remover: %s\n' "$BASE"
echo 'O atalho Trinity sera restaurado antes de apagar a pasta.'
echo 'Capturas e backups DENTRO desta pasta tambem serao removidos.'
read -r -p 'Para confirmar digite exatamente REMOVER: ' answer || true
[[ "$answer" == REMOVER ]] || { echo 'Cancelado.'; exit 1; }
python3 "$BASE/scripts/atalho.py" remove --base "$BASE" || {
  echo 'Nao consegui restaurar o atalho com seguranca. Pasta preservada.'; exit 1;
}
cd -- "$HOME"
rm -rf -- "$BASE"
echo 'Print RC removido. Encerre a sessao Trinity e entre novamente.'
