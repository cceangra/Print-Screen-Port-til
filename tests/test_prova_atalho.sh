#!/usr/bin/env bash
# Prova de ativacao do atalho. Isolada, nunca usa o escritorio real do usuario.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
APP="$TMP/Print RC com espacos"
mkdir -p "$APP/scripts" "$APP/bin" "$APP/config"
cp -- "$ROOT/iniciar.sh" "$APP/iniciar.sh"
cp -- "$ROOT/scripts/provar-atalho.sh" "$APP/scripts/provar-atalho.sh"
cat > "$APP/bin/print-rc" <<'SH'
#!/usr/bin/env bash
printf 'BINARIO_EXECUTADO\n' >> "$PRINT_RC_PROVA_LOG"
SH
chmod +x "$APP/bin/print-rc"
export PRINT_RC_PROVA_LOG="$TMP/executado.log"
export DISPLAY=:99 XDG_SESSION_TYPE=x11
export PRINT_RC_PROVA_PASSOS=12
echo '[1] Prova so aprova se o inicializador receber acionamento real'
bash "$APP/scripts/provar-atalho.sh" > "$TMP/prova-ok.log" 2>&1 &
PID=$!
for ((i=0;i<80;i++)); do
    [[ -f "$APP/config/.print-rc-prova-armada" ]] && break
    sleep 0.03
done
test -f "$APP/config/.print-rc-prova-armada"
bash "$APP/iniciar.sh"
wait "$PID"
grep -F 'ATIVACAO_CONFIRMADA:' "$TMP/prova-ok.log"
test ! -e "$PRINT_RC_PROVA_LOG"
test ! -e "$APP/config/.print-rc-prova-armada"
test ! -e "$APP/config/.print-rc-prova-resposta"
echo '[2] Sem acionamento externo, teste falha e limpa todos os arquivos'
export PRINT_RC_PROVA_PASSOS=4
CODE=0
bash "$APP/scripts/provar-atalho.sh" > "$TMP/prova-falhou.log" 2>&1 || CODE=$?
test "$CODE" -eq 1
grep -F 'ATIVACAO_NAO_CONFIRMADA:' "$TMP/prova-falhou.log"
test ! -e "$APP/config/.print-rc-prova-armada"
test ! -e "$APP/config/.print-rc-prova-resposta"
echo '[3] Marcador expirado NUNCA impede a captura real'
printf 'print-rc-expirado\n%s\n' "$(($(date +%s)-30))" > "$APP/config/.print-rc-prova-armada"
bash "$APP/iniciar.sh"
grep -F 'BINARIO_EXECUTADO' "$PRINT_RC_PROVA_LOG"
test ! -e "$APP/config/.print-rc-prova-resposta"
rm -f -- "$APP/config/.print-rc-prova-armada"
echo '[4] Protecao contra sobrescrita de arquivos preexistentes'
printf 'DADO_PESSOAL\n' > "$APP/config/.print-rc-prova-resposta"
CODE=0
bash "$APP/scripts/provar-atalho.sh" > "$TMP/prova-preexistente.log" 2>&1 || CODE=$?
test "$CODE" -eq 2
test "$(cat "$APP/config/.print-rc-prova-resposta")" = 'DADO_PESSOAL'
echo 'OK: prova confirma launcher, falha sem acionamento, nao rouba a tela e limpa temporarios.'
