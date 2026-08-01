import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as encryption;
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/features/backup/services/metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_operation_lock.dart';
import 'package:tele_vault/src/features/backup/services/metadata_remote_verifier.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';
import 'package:tele_vault/src/features/vault/services/vault_recovery_service.dart';

import 'support/fake_telegram_gateway.dart';

void main() {
  group('metadata snapshot v5', () {
    test(
      'encrypts, authenticates, imports, and marks paths unresolved',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        await fixture.seed();

        final snapshot = await fixture.service.exportAccountBoundSnapshot();
        final inspection = await fixture.service.inspectSnapshot(snapshot);
        expect(inspection.formatVersion, 5);
        expect(inspection.protection, MetadataSnapshotProtection.recoveryKey);
        expect(
          utf8.decode(await snapshot.readAsBytes(), allowMalformed: true),
          isNot(contains('/demo/private/sample.jpg')),
        );

        final result = await fixture.service.importAccountBoundSnapshot(
          snapshot,
        );
        expect(result.requiresSecureMigration, isFalse);
        final row = await fixture.db.select(fixture.db.files).getSingle();
        expect(row.localPath, startsWith('televault-unresolved://'));
        expect(row.localPathResolved, isFalse);
        expect(row.remoteStateVerified, isTrue);
        expect(row.status, FileSyncStatus.synced.dbValue);
        expect(row.assetId, 'demo-asset-1');
      },
    );

    test('manual v5 requires both recovery key and passphrase', () async {
      final fixture = await _MetadataFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      final snapshot = await fixture.service.exportEncryptedSnapshot(
        passphrase: 'correct horse battery staple',
      );

      await expectLater(
        fixture.service.importEncryptedSnapshot(
          snapshot,
          passphrase: 'wrong passphrase',
        ),
        throwsA(
          isA<MetadataBackupException>().having(
            (error) => error.code,
            'code',
            MetadataBackupErrorCode.authenticationFailed,
          ),
        ),
      );
      await fixture.service.importEncryptedSnapshot(
        snapshot,
        passphrase: 'correct horse battery staple',
      );
    });

    test(
      'rejects a wrong recovery secret without changing the database',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        await fixture.seed();
        final snapshot = await fixture.service.exportAccountBoundSnapshot();
        final wrongKeyService = fixture.createService(
          recoveryKey: Uint8List.fromList(List<int>.filled(32, 99)),
        );

        await expectLater(
          wrongKeyService.importAccountBoundSnapshot(snapshot),
          throwsA(
            isA<MetadataBackupException>().having(
              (error) => error.code,
              'code',
              MetadataBackupErrorCode.authenticationFailed,
            ),
          ),
        );
        expect(await fixture.db.select(fixture.db.files).get(), hasLength(1));
      },
    );

    test('rejects a snapshot bound to another Telegram account', () async {
      final fixture = await _MetadataFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      final snapshot = await fixture.service.exportAccountBoundSnapshot();
      fixture.accountId = 456;

      await expectLater(
        fixture.service.importAccountBoundSnapshot(snapshot),
        throwsA(
          isA<MetadataBackupException>().having(
            (error) => error.code,
            'code',
            MetadataBackupErrorCode.wrongTelegramAccount,
          ),
        ),
      );
    });

    test('rejects modified authenticated header and ciphertext', () async {
      final fixture = await _MetadataFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      final snapshot = await fixture.service.exportAccountBoundSnapshot();
      final original = await snapshot.readAsBytes();

      final headerTampered = Uint8List.fromList(original);
      final versionText = utf8.encode('test+1');
      final versionOffset = _indexOf(headerTampered, versionText);
      expect(versionOffset, greaterThan(0));
      headerTampered[versionOffset + versionText.length - 1] ^= 1;
      final headerFile = io.File('${fixture.directory.path}/header.tvmeta');
      await headerFile.writeAsBytes(headerTampered);
      await expectLater(
        fixture.service.importAccountBoundSnapshot(headerFile),
        throwsA(isA<MetadataBackupException>()),
      );

      final cipherTampered = Uint8List.fromList(original);
      cipherTampered[cipherTampered.length - 17] ^= 1;
      final cipherFile = io.File('${fixture.directory.path}/cipher.tvmeta');
      await cipherFile.writeAsBytes(cipherTampered);
      await expectLater(
        fixture.service.importAccountBoundSnapshot(cipherFile),
        throwsA(
          isA<MetadataBackupException>().having(
            (error) => error.code,
            'code',
            MetadataBackupErrorCode.authenticationFailed,
          ),
        ),
      );
    });

    test(
      'rolls back all table replacement when the transaction fails',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        await fixture.seed();
        final snapshot = await fixture.service.exportAccountBoundSnapshot();
        await (fixture.db.update(fixture.db.buckets)
              ..where((table) => table.id.equals(1)))
            .write(const BucketsCompanion(name: Value('Current data')));
        final failing = fixture.createService(
          importCommitHook: () =>
              throw StateError('injected transaction fault'),
        );

        await expectLater(
          failing.importAccountBoundSnapshot(snapshot),
          throwsA(isA<StateError>()),
        );
        final bucket = await fixture.db.select(fixture.db.buckets).getSingle();
        expect(bucket.name, 'Current data');
        expect(await fixture.db.select(fixture.db.files).get(), hasLength(1));
      },
    );

    test(
      'reads weak v4 only as migration and ignores its absolute path',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        final fingerprint = DriftMetadataBackupService.fingerprintForAccountId(
          123,
        );
        final v4 = await _writeLegacyV4(
          fixture.directory,
          fingerprint,
          _legacyPayload(fingerprint: fingerprint),
        );

        final result = await fixture.service.importAccountBoundSnapshot(v4);
        expect(result.sourceFormatVersion, 4);
        expect(result.requiresSecureMigration, isTrue);
        final row = await fixture.db.select(fixture.db.files).getSingle();
        expect(row.localPathResolved, isFalse);
        expect(row.localPath, isNot('/old/device/private.jpg'));
      },
    );

    test(
      'invalid bucket and message references fail before replacement',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        await fixture.seed();
        final fingerprint = DriftMetadataBackupService.fingerprintForAccountId(
          123,
        );
        final payload = _legacyPayload(fingerprint: fingerprint);
        final files = payload['files']! as List<dynamic>;
        (files.single as Map<String, dynamic>)['bucket_id'] = 999;
        final invalid = await _writeLegacyV4(
          fixture.directory,
          fingerprint,
          payload,
        );

        await expectLater(
          fixture.service.importAccountBoundSnapshot(invalid),
          throwsA(
            isA<MetadataBackupException>().having(
              (error) => error.code,
              'code',
              MetadataBackupErrorCode.validationFailed,
            ),
          ),
        );
        expect(await fixture.db.select(fixture.db.files).get(), hasLength(1));
      },
    );

    test(
      'invalid Telegram message reference fails before replacement',
      () async {
        final fixture = await _MetadataFixture.create();
        addTearDown(fixture.dispose);
        await fixture.seed();
        final fingerprint = DriftMetadataBackupService.fingerprintForAccountId(
          123,
        );
        final payload = _legacyPayload(fingerprint: fingerprint);
        final files = payload['files']! as List<dynamic>;
        (files.single as Map<String, dynamic>)['telegram_message_id'] = 0;
        final invalid = await _writeLegacyV4(
          fixture.directory,
          fingerprint,
          payload,
        );

        await expectLater(
          fixture.service.importAccountBoundSnapshot(invalid),
          throwsA(
            isA<MetadataBackupException>().having(
              (error) => error.code,
              'code',
              MetadataBackupErrorCode.validationFailed,
            ),
          ),
        );
        expect(await fixture.db.select(fixture.db.files).get(), hasLength(1));
      },
    );

    test('unverified Telegram messages are never restored as synced', () async {
      final fixture = await _MetadataFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      final snapshot = await fixture.service.exportAccountBoundSnapshot();
      final conservative = fixture.createService(
        remoteVerifier: const _NoRemoteStateVerified(),
      );

      await conservative.importAccountBoundSnapshot(snapshot);

      final row = await fixture.db.select(fixture.db.files).getSingle();
      expect(row.status, FileSyncStatus.failed.dbValue);
      expect(row.remoteStateVerified, isFalse);
      expect(row.userActionRequired, isTrue);
      expect(row.telegramFileId, null);
    });
  });
}

class _MetadataFixture {
  final AppDatabase db;
  final FakeTelegramGateway gateway;
  final io.Directory directory;
  final MetadataOperationLock lock;
  late final DriftMetadataBackupService service;
  int accountId;
  final Uint8List recoveryKey;

  _MetadataFixture({
    required this.db,
    required this.gateway,
    required this.directory,
    required this.lock,
    required this.accountId,
    required this.recoveryKey,
  });

  static Future<_MetadataFixture> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = FakeTelegramGateway();
    final directory = await io.Directory.systemTemp.createTemp(
      'televault_metadata_v5_',
    );
    final fixture = _MetadataFixture(
      db: db,
      gateway: gateway,
      directory: directory,
      lock: MetadataOperationLock(
        lockFileProvider: () async =>
            io.File('${directory.path}/metadata.lock'),
      ),
      accountId: 123,
      recoveryKey: Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );
    gateway.handler = (request) {
      if (request['@type'] == 'getMe') {
        return {'@type': 'user', 'id': fixture.accountId};
      }
      throw UnimplementedError('Unexpected request: ${request['@type']}');
    };
    fixture.service = fixture.createService();
    return fixture;
  }

  DriftMetadataBackupService createService({
    Uint8List? recoveryKey,
    MetadataRemoteStateVerifier? remoteVerifier,
    MetadataImportCommitHook? importCommitHook,
  }) {
    return DriftMetadataBackupService(
      db,
      gateway,
      SettingsService(db),
      _FixedRecoveryKeyProvider(recoveryKey ?? this.recoveryKey),
      remoteVerifier ?? const _AllRemoteStateVerified(),
      lock,
      temporaryDirectoryProvider: () async => directory,
      applicationVersionProvider: () async => 'test+1',
      generationIdFactory: () => '123e4567-e89b-42d3-a456-426614174000',
      clock: () => DateTime.utc(2026, 8, 1, 12),
      importCommitHook: importCommitHook,
    );
  }

  Future<void> seed() async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(-100123),
            name: 'Demo',
            isActive: const Value(true),
          ),
        );
    final labelId = await db
        .into(db.labels)
        .insert(LabelsCompanion.insert(name: 'Trip'));
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/private/sample.jpg',
            assetId: const Value('demo-asset-1'),
            folderName: 'Camera',
            size: 128,
            bucketId: bucketId,
            telegramMessageId: const Value(77),
            telegramFileId: const Value(88),
            status: Value(FileSyncStatus.synced.dbValue),
            labelId: Value(labelId),
            dateAdded: Value(DateTime.utc(2026, 1, 1)),
          ),
        );
  }

  Future<void> dispose() async {
    await gateway.dispose();
    await db.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

class _FixedRecoveryKeyProvider implements VaultRecoveryKeyProvider {
  final Uint8List key;

  const _FixedRecoveryKeyProvider(this.key);

  @override
  Future<Uint8List> requireConfirmedKey() async => Uint8List.fromList(key);
}

class _AllRemoteStateVerified implements MetadataRemoteStateVerifier {
  const _AllRemoteStateVerified();

  @override
  Future<MetadataRemoteReconciliation> reconcile({
    required Map<int, BigInt> bucketChatIds,
    required Map<int, Set<int>> messageIdsByBucket,
  }) async {
    return MetadataRemoteReconciliation(
      verifiedBucketIds: bucketChatIds.keys.toSet(),
      verifiedMessages: {
        for (final entry in messageIdsByBucket.entries)
          for (final messageId in entry.value)
            MetadataRemoteReconciliation.messageKey(entry.key, messageId),
      },
    );
  }
}

class _NoRemoteStateVerified implements MetadataRemoteStateVerifier {
  const _NoRemoteStateVerified();

  @override
  Future<MetadataRemoteReconciliation> reconcile({
    required Map<int, BigInt> bucketChatIds,
    required Map<int, Set<int>> messageIdsByBucket,
  }) async {
    return const MetadataRemoteReconciliation(
      verifiedBucketIds: <int>{},
      verifiedMessages: <String>{},
    );
  }
}

Map<String, dynamic> _legacyPayload({required String fingerprint}) {
  return <String, dynamic>{
    'schema_version': 3,
    'exported_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    'account_fingerprint': fingerprint,
    'buckets': [
      {
        'id': 1,
        'chat_id': '-100123',
        'name': 'Legacy',
        'allowed_media_types': 'photo,video',
        'is_active': true,
        'created_at': DateTime.utc(2025, 1, 1).toIso8601String(),
      },
    ],
    'labels': <dynamic>[],
    'files': [
      {
        'asset_id': 'legacy-asset',
        'local_path': '/old/device/private.jpg',
        'folder_name': 'Camera',
        'file_hash': null,
        'size': 42,
        'bucket_id': 1,
        'telegram_message_id': 77,
        'telegram_file_id': 88,
        'status': FileSyncStatus.synced.dbValue,
        'is_vaulted': false,
        'is_encrypted': false,
        'vault_integrity_status': 'unknown',
        'vault_migration_status': 'notRequired',
        'date_added': DateTime.utc(2025, 2, 1).toIso8601String(),
      },
    ],
    'settings': <dynamic>[],
  };
}

Future<io.File> _writeLegacyV4(
  io.Directory directory,
  String fingerprint,
  Map<String, dynamic> payload,
) async {
  final salt = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));
  final iv = encryption.IV(Uint8List.fromList(List<int>.filled(12, 7)));
  final key = encryption.Key(
    _pbkdf2(
      utf8.encode('televault.account.metadata.v1\n$fingerprint'),
      salt,
      120000,
      32,
    ),
  );
  final encrypted = encryption.Encrypter(
    encryption.AES(key, mode: encryption.AESMode.gcm),
  ).encryptBytes(utf8.encode(jsonEncode(payload)), iv: iv);
  final header = utf8.encode(
    jsonEncode({
      'format_version': 4,
      'account_fingerprint': fingerprint,
      'protection': 'telegram-account',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 120000,
    }),
  );
  final output = BytesBuilder()
    ..addByte(4)
    ..add([(header.length >> 8) & 0xff, header.length & 0xff])
    ..add(header)
    ..add(salt)
    ..add(iv.bytes)
    ..add(encrypted.bytes);
  final file = io.File('${directory.path}/legacy-v4.tvmeta');
  await file.writeAsBytes(output.toBytes());
  return file;
}

Uint8List _pbkdf2(
  List<int> password,
  Uint8List salt,
  int iterations,
  int keyLength,
) {
  final hmac = Hmac(sha256, password);
  final output = Uint8List(keyLength);
  var offset = 0;
  for (var block = 1; offset < keyLength; block++) {
    final input = BytesBuilder()
      ..add(salt)
      ..add([
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ]);
    var u = Uint8List.fromList(hmac.convert(input.toBytes()).bytes);
    final value = Uint8List.fromList(u);
    for (var round = 1; round < iterations; round++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var index = 0; index < value.length; index++) {
        value[index] ^= u[index];
      }
    }
    final count = (keyLength - offset).clamp(0, value.length);
    output.setRange(offset, offset + count, value);
    offset += count;
  }
  return output;
}

int _indexOf(List<int> source, List<int> pattern) {
  for (var index = 0; index <= source.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (source[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  return -1;
}
