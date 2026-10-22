# Start with the executable

Download the **candidate binary package** from a passing Actions run and extract its inner ZIP. It contains one `Print-RC/` folder; the native **`Print-RC` executable is at its root**, with native components in `bin/`. The source Download ZIP needs a build.

Open a terminal in the extracted folder and install with:

```bash
./Print-RC --install
# The original entrypoint remains available:
bash instalar.sh
```

Keep the folder or choose to move it. The destination parent must already exist: setup does not create untracked external parent folders. If ZIP extraction loses execute permission, use `bash instalar.sh`, which restores permission on the packaged executable. Do not run as root. The application does not install dependencies.

Then open **Print-RC** in the file manager or run `./Print-RC`. On first use without configuration, it tries to open setup in an available terminal. When opening a new terminal, it waits for Enter afterward so errors and instructions remain visible.

| Action | Command |
| --- | --- |
| Capture | `./Print-RC` |
| Preferences/language | `./Print-RC --configure` |
| Choose, inspect or release a key | `./Print-RC --shortcut` |
| Read-only diagnosis | `./Print-RC --diagnose --read-only` |
| Uninstall with preview | `./Print-RC --uninstall` |

Choose a physical key recognized by X11. Print and Insert remain independent. Escape and standalone modifiers are reserved. Letters, Enter and space can interrupt typing when bound globally. A key can be occupied by the desktop or another program; no application can guarantee its availability in every session. If registration/proof fails, disable the conflict in the desktop shortcut manager and run `bash configurar-tecla.sh` to inspect it or choose another key. Missing overlay proof leaves activation pending.

Capture uses X11 and compatible system libraries on GNU/Linux x86_64. It does not depend on a distribution name. Trinity and XFCE have automatic adapters; other X11 desktops receive manual shortcut instructions. A shortcut created manually by the user must be removed manually. Wayland, ARM64 and musl need separate editions and are not advertised as supported by this package. The distribution registry separates observed tests from future targets.

`config/installation-manifest.json` declares external resources and known registry files: Trinity's `khotkeysrc` or the XFCE channel's default session storage file, with the exact changed property. XFCE maintains that file through its own service; removal reverses the recorded property without deleting the entire configuration. Later reconfiguration state/backups are also inventoried. An interrupted operation with prepared external state retains an ownership receipt and uninstall instructions, without claiming successful activation.

Review the uninstall preview and type `UNINSTALL` or `DESINSTALAR`. Only still-recognized application changes are reversed. Unknown files, files you modified, captures and user-requested reports are personal data and remain. If a third party changed the integration, removal stops and explains recovery requirements. See [uninstall details](UNINSTALL.md) and the [engineering report](IMPLEMENTATION.md).
