# Explicit X11 resource benchmark

This is an interactive developer test: it paints an isolated X11 root, opens overlays, sends test input and saves temporary captures. It is never part of read-only diagnosis. Use Xvfb or a dedicated test desktop.

```bash
g++ -std=c++17 -O2 tests/performance/x11_driver.cpp -o /tmp/print-rc-perf-driver $(pkg-config --cflags --libs x11)
xvfb-run -a -s '-screen 0 1920x1080x24 -noreset' python3 -B tests/performance/benchmark.py --binary "$PWD/bin/print-rc" --driver /tmp/print-rc-perf-driver --repetitions 5 --label candidate --output /tmp/print-rc-performance.json
```

Repeat at 1366×768, 1920×1080 and 3840×2160 for both the baseline and candidate on the same machine. The workflow compiles unchanged v0.5.6 source dynamically for its glibc 2.35 baseline, because the shipped static executable crashes there. An old-source rebuild is a different baseline from the shipped binary; keep their identities explicit. Test the shipped baseline on the actual Q4OS host separately.

The JSON records OS, libc, architecture, CPU model/count, kernel, memory, resolution, script/driver/binary hashes, binary and PNG bytes, each of five samples, median/sample p95, CPU seconds, peak RSS/PSS, and the clipboard owner's residual memory and idle CPU ticks. RSS/CPU come from wait4; PSS is sampled every 5 ms only when /proc identifies the expected executable. Inaccessible counters are null, never zero. Five-sample p95 is the sample maximum. Capture elapsed time includes driver startup; clipboard elapsed time also includes PNG retrieval and the 200 ms idle sample. The idle interval is a short observation, not an endurance test.

The fixture has white low-entropy pixels. PNG compression level 3 trades larger PNGs for lower encoding latency; exact pixel equality is tested separately, including noncompressible INCR data. Resource numbers cover the native core, excluding transient launcher/system-X-server costs. CI machines and shared developer containers are not low-power laptop benchmarks or installed-desktop acceptance. See [English report](../../docs/en-US/IMPLEMENTATION.md) / [relatório em português](../../docs/pt-BR/IMPLEMENTATION.md) and the retained raw cohorts for scope, variance and pending hardware tests.
