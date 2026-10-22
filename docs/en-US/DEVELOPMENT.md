# Development and validation

Use a developer-controlled environment with C++17, make, pkg-config, X11/libpng development headers, binutils and Python 3. `make -B all` builds dynamically; `make debug` adds symbols and frame pointers. `make portable` strips the dynamic binaries. It does not link static glibc. Build tools are never installed on a user's machine by application scripts.

`python3 scripts/build/locales.py --check` rejects duplicate/missing/blank keys, placeholder mismatches, unsafe format specifiers and stale generated tables. Edit the two JSON catalogs, then run the generator. Native messages are embedded; Bash setup uses generated quoted data; Python helpers are short-lived.

The source is split into app lifecycle, configuration, image encoding, geometry/drawing, keyboard detection, clipboard ownership and localization modules. Portuguese public shell filenames and original shortcut state schemas are preserved.

On an isolated X11 test machine, as a normal user, run `bash tests/run.sh`. It includes original regression tests, adapter mocks, real Xvfb area/fullscreen/drawing/clipboard/INCR, 16/24-depth mapped/dimmed-overlay tests, competing grabs, signal injection and safe-uninstall cases. Synthetic input is never sent by read-only diagnostics. A 24-depth screen commonly uses 32-bpp storage; Xvfb may not offer 32-bit root depth.

Build auditing: `python3 scripts/build/manifest.py --output dist/build-manifest.json`. Package: `python3 packaging/portable/package.py --manifest dist/build-manifest.json --output dist/Print-RC-linux-x86_64-glibc.zip`. Host builds exceeding the ABI ceiling fail; never label a locally relaxed audit a portable release. Source tags, compiler/linker, build IDs, dependencies, symbols and hashes accompany candidates.

Release publication requires an explicit existing tag, passing archive regressions and separate exact-hash desktop/performance evidence. Existing assets are never overwritten, normal CI has read-only repository permission, and no binary is committed back into main. Future ARM/musl/Wayland work requires separately verified tracks.

## Recording release acceptance

The candidate remains `0.6.0-dev` and cannot publish. For a future reviewed release, set VERSION, commit the final source, create an explicit matching `v<VERSION>` tag, and build its candidate. Test that exact ZIP before dispatching release. Put acceptance records in a separate commit/ref so adding evidence cannot change the source tag/archive hash. The `evidence_ref` input selects that ref; the tagged source remains the code being built. If a rebuild differs, retest the new archive instead of changing the old evidence hash.

`compat/test-results/<target-id>.json` is required for each target in `scripts/build/release_gate.py`: Zorin 17.3 XFCE/glibc 2.35, Q4OS/Trinity, Ubuntu 20.04 X11 and the Ubuntu 20.04 builder. Each record must contain:

- `target`, `archive_sha256`, `git_commit`, `tested_at` and `test_kind` (`physical-desktop` or `virtual-machine-desktop` for Zorin/Q4OS).
- Measured `environment`: `os_release`, `architecture`, `protocol`, `desktop`, `libc`, `libc_version` and `libX11`. A newer host or Xvfb cannot be relabeled as the required desktop/baseline.
- Boolean `checks` for every name in `release_gate.CHECKS`. Only observed passing checks may be true; attach mapped/dimmed-overlay, screenshot/clipboard, keyboard, restoration and uninstall evidence.
- Numeric finite positive `performance`: `repetitions` (at least five), `latency_median_ms`, `latency_p95_ms`, `peak_rss_kib`, `peak_pss_kib`, `cpu_seconds`, `baseline_peak_pss_kib`, `baseline_latency_p95_ms`. Any >20% PSS/p95 regression needs a concrete `regression_justification`, raw samples and reviewer assessment. Include the requested resolutions, clipboard residual/idle observations and hardware details in the accompanying logs/report.
- `evidence_files`: objects with safe relative `path` and matching `sha256`. Files must resolve inside the evidence directory. Keep logs/screenshots redacted and identify baseline builds explicitly. Checked-in development cohorts are examples of measured data, not release acceptance records.

Run `python3 -B scripts/build/release_gate.py --archive <exact.zip> --manifest <build-manifest.json> --evidence-dir <acceptance/compat/test-results>` locally, then dispatch the release workflow with `tag` and `evidence_ref`. Publication also requires clean non-dev source, the dynamic ABI baseline and all archive jobs. Existing releases/assets are never overwritten. Passing a JSON schema is not a substitute for executing and reviewing its actual-host evidence.

The build checks that two ZIPs from identical audited input have identical bytes, and that all tracked corresponding source is present except intentionally excluded `compat/test-results/` evidence. Performance CI runs `tests/performance/compare.py` on same-host original-source-dynamic/candidate cohorts; it checks core CPU/p95/PSS regressions, no residual capture process, and clipboard PSS bounded by 8 MiB plus twice encoded PNG bytes. This is an isolated white-Xvfb fixture, not a hardware acceptance threshold for every image or machine.
