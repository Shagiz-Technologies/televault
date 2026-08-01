# Google Play review video script

Target length: 2-4 minutes. Record the exact production release candidate or
Play-generated APK, with no private notifications or personal media visible.

## 1. Environment and legal access

- Launch the app.
- Select `Google Play reviewer access` on the first connection screen.
- Show the persistent `Telegram Test Environment` banner.
- Open Privacy Policy and Terms of Service before entering a phone number.
- Return to login.

## 2. Reviewer authorization

- Enter a Telegram Test DC number in the `99966XYYYY` format. Use Test DC 1,
  2, or 3 for `X` and an available four-digit suffix for `YYYY`.
- Enter `XXXXX` as the code, repeating the selected Test DC number five times.
- Do not show production credentials, API secrets, or a personal Telegram account.
- Do not store private or important information in the synthetic test account.

## 3. Photo/video permission

- Show the Android photo/video permission prompt.
- Demonstrate selected-media access and the partial-access notice.
- Open Settings > Media Access.
- Expand or change access and show that only accessible items appear.

## 4. Core backup

- Create or select a private test bucket.
- Queue one small test photo and one small test video.
- Show queued, uploading, and synced states.
- Explain that Telegram/TDLib process the account, channel, messages, and uploaded files.
- State that normal non-vault uploads are not client-side end-to-end encrypted by TeleVault.

## 5. Vault boundary

- Open Vault setup.
- Generate, record, and confirm the Vault Recovery Key using non-sensitive test data.
- Vault one test item and show its status.
- Explain that the PIN/biometric is a local access control and the Recovery Key is required for portable recovery.

## 6. Background and constraints

- Show Sync Preferences.
- Explain that Android may defer background work.
- Demonstrate persistent work and active Wi-Fi-loss handling using the release candidate.

## 7. Logout and deletion boundary

- Open logout.
- Show the explanation of local data removal and the option to retain encrypted Vault files.
- Show that remote Telegram channels/messages are not automatically deleted.
- Complete logout and return to the login screen.
- Select `Return to normal Telegram` and show that only Test Environment state is cleared.

## Recording evidence

Capture or retain separately:

- app version and build number;
- commit SHA;
- AAB SHA-256;
- Android version and device model;
- whether the installed APK came from Play internal testing;
- date of the recording;
- the synthetic reviewer number entered privately in Play Console.
