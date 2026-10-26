# Compatibilidade desta edição

Esta edição é **GNU/Linux x86_64 + glibc + X11**. O nome da distribuição, sozinho, não comprova compatibilidade. Não existe uma versão validada para “qualquer Linux”.

| Ambiente | Captura | Tecla global | Evidência disponível |
| --- | --- | --- | --- |
| Ubuntu 20.04 e 22.04, Debian 13, em contêiner/Xvfb | Núcleo testado | Adaptadores simulados | Testes automatizados do ZIP; não é aceitação do desktop instalado |
| XFCE sobre Ubuntu 22.04/glibc 2.35 em D-Bus/Xvfb | Testada nesse ambiente | Serviço xfsettingsd/xfconf real testado | Não equivale ao Zorin instalado |
| Zorin 17.3 Lite, XFCE/X11 | Candidato dinâmico a validar | Adaptador XFCE implementado | Falha SIGFPE confirmada na 0.5.6 antiga; reparo no notebook real não confirmado |
| Q4OS, Trinity/X11 | Candidato a validar | Adaptador Trinity implementado | Versão atual ainda sem aceitação em desktop real |
| Mint, MX, Xubuntu e outros GNU/Linux x86_64 com XFCE/X11 | Possível com bibliotecas compatíveis | Adaptador XFCE | Distribuição/versão específica não testada não recebe selo de compatibilidade |
| GNOME, Plasma, MATE, Cinnamon, LXQt e outros em X11 | Possível, ainda a validar | Configuração manual no desktop | Sem adaptador automático nesta edição |
| Wayland, incluindo GNOME/Plasma/COSMIC/Sway/Hyprland nessa sessão | **Não implementada** | **Não implementada** | XWayland não transforma esta edição em um capturador Wayland |
| ARM64, ARM32, x86 de 32 bits | **Sem pacote** | Sem pacote | Exigem outra compilação validada |
| Alpine/musl | **Sem pacote** | Sem pacote | O pacote atual usa glibc |
| NixOS padrão | **Pacote genérico inadequado sem adaptação** | Não validada | Carregador e caminhos diferentes; nenhuma configuração do sistema é alterada automaticamente |
| Windows, macOS, Android | **Não implementada** | **Não implementada** | O formato ELF/Linux desta edição não serve a essas plataformas |

## Dependências e abertura por clique

O pacote **não embute bibliotecas de execução**. Requer glibc, libstdc++, libgcc, libX11, libpng16 e dependências transitivas compatíveis do sistema; Bash 4 ou posterior, ferramentas GNU usuais e Python **3.8 ou posterior** para instalar/configurar. O CI compila na base Ubuntu 20.04 e limita símbolos GLIBC a 2.31 e GLIBCXX a 3.4.28. Isso é um teto do build; os requisitos efetivos de cada executável constam em `build-manifest.json`. Não significa que toda distribuição com essa glibc foi testada.

A pasta deve ser gravável e permitir execução. Mantenha-a em um sistema de arquivos Linux, na pasta pessoal, se pendrive/montagem `noexec` impedir a abertura. Não é necessário alterar opções de montagem do sistema. `Instalar` e `Print-RC` precisam da permissão de executar; os extratores podem perder essa permissão. O instalador por script/entrada de desktop recupera os bits dos executáveis regulares dentro do app.

Abra **Instalar** na pasta. Se o gerenciador de arquivos bloquear binários, use **Instalar.desktop / Instalar (terminal)**, autorizando a execução desse arquivo quando solicitado. Esse arquivo abre o terminal escolhido pelo desktop e encontra sua própria pasta, sem digitar caminhos. Ele permanece dentro do app e não é copiado para menus/autostart. O comportamento exato do duplo clique depende do gerenciador de arquivos e ainda precisa ser conferido no notebook real.

A captura não exige terminal permanente. A entrada nativa reconhece x-terminal-emulator, Konsole, Konsole do Trinity em /opt/trinity, Sakura, xfce4-terminal, xterm e gnome-terminal para tarefas interativas. Diálogos de erro usam zenity, kdialog ou xmessage somente se já disponíveis; nenhum deles é instalado pelo app. Sem esses programas, a saída de erro continua disponível no terminal.

## Próxima plataforma

Para uma futura edição Wayland, use os portais **Screenshot** e **GlobalShortcuts**, detectando os recursos que o compositor realmente oferece e respeitando a confirmação do usuário. O compositor pode recusar uma tecla; “qualquer tecla garantida” não é uma promessa possível. Compartilhe a parte PNG/configuração e isole captura/atalhos por backend. Trocar C++ por outra linguagem não remove essa limitação de protocolo.

ARM precisa de build/artefato próprios. Musl e NixOS precisam de empacotamento próprio. Um AppImage pode reduzir dependências ausentes, mas não elimina os requisitos de glibc, permissões ou os testes em cada base. A prioridade desta edição é manter o núcleo X11 pequeno, sem leitor de teclado permanente.

## Fontes e resultados

- [Testes do main antes desta auditoria](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39855959788): fonte `2ea3420e91c716a89c370de2c03b188b160fcdab`. Cada resultado vale para seu ZIP/commit; não é aceitação das alterações posteriores.
- [Catálogo de alvos e evidências históricas](../../compat/linux-targets.json). `support_tier` significa prioridade de teste; não qualidade de suporte.
- [Thunar: regras para abrir executáveis](https://docs.xfce.org/xfce/thunar/faq).
- [Portais Screenshot](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Screenshot.html) e [GlobalShortcuts](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html).
- [NixOS e executáveis genéricos](https://nix.dev/guides/faq.html).
- [AppImage: dependências, base antiga e testes continuam necessários](https://docs.appimage.org/reference/best-practices.html).

Zorin e Q4OS reais continuam como critérios de aceitação antes de uma release estável. Não há substituição de libc, instalação automática de dependências ou alteração ampla de configuração do sistema.
