# Troubleshooting

Run `bash diagnosticar.sh --read-only`. It observes OS/session, ELF metadata, configuration and recorded shortcuts without starting capture, grabbing keys, creating reports or modifying preferences. Output is redacted by default. Saving requires explicit `--output /chosen/report.json`, which refuses existing files.

SIGFPE is signal 8; status 136 is 128+8. The v0.5.6 Zorin evidence proves an integer divide exception in host glibc at offset 0x175c79. Static glibc interacting with runtime-loaded host modules/TLS remains a hypothesis. Actual target and packaged-candidate tests are required. A PNG self-test or a process ID does not prove an overlay appeared.

The native launcher reports fatal signals and whether rendered-overlay readiness was emitted. A clipboard owner may outlive the launcher. Shortcut proof requires a matching instance, mapped/drawn overlay and both input grabs. Failure leaves activation pending.

For CONFIG_MISSING/CONFIG_INVALID, run `bash configurar.sh`. UNSUPPORTED_DISPLAY requires X11; no Wayland backend exists. INSTANCE_BUSY means finish/cancel the active capture. POINTER_GRAB_FAILED/KEYBOARD_GRAB_FAILED preserve another application's reservation; retry after it releases control. PNG_SAVE_FAILED preserves paste when clipboard is enabled.

Trinity integration requests `khotkeysd` to reread configuration. If activation stays pending, inspect its service manager or log out/back in. No desktop process is killed. Changed third-party shortcuts block restoration. Preserve `backups/` and `config/` for recovery.

Debugger use and crash dumps are optional developer actions. The app does not install a debugger, enable dumps or upload logs. Redact personal paths before publishing additional evidence.

## Setup does not open or seems to disappear

- Check `VERSION`: 0.5.6 is the old release. Main's source ZIP has no binaries. Use **Print-RC-Linux-x86_64.zip** from the intended candidate run; its manifest identifies the source.
- Open **Instalar** or **Instalar.desktop / Install (terminal)**. If the desktop asks, allow execution of that file. No terminal path needs typing.
- Permission denied: check execute permission and extract to a writable Linux folder that permits execution. The app changes no mount settings.
- `error while loading shared libraries`, `GLIBCXX ... not found` or a missing loader: incompatible/missing dependency. This ZIP does not bundle libraries; do not replace system libc. Send the exact message and read-only diagnosis to identify the dependency.
- Wayland/ARM/musl/32-bit: this edition does not serve that target. Read the [matrix](COMPATIBILITY.md).
- Startup failures can appear in a dialog if zenity/kdialog/xmessage already exists; setup keeps results visible until Enter. Without those dialogs, use terminal output for the error.

[Audit and tests](AUDIT.md). The real laptop's error is still required to establish its exact cause.
