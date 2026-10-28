# Print RC

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

Capturador de tela e anotação leve, escrito em C++17 nativo para Linux **X11**. Selecione uma área, capture a tela inteira com um clique, desenhe com o lápis, desfaça, salve PNG e, opcionalmente, cole com Ctrl+V. O desktop gerencia os atalhos; o Print RC não mantém um leitor de teclado residente.

## Situação da versão candidata

A `0.6.0-dev` substitui a compilação GNU totalmente estática por uma compilação dinâmica. Isso trata uma hipótese de empacotamento ligada ao **SIGFPE da v0.5.6 no Zorin OS 17.3 Lite/XFCE/glibc 2.35**. **O reparo nesse desktop ainda não foi verificado.** A validação no Q4OS/Trinity também continua obrigatória. Acompanhe a [issue #1](https://github.com/cceangra/Print-Screen-Port-til/issues/1).

O [catálogo de compatibilidade](compat/linux-targets.json) lista alvos de teste, inclusive distribuições não testadas. Testes com Xvfb verificam o núcleo X11 e a ABI; não certificam o desktop instalado. Wayland, ARM64 e musl/Alpine ainda não têm implementações ou pacotes anunciados como compatíveis.

## Baixar e executar

**Dê duplo clique em `Instalar` na pasta do aplicativo.** A instalação abre no terminal automaticamente; você não precisa digitar `bash` nem o caminho. Se o gerenciador bloquear binários, abra `Instalar.desktop`, exibido como **Instalar (terminal)**, e autorize esse arquivo quando solicitado. Depois da configuração, abra **Print-RC** para capturar ou **Configurar** para mudar as opções em um menu numerado. [Passo a passo](docs/pt-BR/QUICK_START.md).

**Baixe o pacote binário de uma execução aprovada do [Actions](https://github.com/cceangra/Print-Screen-Port-til/actions/workflows/testar.yml)**: artefato **Print-RC-Linux-x86_64**, contendo **Print-RC-Linux-x86_64.zip**. Extraia o ZIP interno: ele contém uma única pasta `Print-RC/`. **Code → Download ZIP contém só fontes**, sem executáveis prontos. A release **0.5.6 é antiga** e não contém esta atualização.

O instalador mantém a pasta extraída ou a move, após confirmação, para um destino escolhido. Configurações, executáveis, backups e capturas padrão ficam dentro dela. O app não instala pacotes, não usa sudo e não baixa dependências. Requer bibliotecas do sistema compatíveis, Bash e Python 3.8+; **não é um pacote com todas as bibliotecas embutidas**.

| Plataforma/sessão | Situação desta edição |
| --- | --- |
| GNU/Linux x86_64, glibc, X11 | Núcleo testado em Ubuntu 20.04/22.04 e Debian 13 via Xvfb; desktop real ainda requer aceitação |
| XFCE ou Trinity em X11 | Configuração automática da tecla implementada; Zorin/Q4OS reais pendentes |
| Outros desktops X11 | Associação manual da tecla; validação específica pendente |
| Wayland, ARM, 32 bits, Alpine/musl | Sem implementação/pacote compatível nesta edição |
| NixOS padrão, Windows, macOS | Este pacote genérico não atende sem outra adaptação/edição |

Veja a [matriz completa](docs/pt-BR/COMPATIBILITY.md) e a [auditoria das falhas e correções](docs/pt-BR/AUDIT.md). A instalação verifica componentes/Python e recuperação de permissões antes de criar preferências ou atalhos. As entradas antigas `bash instalar.sh` e `bash iniciar.sh` continuam disponíveis em um terminal aberto na pasta.

## Configurações e idioma

Abra **Configurar** na pasta do app. Escolha 1 para imagens/Ctrl+V, 2 para a tecla, 3 para idioma, 4 para diagnóstico ou 5 para desinstalar com confirmação. Nas perguntas de salvar/alterar, 1 = Sim, 2 = Não e Enter = Não. Não é preciso escrever comandos.

Os comandos antigos também continuam disponíveis:

```bash
bash configurar.sh
bash configurar.sh --language pt-BR
bash configurar.sh --language en-US
bash configurar-tecla.sh
bash diagnosticar.sh --read-only
bash desinstalar.sh
```

Escolha do idioma: variável `PRINT_RC_LANG` → preferência em `config/language` → `LC_ALL` → `LC_MESSAGES` → `LANG` → inglês quando não houver idioma reconhecido. Português brasileiro e inglês usam os mesmos fontes e catálogos validados. Os nomes antigos dos inicializadores em português continuam disponíveis nos dois idiomas.

As capturas ficam em `capturas/` por padrão. Um destino externo escolhido explicitamente pertence ao usuário. A desinstalação preserva imagens, arquivos desconhecidos, arquivos do app modificados e atalhos alterados por terceiros. Confira a apresentação antes de confirmar.

Com clipboard ligado, um processo nativo guarda o **PNG comprimido** por até 30 minutos ou até outro aplicativo assumir o clipboard. Os buffers de pixels são liberados antes dessa espera. Com clipboard desligado, nenhum processo do Print RC permanece após a captura ou o cancelamento.

## Documentação

[Instalação](docs/pt-BR/INSTALL.md) · [Uso](docs/pt-BR/USER_GUIDE.md) · [Problemas](docs/pt-BR/TROUBLESHOOTING.md) · [Desinstalação](docs/pt-BR/UNINSTALL.md) · [Compatibilidade](docs/pt-BR/COMPATIBILITY.md) · [Privacidade](docs/pt-BR/PRIVACY.md) · [Desenvolvimento](docs/pt-BR/DEVELOPMENT.md) · [Alterações](CHANGELOG.pt-BR.md)

Licença GPL-3.0-or-later. O histórico original permanece no Git, incluindo o [README da v0.5.6](https://github.com/cceangra/Print-Screen-Port-til/blob/v0.5.6/README.md).

[Relatório completo de implementação e testes](docs/pt-BR/IMPLEMENTATION.md). O SIGFPE original foi reproduzido no substituto Ubuntu 22.04/glibc 2.35 com serviços XFCE isolados; compilação dinâmica abriu a interface nesse ambiente. Zorin e Q4OS reais continuam pendentes.
