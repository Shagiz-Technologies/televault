# libtdjson vendored plugin

This directory contains a vendored Flutter plugin for TDLib/libtdjson JSON/FFI integration.

Upstream metadata from the plugin package:

- Package name: `libtdjson`
- Version: `0.2.2`
- Repository: `https://github.com/up9cloud/flutter_libtdjson`
- License: MIT, included in `LICENSE`

TeleVault keeps this vendored copy so Android builds can resolve the TDLib binding from a stable local path. Native Android `libtdjson.so` binaries are stored under `android/src/main/jniLibs`.

Before production distribution, verify native binary provenance, TDLib licensing requirements, and Android 15+ 16 KB page-size compatibility.
