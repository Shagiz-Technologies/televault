import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/features/auth/services/local_account_cleanup_coordinator.dart';
import 'package:tele_vault/src/features/backup/services/metadata_operation_lock.dart';

void main() {
  test(
    'logout removes all local account state but no remote backup data',
    () async {
      final fixture = await _CleanupFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      await fixture.createLocalFiles();

      await fixture.coordinator.logout(
        options: const LocalAccountCleanupOptions(
          preserveEncryptedVaultFiles: false,
        ),
        remoteLogout: () async => fixture.remoteActions.add('logOut'),
      );

      expect(await fixture.db.select(fixture.db.files).get(), isEmpty);
      expect(await fixture.db.select(fixture.db.buckets).get(), isEmpty);
      expect(await fixture.db.select(fixture.db.labels).get(), isEmpty);
      expect(await fixture.db.select(fixture.db.appSettings).get(), isEmpty);
      expect(
        await fixture.db.select(fixture.db.telegramAccountStates).get(),
        isEmpty,
      );
      expect(fixture.workersStopped, isTrue);
      expect(fixture.pinSecretsCleared, isTrue);
      expect(fixture.recoveryKeyCleared, isTrue);
      expect(fixture.tdlibCleared, isTrue);
      expect(await fixture.vaultDirectory.exists(), isFalse);
      expect(await fixture.marker.exists(), isFalse);
      expect(fixture.remoteActions, ['logOut']);
      expect(fixture.remoteActions, isNot(contains('deleteMessages')));
      expect(fixture.remoteActions, isNot(contains('deleteChat')));
    },
  );

  test(
    'explicit vault preservation keeps only encrypted files and recovery key',
    () async {
      final fixture = await _CleanupFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      await fixture.createLocalFiles();

      await fixture.coordinator.logout(
        options: const LocalAccountCleanupOptions(
          preserveEncryptedVaultFiles: true,
        ),
        remoteLogout: () async => fixture.remoteActions.add('logOut'),
      );

      expect(await fixture.vaultDirectory.exists(), isTrue);
      expect(await fixture.vaultObject.exists(), isTrue);
      expect(await fixture.decryptedDirectory.exists(), isFalse);
      expect(fixture.recoveryKeyCleared, isFalse);
      expect(fixture.pinSecretsCleared, isTrue);
    },
  );

  test(
    'crash during cleanup leaves a marker and resumes idempotently',
    () async {
      final fixture = await _CleanupFixture.create(failVaultDeleteOnce: true);
      addTearDown(fixture.dispose);
      await fixture.seed();
      await fixture.createLocalFiles();

      await expectLater(
        fixture.coordinator.logout(
          options: const LocalAccountCleanupOptions(
            preserveEncryptedVaultFiles: false,
          ),
          remoteLogout: () async => fixture.remoteActions.add('logOut'),
        ),
        throwsA(isA<LocalAccountCleanupException>()),
      );
      expect(await fixture.marker.exists(), isTrue);
      expect(await fixture.db.select(fixture.db.files).get(), isEmpty);

      await fixture.coordinator.resumePendingCleanup();
      expect(await fixture.marker.exists(), isFalse);
      expect(await fixture.vaultDirectory.exists(), isFalse);
      expect(fixture.remoteActions, ['logOut']);
    },
  );

  test(
    'interrupted marker replacement resumes from the flushed temp file',
    () async {
      final fixture = await _CleanupFixture.create();
      addTearDown(fixture.dispose);
      await fixture.seed();
      await fixture.marker.parent.create(recursive: true);
      await io.File('${fixture.marker.path}.tmp').writeAsString(
        jsonEncode({
          'version': 1,
          'stage': 'workersStopped',
          'preserve_encrypted_vault_files': false,
        }),
        flush: true,
      );

      await fixture.coordinator.resumePendingCleanup();

      expect(await fixture.db.select(fixture.db.files).get(), isEmpty);
      expect(await fixture.db.select(fixture.db.buckets).get(), isEmpty);
      expect(await fixture.marker.exists(), isFalse);
      expect(await io.File('${fixture.marker.path}.tmp').exists(), isFalse);
      expect(fixture.tdlibCleared, isTrue);
    },
  );

  test('Account A data is gone before Account B is bound', () async {
    final fixture = await _CleanupFixture.create();
    addTearDown(fixture.dispose);
    const accountA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const accountB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    await fixture.coordinator.bindCurrentAccount(accountA);
    await fixture.seed();

    await fixture.coordinator.ensureReadyForNewAuthorization();
    await fixture.coordinator.bindCurrentAccount(accountB);

    expect(await fixture.db.select(fixture.db.files).get(), isEmpty);
    expect(await fixture.db.select(fixture.db.buckets).get(), isEmpty);
    final owner =
        await (fixture.db.select(fixture.db.appSettings)..where(
              (table) => table.key.equals(
                LocalAccountCleanupCoordinator.accountOwnerSettingKey,
              ),
            ))
            .getSingle();
    expect(owner.value, accountB);
    expect(fixture.tdlibCleared, isTrue);
  });

  test('demo cleanup preserves legacy production metadata snapshots', () async {
    AppRuntimeEnvironment.resetForTesting();
    AppRuntimeEnvironment.configure(AppRuntimeMode.reviewerDemo);
    addTearDown(() {
      AppRuntimeEnvironment.resetForTesting();
      AppRuntimeEnvironment.configure(AppRuntimeMode.production);
    });
    final fixture = await _CleanupFixture.create();
    addTearDown(fixture.dispose);
    await fixture.seed();
    final reviewDirectory = io.Directory(
      '${fixture.temporaryDirectory.path}/televault_metadata_reviewer_demo',
    );
    await reviewDirectory.create(recursive: true);
    await io.File(
      '${reviewDirectory.path}/review.tvmeta',
    ).writeAsString('review');
    final productionSnapshot = io.File(
      '${fixture.temporaryDirectory.path}/tele_vault_metadata_production.tvmeta',
    );
    await productionSnapshot.writeAsString('production');

    await fixture.coordinator.clearReviewEnvironment();

    expect(await reviewDirectory.exists(), isFalse);
    expect(await productionSnapshot.exists(), isTrue);
  });
}

class _CleanupFixture {
  final AppDatabase db;
  final io.Directory root;
  final io.Directory vaultDirectory;
  final io.Directory decryptedDirectory;
  final io.Directory temporaryDirectory;
  final io.File marker;
  final io.File vaultObject;
  final List<String> remoteActions = [];
  late final LocalAccountCleanupCoordinator coordinator;
  bool workersStopped = false;
  bool pinSecretsCleared = false;
  bool recoveryKeyCleared = false;
  bool tdlibCleared = false;
  bool _failVaultDeleteOnce;

  _CleanupFixture({
    required this.db,
    required this.root,
    required this.vaultDirectory,
    required this.decryptedDirectory,
    required this.temporaryDirectory,
    required this.marker,
    required this.vaultObject,
    required bool failVaultDeleteOnce,
  }) : _failVaultDeleteOnce = failVaultDeleteOnce;

  static Future<_CleanupFixture> create({
    bool failVaultDeleteOnce = false,
  }) async {
    final root = await io.Directory.systemTemp.createTemp(
      'televault_account_cleanup_',
    );
    final fixture = _CleanupFixture(
      db: AppDatabase.forTesting(NativeDatabase.memory()),
      root: root,
      vaultDirectory: io.Directory('${root.path}/vault'),
      decryptedDirectory: io.Directory('${root.path}/vault_decrypted'),
      temporaryDirectory: io.Directory('${root.path}/temporary'),
      marker: io.File('${root.path}/support/pending-cleanup.json'),
      vaultObject: io.File('${root.path}/vault/demo.tvv3'),
      failVaultDeleteOnce: failVaultDeleteOnce,
    );
    final lock = MetadataOperationLock(
      lockFileProvider: () async =>
          io.File('${root.path}/support/cleanup.lock'),
    );
    fixture.coordinator = LocalAccountCleanupCoordinator(
      fixture.db,
      lock,
      stopAccountWorkers: () async => fixture.workersStopped = true,
      clearReliabilityState: () async {
        await fixture.db.delete(fixture.db.telegramAccountStates).go();
      },
      clearTdlibStorage: () async => fixture.tdlibCleared = true,
      clearVaultTemporaryFiles: () async {
        if (await fixture.decryptedDirectory.exists()) {
          await fixture.decryptedDirectory.delete(recursive: true);
        }
      },
      deleteVaultFiles: () async {
        if (fixture._failVaultDeleteOnce) {
          fixture._failVaultDeleteOnce = false;
          throw const io.FileSystemException('injected vault delete failure');
        }
        if (await fixture.decryptedDirectory.exists()) {
          await fixture.decryptedDirectory.delete(recursive: true);
        }
        if (await fixture.vaultDirectory.exists()) {
          await fixture.vaultDirectory.delete(recursive: true);
        }
      },
      clearVaultAccessSecrets: () async => fixture.pinSecretsCleared = true,
      clearRecoveryKey: () async => fixture.recoveryKeyCleared = true,
      markerFileProvider: () async => fixture.marker,
      temporaryDirectoryProvider: () async => fixture.temporaryDirectory,
    );
    return fixture;
  }

  Future<void> seed() async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(chatId: BigInt.from(-100), name: 'Demo'),
        );
    final labelId = await db
        .into(db.labels)
        .insert(LabelsCompanion.insert(name: 'Tag'));
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/sample.jpg',
            folderName: 'Camera',
            size: 10,
            bucketId: bucketId,
            labelId: Value(labelId),
          ),
        );
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(key: 'diag_upload_success', value: '2'),
        );
    await db
        .into(db.telegramAccountStates)
        .insert(
          TelegramAccountStatesCompanion.insert(
            accountId: Value(BigInt.from(123)),
          ),
        );
  }

  Future<void> createLocalFiles() async {
    await vaultObject.parent.create(recursive: true);
    await vaultObject.writeAsBytes([1, 2, 3]);
    await decryptedDirectory.create(recursive: true);
    await io.File('${decryptedDirectory.path}/plain.jpg').writeAsBytes([4]);
    final metadata = io.Directory(
      '${temporaryDirectory.path}/televault_metadata',
    );
    await metadata.create(recursive: true);
    await io.File('${metadata.path}/snapshot.tvmeta').writeAsBytes([5]);
  }

  Future<void> dispose() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
