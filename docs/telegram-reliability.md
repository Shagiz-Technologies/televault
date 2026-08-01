# Telegram reliability policy

TeleVault centralizes non-essential Telegram writes in
`TelegramReliabilityService`. Media uploads, metadata uploads, metadata cleanup,
and bucket/channel creation use the same serialized, account-scoped policy.
Authentication requests remain outside this gate because they are required to
establish or recover the Telegram session.

## Error handling

TDLib errors are converted to `TelegramError` values. The parser supports direct
`error` responses, `updateMessageSendFailed.error`, and
`messageSendingStateFailed`, including structured `retry_after` values and the
`FLOOD_WAIT_X` and `FLOOD_PREMIUM_WAIT_X` forms. Structured retry information
takes precedence over message-text parsing.

TDLib error code 406 text is retained internally for typed state but is never
parsed, logged, or shown to users. User-facing messages are derived from the
error category.

## Durable write gate

Exact Telegram waits are stored per Telegram account in Drift. The persisted
state contains the server-required resume time and a write-blocked time with a
bounded 250-1000 ms post-wait jitter. A later existing gate is never shortened.
Manual retry cannot bypass this state, and one timer wakes the queue at the
required time instead of polling every 30 seconds.

The uploader remains sequential. A file is marked synced only after
`updateMessageSendSucceeded`, or when TDLib returns a final message with no
sending state.

## TDLib media payloads

The vendored TDLib 1.8.66 build is pinned to commit
`022d60202e446ad1287b9fb68e687c8a0760788b`. At that revision, media message
content wraps `inputFileLocal` in `inputDocument`, `inputPhoto`, or `inputVideo`.
`TelegramMessageContent` owns this wire format for both media and metadata
uploads. Tests must fail if a future change restores the incompatible flat
payload, which TDLib rejects with `400 InputFile is not specified`.

## Upload limits

TeleVault obtains the current account's Premium capability from TDLib and keeps
the last known value while temporarily offline:

| Account capability | Operational upload cap |
| --- | ---: |
| Free | 1900 MiB |
| Telegram Premium | 3900 MiB |

Settings and imported metadata are clamped to the live cap. If Premium expires,
oversized pending files are moved to a user-action-required failed state without
automatic retry.

## Database migration

Schema version 8 adds typed Telegram failure fields to `files` and the
`telegram_account_states` table. Existing file and bucket rows are preserved.
Older metadata packages remain readable because the added file fields are
optional during import; new exports include them.

## Verification

```bash
flutter test test/telegram_error_test.dart
flutter test test/telegram_reliability_service_test.dart
flutter test test/telegram_message_content_test.dart
flutter test test/database_migration_test.dart
flutter test test/file_uploader_test.dart
flutter test test/bucket_service_test.dart
flutter test test/metadata_backup_service_test.dart
```

Physical-device release checks must confirm Telegram login, a successful upload,
an intentionally induced or observed retry state, and queue recovery after an
app restart. Never use or commit production credentials in automated tests.
