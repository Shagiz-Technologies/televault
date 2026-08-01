# TeleVault vault container v3

Status: active write format for new vault objects.

## Security model

Vault v3 separates local access control from portable recovery:

- The Vault PIN/password and device biometrics unlock the local UI.
- A randomly generated 256-bit Vault Recovery Key protects portable vault
  objects.
- The recovery key is stored through `flutter_secure_storage` while TeleVault is
  installed. On Android, the package wraps storage keys with Android Keystore.
- The recovery key is never written to Drift, logs, filenames, Telegram
  captions, or diagnostics.
- A user must record and confirm the recovery key before TeleVault creates a v3
  object that can be uploaded.

Losing both the installed secure-storage entry and the exported recovery key
makes v3 vault objects unrecoverable. A short PIN or biometric cannot recover
them.

## Primitives

- Data encryption: AES-256-GCM with a 16-byte authentication tag.
- Recovery-key derivation: HKDF-HMAC-SHA256, 32-byte output.
- Key wrapping: AES-256-GCM.
- Random material: the operating system secure random source exposed by Dart.
- Default plaintext chunk size: 2 MiB. Readers accept 64 KiB through 4 MiB.

Each object has a random 256-bit data-encryption key. HKDF derives a wrapping
key from the recovery key and a random 32-byte salt. Changing a local PIN does
not re-encrypt v3 files.

## File layout

All integer fields are unsigned big-endian.

```text
+----------------------+----------------------------------------------+
| Field                | Encoding                                     |
+----------------------+----------------------------------------------+
| Magic                | 8 bytes: ASCII `TVLT0003`                    |
| Header length        | uint32                                       |
| Header               | UTF-8 deterministically ordered JSON, 64 KiB max |
| Chunk record 0       | index, plaintext length, ciphertext length,  |
|                      | ciphertext, 16-byte GCM tag                   |
| ...                  | one record per expected plaintext chunk      |
+----------------------+----------------------------------------------+
```

The strict header contains only these keys, in this order:

```text
version, cipher, kdf, keyWrap, keyWrappingVersion, chunkSize,
originalLength, chunkCount, objectId, salt, noncePrefix, wrapNonce,
wrappedKey, wrappedKeyTag, metadataCiphertext, metadataTag
```

The private metadata plaintext is JSON containing the original display name
and MIME type. It is encrypted with the per-file data key and a dedicated nonce
that cannot overlap a chunk nonce.

## Authentication and nonce rules

The key-wrap AAD authenticates all public context fields. Private metadata AAD
also binds the wrapped-key fields. Every chunk authenticates the complete final
header, its expected index, and its plaintext length.

The per-file nonce prefix is eight random bytes. Chunk `n` uses
`prefix || uint32(n)`. Private metadata reserves index `0xffffffff`. The maximum
chunk count is therefore `0xffffffff`; nonce reuse under one data key is
rejected by construction. The key-wrap nonce uses a different wrapping key.

The reader derives the expected chunk count from the authenticated original
length and chunk size. It rejects missing, reordered, duplicated, truncated, or
extra records. AES-GCM rejects modified metadata, ciphertext, tags, and wrong
recovery keys.

## Filesystem behavior

- Encrypted objects are named `<uuid>.tvv3`; original basenames are never used.
- Encryption and decryption write to a unique `.partial-*` file in the same
  destination directory.
- Data is flushed and closed before an atomic rename.
- Existing destinations are never overwritten.
- Decrypted files live only below the application cache directory and use a
  random filename plus a validated extension.
- Startup cleanup removes stale plaintext and partial files. Android application
  backup is disabled, and cache files are not backup inputs.

## Legacy migration

Versions 1 and 2 remain read-only. Their existing PIN/password derivation is
used only to decrypt for migration. A migration records its target UUID before
work starts, writes and verifies v3, commits the database update, and only then
deletes the legacy encrypted object. Re-running an interrupted migration adopts
an already verified target or safely retries without overwriting it.
