# libtdjson vendored plugin

This directory contains a vendored Flutter plugin for TDLib/libtdjson JSON/FFI integration.

Upstream metadata from the plugin package:

- Package name: `libtdjson`
- Version: `0.2.2`
- Repository: `https://github.com/up9cloud/flutter_libtdjson`
- License: MIT, included in `LICENSE`

TeleVault keeps this vendored copy so platform builds resolve the TDLib binding from a stable local path.

- Android `libtdjson.so` binaries are stored under `android/src/main/jniLibs`.
- iOS resolves `flutter_libtdjson` `1.8.65` through CocoaPods and links its static XCFramework into the Flutter plugin. Dart accesses those symbols through `DynamicLibrary.process()`.
- The manual iOS workflow rejects missing runtime dependencies, verifies TDLib FFI symbols, and launches the app on an iPhone simulator before packaging an IPA.

Before production distribution, verify native binary provenance, TDLib licensing requirements, Android 15+ 16 KB page-size compatibility, and Telegram login/upload behavior on physical iOS devices.
