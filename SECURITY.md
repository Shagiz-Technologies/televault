# Security Policy

## Supported versions

This repository is preparing an initial open-source release. Until stable release tags exist, security fixes target the `main` branch.

## Reporting a vulnerability

Do not open a public issue containing secrets, personal metadata, credentials, exploit details, or private Telegram account information.

Use [GitHub Private Vulnerability Reporting](https://github.com/Shagiz-Technologies/televault/security/advisories/new) as the primary reporting path.

If private reporting is unavailable, open a minimal public issue stating only
that a private security conversation is needed. Do not include reproduction
details, exploit code, secrets, account identifiers, paths, logs, metadata
backups, or personal media.

## Response targets

The project aims to acknowledge a private report within 7 days and provide an
initial triage update within 14 days. These are targets, not guarantees.
Resolution time depends on severity, reproducibility, maintainer availability,
and coordinated-disclosure needs.

## Sensitive areas

Changes touching these areas need extra review:

- Telegram login/session handling.
- TDLib request/response handling.
- Upload and restore state machines.
- Vault encryption and key derivation.
- Metadata export/import and Safe Uninstall restore.
- Android permissions.
- Release signing and CI/CD.
- Vendored TDLib/libtdjson binaries and dependency provenance.
- Local database, diagnostics, biometric, and secure-storage behavior.

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
