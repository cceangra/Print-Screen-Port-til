# Print RC v0.4.3 — Linux X11 / pasta unica

Aplicativo de captura de uma regiao da tela em **C++**, com tela escurecida, selecao por mouse e copia da imagem como PNG para Ctrl+V. Criado principalmente para **Q4OS / Trinity / X11**, em computadores **x86_64**.

## Correcoes de seguranca da v0.4.3

- **Teclado ocupado:** caso outro aplicativo ja esteja capturando o teclado no X11, a janela de selecao fecha e o mouse e imediatamente liberado. O Print RC nao salva imagem nem fica aberto sem a tecla Esc. O fluxo e testado em servidor X11 virtual.
- **Atalho Trinity:** verifica novamente `khotkeysrc` antes de escrever, inclusive depois das confirmacoes. Se outro processo alterar o arquivo, **cancela sem sobrescrever configuracoes de terceiros**. Reconhece `TDEHOME`, se definido. Na desinstalacao remove SOMENTE as secoes do proprio Print RC e tenta restaurar a tecla anterior.
- **Arquivos pessoais:** o instalador novo registra em `config/arquivos-instalados.sha256` os checksums SHA-256 de seus proprios arquivos, sem incluir fotos ou arquivos desconhecidos. A desinstalacao remove somente arquivos presentes no inventario que continuem **identicos**. Se um codigo, README ou configuracao for editado/substituido pelo usuario, e preservado.
- **Capturas protegidas:** nenhum `*.png`, `*.jpg` ou outro print pessoal e apagado, mesmo dentro de `Print-RC/capturas/`. Diretorios nao vazios continuam no disco.
- **Instalacoes antigas:** se a pasta antiga **nao** tem inventario SHA-256, a desinstalacao pode restaurar a tecla registrada, mas se recusa a apagar os arquivos locais sem prova da sua origem. Isso evita excluir arquivos pessoais de instalacoes anteriores.

O inventario e apenas um pequeno arquivo de texto dentro da pasta do Print RC, nao um servico adicional. O app nao precisa de compilador ou apt para funcionar.

## Novidades da v0.4.3

- **Capturas simultaneas:** o Print RC usa uma selecao propria do X11 para nao permitir dois overlays de captura ao mesmo tempo. Esse bloqueio NAO cria arquivos, processos residentes nem servicos.
- **Salvar + colar independentes:** se um diretorio ficar sem permissao ou o disco nao puder salvar o PNG, o Print RC ainda disponibiliza o print em Ctrl+V quando essa preferencia esta ativada. Uma mensagem de erro informa que o arquivo nao foi gravado.
- **Clipboard grande:** testes reais com xclip no servidor grafico X11 virtual, incluindo transferencias incrementais INCR de imagens maiores que 64 KiB, sem adicionar xclip como dependencia no notebook.
- **Reinstalacao preservando prints:** o instalador permite escolher uma pasta existente com imagens antigas. Verifica antecipadamente todos os caminhos, nao sobrescreve arquivos pessoais e pede confirmacao antes de incorporar os arquivos novos. Arquivos existentes em conflito impedem a reinstalacao.
- **Desinstalacao com clipboard ativo:** apenas processos cujo executavel corresponde exatamente ao Print RC daquela pasta sao encerrados com SIGTERM, apos confirmacao. Isso encerra o clipboard que o aplicativo estivesse servindo; prints JA SALVOS nao sao apagados.
- **Configurar:** pressionar Enter mantem a pasta de imagens e a preferencia de Ctrl+V anteriores; a nova instalacao ainda tem `capturas/` como padrao.
- **Desempenho e visual:** em formatos X11 RGB888 de 32 bits, a conversao para PNG usa acesso direto a pixels, o desenho evita repintar tracos fora da area alterada e a barra fica menor em telas estreitas.

**Nenhum pacote adicional e instalado no Q4OS.** Os testes usam ferramentas adicionais apenas no GitHub Actions, no ambiente de construcao.

## BAIXAR: pacote pronto, sem `apt install`

**Baixe a versao empacotada:**

**[Print-RC-Linux-x86_64.zip — Downloads / Releases](https://github.com/cceangra/Print-Screen-Port-til/releases/latest/download/Print-RC-Linux-x86_64.zip)**

O ZIP contem **um unico diretorio `Print-RC/`**, com:
- `bin/print-rc`: executavel C++ **compilado estaticamente**; `ldd` nao lista bibliotecas compartilhadas para esse executavel;
- `instalar.sh`, `iniciar.sh`, `configurar.sh`, `desinstalar.sh`;
- `src/main.cpp`, `src/settings.hpp`, `Makefile`, `scripts/atalho.py` e documentacao;
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

O instalador NAO cria segunda copia, nao instala pacotes e nunca sobrescreve arquivos existentes. Pode mesclar de forma conservadora a nova instalacao em uma pasta que ainda contenha prints preservados, com confirmacao. Se houver conflito com arquivo pessoal, cancela sem sobrescrever. Pergunta separadamente se deseja registrar o atalho Print do Trinity, com confirmacao e backup.

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

## Escolher pasta das imagens e copiar para Ctrl+V (terminal)

Na instalacao, o Print RC faz **duas perguntas obrigatorias** pelo terminal:

1. Digite o **caminho completo e absoluto** da pasta para receber as imagens PNG, por exemplo `/home/rc/Imagens/Print-RC`. Pressione Enter para escolher a pasta `capturas/` **dentro do proprio aplicativo**.
2. Escolha **SIM ou NAO** para copiar cada imagem para a **area de transferencia**, permitindo colar com **Ctrl+V**. Ctrl+C nao e necessario: a captura e copiada automaticamente se essa opcao estiver ligada.

Depois, o instalador **mostra todas as escolhas e pede confirmacao** antes de salvar a configuracao. As preferencias ficam em `Print-RC/config/opcoes.conf`. O capturador usa essas opcoes sempre que for iniciado pela tecla Print ou pelo `iniciar.sh`. O C++ salva arquivos PNG com data, hora e nome unico, sem sobrescrever imagens existentes.

**Destino externo:** se voce escolher `/home/rc/Imagens/Print-RC`, os PNGs ficarao **fora da pasta do aplicativo, porque voce escolheu isso**. O instalador informa o caminho exato e exige confirmacao adicional. A desinstalacao **nunca remove essas imagens externas**. Caso o diretorio ainda nao exista, ele somente e criado apos a confirmacao final.

**Destino interno:** se escolher `.../Print-RC/capturas`, as imagens ficam dentro da pasta do aplicativo enquanto ele estiver instalado. **Ao desinstalar, todas as capturas sao preservadas no mesmo local.** O Print RC remove apenas os arquivos conhecidos do programa, nao apaga imagens nem diretorios que contenham qualquer outro arquivo. Se houver prints dentro da pasta do aplicativo, ela permanecera com as imagens.

### Modificar as opcoes depois de instalar

Abra o terminal na pasta instalada e execute:

```bash
bash configurar.sh
```

Para verificar as escolhas registradas, execute:

```bash
bash iniciar.sh --show-config
```

**Efeito na RAM:** com a copia para Ctrl+V desligada, o processo sai logo apos salvar o PNG; com a copia ligada, o processo pode continuar dormindo por ate 30 minutos para atender o clipboard X11.

## Interface compacta Print RC 0.4.1

Ao pressionar **Print** (apos configurar o atalho no Trinity) ou iniciar manualmente, uma **barra curta de 280 px** aparece na parte superior da tela. Ela e desenhada em C++/Xlib e nao instala toolkit grafico pesado.

| Botao | Funcao |
|---|---|
| **AREA** | Arrastar mouse para selecionar uma parte da tela, com fundo escurecido e borda azul |
| **TELA** | **Um clique** e ja salva a captura de tela inteira |
| **LAPIS** | Desenhar tracos azuis com o mouse sobre a tela, ANTES de selecionar |
| **DESF** | Remover o ultimo traco desenhado |
| **X** | Fechar/cancelar sem salvar |

**Exemplo para desenhar e capturar:** aperte Print, clique em **LAPIS**, desenhe com o mouse, clique em **AREA** e arraste para escolher uma regiao; os tracos dentro da selecao sao incluidos no PNG. Como alternativa, clique em **TELA** apos desenhar e grave a tela inteira anotada. **Esc** ou clique direito cancela.

A tela fora da selecao fica escurecida, e a parte escolhida volta ao brilho original. O formato salvo continua PNG, com copia automatica para **Ctrl+V** apenas quando essa opcao foi ativada em configurar.sh.

**Tempo limite:** a interface de selecao fecha sozinha apos 120 segundos sem concluir a captura, e nao deixa overlay agarrando teclado e mouse. Se Ctrl+V estiver ativado, o processo pode permanecer adormecido ate 30 minutos para disponibilizar o PNG no clipboard; sem Ctrl+V, encerra apos salvar.

**Otimizacao:** em tela X11 convencional de 32 bits, escurecimento trabalha diretamente nos bytes da imagem; outras combinacoes usam o codigo generico. Existe teste de UI no Xvfb (tela virtual) para clicar nos botoes TELA e LAPIS/AREA e conferir que o desenho aparece no PNG. Ainda e recomendado testar no Trinity fisico, especialmente jogos fullscreen.

## Usar

Apos a instalacao, pelo caminho escolhido:

```bash
bash /home/rc/Apps/Print-RC/iniciar.sh
```

A tela escurece levemente; pressione e arraste o botao esquerdo do mouse. Ao soltar, um PNG e salvo na pasta que voce escolheu. Se ativou a copia automatica, a imagem tambem fica na area de transferencia X11: cole em um aplicativo compativel com Ctrl+V. **Esc** ou botao direito cancela.

O capturador so inicia quando chamado; apos a selecao, a interface some. Em X11, se a copia estiver ativada, ele pode manter um processo adormecido por **ate 30 minutos** para disponibilizar o PNG no clipboard; depois encerra. Se a copia estiver desligada, o processo encerra apos salvar a imagem. Se um gerenciador externo assumir o clipboard, a imagem podera continuar disponivel.

### Tecla Print Screen

No Trinity, `instalar.sh` oferece registrar a tecla `Print` no atalho global. O instalador examina conflitos conhecidos em `~/.trinity/share/config/khotkeysrc`, apresenta acoes que encontrou e pede autorizacao antes de modificar qualquer registro. Os backups ficam em `Print-RC/backups/` e a desinstalacao tenta restaurar as alteracoes. Pode ser necessario sair e entrar novamente no Trinity.

A configuracao automatica do atalho usa `python3` **do sistema, se existir**; caso contrario, nao altera o atalho, e voce pode associa-lo manualmente pelo painel do desktop.

## O que nao pode ficar dentro da pasta

- **O kernel Linux, o servidor grafico X11, drivers, servicos do desktop e eventuais modulos dinamicos do sistema** nao fazem parte do aplicativo. Ele depende desses componentes para executar e captar teclas/tela.
- **O registro global permanente da tecla Print** e armazenado nas configuracoes do Trinity, fora da pasta, porque um arquivo apenas dentro da pasta nao pode mudar os atalhos globais do desktop.
- **O interpretador Python3, quando escolhido para registrar o atalho automaticamente**, e um recurso do sistema. O executavel C++ de captura nao precisa dele.

Assim, 'pasta unica' aqui significa **todos os arquivos distribuidos do Print RC e as bibliotecas vinculadas ao executavel**, e nao um sistema Linux inteiro dentro da pasta. **Nao prometemos funcionar em todo Linux nem em Wayland.**

## Desinstalar

Na pasta instalada, execute `bash desinstalar.sh`. Digite **DESINSTALAR** para confirmar. A desinstalacao da v0.4.3 **NUNCA exclui imagens** e remove apenas os arquivos originais que tenham hash compativel com o inventario criado na instalacao. O atalho Print e desfeito quando foi configurado pelo Print RC. **Nao existe comando `rm -rf` para apagar a pasta inteira nem qualquer opcao para apagar prints.** Se houver fotos, capturas ou arquivos desconhecidos dentro da pasta do aplicativo, esses arquivos e suas pastas ficam no mesmo local, preservados. Se as imagens estiverem em uma pasta externa, essa pasta permanece completamente intacta. O atalho que voce registrou manualmente no desktop precisa ser removido manualmente, pois o programa so pode restaurar automaticamente atalhos que ele mesmo gerenciou. Se falhar ao restaurar o atalho gerenciado, a desinstalacao interrompe e preserva arquivos e backups. Nao altera pacotes instalados pelo Linux.

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
