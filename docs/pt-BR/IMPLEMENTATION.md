# Relatório de implementação e validação — 0.6.0-dev

[English](../en-US/IMPLEMENTATION.md)

Este é um candidato de desenvolvimento revisável no [PR #2](https://github.com/cceangra/Print-Screen-Port-til/pull/2), seguindo o handoff fornecido na ordem P0 → empacotamento → idiomas/organização → ciclo de instalação → desempenho. Os commits separam essas fases. O contrato de aceitação **ainda não foi concluído**: não houve acesso a desktop físico ou VM Zorin 17.3 nem Q4OS/Trinity. Main e tag/assets originais v0.5.6 permanecem intactos. Nenhum lançamento foi publicado.

## Evidência e alteração P0

O handoff demonstra que Insert iniciava o processo antigo, que terminava com SIGFPE/136 em divisão inteira da libc do sistema. Autoteste PNG ou PID nunca foram prova suficiente de interface visível.

A [execução aprovada 39695994801](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39695994801), fonte `0bd95a6bb8cc1d46050fefdfcb226205437bc6e9`, testou o ZIP exato SHA-256 `7d5f19147fe21452de771dfd4a39071454b84bb8141dd92526baea0a40c6a83a`. É um checkpoint anterior testado, não o checksum de todos os candidatos posteriores. As verificações atuais do PR identificam seus próprios commits e hashes.

Em contêiner Ubuntu 22.04/glibc 2.35 com xfsettingsd/xfconf reais, D-Bus isolado e Xvfb, o GDB reproduziu SIGFPE no binário estático original v0.5.6 preservado (build ID `f1fd943d78ed03fa6936057229f7966adba90126`). O código v0.5.6 sem alterações, compilado dinamicamente nesse ambiente, mapeou/desenhou a interface e cancelou corretamente. O candidato iniciou pelo atalho Insert real, comprovou nonce/desenho/entrada pronta, gravou PNG válido de 1024×768, restaurou Insert anterior e preservou Print. Consulte o [índice preservado](../../compat/test-results/ci-39695994801/evidence-index.json) e os logs com hashes.

O checkpoint GDB ampliado [39697099560](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39697099560) também registrou mapas/instruções: a falha ocorre no deslocamento `0x175c79` da libc do sistema, instrução `div %rsi`, com RSI=0. Corresponde ao deslocamento do handoff e comprova divisor zero no substituto.

Isso restringe a falha à interação entre build distribuído e host, sustentando substituir o empacotamento GNU totalmente estático. A causa em símbolo específico de libc/TLS **não foi identificada**: o backtrace do binário sem símbolos contém quadros não resolvidos. A interação de carregamento entre glibc estática e bibliotecas do sistema continua sendo inferência. O substituto não certifica Zorin; o teste real Insert→interface→PNG→colar continua bloqueando o lançamento.

Os alvos GNU padrão e portátil agora usam ligação dinâmica. Um pequeno supervisor nativo observa sinais fatais do filho, devolve 128+sinal e informa se a interface chegou à etapa pronta. O aplicativo só publica prontidão após desenhar, XSync, IsViewable, reservar teclado e ponteiro com sucesso e não ter erro X de inicialização. O teste explícito abre/fecha brevemente a interface sem salvar. A prova de atalho só aceita o token da instância correspondente; criar processo mantém ativação pendente. Injeção controlada SIGFPE/SIGSEGV verifica relato de falha sem remapear teclas.

## Empacotamento, organização e idiomas

Ubuntu 20.04/glibc 2.31 é a base de compilação em runner Ubuntu 22.04. O manifesto registra compilador/linker, commit limpo, arquitetura, build IDs, dependências, símbolos e SHA-256. O gate impõe GLIBC ≤2.31 / GLIBCXX ≤3.4.28. No checkpoint registrado, o executável principal tinha 96.576 bytes, exigia GLIBC 2.15 / GLIBCXX 3.4.26 / CXXABI 1.3.9 e dependia de libX11, libpng16, libstdc++, libgcc_s e libc. Esses requisitos medidos não prometem suporte a qualquer sistema antigo.

O pacote tem uma pasta `Print-RC/` com dois executáveis nativos necessários, fontes, catálogos, scripts, testes e documentação. Não inclui glibc, carregadores ou drivers do host, nem altera LD_LIBRARY_PATH globalmente. Ordem/timestamps determinísticos e hashes permitem reproduzir o ZIP para uma entrada auditada fixa; imagens e repositórios de dependências são bases versionadas, sem promessa de reconstrução idêntica indefinidamente. Download ZIP do código requer compilação; binários prontos ficam nos artefatos Actions. CI normal não faz commit de binários nem publica por marcadores históricos.

Publicação é manual para tag existente explícita: recompila/testa essa tag e exige evidência separada do mesmo arquivo/fonte em Zorin, Q4OS, ambiente antigo e base de compilação, com desempenho e logs com hashes. Xvfb não substitui os dois desktops alvo. Evidência ausente/incompleta, fonte suja/dev, libc estática, ABI nova ou hashes diferentes bloqueiam publicação. Assets existentes não são sobrescritos. ARM64, musl/Alpine e Wayland exigem implementação/compilação/testes próprios e não são anunciados como suportados.

O C++ foi separado em módulos app/config/images/input/clipboard/ui/i18n. Entradas públicas com nomes portugueses e include legado de preferências continuam compatíveis. Esquemas de estado Trinity/XFCE foram mantidos, incluindo recuperação de operações antigas interrompidas.

Cada catálogo contém **613 mensagens correspondentes**: interface/ajuda/erros nativos, Bash/Python de instalação/configuração/remoção e diagnóstico. O gerador rejeita chave ausente/duplicada/vazia, placeholders/printf incompatíveis, ID desconhecido e tabelas desatualizadas. Precedência: PRINT_RC_LANG → config/language salvo → LC_ALL → LC_MESSAGES → LANG → inglês. Rótulos X11 de fonte fixa convertem acentos portugueses suportados sem Qt/GTK. A documentação cobre os mesmos tópicos nos dois idiomas. Fluxos CLI, ajuda e propriedades de idioma da interface foram testados; revisão visual de fonte/texto nos desktops reais continua pendente.

## Instalação, migração e alterações externas

Execute como usuário comum: `bash instalar.sh`, `bash configurar.sh --language pt-BR` (ou `en-US`), `bash configurar-tecla.sh`, `bash iniciar.sh`. Mantenha a pasta extraída ou escolha explicitamente movê-la. Não sobrescreva instalação existente: preserve capturas/backups/estado, extraia candidato separado e revise a prévia do desinstalador antigo antes de confirmar. Preferências absolutas antigas save_dir continuam aceitas. Novos destinos internos usam save_dir_relative; pastas externas escolhidas continuam pertencendo ao usuário.

Após mover/renomear, execute `bash configurar-tecla.sh --relocate` na nova pasta. O reparo mostra e atualiza caminhos registrados do inicializador/imagens internos, compara posse externa e grava diário antes da alteração. Preserva edições de terceiros e mantém metadados em caso de interrupção. Espaços, acentos, parênteses e links para wrappers públicos foram cobertos; links internos inesperados são recusados.

As únicas integrações automáticas externas são a propriedade custom selecionada de xfce4-keyboard-shortcuts (normalmente persistida pelo xfconf na configuração da sessão do usuário) ou ação/gatilho Trinity em `$TDEHOME/share/config/khotkeysrc` / `~/.trinity/share/config/khotkeysrc`. Valores anteriores, referências externas exatas e backups ficam dentro do aplicativo. Não há alteração do override global XFCE, mapa de teclado, XKB, configuração de sistema, pacote de dependências ou encerramento forçado de serviço do desktop. Atalhos manuais de outros desktops exigem remoção manual. Uma pasta externa de imagens escolhida explicitamente é o outro destino possível e nunca vira conteúdo removível do app.

`bash desinstalar.sh` mostra prévia, restaura apenas alterações de atalho ainda próprias e remove só arquivos inventariados e inalterados. Capturas, arquivos desconhecidos, fontes alteradas e atalhos mudados por terceiros são preservados. Arquivos modificados podem manter intencionalmente pasta/backups; o ZIP original baixado fora da pasta também permanece. O inventário não concede posse de capturas nem destinos de links. Auxiliares suprimem bytecode Python, evitando caches não registrados no uso normal.

`bash diagnosticar.sh --read-only` observa SO/sessão/ELF/configuração e arquivos conhecidos dos registros de atalhos. Não executa capturador, xfconf-query/DCOP, cria relatório, reserva entrada, injeta teclas ou inicia serviço. Campos técnicos/esquema JSON são estáveis; explicações seguem idioma e caminhos pessoais são ocultados. `--output /novo/relatorio.json` é modo de escrita separado, explícito e exclusivo/sem sobrescrita. Testes comparam conteúdo/mtime e usam executável falso com sentinela para comprovar ausência de execução/mutação.

## Testes e comandos exatos

Em máquina isolada de desenvolvimento/teste com ferramentas documentadas:

```bash
make -B all
python3 -B scripts/build/locales.py --check
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s tests -v
bash -n ./*.sh scripts/*.sh tests/*.sh
# Usuário comum; isto abre janelas de teste e envia entrada explicitamente.
bash tests/run.sh
# Compilar/auditar na base declarada, não no host mais novo do desenvolvedor.
make -B portable
python3 -B scripts/build/manifest.py --output dist/build-manifest.json --max-glibc 2.31 --max-glibcxx 3.4.28
python3 -B packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-linux-x86_64-glibc.zip
(cd dist && sha256sum -c Print-RC-linux-x86_64-glibc.zip.sha256)
```

Consulte os workflows para comandos de contêiner e artefatos de logs. Dependências são instaladas somente em CI/ambiente de desenvolvimento.

| Escopo | Resultado e limite prático |
| --- | --- |
| Base original | 42 testes Python originais passaram antes da refatoração. Testes de captura/teclado/clipboard/ciclo de instalação foram preservados. |
| Python atual | 68 testes passaram localmente no Ubuntu 24.04/glibc 2.39, incluindo recusas de lançamento, idiomas, posse, movimentação e diagnóstico de leitura. |
| Matriz de pacote registrada | Cinco jobs aprovados na execução 39695994801: base auditada, Ubuntu 20.04, Ubuntu 22.04, Debian 13 e serviços XFCE reais no substituto. Esse checkpoint anterior tinha 62 testes Python; os checks posteriores repetem a suíte ampliada. |
| Interface/entrada | Pixels mapeados/escurecidos, nonce, ambas reservas de entrada, falhas com reserva concorrente, Escape/botão direito/fechar, instância única e liberação; profundidade 16/24 e dois idiomas. |
| Captura/PNG | Área/tela inteira, igualdade de pixels caneta/desfazer, geometria ímpar 301×173 e RGBA exato; profundidade 24 normalmente cobre armazenamento 32-bpp. Profundidade raiz nativa 32 não estava disponível. |
| Clipboard | Igualdade de PNG via INCR de vários MB, falha de disco preservando colar, saída do proprietário antigo, limite de 16 transferências, recusa do excesso e recuperação de vaga após cliente destruído. |
| Teclas/adaptadores | Independência Print/Insert; letras, Return, F9/F12, modificadores/timeout/liberação; recuperação de esquema Trinity e mocks XFCE; Insert→PNG→restaurar via xfsettingsd real isolado. |
| Ciclo de instalação | Instalação/configuração/remoção sem root, fluxo inglês/preferência portuguesa, espaços/acentos/parênteses, movimentação interrompida, arquivos pré-alterados/desconhecidos, links e edições concorrentes preservadas. |
| Sanitizadores | AddressSanitizer + UndefinedBehaviorSanitizer locais mapearam/cancelaram e salvaram PNG ímpar com profundidade 16 sem erro relatado (`ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1`). LeakSanitizer não conseguiu inspecionar namespace de processos deste sandbox; não se alega teste de vazamentos aprovado. |
| Não demonstrado | Zorin/Q4OS reais; múltiplos monitores/coordenadas negativas/escalas; laptop Intel físico de baixo consumo; Wayland, ARM64, musl ou todas as distribuições do catálogo. |

O contêiner local executa como root e restringe sockets Unix e /proc dos filhos. Testes de instalação/remoção rodaram como usuário comum no CI; Xvfb local usou TCP loopback. A proteção contra root foi mantida. Builds locais de host mais novo são de desenvolvimento, sem rótulo de pacote portátil da base.

## Medições de recursos

O PNG usa buffer de uma linha e codifica uma vez, evitando RGBA completo e dupla codificação. Geometria/stride/bpp/máscaras/limites de alocação do XImage são validados. Antes da residência, a conexão X11 da captura é fechada, traços são liberados e páginas livres da arena glibc são devolvidas com um malloc_trim(0), sem alterar parâmetros globais do alocador. Clipboard nativo retém só PNG comprimido, bloqueia por eventos X11 até substituição/expiração de 30 minutos e limita INCR a 16 transferências. Buffers de captura são liberados antes da espera. Sem posse do clipboard não sobra processo Print RC; Python de configuração não permanece rodando. O supervisor encerra após etapa de posse, deixando um proprietário nativo.

O benchmark de desenvolvimento no mesmo host usou Ubuntu 24.04/glibc 2.39, Xvfb de profundidade 24 por TCP loopback, pixels brancos, cinco capturas por build/resolução e binários nativos diretos. O v0.5.6 estático distribuído conseguiu executar nesse host. O checkpoint dinâmico medido antecedeu a última atualização só de catálogos; os JSON brutos identificam cada hash. Não é medição de máquina Q4OS/Zorin nem de todos os ZIPs finais. Os três pares ficam em `compat/test-results/development-performance/`.

| Resolução | Estático original mediana / p95 ms | Dinâmico PNG por linhas mediana / p95 ms | CPU mediana original → dinâmico segundos | Pico RSS original → dinâmico KiB |
| --- | --- | --- | --- | --- |
| 1366×768 | 199,9 / 299,1 | 97,6 / 148,3 | 0,1559 → 0,0639 | 13824 → 13824 |
| 1920×1080 | 385,5 / 748,5 | 159,5 / 306,2 | 0,3425 → 0,1085 | 20484 → 19036 |
| 3840×2160 | 1485,5 / 2452,7 | 623,6 / 876,4 | 1,4548 → 0,5654 | 69104 → 67648 |

Com cinco amostras, p95 é o maior valor observado; tempo de parede sofre variação no ambiente compartilhado. Coortes preliminares também tiveram grandes outliers. PSS local, RSS/PSS residual do clipboard e ticks ociosos são null por falta de acesso ao /proc dos filhos, nunca zero. CPU/RSS acima vêm de wait4. Cobrem núcleo da captura, excluindo supervisor transitório e X server. Compressão nível 3 troca explicitamente PNG maior por menor CPU/latência (no cenário branco 4K CI, 150.581 contra 37.549 bytes da fonte antiga dinâmica); pixels continuam sem perdas. O cenário tem baixa entropia; tamanhos PNG e amostras completas foram mantidos. A etapa de recursos CI compara candidato exato com fonte v0.5.6 inalterada recompilada dinamicamente no mesmo Ubuntu 22.04/glibc 2.35, pois o estático distribuído falha ali. Identidade/limites das duas referências devem continuar explícitos. Aceitação real em Q4OS/Zorin/laptop/dois monitores e regressões ≤20% nesses hosts continuam pendentes.

## Aceitação pendente e riscos

Mantenha PR como draft e issue #1 aberta até Zorin 17.3 XFCE/glibc 2.35 e Q4OS/Trinity reais testarem o **mesmo arquivo pretendido para lançamento**: instalação, Insert/Print físicos, tela escurecida/barra visível, área/tela inteira, caneta/desfazer, Escape, PNG, Ctrl+V/INCR, recuperação da tecla, movimentação e desinstalação segura. Anexe versões SO/desktop/bibliotecas ocultando dados pessoais, hashes binário/build/pacote, logs e cinco repetições de latência/CPU/RSS/PSS. Teste resoluções pedidas no Intel de baixo consumo, 4K e dois monitores. Evidência de outro pacote não libera lançamento.

Ligação dinâmica exige bibliotecas compatíveis do host; dependências ausentes devem ser resolvidas pelo usuário/distribuição, sem mutação automática do sistema. Visuais/tamanhos inesperados são recusados. Edição externa pode bloquear restauração automática; backups ficam para recuperação. Rótulos portugueses de fonte fixa exigem confirmação visual no desktop real. Wayland/portal, ARM64 e Alpine são trabalho futuro, sem fallback oculto.

## Inventário de arquivos alterados

A = adicionado, M = modificado, D = retirado deste branch. Assets v0.5.6 foram preservados. Evidências são material de revisão do repositório e ficam fora dos ZIPs de execução para evitar hashes circulares e tamanho desnecessário.

| Alteração | Arquivo | Finalidade |
| --- | --- | --- |
| A | `.github/workflows/build.yml` | Compila candidato GNU no Ubuntu 20.04; audita ABI e envia ZIP com checksum. |
| A | `.github/workflows/release.yml` | Publicação por tag explícita após testes do pacote e evidência separada de hosts; recusa sobrescrever assets. |
| A | `.github/workflows/test.yml` | Testa ZIP exato em três ambientes libc; serviços XFCE reais, comparação GDB e medições de recursos. |
| M | `.github/workflows/testar.yml` | Coordena compilação/teste com permissões de leitura; sem commit automático de binário ou publicação. |
| M | `.gitignore` | Ignora binários gerados, compilações, logs e estado do usuário. |
| A | `CHANGELOG.md` | Resumo em inglês das mudanças por fase e limites de aceitação. |
| A | `CHANGELOG.pt-BR.md` | Histórico equivalente em português brasileiro. |
| M | `Makefile` | Alvos padrão/portátil dinâmicos, validação de idiomas e debug; compila supervisor nativo. |
| M | `README.md` | Entrada em inglês com status real do candidato, instruções e links da documentação. |
| A | `README.pt-BR.md` | Entrada equivalente em português brasileiro com instruções de uso. |
| A | `VERSION` | Identifica 0.6.0-dev como candidato não lançado. |
| D | `bin/print-rc` | Retira binário legado gerado do branch de código; tag/assets originais permanecem intactos. |
| A | `compat/linux-targets.json` | Registra evidência e status por alvo sem alegar compatibilidade universal. |
| A | `compat/test-results/ci-39695994801/Print-RC-linux-x86_64-glibc.zip.sha256` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/binary-sha256.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/build-manifest.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/evidence-index.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/legacy-build-id.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/legacy-gdb.log` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/legacy-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/libc.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/original-dynamic-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/os-release.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/shortcut-proof.log` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39695994801/xfce-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/Print-RC-linux-x86_64-glibc.zip.sha256` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/binary-sha256.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/build-manifest.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/evidence-index.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/legacy-build-id.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/legacy-gdb.log` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/legacy-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/libc.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/original-dynamic-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/os-release.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-candidate-1366x768.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-candidate-1920x1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-candidate-3840x2160.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-1366x768.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-1920x1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-3840x2160.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/performance.log` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/shortcut-proof.log` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/ci-39697099560/xfce-result.txt` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/dynamic-1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/dynamic-2160.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/dynamic-768.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/evidence-index.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/perf-post-1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/perf-pre-1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/perf-static-1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/static-1080.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/static-2160.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| A | `compat/test-results/development-performance/static-768.json` | Evidência de teste preservada com hashes; excluída dos pacotes de execução. |
| M | `configurar-tecla.sh` | Preserva seleção de teclas e independência Print/Insert; oferece reparo de caminhos após movimentação. |
| M | `configurar.sh` | Persiste idioma e destino interno relativo de imagens; registra preferências geradas com segurança. |
| M | `desinstalar.sh` | Valida inventário, preserva arquivos alterados/desconhecidos e restaura apenas integração ainda própria; evita resíduos de bytecode. |
| A | `diagnosticar.sh` | Wrapper público para diagnóstico de observação e gravação de relatório explícita. |
| A | `docs/en-US/COMPATIBILITY.md` | Distinção ABI/execução/desktop e plataformas não testadas. |
| A | `docs/en-US/DEVELOPMENT.md` | Procedimentos de compilação, idiomas, regressões, empacotamento e lançamento. |
| A | `docs/en-US/IMPLEMENTATION.md` | Este relatório por fases, inventário de arquivos, evidências, medições e aceitação pendente. |
| A | `docs/en-US/INSTALL.md` | Instalação/extração/dependências e declaração de atalhos. |
| A | `docs/en-US/PRIVACY.md` | Estado local, ocultação de dados no relatório, referências externas e ausência de telemetria. |
| A | `docs/en-US/RELEASE.md` | Modelo de resumo de lançamento com bloqueios de aceitação em hosts reais. |
| A | `docs/en-US/TROUBLESHOOTING.md` | Diagnóstico, limites da evidência, erros estáveis e recuperação segura. |
| A | `docs/en-US/UNINSTALL.md` | Prévia, posse, preservação de dados e limites de limpeza. |
| A | `docs/en-US/USER_GUIDE.md` | Uso de captura/caneta/desfazer/clipboard/teclas/idioma. |
| A | `docs/pt-BR/COMPATIBILITY.md` | Distinção ABI/execução/desktop e plataformas não testadas. |
| A | `docs/pt-BR/DEVELOPMENT.md` | Procedimentos de compilação, idiomas, regressões, empacotamento e lançamento. |
| A | `docs/pt-BR/IMPLEMENTATION.md` | Este relatório por fases, inventário de arquivos, evidências, medições e aceitação pendente. |
| A | `docs/pt-BR/INSTALL.md` | Instalação/extração/dependências e declaração de atalhos. |
| A | `docs/pt-BR/PRIVACY.md` | Estado local, ocultação de dados no relatório, referências externas e ausência de telemetria. |
| A | `docs/pt-BR/RELEASE.md` | Modelo de resumo de lançamento com bloqueios de aceitação em hosts reais. |
| A | `docs/pt-BR/TROUBLESHOOTING.md` | Diagnóstico, limites da evidência, erros estáveis e recuperação segura. |
| A | `docs/pt-BR/UNINSTALL.md` | Prévia, posse, preservação de dados e limites de limpeza. |
| A | `docs/pt-BR/USER_GUIDE.md` | Uso de captura/caneta/desfazer/clipboard/teclas/idioma. |
| A | `i18n/README.md` | Documenta catálogos, precedência e validações de regeneração. |
| A | `i18n/en-US.json` | 613 mensagens de referência em inglês, incluindo CLI/interface/instalação/erros/diagnóstico. |
| A | `i18n/pt-BR.json` | 613 traduções correspondentes em português brasileiro com paridade de placeholders. |
| M | `iniciar.sh` | Valida alvo/sessão/configuração, usa supervisor de sinais e prova de interface desenhada com nonce. |
| M | `instalar.sh` | Mantém ou move pasta única, declara integração, registra arquivos e mantém ativação pendente até prova. |
| A | `packaging/portable/package.py` | ZIP determinístico com uma pasta, hashes dos binários auditados, índice e metadados de execução. |
| M | `scripts/atalho.py` | Preserva esquema Trinity/recuperação legada; tradução, posse, proteção contra concorrência e diário de movimentação. |
| M | `scripts/atalho_xfce.py` | Preserva atalhos custom/default XFCE; compara antes de alterar, registra originais e traduz auxiliar. |
| A | `scripts/build/locales.py` | Valida catálogos completos, duplicatas/placeholders/formatos e tabelas C++/Bash geradas. |
| A | `scripts/build/manifest.py` | Registra fonte/compilador/libc/dependências ELF, build IDs, versões de símbolos, tamanhos e hashes; impõe teto ABI. |
| A | `scripts/build/release_gate.py` | Recusa evidência ausente/incorreta de pacote/desktop/desempenho, libc estática, ABI nova e caminhos inseguros. |
| A | `scripts/diagnose.py` | Observa/oculta dados de SO, sessão, ELF, configuração e atalhos; sem executar binário ou ativar serviços. |
| A | `scripts/i18n.sh` | Seleciona idioma e formata valores como dados, sem eval. |
| M | `scripts/inventario.sh` | Lista fixa de arquivos do app, hashes esperados do pacote e atualização segura de preferências geradas. |
| A | `scripts/lifecycle.py` | Valida caminhos/índices próprios; grava atomicamente estado real da instalação e referências externas. |
| A | `scripts/messages.bash` | Catálogo Bash bilíngue gerado com escape de dados. |
| A | `scripts/print_rc_i18n.py` | Seleção de idioma, traduções e ajuda argparse compartilhadas pelos auxiliares. |
| M | `scripts/provar-atalho.sh` | Arma token exclusivo e aceita só prova correspondente de interface/entrada pronta; limpeza segura do token. |
| A | `scripts/relocate.py` | Repara caminhos registrados após movimentação; preserva alterações de terceiros e registra interrupções. |
| A | `src/app/launcher.cpp` | Pequeno processo supervisor de sinais; propaga status e termina quando clipboard assume PNG. |
| A | `src/app/runtime.hpp` | Canal opcional de status herdado com etapas X11/interface/gravação/clipboard. |
| A | `src/clipboard/owner.hpp` | Proprietário de PNG comprimido por eventos; INCR limitado, verificação de tamanho, limpeza por substituição/expiração. |
| A | `src/config/settings.hpp` | Valida preferências e resolve destino relativo portátil sem travessia/links inseguros. |
| A | `src/i18n/generated.hpp` | Tabela nativa bilíngue gerada e incorporada. |
| A | `src/i18n/messages.hpp` | Precedência de idioma nativa e conversão de rótulos para fonte fixa X11 sem framework gráfico. |
| A | `src/images/png.hpp` | Codificação PNG única por linhas, buffer de uma linha, máscaras visuais e tratamento seguro de alocação/erros. |
| A | `src/input/keyboard.hpp` | Extrai detecção de teclas e verifica tecla selecionada preservando distinção física Print/Insert. |
| M | `src/main.cpp` | Mantém interface nativa; valida XImage/geometria, comprova mapeamento/desenho/entrada e separa disco/clipboard. |
| M | `src/settings.hpp` | Mantém include compatível apontando para módulo organizado de configuração. |
| A | `src/ui/drawing.hpp` | Extrai desenho de caneta/anotações preservando desfazer. |
| A | `src/ui/geometry.hpp` | Extrai retângulos/traços e auxiliares de geometria. |
| A | `tests/performance/README.md` | Comandos reproduzíveis de medição, limites da referência e interpretação das métricas. |
| A | `tests/performance/benchmark.py` | Mede cinco repetições, tempo/CPU/RSS/PSS/clipboard e registra hashes/limites do ambiente. |
| A | `tests/performance/compare.py` | Impõe limites de regressão de CPU/p95/PSS e memória ociosa do clipboard usando coortes medidas. |
| A | `tests/performance/x11_driver.cpp` | Pintura, detecção real de interface, entrada tela inteira/cancelamento e dimensões só para testes explícitos. |
| A | `tests/run.sh` | Executa validações de sintaxe/Python/Bash/C++ e regressões Xvfb do pacote como usuário comum. |
| M | `tests/test_atalho.py` | Preserva regressões unitárias Trinity após mudanças de módulo/idioma. |
| A | `tests/test_clipboard_limits.cpp` | Exercita 16 transferências INCR, recusa de excesso e recuperação após cliente destruído. |
| A | `tests/test_clipboard_limits_x11.sh` | Compila/executa regressão INCR limitado em X11 real. |
| M | `tests/test_clipboard_x11.sh` | Preserva INCR idêntico e testa falha de gravação mais substituição do proprietário. |
| M | `tests/test_configuracao.sh` | Confere destino interno relativo e invariantes existentes de preferências. |
| M | `tests/test_configurar_tecla.sh` | Mantém regressões originais de configuração de tecla com idioma isolado. |
| M | `tests/test_desinstalacao.sh` | Mantém regressões de desinstalação preservando dados com idioma isolado. |
| M | `tests/test_desinstalacao_processo_x11.sh` | Verifica limpeza de processo/preservação de dados após captura X11 real. |
| M | `tests/test_detectar_print_x11.sh` | Preserva detecção física e verifica F12 selecionada independente de Print. |
| M | `tests/test_gui_x11.sh` | Mantém regressão original de área/tela inteira/caneta/cancelamento/instância única. |
| M | `tests/test_instalacao.sh` | Mantém testes de instalação sem root em pasta única e conflitos de atualização. |
| A | `tests/test_language_setup.sh` | Exercita instalação/desinstalação em inglês, português persistido e override explícito de idioma. |
| A | `tests/test_launcher.sh` | Injeta SIGFPE/SIGSEGV controlados, verifica 128+sinal e relato da etapa da interface. |
| A | `tests/test_lifecycle.py` | Testa estado real, movimentação/diários/concorrência, links e diagnóstico apenas de observação. |
| A | `tests/test_localization.py` | Testa paridade de catálogos/idioma/docs, substituições literais, ajuda nativa e ausência de bytecode dos auxiliares. |
| A | `tests/test_overlay_ready.cpp` | Valida pixels escurecidos mapeados, duas reservas de entrada, idioma, prova nonce e limpeza. |
| A | `tests/test_packaged_ownership.sh` | Preserva arquivos alterados antes da instalação, capturas desconhecidas e movimentação interrompida na remoção. |
| M | `tests/test_prova_atalho.sh` | Distingue resposta de processo iniciado de confirmação de interface desenhada/token concorrente. |
| A | `tests/test_release_gate.py` | Recusa libc estática/ABI nova/dev/hash incorreto/Xvfb/NaN/caminho externo; valida fixture completa. |
| M | `tests/test_settings.cpp` | Valida destino relativo, preferências absolutas antigas, limites e travessia insegura. |
| A | `tests/test_undo_x11.sh` | Verifica alteração de pixels pela caneta e restauração exata ao desfazer. |
| A | `tests/test_visual_png.sh` | Confere RGBA branco exato em dimensão ímpar 301×173 e visuais de profundidade 16/24. |
| M | `tests/test_xfce_integracao.sh` | Mantém regressões de integração XFCE simulada e prova de interface correspondente. |
| A | `tests/test_xfce_real.sh` | Executa Insert/gravação/restauração com xfsettingsd real preservando Print; compara original estático/dinâmico via GDB. |
