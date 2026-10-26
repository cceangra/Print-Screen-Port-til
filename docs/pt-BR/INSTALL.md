# Instalação

Baixe o ZIP candidato de uma execução aprovada no Actions ou de uma versão publicada e validada, confira seu SHA-256 e extraia a única pasta `Print-RC`. O Download ZIP dos fontes exige compilação por um desenvolvedor. Dê duplo clique em **Instalar** (ou **Instalar.desktop / Instalar (terminal)**) como usuário normal. O terminal abre automaticamente, sem digitar caminhos. `bash instalar.sh` permanece como alternativa. Mantenha a pasta extraída ou confirme sua movimentação para um destino exclusivo. Arquivos existentes em conflito interrompem a operação e permanecem intactos.

Escolha o destino PNG e a preferência do clipboard. Pastas de imagens externas são informadas e preservadas na desinstalação. Escolha uma tecla individual X11 e confirme uma vez para substituir conflitos reconhecidos. Letras, Enter e espaço podem atrapalhar a digitação. Escape e modificadores isolados não são aceitos. Print e Insert permanecem separados.

Em um terminal X11 interativo, a prova de atalho desenha brevemente a interface, obtém os controles de mouse e teclado e fecha sem salvar. Sem a prova, a ativação fica pendente. A configuração dos arquivos não certifica que a interface está pronta.

Há adaptadores automáticos para Trinity/KHotKeys e Xfce/xfconf-query. Outros desktops exigem atalho manual para `/bin/bash '/caminho/absoluto/Print-RC/iniciar.sh'`. Atalhos manuais precisam ser removidos manualmente. É necessário testar o desktop real antes de afirmar que um adaptador funciona nele.

O pacote GNU precisa de carregador, glibc, libstdc++, libX11 e libpng16 compatíveis do sistema; auxiliares usam Bash e Python 3. O app não baixa ou instala dependências, não substitui glibc, não chama sudo e não inicia atualizador.

[Executável nativo e instalação simples no terminal](QUICK_START.md). Abra `Print-RC` para capturar; `Print-RC --install` e `Print-RC --uninstall` usam o terminal. A pasta pai do destino deve existir.

[Auditoria das falhas e correções](AUDIT.md). O pacote não embute bibliotecas. A edição atual exige GNU/Linux x86_64/glibc/X11, Bash e Python 3.8+; veja a [matriz](COMPATIBILITY.md).
