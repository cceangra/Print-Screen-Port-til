# Começar pelo executável

Baixe o **pacote binário candidato** de uma execução Actions aprovada e extraia o ZIP interno. O pacote contém uma única pasta `Print-RC/`; o executável **`Print-RC` fica na raiz**, e os componentes nativos ficam em `bin/`. O Download ZIP dos fontes precisa de compilação.

Para instalar pelo terminal, abra a pasta extraída no terminal e execute:

```bash
./Print-RC --install
# A entrada antiga também continua disponível:
bash instalar.sh
```

Escolha manter a pasta ou movê-la. A pasta pai do destino deve existir: o instalador não cria pastas externas sem registro. Se o ZIP perder permissão de execução, use `bash instalar.sh`, que restaura a permissão do executável presente no pacote. Não execute como root. O aplicativo não instala dependências.

Depois, abra **Print-RC** pelo gerenciador de arquivos ou execute `./Print-RC`. No primeiro uso sem configuração, ele tenta abrir a instalação em um terminal disponível. Quando um terminal novo é usado, ele aguarda Enter ao terminar para manter erros e instruções visíveis.

| Ação | Comando |
| --- | --- |
| Capturar | `./Print-RC` |
| Preferências/idioma | `./Print-RC --configure` |
| Escolher, verificar ou liberar tecla | `./Print-RC --shortcut` |
| Diagnóstico somente leitura | `./Print-RC --diagnose --read-only` |
| Desinstalar com prévia | `./Print-RC --uninstall` |

Escolha uma tecla física reconhecida pelo X11. Print e Insert são independentes. Escape e modificadores sozinhos são reservados. Letras, Enter e espaço podem prejudicar a digitação se usados globalmente. Uma tecla pode estar ocupada pelo desktop ou por outro programa; o aplicativo não pode garanti-la em toda sessão. Se o cadastro/prova falhar, desative o conflito no gerenciador de atalhos e execute `bash configurar-tecla.sh` para verificar ou escolher outra tecla. Sem prova de interface, a ativação permanece pendente.

A captura usa X11 e bibliotecas do sistema compatíveis, em GNU/Linux x86_64. Ela não depende do nome da distribuição. Trinity e XFCE têm adaptadores automáticos; outros desktops X11 recebem instruções para atalho manual. Um atalho criado manualmente pelo usuário deve ser removido manualmente. Wayland, ARM64 e musl exigem edições próprias e continuam sem suporte anunciado neste pacote. O catálogo de distribuições diferencia testes realizados de alvos futuros.

O registro `config/installation-manifest.json` declara os recursos externos e os arquivos de registro conhecidos: `khotkeysrc` no Trinity ou o arquivo de sessão padrão do canal XFCE, junto com a propriedade exata alterada. O XFCE mantém esse arquivo pelo seu próprio serviço; a remoção desfaz somente a propriedade registrada, sem apagar a configuração inteira. Estados e backups criados ao reconfigurar também entram no inventário. Uma operação interrompida com estado externo preparado mantém recibo de propriedade e instrução de desinstalação, sem alegar ativação concluída.

Na desinstalação, confira a prévia e digite `DESINSTALAR` ou `UNINSTALL`. Só alterações do aplicativo ainda reconhecidas são revertidas. Arquivos desconhecidos, arquivos modificados por você, capturas e relatórios solicitados pelo usuário são dados pessoais e permanecem. Se terceiros mudarem a integração, a remoção para e informa o que precisa de recuperação. Consulte [detalhes de remoção](UNINSTALL.md) e o [relatório técnico](IMPLEMENTATION.md).
