# Solução de problemas

Execute `bash diagnosticar.sh --read-only`. Ele observa sistema/sessão, metadados ELF, configuração e atalhos registrados sem iniciar captura, reservar teclas, criar relatórios ou mudar preferências. A saída oculta dados pessoais por padrão. Salvar exige `--output /destino/relatorio.json` explícito e recusa arquivos existentes.

SIGFPE é o sinal 8; o código 136 corresponde a 128+8. A evidência da v0.5.6 no Zorin comprova uma exceção de divisão inteira na glibc do sistema, no deslocamento 0x175c79. A interação entre glibc estática e módulos/TLS carregados do sistema continua sendo hipótese. É preciso testar o ambiente real e o pacote candidato. Autoteste PNG ou PID não comprovam uma interface visível.

O inicializador nativo informa sinais fatais e se a prova de interface desenhada foi emitida. O proprietário do clipboard pode permanecer depois dele. A prova do atalho exige a instância correspondente, interface visível/desenhada e os dois controles de entrada. Uma falha deixa a ativação pendente.

Para CONFIG_MISSING/CONFIG_INVALID, execute `bash configurar.sh`. UNSUPPORTED_DISPLAY exige X11; não há backend Wayland. INSTANCE_BUSY indica uma captura ativa a concluir/cancelar. POINTER_GRAB_FAILED/KEYBOARD_GRAB_FAILED preservam a reserva de outro programa; tente depois que ele liberar. PNG_SAVE_FAILED preserva a possibilidade de colar quando o clipboard está ligado.

A integração Trinity pede que `khotkeysd` releia a configuração. Se a ativação continuar pendente, consulte o gerenciador de serviços ou saia e entre na sessão. Nenhum processo do desktop é encerrado. Atalhos alterados por terceiros bloqueiam a restauração. Preserve `backups/` e `config/` para recuperação.

Depurador e despejos de falha são ações opcionais de desenvolvimento. O app não instala depurador, não ativa despejos e não envia logs. Oculte caminhos pessoais antes de publicar evidências adicionais.

## A instalação não abre ou parece sumir

- Confira `VERSION`: 0.5.6 é a release antiga. O ZIP de código da main não tem binários. Use o pacote **Print-RC-Linux-x86_64.zip** da execução candidata desejada, cujo manifesto identifica a fonte.
- Abra **Instalar** ou **Instalar.desktop / Instalar (terminal)**. Se o desktop pedir autorização de execução, autorize apenas esse arquivo. Não é preciso digitar o caminho em um terminal.
- Permissão negada: confira a permissão de executar e extraia em uma pasta Linux gravável que permita execução. O app não muda configurações de montagem.
- `error while loading shared libraries`, `GLIBCXX ... not found` ou carregador ausente: falta dependência/ABI compatível. Este ZIP não embute bibliotecas; não substitua a libc do sistema. Envie a mensagem exata e o diagnóstico somente leitura para identificar a dependência.
- Wayland/ARM/musl/32 bits: esta edição não atende. Veja a [matriz](COMPATIBILITY.md).
- Falha antes de iniciar a captura pode aparecer em diálogo, quando zenity/kdialog/xmessage já existe; pelo instalador, o resultado fica visível até Enter. Sem esses diálogos, use a saída do terminal para obter o erro.

[Auditoria e testes](AUDIT.md). O erro do notebook real continua necessário para atribuir a causa exata.
