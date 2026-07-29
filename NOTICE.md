# NOTICE

TeleVault
Copyright (c) 2026 Shagiz Technologies

TeleVault is licensed under the MIT License. See `LICENSE`.

## Telegram and TDLib

TeleVault is an independent project. It is not affiliated with, endorsed by, or sponsored by Telegram.

The app integrates with Telegram through TDLib/libtdjson. TDLib is a third-party Telegram client library. Review TDLib's upstream license and documentation before redistributing builds.

## Vendored libtdjson Flutter plugin

This repository includes `third_party/libtdjson`, a Flutter plugin for TDLib JSON/FFI integration.

The vendored plugin metadata references:

- Homepage: `https://github.com/up9cloud/flutter_libtdjson`
- Repository: `https://github.com/up9cloud/flutter_libtdjson`
- License: MIT, included at `third_party/libtdjson/LICENSE`

Native Android `libtdjson.so` binaries are included under `third_party/libtdjson/android/src/main/jniLibs`. Their exact build provenance and 16 KB page-size compatibility should be verified before production distribution.

iOS builds resolve the upstream `flutter_libtdjson` `1.8.65` CocoaPod, which provides the TDLib `1.8.65` static XCFramework. The native binary is downloaded by CocoaPods during the macOS build and is not committed to this repository. Physical-device Telegram login, upload, and restore still require release validation before iOS can be declared production-supported.

The Android binary inventory, checksums, known provenance, and unresolved
release blockers are recorded in
[`docs/NATIVE_BINARY_PROVENANCE.md`](docs/NATIVE_BINARY_PROVENANCE.md). The
vendored wrapper's MIT license does not by itself establish the exact source,
build, or complete redistribution record for the committed native binaries.
