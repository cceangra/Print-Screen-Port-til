# Desenvolvimento e validação

Use um ambiente controlado de desenvolvimento com C++17, make, pkg-config, cabeçalhos X11/libpng, binutils e Python 3. `make -B all` compila dinamicamente; `make debug` acrescenta símbolos e quadros de pilha. `make portable` remove símbolos dos binários dinâmicos. Não vincula glibc estática. Os scripts do aplicativo não instalam ferramentas no computador do usuário.

`python3 scripts/build/locales.py --check` rejeita chaves duplicadas/ausentes/vazias, diferenças de parâmetros, formatos inseguros e tabelas geradas desatualizadas. Edite os dois catálogos JSON e execute o gerador. Mensagens nativas ficam embutidas; a configuração Bash usa dados gerados protegidos por aspas; auxiliares Python são temporários.

Os fontes estão separados em ciclo de vida, configuração, codificação de imagens, geometria/desenho, detecção de teclas, clipboard e idiomas. Os nomes públicos de scripts em português e formatos originais de estado de atalhos foram preservados.

Em uma máquina X11 isolada de testes, sem root, execute `bash tests/run.sh`. Há regressões originais, adaptadores simulados, área/tela/desenho/clipboard/INCR reais no Xvfb, interface visível/escurecida em profundidades 16/24, disputa de reservas, sinais simulados e desinstalação segura. Diagnóstico somente leitura nunca envia entradas sintéticas. Uma tela de profundidade 24 normalmente usa armazenamento de 32 bits por pixel; Xvfb pode não oferecer profundidade raiz 32.

Auditoria: `python3 scripts/build/manifest.py --output dist/build-manifest.json`. Pacote: `python3 packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-Linux-x86_64.zip`. Compilações locais acima do teto ABI falham; uma auditoria relaxada localmente não comprova uma versão portátil. Tags, compilador/linker, IDs, dependências, símbolos e hashes acompanham os candidatos.

Publicar exige tag existente explícita, regressões do pacote aprovadas e evidências separadas de desktop/desempenho para o hash exato. Arquivos publicados não são sobrescritos, o CI normal só tem leitura do repositório e nenhum binário é regravado na main. ARM/musl/Wayland exigem trilhas verificadas separadamente.

## Registrar aceitação de lançamento

O candidato continua `0.6.0-dev` e não pode publicar. Em lançamento futuro revisado, ajuste VERSION, faça commit da fonte final, crie tag explícita `v<VERSION>` correspondente e compile o candidato. Teste esse ZIP exato antes de disparar publicação. Guarde registros de aceitação em commit/ref separado para adicionar evidência sem alterar tag/hash do código/pacote. A entrada `evidence_ref` seleciona essa referência; a tag continua sendo o código compilado. Se a recompilação mudar o ZIP, teste o novo arquivo em vez de trocar o hash na evidência antiga.

Exige-se `compat/test-results/<target-id>.json` para cada alvo de `scripts/build/release_gate.py`: Zorin 17.3 XFCE/glibc 2.35, Q4OS/Trinity, Ubuntu 20.04 X11 e base de compilação Ubuntu 20.04. Cada registro precisa conter:

- `target`, `archive_sha256`, `git_commit`, `tested_at` e `test_kind` (`physical-desktop` ou `virtual-machine-desktop` para Zorin/Q4OS).
- `environment` medido: `os_release`, `architecture`, `protocol`, `desktop`, `libc`, `libc_version` e `libX11`. Host mais novo ou Xvfb não pode ser renomeado para o desktop/base exigido.
- `checks` booleanos para cada nome de `release_gate.CHECKS`. Só testes observados aprovados podem ser true; anexe interface mapeada/escurecida, captura/clipboard, teclado, restauração e desinstalação.
- `performance` numérico finito e positivo: `repetitions` (pelo menos cinco), `latency_median_ms`, `latency_p95_ms`, `peak_rss_kib`, `peak_pss_kib`, `cpu_seconds`, `baseline_peak_pss_kib`, `baseline_latency_p95_ms`. Regressão de PSS/p95 >20% exige `regression_justification` concreta, amostras brutas e análise do revisor. Inclua resoluções pedidas, memória/ociosidade do clipboard e hardware nos logs/relatório anexos.
- `evidence_files`: objetos com `path` relativo seguro e `sha256` correspondente. Arquivos devem resolver dentro da pasta de evidência. Oculte dados pessoais de logs/imagens e identifique builds de referência. Coortes de desenvolvimento versionadas exemplificam medições, sem valer como aceitação de lançamento.

Execute localmente `python3 -B scripts/build/release_gate.py --archive <exato.zip> --manifest <build-manifest.json> --evidence-dir <acceptance/compat/test-results>`, depois dispare workflow de publicação com `tag` e `evidence_ref`. Publicação também exige fonte limpa sem dev, base ABI dinâmica e todos os jobs do pacote. Releases/assets existentes não são sobrescritos. Passar um esquema JSON não substitui executar e revisar evidência dos hosts reais.

A compilação confere que dois ZIPs de entrada auditada idêntica tenham os mesmos bytes e que todos os fontes correspondentes versionados estejam presentes, exceto evidências `compat/test-results/` excluídas intencionalmente. CI de desempenho usa `tests/performance/compare.py` em coortes fonte-original-dinâmica/candidato no mesmo host; verifica regressões de CPU/p95/PSS, ausência de processo de captura residual e PSS do clipboard limitado a 8 MiB mais duas vezes bytes PNG comprimidos. É um cenário branco Xvfb isolado, sem definir limite de hardware para toda imagem ou máquina.
