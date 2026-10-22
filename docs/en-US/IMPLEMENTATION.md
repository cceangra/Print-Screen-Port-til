# Implementation and validation report — 0.6.0-dev

[Português (Brasil)](../pt-BR/IMPLEMENTATION.md)

This is a reviewable development candidate in [PR #2](https://github.com/cceangra/Print-Screen-Port-til/pull/2), following the supplied engineering handoff in P0 → packaging → localization/layout → lifecycle → performance order. The commits separate these phases. The acceptance contract is **not complete**: no physical or VM Zorin 17.3 desktop or Q4OS/Trinity desktop was available. Main and the original v0.5.6 tag/assets are unchanged. No release has been published.

## P0 evidence and change

The handoff establishes that Insert launched the old process and it died with SIGFPE/136, with a system-libc integer-divide fault. An old PNG self-test or a PID was never sufficient evidence of a visible overlay.

[Recorded passing archive run 39695994801](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39695994801), source `0bd95a6bb8cc1d46050fefdfcb226205437bc6e9`, exercised the exact ZIP SHA-256 `7d5f19147fe21452de771dfd4a39071454b84bb8141dd92526baea0a40c6a83a`. This is an earlier tested checkpoint, not the checksum of every later candidate. The latest PR checks identify their own source and ZIP hash.

In an Ubuntu 22.04/glibc 2.35 container with real xfsettingsd/xfconf, isolated D-Bus and Xvfb, GDB reproduced SIGFPE in the preserved shipped static v0.5.6 binary (build ID `f1fd943d78ed03fa6936057229f7966adba90126`). Unchanged v0.5.6 source compiled dynamically in that environment mapped/drew the overlay and cancelled successfully. The candidate launched from the actual Insert shortcut, passed nonce/render/input readiness, saved a valid 1024×768 PNG, restored the previous Insert assignment and preserved Print. See the [retained evidence index](../../compat/test-results/ci-39695994801/evidence-index.json) and its checksummed logs.

The extended GDB checkpoint [39697099560](https://github.com/cceangra/Print-Screen-Port-til/actions/runs/39697099560) also recorded process mappings and instructions: the fault is at system-libc file offset `0x175c79`, instruction `div %rsi`, with RSI=0. This matches the handoff offset and establishes a zero divisor in the substitute.

This narrows the failure to the shipped build/host interaction and supports replacing full-static GNU packaging. It does **not** identify a symbol-level libc/TLS root cause: the stripped binary's backtrace has unsymbolized frames. A host-library/static-glibc loading interaction remains an inference. The substitute is not Zorin desktop certification, and the actual Zorin Insert→GUI→PNG→paste test remains release blocking.

The default and portable GNU targets now link dynamically. A small native supervisor observes fatal child signals, returns 128+signal and reports whether the ready stage was reached. The app publishes readiness only after rendering, XSync, IsViewable, successful keyboard and pointer grabs and no startup X errors. The explicit probe briefly opens/closes the interface and saves no image. The shortcut tester accepts only its matching instance token; ordinary process creation leaves activation pending. SIGFPE/SIGSEGV injection checks the error path without remapping a key.

## Packaging, organization and localization

Ubuntu 20.04/glibc 2.31 is the builder baseline on an Ubuntu 22.04 runner. The manifest records compiler/linker, clean source commit, architecture, build IDs, dependencies, symbol requirements and SHA-256. The archive gate enforces GLIBC ≤2.31 / GLIBCXX ≤3.4.28. The recorded checkpoint's main binary was 96,576 bytes, required GLIBC 2.15 / GLIBCXX 3.4.26 / CXXABI 1.3.9, and needed libX11, libpng16, libstdc++, libgcc_s and libc. These are measured requirements, not support claims for every older system.

Candidates contain one `Print-RC/` directory with the two required native executables, source, catalogs, scripts, tests and documentation. System glibc, loaders and drivers are not bundled. There is no broad runtime LD_LIBRARY_PATH override. Deterministic ZIP ordering/timestamps and package hashes support reproducibility for a fixed audited input; dependency repositories and toolchain containers are versioned baselines, not a claim of bit-identical rebuilding forever. Source Download ZIP needs a build; ready binaries are Actions artifacts. Normal CI never commits binaries or publishes based on historical marker files.

Publication is manual for an explicit existing tag. It rebuilds/tests that exact tag and requires separate exact-archive/source evidence for Zorin, Q4OS, the older runtime and builder, including performance and hashed logs. Xvfb cannot substitute for the two target desktops. Dirty/dev/static/new-ABI/mismatched or incomplete evidence is rejected. Existing assets are not overwritten. ARM64, musl/Alpine and Wayland need separate implementations/builds/tests and are not advertised.

Native code is split into app/config/images/input/clipboard/UI/i18n modules; Portuguese public entrypoints and the legacy settings include remain compatible. Existing Trinity and XFCE state schemas are retained, including recovery of interrupted older operations.

Both catalogs have **613 matching messages** covering native UI/help/errors, Bash/Python setup/configuration/uninstall and diagnostics. The generator rejects missing/duplicate/blank keys, incompatible braces/printf specifiers, unknown source IDs and stale generated tables. Locale precedence is PRINT_RC_LANG → saved config/language → LC_ALL → LC_MESSAGES → LANG → English. Native fixed-font X11 labels convert supported Portuguese accents without loading Qt/GTK. Both languages have equivalent documentation. CLI flows, help and native label properties are tested; final visual wording/font acceptance on the two real desktops is pending.

## Installation, migration and external changes

Run the candidate as a normal user: `bash instalar.sh`, `bash configurar.sh --language en-US` (or `pt-BR`), `bash configurar-tecla.sh`, `bash iniciar.sh`. Keep the extracted folder or explicitly choose a move. Do not overwrite an existing installation; keep its captures/backups/state, extract the candidate separately, and use the old uninstaller's preview before confirming cleanup. Older absolute save_dir settings are understood. New internal destinations use save_dir_relative; explicit external image folders remain user-owned.

After moving/renaming the folder, run `bash configurar-tecla.sh --relocate` from its new location. It previews and repairs recorded app-owned launcher/output paths, compares external ownership and journals before writing. It preserves third-party edits and keeps recovery metadata on interruption. Spaces, accents, parentheses and public-wrapper symlink paths are covered; unexpected internal symlinks are refused.

The only automatic desktop integrations are the selected XFCE xfce4-keyboard-shortcuts custom property (normally persisted by xfconf in the user's session configuration) or Trinity's selected action/trigger in `$TDEHOME/share/config/khotkeysrc` / `~/.trinity/share/config/khotkeysrc`. Prior values, exact external references and backups live in the application folder. No XFCE global override setting, keymap, XKB file, system config, dependency package or desktop process is forcibly changed. Manual shortcuts on other desktops must be removed manually. An explicitly chosen screenshot folder is the other possible external destination and is never uninstallable app data.

`bash desinstalar.sh` previews deletion, restores only still-owned shortcut changes and removes only inventoried unchanged app files. Captures, unknown files, modified app files and foreign shortcut changes survive. Modified files can intentionally leave the folder/backups behind; an original download ZIP outside the folder also remains. The inventory does not grant ownership over captures or symlink targets. Helper scripts suppress Python bytecode so ordinary use does not create untracked cache residue.

`bash diagnosticar.sh --read-only` observes OS/session/ELF/config and known shortcut registry files. It never executes the capture binary, calls xfconf-query/DCOP, creates a report, grabs input, injects keys or starts a daemon. JSON code/schema fields stay stable; explanations follow the selected locale and personal paths are redacted. Explicit `--output /new/report.json` is a separate writing mode, disclosed and exclusive/no-clobber. Tests snapshot contents/mtimes and use a fake executable sentinel to prove non-execution/non-mutation.

## Tests and exact commands

On an isolated developer/test machine with the documented tools:

```bash
make -B all
python3 -B scripts/build/locales.py --check
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s tests -v
bash -n ./*.sh scripts/*.sh tests/*.sh
# Run as an ordinary user; this explicitly opens test windows and sends test input.
bash tests/run.sh
# Build/audit on the baseline environment, not a newer developer host.
make -B portable
python3 -B scripts/build/manifest.py --output dist/build-manifest.json --max-glibc 2.31 --max-glibcxx 3.4.28
python3 -B packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-linux-x86_64-glibc.zip
(cd dist && sha256sum -c Print-RC-linux-x86_64-glibc.zip.sha256)
```

See the workflows for the exact container invocations and log artifacts. Package dependencies are installed in CI/developer environments only.

| Scope | Result and practical limit |
| --- | --- |
| Original baseline | 42 original Python tests passed before refactoring. Existing screenshot/keyboard/clipboard/lifecycle tests were retained. |
| Current Python suite | 68 tests passed locally on Ubuntu 24.04/glibc 2.39; includes negative release gates, localization, ownership, relocation and read-only behavior. |
| Recorded packaged matrix | All five jobs passed in run 39695994801: audited builder, Ubuntu 20.04, Ubuntu 22.04, Debian 13 and real XFCE-services substitute. That earlier checkpoint had 62 Python tests; later head checks rerun the expanded suite. |
| Overlay/input | Mapped/dimmed-pixel and nonce assertions, both input grabs, competing-grab failures, Escape/right/close cancellation, one active instance and cleanup; 16/24-depth, both languages. |
| Capture/PNG | Area/fullscreen, pen/undo pixel equality, odd 301×173 geometry and exact RGBA checks; 24-depth commonly exercises 32-bpp storage. A native 32-bit root depth was unavailable. |
| Clipboard | Multi-megabyte INCR PNG equality, failed disk write with paste retained, old-owner exit, 16 concurrent transfer limit, overflow rejection and destroyed-client slot recovery. |
| Keys/adapters | Print/Insert independence; letters, Return, F9/F12, modifier/timeout/release handling; original Trinity schema recovery plus XFCE mocks; real xfsettingsd Insert→PNG→restore in isolated services. |
| Lifecycle | Non-root install/config/uninstall, English flow/Portuguese preference, spaces/accents/parentheses, relocation interruption, preinstall/unknown/modified files, symlinks and concurrent foreign edits preserved. |
| Sanitizers | Local AddressSanitizer + UndefinedBehaviorSanitizer mapped/cancelled and saved a 16-depth odd-size PNG with no reported error (`ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1`). LeakSanitizer could not inspect this sandbox's process namespace; no leak-check success is claimed. |
| Not demonstrated | Real Zorin/Q4OS acceptance; multi-monitor/negative-coordinate/scaling layouts; low-power physical Intel laptop; Wayland, ARM64, musl or every registry distribution. |

A local container runs as root and restricts Unix sockets and child /proc views. Installer/uninstaller suites therefore ran as a normal user in CI; local Xvfb used loopback TCP. The root safety checks were retained. Local newer-host builds are development binaries, not baseline release artifacts.

## Resource measurements

PNG conversion now uses a row buffer and encodes once, rather than staging a full RGBA image and encoding twice. XImage geometry/stride/bpp/masks/allocation bounds are checked. Before clipboard residency, the capture X11 connection is closed, pen data is released and glibc free arena pages are returned with one malloc_trim(0), without changing allocator tunables. Native clipboard ownership retains only compressed PNG, blocks on X11 events until replacement/30-minute expiry and allows at most 16 INCR transfers. Screenshot pixel buffers are freed before waiting. Without clipboard ownership no Print RC process remains after completion; setup Python does not run continuously. The supervisor exits after the ownership stage, leaving one native owner.

The same-host development benchmark used Ubuntu 24.04/glibc 2.39, Xvfb 24-depth over loopback TCP, white root pixels, five captures per build/resolution and direct native core binaries. The original shipped static v0.5.6 happened to run on this developer host. The measured dynamic checkpoint preceded the final catalog-only update; its exact binary hash is in each raw JSON. This is not a measurement of a Q4OS/Zorin machine or every final ZIP. All three resolution pairs are retained in `compat/test-results/development-performance/`.

| Resolution | Original static median / p95 ms | Row-PNG dynamic median / p95 ms | CPU median original → dynamic seconds | Peak RSS original → dynamic KiB |
| --- | --- | --- | --- | --- |
| 1366×768 | 199.9 / 299.1 | 97.6 / 148.3 | 0.1559 → 0.0639 | 13824 → 13824 |
| 1920×1080 | 385.5 / 748.5 | 159.5 / 306.2 | 0.3425 → 0.1085 | 20484 → 19036 |
| 3840×2160 | 1485.5 / 2452.7 | 623.6 / 876.4 | 1.4548 → 0.5654 | 69104 → 67648 |

These five-sample p95 values are sample maxima and wall time is noisy in a shared environment; preliminary cohorts also had large scheduling outliers. Local PSS, clipboard residual RSS/PSS and idle ticks are null because child /proc data was unavailable, never zero. CPU/RSS above come from wait4. They cover the capture core, excluding transient supervisor/system X server costs. Compression level 3 deliberately trades larger PNG files for lower CPU/latency (in the CI white 4K fixture, 150,581 vs 37,549 bytes in the old-source dynamic build); pixels remain lossless. The fixture is low-entropy; PNG byte sizes and full raw samples are retained. The CI resource step compares the exact candidate to unchanged-source v0.5.6 rebuilt dynamically on the same Ubuntu 22.04/glibc 2.35 host, because its shipped static original crashes there. Both baseline identities and limits must remain explicit. Actual Q4OS/Zorin/low-power/two-monitor acceptance and ≤20% host regression checks remain pending.

## Remaining acceptance and risks

Keep the PR as a draft and issue #1 open until an actual Zorin 17.3 XFCE/glibc 2.35 and Q4OS/Trinity machine tests the **same intended release archive**: installer, physical Insert and Print, visible dimmed toolbar, area/fullscreen, annotation/undo, Escape, saved PNG, Ctrl+V/INCR, selected-key recovery, relocation and safe uninstall. Attach redacted OS/desktop/library versions, binary/build/archive hashes, logs and five-run latency/CPU/RSS/PSS data. Test the requested Intel laptop resolutions, 4K and two monitors. Release evidence cannot be copied from a different archive.

Dynamic linking intentionally requires compatible host libraries; missing libraries must be resolved by the user/distribution, never by an unprompted system mutation. Unexpected visuals/sizes are rejected instead of assumed supported. Foreign edits can prevent automatic restoration; backups remain for recovery. Fixed-font Portuguese labels need actual-desktop visual confirmation. General Wayland/portal, ARM64 and Alpine support is future work, not a hidden fallback.

## Changed-file inventory

A = added, M = modified, D = removed from this branch. Historical v0.5.6 assets are preserved. Evidence files are repository review material and are excluded from runtime ZIPs to avoid circular archive hashes and needless package size.

| Change | File | Purpose |
| --- | --- | --- |
| A | `.github/workflows/build.yml` | Build GNU candidate on Ubuntu 20.04; audit ABI and upload checksummed ZIP. |
| A | `.github/workflows/release.yml` | Explicit tagged publication only after archive tests and separate host evidence; refuse asset overwrite. |
| A | `.github/workflows/test.yml` | Test exact ZIP on three libc runtimes; real XFCE services, GDB comparison and resource measurements. |
| M | `.github/workflows/testar.yml` | Coordinate build/test with read-only permissions; no automatic binary commit or publication. |
| M | `.gitignore` | Ignore generated binaries, builds, logs and runtime user state. |
| A | `CHANGELOG.md` | English summary of unreleased phased changes and acceptance limits. |
| A | `CHANGELOG.pt-BR.md` | Equivalent Brazilian Portuguese changelog. |
| M | `Makefile` | Dynamic default/portable targets, locale checks and debug build; compile native supervisor. |
| M | `README.md` | English entrypoint with honest candidate status, package/run instructions and documentation links. |
| A | `README.pt-BR.md` | Equivalent Brazilian Portuguese entrypoint and operating instructions. |
| A | `VERSION` | Mark 0.6.0-dev as an unreleased candidate. |
| D | `bin/print-rc` | Remove generated legacy binary from current source branch; original tag/assets remain intact. |
| A | `compat/linux-targets.json` | Record per-target evidence and untested status without universal compatibility claims. |
| A | `compat/test-results/ci-39695994801/Print-RC-linux-x86_64-glibc.zip.sha256` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/binary-sha256.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/build-manifest.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/evidence-index.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/legacy-build-id.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/legacy-gdb.log` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/legacy-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/libc.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/original-dynamic-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/os-release.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/shortcut-proof.log` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39695994801/xfce-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/Print-RC-linux-x86_64-glibc.zip.sha256` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/binary-sha256.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/build-manifest.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/evidence-index.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/legacy-build-id.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/legacy-gdb.log` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/legacy-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/libc.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/original-dynamic-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/os-release.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-candidate-1366x768.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-candidate-1920x1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-candidate-3840x2160.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-1366x768.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-1920x1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance-original-dynamic-3840x2160.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/performance.log` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/shortcut-proof.log` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/ci-39697099560/xfce-result.txt` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/dynamic-1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/dynamic-2160.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/dynamic-768.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/evidence-index.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/perf-post-1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/perf-pre-1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/perf-static-1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/static-1080.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/static-2160.json` | Retained checksummed test evidence; excluded from runtime archives. |
| A | `compat/test-results/development-performance/static-768.json` | Retained checksummed test evidence; excluded from runtime archives. |
| M | `configurar-tecla.sh` | Preserve selectable keys and independent Print/Insert; offer owned-path relocation repair. |
| M | `configurar.sh` | Persist selected language and internal relative image destination; track generated settings safely. |
| M | `desinstalar.sh` | Verify inventory, preserve changed/unknown files and restore only still-owned integrations; avoid bytecode residue. |
| A | `diagnosticar.sh` | Public compatibility wrapper for observation-only diagnosis and explicit report output. |
| A | `docs/en-US/COMPATIBILITY.md` | ABI/runtime/desktop distinctions and untested platforms. |
| A | `docs/en-US/DEVELOPMENT.md` | Build, locale, regression, packaging and release procedures. |
| A | `docs/en-US/IMPLEMENTATION.md` | This phased report, file inventory, evidence, measurements and remaining acceptance. |
| A | `docs/en-US/INSTALL.md` | Install/extract/dependency/shortcut disclosures. |
| A | `docs/en-US/PRIVACY.md` | Local state, report redaction, external references and no telemetry. |
| A | `docs/en-US/RELEASE.md` | Release-summary template with actual-host acceptance blockers. |
| A | `docs/en-US/TROUBLESHOOTING.md` | Diagnosis, evidence limits, stable errors and safe recovery. |
| A | `docs/en-US/UNINSTALL.md` | Preview, ownership, user-data preservation and cleanup limitations. |
| A | `docs/en-US/USER_GUIDE.md` | Capture/pen/undo/clipboard/key/language usage. |
| A | `docs/pt-BR/COMPATIBILITY.md` | ABI/runtime/desktop distinctions and untested platforms. |
| A | `docs/pt-BR/DEVELOPMENT.md` | Build, locale, regression, packaging and release procedures. |
| A | `docs/pt-BR/IMPLEMENTATION.md` | This phased report, file inventory, evidence, measurements and remaining acceptance. |
| A | `docs/pt-BR/INSTALL.md` | Install/extract/dependency/shortcut disclosures. |
| A | `docs/pt-BR/PRIVACY.md` | Local state, report redaction, external references and no telemetry. |
| A | `docs/pt-BR/RELEASE.md` | Release-summary template with actual-host acceptance blockers. |
| A | `docs/pt-BR/TROUBLESHOOTING.md` | Diagnosis, evidence limits, stable errors and safe recovery. |
| A | `docs/pt-BR/UNINSTALL.md` | Preview, ownership, user-data preservation and cleanup limitations. |
| A | `docs/pt-BR/USER_GUIDE.md` | Capture/pen/undo/clipboard/key/language usage. |
| A | `i18n/README.md` | Document source catalogs, precedence and regeneration checks. |
| A | `i18n/en-US.json` | 613 English reference messages, including CLI/GUI/install/errors/diagnostics. |
| A | `i18n/pt-BR.json` | 613 matching Brazilian Portuguese translations with placeholder parity. |
| M | `iniciar.sh` | Validate target/session/config, use signal supervisor and nonce-matched rendered-overlay proof. |
| M | `instalar.sh` | Keep or move one folder, disclose integration, track owned files and leave activation pending until proof. |
| A | `packaging/portable/package.py` | Deterministic one-directory ZIP, exact binary audit hashes, package index and runtime target metadata. |
| M | `scripts/atalho.py` | Preserve Trinity schema/legacy recovery; localization, ownership checks, concurrency safety and relocation journal. |
| M | `scripts/atalho_xfce.py` | Preserve XFCE custom/default bindings; compare before mutation, track original values and localize helper. |
| A | `scripts/build/locales.py` | Validate complete catalogs, duplicate keys/placeholders/specifiers and generated native/Bash tables. |
| A | `scripts/build/manifest.py` | Record source/compiler/libc/ELF dependencies, build IDs, symbol versions, sizes and hashes; enforce ABI ceiling. |
| A | `scripts/build/release_gate.py` | Reject missing/wrong artifact or desktop/performance evidence, static libc, new ABI and unsafe evidence paths. |
| A | `scripts/diagnose.py` | Observe/redact OS, session, ELF, config and shortcut state; no binary execution or daemon activation. |
| A | `scripts/i18n.sh` | Select locale and format catalog values as data, without eval. |
| M | `scripts/inventario.sh` | Fixed application-file allowlist, expected package hashes and safe updates of generated settings. |
| A | `scripts/lifecycle.py` | Validate owned paths/indexes; atomically record truthful install state and external integration references. |
| A | `scripts/messages.bash` | Generated quoted bilingual Bash catalog. |
| A | `scripts/print_rc_i18n.py` | Shared helper locale selection, translations and localized argparse help. |
| M | `scripts/provar-atalho.sh` | Arm an exclusive instance token and accept only matching rendered/input-ready proof; safe token cleanup. |
| A | `scripts/relocate.py` | Repair recorded app-owned paths after moving; preserve foreign edits and journal interruptions. |
| A | `src/app/launcher.cpp` | Small signal-monitor parent; propagate status and exit when clipboard owns the PNG. |
| A | `src/app/runtime.hpp` | Optional inherited status channel with explicit X11/ready/save/clipboard stages. |
| A | `src/clipboard/owner.hpp` | Event-driven compressed-PNG owner; bounded INCR, request-size guards, replacement/expiry cleanup. |
| A | `src/config/settings.hpp` | Validate settings and resolve portable relative image directories without unsafe traversal/symlinks. |
| A | `src/i18n/generated.hpp` | Generated embedded bilingual native message table. |
| A | `src/i18n/messages.hpp` | Native locale precedence and X11 fixed-font label conversion without a GUI framework. |
| A | `src/images/png.hpp` | Single-pass row PNG encoding, one-row conversion buffer, visual masks and safe allocation/error handling. |
| A | `src/input/keyboard.hpp` | Extract key detection and probe selected keys while preserving physical Print/Insert distinction. |
| M | `src/main.cpp` | Retain native capture UI; guard XImage/geometry, prove actual mapping/drawing/grabs and separate disk/clipboard status. |
| M | `src/settings.hpp` | Keep compatibility include forwarding to the organized configuration module. |
| A | `src/ui/drawing.hpp` | Extract pen/annotation rasterization without changing undo behavior. |
| A | `src/ui/geometry.hpp` | Extract rectangle/stroke and geometry helpers. |
| A | `tests/performance/README.md` | Reproducible benchmark commands, baseline limitations and metric interpretation. |
| A | `tests/performance/benchmark.py` | Measure five repetitions, wall/CPU/RSS/PSS/clipboard state and record hashes/host limitations. |
| A | `tests/performance/compare.py` | Guard same-host CPU/p95/PSS regressions and bounded idle clipboard memory using measured cohorts. |
| A | `tests/performance/x11_driver.cpp` | Explicit test-only painting, real overlay detection, fullscreen/cancel input and dimensions. |
| A | `tests/run.sh` | Run syntax, Python, shell, native and isolated Xvfb packaged regressions as a normal user. |
| M | `tests/test_atalho.py` | Preserve Trinity unit regressions after helper module/locale changes. |
| A | `tests/test_clipboard_limits.cpp` | Exercise 16 INCR slots, overflow rejection and destroyed-client recovery. |
| A | `tests/test_clipboard_limits_x11.sh` | Build/run bounded INCR regression on real X11. |
| M | `tests/test_clipboard_x11.sh` | Preserve byte-identical INCR and test failed disk save plus owner replacement. |
| M | `tests/test_configuracao.sh` | Check relative internal output path and existing settings invariants. |
| M | `tests/test_configurar_tecla.sh` | Keep original key configuration regressions under isolated locale. |
| M | `tests/test_desinstalacao.sh` | Keep data-preserving uninstall regressions under isolated locale. |
| M | `tests/test_desinstalacao_processo_x11.sh` | Verify process cleanup/data preservation after real X11 capture. |
| M | `tests/test_detectar_print_x11.sh` | Preserve physical key detection and selected F12 probing independent from Print. |
| M | `tests/test_gui_x11.sh` | Retain original area/fullscreen/pen/cancel/single-instance regression. |
| M | `tests/test_instalacao.sh` | Retain single-folder non-root install and update collision tests. |
| A | `tests/test_language_setup.sh` | Exercise English setup/uninstall, persisted Portuguese and explicit language override. |
| A | `tests/test_launcher.sh` | Inject controlled SIGFPE/SIGSEGV, verify 128+signal and readiness-stage reporting. |
| A | `tests/test_lifecycle.py` | Test truthful setup state, relocation/journals/concurrent edits, symlinks and observation-only diagnostics. |
| A | `tests/test_localization.py` | Test catalog/locale/docs parity, literal shell substitutions, native help and no helper bytecode residue. |
| A | `tests/test_overlay_ready.cpp` | Assert mapped dimmed pixels, both grabs, language property, nonce proof and cleanup. |
| A | `tests/test_packaged_ownership.sh` | Preserve preinstall modified files, unknown captures and interrupted relocation during uninstall. |
| M | `tests/test_prova_atalho.sh` | Distinguish process-start replies from matching rendered-overlay confirmation and token races. |
| A | `tests/test_release_gate.py` | Reject static/new-ABI/development/mismatched/Xvfb/NaN/path-escape evidence; validate complete fixture. |
| M | `tests/test_settings.cpp` | Validate relative output paths, old absolute settings, bounds and unsafe traversal. |
| A | `tests/test_undo_x11.sh` | Verify pen changes PNG pixels and undo returns exact pixels. |
| A | `tests/test_visual_png.sh` | Check exact white RGBA at odd 301×173 sizes and 16/24-depth visuals. |
| M | `tests/test_xfce_integracao.sh` | Keep simulated XFCE integration regressions and matching fake overlay proof. |
| A | `tests/test_xfce_real.sh` | Run real xfsettingsd Insert launch/save/restore with Print preserved; GDB original-static/dynamic comparison. |
