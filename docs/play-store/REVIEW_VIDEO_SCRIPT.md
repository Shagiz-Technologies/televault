# Google Play review video script

Target length: 2-4 minutes. Record the exact production release candidate or a Play-generated APK. Hide personal notifications and do not use private media.

## 1. Enter Reviewer Demo

- Launch the app from a fresh install or cleared app-data state.
- Select `Google Play Reviewer Demo` on the first connection screen.
- Show the persistent `REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM` banner.
- Explain that the demo uses deterministic local data and does not initialize TDLib or contact Telegram.

## 2. Library, albums, and buckets

- Show the sample Library and Albums.
- Create a local demo bucket and show the confirmation that no Telegram channel was created.
- Point out pending, uploading, synced, and failed sample states.

## 3. Simulated backup, foreground notification, and interruption

- Start a simulated upload and allow notification permission if Android requests it.
- Show the Android ongoing notification labeled `Reviewer Demo — simulated` and `No data sent to Telegram`.
- Show the explicit `simulated` labels and in-app progress.
- Turn off the demo Wi-Fi control while progress is active.
- Show that the foreground notification stops, the item returns to pending, and the upload button becomes available again.
- Restore demo Wi-Fi, resume the simulated backup, and complete one operation.
- Show that the notification stops after completion.

## 4. Vault and metadata

- Open Vault and generate a demo Recovery Key.
- Confirm the key, then run local sample encryption.
- Open Settings and run the simulated metadata snapshot.
- State that all of these operations remain inside the isolated demo namespace.

## 5. Legal, deletion, and exit

- Open Privacy, Terms, and deletion information from Settings.
- Select `Exit reviewer demo`.
- Confirm that no demo foreground notification remains.
- Show the normal Telegram startup screen.
- Explain that exit deletes only demo state and does not access or remove production data.

## Recording evidence

Retain separately:

- app version and build number;
- commit SHA and AAB SHA-256;
- Android version and device model;
- whether the APK came from Play internal testing;
- recording date;
- confirmation that no production credentials or user media were shown.
