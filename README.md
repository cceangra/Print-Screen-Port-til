# Print RC v0.2.0 — Linux X11 / pasta unica

Aplicativo de captura de uma regiao da tela em **C++**, com tela escurecida, selecao por mouse e copia da imagem como PNG para Ctrl+V. Criado principalmente para **Q4OS / Trinity / X11**, em computadores **x86_64**.

## BAIXAR: pacote pronto, sem `apt install`

**Baixe a versao empacotada:**

**[Print-RC-Linux-x86_64.zip — Downloads / Releases](https://github.com/cceangra/Print-Screen-Port-til/releases/latest/download/Print-RC-Linux-x86_64.zip)**

O ZIP contem **um unico diretorio `Print-RC/`**, com:
- `bin/print-rc`: executavel C++ **compilado estaticamente**; `ldd` nao lista bibliotecas compartilhadas para esse executavel;
- `instalar.sh`, `iniciar.sh`, `desinstalar.sh`;
- `src/main.cpp`, `Makefile`, `scripts/atalho.py` e documentacao;
- `config/`, `backups/`, `capturas/`: criados dentro da pasta durante a instalacao.

**Nao precisa executar `apt install`, instalar o compilador, `make`, `pkg-config` ou bibliotecas do aplicativo para usar este ZIP.** A compilacao e feita no GitHub antes do download.

### Instalar usando a pasta extraida

Extraia o ZIP. Abra um terminal **dentro da pasta `Print-RC`**, e execute:

```bash
bash instalar.sh
```

Escolha:
- **Enter**: manter tudo nesta unica pasta;
- Digitar `/home/rc/Apps/Print-RC`: mover **a propria pasta inteira** para esse destino, desde que ele nao exista.

O instalador NAO cria segunda copia, nao instala pacotes e nao sobrescreve pastas existentes. Pergunta separadamente se deseja registrar o atalho Print do Trinity, com confirmacao e backup.

**O ZIP original baixado pelo navegador e outro arquivo.** Se quiser 100% dos arquivos do download dentro da mesma pasta, guarde esse ZIP dentro de `Print-RC/` ou apague-o manualmente apos extrair. O instalador nao apaga documentos do usuario sem autorizacao.

### Instalar por terminal e nao deixar ZIP/pastas de extracao extras

No Q4OS, **se ja tiver `wget` e `unzip`**:

```bash
bash <<'BASH'
set -euo pipefail
DEST="$HOME/Apps/Print-RC"
if [[ -e "$DEST" ]]; then
  echo "A pasta ja existe: $DEST. Nada sera sobrescrito."
  exit 1
fi
command -v wget >/dev/null && command -v unzip >/dev/null || {
  echo 'wget ou unzip nao encontrado. Baixe e extraia o ZIP pelo navegador.'
  exit 1
}
mkdir -p "$DEST"
wget -O "$DEST/instalacao.zip" 'https://github.com/cceangra/Print-Screen-Port-til/releases/latest/download/Print-RC-Linux-x86_64.zip'
unzip -q "$DEST/instalacao.zip" -d "$DEST"
( shopt -s dotglob nullglob
  mv -- "$DEST/Print-RC/"* "$DEST/"
)
rmdir -- "$DEST/Print-RC"
rm -- "$DEST/instalacao.zip"
cd "$DEST"
bash instalar.sh
BASH
```

Isso extrai os arquivos diretamente para uma unica pasta definitiva. Nao executa `apt`.

## Usar

Apos a instalacao, pelo caminho escolhido:

```bash
bash /home/rc/Apps/Print-RC/iniciar.sh
```

A tela escurece levemente; pressione e arraste o botao esquerdo do mouse. Ao soltar, o PNG e copiado para a area de transferencia X11. Cole em um aplicativo compativel com imagem, com Ctrl+V. **Esc** ou botao direito cancela.

O capturador so inicia quando chamado; apos a selecao, a interface some. Em X11, ele pode manter um processo adormecido por **ate 30 minutos** para disponibilizar os bytes PNG no clipboard; depois encerra. Nao grava o print no disco por conta propria. Se um gerenciador externo assumir o clipboard, a imagem podera continuar disponivel.

### Tecla Print Screen

No Trinity, `instalar.sh` oferece registrar a tecla `Print` no atalho global. O instalador examina conflitos conhecidos em `~/.trinity/share/config/khotkeysrc`, apresenta acoes que encontrou e pede autorizacao antes de modificar qualquer registro. Os backups ficam em `Print-RC/backups/` e a desinstalacao tenta restaurar as alteracoes. Pode ser necessario sair e entrar novamente no Trinity.

A configuracao automatica do atalho usa `python3` **do sistema, se existir**; caso contrario, nao altera o atalho, e voce pode associa-lo manualmente pelo painel do desktop.

## O que nao pode ficar dentro da pasta

- **O kernel Linux, o servidor grafico X11, drivers, servicos do desktop e eventuais modulos dinamicos do sistema** nao fazem parte do aplicativo. Ele depende desses componentes para executar e captar teclas/tela.
- **O registro global permanente da tecla Print** e armazenado nas configuracoes do Trinity, fora da pasta, porque um arquivo apenas dentro da pasta nao pode mudar os atalhos globais do desktop.
- **O interpretador Python3, quando escolhido para registrar o atalho automaticamente**, e um recurso do sistema. O executavel C++ de captura nao precisa dele.

Assim, 'pasta unica' aqui significa **todos os arquivos distribuidos do Print RC e as bibliotecas vinculadas ao executavel**, e nao um sistema Linux inteiro dentro da pasta. **Nao prometemos funcionar em todo Linux nem em Wayland.**

## Desinstalar

Na pasta instalada, execute `bash desinstalar.sh`. Confirme digitando `REMOVER` quando o caminho exibido estiver correto. O processo tenta restaurar os atalhos alterados e exclui apenas a pasta de instalacao confirmada. Nao altera pacotes instalados pelo sistema.

## Compilacao opcional para desenvolvedores

Quem quiser alterar o codigo-fonte podera usar:

```bash
make portable
make test
python3 -m unittest discover -s tests -v
bash tests/test_instalacao.sh
```

Esses comandos de **desenvolvimento**, diferente do ZIP pronto, exigem compilador, cabeçalhos X11/libpng e ferramentas de compilacao.

### Limitacoes

- Requer Linux **x86_64** com sessao **X11**; Wayland nao e suportado nesta versao.
- Jogos que interceptam teclas, tela cheia exclusiva, drivers especiais e conteudo protegido podem impedir captura ou acesso ao Print.
- Binario estatico foi testado no ambiente automatizado, mas nao foi testado visualmente no notebook Q4OS do usuario.
- Consumo de RAM durante o print depende da resolucao; sem o processo em execucao, ele consome 0 MB.
- As bibliotecas basicas do proprio sistema X11 e eventuais mecanismos dinamicos do glibc continuam sendo dependencias ambientais, mesmo com arquivo ELF estatico.

## Licenca

GNU GPL v3 ou posterior. Consulte `LICENSE`.
