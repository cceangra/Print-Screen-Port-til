# Compatibilidade

`compat/linux-targets.json` é um catálogo de alvos de teste, não uma promessa de suporte. Cada resultado deve identificar sistema real, arquitetura, libc, desktop/protocolo, bibliotecas, hash do pacote, commit dos fontes, verificações, data e medidas de desempenho. Itens sem versão/validação continuam não testados.

O candidato principal é GNU/glibc x86_64, com vínculo dinâmico à glibc/libstdc++/libX11/libpng16 do sistema. O CI compila em Ubuntu 20.04 sobre um executor Ubuntu 22.04 fixado e verifica os símbolos GLIBC ≤ 2.31 e GLIBCXX ≤ 3.4.28 efetivos. Executa o ZIP exato extraído em contêineres Ubuntu 20.04, Ubuntu 22.04/glibc 2.35 e Debian 13 com Xvfb. Sucesso no contêiner não comprova compatibilidade com o desktop instalado.

Bloqueios de publicação: Zorin 17.3 Lite/XFCE/X11/glibc 2.35 real, Q4OS/Trinity/X11, ambiente com libc antiga e base de compilação. Evidências de máquina física/virtual com desktop devem verificar acionamento/restauração do atalho e o fluxo completo de captura/clipboard. O hash publicado precisa corresponder ao pacote testado.

Wayland exige outro backend de portal/compositor e modelo de permissões. ARM64 exige outra compilação. Musl/Alpine exige pacote separado e testado. Nenhum deles é anunciado como compatível. Não há troca da glibc do sistema, carregador arbitrário embutido, alteração ampla de LD_LIBRARY_PATH ou instalação automática de dependências.
