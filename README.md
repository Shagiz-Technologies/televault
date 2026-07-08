# TeleVault

TeleVault is a privacy-first Android media backup and vault app built with Flutter. It lets a user connect their own Telegram account, create private Telegram channels as backup buckets, organize local media, and protect selected items in a vault.

TeleVault is an independent project by Shagiz Technologies. It is not affiliated with, endorsed by, or sponsored by Telegram.

## Why it exists

Many people already use gallery apps such as Google Photos because the experience is simple: open the app, see the library, and trust that backup is happening in the background. TeleVault aims to bring that same simple media-library experience to users who want to use storage they control through their own Telegram account instead of sending files to a TeleVault-operated backend.

This repository does not include a TeleVault backend server.

## Current features

- Telegram login through TDLib/libtdjson.
- Private Telegram channel buckets for media backup.
- Android gallery scanning for photos and videos.
- Library-first UI with albums, vault, settings, selection, labels, filters, and media previews.
- Backup status indicators for queued, uploading, synced, failed, vaulted, and deleted-local states.
- Bucket preferences for media type selection and sync behavior.
- Vault lock/unlock support with a Vault PIN or password and device biometric authentication where supported.
- Vault-protected media encryption flow for items moved into the vault.
- Manual metadata export/import using encrypted `.tvmeta` packages.
- Safe Uninstall flow that uploads pending media first and uploads encrypted metadata last to the active Telegram bucket.
- Local operational diagnostics screens. No external analytics or telemetry SDK was found during the open-source preparation audit.

## What is encrypted

- Vault-protected media is encrypted by TeleVault before being stored as vaulted content.
- Metadata backup packages are encrypted with a user passphrase and are bound to the Telegram account recorded in the package.
- Normal non-vault media backups are not client-side encrypted by TeleVault in the current implementation. They are sent to Telegram as regular media/files using the user's Telegram account and private bucket channel.

If you need all-media client-side encryption, treat that as future work and do not assume it exists today.

## Privacy model

TeleVault stores app metadata locally using Drift/SQLite so it can track files, buckets, labels, sync status, retry state, vault state, and backup history. The app sends media to private Telegram channels controlled by the logged-in Telegram account.

TeleVault does not operate a backend server in this repository. Telegram and TDLib still process the Telegram account login, channel access, and uploaded files. Review Telegram's terms and privacy policy before using Telegram as a storage backend.

## Android permissions

TeleVault currently requests these Android permissions:

- `INTERNET`: required for Telegram login and backup upload/download.
- `READ_MEDIA_IMAGES`: read image media on Android 13 and newer.
- `READ_MEDIA_VIDEO`: read video media on Android 13 and newer.
- `READ_EXTERNAL_STORAGE` with `maxSdkVersion=32`: read media on older Android versions.
- `ACCESS_MEDIA_LOCATION`: access original media location metadata when Android allows it. This should be reviewed before Play Store release because it is privacy-sensitive.
- `USE_BIOMETRIC` and `USE_FINGERPRINT`: allow device biometrics for app/vault unlock flows where supported.

Android 14+ selected-photos access (`READ_MEDIA_VISUAL_USER_SELECTED`) still needs a dedicated implementation review.

## Supported platforms

Android is the current supported release target. Flutter-generated iOS, macOS, Linux, Windows, and web folders may exist in this repository, but they are not release-supported yet.

## Build from source

Prerequisites:

- Flutter stable SDK matching the `pubspec.yaml` SDK constraint.
- Android Studio or Android command-line tools.
- A Telegram API ID and API hash from Telegram's developer portal.
- TDLib/libtdjson native binaries included under `third_party/libtdjson`.

Install dependencies:

```bash
flutter pub get
```

Run in debug mode with local Telegram credentials:

```bash
flutter run \
  --dart-define=TELEGRAM_API_ID=YOUR_TELEGRAM_API_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_TELEGRAM_API_HASH
```

Build a release APK locally:

```bash
flutter build apk --release \
  --dart-define=TELEGRAM_API_ID=YOUR_TELEGRAM_API_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_TELEGRAM_API_HASH
```

Do not commit real credentials, `.env` files, keystores, signing files, release APKs/AABs, local databases, Telegram sessions, or user backups.

## Release signing

Use `android/key.properties.example` as a template for local signing setup. Keep the real `android/key.properties` and keystore file outside Git.

## Third-party native dependency

TeleVault uses the vendored `third_party/libtdjson` Flutter plugin for TDLib JSON/FFI integration. The vendored plugin metadata points to `https://github.com/up9cloud/flutter_libtdjson` and includes an MIT license. Native `libtdjson.so` binaries are included for Android ABIs.

Before a Play Store production release, verify native binary provenance, TDLib licensing requirements, and Android 15+ 16 KB page-size compatibility.

## Current limitations

- Android is the only supported release target today.
- Normal non-vault uploads are not encrypted by TeleVault before upload.
- Full media restore UX is not yet presented as a completed, polished flow.
- Google Drive backup code exists in the tree as an experimental prototype and should be documented or removed before broader release.
- The project has not yet completed a Play Store compliance review.

## Contributing

Read `CONTRIBUTING.md` before opening pull requests. Privacy, permissions, encryption, login, sync, and restore changes need careful review and Android testing.

## Security

Read `SECURITY.md` for vulnerability reporting guidance. Do not open public issues containing secrets, credentials, personal metadata, or exploit details.

## Roadmap

See `ROADMAP.md` for planned work and known release-readiness items.

## License

TeleVault is licensed under the MIT License. See `LICENSE`.

