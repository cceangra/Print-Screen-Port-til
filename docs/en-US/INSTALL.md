# Installation

Download the candidate ZIP from a passing Actions run or a validated tagged release, verify its SHA-256, and extract the single `Print-RC` directory. The source Download ZIP needs a developer build. Double-click **Instalar** or **Instalar.desktop / Install (terminal)** as your regular user. Setup opens a terminal automatically without typing a path; `bash instalar.sh` remains available. Keep the extracted folder or explicitly move it to a dedicated destination. Existing conflicting files stop the operation and remain intact.

Choose the PNG destination and clipboard preference. External image folders are disclosed and preserved during uninstall. Select a single X11 key and confirm once to replace recognized conflicts. Letters, Enter and space may interrupt normal typing. Escape and standalone modifiers are not accepted. Print and Insert remain separate.

In an interactive X11 terminal, the shortcut proof briefly draws the overlay, obtains both input grabs and closes without saving. Missing proof leaves activation pending. File setup alone does not certify readiness.

Automatic adapters exist for Trinity/KHotKeys and Xfce/xfconf-query. Other desktops require a manual shortcut to `/bin/bash '/absolute/path/Print-RC/iniciar.sh'`. Manual shortcuts must be removed manually. A real desktop test is required before claiming an adapter works there.

The GNU package needs a compatible system loader, glibc, libstdc++, libX11 and libpng16; helpers use Bash and Python 3. The app never downloads or installs dependencies, replaces glibc, calls sudo or starts an updater.

[Native executable and simple terminal setup](QUICK_START.md). Open `Print-RC` for captures; `Print-RC --install` and `Print-RC --uninstall` use the terminal. The destination parent must exist.

[Failure/fix audit](AUDIT.md). The package does not bundle libraries. This edition requires GNU/Linux x86_64/glibc/X11, Bash and Python 3.8+; see the [matrix](COMPATIBILITY.md).
