# Google Play app access

TeleVault normally requires the user's own Telegram account before its backup features can operate. The production AAB also includes a credential-free, network-free **Google Play Reviewer Demo** so reviewers can inspect restricted workflows without a Telegram account.

No Telegram account or reviewer credential is required for the demo. It does not initialize TDLib, connect to Telegram, inspect production TeleVault data, or read the reviewer's media. When the reviewer starts the simulated backup, TeleVault requests Android photo/video and notification permissions so the declared permission and foreground-service flows can be reviewed with real system prompts.

## Reviewer steps

1. Launch TeleVault from a fresh install or cleared app-data state.
2. On the first connection screen, select **Google Play Reviewer Demo**.
3. Confirm that the persistent banner reads **REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM**.
4. Inspect the deterministic sample Library and Albums.
5. Open **Albums** to inspect sample buckets or create a local demo bucket.
6. In **Library**, run the simulated backup and respond to the Android photo/video and notification permission prompts.
7. Confirm that Android displays an ongoing notification labeled **Reviewer Demo — simulated** and **No data sent to Telegram**.
8. Inspect pending, uploading, synced, and failed states. Every transfer operation is labeled as simulated.
9. Turn the demo Wi-Fi control off during a simulated upload. Confirm that the notification stops, the active item returns to pending, and the interface becomes resumable.
10. Restore demo Wi-Fi and complete one simulated operation.
11. Open **Vault** to inspect the local encryption and Recovery Key demonstration.
12. Open **Settings** to inspect metadata backup status, Privacy, Terms, deletion information, and logout behavior.
13. Select **Exit reviewer demo** to delete only demo data and return to normal Telegram startup.
14. Select **Continue with Telegram** to confirm that the normal authorization screen opens without a stale Test or Demo environment.

## Isolation and behavior

- Production Telegram login remains the default normal-user path and always uses Telegram Production DC.
- Reviewer Demo starts before production TDLib, Drift, Vault, secure storage, cache, or background workers are initialized.
- Demo Drift, cache, temporary files, Vault secrets, Recovery Key data, WorkManager names, foreground-service identifiers, queue ownership, and cleanup state use dedicated namespaces.
- TDLib is disabled in demo mode, so no Telegram network request, channel, message, or upload is created.
- Sample media are generated descriptions and colored placeholders. The photo/video permission prompt demonstrates the production permission flow, but the demo does not enumerate or read device media.
- Backup and metadata operations are deterministic local simulations and are visibly identified as simulated.
- The demo uses TeleVault's real Android foreground-service notification mechanism only to demonstrate visible background progress. The transferred content and completion result remain local simulations.
- The demo notification stops on interruption, completion, exit, and cleanup.
- Before production switches into Reviewer Demo, TeleVault stops workers and closes TDLib cleanly so its local database can be reopened safely later without logging out the user.
- Exiting the demo cancels current demo work and legacy Test DC worker names, then removes only demo secrets, databases, and files. Production sessions and data are neither opened nor deleted.

## Production verification

Reviewers who choose **Continue with Telegram** use the normal production path and must authorize their own real Telegram account. TeleVault does not ship phone numbers, login codes, sessions, API credentials, reviewer identities, or private media.

The demo supports Play review of application behavior; it is not evidence of successful Telegram delivery. Production Telegram login and upload are validated separately during release testing.
