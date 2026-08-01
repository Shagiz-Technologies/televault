# TeleVault Google Play release checklist

A release is not production-ready until every P0 item is complete against the exact signed AAB submitted to Google Play.

## P0 — technical release gates

- [x] Compile SDK and target SDK are pinned to API 36.
- [x] Android release artifacts are 64-bit only and pass the documented 16 KB native-page checks.
- [x] TDLib Android binary provenance and hashes are documented and enforced.
- [x] Release signing never silently falls back to debug signing.
- [x] The merged manifest contains only the reviewed media, internet, biometric, and legacy media permissions.
- [x] No `MANAGE_EXTERNAL_STORAGE` or `ACCESS_MEDIA_LOCATION` permission.
- [x] Android 14+ selected-media access is implemented and represented as partial access.
- [x] Unused Google Drive and Google Sign-In production integrations are removed.
- [ ] Persistent Android work can resume pending automatic backups after process death without creating a second TDLib client or queue processor.
- [ ] Wi-Fi-only uploads stop or pause safely when Wi-Fi is lost during an active transfer.
- [ ] A crash after Telegram accepts a message cannot create an untracked duplicate on restart.
- [ ] Final physical-device login, upload, Vault, logout, and recovery smoke test passes.
- [ ] Representative multi-gigabyte media and low-disk-space behavior are verified.

## P0 — reviewer access

- [ ] An isolated Telegram Test DC review build exists.
- [ ] Review mode uses separate TDLib, Drift, cache, and secure-storage namespaces.
- [ ] A persistent `Telegram Test Environment` indicator is visible.
- [ ] Reusable reviewer credentials and exact steps are entered privately in Play Console.
- [ ] The Play-generated APKs from the submitted AAB are tested with the reviewer flow.

## P0 — privacy and Play Console

- [x] In-app Privacy & Data copy is factual and contains no jokes or unconditional security claims.
- [x] Terms and Privacy are accessible before Telegram login.
- [x] Store listing copy avoids unlimited-storage, total-privacy, universal-encryption, and guaranteed-background claims.
- [x] Photo/video permission declaration matches the current manifest and core use.
- [x] Foreground-service status is documented as not currently declared.
- [ ] Public Privacy, Terms, Support, Data & Deletion, and Security pages contain no placeholder contact values and match the final app.
- [ ] Data safety answers are completed from the final dependency and network inventory.
- [ ] Content rating, target audience, ads declaration, app access, and account/data deletion sections are completed in Play Console.

## Clean release evidence

Run and retain the results for:

```bash
flutter clean
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build appbundle --release \
  --target-platform=android-arm64,android-x64 \
  --dart-define=TELEGRAM_API_ID=<release-secret> \
  --dart-define=TELEGRAM_API_HASH=<release-secret>
```

Then run the existing API 36, 16 KB, merged-manifest, dependency, and secret/artifact verification. Record the commit SHA, version code, AAB SHA-256, signing-certificate fingerprints, and Play Console track.

## Stop conditions

Do not submit or promote the release when:

- any P0 item remains unchecked;
- legal pages contain placeholders or contradict the app;
- review access depends on a personal production Telegram OTP;
- the signed AAB has not been tested through Play's generated APK delivery;
- a critical workflow passes only with uncommitted local changes.
