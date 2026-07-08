# Privacy

TeleVault is designed so users back up media to Telegram storage controlled by their own Telegram account. This repository does not include a TeleVault-operated backend server.

TeleVault is independent and is not affiliated with, endorsed by, or sponsored by Telegram.

## Data stored locally

TeleVault stores local metadata such as:

- Bucket records.
- Media identifiers and local paths needed for scanning and backup state.
- Sync status, retry state, and error messages.
- Labels and library organization metadata.
- Vault state and encryption metadata for vaulted items.
- App preferences and security settings.

This metadata is stored on the device using local app storage and Drift/SQLite.

## Data sent to Telegram

When backup is enabled, TeleVault uploads selected photos and videos to private Telegram channels under the logged-in Telegram account. Normal non-vault media is not client-side encrypted by TeleVault before upload in the current implementation.

Vault-protected media is encrypted by TeleVault as part of the vault flow. Metadata backup packages are encrypted and bound to the Telegram account recorded in the snapshot.

## Telemetry and diagnostics

No external analytics or telemetry SDK was found during the open-source preparation audit. The app contains local operational diagnostics UI. Contributors should not add external telemetry without clear user control, documentation, and review.

## Permissions

TeleVault requests media permissions to scan photos and videos, biometric permissions for app/vault unlock, and internet access for Telegram login/upload. `ACCESS_MEDIA_LOCATION` is privacy-sensitive and should be reviewed before production release.

## User responsibility

Users are responsible for the Telegram account, private channels, credentials, device lock, passphrases, and local backups they choose to use with TeleVault.
