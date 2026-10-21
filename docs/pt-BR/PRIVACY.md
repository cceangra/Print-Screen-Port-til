# Privacidade e arquivos

A captura lê a tela raiz visível do X11 somente quando solicitada. A detecção de tecla reserva temporariamente o teclado apenas durante a configuração pedida, termina na primeira tecla válida/Escape/prazo e registra o keysym escolhido, sem histórico de digitação. Não há leitor de teclado residente, telemetria, downloads, envios ou atualizador automático.

Preferências, idioma, registros de recuperação de atalhos, backups originais e inventário da desinstalação ficam na pasta do aplicativo. Os PNGs usam `capturas/` por padrão ou um destino externo escolhido explicitamente pelo usuário. Xfce e Trinity necessariamente guardam seus próprios registros de atalhos fora da pasta; os auxiliares informam essas mudanças e mantêm dados para restauração.

Não é criado log por captura por padrão. O diagnóstico somente leitura escreve na saída padrão, oculta caminhos pessoais/do app e evita segredos de variáveis de ambiente. Gravar relatório é uma ação explícita separada. O clipboard mantém temporariamente o PNG comprimido na memória por até 30 minutos ou até outro programa assumir. Quem tem acesso à mesma sessão X11 pode conseguir solicitar dados do clipboard pelo modelo normal de segurança do X11.
