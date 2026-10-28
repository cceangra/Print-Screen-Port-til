# Instalar sem digitar caminhos

1. Baixe o **pacote binário candidato** do [Actions](https://github.com/cceangra/Print-Screen-Port-til/actions/workflows/testar.yml), em uma execução aprovada. O artefato chama-se **Print-RC-Linux-x86_64**. Dentro dele está o ZIP do aplicativo **Print-RC-Linux-x86_64.zip**. Extraia esse ZIP interno.
2. Abra a pasta única **Print-RC** e dê duplo clique em **Instalar**. Ele abre a instalação no terminal automaticamente. Não é preciso escrever `bash` nem o caminho completo.
3. Se o gerenciador bloquear binários, abra **Instalar.desktop**, exibido como **Instalar (terminal)**. Autorize a execução desse arquivo quando o desktop perguntar. Essa alternativa permanece dentro da pasta do app.
4. Na primeira pergunta, **1 ou Enter mantém a pasta atual**. Nas perguntas sobre imagens, **1 ou Enter mantém a pasta recomendada/atual e a escolha de Ctrl+V anterior** (no primeiro uso, copiar fica ligado). Leia o resumo e confirme com **1 = Sim**.
5. Pressione a tecla desejada quando aparecer o pedido. Confira o nome e o conflito identificado e confirme com **1 = Sim**. Depois, no teste, aperte **a própria tecla escolhida** mais uma vez. Não é outra pergunta para responder Sim. Sem o teste bem-sucedido, o app avisa que a tecla ainda não está confirmada.
6. Depois, abra **Print-RC** para capturar ou use a tecla configurada. Para mudar as opções, abra **Configurar**. Se o gerenciador bloquear o binário, use **Configurar.desktop**, exibido como **Configurar Print RC**.

**Code → Download ZIP contém apenas fontes.** Os arquivos novos `Instalar`, `Print-RC` e `bin/` só aparecem no pacote binário compilado. A release **0.5.6 é antiga** e não contém esta atualização. O nome do ZIP é o mesmo; verifique a versão em `VERSION` e o commit em `build-manifest.json`.

A pasta pai do destino deve existir. Não execute como root. O aplicativo não instala dependências. Veja a [matriz de compatibilidade](COMPATIBILITY.md): esta edição usa GNU/Linux x86_64, glibc e **X11**. Wayland, ARM e musl não têm pacote compatível nesta edição.

Se a permissão de executar tiver sido perdida, marque **Propriedades → Permissões → Permitir executar** no arquivo, ou use `Instalar.desktop`. Se a montagem bloquear execução, extraia em uma pasta Linux na sua pasta pessoal. Não é preciso mudar configurações de montagem nem a política geral do gerenciador de arquivos.

| Ação | Clique ou comando opcional |
| --- | --- |
| Instalar ou revisar instalação | **Instalar** ou **Instalar (terminal)** |
| Capturar | **Print-RC** |
| Preferências e idioma | **Configurar** → opção 1 (imagens/Ctrl+V) ou 3 (idioma) |
| Escolher, verificar ou liberar tecla | **Configurar** → opção 2 |
| Diagnóstico somente leitura | **Configurar** → opção 4 |
| Desinstalar com prévia | **Configurar** → opção 5 |

As entradas antigas `bash instalar.sh` e `bash iniciar.sh` continuam disponíveis em um terminal aberto na própria pasta. Não é preciso escrever o caminho completo.

Escolha uma tecla física reconhecida pelo X11. Print e Insert são independentes; Escape e modificadores sozinhos são reservados. Letras, Enter e espaço podem prejudicar a digitação como teclas globais. Se o cadastro/prova falhar, desative o conflito no gerenciador de atalhos e abra `configurar-tecla.sh` para verificar ou escolher outra tecla. Apenas Trinity e XFCE têm adaptadores automáticos; outros desktops X11 precisam de associação manual.

Configurações, estados, backups, executáveis e capturas padrão ficam dentro da pasta. O manifesto `config/installation-manifest.json` declara a propriedade XFCE ou as seções Trinity externas registradas pelo app; a remoção restaura somente o que ainda pertence à instalação. Atalhos criados manualmente pelo usuário precisam de remoção manual. O gerenciador de arquivos pode guardar seus próprios metadados de confiança/histórico; o app não controla esses arquivos do desktop.

Ao desinstalar, confira a prévia e digite `DESINSTALAR` ou `UNINSTALL`. Capturas, relatórios pedidos pelo usuário e arquivos desconhecidos/modificados permanecem. Consulte [remoção](UNINSTALL.md) e [auditoria](AUDIT.md).

Nas confirmações de gravação/alteração, **Enter significa Não**. Respostas desconhecidas pedem novamente. As respostas antigas s/n e sim/não continuam aceitas. Se preferir outra pasta de imagens, escolha 2 e cole o caminho sem aspas; ~/ é aceito. [Detalhes desta melhoria](BEGINNER_SETUP.md).
