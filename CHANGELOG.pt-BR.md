# Alterações

## 0.6.0-dev — candidato não publicado

- Troca do vínculo GNU/glibc totalmente estático por compilações dinâmicas; tag e arquivos originais da v0.5.6 preservados para investigação. O reparo relatado no Zorin continua sem confirmação até a validação no desktop real.
- Processo pai nativo para informar sinais e prova com identificador da instância depois de desenhar/mapear a interface e obter os dois controles de entrada. Apenas criar um processo não aprova o teste.
- Compilação com base ABI declarada; auditoria ELF de dependências/símbolos/IDs; arquivos de pasta única com hash e geração determinística; testes do pacote extraído em diferentes ambientes. Publicação por tag explícita exige evidências separadas de desktop/desempenho. Removidas regravação automática de binário e publicação por arquivos marcadores.
- Interface, auxiliares e documentação centralizados em inglês/português brasileiro. Nomes dos inicializadores e formatos de atalhos preservados; módulos nativos de imagens/entrada/clipboard/interface separados.
- Instalação/desinstalação que preservam dados, diagnóstico somente leitura e medidas de recursos sob testes de regressão. Consulte o relatório de implementação para resultados exatos e validações pendentes.

O histórico original permanece no Git e na documentação/tag intactas da v0.5.6.

A investigação reproduziu SIGFPE no original estático em Ubuntu 22.04/glibc 2.35 com serviços XFCE isolados. Original recompilado dinamicamente e candidato abriram a interface nesse substituto; Zorin/Q4OS reais continuam pendentes. O PNG é codificado uma vez por linhas; clipboard usa eventos e libera conexão X11 da captura e dados da caneta antes de permanecer residente.
