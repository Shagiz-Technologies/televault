# iOS Feasibility Notes

TeleVault is Android-first. The iOS project is kept for local development and feasibility testing, not for App Store or TestFlight distribution.

## Current Status

- Android remains the supported release target.
- iOS is experimental and not production-ready.
- App Store and TestFlight distribution are not configured.
- Apple signing certificates, provisioning profiles, and App Store Connect automation are intentionally not included.

## What Can Be Tested Locally

These areas should be feasible to validate on iOS once the Flutter iOS toolchain is available on macOS:

- Flutter UI and navigation.
- Local Drift/SQLite metadata storage.
- Vault encryption and decryption logic.
- Secure local storage through iOS Keychain via `flutter_secure_storage`.
- Photo library browsing through `photo_manager`, subject to iOS permission behavior.
- Phone security and Face ID/biometric flows through `local_auth`, subject to device/simulator support.
- File import/export and share sheets through `file_picker` and `share_plus`.

## What Is Not Ready Yet

Telegram-backed features are blocked until iOS TDLib/libtdjson support is validated end to end:

- Telegram login.
- Bucket creation and switching.
- Upload and download.
- Background sync.
- Safe Uninstall metadata upload and restore.
- Production-grade metadata restore from Telegram channels.

The vendored `third_party/libtdjson` plugin includes iOS plugin metadata and a CocoaPods dependency on `flutter_libtdjson`, but TeleVault does not currently vendor or verify iOS `libtdjson` native binaries. Treat the iOS Telegram engine as pending.

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

Because the iOS Telegram engine is intentionally guarded as unavailable right now, the app should show a clear unsupported message for Telegram login instead of claiming backup is functional on iOS.
