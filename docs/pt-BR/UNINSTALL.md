# Desinstalação

Execute `bash desinstalar.sh`, confira a pasta, o destino de imagens, as integrações registradas e o aviso sobre clipboard; depois digite `DESINSTALAR` (também é aceito `UNINSTALL`).

O aplicativo restaura apenas associações cujo estado atual ainda corresponde ao seu registro de propriedade. O Xfce usa a propriedade exata registrada, sem confundir Insert com Print. O Trinity preserva grupos não relacionados e comandos modificados. Estados ambíguos ou interrompidos ficam preservados para recuperação; nenhum backup antigo substitui toda a configuração do desktop.

Só são apagados arquivos conhecidos do aplicativo que correspondem aos hashes da instalação. Capturas, PNG/JPG fora dessa lista, arquivos desconhecidos, arquivos do app modificados e links inesperados são preservados. Apenas pastas conhecidas vazias são removidas. Pastas externas de imagens e o ZIP original permanecem. Nenhuma pasta do usuário é apagada recursivamente.

O desinstalador pode encerrar processos cujo `/proc/PID/exe` identifique este executável e usuário exatos. Isso invalida sua imagem no clipboard. Outra cópia e programas não relacionados são preservados. Quando a restauração segura é impossível, ele interrompe e informa o que permaneceu.
