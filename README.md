# Print RC

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

A small native C++17 screenshot and annotation utility for Linux **X11**. Select an area, capture the whole screen with one click, draw with the pen, undo, save PNG and optionally paste with Ctrl+V. Keyboard shortcuts are managed by your desktop; Print RC has no resident keyboard listener.

## Candidate status

`0.6.0-dev` replaces the full-static GNU release build with a dynamically linked build. In Ubuntu 22.04/glibc 2.35 with isolated XFCE services, the shipped static original reproduced SIGFPE while the dynamically rebuilt original and candidate opened the overlay. This supports the packaging change for the reported v0.5.6 **SIGFPE on Zorin OS 17.3 Lite/XFCE/glibc 2.35**. **The target desktop repair is not yet verified.** Q4OS/Trinity acceptance also remains required. Track [issue #1](https://github.com/cceangra/Print-Screen-Port-til/issues/1).

The [compatibility catalog](compat/linux-targets.json) lists test targets, including untested distributions. Xvfb tests establish X11 core/ABI behavior; they do not certify an installed desktop. Wayland, ARM64 and musl/Alpine builds are not implemented or advertised as supported.

## Download and run

**Double-click `Instalar` inside the application folder.** Setup opens a terminal automatically; no `bash` or full path needs typing. If the file manager blocks binaries, open `Instalar.desktop`, displayed as **Install (terminal)**, and allow that file to launch when asked. After setup, open **Print-RC** to capture or **Configurar** for a numbered settings menu. [Step by step](docs/en-US/QUICK_START.md).

**Download the binary package from a successful [Actions run](https://github.com/cceangra/Print-Screen-Port-til/actions/workflows/testar.yml)**: artifact **Print-RC-Linux-x86_64**, containing **Print-RC-Linux-x86_64.zip**. Extract the inner ZIP: it contains one `Print-RC/` folder. **Code → Download ZIP is source-only**, without ready executables. Release **0.5.6 is old** and does not contain this update.

Setup keeps the extracted folder or moves it to a chosen destination after confirmation. Settings, executables, backups and default captures stay inside it. The app installs no packages, uses no sudo and downloads no dependencies. Compatible system libraries, Bash and Python 3.8+ are required; **runtime libraries are not bundled**.

| Platform/session | Status of this edition |
| --- | --- |
| GNU/Linux x86_64, glibc, X11 | Core tested in Ubuntu 20.04/22.04 and Debian 13 using Xvfb; real desktops still require acceptance |
| XFCE or Trinity on X11 | Automatic key setup implemented; real Zorin/Q4OS acceptance pending |
| Other X11 desktops | Manual key association; specific validation pending |
| Wayland, ARM, 32-bit, Alpine/musl | No compatible implementation/package in this edition |
| Stock NixOS, Windows, macOS | This generic package needs separate adaptation/edition |

Read the [full matrix](docs/en-US/COMPATIBILITY.md) and [failure/fix audit](docs/en-US/AUDIT.md). Setup checks components/Python and restores executable permissions before creating preferences or shortcuts. Legacy `bash instalar.sh` and `bash iniciar.sh` remain available from a terminal opened in the folder.

## Settings and language

Open **Configurar** in the app folder. Choose 1 for images/Ctrl+V, 2 for the key, 3 for language, 4 for diagnosis or 5 to uninstall with confirmation. For save/change confirmations: 1 = Yes, 2 = No, Enter = No. No commands need typing.

Legacy commands remain available:

```bash
bash configurar.sh
bash configurar.sh --language en-US
bash configurar.sh --language pt-BR
bash configurar-tecla.sh
bash diagnosticar.sh --read-only
bash desinstalar.sh
```

Locale selection: `PRINT_RC_LANG` override → saved `config/language` → `LC_ALL` → `LC_MESSAGES` → `LANG` → English fallback. Brazilian Portuguese and English use one source tree and validated catalogs. Old Portuguese launcher names remain public entrypoints in both languages.

Captures default to `capturas/`. An explicitly selected external image directory remains user-owned. Uninstallation preserves images, unknown files, modified application files and externally changed shortcuts. Review its preview before confirming.

With clipboard enabled, a native process retains the **compressed PNG** for up to 30 minutes or until another application owns the clipboard. Pixel buffers are released before that wait. With clipboard disabled, no Print RC process remains after capture/cancellation.

## Documentation

[Install](docs/en-US/INSTALL.md) · [User guide](docs/en-US/USER_GUIDE.md) · [Troubleshooting](docs/en-US/TROUBLESHOOTING.md) · [Uninstall](docs/en-US/UNINSTALL.md) · [Compatibility](docs/en-US/COMPATIBILITY.md) · [Privacy](docs/en-US/PRIVACY.md) · [Development](docs/en-US/DEVELOPMENT.md) · [Changes](CHANGELOG.md) · [Implementation and test evidence](docs/en-US/IMPLEMENTATION.md)

Licensed under GPL-3.0-or-later. Original version history remains in Git, including the [v0.5.6 README](https://github.com/cceangra/Print-Screen-Port-til/blob/v0.5.6/README.md).
