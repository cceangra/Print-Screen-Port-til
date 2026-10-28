# Alterações

## 0.6.0-dev — candidato não publicado

- Troca do vínculo GNU/glibc totalmente estático por compilações dinâmicas; tag e arquivos originais da v0.5.6 preservados para investigação. O reparo relatado no Zorin continua sem confirmação até a validação no desktop real.
- Processo pai nativo para informar sinais e prova com identificador da instância depois de desenhar/mapear a interface e obter os dois controles de entrada. Apenas criar um processo não aprova o teste.
- Compilação com base ABI declarada; auditoria ELF de dependências/símbolos/IDs; arquivos de pasta única com hash e geração determinística; testes do pacote extraído em diferentes ambientes. Publicação por tag explícita exige evidências separadas de desktop/desempenho. Removidas regravação automática de binário e publicação por arquivos marcadores.
- Interface, auxiliares e documentação centralizados em inglês/português brasileiro. Nomes dos inicializadores e formatos de atalhos preservados; módulos nativos de imagens/entrada/clipboard/interface separados.
- Instalação/desinstalação que preservam dados, diagnóstico somente leitura e medidas de recursos sob testes de regressão. Consulte o relatório de implementação para resultados exatos e validações pendentes.

O histórico original permanece no Git e na documentação/tag intactas da v0.5.6.

A investigação reproduziu SIGFPE no original estático em Ubuntu 22.04/glibc 2.35 com serviços XFCE isolados. Original recompilado dinamicamente e candidato abriram a interface nesse substituto; Zorin/Q4OS reais continuam pendentes. O PNG é codificado uma vez por linhas; clipboard usa eventos e libera conexão X11 da captura e dados da caneta antes de permanecer residente.

- Adiciona executável nativo `Print-RC` na raiz e ações/instalação no terminal. Rastreia atalhos posteriores e registros externos, mantém recibos de remoção em operações externas interrompidas, evita pastas pais externas sem registro e corrige corrida de prontidão no benchmark do clipboard.

- Auditoria de instalação: adiciona Instalar nativo e entrada de desktop interna, Sakura/Trinity, verificações antecipadas de Python/supervisor/permissões, falhas gráficas opcionais e matriz explícita de plataformas. Nome do artefato/ZIP segue Print-RC-Linux-x86_64. Sem novos processos residentes. [Relatório](docs/pt-BR/AUDIT.md).

- Configuração para iniciantes: executável Configurar e alternativa de desktop; menu único para imagens/Ctrl+V, tecla, idioma, diagnóstico e remoção; perguntas numeradas, padrões explícitos e confirmação segura. Corrige mensagem de sucesso após falha no cadastro da tecla e preserva o resultado da prova no manifesto. [Detalhes e testes](docs/pt-BR/BEGINNER_SETUP.md).
