#!/usr/bin/env bash
# Print RC - remocao seletiva; NUNCA remove capturas nem dados pessoais.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Nao execute com sudo/root.'; exit 1; }

BASE="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd -P)"
MARKER="$BASE/.print-rc-installation"
if [[ ! -f "$MARKER" || -L "$MARKER" ]]; then
    echo 'Instalacao nao reconhecida. Nao vou remover arquivos.'; exit 2
fi
mapfile -t marker < "$MARKER"
if [[ \${marker[0]:-} != PRINT-RC || \${marker[1]:-} != "$BASE" ]]; then
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
if [[ -L "$STATE" ]]; then
    echo 'Registro do atalho e link simbolico. Remocao bloqueada.'
    exit 2
fi
EXTERNAL="$HOME/.trinity/share/config/khotkeysrc"
OPTIONS="$BASE/config/opcoes.conf"
IMAGE_DIR=''
if [[ -f "$OPTIONS" && ! -L "$OPTIONS" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in save_dir=*) IMAGE_DIR="\${line#save_dir=}" ;; esac
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
echo '======================================================'
read -r -p 'Digite DESINSTALAR para confirmar (nenhuma imagem sera apagada): ' response || true
[[ "$response" == DESINSTALAR ]] || { echo 'Cancelado sem mudancas.'; exit 1; }

# Restaurar a tecla antes de remover o programa ou seus backups.
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

# LISTA EXPLICITA: somente arquivos do programa, sem rm -r ou rm -rf.
# Nao apaga nenhum arquivo dentro de capturas/ nem diretorios nao vazios.
OWNED_FILES=(
    'bin/print-rc'
    'src/main.cpp' 'src/settings.hpp'
    'scripts/atalho.py'
    'tests/test_atalho.py' 'tests/test_settings.cpp'
    'tests/test_configuracao.sh' 'tests/test_instalacao.sh' 'tests/test_gui_x11.sh'
    '.github/workflows/testar.yml'
    'config/opcoes.conf' 'config/atalho-state.json'
    'backups/khotkeysrc.antes'
    'README.md' 'LICENSE' 'Makefile' '.gitignore'
    'instalar.sh' 'iniciar.sh' 'configurar.sh'
    '.print-rc-installation'
    'desinstalar.sh'
)

for rel in "\${OWNED_FILES[@]}"; do
    file="$BASE/$rel"
    if [[ -f "$file" || -L "$file" ]]; then
        rm -- "$file" || {
            echo "Erro ao remover arquivo do app: $file"
            echo 'Imagens nao foram tocadas. Confira manualmente os arquivos restantes.'
            exit 1
        }
    fi
done

# Apagar somente diretorios VAZIOS. Qualquer arquivo do usuario os preserva.
for dir in .github/workflows .github tests scripts src bin config backups capturas; do
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
echo 'Saia e entre na sessao Trinity para recarregar os atalhos.'
