# Print RC — Captura de tela leve (v0.1.0 experimental)

Capturador de região em **C++ / Xlib / libpng** para **Linux X11**, com prioridade ao **Q4OS Debian 13 e Trinity Desktop**. Inspirado na interação do `Win + Shift + S` do Windows: tela escurecida, cursor de mira, arrastar um retângulo, soltar e colar a imagem com `Ctrl + V`.

**Esta é uma primeira versão para teste.** Não promete funcionamento em Wayland, consoles Linux, aplicativos com proteção de captura, jogos com captura exclusiva de entrada ou em todas as resoluções e múltiplos monitores.

## Uma única pasta: instalação sem cópias ou resíduos do projeto fora dela

**A pasta extraída é o próprio aplicativo.** O instalador **não duplica** a pasta: você pode manter no lugar ou indicar outro destino, quando ele moverá a pasta inteira, com o código, instalador, executável e configurações. Ele não cria pasta extra de instalação e não executa `apt`. Se o destino já existir, ele se recusa a sobrescrevê-lo.

**Método fácil:** no GitHub clique em **Code > Download ZIP**, extraia o ZIP e abra um terminal *na pasta extraída*. Execute:

```bash
bash instalar.sh
```

Quando perguntar **Nova pasta de destino**, pressione Enter para ficar naquela única pasta; ou digite `/home/rc/Apps/Print-RC` para **mover essa mesma pasta inteira**. Quando perguntar sobre atalho, `n` mantém o sistema inalterado; `s` tenta registrar o Print no Trinity, com confirmações e backup.

**Observação:** o ZIP que o navegador já baixou fora da pasta não pode ser removido automaticamente sem sua permissão. Mova-o para dentro da pasta final ou exclua-o depois de instalar. Se você já possui uma instalação antiga no destino escolhido, não sobrescreva: use outra pasta ou desinstale a antiga primeiro.

### Baixar e instalar sem deixar nem o ZIP em Downloads

Este exemplo coloca o download, a extração e a instalação **dentro de uma única pasta** desde o começo. Só execute se `$HOME/Apps/Print-RC` **ainda não existir**:

```bash
bash <<'BASH'
set -euo pipefail
DEST="$HOME/Apps/Print-RC"
if [[ -e "$DEST" ]]; then echo "Destino ja existe: $DEST"; exit 1; fi
for p in wget unzip; do command -v "$p" >/dev/null || { echo "Falta o comando: $p"; exit 1; }; done
mkdir -p -- "$DEST"
wget -O "$DEST/origem.zip" "https://github.com/cceangra/Print-Screen-Port-til/archive/refs/heads/main.zip"
unzip -q "$DEST/origem.zip" -d "$DEST"
(
  shopt -s dotglob nullglob
  mv -- "$DEST/Print-Screen-Port-til-main/"* "$DEST/"
)
rmdir -- "$DEST/Print-Screen-Port-til-main"
rm -- "$DEST/origem.zip"
cd -- "$DEST"
bash instalar.sh
BASH
```

O instalador oferecerá manter essa mesma pasta; pressione Enter. A fonte, compilação, backups e programa permanecerão nela.

### Dependências de compilação (Q4OS / Debian 13)

O instalador verifica as dependências e **não instala pacotes automaticamente**. Se faltar algum, ele mostra o que instalar. Somente **se faltar algum pacote**, e com sua autorização, você poderá instalá-lo manualmente:

```bash
sudo apt install build-essential pkg-config python3 libx11-dev libpng-dev
```

Esses pacotes, quando necessários, são gerenciados pelo Linux e ficam fora da pasta do Print RC. **Não é possível prometer portabilidade absoluta sem dependências do sistema.** Uma vez compilado, para executar bastam as bibliotecas compartilhadas do X11 e libpng disponíveis no sistema. Não é um binário universal Linux. Não use os executáveis compilados nesta máquina em outra arquitetura.

## Usar

Teste antes de configurar a tecla:

```bash
bash "$HOME/Apps/Print-RC/iniciar.sh"
```

Se escolheu outra pasta, substitua o caminho. Arraste com o **botão esquerdo**. Solte para copiar imagem no formato PNG. Cole com **Ctrl+V** num aplicativo compatível com imagem. Clique com botão direito ou pressione **Esc** para cancelar. Não salva imagens automaticamente. O print não fica gravado em disco pelo app.

O processo `print-rc` é iniciado **somente sob demanda**. Depois da captura, a interface fecha, mas o processo continua dormindo para manter a imagem na área de transferência X11; ele encerra depois de **30 minutos desde o início** ou quando outro aplicativo assume a área de transferência. Não usa CPU em loop contínuo. Um gerenciador de área de transferência externo pode fazer a imagem continuar disponível depois.

### Atalho global no Trinity

Durante a instalação você pode aceitar a configuração de `Print`. Para não apagar atalhos antigos, o instalador:

- Examina `~/.trinity/share/config/khotkeysrc` e **lista os atalhos `Key=Print` conhecidos** com nome e comando, se estiverem declarados naquele arquivo.
- Se necessário, pede autorização para **desativar somente o acionamento da tecla** nos atalhos conflitantes, sem desinstalar o programa antigo.
- Pede outra confirmação antes de escrever no arquivo.
- Faz backup integral dentro de `Print-RC/backups/` e registra quais trechos alterou.
- Na desinstalação, remove o grupo do Print RC e tenta restaurar os atalhos modificados, **sem sobrescrever edições posteriores do usuário**. Em caso de conflito ambíguo, interrompe a remoção para evitar danos.

**Encerre a sessão e entre novamente** no Trinity após registrar/desregistrar o atalho: a mudança no arquivo pode não ser recarregada imediatamente. A configuração em execução ou de outros componentes (por exemplo teclas reservadas por jogos, aplicativos que capturam o teclado, atalhos fora de `khotkeysrc`) **não pode ser identificada com 100% de confiabilidade**. Se o atalho não funcionar, abra **Centro de Controle Trinity > Regional e Acessibilidade > Ações de Entrada / Atalhos Globais** e vincule manualmente `Print` ao caminho de `iniciar.sh`.

Se a identificação automática do ambiente não for Trinity, o instalador **não tenta alterar atalhos** de outro desktop. Use a tela de atalhos de seu ambiente.

## Organização

```text
Print-RC/
├── instalar.sh
├── iniciar.sh
├── desinstalar.sh
├── Makefile
├── src/main.cpp
├── scripts/atalho.py
├── tests/test_atalho.py
├── bin/print-rc            # gerado localmente
├── config/                 # estado da integração
├── backups/                # backup da integração
├── capturas/               # reservado, não utilizado nesta versão
└── README.md
```

**Fora da pasta, somente quando necessário**: a associação do atalho em `~/.trinity/share/config/khotkeysrc`, pacotes de compilação se precisarem ser instalados, bibliotecas compartilhadas existentes e integrações do sistema. A compilação e a captura não criam serviços persistentes de inicialização automática, nem escrevem arquivos de imagem fora da pasta.

## Desinstalar

Execute da pasta de instalação (não da cópia ZIP original):

```bash
bash "$HOME/Apps/Print-RC/desinstalar.sh"
```

Leia o caminho exibido. Digite `REMOVER` apenas se concordar em excluir a pasta inteira, inclusive as capturas e os backups locais. O script **não remove dependências do sistema**. Se os atalhos tiverem sido modificados de maneira imprevisível, a desinstalação é interrompida sem destruir o backup.

## Diagnóstico e compilação

```bash
make
make test
python3 -m unittest discover -s tests -v
bash iniciar.sh --version
```

Consumo real de memória (após iniciar):

```bash
ps -C print-rc -o pid,rss,%cpu,etime,cmd
```

O `RSS` é apresentado em KiB. Não há promessa de consumo fixo: a RAM depende da resolução, da área selecionada e do tamanho do PNG na área de transferência.

## Limitações conhecidas

- X11 apenas. Wayland não permite capturas e atalhos globais pela mesma interface.
- Jogos em fullscreen exclusivo, conteúdo protegido ou drivers gráficos especiais podem bloquear a captura ou a tecla.
- A tela é fotografada antes do overlay, mas aplicações com aceleração podem retornar quadro preto ou antigo.
- O Print RC não é serviço residente: se o atalho nativo não estiver disponível, registre um atalho do próprio desktop.
- Seleção em desktop virtual muito grande consome mais memória; esta v0.1.0 não implementa ferramentas extras de anotação, lupa ou menus de edição.
- Algumas aplicações não aceitam PNG da área de transferência; teste num editor de imagens.
- O arquivo de configuração de atalhos é interno ao Trinity e pode variar de versão para versão. Um arquivo não reconhecido pode exigir ajuste manual.

## Licença

GNU GPL v3.0 ou posterior (consulte `LICENSE`).
