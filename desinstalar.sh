#!/usr/bin/env bash
# Print RC - remocao seletiva; NUNCA remove capturas nem dados pessoais.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Nao execute com sudo/root.'; exit 1; }

BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MARKER="$BASE/.print-rc-installation"
if [[ ! -f "$MARKER" || -L "$MARKER" ]]; then
    echo 'Instalacao nao reconhecida. Nao vou remover arquivos.'; exit 2
fi
mapfile -t marker < "$MARKER"
if [[ ${marker[0]:-} != PRINT-RC || ${marker[1]:-} != "$BASE" ]]; then
    echo 'Pasta difere do registro de instalacao. Nada foi removido.'; exit 2
fi
case "$BASE" in
    /|"$HOME"|/home|/usr|/usr/local|/tmp|/var)
        echo 'Destino protegido. Nao vou remover arquivos.'; exit 2;;
esac

# Um diretorio simbolico poderia apontar para dados externos. Recusar.
for dir in bin config backups capturas src scripts tests .github .github/workflows; do
    if [[ -L "$BASE/$dir" ]]; then
        echo "ATENCAO: caminho simbolico inesperado: $BASE/$dir"
        echo 'Remocao bloqueada para preservar arquivos externos.'
        exit 2
    fi
done
STATE="$BASE/config/atalho-state.json"
STATE_XFCE="$BASE/config/atalho-xfce.json"
if [[ -L "$STATE_XFCE" ]]; then
    echo 'Registro Xfce e um link simbolico inesperado. Remocao bloqueada.'
    exit 2
fi
if [[ -L "$STATE" ]]; then
    echo 'Registro do atalho e link simbolico. Remocao bloqueada.'
    exit 2
fi
TRINITY_HOME="${TDEHOME:-$HOME/.trinity}"
EXTERNAL="$TRINITY_HOME/share/config/khotkeysrc"
OPTIONS="$BASE/config/opcoes.conf"
IMAGE_DIR=''
if [[ -f "$OPTIONS" && ! -L "$OPTIONS" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in save_dir=*) IMAGE_DIR="${line#save_dir=}" ;; esac
    done < "$OPTIONS"
fi

echo '======================================================'
echo '          DESINSTALAR PRINT RC - SEGURO'
echo '======================================================'
echo "Aplicativo instalado em: $BASE"
echo
echo '1. Remove SOMENTE os arquivos conhecidos do Print RC.'
echo '2. Desfaz somente a atribuicao Print feita pelo Print RC.'
echo '3. NUNCA exclui prints, PNG, JPG ou arquivos pessoais.'
echo '4. Pastas com imagens ou arquivos desconhecidos ficam no disco.'
if [[ -n "$IMAGE_DIR" ]]; then
    echo "Pasta de imagens registrada: $IMAGE_DIR"
    echo 'ESSA PASTA E SUAS IMAGENS NAO SERAO APAGADAS.'
fi
if [[ -f "$STATE_XFCE" ]]; then
    echo 'Atalho Xfce a restaurar: /commands/custom/Print (xfce4-keyboard-shortcuts)'
    echo 'O Xfce pode gravar essa preferencia em ~/.config/xfce4/.'
fi
if [[ -f "$STATE" ]]; then
    echo "Atalho externo a restaurar: $EXTERNAL"
    echo 'Arquivo preexistente: preservar; arquivo criado: remover somente se seguro.'
else
    echo 'Nao ha atalho global registrado por esta instalacao.'
    echo 'Atalhos registrados MANUALMENTE devem ser retirados pelo proprio usuario.'
fi
echo
echo 'IMPORTANTE: se imagens estiverem DENTRO da pasta do app,'
echo 'a pasta continuara existindo, apenas com os dados preservados.'
echo 'Processos executando este Print RC poderao ser encerrados:'
echo 'isso libera o programa para remocao, mas invalida clipboard ainda ativo.'
echo '======================================================'
read -r -p 'Digite DESINSTALAR para confirmar (nenhuma imagem sera apagada): ' response || true
[[ "$response" == DESINSTALAR ]] || { echo 'Cancelado sem mudancas.'; exit 1; }

# Encerrar somente processos deste executavel instalado, NUNCA processos de
# outros programas ou de outra copia do Print RC. Sem kill -9.
# Em Linux, /proc/PID/exe identifica o executavel carregado.
# Isso evita apagar binario ainda em uso e libera o clipboard mantido pelo app.
for proc_exe in /proc/[0-9]*/exe; do
    [[ -L "$proc_exe" ]] || continue
    if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" != "$BASE/bin/print-rc" ]]; then
        continue
    fi
    pid="${proc_exe#/proc/}"
    pid="${pid%%/*}"
    [[ -O "/proc/$pid" ]] || continue
    echo "Encerrando somente Print RC instalado nesta pasta (PID $pid)."
    kill -TERM -- "$pid" 2>/dev/null || continue
    for attempt in {1..20}; do
        if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" != "$BASE/bin/print-rc" ]]; then
            break
        fi
        sleep 0.1
    done
    if [[ "$(readlink -f -- "$proc_exe" 2>/dev/null || true)" == "$BASE/bin/print-rc" ]]; then
        echo 'Este processo ainda nao encerrou. Desinstalacao interrompida sem apagar arquivos.'
        exit 1
    fi
done

# Restaurar SOMENTE atalhos criados por esta instalacao, antes de
# remover os respectivos registros. Nunca apagar atalhos configurados a mao.
if [[ -f "$STATE_XFCE" ]]; then
    command -v python3 >/dev/null 2>&1 || {
        echo 'Python3 ausente: remocao do atalho Xfce e do app cancelada.'
        exit 1
    }
    if [[ ! -f "$BASE/scripts/atalho_xfce.py" || -L "$BASE/scripts/atalho_xfce.py" ]]; then
        echo 'Integrador Xfce ausente/inseguro. Nada sera apagado.'
        exit 1
    fi
    python3 "$BASE/scripts/atalho_xfce.py" remove --base "$BASE" || {
        echo 'Nao foi possivel restaurar atalho Xfce. Programa preservado.'
        exit 1
    }
fi
if [[ -f "$STATE" ]]; then
    command -v python3 >/dev/null 2>&1 || {
        echo 'Python3 nao disponivel. Programa e imagens preservados.'
        exit 1
    }
    if [[ ! -f "$BASE/scripts/atalho.py" || -L "$BASE/scripts/atalho.py" ]]; then
        echo 'Integrador de atalhos ausente/inseguro. Nao vou apagar o app.'
        exit 1
    fi
    python3 "$BASE/scripts/atalho.py" remove --base "$BASE" || {
        echo 'Nao foi possivel restaurar a tecla com seguranca.'
        echo 'Programa, imagens e backup foram preservados.'
        exit 1
    }
fi

# Somente arquivos com hash registrado na primeira instalacao podem ser excluidos.
# Se um arquivo mudou (ou foi substituido por foto/documento), permanece intocado.
MANIFEST="$BASE/config/arquivos-instalados.sha256"
if [[ ! -f "$MANIFEST" || -L "$MANIFEST" ]]; then
    echo 'SEM INVENTARIO CONFIAVEL: nenhum arquivo local sera apagado.'
    echo 'O atalho foi tratado acima. Seus arquivos e imagens foram preservados.'
    echo 'Em instalacoes antigas sem inventario, a limpeza de arquivos exige revisao manual.'
    exit 2
fi
if [[ ! -f "$BASE/scripts/inventario.sh" || -L "$BASE/scripts/inventario.sh" ]]; then
    echo 'Lista de arquivos conhecidos nao existe ou nao e segura. Nada local removido.'
    exit 2
fi
source "$BASE/scripts/inventario.sh"
declare -A ALLOWED=()
declare -A EXPECTED=()
for rel in "${PRINT_RC_KNOWN[@]}"; do ALLOWED["$rel"]=1; done

# Derivar as pastas somente da lista fixa de arquivos conhecidos.
# Inclui diretorios ocultos (.github) e subdiretorios futuros.
# Nunca entrar em pastas externas nem seguir links simbolicos.
declare -A KNOWN_DIRS=([capturas]=1 [config]=1 [backups]=1)
for rel in "${PRINT_RC_KNOWN[@]}"; do
    parent="$rel"
    while [[ "$parent" == */* ]]; do
        parent="${parent%/*}"
        KNOWN_DIRS["$parent"]=1
    done
done
for dir in "${!KNOWN_DIRS[@]}"; do
    if [[ -L "$BASE/$dir" ]]; then
        echo "Diretorio conhecido virou link simbolico: $BASE/$dir"
        echo 'Remocao interrompida antes de apagar arquivos locais.'
        exit 2
    fi
done

while IFS=$'\t' read -r checksum rel || [[ -n "${checksum:-}${rel:-}" ]]; do
    [[ -z "${checksum:-}" && -z "${rel:-}" ]] && continue
    if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ || ! -v 'ALLOWED[$rel]' || -v 'EXPECTED[$rel]' ]]; then
        echo "Inventario invalido. Nada local removido: $rel"
        exit 2
    fi
    EXPECTED["$rel"]="$checksum"
done < "$MANIFEST"
if [[ ! -v 'EXPECTED[desinstalar.sh]' || ! -v 'EXPECTED[.print-rc-installation]' ]]; then
    echo 'Inventario incompleto. Nada local removido.'
    exit 2
fi

for rel in "${PRINT_RC_KNOWN[@]}"; do
    file="$BASE/$rel"
    if [[ -L "$file" ]]; then
        echo "LINK SIMBOLICO PRESERVADO (nao pertence ao app): $file"
        continue
    fi
    if [[ ! -f "$file" ]]; then continue; fi
    if [[ ! -v 'EXPECTED[$rel]' ]]; then
        echo "ARQUIVO SEM REGISTRO PRESERVADO: $file"
        continue
    fi
    if ! current="$(sha256sum -- "$file")"; then
        echo "Falha ao verificar hash de $file; arquivo preservado."
        continue
    fi
    current="${current%% *}"
    if [[ "$current" != "${EXPECTED[$rel]}" ]]; then
        echo "ARQUIVO MODIFICADO PELO USUARIO - PRESERVADO: $file"
        continue
    fi
    rm -- "$file" || {
        echo "Falha ao remover arquivo original: $file"
        echo 'Imagens e outros arquivos pessoais seguem preservados.'
        exit 1
    }
done

# Este inventario tambem pertence ao Print RC e fica somente dentro da pasta.
rm -- "$MANIFEST" || { echo 'Inventario nao pode ser removido.'; exit 1; }

# Apagar SOMENTE diretorios conhecidos e VAZIOS, dos mais profundos
# para os pais. Isso inclui .github, tests e novos caminhos da lista fixa.
# Nenhum rm -rf, nenhuma exclusao recursiva nem seguimento de symlinks.
mapfile -t ORDERED_DIRS < <(
    printf '%s\n' "${!KNOWN_DIRS[@]}" |
        awk '{ print length($0) "\t" $0 }' |
        LC_ALL=C sort -rn | cut -f2-
)
for dir in "${ORDERED_DIRS[@]}"; do
    rmdir -- "$BASE/$dir" 2>/dev/null || true
done
cd -- "$HOME"
rmdir -- "$BASE" 2>/dev/null || true
if [[ -d "$BASE" ]]; then
    echo
    echo "ARQUIVOS PRESERVADOS EM: $BASE"
    echo 'A pasta nao foi excluida porque ainda contem dados.'
else
    echo 'Pasta do app removida porque estava vazia.'
fi
if [[ -n "$IMAGE_DIR" && "$IMAGE_DIR" != "$BASE/"* ]]; then
    echo "IMAGENS EXTERNAS PRESERVADAS: $IMAGE_DIR"
fi
echo 'Atalho Print RC removido quando gerenciado por esta instalacao.'
echo 'Se necessario, saia e entre novamente no desktop para atualizar os atalhos.'
echo 'O ZIP baixado fora da instalacao nao foi modificado nem removido.'
