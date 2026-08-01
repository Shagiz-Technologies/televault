import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'vault_service.dart';

typedef VaultLegacyFileDeleter = Future<void> Function(io.File file);

final vaultMigrationServiceProvider = Provider<VaultMigrationService>((ref) {
  return VaultMigrationService(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

abstract final class VaultMigrationStates {
  static const String notRequired = 'notRequired';
  static const String pending = 'pending';
  static const String inProgress = 'inProgress';
  static const String completed = 'completed';
  static const String failed = 'failed';
}

abstract final class VaultIntegrityStates {
  static const String unknown = 'unknown';
  static const String verified = 'verified';
  static const String failed = 'failed';
}

class VaultMigrationReport {
  final int migrated;
  final int failed;

  const VaultMigrationReport({required this.migrated, required this.failed});
}

class VaultMigrationService {
  final AppDatabase _database;
  final VaultService _vaultService;
  final VaultLegacyFileDeleter _legacyFileDeleter;

  VaultMigrationService(
    this._database,
    this._vaultService, {
    VaultLegacyFileDeleter? legacyFileDeleter,
  }) : _legacyFileDeleter = legacyFileDeleter ?? _deleteFile;

  Future<VaultMigrationReport> migratePending(String legacySecret) async {
    final rows =
        await (_database.select(_database.files)..where(
              (table) =>
                  table.isVaulted.equals(true) &
                  table.isEncrypted.equals(true) &
                  (table.vaultFormatVersion.isSmallerThanValue(3) |
                      table.vaultFormatVersion.isNull()),
            ))
            .get();

    var migrated = 0;
    var failed = 0;
    for (final row in rows) {
      try {
        await migrateFile(row, legacySecret: legacySecret);
        migrated++;
      } on Exception {
        failed++;
      }
    }
    return VaultMigrationReport(migrated: migrated, failed: failed);
  }

  Future<void> migrateFile(File row, {required String legacySecret}) async {
    final source = io.File(row.localPath);
    if (!await source.exists()) {
      await _markFailed(row.id, integrityFailed: false);
      throw const VaultException(
        VaultErrorCode.sourceMissing,
        'The legacy vault object is unavailable.',
      );
    }

    final detectedVersion = await _vaultService.detectFormatVersion(source);
    if (detectedVersion == VaultService.currentVersion) {
      final verifiedAt = await _vaultService.verifyFile(source);
      await _database.transaction(() async {
        await (_database.update(
          _database.files,
        )..where((table) => table.id.equals(row.id))).write(
          FilesCompanion(
            vaultFormatVersion: const Value(VaultService.currentVersion),
            encryptionVersion: const Value(VaultService.currentVersion),
            vaultIntegrityStatus: const Value(VaultIntegrityStates.verified),
            vaultMigrationStatus: const Value(VaultMigrationStates.completed),
            keyWrappingVersion: const Value(VaultService.keyWrappingVersion),
            lastVerifiedAt: Value(verifiedAt),
          ),
        );
      });
      return;
    }

    final objectId = row.encryptedObjectId ?? _vaultService.newObjectId();
    await (_database.update(
      _database.files,
    )..where((table) => table.id.equals(row.id))).write(
      FilesCompanion(
        encryptedObjectId: Value(objectId),
        vaultMigrationStatus: const Value(VaultMigrationStates.inProgress),
      ),
    );

    io.File? plaintext;
    io.File? candidate;
    var candidateCreatedHere = false;
    try {
      final recordedVersion = row.vaultFormatVersion ?? row.encryptionVersion;
      plaintext = recordedVersion == 1 || recordedVersion == 2
          ? await _vaultService.decryptLegacyFile(
              source,
              legacySecret,
              formatVersion: recordedVersion!,
            )
          : await _vaultService.decryptFile(source, legacySecret);
      candidate = await _vaultService.destinationForObjectId(objectId);
      VaultEncryptionResult result;
      if (await candidate.exists()) {
        final verifiedAt = await _vaultService.verifyFile(
          candidate,
          expectedPlaintext: plaintext,
        );
        result = VaultEncryptionResult(
          path: candidate.path,
          objectId: objectId,
          ivB64: row.ivB64 ?? '',
          version: VaultService.currentVersion,
          encryptedSize: await candidate.length(),
          originalSize: await plaintext.length(),
          keyWrappingVersion: VaultService.keyWrappingVersion,
        );
        await _commitMigration(row.id, result, verifiedAt);
      } else {
        result = await _vaultService.encryptFile(plaintext, objectId: objectId);
        candidate = io.File(result.path);
        candidateCreatedHere = true;
        final verifiedAt = await _vaultService.verifyFile(
          candidate,
          expectedPlaintext: plaintext,
        );
        await _commitMigration(row.id, result, verifiedAt);
      }
    } on Exception {
      if (candidateCreatedHere &&
          candidate != null &&
          await candidate.exists()) {
        await candidate.delete();
      }
      await _markFailed(row.id, integrityFailed: candidate != null);
      rethrow;
    } finally {
      if (plaintext != null) {
        await _vaultService.deleteTemporaryPlaintext(plaintext);
      }
    }

    // The database now points at a verified v3 object. Failure to remove the
    // legacy copy must never roll back or delete that committed replacement.
    if (source.path != candidate.path && await source.exists()) {
      try {
        await _legacyFileDeleter(source);
      } on io.FileSystemException {
        // A later maintenance pass may remove the harmless legacy duplicate.
      }
    }
  }

  Future<void> _commitMigration(
    int rowId,
    VaultEncryptionResult result,
    DateTime verifiedAt,
  ) {
    return _database.transaction(() async {
      final updated =
          await (_database.update(
            _database.files,
          )..where((table) => table.id.equals(rowId))).write(
            FilesCompanion(
              localPath: Value(result.path),
              size: Value(result.encryptedSize),
              encryptionVersion: Value(result.version),
              ivB64: Value(result.ivB64),
              vaultFormatVersion: Value(result.version),
              encryptedObjectId: Value(result.objectId),
              encryptedSize: Value(result.encryptedSize),
              originalSize: Value(result.originalSize),
              vaultIntegrityStatus: const Value(VaultIntegrityStates.verified),
              vaultMigrationStatus: const Value(VaultMigrationStates.completed),
              keyWrappingVersion: Value(result.keyWrappingVersion),
              lastVerifiedAt: Value(verifiedAt),
            ),
          );
      if (updated != 1) {
        throw StateError('Vault migration record no longer exists.');
      }
    });
  }

  Future<void> _markFailed(int rowId, {required bool integrityFailed}) async {
    await (_database.update(
      _database.files,
    )..where((table) => table.id.equals(rowId))).write(
      FilesCompanion(
        vaultMigrationStatus: const Value(VaultMigrationStates.failed),
        vaultIntegrityStatus: Value(
          integrityFailed
              ? VaultIntegrityStates.failed
              : VaultIntegrityStates.unknown,
        ),
      ),
    );
  }

  static Future<void> _deleteFile(io.File file) => file.delete();
}
