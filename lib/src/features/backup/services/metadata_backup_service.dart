import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_service.dart';
import '../../settings/services/settings_service.dart';

final metadataBackupServiceProvider = Provider<MetadataBackupService>((ref) {
  return DriftMetadataBackupService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});

abstract interface class MetadataBackupService {
  Future<io.File> exportEncryptedSnapshot({required String passphrase});
  Future<io.File> exportAccountBoundSnapshot();
  Future<void> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  });
  Future<void> importAccountBoundSnapshot(io.File snapshot);
}

class DriftMetadataBackupService implements MetadataBackupService {
  final AppDatabase _db;
  final TelegramService _telegram;
  final SettingsService _settingsService;

  static const _formatVersionV1 = 1;
  static const _formatVersionV2 = 2;
  static const _formatVersionV3 = 3;
  static const _formatVersionV4 = 4;
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _pbkdf2Iterations = 120000;

  DriftMetadataBackupService(this._db, this._telegram, this._settingsService);

  @override
  Future<io.File> exportEncryptedSnapshot({required String passphrase}) async {
    if (passphrase.trim().isEmpty) {
      throw Exception('Passphrase is required for metadata export');
    }
    final accountFingerprint = await _currentAccountFingerprint();
    final payload = await _buildPayload(accountFingerprint);
    final salt = _randomBytes(_saltLength);
    return _writeEncryptedSnapshot(
      payload: payload,
      accountFingerprint: accountFingerprint,
      formatVersion: _formatVersionV3,
      protection: 'passphrase',
      salt: salt,
      key: _deriveAccountBoundPassphraseKey(
        passphrase,
        salt,
        accountFingerprint,
      ),
    );
  }

  @override
  Future<io.File> exportAccountBoundSnapshot() async {
    final accountFingerprint = await _currentAccountFingerprint();
    final payload = await _buildPayload(accountFingerprint);
    final salt = _randomBytes(_saltLength);
    return _writeEncryptedSnapshot(
      payload: payload,
      accountFingerprint: accountFingerprint,
      formatVersion: _formatVersionV4,
      protection: 'telegram-account',
      salt: salt,
      key: _deriveAccountOnlyKey(salt, accountFingerprint),
    );
  }

  Future<Map<String, dynamic>> _buildPayload(String accountFingerprint) async {
    final buckets = await _db.select(_db.buckets).get();
    final files = await _db.select(_db.files).get();
    final labels = await _db.select(_db.labels).get();
    final settings = (await _db.select(_db.appSettings).get())
        .where((setting) => MetadataSettingPolicy.isSafeSettingKey(setting.key))
        .toList();

    return {
      'schema_version': _formatVersionV3,
      'exported_at': DateTime.now().toIso8601String(),
      'account_fingerprint': accountFingerprint,
      'buckets': buckets
          .map(
            (b) => {
              'id': b.id,
              'chat_id': b.chatId.toString(),
              'name': b.name,
              'allowed_media_types': b.allowedMediaTypes,
              'is_active': b.isActive,
              'created_at': b.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'labels': labels
          .map(
            (label) => {
              'id': label.id,
              'name': label.name,
              'color_hex': label.colorHex,
              'emoji': label.emoji,
              'created_at': label.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'files': files
          .map(
            (f) => {
              'asset_id': f.assetId,
              'local_path': f.localPath,
              'folder_name': f.folderName,
              'file_hash': f.fileHash,
              'size': f.size,
              'bucket_id': f.bucketId,
              'telegram_message_id': f.telegramMessageId,
              'telegram_file_id': f.telegramFileId,
              'status': f.status,
              'retry_count': f.retryCount,
              'last_error': f.lastError,
              'next_retry_at': f.nextRetryAt?.toIso8601String(),
              'last_attempt_at': f.lastAttemptAt?.toIso8601String(),
              'telegram_error_code': f.telegramErrorCode,
              'telegram_error_category': f.telegramErrorCategory,
              'telegram_retry_after': f.telegramRetryAfter?.toIso8601String(),
              'last_telegram_operation': f.lastTelegramOperation,
              'user_action_required': f.userActionRequired,
              'is_vaulted': f.isVaulted,
              'is_encrypted': f.isEncrypted,
              'encryption_version': f.encryptionVersion,
              'iv_b64': f.ivB64,
              'deleted_locally_at': f.deletedLocallyAt?.toIso8601String(),
              'label_id': f.labelId,
              'date_added': f.dateAdded.toIso8601String(),
            },
          )
          .toList(),
      'settings': settings
          .map((s) => {'key': s.key, 'value': s.value})
          .toList(),
    };
  }

  Future<io.File> _writeEncryptedSnapshot({
    required Map<String, dynamic> payload,
    required String accountFingerprint,
    required int formatVersion,
    required String protection,
    required Uint8List salt,
    required enc.Key key,
  }) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
    final headerBytes = utf8.encode(
      jsonEncode({
        'format_version': formatVersion,
        'account_fingerprint': accountFingerprint,
        'protection': protection,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
      }),
    );
    if (headerBytes.length > 65535) {
      throw Exception('Metadata header is too large');
    }

    final bytes = BytesBuilder()
      ..addByte(formatVersion)
      ..add(_uint16BigEndian(headerBytes.length))
      ..add(headerBytes)
      ..add(salt)
      ..add(iv.bytes)
      ..add(encrypted.bytes);

    final dir = await getTemporaryDirectory();
    final filename =
        'tele_vault_metadata_${DateTime.now().millisecondsSinceEpoch}.tvmeta';
    final outFile = io.File(p.join(dir.path, filename));
    await outFile.writeAsBytes(bytes.toBytes(), flush: true);
    return outFile;
  }

  @override
  Future<void> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  }) async {
    final raw = await snapshot.readAsBytes();
    if (raw.isEmpty) {
      throw Exception('Invalid metadata snapshot');
    }

    final version = raw.first;
    Map<String, dynamic> map;
    if (version == _formatVersionV3) {
      final accountFingerprint = await _currentAccountFingerprint();
      map = _decodeV3Payload(raw, passphrase, accountFingerprint);
    } else if (version == _formatVersionV4) {
      throw Exception(
        'This metadata snapshot is automatic and account-bound. Use automatic TeleVault restore instead of passphrase import.',
      );
    } else if (version == _formatVersionV1) {
      throw Exception(
        'This metadata snapshot is from an older unbound format. Export a new snapshot from the same Telegram account.',
      );
    } else if (version == _formatVersionV2) {
      throw Exception(
        'This metadata snapshot is not bound to a Telegram account. Export a new snapshot before importing.',
      );
    } else {
      throw Exception('Unsupported metadata snapshot version: $version');
    }

    await _importPayload(map);
  }

  @override
  Future<void> importAccountBoundSnapshot(io.File snapshot) async {
    final raw = await snapshot.readAsBytes();
    if (raw.isEmpty) {
      throw Exception('Invalid metadata snapshot');
    }

    final version = raw.first;
    if (version != _formatVersionV4) {
      throw Exception('This is not an automatic TeleVault metadata snapshot.');
    }

    final accountFingerprint = await _currentAccountFingerprint();
    final map = _decodeV4Payload(raw, accountFingerprint);
    await _importPayload(map);
  }

  Future<void> _importPayload(Map<String, dynamic> map) async {
    final bucketRows = (map['buckets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final labelRows = (map['labels'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final fileRows = (map['files'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final settingRows = (map['settings'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      await _db.delete(_db.files).go();
      await _db.delete(_db.buckets).go();
      await _db.delete(_db.labels).go();
      final existingSettings = await _db.select(_db.appSettings).get();
      for (final setting in existingSettings) {
        if (!MetadataSettingPolicy.isSafeSettingKey(setting.key)) continue;
        await (_db.delete(
          _db.appSettings,
        )..where((t) => t.key.equals(setting.key))).go();
      }

      final bucketIdMap = <int, int>{};
      for (final row in bucketRows) {
        final oldId = row['id'] as int? ?? 0;
        final insertedId = await _db
            .into(_db.buckets)
            .insert(
              BucketsCompanion.insert(
                chatId: BigInt.parse(row['chat_id'] as String),
                name: row['name'] as String? ?? 'Bucket',
                allowedMediaTypes: Value(
                  row['allowed_media_types'] as String? ?? 'photo,video',
                ),
                isActive: Value(row['is_active'] as bool? ?? false),
                createdAt: Value(
                  DateTime.tryParse(row['created_at'] as String? ?? '') ??
                      DateTime.now(),
                ),
              ),
            );
        bucketIdMap[oldId] = insertedId;
      }

      final labelIdMap = <int, int>{};
      for (final row in labelRows) {
        final oldId = row['id'] as int? ?? 0;
        final insertedId = await _db
            .into(_db.labels)
            .insert(
              LabelsCompanion.insert(
                name: row['name'] as String? ?? 'Label',
                colorHex: Value(row['color_hex'] as String? ?? '#0A84FF'),
                emoji: Value(row['emoji'] as String?),
                createdAt: Value(
                  DateTime.tryParse(row['created_at'] as String? ?? '') ??
                      DateTime.now(),
                ),
              ),
            );
        labelIdMap[oldId] = insertedId;
      }

      for (final row in fileRows) {
        final oldBucketId = row['bucket_id'] as int? ?? 0;
        final bucketId = bucketIdMap[oldBucketId];
        if (bucketId == null) continue;
        final oldLabelId = row['label_id'] as int?;
        final labelId = oldLabelId == null ? null : labelIdMap[oldLabelId];

        await _db
            .into(_db.files)
            .insert(
              FilesCompanion.insert(
                localPath: row['local_path'] as String? ?? '',
                folderName: row['folder_name'] as String? ?? 'Unknown',
                size: row['size'] as int? ?? 0,
                bucketId: bucketId,
                assetId: Value(row['asset_id'] as String?),
                fileHash: Value(row['file_hash'] as String?),
                telegramMessageId: Value(row['telegram_message_id'] as int?),
                telegramFileId: Value(row['telegram_file_id'] as int?),
                status: Value(row['status'] as int? ?? 0),
                retryCount: Value(row['retry_count'] as int? ?? 0),
                lastError: Value(row['last_error'] as String?),
                nextRetryAt: Value(
                  DateTime.tryParse(row['next_retry_at'] as String? ?? ''),
                ),
                lastAttemptAt: Value(
                  DateTime.tryParse(row['last_attempt_at'] as String? ?? ''),
                ),
                telegramErrorCode: Value(row['telegram_error_code'] as int?),
                telegramErrorCategory: Value(
                  row['telegram_error_category'] as String?,
                ),
                telegramRetryAfter: Value(
                  DateTime.tryParse(
                    row['telegram_retry_after'] as String? ?? '',
                  ),
                ),
                lastTelegramOperation: Value(
                  row['last_telegram_operation'] as String?,
                ),
                userActionRequired: Value(
                  row['user_action_required'] as bool? ?? false,
                ),
                isVaulted: Value(row['is_vaulted'] as bool? ?? false),
                isEncrypted: Value(row['is_encrypted'] as bool? ?? false),
                encryptionVersion: Value(row['encryption_version'] as int?),
                ivB64: Value(row['iv_b64'] as String?),
                deletedLocallyAt: Value(
                  DateTime.tryParse(row['deleted_locally_at'] as String? ?? ''),
                ),
                labelId: Value(labelId),
                dateAdded: Value(
                  DateTime.tryParse(row['date_added'] as String? ?? '') ??
                      DateTime.now(),
                ),
              ),
            );
      }

      for (final row in settingRows) {
        final key = row['key'] as String?;
        final importKey = MetadataSettingPolicy.normalizeImportedSettingKey(
          key,
          bucketIdMap,
        );
        if (importKey == null) continue;
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                key: importKey,
                value: row['value'] as String? ?? '',
              ),
            );
      }
    });
    await _settingsService.normalizeStoredUploadLimits();
  }

  Map<String, dynamic> _decodeV4Payload(
    List<int> raw,
    String currentAccountFingerprint,
  ) {
    final decoded = _decodeEncryptedPayload(
      raw,
      currentAccountFingerprint,
      (salt) => _deriveAccountOnlyKey(salt, currentAccountFingerprint),
    );
    return decoded;
  }

  Map<String, dynamic> _decodeV3Payload(
    List<int> raw,
    String passphrase,
    String currentAccountFingerprint,
  ) {
    if (passphrase.trim().isEmpty) {
      throw Exception('Passphrase is required to import metadata');
    }
    return _decodeEncryptedPayload(
      raw,
      currentAccountFingerprint,
      (salt) => _deriveAccountBoundPassphraseKey(
        passphrase,
        salt,
        currentAccountFingerprint,
      ),
    );
  }

  Map<String, dynamic> _decodeEncryptedPayload(
    List<int> raw,
    String currentAccountFingerprint,
    enc.Key Function(Uint8List salt) keyBuilder,
  ) {
    if (raw.length < 3 + _saltLength + _ivLength + 1) {
      throw Exception('Invalid metadata snapshot payload');
    }

    final headerLength = (raw[1] << 8) | raw[2];
    final headerStart = 3;
    final headerEnd = headerStart + headerLength;
    final saltStart = headerEnd;
    final ivStart = saltStart + _saltLength;
    final cipherStart = ivStart + _ivLength;
    if (raw.length <= cipherStart) {
      throw Exception('Invalid metadata snapshot payload');
    }

    final header =
        jsonDecode(utf8.decode(raw.sublist(headerStart, headerEnd)))
            as Map<String, dynamic>;
    final snapshotAccountFingerprint = header['account_fingerprint']
        ?.toString();
    if (snapshotAccountFingerprint == null ||
        snapshotAccountFingerprint.isEmpty) {
      throw Exception('Metadata snapshot has no Telegram account binding');
    }
    if (snapshotAccountFingerprint != currentAccountFingerprint) {
      throw Exception(
        'This metadata snapshot belongs to a different Telegram account. Log in with the original account to import it.',
      );
    }

    final salt = Uint8List.fromList(raw.sublist(saltStart, ivStart));
    final iv = enc.IV(Uint8List.fromList(raw.sublist(ivStart, cipherStart)));
    final cipher = enc.Encrypted(Uint8List.fromList(raw.sublist(cipherStart)));
    final key = keyBuilder(salt);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    try {
      final jsonString = utf8.decode(encrypter.decryptBytes(cipher, iv: iv));
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      if (decoded['account_fingerprint'] != currentAccountFingerprint) {
        throw Exception('Metadata account binding mismatch');
      }
      return decoded;
    } catch (_) {
      throw Exception(
        'Invalid passphrase, wrong Telegram account, or corrupted metadata snapshot',
      );
    }
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  enc.Key _derivePassphraseKey(String passphrase, Uint8List salt) {
    final keyBytes = _pbkdf2(
      password: utf8.encode(passphrase),
      salt: salt,
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );
    return enc.Key(keyBytes);
  }

  enc.Key _deriveAccountBoundPassphraseKey(
    String passphrase,
    Uint8List salt,
    String accountFingerprint,
  ) {
    return _derivePassphraseKey('$passphrase\n$accountFingerprint', salt);
  }

  enc.Key _deriveAccountOnlyKey(Uint8List salt, String accountFingerprint) {
    return _derivePassphraseKey(
      'televault.account.metadata.v1\n$accountFingerprint',
      salt,
    );
  }

  Uint8List _pbkdf2({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final hashLength = sha256.convert(const []).bytes.length;
    final blocks = (keyLength / hashLength).ceil();
    final output = Uint8List(keyLength);
    var offset = 0;

    for (var block = 1; block <= blocks; block++) {
      final blockInput = BytesBuilder()
        ..add(salt)
        ..add(_int32BigEndian(block));
      var u = Uint8List.fromList(hmac.convert(blockInput.toBytes()).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }

      final copyLength = (keyLength - offset).clamp(0, hashLength);
      output.setRange(offset, offset + copyLength, t);
      offset += copyLength;
    }

    return output;
  }

  List<int> _int32BigEndian(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  List<int> _uint16BigEndian(int value) {
    return [(value >> 8) & 0xff, value & 0xff];
  }

  Future<String> _currentAccountFingerprint() async {
    final me = await _telegram.request({
      '@type': 'getMe',
    }, timeout: const Duration(seconds: 10));
    final id = me['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Unable to identify the current Telegram account');
    }
    return sha256
        .convert(utf8.encode('televault.telegram.account.v1:$id'))
        .toString();
  }
}

class MetadataSettingPolicy {
  static const safeSettingKeys = {
    'auto_backup',
    'sync_last_scan_at',
    'sync_include_photos',
    'sync_include_videos',
    'sync_wifi_only',
    'sync_charging_only',
    'sync_album_mode',
    'sync_album_ids',
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
