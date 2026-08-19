# Contributing

Thanks for helping improve TeleVault. This project handles private media, Telegram sessions, and metadata, so changes must be reviewed with privacy and data integrity in mind.

Read [`GOVERNANCE.md`](GOVERNANCE.md),
[`DEVELOPMENT.md`](DEVELOPMENT.md), and
[`docs/CONTRIBUTION_WORKFLOW.md`](docs/CONTRIBUTION_WORKFLOW.md) before
contributing. Public contributors should work from a fork and submit pull
requests; public repository visibility does not grant push or merge access.

## Development setup

```bash
flutter pub get
flutter analyze
flutter test --dart-define=TELEGRAM_API_ID=0 --dart-define=TELEGRAM_API_HASH=placeholder
```

Run locally with placeholder or personal Telegram credentials supplied through dart-defines. Do not commit real credentials.

```bash
flutter run \
  --dart-define=TELEGRAM_API_ID=YOUR_TELEGRAM_API_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_TELEGRAM_API_HASH
```

## Branch and pull request workflow

1. Open or identify an issue for non-trivial changes.
2. Create a focused branch from the latest `main`.
3. Use a descriptive branch name such as:
   - `feature/42-background-sync`
   - `fix/57-upload-retry-loop`
   - `docs/contribution-guide`
4. Keep each pull request limited to one coherent change.
5. Open the pull request against `main` and complete the pull request template.
6. Resolve review comments and ensure all required checks pass.
7. Maintainers merge approved changes using squash merge.

Do not push directly to `main`. Production releases are created from semantic-version tags, not from every merge to `main`.

## Pull request expectations

- Keep changes scoped.
- Add or update tests for behavior changes.
- Include screenshots for UI changes.
- Document Android permission changes.
- Be explicit about privacy, encryption, login, sync, bucket, vault, restore, and deletion impact.
- Explain migrations, release notes, or Play Store review impact where applicable.
- Do not include generated release artifacts, local databases, user media, credentials, Telegram sessions, backup files, or signing material.

Changes affecting authentication, permissions, encryption, Telegram integration, native binaries, CI, signing, or release automation require code-owner review.

## Code style

Run:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --dart-define=TELEGRAM_API_ID=0 --dart-define=TELEGRAM_API_HASH=placeholder
```

## Documentation accuracy

Do not claim security or privacy behavior that the code does not implement. In particular, do not claim all media is client-side encrypted unless that feature is actually implemented and tested.

## Security reports

Follow [`SECURITY.md`](SECURITY.md). Do not open public issues containing vulnerabilities, exploit details, credentials, private metadata, personal media, or Telegram session information.
