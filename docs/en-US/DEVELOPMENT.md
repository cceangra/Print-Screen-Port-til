# Development and validation

Use a developer-controlled environment with C++17, make, pkg-config, X11/libpng development headers, binutils and Python 3. `make -B all` builds dynamically; `make debug` adds symbols and frame pointers. `make portable` strips the dynamic binaries. It does not link static glibc. Build tools are never installed on a user's machine by application scripts.

`python3 scripts/build/locales.py --check` rejects duplicate/missing/blank keys, placeholder mismatches, unsafe format specifiers and stale generated tables. Edit the two JSON catalogs, then run the generator. Native messages are embedded; Bash setup uses generated quoted data; Python helpers are short-lived.

The source is split into app lifecycle, configuration, image encoding, geometry/drawing, keyboard detection, clipboard ownership and localization modules. Portuguese public shell filenames and original shortcut state schemas are preserved.

On an isolated X11 test machine, as a normal user, run `bash tests/run.sh`. It includes original regression tests, adapter mocks, real Xvfb area/fullscreen/drawing/clipboard/INCR, 16/24-depth mapped/dimmed-overlay tests, competing grabs, signal injection and safe-uninstall cases. Synthetic input is never sent by read-only diagnostics. A 24-depth screen commonly uses 32-bpp storage; Xvfb may not offer 32-bit root depth.

Build auditing: `python3 scripts/build/manifest.py --output dist/build-manifest.json`. Package: `python3 packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-linux-x86_64-glibc.zip`. Host builds exceeding the ABI ceiling fail; never label a locally relaxed audit a portable release. Source tags, compiler/linker, build IDs, dependencies, symbols and hashes accompany candidates.

Release publication requires an explicit existing tag, passing archive regressions and separate exact-hash desktop/performance evidence. Existing assets are never overwritten, normal CI has read-only repository permission, and no binary is committed back into main. Future ARM/musl/Wayland work requires separately verified tracks.
