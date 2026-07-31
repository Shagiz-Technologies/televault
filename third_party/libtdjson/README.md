# libtdjson vendored plugin

This directory contains a vendored Flutter plugin for TDLib/libtdjson JSON/FFI integration.

Upstream metadata from the plugin package:

- Package name: `libtdjson`
- Version: `0.2.2`
- Repository: `https://github.com/up9cloud/flutter_libtdjson`
- License: MIT, included in `LICENSE`

TeleVault keeps this vendored copy so platform builds resolve the TDLib binding from a stable local path.

- Android `libtdjson.so` binaries are stored under `android/src/main/jniLibs`. They are built from TDLib 1.8.66 commit `022d60202e446ad1287b9fb68e687c8a0760788b` using the pinned recipe at `tool/android/tdlib/Dockerfile`.
- iOS resolves `flutter_libtdjson` `1.8.65` through CocoaPods and links its static XCFramework into the Flutter plugin. Dart accesses those symbols through `DynamicLibrary.process()`.
- The manual iOS workflow rejects missing runtime dependencies, verifies TDLib FFI symbols, and launches the app on an iPhone simulator before packaging an IPA.

Android source/toolchain provenance and SHA-256 hashes are recorded in `android/TDLIB_BUILD_PROVENANCE.txt`. The release verifier checks 16 KB ELF alignment and GNU RELRO for all packaged native libraries. Telegram login/upload behavior still requires release testing on physical Android and iOS devices.
