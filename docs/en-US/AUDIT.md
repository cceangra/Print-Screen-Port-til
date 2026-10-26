# Installation and platform audit — 2026-10-26

Reviewed base: `main` at `2ea3420e91c716a89c370de2c03b188b160fcdab`. Entry points, installer, settings, key adapters, ownership inventory, diagnostics, packaging, workflows and tests were examined. The failing laptop and its installation error were not available. Findings below are repository observations and reproducible regressions; none alone proves the cause of the user's attempt.

| Priority | Observed problem | Change / status |
| --- | --- | --- |
| High | Latest release is still 0.5.6, with the reported SIGFPE defect. Main's source ZIP has no binaries; candidates live in a separate download. | README/guide warnings and instructions; artifact renamed Print-RC-Linux-x86_64. Old release was neither replaced nor deleted. Stable publication still requires real acceptance. |
| High | Setup checked only bin/print-rc; a missing supervisor breaks capture after settings are configured. | Check both components and run self-test through the supervisor before moving/creating preferences/shortcuts. |
| High | ZIP extraction can lose execute bits. Core execution was tested before its permissions were repaired. | Restore only internal regular-file permissions before testing; refuse symlinks. A noexec mount remains an explicit blocker. |
| High | Missing Python could be discovered only after creating folders/settings. | Require working Python 3.8+ before configuration. No automatic dependency downloads. |
| High | Supervisor or pre-exec failures could appear only on stderr, making a file-manager launch seem inert. | Optional native error dialog; forward script failures before the supervisor too. Handle failed exec explicitly because Bash can clear its EXIT trap at that point. |
| Medium | Print-RC opens setup only on first use; no separate obvious executable reopened installation by click. | Native **Instalar** compiled from the same source with fixed installer mode, including after renaming. |
| Medium | Terminal selection omitted direct Sakura and /opt/trinity/bin/konsole outside PATH. | Add both entries with no shell interpolation of paths/arguments. |
| Medium | Not every file manager allows double-clicking ELF; trust rules differ. | Portable **Instalar.desktop**, Terminal=true, pt-BR/en-US names, own-folder discovery including escaped file: URIs. No copy outside the app. Desktop may still request launch authorization for this file. |
| Medium | A long distribution catalog and test priorities could look like certified support; Wayland/musl/ARM were merely “untested”. | Explicit architecture/libc/protocol matrix; distinguish missing implementations/packages and NixOS adaptation. Historical evidence stays tied to its hashes. |
| Medium | Dynamic package relies on system libraries; it is not self-contained. | Document dependencies and limits. Bundling libraries remains a future validated improvement; fully static glibc should not conceal this requirement. |

## Changed files by group

- `src/app/entrypoint.cpp`, `src/app/dialog.hpp`, `src/app/launcher.cpp`, `Makefile`: native Instalar, additional terminals and failure messages; no new toolkit in the capture core.
- `Instalar.desktop`, `packaging/portable/package.py`, `scripts/build/manifest.py`: click alternative, fourth audited ELF, execution bits and ZIP hashes.
- `instalar.sh`, `iniciar.sh`: early checks and visible failures; still no sudo, package installation or broad desktop changes.
- `scripts/inventario.sh`: Instalar, desktop entry, new header and this documentation join the application ownership allowlist. Removal remains hash-based.
- `i18n/*.json`, generated C++/Bash tables: 626 matching messages, updated prerequisite, failure and usage text in both languages.
- `.github/workflows/{build,test,release}.yml`: matching producer/consumer artifact names, desktop-file validation and four-ELF/permission checks. Existing stable-release gates remain.
- `tests/test_entrypoint.py`, `tests/test_instalacao.sh`, `tests/test_launcher.sh`, `tests/test_packaged_ownership.sh`: click/argument/URI, graphical failure, Python/supervisor/permission and owned-file removal regressions preserving personal data.
- READMEs, changelogs, quick/install/troubleshooting/compatibility guides and `compat/linux-targets.json`: consistent instructions and distinction between core testing and desktop acceptance.

## Verification

Locally: both entry executables and supervisor compiled with warnings; **75 Python tests passed**; supervisor regressions for SIGFPE/136, missing execution/127 and a simulated graphical error; Bash syntax, catalogs and workflow YAML checked. Local Python tests used the core from the base artifact above; this host without X11 headers did not rebuild that core. No local test modified a person's desktop.

Revision CI rebuilds every ELF and tests the extracted ZIP without root on Ubuntu 20.04/22.04 and Debian 13, plus real XFCE services over D-Bus/Xvfb. Read PR/commit checks for the new result and artifact hash; a green old base does not automatically approve this revision.

Still missing: click installation in the real laptop's file manager, Zorin and Q4OS acceptance, and the reported attempt's error text. Graphical error windows depend on existing zenity/kdialog/xmessage. No proven repair on the laptop, Wayland support or universal compatibility is claimed.

## Next improvements by usefulness

1. After real acceptance, publish an easy-to-find versioned package and label 0.5.6 old. End users should not have to navigate CI artifacts or download sources.
2. If missing dependencies are common, prepare a bundled-library/AppImage package with an old base and tests; do not include arbitrary glibc or globally modify LD_LIBRARY_PATH.
3. Build a Wayland edition using portals and compositor confirmation. Keep X11/Trinity and its tests; another backend, not another distribution-name list.
4. Make setup fully graphical only if clicking into the terminal remains difficult. This requires no extra resident GUI process.

Architecture choices and official references are in the [matrix](COMPATIBILITY.md). Capture/PNG/clipboard were not rewritten in this revision; the focus was installation, observable failure and platform boundaries.
