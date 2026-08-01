# TeleVault Architecture

TeleVault is a Flutter application organized by product feature, with shared
database, Telegram, theme, diagnostics, and platform services under
`lib/src/core`.

## Application composition

- `lib/main.dart` creates a Riverpod `ProviderScope`.
- `lib/src/app.dart` routes between Telegram authorization, bucket setup, the
  main library, synchronization startup, and the app-lock overlay.
- Feature providers expose services and state controllers through Riverpod.
- UI code lives under each feature's `presentation` directory; service and data
  code remains close to the feature that owns it.

## Local data

Drift manages a SQLite database named `tele_vault.sqlite` in application
documents storage. It records:

- Telegram-backed bucket identifiers and bucket media preferences.
- Media asset identifiers, local paths, sizes, folder names, and optional
  hashes.
- Telegram message/file identifiers and upload state.
- Retry, vault, encryption, deletion, label, and application-setting metadata.

The database is not encrypted at rest by TeleVault. Device storage protection
and operating-system access controls remain part of the local trust boundary.

## Media discovery

The gallery layer uses `photo_manager` to request platform media access and
enumerate photos, videos, and albums. Library controllers map gallery assets to
database state for filtering, selection, labels, deletion, and vault actions.

The Android permission flow and continuous-library access are privacy-sensitive
areas. Changes require maintainer review and physical-device testing.

## Telegram boundary

`TelegramService` implements the repository's `TelegramGateway` abstraction and
communicates with TDLib through the vendored `libtdjson` FFI plugin. It owns the
native TDLib client, authorization-state updates, request correlation,
throttling, and Telegram storage directories.

Telegram receives account authentication data, channel operations, and media
selected for backup. TeleVault does not operate an application backend in this
repository, but Telegram and TDLib remain external processors and trust
boundaries. TeleVault is independent and is not affiliated with, endorsed by,
or sponsored by Telegram.

## Buckets and synchronization

A bucket maps a local database record to a Telegram channel identifier.
Per-bucket settings determine allowed media types and synchronization behavior.

The sync service scans eligible gallery assets and creates per-bucket queue
rows. The uploader serializes work for the selected bucket, persists
pending/uploading/synced/failed states, observes TDLib message-send completion,
and stores Telegram identifiers after confirmed success. Retry timing and
errors remain in the local database.

Lifecycle initialization resumes scanning and queue processing while the app is
running. Platform background execution is subject to Android process, battery,
and scheduling restrictions and must not be treated as an unconditional
always-running guarantee.

## Vault boundary

Vault-selected files use the vault encryption flow before encrypted payloads
are stored or uploaded. The current format uses AES-GCM and derives a key from
the user credential with PBKDF2-HMAC-SHA256. Vault authentication can use a
TeleVault credential and supported device authentication through `local_auth`.

Normal, non-vault media does not pass through TeleVault's client-side
encryption. It is sent to Telegram in the selected upload format. The vault is
not a claim that all application data, the local database, or all Telegram
uploads are end-to-end encrypted by TeleVault.

## Metadata backup and restore

Metadata export serializes buckets, files, labels, and related state into an
encrypted package. Current package formats use AES-GCM, a user passphrase or an
account-derived key, and a fingerprint derived from the authenticated Telegram
user ID. Import rejects snapshots whose recorded account fingerprint does not
match the current Telegram account.

The automatic metadata flow looks for or creates a dedicated `TeleVault`
Telegram channel, uploads replacement metadata snapshots, and can restore the
latest recognized snapshot. Safe Uninstall invokes a final metadata backup
flow. These mechanisms restore metadata; they do not constitute a complete,
polished restoration of every original media file.

An experimental Google Drive database service exists in source but is not
wired into the current user interface. It must not be described as a supported
backup path without product, privacy, and release review.

## Trust boundaries

1. **Device and operating system:** gallery permissions, biometrics, app
   sandboxing, local files, secure storage, process lifecycle, and notifications.
2. **TeleVault local storage:** unencrypted SQLite metadata, encrypted vault
   payloads, temporary decrypted files, settings, and local diagnostics.
3. **Telegram and TDLib:** authentication, sessions, channels, transmitted
   media, metadata packages, network behavior, and remote retention.
4. **User credentials:** Telegram access, vault credentials, metadata
   passphrases, device security, and recovery responsibility.
5. **Build supply chain:** Flutter packages, Gradle dependencies, GitHub
   Actions, and vendored native binaries.

Changes crossing these boundaries require explicit documentation, tests, and
maintainer review.
