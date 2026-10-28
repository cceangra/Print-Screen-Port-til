# Beginner setup

This revision keeps the existing GNU/Linux x86_64/glibc/X11 edition, capture core and compatibility criteria. It creates no Wayland edition, publishes no stable release and certifies no laptop without testing it.

## What changes for users

- **Instalar** still starts setup by click. Three stages cover the application folder, saving/copying images and the chosen key.
- **Configurar** opens a numbered menu. Configurar.desktop is available for file managers that require desktop entries. No bash or command paths need typing.
- Two image questions explain the folder and “copy so I can paste with Ctrl+V”. Enter keeps the previous/recommended choice; old choices are preserved.
- Confirmations that write or replace something use **1 = Yes, 2 = No, Enter = No**. Invalid answers prompt again. Legacy y/n and yes/no remain accepted.
- Another folder is optional. Paste its path without quotes; ~/ is accepted. The answer is not evaluated as code.
- The key is physically selected, shown and confirmed. The test then asks to press that key itself again; it is not another Yes question. Messages distinguish unconfigured, saved and tested keys.
- Configurar includes language selection, read-only diagnosis and removal with the existing preview/confirmation. The menu itself creates no external shortcuts, desktop menu items or autostart entries.

## Fixes beyond wording

Bash can run a function without aborting on an error when it is invoked as `function || true`. The key menu continued after an adapter failed and could announce a saved registration and start the proof. Adapter return codes are now checked explicitly; failure or refusal stops that path without claiming success.

When overlay proof passes during reconfiguration, the manifest now retains that result instead of always returning to pending. It proves only the reported overlay check; a saved capture and laptop acceptance remain separate.

## Files by responsibility

- `configurar.sh`, `instalar.sh`, `configurar-tecla.sh`: menu, numbered choices, confirmations and clear states; legacy entrypoints/answers remain.
- `scripts/prompts.sh`, `scripts/print_rc_i18n.py`, Trinity/XFCE adapters: consistent confirmation, shorter setup view retaining external-change disclosures and detailed diagnostics.
- `src/app/entrypoint.cpp`, `Makefile`, `Configurar.desktop`, desktop bootstrap: native settings entry and location independent of the opening directory.
- Manifest, packager, build workflow and inventory: fifth audited ELF, execution permissions, corresponding sources and hash-based removal of new files.
- pt-BR/en-US catalogs and generated tables: equivalent questions in both languages.
- Tests: Configurar entry/path/URI/lost permission, numeric/legacy/EOF confirmation, no writes after cancellation, menu language change, adapter failure without false success and removal preserving data. Real Sakura remains in CI.

## Limits and validation

Locally: entries/supervisor compiled; 78 Python tests passed; Bash syntax and catalogs checked. The local core came from the previously approved candidate; CI rebuilds the full package and runs Bash/C++/Xvfb tests without root in the declared environments. Read commit checks for this ZIP's exact result.

No new resident service, continuous keyboard reader, dependency downloads or global system changes. Settings, executables and records remain in the folder; external shortcut resources remain recorded for conservative restoration. Images and personal files are preserved. [Quick start](QUICK_START.md) · [Compatibility matrix](COMPATIBILITY.md).

Keeping the image folder respects its relative internal path after the application folder moves; it does not silently revert to the old destination. This does not automatically change externally registered shortcuts after a manual move.

Changing the image folder also updates an existing installation manifest, keeping those images user-owned and preserved on removal.

Shortcut proof also refuses a symlinked config/ directory, preventing temporary markers outside the application folder. An isolated regression verifies preservation of the external file.
