# Configuração para iniciantes

Esta revisão mantém a edição GNU/Linux x86_64/glibc/X11, o núcleo de captura e os critérios de compatibilidade anteriores. Não cria uma edição Wayland, não publica uma release estável e não certifica um notebook sem teste nele.

## O que muda para quem usa

- **Instalar** continua iniciando a instalação por clique. As três etapas são: onde manter a pasta, como salvar/copiar imagens e qual tecla usar.
- **Configurar** abre um menu numerado. Há uma alternativa Configurar.desktop para gerenciadores que exigem uma entrada de desktop. Não precisa escrever bash nem caminhos de comandos.
- As duas perguntas de imagens explicam a pasta e a opção “copiar para colar com Ctrl+V”. Enter mantém a escolha atual/recomendada; escolhas antigas são preservadas.
- Confirmações que gravam ou substituem algo usam **1 = Sim, 2 = Não, Enter = Não**. Uma resposta inválida pede novamente. s/n e sim/não continuam aceitos.
- Outra pasta é opcional. Ela pode ser colada sem aspas e ~/ é aceito. O aplicativo não avalia a resposta como código.
- A tecla é escolhida fisicamente, mostrada e confirmada. Depois o teste pede pressionar a própria tecla de novo; não é outra confirmação com Sim. As mensagens distinguem tecla não configurada, salva e testada.
- Configurar inclui a troca de idioma, relatório somente leitura e remoção com a prévia/confirmacão anterior. O próprio menu não instala atalhos externos, itens de menu do desktop ou autostart.

## Correções além dos textos

No menu da tecla, Bash pode executar uma função sem encerrar em erro quando ela é chamada em `funcao || true`. O configurador continuava depois de uma falha do adaptador e podia anunciar registro gravado e iniciar a prova. Agora o retorno de cada adaptador é verificado explicitamente; falha ou recusa interrompe esse caminho sem anunciar sucesso.

Quando a prova de interface é aprovada ao reconfigurar, o manifesto recebe esse resultado em vez de voltar sempre ao estado pendente. Isso comprova somente a prova relatada; captura salva e aceitação do notebook continuam separadas.

## Arquivos por responsabilidade

- `configurar.sh`, `instalar.sh`, `configurar-tecla.sh`: menu, opções numeradas, confirmação e estados claros; entradas e respostas antigas continuam disponíveis.
- `scripts/prompts.sh`, `scripts/print_rc_i18n.py`, adaptadores Trinity/XFCE: confirmações consistentes; visão resumida no instalador preservando o aviso das alterações externas e os diagnósticos detalhados.
- `src/app/entrypoint.cpp`, `Makefile`, `Configurar.desktop`, bootstrap de desktop: entrada nativa de configuração e localização independente da pasta de onde foi aberta.
- Manifesto, empacotador, workflow de build e inventário: quinto ELF auditado, permissões de execução, fontes correspondentes e remoção dos novos arquivos por hash.
- Catálogos pt-BR/en-US e tabelas geradas: perguntas equivalentes nos dois idiomas.
- Testes: entrada Configurar normal/URI e permissão perdida, confirmação numérica/legada/EOF, configurações sem gravação após cancelamento, idioma pelo menu, falha do adaptador sem falso sucesso e remoção preservando dados. Sakura real continua no CI.

## Limites e validação

Localmente: entradas/supervisor compilados; 78 testes Python aprovados; sintaxe Bash e catálogos verificados. O núcleo usado localmente veio do candidato aprovado anterior; o CI recompila o pacote completo e executa os testes Bash/C++/Xvfb sem root nos ambientes declarados. Consulte os checks do commit para o resultado exato do novo ZIP.

Sem novo serviço residente, leitor de teclado contínuo, download de dependências ou mudança global do sistema. Configurações, executáveis e registros permanecem na pasta; os recursos externos de atalho continuam registrados para restauração conservadora. Imagens e arquivos pessoais permanecem preservados. [Guia rápido](QUICK_START.md) · [Matriz de compatibilidade](COMPATIBILITY.md).

A escolha de manter a pasta das imagens respeita o caminho interno relativo quando a pasta do aplicativo foi movida; não volta silenciosamente para o destino antigo. Isso não altera automaticamente atalhos externos movidos manualmente.

A troca da pasta das imagens também atualiza o destino no manifesto de uma instalação existente, mantendo essas imagens como dados do usuário preservados na remoção.

O teste de tecla também recusa config/ como link simbólico, para não gravar marcadores temporários fora da pasta do aplicativo. A regressão isolada verifica a preservação do arquivo externo.
