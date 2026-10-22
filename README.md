# Print RC

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

A small native C++17 screenshot and annotation utility for Linux **X11**. Select an area, capture the whole screen with one click, draw with the pen, undo, save PNG and optionally paste with Ctrl+V. Keyboard shortcuts are managed by your desktop; Print RC has no resident keyboard listener.

## Candidate status

`0.6.0-dev` replaces the full-static GNU release build with a dynamically linked build. In Ubuntu 22.04/glibc 2.35 with isolated XFCE services, the shipped static original reproduced SIGFPE while the dynamically rebuilt original and candidate opened the overlay. This supports the packaging change for the reported v0.5.6 **SIGFPE on Zorin OS 17.3 Lite/XFCE/glibc 2.35**. **The target desktop repair is not yet verified.** Q4OS/Trinity acceptance also remains required. Track [issue #1](https://github.com/cceangra/Print-Screen-Port-til/issues/1).

The [compatibility catalog](compat/linux-targets.json) lists test targets, including untested distributions. Xvfb tests establish X11 core/ABI behavior; they do not certify an installed desktop. Wayland, ARM64 and musl/Alpine builds are not implemented or advertised as supported.

## Download and run

**Open the native `Print-RC` executable after terminal setup.** [Quick start](docs/en-US/QUICK_START.md).

Use a **candidate artifact from a passing Actions run**, or a future tagged release that passed the desktop release gate. GitHub's source **Download ZIP** contains source and does not contain a prebuilt executable. The old v0.5.6 binary and release are retained in their original tag/assets for investigation.

Extract the application ZIP: it contains one `Print-RC` directory. Run `instalar.sh` as your normal user. The installer keeps the extracted folder or moves it to a destination you select. It does not install packages, use sudo, download dependencies or start an updater.

```bash
bash instalar.sh
bash iniciar.sh
```

The current GNU package requires the system's compatible dynamic loader, glibc, libstdc++, libX11 and libpng16. Python 3 is needed for setup/shortcut helpers, not during capture. The primary build has an enforced GLIBC ≤ 2.31 / GLIBCXX ≤ 3.4.28 symbol ceiling; exact metadata accompanies each archive.

## Settings and language

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
