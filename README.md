# Print RC v0.5.6 — Linux X11 / pasta unica

Aplicativo de captura de uma regiao da tela em **C++**, com tela escurecida, selecao por mouse e copia da imagem como PNG para Ctrl+V. Criado principalmente para **Q4OS / Trinity / X11**, em computadores **x86_64**.

## Tecla de captura escolhida pelo usuario — v0.5.6

O Print RC **nao limita mais a escolha a Print/Insert/Sys_Req**. No X11, durante os 60 segundos de configuracao, pressione uma tecla individual com keysym reconhecido (por exemplo, `F9`, `F12`, `a`, `3`, `Return`, `Insert`, `Print` ou teclas multimidia `XF86...`). O detector encerra a escuta imediatamente e passa a tecla realmente escolhida ao integrador Trinity ou Xfce. A atribuicao requer uma unica confirmacao. **Esc cancela** e modificadores sozinhos (`Shift`, `Ctrl`, `Alt`, `Super`) nao representam atalhos individuais validos; combinacoes como `Ctrl+F9` nao sao selecionadas automaticamente nesta versao.

**Onde ficam as configuracoes?** Codigo, backup, estado de restauracao e `configurar-tecla.sh` ficam **dentro da pasta do Print RC**. Nao e criado um script ou arquivo externo diferente por tecla. O desktop precisa conhecer o atalho global: o Xfce usa seu canal de configuracao `xfce4-keyboard-shortcuts`, por exemplo `/commands/custom/F12` ou `/commands/custom/a`, e o Trinity usa seu **arquivo ja existente** `~/.trinity/share/config/khotkeysrc`. Se a configuracao do desktop ainda nao existia, o proprio desktop pode criar seu armazenamento padrao. A alteracao externa e a associacao necessaria para a tecla funcionar mesmo quando o Print RC estiver fechado. O desinstalador pode restaurar a associacao anterior com o registro salvo na pasta do app.

**Atenção:** definir `a`, `Return` ou `space` como atalho global pode impedir sua digitacao ou uso normal em outros programas. A atribuicao deve ser feita somente com sua confirmacao e pode ser desfeita no configurador/desinstalador. Nao alteramos o mapa de teclado global (`xmodmap`) nem instalamos servicos residentes. A efetiva ativacao do atalho ainda e testada separadamente; a operacao em outras distribuicoes/Wayland permanece limitada pelo desktop.

## Correcao da tecla fisica Print identificada como Insert — v0.5.5

**Defeito relatado com imagem de um Xfce/X11 real:** a pessoa pressionava a tecla de captura do teclado, mas o X11 entregava o keysym **Insert**. O Print RC anterior aceitava exclusivamente `Print` ou `Sys_Req`, exibia repetidamente "tecla lida: Insert", ignorava o evento e esgotava os 60 segundos. A falha nao era um atalho ocupado nem falta de permissao; ocorria antes da etapa de registro.

**Nova sequencia:**
- O detector X11 reconhece **Print**, **Sys_Req** ou **Insert**. Se a pessoa pressionar a tecla fisica mapeada como Insert, ele retorna `PRINT_RC_KEY=Insert` e **encerra a escuta na primeira pressao**, sem aguardar o timeout.
- O instalador recebe exatamente essa resposta e, no **Xfce**, registra `/commands/custom/Insert` via `xfconf-query` com o launcher do Print RC; nao registra `Print` por engano. Se havia um comando personalizado anterior vinculado a Insert, ele e guardado para restauracao durante a desinstalacao. Qualquer associacao da tecla Print separada e mantida intacta.
- No **Trinity**, o integrador aceita `Key=Insert` e so libera conflitos que usem essa tecla.
- A pessoa confirma **SIM uma vez**, e depois testa o acionamento real. O teste de ativacao nao deve ser confundido com simples identificacao ou escrita de configuracao.
- Nao e feito `xmodmap`, `setxkbmap` ou remapeamento global na maquina do usuario: so o atalho do desktop e modificado com confirmacao. **Se escolher Insert, a tecla podera deixar de funcionar como Insert normal** em outros aplicativos enquanto for um atalho global. Essa e a escolha de configuracao feita pelo usuario.
- Os testes em Xvfb reproduzem uma tecla identificada como Insert, verificam a saida imediata e tambem garantem que outra tecla como F12 continue sem ser registrada. Testes do Xfce confirmam a propriedade `/commands/custom/Insert` e a restauracao do atalho anterior.

**Diagnostico correto:** o fato de o instalador mostrar "Insert" significa que o teclado esta enviando Insert. Nao significa que a tecla esta bloqueada por outro aplicativo. Se a associacao for gravada, mas nao ativada pelo Xfce, a prova real mostra a falha separadamente. O nome da tecla fisica no gabinete nao deve prevalecer sobre o keysym X11 realmente recebido.

## Comprovar que Print REALMENTE executa o programa — v0.5.3

**Problema identificado:** a v0.5.1 podia ler a tecla Print e registrar `Key=Print` no arquivo do Trinity sem comprovar que o `khotkeysd` ativara o novo atalho. A mensagem de releitura por DCOP apenas confirmava que um pedido foi enviado. Isso explica por que a instalacao podia parecer correta enquanto Print nao abria o aplicativo. O proprio suporte Q4OS relatou a necessidade ocasional de reiniciar o servico de atalhos ou encerrar e reabrir a sessao grafica depois de registrar atalhos no Trinity.

A partir desta versao o instalador distingue claramente **TECLA IDENTIFICADA**, **REGISTRO_GRAVADO** e **ATIVACAO_CONFIRMADA** (somente apos prova do inicializador).

1. O usuario pressiona Print Screen para identificar a tecla X11 (60 segundos e opcao de repetir).
2. Confirma **SIM uma unica vez** para registrar a tecla, substituindo conflitos reconhecidos no gerenciador.
3. **Prova de ativacao:** se a instalacao estiver em terminal interativo X11, o instalador pede para pressionar Print **novamente**, apenas para verificar o acionamento real do `iniciar.sh`. A segunda pressao e uma verificacao, **nao e outra pergunta nem alteracao do atalho**. A captura de tela nao abre nesse teste. Os marcadores temporarios ficam dentro do `config/`, expiram e sao removidos ao finalizar.
4. Se o iniciador for executado durante o teste, aparece **ATIVACAO_CONFIRMADA**. Se nao, aparece **ATIVACAO_PENDENTE** com a possibilidade de reiniciar o servico de atalhos pelo gerenciador do Trinity ou fazer novo login. O instalador nao encerra processos do ambiente nem afirma falsamente que a tecla esta funcionando.
5. Apos confirmar, pressionar Print normalmente inicia o capturador. O teste prova o **acionamento do script**, nao a abertura da GUI (coberta por testes independentes em X11 virtual).

Para repetir a prova sem reinstalar, dentro da pasta do aplicativo execute `bash configurar-tecla.sh --provar`, ou use a opcao **4) Testar se Print realmente abre o aplicativo** no menu. O script interno correspondente e `scripts/provar-atalho.sh`.

**Limites:** a prova precisa de `DISPLAY` e de interacao fisica com o teclado. GitHub Actions testa o mecanismo de prova com um inicializador simulado, mas nao substitui uma prova real no Q4OS. Se outra aplicacao retiver a tecla, o Trinity nao recarregar o atalho ou o lancador estiver indisponivel, a ativacao e reportada como pendente. Nenhum `sudo`, `killall` ou reinicio forcado e executado.

## Configurador de tecla Print dentro da pasta — v0.5.2

A pasta `Print-RC/` inclui o novo `configurar-tecla.sh`. Execute **`bash configurar-tecla.sh`** dentro do aplicativo, sem `sudo`. Nao e necessario reinstalar o programa para diagnosticar ou refazer o atalho Print.

O menu mostra:

1. **Verificar Print:** le `khotkeysrc` no Trinity ou `xfconf-query` no Xfce, exibe qual comando esta registrado, se o Print RC e o dono gerenciado e exibe possiveis conflitos conhecidos. Realiza uma breve sonda de X11 por `--verificar-tecla` para verificar reservas da combinacao Print/Sys_Req sem manter a tecla capturada. A sonda relata `PRINT_RC_GRAB=ocupada`, `sem_bloqueio_x11` ou `indeterminado`. **Sem bloqueio observado nao garante que Print esteja livre para todos os programas.** O protocolo X11 permite detectar `BadAccess`, mas nao identificar o cliente que ocupa a tecla, nem liberar um grab criado por ele.
2. **Configurar ou reassociar:** pede para pressionar **Print Screen**, espera ate 60 segundos e pergunta se deseja tentar novamente apenas quando o tempo acaba. Confirmar `SIM` no cadastro permite que o Print RC libere e substitua os atalhos conhecidos daquele ambiente. No Trinity a v0.5.2 pode trocar uma associacao propria ja instalada de `Print` para `Sys_Req` ou vice-versa, atualizando seu estado sem reinstalar. No Xfce so `Print` tem suporte automatico.
3. **Liberar atribuicao:** remove somente o atalho previamente registrado pelo Print RC e, onde e seguro, restaura o atalho anterior salvo. Nao mata programas, nao desfaz grabs X11 de outros processos, nao remove imagens nem altera teclas diferentes.
0. **Sair** sem modificacoes.

Os comandos opcionais `bash configurar-tecla.sh --status`, `--configurar` e `--liberar` acessam as mesmas funcoes. `--status` e somente leitura. Todos os arquivos auxiliares sao mantidos dentro da pasta do aplicativo, exceto a propria configuracao de atalhos que pertence ao desktop do usuario e precisa ser editada com confirmacao.

**Limites reais:** a atribuicao de tecla nao e universal entre todos os desktops Linux. Para GNOME/Plasma e outros ambientes X11 ainda ha instrucao de cadastro manual; Wayland exigira outro motor de captura. O app **nao pode remover um atalho detido por qualquer aplicativo arbitrario**, porque uma conexao X11 nao pode desfazer `XGrabKey` de outra conexao. O app explica quando detecta uma reserva externa e nao solicita sudo para tentar burlar o gerenciador de janelas.

## Identificar tecla Print: 60 segundos e repetir se precisar — v0.5.1

No instalador, o detector X11 abre um periodo de **60 segundos** (antes eram 15) para que a pessoa pressione **PRINT SCREEN**. A tela mostra a instrucao e informa claramente o prazo. Apos identificar Print ou Sys_Req, o instalador segue para **uma unica confirmacao SIM** de atribuicao da tecla, preservando a politica da v0.5.0 para conflitos conhecidos no Trinity/Xfce.

Se nenhum Print for pressionado ate o prazo, o detector libera o teclado e o instalador pergunta:

```text
[Print RC] O prazo de 60 segundos terminou.
[Print RC] Tentar novamente? [s/N]:
```

Responder `s` ou `sim` inicia outra leitura independente de ate **60 segundos**; pode repetir quantas vezes quiser. `n`, **Enter** ou fechar a entrada encerra a escolha sem registrar nenhum atalho, mas preserva a instalacao do aplicativo. **Esc cancela imediatamente**, sem perguntar por nova tentativa. Se o teclado X11 estiver indisponivel, o programa informa erro e **nao repete silenciosamente** nem pede senha.

O usuario nao precisa de `sudo`. Um timeout do teclado nao altera arquivos de atalhos, nao cria registrador permanente e nao interfere em outras teclas. O C++ mantem um codigo de retorno especifico para timeout (4), cancelamento (5) e falha de teclado (2/3). Testes automatizados cobrem os dois tempos: binario real com mensagem **60 segundos** e compilacao **somente de teste** com um segundo para simular o timeout sem tornar a CI demorada. Testes integrados cobrem `SIM` -> nova tentativa bem-sucedida, `NAO` -> nenhuma associacao e `Esc` -> cancelamento imediato. A instalacao real no Trinity ainda deve ser validada pressionando Print apos configurar.

## Atalho Print sem perguntas repetidas — v0.5.0

O usuario **pressiona fisicamente Print Screen** quando o instalador solicita e responde **SIM uma unica vez** para escolher a tecla que deve abrir o Print RC. O instalador nao exige resposta adicional para sobrescrever uma associacao conflitante que ele conseguir localizar no gerenciador de atalhos suportado. Qualquer uso anterior do atalho Print fica em segundo plano depois dessa confirmacao. Nao e necessario `sudo` nem instalar servico propio que registre todas as teclas digitadas.

- **Trinity/X11:** usa a acao valida `COMMAND_URL_SHORTCUT_ACTION_DATA`, substitui o atalho Print/Sys_Req identificado nos grupos `khotkeysrc` e solicita `khotkeysd.reread_configuration` por DCOP. O script **nao desinstala nem apaga os programas anteriores**; guarda a atribuicao antiga para restaurar durante a desinstalacao.
- **Xfce/X11:** substitui `/commands/custom/Print` apos um unico SIM. Se existia comando personalizado, o estado anterior e guardado para desinstalacao. A associacao padrao em `/commands/default/Print` nao e apagada; o Xfce controla a precedencia.
- **Outros desktops X11:** o programa informa o comando e onde cadastrar manualmente a tecla. Nao altera arquivos de outros ambientes sem implementacao validada.
- **Wayland:** nao e compativel com o atual capturador X11; nem `sudo` pode tornar universal o registro de atalhos, que e controlado pelo compositor.
- **Protecao:** se a tecla nao for reconhecida, nada e cadastrado. Se houver confirmacao, mas o gerenciador falhar ao registrar, o instalador **termina com erro** em vez de informar sucesso. O status de cadastro e mostrado separadamente do status do executavel.

**Limite real:** o sistema pode ter outro capturador global fora do gerenciador selecionado (por exemplo, uma tecla interceptada pelo compositor ou pelo gerenciador de janelas). O Print RC nao pode garantir prioridade sobre esses atalhos somente escrevendo `khotkeysrc`; nesse caso o problema deve ser diagnosticado no desktop. Nunca usar root como alternativa silenciosa para interceptar todas as teclas.

## Correcao confirmada do formato do atalho Trinity — v0.4.9

O diagnóstico de um Q4OS/TDE real mostrou que o Print RC registrava a tecla mas **o Trinity não executava a ação**. No `khotkeysrc` o Print RC estava com `Type=SIMPLE_ACTION_DATA` e o atalho de microfone funcional tinha `Type=COMMAND_URL_SHORTCUT_ACTION_DATA`. Os fontes do KHotKeys/KDE 3, base da implementação Trinity, confirmam que o tipo específico para acionar comando por tecla é `COMMAND_URL_SHORTCUT_ACTION_DATA`. A v0.4.9 corrige **a geração do grupo inteiro**, não somente a identificação física da tecla.

O integrador agora:
- Registra `Type=COMMAND_URL_SHORTCUT_ACTION_DATA`, `Actions0 Type=COMMAND_URL` e `Triggers0 Type=SHORTCUT` com `Print` ou `Sys_Req` detectado no X11.
- **Repara uma instalação antiga (v0.4.8)** que tenha registro interno válido e grupo exclusivo `Print RC`: valida grupo, comando, tecla e tipos; pede confirmação; altera somente o tipo incorreto e, se necessário, o comando do próprio Print RC. Não sobrescreve atalhos do usuário, `khotkeysrc` modificado simultaneamente ou backup `backups/khotkeysrc.antes`.
- Depois da escrita, solicita a releitura via DCOP ao `khotkeysd`. Isso apenas comprova envio da solicitação; **pressionar Print e observar a barra de captura é o teste definitivo**.
- Testes automatizados simulam os grupos reais `Examples`, `Konqueror Gestures`, `Mutar Microfone` e `Print RC`, verificando formato, reparo, cancelamento, conservação de atalhos de terceiros, desinstalação e captura X11 virtual.

**Como reparar mantendo a mesma instalação:** atualize SOMENTE o script `scripts/atalho.py` para o da v0.4.9 (não sobrescreva a pasta do aplicativo inteira) e execute `python3 -B scripts/atalho.py repair --base "$PWD" --launcher "$PWD/iniciar.sh"` dentro da pasta do Print RC. O script pede confirmação e só escreve no grupo Print RC. A atualização manual de arquivos dentro de uma instalação antiga altera seu hash SHA-256; por isso o desinstalador pode preservar esse script modificado depois. Se preferir uma desinstalação totalmente limpa, **desinstale a v0.4.8 com seu próprio `desinstalar.sh` e instale o ZIP completo da v0.4.9 em pasta nova**. Capturas externas e ZIP anterior ficam intactos.

### Compatibilidade entre Linux e desktops

| Sessão / desktop | Cadastro da tecla Print | Captura Print RC |
| --- | --- | --- |
| Q4OS Trinity / outros Trinity com X11 | Automático, formato corrigido, confirmação e reparo | C++/Xlib |
| Xfce com X11 e xfconf-query | Automático opcional, restaura atalho preexistente quando seguro | C++/Xlib |
| GNOME, KDE Plasma, Cinnamon, MATE, LXQt, LXDE/Openbox etc. no X11 | Manual com comando mostrado no instalador | C++/Xlib |
| Qualquer desktop em Wayland | Ainda não suportado por este capturador | Necessita implementação de portal/compositor |
| Processador não x86_64 | ZIP pré-compilado não atende | Compilação da fonte para a arquitetura, ainda não validada |

No GNOME, a tecla Print costuma estar atribuída à ferramenta de captura do próprio sistema: libere-a em **Configurações → Teclado → Capturas de tela** antes de adicionar um atalho personalizado. No Plasma 6, use **Configurações do sistema → Atalhos → Adicionar novo → Comando ou Script**. Não editamos os bancos de atalhos desses desktops sem integração testada, pois isso poderia sobrescrever atalhos pessoais. Para Wayland há a API XDG Desktop Portal Screenshot, porém ela não fornece automaticamente as mesmas ferramentas interativas de seleção e desenho do nosso programa X11; seria uma versão separada, não uma opção que se ativa somente no instalador.

## Identificacao da tecla Print FISICA — v0.4.8

**Historico de correcao:** a v0.4.7 registrava `Key=Print` diretamente, sem pedir que a pessoa pressionasse a tecla. O instalador agora **pergunta se deseja cadastrar o atalho**, depois pede explicitamente **"Pressione PRINT SCREEN agora"**, usa o proprio executavel `bin/print-rc --detectar-print` para identificar um unico evento X11 e mostra o resultado. Sem reconhecer `Print` ou `Sys_Req`, nao registra o atalho automaticamente: nao confunde sucesso ao chamar `dcop` com tecla fisica detectada.

O detector faz `XGrabKeyboard` temporario, dura no maximo **60 segundos** (desde a v0.5.1), pode ser cancelado com **Esc** e libera a captura do teclado em todas as saidas normais. Em encerramento abrupto, o servidor X11 libera o grab ao encerrar a conexao. Nao registra historico de teclas, nao instala pacotes, nao cria servicos residentes e nao mexe no atalho ate que o usuario o confirme nas perguntas posteriores. Teclas diferentes sao apenas mostradas na tela e nao sao aceitas como Print.

No Trinity o valor `Print` ou `Sys_Req` realmente identificado e enviado ao `khotkeysrc`, e o servico `khotkeysd` recebe pedido de releitura. No Xfce, por seguranca, `Sys_Req` exige cadastro manual porque a integracao automatica desta versao usa a propriedade `/commands/custom/Print`. Mesmo com a deteccao fisica correta, somente **um teste real pressionando Print depois da instalacao** confirma que o ambiente executa o atalho. Se outro programa estiver bloqueando a captura, o detector falhar ou o usuario pressionar Esc, a instalacao do programa segue, mas o atalho **nao sera registrado automaticamente**.

Teste isolado no X11 virtual com `xdotool`: pressiona Print, verifica resposta `PRINT_RC_KEY=Print`; pressiona F12 e verifica que nao e aceita; pressiona Esc e verifica cancelamento e liberacao do teclado.

## Compatibilidade da tecla Print — v0.4.7

Esta versao **detecta o ambiente grafico na instalacao** e, na v0.4.8, exige pressionar fisicamente a tecla Print para seu cadastro automatico. Nenhum daemon, observador de teclado ou pacote adicional e instalado pelo Print RC.

- **Trinity/X11:** continua usando o gerenciador `khotkeysd`, detectando conflitos conhecidos e solicitando a releitura dos atalhos via DCOP.
- **Xfce/X11:** nova integracao por `xfconf-query` (se ja estiver disponivel no sistema) para a propriedade `/commands/custom/Print`. Antes de substituir um comando preexistente, o instalador mostra o valor e pede **confirmacoes explicitas**. O comando anterior e registrado dentro da pasta do Print RC e restaurado na desinstalacao **somente se ainda estiver sob controle do aplicativo**. O atalho padrao do Xfce e mantido intacto. Caso o usuario altere a tecla depois, a desinstalacao preserva a configuracao de terceiros e interrompe a remocao para evitar perda de dados.
- **GNOME, KDE Plasma, Cinnamon, MATE, LXQt ou outros desktops X11:** o instalador mostra instrucoes de configuracao manual e o comando exato `/bin/bash 'caminho/do/iniciar.sh'`. **Nao escreve nas configuracoes externas desses desktops sem integracao validada.** Atalhos criados manualmente devem ser desfeitos manualmente.
- **Wayland:** continua **nao suportado**; registrar a tecla Print nao torna o capturador Xlib compatível com Wayland. O aplicativo nao tenta contornar as permissoes do compositor.

No Xfce o teste automatizado simula a instalacao e a desinstalacao completas, com um atalho Print preexistente, pasta contendo espacos e fotos/ZIP externos. O Print RC nunca instala `xfconf-query`; se nao existir, orienta a associar a tecla manualmente nas preferencias do teclado.

## Auditoria do instalador — v0.4.6

**Problema corrigido: preferencias alteradas depois da instalacao.** A lista de integridade gravava o SHA-256 original de `config/opcoes.conf`; ao trocar a pasta de imagens ou a opcao Ctrl+V, o arquivo deixava de corresponder ao hash e acabava preservado na desinstalacao. Agora o `configurar.sh` atualiza de forma conservadora **somente o hash desse arquivo de preferencias** no inventario, apos salvar as opcoes. Todas as demais verificacoes de seguranca permanecem. Os testes cobrem diversas alteracoes de preferencias seguidas da exclusao da pasta inteira quando vazia.

**Protecao contra links simbolicos:** o instalador e o configurador agora recusam diretorios/arquivos criticos que sejam links simbolicos inesperados (`config`, `capturas`, `.print-rc-installation` e outros), para nao escrever sem querer fora da pasta do aplicativo. Sao feitos testes com arquivos pessoais externos para verificar que nao sao alterados.

**Instalacoes interrompidas:** o marcador `.print-rc-installation` agora e gravado so depois das perguntas sobre o atalho. Se o cadastro falhar ou o usuario interromper a operacao, nao aparece prematuramente o status de instalacao concluida. Instalacoes com marcador mas sem inventario nao sao tratadas como instalacoes novas confiaveis: para preservar dados existentes, o instalador cancela e orienta a escolher uma pasta nova.

**O ZIP permanece intacto** e capturas salvas dentro ou fora da pasta continuam protegidas. Sem `sudo`, sem instalar pacotes, sem daemons extras. Testado automaticamente em ambiente Linux/X11 virtual do GitHub; ainda e importante validar no Trinity do computador real.

## Desinstalacao completa e segura — v0.4.5

O desinstalador agora inclui no inventario de arquivos originais os testes de X11 que tinham ficado para tras e os marcadores de release em `.github/`. Isso corrige precisamente os residuos `.github/release-0.4.2.ready`, `.github/release-0.4.3.ready`, `tests/test_clipboard_x11.sh`, `tests/paint_test_pattern.cpp` e `tests/test_desinstalacao_processo_x11.sh` observados apos desinstalar uma versao anterior.

A instalacao registra o hash SHA-256 de cada arquivo do aplicativo que reconhecer. Ao desinstalar, so remove arquivos com registro valido cujo conteudo **nao tenha sido modificado**. Depois percorre os diretorios conhecidos de dentro para fora e apaga **somente diretorios vazios**, incluindo `.github/`, `tests/` e a pasta principal do app. Nao usa exclusao recursiva (`rm -rf`), nao acompanha links simbolicos nem remove arquivos desconhecidos.

**O ZIP baixado fora da pasta do Print RC continua onde estava; o desinstalador nao precisa nem vai apaga-lo.** Se voce guardar o ZIP *dentro* da pasta instalada, ele sera tratado como arquivo pessoal: permanece intacto e impede que essa pasta suma inteiramente. O mesmo vale para fotos, capturas e quaisquer arquivos pessoais dentro do app. Prints em pasta externa continuam no lugar, e o atalho Trinity so e restaurado quando for gerenciado pelo proprio app.

O inventario de uma instalacao antiga nao pode provar quais arquivos extras preexistentes eram originais, por isso a v0.4.5 nao os exclui sem hash: a limpeza completa e garantida apenas para instalacoes **feitas com o inventario atualizado**, e desde que nenhum arquivo pessoal/modificado continue na pasta. Os testes automatizados verificam uma copia do codigo GitHub com `.github/` e `tests/`, o ZIP preservado e pastas contendo arquivos particulares.

## Correcoes de seguranca da v0.4.4

- **Teclado ocupado:** caso outro aplicativo ja esteja capturando o teclado no X11, a janela de selecao fecha e o mouse e imediatamente liberado. O Print RC nao salva imagem nem fica aberto sem a tecla Esc. O fluxo e testado em servidor X11 virtual.
- **Atalho Trinity:** verifica novamente `khotkeysrc` antes de escrever, inclusive depois das confirmacoes. Se outro processo alterar o arquivo, **cancela sem sobrescrever configuracoes de terceiros**. Reconhece `TDEHOME`, se definido. Na desinstalacao remove SOMENTE as secoes do proprio Print RC e tenta restaurar a tecla anterior.
- **Arquivos pessoais:** o instalador novo registra em `config/arquivos-instalados.sha256` os checksums SHA-256 de seus proprios arquivos, sem incluir fotos ou arquivos desconhecidos. A desinstalacao remove somente arquivos presentes no inventario que continuem **identicos**. Se um codigo, README ou configuracao for editado/substituido pelo usuario, e preservado.
- **Capturas protegidas:** nenhum `*.png`, `*.jpg` ou outro print pessoal e apagado, mesmo dentro de `Print-RC/capturas/`. Diretorios nao vazios continuam no disco.
- **Instalacoes antigas:** se a pasta antiga **nao** tem inventario SHA-256, a desinstalacao pode restaurar a tecla registrada, mas se recusa a apagar os arquivos locais sem prova da sua origem. Isso evita excluir arquivos pessoais de instalacoes anteriores.

O inventario e apenas um pequeno arquivo de texto dentro da pasta do Print RC, nao um servico adicional. O app nao precisa de compilador ou apt para funcionar.

## Novidades da v0.4.4

- **Capturas simultaneas:** o Print RC usa uma selecao propria do X11 para nao permitir dois overlays de captura ao mesmo tempo. Esse bloqueio NAO cria arquivos, processos residentes nem servicos.
- **Salvar + colar independentes:** se um diretorio ficar sem permissao ou o disco nao puder salvar o PNG, o Print RC ainda disponibiliza o print em Ctrl+V quando essa preferencia esta ativada. Uma mensagem de erro informa que o arquivo nao foi gravado.
- **Clipboard grande:** testes reais com xclip no servidor grafico X11 virtual, incluindo transferencias incrementais INCR de imagens maiores que 64 KiB, sem adicionar xclip como dependencia no notebook.
- **Reinstalacao preservando prints:** o instalador permite escolher uma pasta existente com imagens antigas. Verifica antecipadamente todos os caminhos, nao sobrescreve arquivos pessoais e pede confirmacao antes de incorporar os arquivos novos. Arquivos existentes em conflito impedem a reinstalacao.
- **Desinstalacao com clipboard ativo:** apenas processos cujo executavel corresponde exatamente ao Print RC daquela pasta sao encerrados com SIGTERM, apos confirmacao. Isso encerra o clipboard que o aplicativo estivesse servindo; prints JA SALVOS nao sao apagados.
- **Configurar:** pressionar Enter mantem a pasta de imagens e a preferencia de Ctrl+V anteriores; a nova instalacao ainda tem `capturas/` como padrao.
- **Desempenho e visual:** em formatos X11 RGB888 de 32 bits, a conversao para PNG usa acesso direto a pixels, o desenho evita repintar tracos fora da area alterada e a barra fica menor em telas estreitas.

**Nenhum pacote adicional e instalado no Q4OS.** Os testes usam ferramentas adicionais apenas no GitHub Actions, no ambiente de construcao.

## Tecla Print Screen — corrigida na v0.4.4

Na versao anterior, `iniciar.sh` podia ser distribuido sem permissao de execucao e o Trinity tentava executa-lo diretamente. **Isso impedia a tecla Print de funcionar, embora `bash iniciar.sh` funcionasse.** O novo pacote traz o arquivo com bit executavel, o instalador confere/corrige SOMENTE a permissao do arquivo interno e o atalho Trinity usa `/bin/bash 'caminho-com-espacos/iniciar.sh'`. Isso permite caminhos com espacos e funciona mesmo se um descompactador perder a permissao.

Depois de registrar ou reparar a tecla, o instalador solicita ao servico **`khotkeysd`** a releitura da configuracao via DCOP, sem reiniciar ou encerrar processos do desktop. Se DCOP nao estiver disponivel, informa que pode ser necessario encerrar a sessao e entrar novamente. O usuario deve apertar a tecla Print para verificar; a resposta do servico nao comprova sozinha que o atalho realmente acionou o aplicativo.

**Reparo conservador do atalho (v0.4.9):** no diretorio do aplicativo, com o script atualizado, execute `python3 -B scripts/atalho.py repair --base "$PWD" --launcher "$PWD/iniciar.sh"`. Ele compara o registro interno com o arquivo do Trinity, mostra a mudança e pede confirmação antes de corrigir o tipo e/ou o comando do **próprio Print RC**; preserva todos os outros atalhos e o backup original. Para evitar resíduos de arquivos de versões diferentes, prefira desinstalar a versão anterior com o próprio desinstalador antes de instalar o novo ZIP.

Em outros desktops X11, o capturador funciona, mas atalhos globais precisam ser associados pelo gerenciador de teclas do ambiente; Wayland nao e suportado por esta versao.

## BAIXAR: pacote pronto, sem `apt install`

**Baixe a versao empacotada:**

**[Print-RC-Linux-x86_64.zip — Downloads / Releases](https://github.com/cceangra/Print-Screen-Port-til/releases/latest/download/Print-RC-Linux-x86_64.zip)**

O ZIP contem **um unico diretorio `Print-RC/`**, com:
- `bin/print-rc`: executavel C++ **compilado estaticamente**; `ldd` nao lista bibliotecas compartilhadas para esse executavel;
- `instalar.sh`, `iniciar.sh`, `configurar.sh`, `configurar-tecla.sh`, `desinstalar.sh`;
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

O instalador NAO cria segunda copia, nao instala pacotes e nunca sobrescreve arquivos existentes. Pode mesclar de forma conservadora a nova instalacao em uma pasta que ainda contenha prints preservados, com confirmacao. Se houver conflito com arquivo pessoal, cancela sem sobrescrever. Depois de detectar Print fisicamente, pede uma unica confirmacao de registro; substitui o uso anterior conhecido e guarda backup.

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

## Interface compacta Print RC 0.4.4

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

No Trinity, `instalar.sh` oferece registrar a tecla `Print` no atalho global com verificacao de conflitos e recarregamento do `khotkeysd`. No Xfce ha integracao automatica opcional via `xfconf-query` com restauracao conservadora. Em GNOME/KDE e outros desktops X11, ele fornece o comando e os passos para configurar manualmente sem modificar atalhos alheios. O cadastro do atalho e sempre separado do executavel de captura.

A integracao usa o `python3` do sistema para alterar apenas o atalho autorizado; no Xfce tambem usa `xfconf-query` existente. Se os recursos nao estiverem presentes, mostra instrucao de cadastro manual.

## O que nao pode ficar dentro da pasta

- **O kernel Linux, o servidor grafico X11, drivers, servicos do desktop e eventuais modulos dinamicos do sistema** nao fazem parte do aplicativo. Ele depende desses componentes para executar e captar teclas/tela.
- **O registro global permanente da tecla Print** e armazenado nas configuracoes do desktop, fora da pasta, porque um arquivo apenas dentro da pasta nao pode mudar os atalhos globais do desktop.
- **O interpretador Python3, quando escolhido para registrar o atalho automaticamente**, e um recurso do sistema. O executavel C++ de captura nao precisa dele.

Assim, 'pasta unica' aqui significa **todos os arquivos distribuidos do Print RC e as bibliotecas vinculadas ao executavel**, e nao um sistema Linux inteiro dentro da pasta. **Nao prometemos funcionar em todo Linux nem em Wayland.**

## Desinstalar

Na pasta instalada, execute `bash desinstalar.sh`. Digite **DESINSTALAR** para confirmar. A desinstalacao da v0.5.6 **NUNCA exclui imagens** e remove apenas os arquivos originais que tenham hash compativel com o inventario criado na instalacao. O atalho Print e desfeito quando foi configurado pelo Print RC. **Nao existe comando `rm -rf` para apagar a pasta inteira nem qualquer opcao para apagar prints.** Se houver fotos, capturas ou arquivos desconhecidos dentro da pasta do aplicativo, esses arquivos e suas pastas ficam no mesmo local, preservados. Se as imagens estiverem em uma pasta externa, essa pasta permanece completamente intacta. O atalho que voce registrou manualmente no desktop precisa ser removido manualmente, pois o programa so pode restaurar automaticamente atalhos que ele mesmo gerenciou. Se falhar ao restaurar o atalho gerenciado, a desinstalacao interrompe e preserva arquivos e backups. Nao altera pacotes instalados pelo Linux.

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
