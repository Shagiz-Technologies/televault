# Security Policy

## Supported versions

This repository is preparing an initial open-source release. Until stable release tags exist, security fixes target the `main` branch.

## Reporting a vulnerability

Do not open a public issue containing secrets, personal metadata, credentials, exploit details, or private Telegram account information.

Preferred reporting path:

1. Use GitHub private vulnerability reporting if it is enabled for this repository.
2. If private reporting is not available, open a minimal public issue that says a security report is needed, without sensitive details.

## Sensitive areas

Changes touching these areas need extra review:

- Telegram login/session handling.
- TDLib request/response handling.
- Upload and restore state machines.
- Vault encryption and key derivation.
- Metadata export/import and Safe Uninstall restore.
- Android permissions.
- Release signing and CI/CD.

## Secrets policy

Never commit:

- Telegram API credentials.
- `.env` files.
- `android/key.properties`.
- Keystores or private keys.
- APK/AAB release artifacts.
- Local SQLite databases.
- Telegram session files.
- Real user media, logs, metadata exports, or backups.
