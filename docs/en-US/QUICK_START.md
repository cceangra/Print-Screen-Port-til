# Install without typing paths

1. Download the **candidate binary package** from a successful [Actions run](https://github.com/cceangra/Print-Screen-Port-til/actions/workflows/testar.yml). The artifact is **Print-RC-Linux-x86_64**. It contains the application ZIP **Print-RC-Linux-x86_64.zip**. Extract this inner ZIP.
2. Open the single **Print-RC** folder and double-click **Instalar**. It opens setup in a terminal automatically; no `bash` or full path needs typing.
3. If the file manager blocks binaries, open **Instalar.desktop**, displayed as **Install (terminal)**. Allow that file to launch when the desktop asks. This alternative stays inside the app folder.
4. At the first question, **1 or Enter keeps the current folder**. For image choices, **1 or Enter keeps the recommended/current folder and previous Ctrl+V choice** (copying starts on for new installs). Read the summary and explicitly confirm with **1 = Yes**.
5. Press your chosen key when prompted. Check its name and any identified conflict; confirm with **1 = Yes**. During the test, press **the chosen key itself** once more. This is not another question asking for Yes. Without a successful test, the app says the key is not yet confirmed.
6. Then open **Print-RC** to capture or use the configured key. To change options, open **Configurar**. If the file manager blocks the binary, use **Configurar.desktop**, displayed as **Configure Print RC**.

**Code → Download ZIP contains source code only.** New `Instalar`, `Print-RC` and `bin/` files appear only in the compiled binary package. Release **0.5.6 is old** and does not contain this update. The ZIP name is the same; check `VERSION` and the source commit in `build-manifest.json`.

The destination's parent must exist. Do not run as root. The app installs no dependencies. Read the [compatibility matrix](COMPATIBILITY.md): this edition uses GNU/Linux x86_64, glibc and **X11**. Wayland, ARM and musl have no compatible package in this edition.

If execute permissions were lost, enable **Properties → Permissions → Allow executing** on the file, or use `Instalar.desktop`. If a mount blocks execution, extract to a Linux folder in your home directory. Changing mount settings or the file manager's general policy is unnecessary.

| Action | Click or optional command |
| --- | --- |
| Install or review setup | **Instalar** or **Install (terminal)** |
| Capture | **Print-RC** |
| Preferences and language | **Configurar** → option 1 (images/Ctrl+V) or 3 (language) |
| Choose, check or release a key | **Configurar** → option 2 |
| Read-only diagnosis | **Configurar** → option 4 |
| Uninstall with preview | **Configurar** → option 5 |

Legacy `bash instalar.sh` and `bash iniciar.sh` remain available from a terminal opened in the application folder. No full path is needed.

Choose a physical key recognized by X11. Print and Insert are separate; Escape and standalone modifiers are reserved. Letters, Enter and space can impair typing when used as global keys. If association/proof fails, disable the conflict in desktop shortcut settings and open `configurar-tecla.sh` to check or choose another key. Only Trinity and XFCE have automatic adapters; other X11 desktops need manual association.

Settings, state, backups, executables and default captures remain inside the folder. `config/installation-manifest.json` declares the external XFCE property or Trinity sections registered by the app; removal restores only changes still owned by the installation. User-created manual shortcuts need manual removal. The file manager may keep its own trust/history metadata; the app does not control those desktop files.

On uninstall, preview and type `DESINSTALAR` or `UNINSTALL`. Captures, explicitly requested reports and unknown/modified files remain. See [removal](UNINSTALL.md) and [audit](AUDIT.md).

For confirmations that write/change settings, **Enter means No**. Unknown answers prompt again. Legacy y/n and yes/no answers remain accepted. For another image folder, choose 2 and paste the path without quotes; ~/ is accepted. [Change details](BEGINNER_SETUP.md).
