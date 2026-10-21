# Changes

## 0.6.0-dev — unreleased candidate

- Replace full-static GNU/glibc linking with dynamic builds; preserve original v0.5.6 tag and release assets for investigation. The reported Zorin repair remains unverified until target-desktop acceptance.
- Add a native signal-monitor parent and nonce-matched proof after overlay rendering, mapping and both input grabs. Process creation alone cannot pass the test.
- Build at a declared ABI baseline; audit ELF dependencies/symbols/build IDs; create checksummed, deterministic single-folder archives; test the extracted archive across runtimes. Require separate real-desktop/performance evidence before explicit-tag publication. Remove automatic binary commits and marker-driven publishing.
- Centralize English/Brazilian Portuguese UI, helper messages and documentation. Preserve entrypoint names and shortcut schemas; split native image/input/clipboard/UI modules.
- Keep data-preserving installation/uninstallation, read-only diagnostics and resource measurements under regression tests. See the implementation report for exact completed checks and pending acceptance.

Original release history remains in Git and the unchanged v0.5.6 documentation/tag.
