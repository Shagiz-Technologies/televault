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

This metadata is stored on the device using local app storage and Drift/SQLite. TDLib separately stores the Telegram session and cache in application-private storage.

## Data sent to Telegram

When backup is enabled, TeleVault uploads selected photos and videos to private Telegram channels under the logged-in Telegram account. Telegram and TDLib process authentication, channels, messages, file transfer, storage, and retrieval. A private channel does not mean Telegram is technically unable to process its contents.

Normal non-vault media is not client-side end-to-end encrypted by TeleVault before upload in the current implementation.

Vault-protected media is encrypted by TeleVault as part of the vault flow. New vault objects use the authenticated, streaming v3 format and random per-file keys. The portable Vault Recovery Key is stored through the platform secure-storage facility while installed and is not written to Drift, Telegram captions, diagnostics, or TeleVault-operated infrastructure. New metadata v5 snapshots are encrypted using that Recovery Key and authenticated against the current Telegram account. Manual v5 exports additionally require the user's export passphrase. The account fingerprint is an identity binding, not the encryption secret.

The Vault PIN/password and device biometrics control local access; they are not the portable v3 recovery secret. Users must privately retain the exported Vault Recovery Key. Losing both the installed secure-storage copy and the exported key makes v3 vault backups unrecoverable.

Portable v5 metadata excludes absolute local media paths and restores device media references as unresolved until the current media library confirms them. Legacy v4 metadata remains readable only for migration and used weaker account-identifier-derived protection; a successful automatic v4 restore is replaced with a secure v5 snapshot.

## Background processing

Android may delay, pause, or stop background work because of network, battery, device-vendor, or operating-system restrictions. TeleVault cannot guarantee immediate or uninterrupted automatic backup. Users should verify important uploads before deleting local originals.

## Retention and deletion

Logging out removes account-scoped local metadata, caches, temporary exports, access secrets, and the TDLib session, subject to the options shown during logout. Users may explicitly retain local encrypted vault files and the Recovery Key. Logout and uninstall do not automatically delete the user's remote Telegram channels, uploaded media, messages, or metadata snapshots. Remote Telegram content must be removed through Telegram or supported TeleVault controls.

## Telemetry and diagnostics

No advertising SDK or external analytics or telemetry SDK was found during the open-source preparation audit. The app contains local operational diagnostics UI. Contributors should not add external telemetry without clear user control, documentation, and review.

## Permissions

TeleVault requests photo and video permissions because continuous gallery
discovery and automatic backup are core features. On Android 14 and later,
users can grant selected-media access; TeleVault then scans only those items and
labels discovery as partial. TeleVault does not request media location or all-
files access. Biometric permissions support app/vault unlock, and internet
access supports Telegram login and upload.

The production application does not include Google Drive or Google Sign-In. An
earlier unwired prototype was removed before release.

## User responsibility

Users are responsible for the Telegram account, private channels, credentials, device lock, passphrases, Recovery Key, and independent backups they choose to use with TeleVault.
