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
