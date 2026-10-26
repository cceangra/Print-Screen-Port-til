# Changes

## 0.6.0-dev — unreleased candidate

- Replace full-static GNU/glibc linking with dynamic builds; preserve original v0.5.6 tag and release assets for investigation. The original SIGFPE reproduced in an Ubuntu 22.04/glibc 2.35/XFCE-services substitute; unchanged-source dynamic original and candidate mapped the overlay there. The actual Zorin repair remains unverified until target-desktop acceptance.
- Add a native signal-monitor parent and nonce-matched proof after overlay rendering, mapping and both input grabs. Process creation alone cannot pass the test.
- Build at a declared ABI baseline; audit ELF dependencies/symbols/build IDs; create checksummed, deterministic single-folder archives; test the extracted archive across runtimes. Require separate real-desktop/performance evidence before explicit-tag publication. Remove automatic binary commits and marker-driven publishing.
- Centralize English/Brazilian Portuguese UI, helper messages and documentation. Preserve entrypoint names and shortcut schemas; split native image/input/clipboard/UI modules.
- Encode PNG once by rows and use an event-driven, bounded compressed-PNG clipboard owner. Release the capture X11 connection and pen data before clipboard residency so transport caches are not retained. Measure exact candidates and explicit baselines in CI.
- Keep data-preserving installation/uninstallation, read-only diagnostics and resource measurements under regression tests. See the implementation report for exact completed checks and pending acceptance.

Original release history remains in Git and the unchanged v0.5.6 documentation/tag.

- Add the native root `Print-RC` executable and terminal setup/actions. Track later shortcut writes and external registry files, retain uninstall receipts after interrupted external operations, avoid untracked destination parent folders, and fix the clipboard benchmark readiness race.

- Installation audit: native Instalar and internal desktop entry, Sakura/Trinity terminals, early Python/supervisor/permission checks, optional graphical failures and explicit platform matrix. Artifact/ZIP use Print-RC-Linux-x86_64 naming. No new resident processes. [Report](docs/en-US/AUDIT.md).
