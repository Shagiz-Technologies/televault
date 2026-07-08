# Contributing

Thanks for helping improve TeleVault. This project handles private media, Telegram sessions, and metadata, so changes must be reviewed with privacy and data integrity in mind.

## Development setup

```bash
flutter pub get
flutter analyze
flutter test
```

Run locally with placeholder or personal Telegram credentials supplied through dart-defines. Do not commit real credentials.

```bash
flutter run \
  --dart-define=TELEGRAM_API_ID=YOUR_TELEGRAM_API_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_TELEGRAM_API_HASH
```

## Pull request expectations

- Keep changes scoped.
- Add or update tests for behavior changes.
- Include screenshots for UI changes.
- Document Android permission changes.
- Be explicit about privacy, encryption, login, sync, vault, and restore impact.
- Do not include generated release artifacts, local databases, user media, credentials, or signing files.

## Code style

Run:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Documentation accuracy

Do not claim security or privacy behavior that the code does not implement. In particular, do not claim all media is client-side encrypted unless that feature is actually implemented and tested.
