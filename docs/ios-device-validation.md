# Physical iPhone Validation

Use this checklist only with an unsigned IPA produced by the `device-test` profile on the `ios-tdlib-integration` branch. Android remains the supported release target until the critical iPhone flows below pass.

## Test Safety

- Use a test bucket and non-sensitive sample photos and videos.
- Do not place phone numbers, OTP codes, passwords, API credentials, channel identifiers, or personal media in screenshots, issues, or test notes.
- Do not upload the IPA publicly. It contains client configuration intended only for private testing.
- If a crash report is needed, redact the device name, Apple ID, file paths, UUIDs, and personal notifications before sharing it.
- Record pass/fail behavior, not Telegram credentials or message contents.

## Installation Evidence

- [ ] The workflow run used `device-test` and completed successfully.
- [ ] The artifact came from the expected commit SHA.
- [ ] Sideloadly or AltStore signed and installed the IPA without modifying the bundle contents beyond signing.
- [ ] TeleVault launches repeatedly without an immediate crash.

## Telegram Authentication

- [ ] A valid phone number advances to the OTP screen without a native-engine warning.
- [ ] An invalid phone number shows a deterministic, non-sensitive error.
- [ ] A valid OTP advances to Telegram 2FA or the app, as appropriate.
- [ ] An invalid or expired OTP shows the correct recoverable error.
- [ ] Telegram 2FA succeeds with the correct password and rejects an incorrect password.
- [ ] Force-closing and reopening TeleVault restores the authenticated TDLib session.
- [ ] Logout returns to phone entry and does not leave the old local session usable.

## Buckets And Media

- [ ] TeleVault can create a private test bucket.
- [ ] TeleVault can discover its existing private buckets after restart.
- [ ] A sample photo uploads and is marked complete only after Telegram confirms the message.
- [ ] A sample video uploads and is marked complete only after Telegram confirms the message.
- [ ] A queued PhotoKit item still uploads after an app restart, proving temporary media paths are re-resolved.
- [ ] Downloading a backed-up sample file completes and opens or shares correctly.
- [ ] TDLib file progress updates change the in-app indicator in real time.

## Lifecycle And Recovery

- [ ] Leaving and reopening the app does not cause a splash-screen loop.
- [ ] Interrupting the network during upload produces a recoverable failure or pending state.
- [ ] Restoring the network resumes or retries without duplicate successful messages.
- [ ] Foreground sync continues across normal navigation.
- [ ] The app does not claim background upload behavior that iOS has not granted.

## Vault And Metadata

- [ ] A sample vaulted photo is encrypted before upload.
- [ ] A vaulted item never uploads the original gallery file when its encrypted local file is missing.
- [ ] Unlocking with the configured TeleVault credential works.
- [ ] Device biometric unlock works when configured and does not loop with app lock.
- [ ] Metadata export creates an encrypted package.
- [ ] Metadata import succeeds for the same Telegram account and fails for a different account.

## Privacy Review

- [ ] No UI error exposes a local file path, Telegram identifier, API credential, OTP, or password.
- [ ] TDLib native logs are limited to fatal messages.
- [ ] App diagnostics contain operational counters only, not media names or paths.
- [ ] Any screenshots use demo media and contain no status-bar or notification identifiers.

## Result

Record the tested iPhone model, iOS version, TeleVault commit SHA, sideloading tool, and pass/fail status without account identifiers. Keep the pull request in draft while any critical authentication, upload, download, session, or privacy item is failing.

After the critical flows pass, update the README status to `iOS experimental: Telegram login and foreground backup verified`. Do not use `iOS supported` until the broader compatibility and background-behavior work is complete.
