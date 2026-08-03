# TeleVault Google Play release checklist

A release is not production-ready until every P0 item is complete against the exact signed AAB submitted to Google Play.

## P0 — technical release gates

- [x] Compile SDK and target SDK are pinned to API 36.
- [x] Android release artifacts include `armeabi-v7a`, `arm64-v8a`, and `x86_64`, with the required 64-bit counterparts and reviewed native-page checks.
- [x] TDLib Android binary provenance and hashes are documented and enforced.
- [ ] Play-generated APKs install and launch on physical `armeabi-v7a` and `arm64-v8a` devices, including Huawei/EMUI hardware when available.
- [x] Release signing never silently falls back to debug signing.
- [x] The merged manifest contains only the reviewed media, internet, biometric, and legacy media permissions.
- [x] No `MANAGE_EXTERNAL_STORAGE` or `ACCESS_MEDIA_LOCATION` permission.
- [x] Android 14+ selected-media access is implemented and represented as partial access.
- [x] Unused Google Drive and Google Sign-In production integrations are removed.
- [x] Unique WorkManager jobs wake the existing Drift queue after process death, while runtime leases prevent a second TDLib client or queue processor in the process.
- [x] Wi-Fi-only uploads request TDLib cancellation when connectivity is lost and return unconfirmed work to `pending` without consuming a retry.
- [x] Each upload has a persisted operation ID; restart reconciliation searches the bucket before sending again.
- [ ] Final physical-device login, upload, Vault, logout, and recovery smoke test passes.
- [ ] Representative multi-gigabyte media and low-disk-space behavior are verified.

Google Play testing covers Huawei devices that have Google Play access. AppGallery or direct signed-APK distribution for Huawei devices without Google Play is a separate release channel and must be validated independently.

## P0 — reviewer access

- [x] The production AAB exposes a credential-free Reviewer Demo before production services start.
- [x] Demo mode uses separate Drift, cache, temporary-file, Vault, Recovery Key, worker, foreground-service, queue, and cleanup namespaces.
- [x] TDLib is not initialized and Telegram is not contacted in Reviewer Demo.
- [x] A persistent `REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM` banner is visible.
- [x] All demo uploads and metadata operations are explicitly labeled as simulated.
- [ ] The Play-generated APKs from the submitted AAB are tested through enter, workflow, interruption, cleanup, and exit.

## P0 — privacy and Play Console

- [x] In-app Privacy & Data copy is factual and contains no jokes or unconditional security claims.
- [x] Terms and Privacy are accessible before Telegram login.
- [x] Store listing copy avoids unlimited-storage, total-privacy, universal-encryption, and guaranteed-background claims.
- [x] Photo/video permission declaration matches the current manifest and core use.
- [x] The declared `dataSync` foreground service, notification, timeout handling, and WorkManager recovery are documented accurately.
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
  --target-platform=android-arm,android-arm64,android-x64 \
  --dart-define=TELEGRAM_API_ID=<release-secret> \
  --dart-define=TELEGRAM_API_HASH=<release-secret>
```

The same production AAB contains the credential-free Reviewer Demo. No alternate build flag or reviewer credential is required.

```bash
python3 tool/android/check_release_logs.py --log <captured-log-file>
```

Then run the existing API 36, ABI-payload, 16 KB, merged-manifest, dependency, and secret/artifact verification. Record the commit SHA, version code, AAB SHA-256, signing-certificate fingerprints, and Play Console track.

## Stop conditions

Do not submit or promote the release when:

- any P0 item remains unchecked;
- legal pages contain placeholders or contradict the app;
- Reviewer Demo initializes TDLib, contacts Telegram, or accesses production data;
- the signed AAB has not been tested through Play's generated APK delivery;
- a critical workflow passes only with uncommitted local changes.
