# Google Play Data safety worksheet

Use this as an implementation inventory, not as a substitute for answering the current Play Console questionnaire. Re-check every answer against the final signed AAB and Google's definitions before submission.

## Network services

- Telegram/TDLib is the primary network service.
- TeleVault does not currently operate a separate media-storage backend.
- No advertising SDK or external analytics SDK is included in the reviewed production dependencies.

## Data accessed or transmitted

| Data category | Purpose | Destination | User control / notes |
| --- | --- | --- | --- |
| Phone number and Telegram authentication inputs | Telegram account authorization | Telegram through TDLib | Required to sign in. Never log or commit credentials. |
| Telegram account/profile and channel information | Display account and manage private backup buckets | Telegram through TDLib; local app storage | Required for core functionality. |
| Photos and videos selected or accessible under Android permission | Backup, display, organization, restore | Telegram private channels selected/created by the user | Core app purpose. Selected-media access is supported on Android 14+. |
| Media metadata and sync state | Queueing, deduplication, recovery, diagnostics | Local Drift/SQLite; encrypted metadata snapshots may be sent to Telegram | Absolute local paths are excluded from portable v5 snapshots. |
| Vault-protected media | Encrypted backup and local Vault access | Telegram after TeleVault client-side encryption | Requires the separate Vault Recovery Key. |
| Local operational diagnostics | Troubleshooting | Local device only in the reviewed implementation | Must not contain secrets or private media content. |

## Security practices

- Data is encrypted in transit by the Telegram/TDLib transport.
- Normal non-vault media is not client-side end-to-end encrypted by TeleVault.
- Vault v3 objects use authenticated client-side encryption.
- Metadata v5 snapshots use authenticated encryption and account binding.
- TDLib session data and app databases are stored in application-private storage.
- Android application backup is disabled.

## Retention and deletion

- Local account data is removed through the logout cleanup flow or when Android clears/uninstalls the app, subject to the user's explicit option to retain encrypted Vault files and the Recovery Key.
- Logout or uninstall does not automatically delete Telegram channels, messages, uploaded media, or metadata snapshots.
- Users must delete remote content through Telegram or supported TeleVault controls.
- Shagiz Technologies cannot directly delete content held in a user's Telegram account.

## Final verification questions

- Does the final AAB contain any new analytics, crash reporting, advertising, cloud-storage, or authentication SDK?
- Does any dependency transmit identifiers or diagnostics independently?
- Are Play Console answers consistent with the public Privacy Policy and in-app Privacy & Data screen?
- Are account deletion and data deletion described separately and accurately?
- Have all declarations been reviewed after manifest merging and dependency resolution?
