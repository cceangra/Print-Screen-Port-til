#!/usr/bin/env bash
# Teste de instalacao portatil com pasta unica, sem instalar bibliotecas.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export XDG_SESSION_TYPE=x11

[[ -x "$ROOT/bin/print-rc" ]] || { echo 'Antes execute make portable'; exit 1; }
"$ROOT/bin/print-rc" --self-test

make_source() {
    local d="$1"
    mkdir -p -- "$d"
    cp -a -- "$ROOT/instalar.sh" "$ROOT/iniciar.sh" "$ROOT/desinstalar.sh" \
      "$ROOT/Makefile" "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/configurar.sh" \
      "$ROOT/src" "$ROOT/scripts" "$ROOT/bin" "$d/"
    # Simular ZIP que perdeu bit de execucao, como ocorreu no Q4OS.
    chmod 644 "$d/iniciar.sh"
}
echo '[1] Mantendo a pasta extraida: nao instalar pacotes nem criar segunda copia'
make_source "$TEMP/origem1"
printf '\n\n\ns\nn\n' | bash "$TEMP/origem1/instalar.sh"
test -x "$TEMP/origem1/bin/print-rc"
test -x "$TEMP/origem1/iniciar.sh"
test "$(stat -c %a "$TEMP/origem1/iniciar.sh")" = 744
test -f "$TEMP/origem1/.print-rc-installation"
test -f "$TEMP/origem1/config/opcoes.conf"
test -f "$TEMP/origem1/config/arquivos-instalados.sha256"
grep -F "desinstalar.sh" "$TEMP/origem1/config/arquivos-instalados.sha256"

grep -Fx "save_dir=$TEMP/origem1/capturas" "$TEMP/origem1/config/opcoes.conf"
grep -Fx "copy_clipboard=1" "$TEMP/origem1/config/opcoes.conf"
test "$(sed -n '2p' "$TEMP/origem1/.print-rc-installation")" = "$TEMP/origem1"

echo '[2] Movendo a pasta inteira para um destino com espacos'
make_source "$TEMP/origem2"
FINAL="$TEMP/pasta final/Print RC"
printf '%s\ns\n\n\ns\nn\n' "$FINAL" | bash "$TEMP/origem2/instalar.sh"
test ! -e "$TEMP/origem2"
test -x "$FINAL/bin/print-rc"
test -x "$FINAL/iniciar.sh"
test -f "$FINAL/src/main.cpp"
test -f "$FINAL/instalar.sh"
test -f "$FINAL/configurar.sh"
test -f "$FINAL/config/opcoes.conf"
test -f "$FINAL/config/arquivos-instalados.sha256"
test "$(sed -n '2p' "$FINAL/.print-rc-installation")" = "$FINAL"

echo '[3] Recusar sobrescrever pasta existente'
make_source "$TEMP/origem3"
mkdir -p "$TEMP/existente"
printf 'usuario' > "$TEMP/existente/dados.txt"
if printf '%s\n' "$TEMP/existente" | bash "$TEMP/origem3/instalar.sh"; then
    echo 'ERRO: permitiu destino existente'; exit 1
fi
test -f "$TEMP/origem3/instalar.sh"
test "$(cat "$TEMP/existente/dados.txt")" = usuario

echo '[4] Recusar binario ausente sem mover arquivos'
make_source "$TEMP/origem4"
rm -f -- "$TEMP/origem4/bin/print-rc"
if bash "$TEMP/origem4/instalar.sh"; then
    echo 'ERRO: permitiu pacote incompleto'; exit 1
fi
test -e "$TEMP/origem4/instalar.sh"
echo '[5] Reinstalar em pasta preservada com prints, sem sobrescrever nada'
make_source "$TEMP/origem5"
FINAL5="$TEMP/pasta com fotos/Print-RC"
mkdir -p "$FINAL5/capturas" "$FINAL5/src" "$FINAL5/config"
printf 'PRINT IMPORTANTE\n' > "$FINAL5/capturas/print-antigo.png"
printf 'DESENHO PROPRIO\n' > "$FINAL5/src/arquivo-pessoal.png"
printf 'CONFIG PESSOAL\n' > "$FINAL5/config/meus-dados.txt"
printf '%s\ns\n\n\ns\nn\n' "$FINAL5" | bash "$TEMP/origem5/instalar.sh"
test ! -e "$TEMP/origem5"
test -x "$FINAL5/bin/print-rc"
test -x "$FINAL5/iniciar.sh"
test -f "$FINAL5/config/arquivos-instalados.sha256"
test "$(cat "$FINAL5/capturas/print-antigo.png")" = 'PRINT IMPORTANTE'
test "$(cat "$FINAL5/src/arquivo-pessoal.png")" = 'DESENHO PROPRIO'
test "$(cat "$FINAL5/config/meus-dados.txt")" = 'CONFIG PESSOAL'

echo '[6] Conflito com arquivo pessoal de mesmo nome bloqueia reinstalacao'
make_source "$TEMP/origem6"
FINAL6="$TEMP/pasta com conflito/Print-RC"
mkdir -p "$FINAL6"
printf 'README PESSOAL\n' > "$FINAL6/README.md"
if printf '%s\n' "$FINAL6" | bash "$TEMP/origem6/instalar.sh"; then
    echo 'ERRO: reinstalacao sobrescreveu arquivo pessoal.'
    exit 1
fi
test "$(cat "$FINAL6/README.md")" = 'README PESSOAL'
test -f "$TEMP/origem6/README.md"
echo '[7] Rejeitar marcador simbolico para arquivo do usuario'
make_source "$TEMP/origem7"
USER_DATA="$TEMP/arquivo-pessoal-importante.txt"
printf 'DADO PESSOAL ORIGINAL\n' > "$USER_DATA"
ln -s -- "$USER_DATA" "$TEMP/origem7/.print-rc-installation"
if bash "$TEMP/origem7/instalar.sh"; then
    echo 'ERRO: instalador aceitou marcador apontando para arquivo pessoal.'
    exit 1
fi
test "$(cat "$USER_DATA")" = 'DADO PESSOAL ORIGINAL'

echo '[8] Rejeitar diretorio de configuracao simbolico'
make_source "$TEMP/origem8"
mkdir -p "$TEMP/config-de-terceiros"
printf 'PREFERENCIAS DE TERCEIROS\n' > "$TEMP/config-de-terceiros/meus-dados.txt"
ln -s -- "$TEMP/config-de-terceiros" "$TEMP/origem8/config"
if bash "$TEMP/origem8/instalar.sh"; then
    echo 'ERRO: instalador aceitou config externa.'
    exit 1
fi
test "$(cat "$TEMP/config-de-terceiros/meus-dados.txt")" = 'PREFERENCIAS DE TERCEIROS'
test ! -e "$TEMP/config-de-terceiros/opcoes.conf"

echo '[9] Falha ao cadastrar atalho nao deixa marcador falso de instalacao'
make_source "$TEMP/origem9"
printf 'raise SystemExit(43)\n' > "$TEMP/origem9/scripts/atalho.py"
# Reproduzir Print fisicamente identificado nesta prova de falha posterior.
# A deteccao verdadeira e testada num X11 virtual em teste proprio.
cp -- "$TEMP/origem9/bin/print-rc" "$TEMP/print-rc-original"
export PRINT_RC_TEST_BINARY="$TEMP/print-rc-original"
cat > "$TEMP/origem9/bin/print-rc" <<'SH'
#!/bin/bash
if [[ "${1:-}" == --detectar-print ]]; then
    printf 'PRINT_RC_KEY=Print\n'
else
    exec "$PRINT_RC_TEST_BINARY" "$@"
fi
SH
chmod +x "$TEMP/origem9/bin/print-rc"
if printf '\n\n\ns\ns\n' | XDG_CURRENT_DESKTOP=Trinity bash "$TEMP/origem9/instalar.sh"; then
    echo 'ERRO: falha da integracao de atalho nao interrompeu instalacao.'
    exit 1
fi
test ! -e "$TEMP/origem9/.print-rc-installation"
test ! -e "$TEMP/origem9/config/arquivos-instalados.sha256"
test -f "$TEMP/origem9/iniciar.sh"

echo '[10] Sem tecla fisica detectada nao cadastrar atalho nem mentir sucesso'
make_source "$TEMP/origem10"
cp -- "$TEMP/origem10/bin/print-rc" "$TEMP/print-rc-antigo10"
export PRINT_RC_TEST_BINARY="$TEMP/print-rc-antigo10"
cat > "$TEMP/origem10/bin/print-rc" <<'SH'
#!/bin/bash
if [[ "${1:-}" == --detectar-print ]]; then
    echo 'SIMULACAO: nenhum Print detectado' >&2
    exit 4
else
    exec "$PRINT_RC_TEST_BINARY" "$@"
fi
SH
chmod +x "$TEMP/origem10/bin/print-rc"
printf '\n\n\ns\ns\n' | XDG_CURRENT_DESKTOP=Trinity bash "$TEMP/origem10/instalar.sh"
test -f "$TEMP/origem10/.print-rc-installation"
test -f "$TEMP/origem10/config/arquivos-instalados.sha256"
test ! -e "$TEMP/origem10/config/atalho-state.json"
test ! -e "$TEMP/origem10/backups/khotkeysrc.antes"

echo '[11] Apos timeout, SIM inicia segunda tentativa e permite cadastrar Print'
make_source "$TEMP/origem11"
export PRINT_RC_TEST_ATTEMPTS="$TEMP/tentativas11"
export PRINT_RC_TEST_REGISTER="$TEMP/cadastro11"
cp -- "$TEMP/origem11/bin/print-rc" "$TEMP/original11"
export PRINT_RC_TEST_BINARY="$TEMP/original11"
cat > "$TEMP/origem11/bin/print-rc" <<'SH'
#!/bin/bash
if [[ "${1:-}" == --detectar-print ]]; then
    echo tentativa >> "$PRINT_RC_TEST_ATTEMPTS"
    if [[ "$(wc -l < "$PRINT_RC_TEST_ATTEMPTS")" == 1 ]]; then
        exit 4
    fi
    echo 'PRINT_RC_KEY=Print'
else
    exec "$PRINT_RC_TEST_BINARY" "$@"
fi
SH
chmod +x "$TEMP/origem11/bin/print-rc"
cat > "$TEMP/origem11/scripts/atalho.py" <<'PY'
import os
from pathlib import Path
import sys
assert sys.argv[1] == 'install'
assert sys.argv[sys.argv.index('--key')+1] == 'Print'
Path(os.environ['PRINT_RC_TEST_REGISTER']).write_text('Print cadastrado\n')
PY
printf '\n\n\ns\ns\ns\n' | XDG_CURRENT_DESKTOP=Trinity \
    bash "$TEMP/origem11/instalar.sh" > "$TEMP/teste11.log" 2>&1
test "$(wc -l < "$PRINT_RC_TEST_ATTEMPTS")" -eq 2
test "$(cat "$PRINT_RC_TEST_REGISTER")" = 'Print cadastrado'
grep -F 'Tentar novamente? [s/N]:' "$TEMP/teste11.log"
test -f "$TEMP/origem11/.print-rc-installation"

echo '[12] Se responder NAO ao timeout, encerrar leitura sem registrar atalho'
make_source "$TEMP/origem12"
export PRINT_RC_TEST_ATTEMPTS="$TEMP/tentativas12"
export PRINT_RC_TEST_REGISTER="$TEMP/cadastro12"
cp -- "$TEMP/origem12/bin/print-rc" "$TEMP/original12"
export PRINT_RC_TEST_BINARY="$TEMP/original12"
cat > "$TEMP/origem12/bin/print-rc" <<'SH'
#!/bin/bash
if [[ "${1:-}" == --detectar-print ]]; then
    echo tentativa >> "$PRINT_RC_TEST_ATTEMPTS"
    exit 4
else
    exec "$PRINT_RC_TEST_BINARY" "$@"
fi
SH
chmod +x "$TEMP/origem12/bin/print-rc"
cat > "$TEMP/origem12/scripts/atalho.py" <<'PY'
raise SystemExit('ERRO: nao deveria tentar registrar tecla')
PY
printf '\n\n\ns\nn\n' | XDG_CURRENT_DESKTOP=Trinity \
    bash "$TEMP/origem12/instalar.sh" > "$TEMP/teste12.log" 2>&1
test "$(wc -l < "$PRINT_RC_TEST_ATTEMPTS")" -eq 1
test ! -e "$TEMP/origem12/config/atalho-state.json"
test -f "$TEMP/origem12/.print-rc-installation"
grep -F 'Tentar novamente? [s/N]:' "$TEMP/teste12.log"
grep -F 'nenhuma tecla sera associada' "$TEMP/teste12.log"

echo '[13] Esc cancela sem perguntar tentar novamente'
make_source "$TEMP/origem13"
cp -- "$TEMP/origem13/bin/print-rc" "$TEMP/original13"
export PRINT_RC_TEST_BINARY="$TEMP/original13"
cat > "$TEMP/origem13/bin/print-rc" <<'SH'
#!/bin/bash
if [[ "${1:-}" == --detectar-print ]]; then
    exit 5
else
    exec "$PRINT_RC_TEST_BINARY" "$@"
fi
SH
chmod +x "$TEMP/origem13/bin/print-rc"
cat > "$TEMP/origem13/scripts/atalho.py" <<'PY'
raise SystemExit('ERRO: nao deveria tentar registrar tecla')
PY
printf '\n\n\ns\n' | XDG_CURRENT_DESKTOP=Trinity \
    bash "$TEMP/origem13/instalar.sh" > "$TEMP/teste13.log" 2>&1
test -f "$TEMP/origem13/.print-rc-installation"
! grep -Fq 'Tentar novamente?' "$TEMP/teste13.log"
grep -F 'cancelada com Esc' "$TEMP/teste13.log"

echo 'OK: instalacao sem compilar, mover pasta completa, recusa sobrescrita.'
