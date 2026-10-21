# Privacy and files

Capture reads the visible X11 root screen only when requested. Key detection temporarily grabs the keyboard only during explicitly requested setup, ends on the first valid key/Escape/timeout, and records the chosen keysym rather than keystroke history. No resident keyboard listener, telemetry, network download, upload or automatic updater is present.

Preferences, language, shortcut recovery state, original shortcut backups and the uninstall inventory stay inside the application folder. PNGs default to `capturas/` or an explicitly selected external user-owned folder. Xfce and Trinity necessarily persist their own shortcut registry outside the folder; helpers disclose those changes and retain restoration records.

No per-capture log file is created by default. Read-only diagnostics write only to standard output, redact home/application paths and avoid environment secrets. Writing a report is a separate explicit action. Clipboard ownership temporarily retains compressed PNG in memory for up to 30 minutes or until another application takes ownership. Anyone with access to the same X11 session may be able to request clipboard data under X11's normal security model.
