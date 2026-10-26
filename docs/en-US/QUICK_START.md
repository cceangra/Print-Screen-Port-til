# Install without typing paths

1. Download the **candidate binary package** from a successful [Actions run](https://github.com/cceangra/Print-Screen-Port-til/actions/workflows/testar.yml). The artifact is **Print-RC-Linux-x86_64**. It contains the application ZIP **Print-RC-Linux-x86_64.zip**. Extract this inner ZIP.
2. Open the single **Print-RC** folder and double-click **Instalar**. It opens setup in a terminal automatically; no `bash` or full path needs typing.
3. If the file manager blocks binaries, open **Instalar.desktop**, displayed as **Install (terminal)**. Allow that file to launch when the desktop asks. This alternative stays inside the app folder.
4. Confirm the destination (Enter keeps the folder), capture folder and clipboard. Press your chosen key, read any detected conflict and confirm the association. When asked, press it again to test activation. Without overlay proof, activation remains pending.
5. Then open **Print-RC** to capture or use the configured key.

**Code → Download ZIP contains source code only.** New `Instalar`, `Print-RC` and `bin/` files appear only in the compiled binary package. Release **0.5.6 is old** and does not contain this update. The ZIP name is the same; check `VERSION` and the source commit in `build-manifest.json`.

The destination's parent must exist. Do not run as root. The app installs no dependencies. Read the [compatibility matrix](COMPATIBILITY.md): this edition uses GNU/Linux x86_64, glibc and **X11**. Wayland, ARM and musl have no compatible package in this edition.

If execute permissions were lost, enable **Properties → Permissions → Allow executing** on the file, or use `Instalar.desktop`. If a mount blocks execution, extract to a Linux folder in your home directory. Changing mount settings or the file manager's general policy is unnecessary.

| Action | Click or optional command |
| --- | --- |
| Install or review setup | **Instalar** or **Install (terminal)** |
| Capture | **Print-RC** |
| Preferences/language | `./Print-RC --configure` |
| Choose, check or release a key | `./Print-RC --shortcut` or `configurar-tecla.sh` |
| Read-only diagnosis | `./Print-RC --diagnose --read-only` |
| Uninstall with preview | `./Print-RC --uninstall` |

Legacy `bash instalar.sh` and `bash iniciar.sh` remain available from a terminal opened in the application folder. No full path is needed.

Choose a physical key recognized by X11. Print and Insert are separate; Escape and standalone modifiers are reserved. Letters, Enter and space can impair typing when used as global keys. If association/proof fails, disable the conflict in desktop shortcut settings and open `configurar-tecla.sh` to check or choose another key. Only Trinity and XFCE have automatic adapters; other X11 desktops need manual association.

Settings, state, backups, executables and default captures remain inside the folder. `config/installation-manifest.json` declares the external XFCE property or Trinity sections registered by the app; removal restores only changes still owned by the installation. User-created manual shortcuts need manual removal. The file manager may keep its own trust/history metadata; the app does not control those desktop files.

On uninstall, preview and type `DESINSTALAR` or `UNINSTALL`. Captures, explicitly requested reports and unknown/modified files remain. See [removal](UNINSTALL.md) and [audit](AUDIT.md).
