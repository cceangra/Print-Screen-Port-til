# Uninstall

Run `bash desinstalar.sh`, review the folder, image destination, recorded desktop integrations and clipboard-process warning, then type `UNINSTALL` (the legacy token `DESINSTALAR` is also accepted).

The application restores only shortcut assignments whose current state still matches its ownership record. Xfce uses the exact recorded property, so Insert is not confused with Print. Trinity preserves unrelated groups and modified shortcut commands. Ambiguous/interrupted state is preserved for recovery; no old backup replaces the whole desktop configuration.

Only known application files matching installation-time hashes are deleted. Captures, PNG/JPG files outside that whitelist, unknown files, modified application files and unexpected symlinks are preserved. Only empty known directories are removed. External user-chosen image folders and the original downloaded ZIP are preserved. No recursive deletion of a user directory occurs.

The uninstaller may stop processes whose `/proc/PID/exe` identifies this exact installed executable and user. This invalidates its clipboard image. It does not stop another copy or unrelated applications. If safe restoration is impossible, it stops and reports what remains.

The native entrypoint also supports `./Print-RC --uninstall`. The preview lists the recorded external registry files/resources. Files/backups written by later shortcut configuration are tracked, and interrupted prepared integrations retain an ownership receipt for cleanup.
