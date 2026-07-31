# NOTICE

TeleVault
Copyright (c) 2026 Shagiz Technologies

TeleVault is licensed under the MIT License. See `LICENSE`.

## Telegram and TDLib

TeleVault is an independent project. It is not affiliated with, endorsed by, or sponsored by Telegram.

The app integrates with Telegram through TDLib/libtdjson. TDLib is a third-party Telegram client library licensed under the Boost Software License 1.0. A copy is included at `third_party/libtdjson/TDLIB_LICENSE_1_0.txt`.

## Vendored libtdjson Flutter plugin

This repository includes `third_party/libtdjson`, a Flutter plugin for TDLib JSON/FFI integration.

The vendored plugin metadata references:

- Homepage: `https://github.com/up9cloud/flutter_libtdjson`
- Repository: `https://github.com/up9cloud/flutter_libtdjson`
- License: MIT, included at `third_party/libtdjson/LICENSE`

Native Android `libtdjson.so` binaries are built from pinned official TDLib source and included under `third_party/libtdjson/android/src/main/jniLibs`. Exact source/toolchain provenance and SHA-256 hashes are recorded in `third_party/libtdjson/android/TDLIB_BUILD_PROVENANCE.txt` and `docs/android-release-16kb.md`.

The Android TDLib build statically links OpenSSL 3.5.7 LTS. Its Apache License 2.0 is included at `third_party/libtdjson/OPENSSL_LICENSE.txt`.

iOS builds resolve the upstream `flutter_libtdjson` `1.8.65` CocoaPod, which provides the TDLib `1.8.65` static XCFramework. The native binary is downloaded by CocoaPods during the macOS build and is not committed to this repository. Physical-device Telegram login, upload, and restore still require release validation before iOS can be declared production-supported.
