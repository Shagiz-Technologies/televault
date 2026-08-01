# Foreground service declaration

## Current release state

TeleVault declares `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC`. Its non-exported `TeleVaultSyncService` uses the `dataSync` type and displays a private, low-priority ongoing notification while automatic backup work is queued or uploading. It stops when that work finishes. The notification reports queued, uploading, completed, failed, and transferred-byte status.

The service keeps the active Flutter/TDLib upload session alive and provides visible progress. A unique WorkManager schedule provides periodic restart recovery; it does not create a second uploader or TDLib client. Android may still defer work, enforce data-sync foreground-service time limits, or stop the process.

`TeleVaultSyncService.onTimeout` removes the notification and stops the service when Android applies the data-sync time limit. WorkManager can wake the existing sequential Drift queue later when its network constraint is met.

## User benefit and initiation

The service supports TeleVault's core user-facing purpose: continuous backup of newly available photos and videos to the user's selected private Telegram channel. It runs only for a bucket whose Auto Backup setting is enabled, or long enough to finish an upload that was already active when Auto Backup was disabled. Logout cancels persistent work and stops the service before TDLib account storage is cleared.

## Play Console declaration

Declare the `dataSync` foreground-service type in Play Console. The review video must show:

1. The user enabling Auto Backup for a bucket.
2. A media item entering the backup queue.
3. The TeleVault ongoing notification showing live progress.
4. The Telegram channel receiving the completed item.
5. Auto Backup being disabled and the service stopping after the active transfer finishes.

## Release checks

- Inspect the final merged manifest for the two foreground-service permissions, the non-exported service, and `android:foregroundServiceType="dataSync"`.
- Verify the notification appears during a real upload and its counts match the selected bucket.
- Verify logout cancels WorkManager jobs and removes the notification.
- Verify Android 15+ timeout handling does not leave a stale notification.
- Keep the Play Console declaration and review video synchronized with the submitted build.
