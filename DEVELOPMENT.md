# TeleVault Development

This guide describes the currently verified development baseline. TeleVault is
Android-first; other generated Flutter platforms are not production-supported.

## Toolchain

The repository was validated with:

- Flutter `3.38.9` stable.
- Dart `3.10.8`; `pubspec.yaml` accepts Dart `^3.10.4`.
- Java 17 language and bytecode compatibility in the Android project.
- JDK 21 from Android Studio for the most recent local validation.
- Android SDK 36 and Build Tools 36.1.0 for that validation environment.

Use Flutter `3.38.9` when reproducing CI or release-readiness results. The
Android project currently inherits its compile SDK, target SDK, minimum SDK,
and NDK version from the selected Flutter SDK. Before a production release,
record the resolved values from the final artifact and build environment rather
than assuming them from this document.

## Native TDLib dependency

Telegram integration uses the vendored Flutter plugin under
`third_party/libtdjson`. Android native `libtdjson.so` files are committed for
multiple ABIs. Their exact native source revision, build environment, and
16 KB page-size status are not established by the repository.

Read [`docs/NATIVE_BINARY_PROVENANCE.md`](docs/NATIVE_BINARY_PROVENANCE.md)
before changing or distributing these binaries. Do not replace them without
documented source, reproducible build instructions, checksums, license review,
and device testing.

## Configuration

Install Flutter packages:

```bash
flutter pub get
```

Telegram API credentials are compile-time Dart defines:

```bash
flutter run \
  --dart-define=TELEGRAM_API_ID=YOUR_API_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_API_HASH
```

`.env.example` is a placeholder reference only. The application does not load a
repository `.env` file at runtime. Never commit real Telegram credentials.

Tests use non-secret placeholders:

```bash
flutter test \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

## Validation

Run before opening a pull request:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

When Drift or generated models intentionally change:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Review generated changes before committing them.

## Android builds

Create a local debug APK:

```bash
flutter build apk --debug \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

Release signing uses an untracked `android/key.properties` file and an
untracked keystore. See `android/key.properties.example`. Public CI must not
receive or use production signing material.

## Repository safety

Do not commit:

- `.env` files or real API credentials.
- `android/local.properties`, `android/key.properties`, or keystores.
- Telegram sessions, authorization data, phone numbers, or account metadata.
- APKs, AABs, build directories, generated release packages, or signing
  checksums.
- Local SQLite databases, metadata backups, personal media, captures, or
  unredacted logs.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`docs/CONTRIBUTION_WORKFLOW.md`](docs/CONTRIBUTION_WORKFLOW.md) for the change
process.
