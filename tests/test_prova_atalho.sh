#!/usr/bin/env bash
# Prova de ativacao do atalho. Isolada, nunca usa o escritorio real do usuario.
set -Eeuo pipefail
export PRINT_RC_LANG=pt-BR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
APP="$TMP/Print RC com espacos"
mkdir -p "$APP/scripts" "$APP/bin" "$APP/config"
cp -a "$ROOT/i18n" "$APP/"
cp "$ROOT/scripts/i18n.sh" "$ROOT/scripts/messages.bash" "$ROOT/scripts/print_rc_i18n.py" "$APP/scripts/"
cp -- "$ROOT/iniciar.sh" "$APP/iniciar.sh"
cp -- "$ROOT/bin/print-rc-launcher" "$APP/bin/"
cp -- "$ROOT/scripts/provar-atalho.sh" "$APP/scripts/provar-atalho.sh"
cat > "$APP/bin/print-rc" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == --probe-overlay ]]; then
    printf 'PRINT_RC_OVERLAY_READY=%s\n' "$2"
else
    printf 'BINARIO_EXECUTADO\n' >> "$PRINT_RC_PROVA_LOG"
fi
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
grep -F 'OVERLAY_VERIFICADO:' "$TMP/prova-ok.log"
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

echo '[5] Processo sem prova de overlay nao pode aprovar o teste'
rm -f -- "$APP/config/.print-rc-prova-resposta"
printf '#!/bin/bash\nexit 0\n' > "$APP/bin/print-rc"
export PRINT_RC_PROVA_PASSOS=6
bash "$APP/scripts/provar-atalho.sh" > "$TMP/prova-falso.log" 2>&1 &
PID=$!
for ((i=0;i<80;i++)); do
    [[ -f "$APP/config/.print-rc-prova-armada" ]] && break
    sleep 0.03
done
if bash "$APP/iniciar.sh"; then echo 'ERROR: false GUI success'; exit 1; fi
if wait "$PID"; then echo 'ERROR: false activation'; exit 1; fi
test ! -e "$APP/config/.print-rc-prova-resposta"
