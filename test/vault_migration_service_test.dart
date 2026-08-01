import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/features/vault/services/vault_migration_service.dart';
import 'package:tele_vault/src/features/vault/services/vault_recovery_service.dart';
import 'package:tele_vault/src/features/vault/services/vault_service.dart';

void main() {
  late AppDatabase database;
  late io.Directory root;
  late io.Directory vaultDirectory;
  late io.Directory temporaryDirectory;
  late Uint8List recoveryKey;
  late VaultService vaultService;
  late VaultMigrationService migrationService;
  late int bucketId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    root = await io.Directory.systemTemp.createTemp('televault_migration_');
    vaultDirectory = io.Directory(path.join(root.path, 'vault'));
    temporaryDirectory = io.Directory(path.join(root.path, 'temp'));
    recoveryKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    vaultService = _service(recoveryKey, vaultDirectory, temporaryDirectory);
    migrationService = VaultMigrationService(database, vaultService);
    bucketId = await database
        .into(database.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(99),
            name: 'Vault',
            isActive: const Value(true),
          ),
        );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'v1 and v2 rows migrate to verified v3 without destructive failure',
    () async {
      const secret = 'legacy-secret';
      final plaintext = Uint8List.fromList(
        List<int>.generate(8192, (index) => index & 0xff),
      );
      final legacyV1 = io.File(path.join(root.path, 'legacy-v1.jpg.enc'));
      final legacyV2 = io.File(path.join(root.path, 'legacy-v2.jpg.enc'));
      await _writeLegacy(legacyV1, plaintext, secret, version: 1);
      await _writeLegacy(legacyV2, plaintext, secret, version: 2);
      await _insertLegacy(database, bucketId, legacyV1, version: 1);
      await _insertLegacy(database, bucketId, legacyV2, version: 2);

      final report = await migrationService.migratePending(secret);
      final rows = await database.select(database.files).get();

      expect(report.migrated, 2);
      expect(report.failed, 0);
      for (final row in rows) {
        expect(row.localPath, endsWith('.tvv3'));
        expect(row.vaultFormatVersion, VaultService.currentVersion);
        expect(row.vaultMigrationStatus, VaultMigrationStates.completed);
        expect(row.vaultIntegrityStatus, VaultIntegrityStates.verified);
        expect(row.encryptedObjectId, isNotEmpty);
        expect(row.originalSize, plaintext.length);
        expect(row.lastVerifiedAt, isNotNull);
        final decrypted = await vaultService.decryptFile(
          io.File(row.localPath),
        );
        expect(await decrypted.readAsBytes(), plaintext);
        await vaultService.deleteTemporaryPlaintext(decrypted);
      }
      expect(await legacyV1.exists(), isFalse);
      expect(await legacyV2.exists(), isFalse);
    },
  );

  test(
    'interrupted migration resumes by verifying its existing target',
    () async {
      const secret = 'legacy-secret';
      const objectId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final plaintext = Uint8List.fromList(List<int>.filled(4096, 41));
      final legacyFile = io.File(path.join(root.path, 'interrupted.jpg.enc'));
      final clearFile = io.File(path.join(root.path, 'interrupted.jpg'));
      await clearFile.writeAsBytes(plaintext);
      await _writeLegacy(legacyFile, plaintext, secret, version: 2);
      final rowId = await _insertLegacy(
        database,
        bucketId,
        legacyFile,
        version: 2,
        objectId: objectId,
        migrationStatus: VaultMigrationStates.inProgress,
      );
      final candidate = await vaultService.encryptFile(
        clearFile,
        objectId: objectId,
      );

      final row = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();
      await migrationService.migrateFile(row, legacySecret: secret);
      final migrated = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();

      expect(migrated.localPath, candidate.path);
      expect(migrated.vaultMigrationStatus, VaultMigrationStates.completed);
      expect(await legacyFile.exists(), isFalse);
      expect(await io.File(candidate.path).exists(), isTrue);
    },
  );

  test(
    'encryption failure leaves legacy database path and object intact',
    () async {
      const secret = 'legacy-secret';
      final plaintext = Uint8List.fromList(List<int>.filled(2048, 9));
      final legacyFile = io.File(path.join(root.path, 'rollback.jpg.enc'));
      await _writeLegacy(legacyFile, plaintext, secret, version: 2);
      final rowId = await _insertLegacy(
        database,
        bucketId,
        legacyFile,
        version: 2,
      );
      final failingService = VaultService(
        recoveryKeyProvider: _FailingRecoveryKeyProvider(),
        vaultDirectoryProvider: () async => vaultDirectory,
        temporaryDirectoryProvider: () async => temporaryDirectory,
        chunkSize: 64 * 1024,
      );
      final failingMigration = VaultMigrationService(database, failingService);
      final original = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();

      try {
        await failingMigration.migrateFile(original, legacySecret: secret);
        fail('Migration should have failed');
      } on Object catch (error) {
        expect(error, isA<VaultRecoveryException>());
      }
      final after = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();
      expect(after.localPath, legacyFile.path);
      expect(after.vaultFormatVersion, 2);
      expect(after.vaultMigrationStatus, VaultMigrationStates.failed);
      expect(await legacyFile.exists(), isTrue);
    },
  );

  test(
    'legacy cleanup failure preserves the committed verified v3 object',
    () async {
      const secret = 'legacy-secret';
      final plaintext = Uint8List.fromList(List<int>.filled(2048, 17));
      final legacyFile = io.File(path.join(root.path, 'cleanup-failure.enc'));
      await _writeLegacy(legacyFile, plaintext, secret, version: 2);
      final rowId = await _insertLegacy(
        database,
        bucketId,
        legacyFile,
        version: 2,
      );
      final cleanupSafeMigration = VaultMigrationService(
        database,
        vaultService,
        legacyFileDeleter: (_) {
          throw const io.FileSystemException('simulated cleanup failure');
        },
      );
      final original = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();

      await cleanupSafeMigration.migrateFile(original, legacySecret: secret);

      final migrated = await (database.select(
        database.files,
      )..where((table) => table.id.equals(rowId))).getSingle();
      final v3File = io.File(migrated.localPath);
      expect(migrated.vaultMigrationStatus, VaultMigrationStates.completed);
      expect(migrated.vaultIntegrityStatus, VaultIntegrityStates.verified);
      expect(await v3File.exists(), isTrue);
      expect(await legacyFile.exists(), isTrue);
      final decrypted = await vaultService.decryptFile(v3File);
      expect(await decrypted.readAsBytes(), plaintext);
      await vaultService.deleteTemporaryPlaintext(decrypted);
    },
  );
}

VaultService _service(
  Uint8List recoveryKey,
  io.Directory vaultDirectory,
  io.Directory temporaryDirectory,
) {
  return VaultService(
    recoveryKeyProvider: _StaticRecoveryKeyProvider(recoveryKey),
    vaultDirectoryProvider: () async => vaultDirectory,
    temporaryDirectoryProvider: () async => temporaryDirectory,
    chunkSize: 64 * 1024,
  );
}

Future<int> _insertLegacy(
  AppDatabase database,
  int bucketId,
  io.File file, {
  required int version,
  String? objectId,
  String migrationStatus = VaultMigrationStates.pending,
}) async {
  return database
      .into(database.files)
      .insert(
        FilesCompanion.insert(
          localPath: file.path,
          folderName: 'Legacy',
          size: await file.length(),
          bucketId: bucketId,
          isVaulted: const Value(true),
          isEncrypted: const Value(true),
          encryptionVersion: Value(version),
          vaultFormatVersion: Value(version),
          encryptedObjectId: Value(objectId),
          encryptedSize: Value(await file.length()),
          originalSize: const Value(4096),
          vaultMigrationStatus: Value(migrationStatus),
        ),
      );
}

Future<void> _writeLegacy(
  io.File destination,
  Uint8List plaintext,
  String secret, {
  required int version,
}) async {
  final iv = legacy.IV.fromSecureRandom(12);
  final output = BytesBuilder();
  late final legacy.Key key;
  if (version == 2) {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (index) => index + 1),
    );
    key = legacy.Key(_pbkdf2(secret, salt));
    output
      ..addByte(2)
      ..add(salt);
  } else {
    key = legacy.Key(
      Uint8List.fromList(hashes.sha256.convert(utf8.encode(secret)).bytes),
    );
  }
  final encrypted = legacy.Encrypter(
    legacy.AES(key, mode: legacy.AESMode.gcm),
  ).encryptBytes(plaintext, iv: iv);
  output
    ..add(iv.bytes)
    ..add(encrypted.bytes);
  await destination.writeAsBytes(output.takeBytes(), flush: true);
}

Uint8List _pbkdf2(String secret, Uint8List salt) {
  final hmac = hashes.Hmac(hashes.sha256, utf8.encode(secret));
  final output = Uint8List(32);
  final input = BytesBuilder()
    ..add(salt)
    ..add([0, 0, 0, 1]);
  var u = Uint8List.fromList(hmac.convert(input.takeBytes()).bytes);
  output.setAll(0, u);
  for (var iteration = 1; iteration < 120000; iteration++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var index = 0; index < output.length; index++) {
      output[index] ^= u[index];
    }
  }
  return output;
}

class _StaticRecoveryKeyProvider implements VaultRecoveryKeyProvider {
  final Uint8List key;

  const _StaticRecoveryKeyProvider(this.key);

  @override
  Future<Uint8List> requireConfirmedKey() async => Uint8List.fromList(key);
}

class _FailingRecoveryKeyProvider implements VaultRecoveryKeyProvider {
  @override
  Future<Uint8List> requireConfirmedKey() {
    throw const VaultRecoveryException(
      VaultRecoveryErrorCode.confirmationRequired,
      'Recovery confirmation required.',
    );
  }
}
