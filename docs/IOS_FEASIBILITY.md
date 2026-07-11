# iOS Feasibility Notes

TeleVault is Android-first. The iOS project is kept for local development and feasibility testing, not for App Store or TestFlight distribution.

## Current Status

- Status: **iOS experimental: TDLib integration in progress**.
- Android remains the supported release target.
- iOS is experimental and not production-ready.
- The declared iOS deployment target is iOS 13.0 or newer.
- App Store and TestFlight distribution are not configured.
- Apple signing certificates, provisioning profiles, and App Store Connect automation are intentionally not included.
- The manual macOS workflow validates native dependencies and TDLib FFI symbols, then keeps TeleVault alive on an iPhone simulator before creating the unsigned IPA.

## What Can Be Tested Locally

These areas should be feasible to validate on iOS once the Flutter iOS toolchain is available on macOS:

- Flutter UI and navigation.
- Local Drift/SQLite metadata storage.
- Vault encryption and decryption logic.
- Secure local storage through iOS Keychain via `flutter_secure_storage`.
- Photo library browsing through `photo_manager`, subject to iOS permission behavior.
- Phone security and Face ID/biometric flows through `local_auth`, subject to device/simulator support.
- File import/export and share sheets through `file_picker` and `share_plus`.

## Telegram Engine Status

The iOS plugin resolves `flutter_libtdjson` `1.8.65` through CocoaPods and statically links TDLib into the plugin. Dart accesses its exported symbols through `DynamicLibrary.process()`, avoiding the standalone dylib launch failure found in the first experimental IPA.

The workflow verifies required native symbols, creates a TDLib client, executes a safe `getTextEntities` request, and keeps the app alive on the available GitHub-hosted iPhone simulator. These Telegram-backed flows still require end-to-end physical-device validation:

- Telegram login.
- Bucket creation and switching.
- Upload and download.
- Background sync and iOS suspension/resume behavior.
- Safe Uninstall metadata upload and restore.
- Production-grade metadata restore from Telegram channels.

The iOS TDLib native binary is downloaded from the upstream CocoaPod during the macOS build and is not vendored in this repository. Treat iOS as experimental until the physical-device checks above pass across the supported OS range.

On iOS, TDLib database and downloaded-file directories live under the app's private Application Support container. The database encryption key is generated with a secure random source and stored in iOS Keychain using `flutter_secure_storage`; the key is not logged or included in metadata exports.

## Local macOS Commands

Run these on a Mac with Xcode, CocoaPods, and Flutter installed:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --debug --no-codesign
```

For a connected iPhone, a free Apple ID may allow local debug deployment from Xcode for a limited provisioning period. A paid Apple Developer Program membership is not required for this feasibility phase, but it is required for normal App Store distribution.

```bash
flutter devices
flutter run -d <ios-device-id> \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

For a Telegram-capable private test build, configure `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` as GitHub Actions repository secrets before manually running the unsigned IPA workflow. Placeholder builds are suitable only for compilation and launch testing.
