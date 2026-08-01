# TeleVault metadata snapshot v5

Metadata snapshot v5 replaces the legacy automatic v4 format. New automatic
and manual exports write v5 only. Version 4 remains readable solely so an
existing account can migrate its metadata.

## Recovery model

V5 uses the same confirmed, randomly generated 256-bit TeleVault Recovery Key
(`TVRK1`) as vault v3. The key is held in platform secure storage while the app
is installed. Users must keep an exported copy if they expect to restore after
reinstalling or deleting local app data.

The current Telegram account fingerprint is an identity binding, not a secret.
It is authenticated as part of the v5 header and contributes domain-separated
context to key derivation. A Telegram account ID, phone number, username, fixed
application string, or public snapshot field is never sufficient to decrypt a
v5 snapshot.

Automatic snapshots require the Recovery Key. Manual snapshots require both
the Recovery Key and the user-supplied export passphrase. Losing either required
secret makes the corresponding snapshot unrecoverable. Resetting the local
Vault PIN/password or using biometrics does not recover a missing Recovery Key.

## Container

The binary container is:

```text
TVMETA05 | uint32_be(header_length) | UTF-8 JSON header | ciphertext | 16-byte GCM tag
```

The authenticated header contains:

- Format, cipher, KDF, and protection-mode identifiers.
- A random 32-byte salt and random 12-byte nonce.
- The authenticated Telegram account fingerprint.
- A UUID snapshot generation ID and UTC creation timestamp.
- Drift database schema version and application version.
- Expected plaintext length.

The header prefix and complete header are AES-GCM additional authenticated data.
The ciphertext uses AES-256-GCM. The key is derived with HKDF-HMAC-SHA256 using
the Recovery Key, random salt, protection mode, and account-binding context. For
manual exports, a PBKDF2-HMAC-SHA256 passphrase result is combined with the
Recovery Key before HKDF. Key derivation is domain-separated with
`televault-metadata-snapshot-v5`.

Header and payload copies of the generation ID, timestamp, schema version,
application version, and account fingerprint must agree. Authentication and all
structural validation finish before database mutation begins.

## Portable metadata

V5 exports bucket, label, media identity, size, creation time, hash, Telegram
message/file references, vault state, and an allowlisted subset of settings.
Absolute local media paths, local error details, vault IV fields, credentials,
TDLib sessions, and secure-storage secrets are excluded.
Device-specific album IDs, album selection mode, and scan watermarks are also
excluded. Users must reselect albums after restore; the next scan starts from
the current device state instead of trusting a stale watermark.

A display basename may be retained inside the encrypted payload. Restored rows
receive an internal `televault-unresolved://` placeholder and
`local_path_resolved = false`. TeleVault must resolve the asset against the
current device media library before treating a local file as present.

## Transactional restore and reconciliation

Restore performs these steps in order:

1. Read the bounded snapshot file.
2. Verify its account binding and AEAD authentication.
3. Parse and validate every collection and row.
4. Validate IDs, references, enum values, dates, sizes, and allowlisted settings.
5. Reconcile bucket and message references with the current Telegram account.
6. Replace portable tables in one Drift transaction.

An exception during the transaction rolls back the complete replacement.
Restored `uploading` rows become `pending`. A row claiming remote completion is
never restored as `synced` when its Telegram message cannot be verified; it is
marked failed, unverified, and user-action-required instead. Telegram file IDs
from an unverified reference are not trusted.

Schema v10 adds `local_path_resolved` and `remote_state_verified` to preserve
these states explicitly. Existing local rows migrate with both values true;
portable imports set them according to actual resolution and reconciliation.

## Remote durability and locking

TeleVault keeps the latest two verified metadata snapshots. It waits for TDLib
message success, fetches the completed message, downloads a temporary copy, and
cryptographically verifies that copy before recording it as verified. Only then
does it attempt to prune snapshots older than the retention window. Failure to
delete an old snapshot does not invalidate the new snapshot.

Automatic backup, manual backup, restore, and Safe Uninstall share an exclusive
file lock in application support storage. The lock also serializes in-process
callers and permits intentional nested operations. The operating system releases
the lock if the process terminates, avoiding a permanently stale in-memory flag.

## Legacy v4 migration

V4 automatic snapshots used predictable key material derived from a fixed
application string and a public Telegram account fingerprint. Treat v4 as weak
protection: anyone with the snapshot and account identifier may be able to derive
its key. V4 import is available only to the matching Telegram account and only
after the user supplies or confirms the Recovery Key. A successful automatic v4
restore immediately creates and verifies a v5 snapshot. TeleVault never writes a
new v4 snapshot.

## Logout and account switching

Explicit logout stops account workers, clears retry/flood state, deletes local
Drift account data, labels, account-scoped settings and diagnostics, temporary
metadata/decrypted files, TDLib data/cache, profile images in that cache, and
account-scoped access secrets. Encrypted vault files and the Recovery Key are
deleted unless the user explicitly selects local preservation.

Preserved vault files remain encrypted and require the Recovery Key. Remote
Telegram channels, uploaded media, and metadata messages are not deleted by
local cleanup. A resumable local marker makes interrupted cleanup idempotent on
the next launch. Before a different Telegram account is bound, previous Drift
state is removed so Account B cannot observe Account A's local metadata.

## Verification

```bash
flutter test test/metadata_snapshot_v5_test.dart
flutter test test/metadata_remote_retention_test.dart
flutter test test/metadata_operation_lock_test.dart
flutter test test/local_account_cleanup_coordinator_test.dart
flutter test test/database_migration_test.dart
```
