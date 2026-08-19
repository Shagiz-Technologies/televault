# Release Process

TeleVault does not currently have automated production publishing. This
document defines the intended maintainer process without configuring signing or
store credentials.

## Preconditions

- `main` is protected and all required checks pass.
- The release scope and migration impact are reviewed.
- Privacy, permission, encryption, and store-facing claims match the code.
- Native binary provenance, licensing, ABI coverage, and 16 KB compatibility
  are verified for the artifact being released.
- No unresolved release-blocking security or data-integrity issue remains.
- Production signing material is available outside Git and is controlled by a
  maintainer.

## Versioning

Update `version` in `pubspec.yaml` using `major.minor.patch+build`. The Flutter
version name and build number feed Android and supported platform metadata.
Document user-visible changes in `CHANGELOG.md`.

## Candidate validation

From a clean checkout of the intended commit:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

Build production artifacts only in a protected maintainer environment with
approved credentials. Do not expose Telegram API values, keystores, key
passwords, or Play credentials in logs or artifacts.

Validate the final signed artifact, merged manifest, application ID, version,
permissions, native libraries, and supported Android versions. Test critical
login, sync, interruption, vault, restore, logout, and deletion flows on
physical devices.

## Publication

1. Upload the exact validated Android App Bundle to a protected internal testing
   track.
2. Complete internal testing and review Play Console declarations.
3. Promote the same tested artifact through the approved rollout path.
4. Create an immutable semantic-version tag such as `v1.2.0` for the released
   commit.
5. Publish release notes without attaching secrets, sessions, databases, user
   media, or unapproved unsigned builds.

A merge into `main` is not a release. A GitHub tag is not evidence that Google
Play accepted or published an artifact.

## Rollback

Stop a staged rollout when crash, data-integrity, authentication, upload,
restore, permission, or security gates fail. Prepare a new version and build
number for corrective releases; do not overwrite published tags or artifacts.
