# Print RC

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

Capturador de tela e anotação leve, escrito em C++17 nativo para Linux **X11**. Selecione uma área, capture a tela inteira com um clique, desenhe com o lápis, desfaça, salve PNG e, opcionalmente, cole com Ctrl+V. O desktop gerencia os atalhos; o Print RC não mantém um leitor de teclado residente.

## Situação da versão candidata

A `0.6.0-dev` substitui a compilação GNU totalmente estática por uma compilação dinâmica. Isso trata uma hipótese de empacotamento ligada ao **SIGFPE da v0.5.6 no Zorin OS 17.3 Lite/XFCE/glibc 2.35**. **O reparo nesse desktop ainda não foi verificado.** A validação no Q4OS/Trinity também continua obrigatória. Acompanhe a [issue #1](https://github.com/cceangra/Print-Screen-Port-til/issues/1).

O [catálogo de compatibilidade](compat/linux-targets.json) lista alvos de teste, inclusive distribuições não testadas. Testes com Xvfb verificam o núcleo X11 e a ABI; não certificam o desktop instalado. Wayland, ARM64 e musl/Alpine ainda não têm implementações ou pacotes anunciados como compatíveis.

## Baixar e executar

Use um **artefato candidato de uma execução aprovada no Actions**, ou uma futura versão publicada após passar pela validação dos desktops. A opção **Download ZIP** do código do GitHub contém fontes e não contém executável pronto. O binário e a publicação antigos da v0.5.6 permanecem nos arquivos e na tag originais para investigação.

Extraia o ZIP do aplicativo: haverá uma única pasta `Print-RC`. Execute `instalar.sh` como usuário normal. O instalador mantém a pasta extraída ou a move para um destino escolhido por você. Não instala pacotes, não usa sudo, não baixa dependências e não inicia atualizador.

```bash
bash instalar.sh
bash iniciar.sh
```

O pacote GNU atual precisa do carregador dinâmico e de versões compatíveis de glibc, libstdc++, libX11 e libpng16 do sistema. Python 3 serve aos auxiliares de configuração/atalhos, sem permanecer durante a captura. A compilação principal impõe teto de símbolos GLIBC ≤ 2.31 / GLIBCXX ≤ 3.4.28; cada pacote traz seus metadados exatos.

## Configurações e idioma

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
