# Compatibility

`compat/linux-targets.json` is a catalog of test targets, not a support claim. Each tested result must identify the actual OS, architecture, libc, desktop/protocol, libraries, archive hash, source commit, checks, timestamp and performance measurements. Null/unverified entries remain untested.

The primary candidate is x86_64 GNU/glibc, dynamically linked against system glibc/libstdc++/libX11/libpng16. CI builds in Ubuntu 20.04 on a pinned Ubuntu 22.04 runner and audits the actual GLIBC ≤ 2.31 and GLIBCXX ≤ 3.4.28 symbols. It runs the exact extracted ZIP under Ubuntu 20.04, Ubuntu 22.04/glibc 2.35 and Debian 13 containers with Xvfb. Container success does not establish installed-desktop compatibility.

Release blockers: actual Zorin 17.3 Lite/XFCE/X11/glibc 2.35, Q4OS/Trinity/X11, the older-libc runtime and builder baseline. Real VM/physical desktop evidence must verify shortcut launch/restoration and the full capture/clipboard flow. The published archive hash must match the tested one.

Wayland requires a separately implemented portal/compositor backend and permission model. ARM64 requires a separate build. Musl/Alpine requires a separate tested artifact. None is currently claimed. No system glibc replacement, bundled arbitrary loader, broad LD_LIBRARY_PATH override or dependency auto-install is used.
