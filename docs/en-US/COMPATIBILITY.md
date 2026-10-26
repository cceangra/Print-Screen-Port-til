# Compatibility of this edition

This edition is **GNU/Linux x86_64 + glibc + X11**. A distribution name alone does not establish compatibility. There is no validated “every Linux” edition.

| Environment | Capture | Global key | Available evidence |
| --- | --- | --- | --- |
| Ubuntu 20.04 and 22.04, Debian 13 in containers/Xvfb | Core tested | Simulated adapters | Automated ZIP tests; not acceptance of an installed desktop |
| XFCE services on Ubuntu 22.04/glibc 2.35, D-Bus/Xvfb | Tested in this environment | Real xfsettingsd/xfconf tested | Does not equal installed Zorin |
| Zorin 17.3 Lite, XFCE/X11 | Dynamic candidate needs validation | XFCE adapter implemented | SIGFPE confirmed in old 0.5.6; repair on the real laptop unconfirmed |
| Q4OS, Trinity/X11 | Candidate needs validation | Trinity adapter implemented | Current edition still lacks real-desktop acceptance |
| Mint, MX, Xubuntu and other GNU/Linux x86_64 with XFCE/X11 | Possible with compatible libraries | XFCE adapter | Untested distributions/versions are not certified |
| GNOME, Plasma, MATE, Cinnamon, LXQt and others on X11 | Possible, needs validation | Manual desktop association | No automatic adapter in this edition |
| Wayland, including GNOME/Plasma/COSMIC/Sway/Hyprland in that session | **Not implemented** | **Not implemented** | XWayland does not turn this edition into a Wayland screenshot tool |
| ARM64, ARM32, 32-bit x86 | **No package** | No package | Require a separately validated build |
| Alpine/musl | **No package** | No package | This package uses glibc |
| Stock NixOS | **Generic package needs adaptation** | Unverified | Different loader/paths; no automatic system configuration changes |
| Windows, macOS, Android | **Not implemented** | **Not implemented** | This edition's Linux ELF format does not serve these platforms |

## Dependencies and opening by click

The package **does not bundle runtime libraries**. It requires compatible system glibc, libstdc++, libgcc, libX11, libpng16 and transitive dependencies; Bash 4 or later, normal GNU utilities and Python **3.8 or later** for setup/configuration. CI builds on Ubuntu 20.04 and limits GLIBC symbols to 2.31 and GLIBCXX to 3.4.28. These are build ceilings; exact requirements per executable are in `build-manifest.json`. This does not certify every distribution with that glibc.

The folder must be writable and allow execution. Prefer a Linux filesystem in your home folder when a USB drive or `noexec` mount blocks launching. Changing system mount options is unnecessary. `Instalar` and `Print-RC` need execute permission; extractors can discard it. The script/desktop installer restores execute bits only on regular application files.

Open **Instalar** in the folder. If the file manager blocks binaries, use **Instalar.desktop / Install (terminal)** and allow execution of that file when prompted. It opens the desktop's chosen terminal and locates its own folder, without typing paths. It stays inside the application and is not copied into menus/autostart. Exact double-click behavior still needs checking on the real laptop's file manager.

Capture needs no persistent terminal. The native entrypoint recognizes x-terminal-emulator, Konsole, Trinity Konsole in /opt/trinity, Sakura, xfce4-terminal, xterm and gnome-terminal for interactive tasks. Error dialogs use zenity, kdialog or xmessage only when already available; none is installed by the application. Without these tools, stderr remains available in a terminal.

## Next platform

For a future Wayland edition, use **Screenshot** and **GlobalShortcuts** portals, detect the compositor's actual capabilities and honor user confirmation. The compositor may reject a key; promising “any key guaranteed” is not possible. Share PNG/configuration code and isolate capture/shortcut backends. Changing C++ to another language does not remove this protocol limitation.

ARM needs its own build/artifact. Musl and NixOS need separate packaging. AppImage can reduce missing dependencies but does not remove glibc requirements, permissions or tests on each base. This edition prioritizes a small X11 core with no resident keyboard reader.

## Sources and results

- [Main tests before this audit](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39855959788): source `2ea3420e91c716a89c370de2c03b188b160fcdab`. Results apply to their specific ZIP/commit, not later edits.
- [Target catalog and historical evidence](../../compat/linux-targets.json). `support_tier` means test priority, not support quality.
- [Thunar executable-opening rules](https://docs.xfce.org/xfce/thunar/faq).
- [Screenshot](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Screenshot.html) and [GlobalShortcuts](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html) portals.
- [NixOS and generic executables](https://nix.dev/guides/faq.html).
- [AppImage: dependencies, an old build base and testing remain necessary](https://docs.appimage.org/reference/best-practices.html).

Real Zorin and Q4OS remain acceptance requirements before a stable release. No libc replacement, automatic dependency installation or broad system configuration changes occur.
