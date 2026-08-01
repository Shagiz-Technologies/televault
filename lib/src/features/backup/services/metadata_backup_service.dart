import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as legacy_encryption;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_runtime_environment.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_service.dart';
import '../../settings/services/settings_service.dart';
import '../../vault/services/vault_recovery_service.dart';
import 'metadata_operation_lock.dart';
import 'metadata_remote_verifier.dart';

final metadataRemoteStateVerifierProvider =
    Provider<MetadataRemoteStateVerifier>((ref) {
      return TelegramMetadataRemoteStateVerifier(
        ref.watch(telegramServiceProvider),
      );
    });

final metadataBackupServiceProvider = Provider<MetadataBackupService>((ref) {
  return DriftMetadataBackupService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(vaultRecoveryServiceProvider),
    ref.watch(metadataRemoteStateVerifierProvider),
    ref.watch(metadataOperationLockProvider),
  );
});

enum MetadataBackupErrorCode {
  invalidSnapshot,
  unsupportedVersion,
  wrongTelegramAccount,
  recoveryKeyRequired,
  legacyPassphraseRequired,
  invalidPassphrase,
  authenticationFailed,
  validationFailed,
  accountUnavailable,
  ioFailure,
}

class MetadataBackupException implements Exception {
  final MetadataBackupErrorCode code;
  final String message;
  final Object? cause;
  final bool requiresExistingRecoveryKey;

  const MetadataBackupException(
    this.code,
    this.message, {
    this.cause,
    this.requiresExistingRecoveryKey = false,
  });

  @override
  String toString() => message;
}

enum MetadataSnapshotProtection {
  recoveryKey('recovery-key'),
  recoveryKeyAndPassphrase('recovery-key-and-passphrase'),
  legacyAccountOnly('legacy-account-only'),
  legacyPassphrase('legacy-passphrase');

  final String wireName;

  const MetadataSnapshotProtection(this.wireName);
}

class MetadataSnapshotInspection {
  final int formatVersion;
  final MetadataSnapshotProtection protection;
  final String? generationId;
  final DateTime? createdAt;

  const MetadataSnapshotInspection({
    required this.formatVersion,
    required this.protection,
    this.generationId,
    this.createdAt,
  });
}

class MetadataImportResult {
  final int sourceFormatVersion;
  final String generationId;
  final bool requiresSecureMigration;

  const MetadataImportResult({
    required this.sourceFormatVersion,
    required this.generationId,
    required this.requiresSecureMigration,
  });
}

abstract interface class MetadataBackupService {
  Future<io.File> exportEncryptedSnapshot({required String passphrase});

  Future<io.File> exportAccountBoundSnapshot();

  Future<MetadataImportResult> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  });

  Future<MetadataImportResult> importAccountBoundSnapshot(io.File snapshot);

  Future<void> verifyAccountBoundSnapshot(io.File snapshot);

  Future<MetadataSnapshotInspection> inspectSnapshot(io.File snapshot);
}

typedef MetadataTemporaryDirectoryProvider = Future<io.Directory> Function();
typedef MetadataApplicationVersionProvider = Future<String> Function();
typedef MetadataImportCommitHook = FutureOr<void> Function();

class DriftMetadataBackupService implements MetadataBackupService {
  static const formatVersionV5 = 5;
  static const _formatVersionV1 = 1;
  static const _formatVersionV2 = 2;
  static const _formatVersionV3 = 3;
  static const _formatVersionV4 = 4;
  static const _legacySaltLength = 16;
  static const _legacyIvLength = 12;
  static const _legacyPbkdf2Iterations = 120000;
  static const _v5SaltLength = 32;
  static const _v5NonceLength = 12;
  static const _tagLength = 16;
  static const _maximumHeaderLength = 64 * 1024;
  static const _maximumSnapshotLength = 256 * 1024 * 1024;
  static const _maximumBuckets = 100;
  static const _maximumLabels = 10000;
  static const _maximumFiles = 500000;
  static const _maximumPortableFileSize = 1 << 50;
  static const _metadataKdfContext = 'televault-metadata-snapshot-v5';
  static final Uint8List _magic = Uint8List.fromList(ascii.encode('TVMETA05'));

  final AppDatabase _db;
  final TelegramGateway _telegram;
  final SettingsService _settingsService;
  final VaultRecoveryKeyProvider _recoveryKeyProvider;
  final MetadataRemoteStateVerifier _remoteVerifier;
  final MetadataOperationLock _operationLock;
  final MetadataTemporaryDirectoryProvider _temporaryDirectoryProvider;
  final MetadataApplicationVersionProvider _applicationVersionProvider;
  final Uint8List Function(int length) _randomBytes;
  final String Function() _generationIdFactory;
  final DateTime Function() _clock;
  final MetadataImportCommitHook? _importCommitHook;
  final AesGcm _aesGcm = AesGcm.with256bits();

  DriftMetadataBackupService(
    this._db,
    this._telegram,
    this._settingsService,
    this._recoveryKeyProvider,
    this._remoteVerifier,
    this._operationLock, {
    MetadataTemporaryDirectoryProvider? temporaryDirectoryProvider,
    MetadataApplicationVersionProvider? applicationVersionProvider,
    Uint8List Function(int length)? randomBytes,
    String Function()? generationIdFactory,
    DateTime Function()? clock,
    MetadataImportCommitHook? importCommitHook,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _applicationVersionProvider =
           applicationVersionProvider ?? _defaultApplicationVersion,
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _generationIdFactory = generationIdFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now,
       _importCommitHook = importCommitHook;

  @override
  Future<io.File> exportEncryptedSnapshot({required String passphrase}) {
    if (passphrase.trim().isEmpty) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidPassphrase,
        'A passphrase is required for this metadata export.',
      );
    }
    return _operationLock.synchronized(
      () => _exportV5(
        protection: MetadataSnapshotProtection.recoveryKeyAndPassphrase,
        passphrase: passphrase,
      ),
    );
  }

  @override
  Future<io.File> exportAccountBoundSnapshot() {
    return _operationLock.synchronized(
      () => _exportV5(protection: MetadataSnapshotProtection.recoveryKey),
    );
  }

  Future<io.File> _exportV5({
    required MetadataSnapshotProtection protection,
    String? passphrase,
  }) async {
    final recoveryKey = await _requireRecoveryKey();
    final accountFingerprint = await _currentAccountFingerprint();
    final generationId = _generationIdFactory();
    if (!_isUuid(generationId)) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.validationFailed,
        'The metadata snapshot generation identifier is invalid.',
      );
    }
    final createdAt = _clock().toUtc();
    final applicationVersion = await _applicationVersionProvider();
    final payload = await _buildPortablePayload(
      accountFingerprint: accountFingerprint,
      generationId: generationId,
      createdAt: createdAt,
      applicationVersion: applicationVersion,
    );
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final salt = _randomBytes(_v5SaltLength);
    final nonce = _randomBytes(_v5NonceLength);
    if (salt.length != _v5SaltLength || nonce.length != _v5NonceLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.ioFailure,
        'Secure random metadata parameters could not be generated.',
      );
    }

    final header = <String, dynamic>{
      'format_version': formatVersionV5,
      'cipher': 'AES-256-GCM',
      'kdf': 'HKDF-HMAC-SHA256',
      'protection': protection.wireName,
      'account_fingerprint': accountFingerprint,
      'generation_id': generationId,
      'created_at': createdAt.toIso8601String(),
      'database_schema_version': _db.schemaVersion,
      'application_version': applicationVersion,
      'salt_b64': base64UrlEncode(salt),
      'nonce_b64': base64UrlEncode(nonce),
      'plaintext_length': plaintext.length,
    };
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
    if (headerBytes.length > _maximumHeaderLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.validationFailed,
        'The metadata snapshot header is too large.',
      );
    }
    final aad = _join([
      _magic,
      _uint32BigEndian(headerBytes.length),
      headerBytes,
    ]);
    final key = await _deriveV5Key(
      recoveryKey: recoveryKey,
      salt: salt,
      accountFingerprint: accountFingerprint,
      protection: protection,
      passphrase: passphrase,
    );
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    final bytes = _join([aad, secretBox.cipherText, secretBox.mac.bytes]);
    if (bytes.length > _maximumSnapshotLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.validationFailed,
        'The metadata snapshot exceeds the supported size.',
      );
    }

    try {
      final directory = await _temporaryDirectoryProvider();
      final metadataDirectory = io.Directory(
        path.join(
          directory.path,
          AppRuntimeEnvironment.cacheDirectory('televault_metadata'),
        ),
      );
      await metadataDirectory.create(recursive: true);
      final output = io.File(
        path.join(metadataDirectory.path, '$generationId.tvmeta'),
      );
      await output.writeAsBytes(bytes, flush: true);
      return output;
    } catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.ioFailure,
        'The encrypted metadata snapshot could not be written.',
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _buildPortablePayload({
    required String accountFingerprint,
    required String generationId,
    required DateTime createdAt,
    required String applicationVersion,
  }) async {
    final buckets = await _db.select(_db.buckets).get();
    final files = await _db.select(_db.files).get();
    final labels = await _db.select(_db.labels).get();
    final settings = (await _db.select(_db.appSettings).get())
        .where((setting) => MetadataSettingPolicy.isSafeSettingKey(setting.key))
        .toList(growable: false);

    return <String, dynamic>{
      'snapshot_schema_version': formatVersionV5,
      'database_schema_version': _db.schemaVersion,
      'application_version': applicationVersion,
      'generation_id': generationId,
      'created_at': createdAt.toIso8601String(),
      'account_fingerprint': accountFingerprint,
      'buckets': buckets
          .map(
            (bucket) => <String, dynamic>{
              'id': bucket.id,
              'chat_id': bucket.chatId.toString(),
              'name': bucket.name,
              'allowed_media_types': bucket.allowedMediaTypes,
              'is_active': bucket.isActive,
              'created_at': bucket.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
      'labels': labels
          .map(
            (label) => <String, dynamic>{
              'id': label.id,
              'name': label.name,
              'color_hex': label.colorHex,
              'emoji': label.emoji,
              'created_at': label.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
      'files': files
          .map((file) {
            final claimsRemoteCompletion =
                file.status == FileSyncStatus.synced.dbValue ||
                file.status == FileSyncStatus.deletedLocal.dbValue;
            final hasConfirmedMessage = file.telegramMessageId != null;
            final portableStatus =
                claimsRemoteCompletion && !hasConfirmedMessage
                ? FileSyncStatus.failed.dbValue
                : file.status;
            return <String, dynamic>{
              'asset_id': file.assetId,
              'display_name': _portableDisplayName(file.localPath),
              'folder_name': file.folderName,
              'file_hash': file.fileHash,
              'size': file.size,
              'bucket_id': file.bucketId,
              'telegram_message_id': file.telegramMessageId,
              'telegram_file_id': file.telegramFileId,
              'status': portableStatus,
              'is_vaulted': file.isVaulted,
              'is_encrypted': file.isEncrypted,
              'encryption_version': file.encryptionVersion,
              'vault_format_version': file.vaultFormatVersion,
              'encrypted_object_id': file.encryptedObjectId,
              'encrypted_size': file.encryptedSize,
              'original_size': file.originalSize,
              'vault_integrity_status': file.vaultIntegrityStatus,
              'vault_migration_status': file.vaultMigrationStatus,
              'key_wrapping_version': file.keyWrappingVersion,
              'last_verified_at': file.lastVerifiedAt
                  ?.toUtc()
                  .toIso8601String(),
              'deleted_locally_at': file.deletedLocallyAt
                  ?.toUtc()
                  .toIso8601String(),
              'label_id': file.labelId,
              'date_added': file.dateAdded.toUtc().toIso8601String(),
            };
          })
          .toList(growable: false),
      'settings': settings
          .map((setting) => {'key': setting.key, 'value': setting.value})
          .toList(growable: false),
    };
  }

  @override
  Future<MetadataImportResult> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  }) {
    return _operationLock.synchronized(() async {
      final raw = await _readSnapshot(snapshot);
      final inspection = _inspectRaw(raw);
      late final _ValidatedSnapshot validated;
      if (inspection.formatVersion == formatVersionV5) {
        validated = await _decodeAndValidateV5(
          raw,
          passphrase: passphrase,
          allowPassphraseProtection: true,
        );
      } else if (inspection.formatVersion == _formatVersionV3) {
        if (passphrase.trim().isEmpty) {
          throw const MetadataBackupException(
            MetadataBackupErrorCode.legacyPassphraseRequired,
            'This legacy metadata snapshot requires its export passphrase.',
          );
        }
        final fingerprint = await _currentAccountFingerprint();
        final payload = _decodeLegacyPayload(
          raw,
          fingerprint,
          (salt) => _deriveLegacyAccountBoundPassphraseKey(
            passphrase,
            salt,
            fingerprint,
          ),
        );
        validated = _validatePayload(
          payload,
          sourceFormatVersion: _formatVersionV3,
          expectedAccountFingerprint: fingerprint,
        );
      } else if (inspection.formatVersion == _formatVersionV4) {
        throw const MetadataBackupException(
          MetadataBackupErrorCode.validationFailed,
          'Legacy automatic v4 snapshots must be restored from the TeleVault metadata channel.',
        );
      } else {
        _throwUnsupportedVersion(inspection.formatVersion);
      }
      await _applyValidatedSnapshot(validated);
      return MetadataImportResult(
        sourceFormatVersion: validated.sourceFormatVersion,
        generationId: validated.generationId,
        requiresSecureMigration:
            validated.sourceFormatVersion < formatVersionV5,
      );
    });
  }

  @override
  Future<MetadataImportResult> importAccountBoundSnapshot(io.File snapshot) {
    return _operationLock.synchronized(() async {
      final raw = await _readSnapshot(snapshot);
      final inspection = _inspectRaw(raw);
      late final _ValidatedSnapshot validated;
      if (inspection.formatVersion == formatVersionV5) {
        validated = await _decodeAndValidateV5(
          raw,
          allowPassphraseProtection: false,
        );
      } else if (inspection.formatVersion == _formatVersionV4) {
        // Require a confirmed recovery key before mutating the database so the
        // caller can immediately replace weak v4 protection with v5.
        await _requireRecoveryKey();
        final fingerprint = await _currentAccountFingerprint();
        final payload = _decodeLegacyPayload(
          raw,
          fingerprint,
          (salt) => _deriveLegacyAccountOnlyKey(salt, fingerprint),
        );
        validated = _validatePayload(
          payload,
          sourceFormatVersion: _formatVersionV4,
          expectedAccountFingerprint: fingerprint,
        );
      } else {
        _throwUnsupportedVersion(inspection.formatVersion);
      }
      await _applyValidatedSnapshot(validated);
      return MetadataImportResult(
        sourceFormatVersion: validated.sourceFormatVersion,
        generationId: validated.generationId,
        requiresSecureMigration:
            validated.sourceFormatVersion < formatVersionV5,
      );
    });
  }

  @override
  Future<void> verifyAccountBoundSnapshot(io.File snapshot) {
    return _operationLock.synchronized(() async {
      final raw = await _readSnapshot(snapshot);
      final inspection = _inspectRaw(raw);
      if (inspection.formatVersion == formatVersionV5) {
        await _decodeAndValidateV5(raw, allowPassphraseProtection: false);
        return;
      }
      if (inspection.formatVersion == _formatVersionV4) {
        final fingerprint = await _currentAccountFingerprint();
        final payload = _decodeLegacyPayload(
          raw,
          fingerprint,
          (salt) => _deriveLegacyAccountOnlyKey(salt, fingerprint),
        );
        _validatePayload(
          payload,
          sourceFormatVersion: _formatVersionV4,
          expectedAccountFingerprint: fingerprint,
        );
        return;
      }
      _throwUnsupportedVersion(inspection.formatVersion);
    });
  }

  @override
  Future<MetadataSnapshotInspection> inspectSnapshot(io.File snapshot) async {
    final raw = await _readSnapshot(snapshot);
    return _inspectRaw(raw);
  }

  Future<_ValidatedSnapshot> _decodeAndValidateV5(
    Uint8List raw, {
    String? passphrase,
    required bool allowPassphraseProtection,
  }) async {
    final parsed = _parseV5Container(raw);
    final currentFingerprint = await _currentAccountFingerprint();
    if (parsed.accountFingerprint != currentFingerprint) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.wrongTelegramAccount,
        'This metadata snapshot belongs to a different Telegram account.',
      );
    }
    if (parsed.protection ==
            MetadataSnapshotProtection.recoveryKeyAndPassphrase &&
        !allowPassphraseProtection) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.legacyPassphraseRequired,
        'This metadata snapshot also requires its export passphrase.',
      );
    }
    if (parsed.protection ==
            MetadataSnapshotProtection.recoveryKeyAndPassphrase &&
        (passphrase == null || passphrase.trim().isEmpty)) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.legacyPassphraseRequired,
        'This metadata snapshot requires its export passphrase.',
      );
    }

    final recoveryKey = await _requireRecoveryKey(mustAlreadyExist: true);
    final key = await _deriveV5Key(
      recoveryKey: recoveryKey,
      salt: parsed.salt,
      accountFingerprint: currentFingerprint,
      protection: parsed.protection,
      passphrase: passphrase,
    );
    late final List<int> plaintext;
    try {
      plaintext = await _aesGcm.decrypt(
        SecretBox(parsed.ciphertext, nonce: parsed.nonce, mac: Mac(parsed.tag)),
        secretKey: key,
        aad: parsed.aad,
      );
    } on SecretBoxAuthenticationError catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.authenticationFailed,
        'The recovery key, passphrase, or snapshot authentication is invalid.',
        cause: error,
      );
    }
    if (plaintext.length != parsed.plaintextLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.authenticationFailed,
        'The authenticated metadata length is invalid.',
      );
    }
    final payload = _decodeJsonMap(plaintext);
    return _validatePayload(
      payload,
      sourceFormatVersion: formatVersionV5,
      expectedAccountFingerprint: currentFingerprint,
      expectedGenerationId: parsed.generationId,
      expectedCreatedAt: parsed.createdAt,
      expectedDatabaseSchemaVersion: parsed.databaseSchemaVersion,
      expectedApplicationVersion: parsed.applicationVersion,
    );
  }

  _ParsedV5Container _parseV5Container(Uint8List raw) {
    if (raw.length < _magic.length + 4 + _tagLength + 1 ||
        !_constantTimeEquals(raw.sublist(0, _magic.length), _magic)) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'This is not a TeleVault v5 metadata snapshot.',
      );
    }
    final headerLength = _readUint32(raw, _magic.length);
    if (headerLength <= 0 || headerLength > _maximumHeaderLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata snapshot header length is invalid.',
      );
    }
    final headerStart = _magic.length + 4;
    final headerEnd = headerStart + headerLength;
    final cipherEnd = raw.length - _tagLength;
    if (headerEnd >= cipherEnd) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata snapshot container is truncated.',
      );
    }
    final headerBytes = Uint8List.fromList(raw.sublist(headerStart, headerEnd));
    final header = _decodeJsonMap(headerBytes);
    if (_requiredInt(header, 'format_version') != formatVersionV5 ||
        _requiredString(header, 'cipher') != 'AES-256-GCM' ||
        _requiredString(header, 'kdf') != 'HKDF-HMAC-SHA256') {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.unsupportedVersion,
        'The metadata snapshot uses unsupported cryptography.',
      );
    }
    final protectionName = _requiredString(header, 'protection');
    final protection = MetadataSnapshotProtection.values.where(
      (value) => value.wireName == protectionName,
    );
    if (protection.isEmpty ||
        protection.first == MetadataSnapshotProtection.legacyAccountOnly ||
        protection.first == MetadataSnapshotProtection.legacyPassphrase) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.unsupportedVersion,
        'The v5 metadata protection mode is unsupported.',
      );
    }
    final salt = _requiredBase64(header, 'salt_b64', _v5SaltLength);
    final nonce = _requiredBase64(header, 'nonce_b64', _v5NonceLength);
    final generationId = _requiredString(header, 'generation_id');
    if (!_isUuid(generationId)) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.validationFailed,
        'The metadata generation identifier is invalid.',
      );
    }
    final createdAt = _requiredDate(header, 'created_at');
    final databaseSchema = _requiredInt(header, 'database_schema_version');
    if (databaseSchema <= 0 || databaseSchema > _db.schemaVersion) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.unsupportedVersion,
        'This metadata snapshot requires a newer TeleVault database version.',
      );
    }
    final plaintextLength = _requiredInt(header, 'plaintext_length');
    if (plaintextLength <= 0 || plaintextLength > _maximumSnapshotLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata plaintext length is invalid.',
      );
    }
    final applicationVersion = _boundedString(
      header['application_version'],
      field: 'application_version',
      minLength: 1,
      maxLength: 100,
    );
    return _ParsedV5Container(
      protection: protection.first,
      accountFingerprint: _requiredFingerprint(header),
      generationId: generationId,
      createdAt: createdAt,
      databaseSchemaVersion: databaseSchema,
      applicationVersion: applicationVersion,
      plaintextLength: plaintextLength,
      salt: salt,
      nonce: nonce,
      aad: Uint8List.fromList(raw.sublist(0, headerEnd)),
      ciphertext: Uint8List.fromList(raw.sublist(headerEnd, cipherEnd)),
      tag: Uint8List.fromList(raw.sublist(cipherEnd)),
    );
  }

  _ValidatedSnapshot _validatePayload(
    Map<String, dynamic> payload, {
    required int sourceFormatVersion,
    required String expectedAccountFingerprint,
    String? expectedGenerationId,
    DateTime? expectedCreatedAt,
    int? expectedDatabaseSchemaVersion,
    String? expectedApplicationVersion,
  }) {
    final payloadFingerprint = _requiredFingerprint(payload);
    if (payloadFingerprint != expectedAccountFingerprint) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.wrongTelegramAccount,
        'The encrypted metadata account binding is inconsistent.',
      );
    }
    final generationId = sourceFormatVersion == formatVersionV5
        ? _requiredString(payload, 'generation_id')
        : 'legacy-${legacy_crypto.sha256.convert(utf8.encode(jsonEncode(payload))).toString().substring(0, 24)}';
    if (expectedGenerationId != null && generationId != expectedGenerationId) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.authenticationFailed,
        'The metadata generation identifiers do not match.',
      );
    }
    final createdAt = sourceFormatVersion == formatVersionV5
        ? _requiredDate(payload, 'created_at')
        : _optionalDate(payload['exported_at']) ?? _clock().toUtc();
    if (expectedCreatedAt != null &&
        createdAt.toUtc() != expectedCreatedAt.toUtc()) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.authenticationFailed,
        'The metadata creation timestamps do not match.',
      );
    }
    if (sourceFormatVersion == formatVersionV5) {
      final payloadSchema = _requiredInt(payload, 'snapshot_schema_version');
      final databaseSchema = _requiredInt(payload, 'database_schema_version');
      final appVersion = _requiredString(payload, 'application_version');
      if (payloadSchema != formatVersionV5 ||
          databaseSchema != expectedDatabaseSchemaVersion ||
          appVersion != expectedApplicationVersion) {
        throw const MetadataBackupException(
          MetadataBackupErrorCode.authenticationFailed,
          'The authenticated metadata header and payload disagree.',
        );
      }
    }

    final bucketMaps = _requiredMapList(
      payload,
      'buckets',
      maximum: _maximumBuckets,
    );
    final labelMaps = _requiredMapList(
      payload,
      'labels',
      maximum: _maximumLabels,
    );
    final fileMaps = _requiredMapList(payload, 'files', maximum: _maximumFiles);
    final settingMaps = _requiredMapList(payload, 'settings', maximum: 10000);

    final bucketIds = <int>{};
    final buckets = <_BucketSnapshot>[];
    var activeCount = 0;
    for (final row in bucketMaps) {
      final id = _positiveInt(row['id'], 'bucket.id');
      if (!bucketIds.add(id)) {
        _validationFailure('Bucket IDs must be unique.');
      }
      final chatId = _signedInt64(row['chat_id'], 'bucket.chat_id');
      if (chatId == BigInt.zero) {
        _validationFailure('Bucket chat ID is invalid.');
      }
      final isActive = _requiredBool(row, 'is_active');
      if (isActive) activeCount++;
      buckets.add(
        _BucketSnapshot(
          id: id,
          chatId: chatId,
          name: _boundedString(
            row['name'],
            field: 'bucket.name',
            minLength: 1,
            maxLength: 50,
          ),
          allowedMediaTypes: _validateMediaTypes(
            _boundedString(
              row['allowed_media_types'] ?? 'photo,video',
              field: 'bucket.allowed_media_types',
              minLength: 1,
              maxLength: 100,
            ),
          ),
          isActive: isActive,
          createdAt: _requiredDate(row, 'created_at'),
        ),
      );
    }
    if (activeCount > 1) {
      _validationFailure('Only one restored bucket may be active.');
    }

    final labelIds = <int>{};
    final labels = <_LabelSnapshot>[];
    for (final row in labelMaps) {
      final id = _positiveInt(row['id'], 'label.id');
      if (!labelIds.add(id)) _validationFailure('Label IDs must be unique.');
      labels.add(
        _LabelSnapshot(
          id: id,
          name: _boundedString(
            row['name'],
            field: 'label.name',
            minLength: 1,
            maxLength: 11,
          ),
          colorHex: _validColor(row['color_hex']),
          emoji: _optionalBoundedString(row['emoji'], 32),
          createdAt: _requiredDate(row, 'created_at'),
        ),
      );
    }

    final files = <_FileSnapshot>[];
    for (var index = 0; index < fileMaps.length; index++) {
      final row = fileMaps[index];
      final bucketId = _positiveInt(row['bucket_id'], 'file.bucket_id');
      if (!bucketIds.contains(bucketId)) {
        _validationFailure('A file references an unknown bucket.');
      }
      final labelId = _optionalPositiveInt(row['label_id'], 'file.label_id');
      if (labelId != null && !labelIds.contains(labelId)) {
        _validationFailure('A file references an unknown label.');
      }
      final status = _requiredInt(row, 'status');
      if (status < FileSyncStatus.pending.dbValue ||
          status > FileSyncStatus.vaultedEncrypted.dbValue) {
        _validationFailure('A file has an invalid sync status.');
      }
      final size = _nonNegativeInt(row['size'], 'file.size');
      if (size > _maximumPortableFileSize) {
        _validationFailure('A file size exceeds the portable metadata limit.');
      }
      final messageId = _optionalPositiveInt(
        row['telegram_message_id'],
        'file.telegram_message_id',
      );
      final telegramFileId = _optionalPositiveInt(
        row['telegram_file_id'],
        'file.telegram_file_id',
      );
      if ((status == FileSyncStatus.synced.dbValue ||
              status == FileSyncStatus.deletedLocal.dbValue) &&
          messageId == null) {
        _validationFailure('A synced file has no Telegram message reference.');
      }
      final encryptedSize = _optionalNonNegativeInt(
        row['encrypted_size'],
        'file.encrypted_size',
      );
      final originalSize = _optionalNonNegativeInt(
        row['original_size'],
        'file.original_size',
      );
      if ((encryptedSize ?? 0) > _maximumPortableFileSize ||
          (originalSize ?? 0) > _maximumPortableFileSize) {
        _validationFailure('A vault file size is invalid.');
      }
      files.add(
        _FileSnapshot(
          index: index,
          assetId: _optionalBoundedString(row['asset_id'], 512),
          displayName: _optionalBoundedString(
            row['display_name'] ?? _legacyBasename(row['local_path']),
            512,
          ),
          folderName: _boundedString(
            row['folder_name'] ?? 'Unknown',
            field: 'file.folder_name',
            minLength: 1,
            maxLength: 512,
          ),
          fileHash: _optionalHash(row['file_hash']),
          size: size,
          bucketId: bucketId,
          telegramMessageId: messageId,
          telegramFileId: telegramFileId,
          status: status,
          isVaulted: _optionalBool(row['is_vaulted']) ?? false,
          isEncrypted: _optionalBool(row['is_encrypted']) ?? false,
          encryptionVersion: _optionalPositiveInt(
            row['encryption_version'],
            'file.encryption_version',
          ),
          vaultFormatVersion: _optionalPositiveInt(
            row['vault_format_version'],
            'file.vault_format_version',
          ),
          encryptedObjectId: _optionalBoundedString(
            row['encrypted_object_id'],
            128,
          ),
          encryptedSize: encryptedSize,
          originalSize: originalSize,
          vaultIntegrityStatus: _enumString(
            row['vault_integrity_status'] ?? 'unknown',
            'file.vault_integrity_status',
            const {'unknown', 'verified', 'failed'},
          ),
          vaultMigrationStatus: _enumString(
            row['vault_migration_status'] ?? 'notRequired',
            'file.vault_migration_status',
            const {
              'notRequired',
              'pending',
              'inProgress',
              'completed',
              'failed',
            },
          ),
          keyWrappingVersion: _optionalPositiveInt(
            row['key_wrapping_version'],
            'file.key_wrapping_version',
          ),
          lastVerifiedAt: _optionalDate(row['last_verified_at']),
          deletedLocallyAt: _optionalDate(row['deleted_locally_at']),
          labelId: labelId,
          dateAdded: _requiredDate(row, 'date_added'),
        ),
      );
    }

    final settings = <_SettingSnapshot>[];
    final settingKeys = <String>{};
    for (final row in settingMaps) {
      final key = _boundedString(
        row['key'],
        field: 'setting.key',
        minLength: 1,
        maxLength: 200,
      );
      if (!MetadataSettingPolicy.isSafeSettingKey(key)) continue;
      if (!settingKeys.add(key)) {
        _validationFailure('Metadata setting keys must be unique.');
      }
      settings.add(
        _SettingSnapshot(
          key: key,
          value: _boundedString(
            row['value'] ?? '',
            field: 'setting.value',
            minLength: 0,
            maxLength: 100000,
          ),
        ),
      );
    }

    return _ValidatedSnapshot(
      sourceFormatVersion: sourceFormatVersion,
      generationId: generationId,
      createdAt: createdAt,
      accountFingerprint: expectedAccountFingerprint,
      buckets: buckets,
      labels: labels,
      files: files,
      settings: settings,
    );
  }

  Future<void> _applyValidatedSnapshot(_ValidatedSnapshot snapshot) async {
    final bucketChatIds = <int, BigInt>{
      for (final bucket in snapshot.buckets) bucket.id: bucket.chatId,
    };
    final messageIds = <int, Set<int>>{};
    for (final file in snapshot.files) {
      final messageId = file.telegramMessageId;
      if (messageId != null) {
        messageIds.putIfAbsent(file.bucketId, () => <int>{}).add(messageId);
      }
    }
    final reconciliation = await _remoteVerifier.reconcile(
      bucketChatIds: bucketChatIds,
      messageIdsByBucket: messageIds,
    );

    await _db.transaction(() async {
      await _db.delete(_db.files).go();
      await _db.delete(_db.buckets).go();
      await _db.delete(_db.labels).go();
      final existingSettings = await _db.select(_db.appSettings).get();
      for (final setting in existingSettings) {
        if (!MetadataSettingPolicy.isSafeSettingKey(setting.key)) continue;
        await (_db.delete(
          _db.appSettings,
        )..where((table) => table.key.equals(setting.key))).go();
      }

      final bucketIdMap = <int, int>{};
      for (final bucket in snapshot.buckets) {
        final insertedId = await _db
            .into(_db.buckets)
            .insert(
              BucketsCompanion.insert(
                chatId: bucket.chatId,
                name: bucket.name,
                allowedMediaTypes: Value(bucket.allowedMediaTypes),
                isActive: Value(bucket.isActive),
                createdAt: Value(bucket.createdAt),
              ),
            );
        bucketIdMap[bucket.id] = insertedId;
      }

      final labelIdMap = <int, int>{};
      for (final label in snapshot.labels) {
        final insertedId = await _db
            .into(_db.labels)
            .insert(
              LabelsCompanion.insert(
                name: label.name,
                colorHex: Value(label.colorHex),
                emoji: Value(label.emoji),
                createdAt: Value(label.createdAt),
              ),
            );
        labelIdMap[label.id] = insertedId;
      }

      for (final file in snapshot.files) {
        final newBucketId = bucketIdMap[file.bucketId]!;
        final messageId = file.telegramMessageId;
        final messageVerified =
            messageId == null ||
            reconciliation.isMessageVerified(file.bucketId, messageId);
        final claimsRemoteCompletion =
            file.status == FileSyncStatus.synced.dbValue ||
            file.status == FileSyncStatus.deletedLocal.dbValue;
        final encryptedLocalObjectMissing =
            file.isEncrypted && !claimsRemoteCompletion;
        final importedStatus =
            !messageVerified && claimsRemoteCompletion ||
                encryptedLocalObjectMissing
            ? FileSyncStatus.failed.dbValue
            : file.status == FileSyncStatus.uploading.dbValue
            ? FileSyncStatus.pending.dbValue
            : file.status;
        final needsUserAction =
            (!messageVerified && claimsRemoteCompletion) ||
            encryptedLocalObjectMissing;
        final unresolvedPath =
            'televault-unresolved://${snapshot.generationId}/${file.index}';

        await _db
            .into(_db.files)
            .insert(
              FilesCompanion.insert(
                localPath: unresolvedPath,
                localPathResolved: const Value(false),
                localMediaAccessState: const Value('accessUnavailable'),
                assetId: Value(file.assetId),
                folderName: file.folderName,
                fileHash: Value(file.fileHash),
                size: file.size,
                bucketId: newBucketId,
                telegramMessageId: Value(file.telegramMessageId),
                telegramFileId: Value(
                  messageVerified ? file.telegramFileId : null,
                ),
                remoteStateVerified: Value(messageVerified),
                status: Value(importedStatus),
                retryCount: const Value(0),
                lastError: Value(
                  needsUserAction
                      ? 'Restored metadata requires local or Telegram reconciliation.'
                      : null,
                ),
                nextRetryAt: const Value(null),
                lastAttemptAt: const Value(null),
                telegramErrorCode: const Value(null),
                telegramErrorCategory: const Value(null),
                telegramRetryAfter: const Value(null),
                lastTelegramOperation: const Value(null),
                userActionRequired: Value(needsUserAction),
                isVaulted: Value(file.isVaulted),
                isEncrypted: Value(file.isEncrypted),
                encryptionVersion: Value(file.encryptionVersion),
                ivB64: const Value(null),
                vaultFormatVersion: Value(file.vaultFormatVersion),
                encryptedObjectId: Value(file.encryptedObjectId),
                encryptedSize: Value(file.encryptedSize),
                originalSize: Value(file.originalSize),
                vaultIntegrityStatus: Value(file.vaultIntegrityStatus),
                vaultMigrationStatus: Value(file.vaultMigrationStatus),
                keyWrappingVersion: Value(file.keyWrappingVersion),
                lastVerifiedAt: Value(
                  messageVerified ? file.lastVerifiedAt : null,
                ),
                deletedLocallyAt: Value(file.deletedLocallyAt),
                labelId: Value(
                  file.labelId == null ? null : labelIdMap[file.labelId!],
                ),
                dateAdded: Value(file.dateAdded),
              ),
            );
      }

      for (final setting in snapshot.settings) {
        final key = MetadataSettingPolicy.normalizeImportedSettingKey(
          setting.key,
          bucketIdMap,
        );
        if (key == null) continue;
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: key, value: setting.value),
            );
      }
      await _settingsService.normalizeStoredUploadLimits();
      await _importCommitHook?.call();
    });
  }

  Map<String, dynamic> _decodeLegacyPayload(
    Uint8List raw,
    String currentAccountFingerprint,
    legacy_encryption.Key Function(Uint8List salt) keyBuilder,
  ) {
    if (raw.length < 3 + _legacySaltLength + _legacyIvLength + 1) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The legacy metadata snapshot is truncated.',
      );
    }
    final headerLength = (raw[1] << 8) | raw[2];
    if (headerLength <= 0 || headerLength > _maximumHeaderLength) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The legacy metadata header length is invalid.',
      );
    }
    final headerStart = 3;
    final headerEnd = headerStart + headerLength;
    final saltStart = headerEnd;
    final ivStart = saltStart + _legacySaltLength;
    final cipherStart = ivStart + _legacyIvLength;
    if (headerEnd > raw.length || cipherStart >= raw.length) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The legacy metadata snapshot is malformed.',
      );
    }
    final header = _decodeJsonMap(raw.sublist(headerStart, headerEnd));
    final snapshotFingerprint = _requiredFingerprint(header);
    if (snapshotFingerprint != currentAccountFingerprint) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.wrongTelegramAccount,
        'This metadata snapshot belongs to a different Telegram account.',
      );
    }
    final salt = Uint8List.fromList(raw.sublist(saltStart, ivStart));
    final iv = legacy_encryption.IV(
      Uint8List.fromList(raw.sublist(ivStart, cipherStart)),
    );
    final encrypted = legacy_encryption.Encrypted(
      Uint8List.fromList(raw.sublist(cipherStart)),
    );
    try {
      final encrypter = legacy_encryption.Encrypter(
        legacy_encryption.AES(
          keyBuilder(salt),
          mode: legacy_encryption.AESMode.gcm,
        ),
      );
      return _decodeJsonMap(encrypter.decryptBytes(encrypted, iv: iv));
    } catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.authenticationFailed,
        'The legacy passphrase, account, or snapshot authentication is invalid.',
        cause: error,
      );
    }
  }

  Future<SecretKey> _deriveV5Key({
    required Uint8List recoveryKey,
    required Uint8List salt,
    required String accountFingerprint,
    required MetadataSnapshotProtection protection,
    String? passphrase,
  }) async {
    final material = BytesBuilder()..add(recoveryKey);
    if (protection == MetadataSnapshotProtection.recoveryKeyAndPassphrase) {
      if (passphrase == null || passphrase.trim().isEmpty) {
        throw const MetadataBackupException(
          MetadataBackupErrorCode.legacyPassphraseRequired,
          'The metadata export passphrase is required.',
        );
      }
      material.add(
        _legacyPbkdf2(
          password: utf8.encode(passphrase),
          salt: salt,
          iterations: _legacyPbkdf2Iterations,
          keyLength: 32,
        ),
      );
    }
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(material.toBytes()),
      nonce: salt,
      info: utf8.encode(
        '$_metadataKdfContext\n${protection.wireName}\n$accountFingerprint',
      ),
    );
  }

  legacy_encryption.Key _deriveLegacyAccountBoundPassphraseKey(
    String passphrase,
    Uint8List salt,
    String accountFingerprint,
  ) {
    return legacy_encryption.Key(
      _legacyPbkdf2(
        password: utf8.encode('$passphrase\n$accountFingerprint'),
        salt: salt,
        iterations: _legacyPbkdf2Iterations,
        keyLength: 32,
      ),
    );
  }

  legacy_encryption.Key _deriveLegacyAccountOnlyKey(
    Uint8List salt,
    String accountFingerprint,
  ) {
    return legacy_encryption.Key(
      _legacyPbkdf2(
        password: utf8.encode(
          'televault.account.metadata.v1\n$accountFingerprint',
        ),
        salt: salt,
        iterations: _legacyPbkdf2Iterations,
        keyLength: 32,
      ),
    );
  }

  Uint8List _legacyPbkdf2({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = legacy_crypto.Hmac(legacy_crypto.sha256, password);
    final hashLength = legacy_crypto.sha256.convert(const []).bytes.length;
    final blocks = (keyLength / hashLength).ceil();
    final output = Uint8List(keyLength);
    var offset = 0;
    for (var block = 1; block <= blocks; block++) {
      final blockInput = BytesBuilder()
        ..add(salt)
        ..add(_uint32BigEndian(block));
      var u = Uint8List.fromList(hmac.convert(blockInput.toBytes()).bytes);
      final accumulator = Uint8List.fromList(u);
      for (var round = 1; round < iterations; round++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var index = 0; index < accumulator.length; index++) {
          accumulator[index] ^= u[index];
        }
      }
      final copyLength = min(keyLength - offset, hashLength);
      output.setRange(offset, offset + copyLength, accumulator);
      offset += copyLength;
    }
    return output;
  }

  Future<Uint8List> _requireRecoveryKey({bool mustAlreadyExist = false}) async {
    try {
      return await _recoveryKeyProvider.requireConfirmedKey();
    } on VaultRecoveryException catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.recoveryKeyRequired,
        mustAlreadyExist
            ? 'Import the original TeleVault Recovery Key to restore this metadata snapshot.'
            : 'Record and confirm the TeleVault Recovery Key before backing up metadata.',
        cause: error,
        requiresExistingRecoveryKey: mustAlreadyExist,
      );
    }
  }

  Future<Uint8List> _readSnapshot(io.File snapshot) async {
    try {
      final length = await snapshot.length();
      if (length <= 0 || length > _maximumSnapshotLength) {
        throw const MetadataBackupException(
          MetadataBackupErrorCode.invalidSnapshot,
          'The metadata snapshot size is invalid.',
        );
      }
      return Uint8List.fromList(await snapshot.readAsBytes());
    } on MetadataBackupException {
      rethrow;
    } catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.ioFailure,
        'The metadata snapshot could not be read.',
        cause: error,
      );
    }
  }

  MetadataSnapshotInspection _inspectRaw(Uint8List raw) {
    if (raw.length >= _magic.length &&
        _constantTimeEquals(raw.sublist(0, _magic.length), _magic)) {
      final parsed = _parseV5Container(raw);
      return MetadataSnapshotInspection(
        formatVersion: formatVersionV5,
        protection: parsed.protection,
        generationId: parsed.generationId,
        createdAt: parsed.createdAt,
      );
    }
    if (raw.isEmpty) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata snapshot is empty.',
      );
    }
    return switch (raw.first) {
      _formatVersionV3 => const MetadataSnapshotInspection(
        formatVersion: _formatVersionV3,
        protection: MetadataSnapshotProtection.legacyPassphrase,
      ),
      _formatVersionV4 => const MetadataSnapshotInspection(
        formatVersion: _formatVersionV4,
        protection: MetadataSnapshotProtection.legacyAccountOnly,
      ),
      final version => MetadataSnapshotInspection(
        formatVersion: version,
        protection: MetadataSnapshotProtection.legacyAccountOnly,
      ),
    };
  }

  Future<String> _currentAccountFingerprint() async {
    TelegramResult me;
    try {
      me = await _telegram.request({
        '@type': 'getMe',
      }, timeout: const Duration(seconds: 10));
    } catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.accountUnavailable,
        'The current Telegram account could not be verified.',
        cause: error,
      );
    }
    final id = me['id'];
    if (me['@type'] == 'error' || id == null) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.accountUnavailable,
        'The current Telegram account could not be verified.',
      );
    }
    return fingerprintForAccountId(id);
  }

  static String fingerprintForAccountId(Object accountId) {
    return legacy_crypto.sha256
        .convert(
          utf8.encode('televault.telegram.account.v1:${accountId.toString()}'),
        )
        .toString();
  }

  static Future<String> _defaultApplicationVersion() async {
    final package = await PackageInfo.fromPlatform();
    return '${package.version}+${package.buildNumber}';
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String? _portableDisplayName(String localPath) {
    if (localPath.startsWith('televault-unresolved://')) return null;
    final name = path.basename(localPath);
    return name.isEmpty || name == '.' ? null : name;
  }

  static String? _legacyBasename(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  Never _throwUnsupportedVersion(int version) {
    final message = switch (version) {
      _formatVersionV1 || _formatVersionV2 =>
        'This old metadata format has no safe Telegram account binding and cannot be imported.',
      _formatVersionV3 =>
        'This passphrase snapshot must be imported through manual metadata restore.',
      _ => 'Unsupported metadata snapshot version: $version.',
    };
    throw MetadataBackupException(
      MetadataBackupErrorCode.unsupportedVersion,
      message,
    );
  }

  static Map<String, dynamic> _decodeJsonMap(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } catch (error) {
      throw MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata snapshot contains invalid structured data.',
        cause: error,
      );
    }
  }

  static List<Map<String, dynamic>> _requiredMapList(
    Map<String, dynamic> map,
    String field, {
    required int maximum,
  }) {
    final value = map[field];
    if (value is! List || value.length > maximum) {
      _validationFailure('The metadata $field collection is invalid.');
    }
    final result = <Map<String, dynamic>>[];
    for (final row in value) {
      if (row is! Map<String, dynamic>) {
        _validationFailure(
          'The metadata $field collection has an invalid row.',
        );
      }
      result.add(row);
    }
    return result;
  }

  static String _requiredFingerprint(Map<String, dynamic> map) {
    final fingerprint = _requiredString(map, 'account_fingerprint');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
      _validationFailure('The Telegram account fingerprint is invalid.');
    }
    return fingerprint;
  }

  static String _requiredString(Map<String, dynamic> map, String field) {
    return _boundedString(
      map[field],
      field: field,
      minLength: 1,
      maxLength: 1000,
    );
  }

  static String _boundedString(
    dynamic value, {
    required String field,
    required int minLength,
    required int maxLength,
  }) {
    if (value is! String ||
        value.length < minLength ||
        value.length > maxLength ||
        value.contains('\u0000')) {
      _validationFailure('The metadata field $field is invalid.');
    }
    return value;
  }

  static String? _optionalBoundedString(dynamic value, int maxLength) {
    if (value == null) return null;
    return _boundedString(
      value,
      field: 'optional_string',
      minLength: 0,
      maxLength: maxLength,
    );
  }

  static String? _optionalHash(dynamic value) {
    final hash = _optionalBoundedString(value, 256);
    if (hash == null || hash.isEmpty) return null;
    if (!RegExp(r'^[A-Fa-f0-9]{32,256}$').hasMatch(hash)) {
      _validationFailure('A file hash is invalid.');
    }
    return hash;
  }

  static int _requiredInt(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    _validationFailure('The metadata field $field must be an integer.');
  }

  static int _positiveInt(dynamic value, String field) {
    final parsed = _integerValue(value, field);
    if (parsed <= 0) {
      _validationFailure('The metadata field $field is invalid.');
    }
    return parsed;
  }

  static int _nonNegativeInt(dynamic value, String field) {
    final parsed = _integerValue(value, field);
    if (parsed < 0) _validationFailure('The metadata field $field is invalid.');
    return parsed;
  }

  static int? _optionalPositiveInt(dynamic value, String field) {
    if (value == null) return null;
    return _positiveInt(value, field);
  }

  static int? _optionalNonNegativeInt(dynamic value, String field) {
    if (value == null) return null;
    return _nonNegativeInt(value, field);
  }

  static int _integerValue(dynamic value, String field) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    _validationFailure('The metadata field $field must be an integer.');
  }

  static BigInt _signedInt64(dynamic value, String field) {
    final parsed = switch (value) {
      int intValue => BigInt.from(intValue),
      String stringValue => BigInt.tryParse(stringValue),
      _ => null,
    };
    final minimum = -(BigInt.one << 63);
    final maximum = (BigInt.one << 63) - BigInt.one;
    if (parsed == null || parsed < minimum || parsed > maximum) {
      _validationFailure(
        'The metadata field $field is not a signed 64-bit ID.',
      );
    }
    return parsed;
  }

  static bool _requiredBool(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! bool) {
      _validationFailure('The metadata field $field must be a boolean.');
    }
    return value;
  }

  static bool? _optionalBool(dynamic value) {
    if (value == null) return null;
    if (value is! bool) {
      _validationFailure('A metadata boolean is invalid.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, dynamic> map, String field) {
    final result = _optionalDate(map[field]);
    if (result == null) {
      _validationFailure('The metadata date $field is invalid.');
    }
    return result.toUtc();
  }

  static DateTime? _optionalDate(dynamic value) {
    if (value == null) return null;
    if (value is! String) _validationFailure('A metadata date is invalid.');
    final date = DateTime.tryParse(value);
    if (date == null) _validationFailure('A metadata date is invalid.');
    return date.toUtc();
  }

  static Uint8List _requiredBase64(
    Map<String, dynamic> map,
    String field,
    int length,
  ) {
    final encoded = _requiredString(map, field);
    try {
      final bytes = Uint8List.fromList(base64Url.decode(encoded));
      if (bytes.length != length) throw const FormatException();
      return bytes;
    } on FormatException {
      _validationFailure('The metadata field $field has an invalid length.');
    }
  }

  static String _validColor(dynamic value) {
    final color = _boundedString(
      value ?? '#0A84FF',
      field: 'label.color_hex',
      minLength: 7,
      maxLength: 9,
    );
    if (!RegExp(r'^#[A-Fa-f0-9]{6}([A-Fa-f0-9]{2})?$').hasMatch(color)) {
      _validationFailure('A label color is invalid.');
    }
    return color;
  }

  static String _enumString(dynamic value, String field, Set<String> allowed) {
    final parsed = _boundedString(
      value,
      field: field,
      minLength: 1,
      maxLength: 32,
    );
    if (!allowed.contains(parsed)) {
      _validationFailure('The metadata field $field has an invalid value.');
    }
    return parsed;
  }

  static String _validateMediaTypes(String value) {
    const allowed = {'photo', 'video', 'document', 'app', 'other'};
    final entries = value.split(',').where((entry) => entry.isNotEmpty).toSet();
    if (entries.isEmpty || entries.any((entry) => !allowed.contains(entry))) {
      _validationFailure('The bucket media type selection is invalid.');
    }
    return entries.join(',');
  }

  static bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  static Uint8List _join(List<List<int>> values) {
    final builder = BytesBuilder(copy: false);
    for (final value in values) {
      builder.add(value);
    }
    return builder.toBytes();
  }

  static Uint8List _uint32BigEndian(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  static int _readUint32(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The metadata snapshot is truncated.',
      );
    }
    return ByteData.sublistView(
      bytes,
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);
  }

  static bool _constantTimeEquals(List<int> first, List<int> second) {
    var difference = first.length ^ second.length;
    final count = min(first.length, second.length);
    for (var index = 0; index < count; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }

  static Never _validationFailure(String message) {
    throw MetadataBackupException(
      MetadataBackupErrorCode.validationFailed,
      message,
    );
  }
}

class _ParsedV5Container {
  final MetadataSnapshotProtection protection;
  final String accountFingerprint;
  final String generationId;
  final DateTime createdAt;
  final int databaseSchemaVersion;
  final String applicationVersion;
  final int plaintextLength;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List aad;
  final Uint8List ciphertext;
  final Uint8List tag;

  const _ParsedV5Container({
    required this.protection,
    required this.accountFingerprint,
    required this.generationId,
    required this.createdAt,
    required this.databaseSchemaVersion,
    required this.applicationVersion,
    required this.plaintextLength,
    required this.salt,
    required this.nonce,
    required this.aad,
    required this.ciphertext,
    required this.tag,
  });
}

class _ValidatedSnapshot {
  final int sourceFormatVersion;
  final String generationId;
  final DateTime createdAt;
  final String accountFingerprint;
  final List<_BucketSnapshot> buckets;
  final List<_LabelSnapshot> labels;
  final List<_FileSnapshot> files;
  final List<_SettingSnapshot> settings;

  const _ValidatedSnapshot({
    required this.sourceFormatVersion,
    required this.generationId,
    required this.createdAt,
    required this.accountFingerprint,
    required this.buckets,
    required this.labels,
    required this.files,
    required this.settings,
  });
}

class _BucketSnapshot {
  final int id;
  final BigInt chatId;
  final String name;
  final String allowedMediaTypes;
  final bool isActive;
  final DateTime createdAt;

  const _BucketSnapshot({
    required this.id,
    required this.chatId,
    required this.name,
    required this.allowedMediaTypes,
    required this.isActive,
    required this.createdAt,
  });
}

class _LabelSnapshot {
  final int id;
  final String name;
  final String colorHex;
  final String? emoji;
  final DateTime createdAt;

  const _LabelSnapshot({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.emoji,
    required this.createdAt,
  });
}

class _FileSnapshot {
  final int index;
  final String? assetId;
  final String? displayName;
  final String folderName;
  final String? fileHash;
  final int size;
  final int bucketId;
  final int? telegramMessageId;
  final int? telegramFileId;
  final int status;
  final bool isVaulted;
  final bool isEncrypted;
  final int? encryptionVersion;
  final int? vaultFormatVersion;
  final String? encryptedObjectId;
  final int? encryptedSize;
  final int? originalSize;
  final String vaultIntegrityStatus;
  final String vaultMigrationStatus;
  final int? keyWrappingVersion;
  final DateTime? lastVerifiedAt;
  final DateTime? deletedLocallyAt;
  final int? labelId;
  final DateTime dateAdded;

  const _FileSnapshot({
    required this.index,
    required this.assetId,
    required this.displayName,
    required this.folderName,
    required this.fileHash,
    required this.size,
    required this.bucketId,
    required this.telegramMessageId,
    required this.telegramFileId,
    required this.status,
    required this.isVaulted,
    required this.isEncrypted,
    required this.encryptionVersion,
    required this.vaultFormatVersion,
    required this.encryptedObjectId,
    required this.encryptedSize,
    required this.originalSize,
    required this.vaultIntegrityStatus,
    required this.vaultMigrationStatus,
    required this.keyWrappingVersion,
    required this.lastVerifiedAt,
    required this.deletedLocallyAt,
    required this.labelId,
    required this.dateAdded,
  });
}

class _SettingSnapshot {
  final String key;
  final String value;

  const _SettingSnapshot({required this.key, required this.value});
}

class MetadataSettingPolicy {
  static const safeSettingKeys = {
    'auto_backup',
    'sync_include_photos',
    'sync_include_videos',
    'sync_wifi_only',
    'sync_charging_only',
    'sync_max_file_size_mb',
    'sync_upload_format',
    'metadata_backup_every_files',
    'diagnostics_enabled',
  };

  static final _bucketScopedSettingPattern = RegExp(
    r'^bucket\.(\d+)\.([a-z_]+)$',
  );

  const MetadataSettingPolicy._();

  static bool isSafeSettingKey(String key) {
    if (safeSettingKeys.contains(key)) return true;
    final match = _bucketScopedSettingPattern.firstMatch(key);
    if (match == null) return false;
    final baseKey = match.group(2);
    return baseKey != null && safeSettingKeys.contains(baseKey);
  }

  static String? normalizeImportedSettingKey(
    String? key,
    Map<int, int> bucketIdMap,
  ) {
    if (key == null) return null;
    if (safeSettingKeys.contains(key)) return key;
    final match = _bucketScopedSettingPattern.firstMatch(key);
    if (match == null) return null;
    final oldBucketId = int.tryParse(match.group(1) ?? '');
    final baseKey = match.group(2);
    if (oldBucketId == null ||
        baseKey == null ||
        !safeSettingKeys.contains(baseKey)) {
      return null;
    }
    final newBucketId = bucketIdMap[oldBucketId];
    if (newBucketId == null) return null;
    return 'bucket.$newBucketId.$baseKey';
  }
}
