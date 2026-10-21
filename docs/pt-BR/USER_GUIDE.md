# Guia de uso

Execute `bash iniciar.sh` ou pressione a tecla cadastrada. Arraste uma área para salvar. TELA captura a tela raiz inteira com um clique. LÁPIS desenha traços azuis; DESF remove o último traço. Volte para ÁREA para capturar uma região com o desenho. SAIR, Escape ou clique direito cancela sem salvar. Somente uma interface de seleção pode ficar ativa por vez.

Use `bash configurar.sh` para a pasta de imagens e a preferência do clipboard. Os nomes PNG são exclusivos e nunca sobrescrevem capturas. Os arquivos usam permissões privadas. Uma falha de gravação é informada e a captura ainda pode ser colada quando o clipboard está ligado.

O proprietário do clipboard X11 guarda apenas o PNG comprimido, expira após 30 minutos e encerra quando outro programa assume. Com clipboard desligado, capturar ou cancelar não deixa processo do Print RC. Não existe leitor de teclado residente.

Escolha o idioma com `bash configurar.sh --language pt-BR` ou `--language en-US`. `PRINT_RC_LANG` permite uma escolha temporária. Idiomas desconhecidos usam inglês. Nomes de opções, caminhos, formato da configuração e códigos para leitura automática permanecem estáveis.

`bash configurar-tecla.sh` consulta, configura, libera ou verifica atalhos. Sua sonda de reserva X11 é interativa e tenta uma reserva breve. Use `diagnosticar.sh --read-only` para observar sem reservas. Depois de mover uma pasta instalada, repare ou recadastre a integração explicitamente; pastas externas de imagens continuam pertencendo ao usuário.
