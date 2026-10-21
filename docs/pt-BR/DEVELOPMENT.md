# Desenvolvimento e validação

Use um ambiente controlado de desenvolvimento com C++17, make, pkg-config, cabeçalhos X11/libpng, binutils e Python 3. `make -B all` compila dinamicamente; `make debug` acrescenta símbolos e quadros de pilha. `make portable` remove símbolos dos binários dinâmicos. Não vincula glibc estática. Os scripts do aplicativo não instalam ferramentas no computador do usuário.

`python3 scripts/build/locales.py --check` rejeita chaves duplicadas/ausentes/vazias, diferenças de parâmetros, formatos inseguros e tabelas geradas desatualizadas. Edite os dois catálogos JSON e execute o gerador. Mensagens nativas ficam embutidas; a configuração Bash usa dados gerados protegidos por aspas; auxiliares Python são temporários.

Os fontes estão separados em ciclo de vida, configuração, codificação de imagens, geometria/desenho, detecção de teclas, clipboard e idiomas. Os nomes públicos de scripts em português e formatos originais de estado de atalhos foram preservados.

Em uma máquina X11 isolada de testes, sem root, execute `bash tests/run.sh`. Há regressões originais, adaptadores simulados, área/tela/desenho/clipboard/INCR reais no Xvfb, interface visível/escurecida em profundidades 16/24, disputa de reservas, sinais simulados e desinstalação segura. Diagnóstico somente leitura nunca envia entradas sintéticas. Uma tela de profundidade 24 normalmente usa armazenamento de 32 bits por pixel; Xvfb pode não oferecer profundidade raiz 32.

Auditoria: `python3 scripts/build/manifest.py --output dist/build-manifest.json`. Pacote: `python3 packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-linux-x86_64-glibc.zip`. Compilações locais acima do teto ABI falham; uma auditoria relaxada localmente não comprova uma versão portátil. Tags, compilador/linker, IDs, dependências, símbolos e hashes acompanham os candidatos.

Publicar exige tag existente explícita, regressões do pacote aprovadas e evidências separadas de desktop/desempenho para o hash exato. Arquivos publicados não são sobrescritos, o CI normal só tem leitura do repositório e nenhum binário é regravado na main. ARM/musl/Wayland exigem trilhas verificadas separadamente.
