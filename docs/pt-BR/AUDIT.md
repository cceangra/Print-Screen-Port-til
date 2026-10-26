# Auditoria de instalação e plataformas — 26/10/2026

Base revisada: `main` em `2ea3420e91c716a89c370de2c03b188b160fcdab`. Foram lidos inicializadores, instalador, configuração, adaptadores de tecla, inventário, diagnóstico, empacotamento, workflows e testes. Não houve acesso ao notebook que falhou nem ao erro dessa tentativa. As falhas abaixo são observações do repositório e regressões reproduzíveis; nenhuma delas identifica sozinha a causa da tentativa do usuário.

| Prioridade | Problema observado | Mudança / situação |
| --- | --- | --- |
| Alta | A release mais recente continua sendo 0.5.6, com o defeito SIGFPE relatado. O ZIP de código da main não contém binários; os candidatos ficam em outro download. | Avisos e instruções nos READMEs/guias; artefato passa a chamar Print-RC-Linux-x86_64. A release antiga não foi substituída ou apagada. Publicar uma versão estável continua dependendo da aceitação real. |
| Alta | Instalador verificava somente bin/print-rc; faltando o supervisor, a captura não abre mesmo depois de configurar arquivos. | Verificar os dois componentes e executar o autoteste através do supervisor antes de mover/criar preferências/atalhos. |
| Alta | Os executáveis podiam perder permissão no ZIP. O teste de execução vinha antes da recuperação dos bits do núcleo. | Recuperar somente permissões de arquivos regulares internos antes do teste; links são recusados. Uma montagem noexec continua sendo informada como bloqueio. |
| Alta | Python faltando podia ser percebido só depois de criar pastas/configuração. | Exigir Python 3.8+ funcional antes da configuração. Sem download automático de dependências. |
| Alta | Pelo gerenciador de arquivos, erro do supervisor ou falha antes de exec podia aparecer apenas em stderr e a abertura parecia não fazer nada. | Aviso gráfico opcional no processo nativo; erros de script anteriores ao supervisor também são encaminhados. Corrigido o tratamento explícito de exec falhando, pois Bash pode limpar o trap EXIT nesse ponto. |
| Média | Print-RC abre configuração só no primeiro uso; faltava uma entrada separada, óbvia, para instalar novamente com clique. | Executável nativo **Instalar**, compilado do mesmo fonte com modo fixo de instalação, inclusive se renomeado. |
| Média | A seleção de terminal não contemplava Sakura diretamente nem /opt/trinity/bin/konsole fora do PATH. | Acrescentadas essas duas entradas sem interpolação shell dos caminhos/argumentos. |
| Média | Nem todo gerenciador permite abrir ELF pelo duplo clique; regras de confiança não são iguais. | **Instalar.desktop** portátil, com Terminal=true, nomes pt-BR/en-US e descoberta da própria pasta, inclusive URI file: com caracteres escapados. Nenhuma cópia para fora do app. O desktop ainda pode pedir autorização para executar esse arquivo. |
| Média | Lista longa de distribuições e rótulos de prioridade podiam parecer suporte confirmado; Wayland/musl/ARM apareciam apenas como “não testados”. | Matriz explícita por arquitetura/libc/protocolo; estados sem implementação/pacote separados; NixOS marcado como adaptação necessária. Evidências antigas continuam vinculadas aos respectivos hashes. |
| Média | O pacote dinâmico depende de bibliotecas do sistema; não é autossuficiente. | Dependências e limites documentados. Embutir bibliotecas continua sendo melhoria futura a validar; não se deve voltar a glibc totalmente estática para ocultar esse requisito. |

## Arquivos alterados por grupo

- `src/app/entrypoint.cpp`, `src/app/dialog.hpp`, `src/app/launcher.cpp`, `Makefile`: Instalar nativo, terminais adicionais e mensagens de falha; sem toolkit novo no núcleo da captura.
- `Instalar.desktop`, `packaging/portable/package.py`, `scripts/build/manifest.py`: alternativa de clique, quarto ELF auditado, bits de execução e hashes no ZIP.
- `instalar.sh`, `iniciar.sh`: verificações antecipadas e falhas visíveis; continuam sem sudo, instalações de pacotes ou mudanças gerais no desktop.
- `scripts/inventario.sh`: Instalar, entrada de desktop, header novo e esta documentação entram na lista de propriedade da aplicação. Remoção continua baseada em hashes.
- `i18n/*.json`, tabelas geradas C++/Bash: 626 mensagens correspondentes; textos de pré-requisitos, falhas e modo de uso atualizados nos dois idiomas.
- `.github/workflows/{build,test,release}.yml`: mesmo nome de artefato nos produtores/consumidores, validação desktop-file e conferência dos quatro ELFs/permissões no pacote. Publicação estável mantém os critérios anteriores.
- `tests/test_entrypoint.py`, `tests/test_instalacao.sh`, `tests/test_launcher.sh`, `tests/test_packaged_ownership.sh`: regressões dos fluxos de clique, argumentos/URI, erro gráfico, Python/supervisor/permissões e remoção dos novos arquivos preservando dados pessoais.
- READMEs, changelogs, guias rápidos/instalação/problemas/compatibilidade e `compat/linux-targets.json`: orientação consistente e separação entre teste de núcleo e aceitação de desktop.

## Verificações

Localmente: os dois executáveis de entrada e o supervisor compilados com avisos habilitados; **75 testes Python aprovados**, regressão do supervisor para SIGFPE/código 136, execução inexistente/código 127 e erro gráfico simulado; sintaxe Bash, catálogos e YAML verificados. O núcleo usado nos testes Python locais veio do artefato aprovado da base acima; não foi recompilado neste host sem cabeçalhos X11. Nenhum teste local alterou o desktop de uma pessoa.

O CI da revisão recompila todos os ELFs e testa o ZIP extraído sem root em Ubuntu 20.04/22.04 e Debian 13, além de XFCE real sobre D-Bus/Xvfb. Consulte os checks do PR/commit para o resultado e o hash do novo pacote; o sucesso da base antiga não aprova esta revisão automaticamente.

Ainda faltam: instalação por clique no gerenciador do notebook real, aceitação no Zorin e no Q4OS, e o texto do erro da tentativa relatada. A janela gráfica de erro depende de zenity/kdialog/xmessage já presentes. Não foi prometida correção comprovada no notebook, suporte Wayland ou compatibilidade universal.

## Melhorias seguintes, por utilidade

1. Após aceitação real, publicar um pacote versionado fácil de encontrar e marcar 0.5.6 como antiga. Evitar obrigar usuários finais a navegar por artefatos de CI ou baixar fontes.
2. Se dependências ausentes forem frequentes, preparar pacote de bibliotecas próprias/AppImage com base antiga e testes; não incluir glibc arbitrária nem modificar LD_LIBRARY_PATH global.
3. Criar a edição Wayland com portais e confirmação pelo compositor. Manter X11/Trinity e testes próprios; outro backend, não outra lista de nomes de distribuições.
4. Tornar a configuração totalmente gráfica apenas se o uso por clique no terminal não resolver a dificuldade. Isso não exige deixar um processo gráfico extra residente.

As escolhas de arquitetura e referências oficiais estão na [matriz](COMPATIBILITY.md). Captura/PNG/clipboard não foram reescritos nesta revisão; a investigação concentrou-se em instalação, erro observável e delimitação de plataformas.
