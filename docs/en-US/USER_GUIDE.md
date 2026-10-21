# User guide

Run `bash iniciar.sh` or press the registered key. Drag an area to save it. SCREEN captures the whole root screen with one click. PEN draws blue strokes; UNDO removes the latest stroke. Switch back to AREA to capture a region including the drawing. CLOSE, Escape or right-click cancels without saving. One selection overlay can be active at a time.

Use `bash configurar.sh` for the image folder and clipboard preference. PNG filenames are exclusive and never overwrite captures. Files use private permissions. If saving fails, the error is reported and clipboard paste remains available when enabled.

The X11 clipboard owner retains compressed PNG only, expires after 30 minutes, and exits when another owner takes over. With clipboard off, capture/cancellation leaves no Print RC process. There is no resident keyboard listener.

Select language with `bash configurar.sh --language en-US` or `--language pt-BR`. `PRINT_RC_LANG` overrides it temporarily. Unknown locales fall back to English. Option names, paths, configuration schema and machine-readable status tokens stay stable.

`bash configurar-tecla.sh` inspects, configures, releases or verifies shortcuts. Its X11 reservation probe is interactive and briefly attempts a grab. Use `diagnosticar.sh --read-only` for observation without grabs. After relocating an installed folder, explicitly repair/rebind desktop integration; external image folders remain user-owned destinations.
