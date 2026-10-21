# Message catalogs / Catálogos de mensagens

Edit en-US.json and pt-BR.json together. IDs and stored schemas are language independent. Preserve positional placeholders and printf specifiers exactly. Never put executable shell syntax in message lookups. Run `python3 scripts/build/locales.py` and commit both generated tables. CI uses `--check`; missing, duplicate, blank or inconsistent translations fail the build. Native capture embeds only its required tables and does not load JSON/Python.

Edite en-US.json e pt-BR.json juntos. IDs e formatos de dados independem do idioma. Preserve exatamente parâmetros posicionais e formatos printf. Não execute mensagens como comandos do shell. Execute `python3 scripts/build/locales.py` e inclua as duas tabelas geradas no commit. O CI usa `--check`; traduções ausentes, duplicadas, vazias ou inconsistentes causam falha. A captura nativa embute apenas as tabelas necessárias, sem carregar JSON/Python.
