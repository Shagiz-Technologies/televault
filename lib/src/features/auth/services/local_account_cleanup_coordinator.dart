import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_runtime_environment.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/services/telegram_service.dart';
import '../../backup/services/metadata_operation_lock.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/background_sync_coordinator.dart';
import '../../sync/services/sync_initializer.dart';
import '../../sync/services/sync_service.dart';
import '../../vault/services/vault_pin_service.dart';
import '../../vault/services/vault_recovery_service.dart';
import '../../vault/services/vault_service.dart';

typedef CleanupAction = Future<void> Function();
typedef CleanupMarkerFileProvider = Future<io.File> Function();
typedef CleanupDirectoryProvider = Future<io.Directory> Function();

final localAccountCleanupCoordinatorProvider =
    Provider<LocalAccountCleanupCoordinator>((ref) {
      final syncService = ref.watch(syncServiceProvider);
      final syncInitializer = ref.watch(syncInitializerProvider);
      final uploader = ref.watch(fileUploaderProvider);
      final background = ref.watch(backgroundSyncCoordinatorProvider);
      final reliability = ref.watch(telegramReliabilityServiceProvider);
      final telegram = ref.watch(telegramServiceProvider);
      final vault = ref.watch(vaultServiceProvider);
      final pin = ref.watch(vaultPinServiceProvider);
      final recovery = ref.watch(vaultRecoveryServiceProvider);
      return LocalAccountCleanupCoordinator(
        ref.watch(databaseProvider),
        ref.watch(metadataOperationLockProvider),
        stopAccountWorkers: () async {
          await background.stopForAccountCleanup();
          syncService.stopSyncLoop();
          syncInitializer.resetForAccountCleanup();
          await uploader.stopForAccountCleanup();
        },
        clearReliabilityState: reliability.clearAccountState,
        clearTdlibStorage: telegram.clearLocalAccountStorage,
        clearVaultTemporaryFiles: vault.cleanupStaleTemporaryFiles,
        deleteVaultFiles: vault.deleteAllLocalVaultFiles,
        clearVaultAccessSecrets: pin.clearAccountSecrets,
        clearRecoveryKey: recovery.clearRecoveryKey,
      );
    });

enum LocalAccountCleanupErrorCode {
  invalidAccountBinding,
  remoteLogoutFailed,
  localCleanupFailed,
}

class LocalAccountCleanupException implements Exception {
  final LocalAccountCleanupErrorCode code;
  final String message;
  final Object? cause;

  const LocalAccountCleanupException(this.code, this.message, {this.cause});

  @override
  String toString() => message;
}

class LocalAccountCleanupOptions {
  final bool preserveEncryptedVaultFiles;

  const LocalAccountCleanupOptions({required this.preserveEncryptedVaultFiles});
}

enum _CleanupStage {
  started,
  workersStopped,
  telegramLoggedOut,
  databaseCleared,
  localFilesCleared,
  secureStorageCleared,
  tdlibCleared,
}

class LocalAccountCleanupCoordinator {
  static const accountOwnerSettingKey = 'local_account_fingerprint_v1';
  static const _markerVersion = 1;

  final AppDatabase _db;
  final MetadataOperationLock _operationLock;
  final CleanupAction _stopAccountWorkers;
  final CleanupAction _clearReliabilityState;
  final CleanupAction _clearTdlibStorage;
  final CleanupAction _clearVaultTemporaryFiles;
  final CleanupAction _deleteVaultFiles;
  final CleanupAction _clearVaultAccessSecrets;
  final CleanupAction _clearRecoveryKey;
  final CleanupMarkerFileProvider _markerFileProvider;
  final CleanupDirectoryProvider _temporaryDirectoryProvider;

  LocalAccountCleanupCoordinator(
    this._db,
    this._operationLock, {
    required CleanupAction stopAccountWorkers,
    required CleanupAction clearReliabilityState,
    required CleanupAction clearTdlibStorage,
    required CleanupAction clearVaultTemporaryFiles,
    required CleanupAction deleteVaultFiles,
    required CleanupAction clearVaultAccessSecrets,
    required CleanupAction clearRecoveryKey,
    CleanupMarkerFileProvider? markerFileProvider,
    CleanupDirectoryProvider? temporaryDirectoryProvider,
  }) : _stopAccountWorkers = stopAccountWorkers,
       _clearReliabilityState = clearReliabilityState,
       _clearTdlibStorage = clearTdlibStorage,
       _clearVaultTemporaryFiles = clearVaultTemporaryFiles,
       _deleteVaultFiles = deleteVaultFiles,
       _clearVaultAccessSecrets = clearVaultAccessSecrets,
       _clearRecoveryKey = clearRecoveryKey,
       _markerFileProvider = markerFileProvider ?? _defaultMarkerFile,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  Future<void> logout({
    required LocalAccountCleanupOptions options,
    required CleanupAction remoteLogout,
  }) {
    return _operationLock.synchronized(() async {
      var marker = _CleanupMarker(
        stage: _CleanupStage.started,
        preserveEncryptedVaultFiles: options.preserveEncryptedVaultFiles,
      );
      await _writeMarker(marker);
      try {
        await _stopAccountWorkers();
        marker = marker.copyWith(stage: _CleanupStage.workersStopped);
        await _writeMarker(marker);
        await remoteLogout();
        marker = marker.copyWith(stage: _CleanupStage.telegramLoggedOut);
        await _writeMarker(marker);
      } catch (error) {
        throw LocalAccountCleanupException(
          LocalAccountCleanupErrorCode.remoteLogoutFailed,
          'Telegram logout did not complete. Local cleanup will resume safely on the next launch.',
          cause: error,
        );
      }
      await _resumeMarker(marker);
    });
  }

  Future<void> resumePendingCleanup() {
    return _operationLock.synchronized(() async {
      final marker = await _readMarker();
      if (marker == null) return;
      await _resumeMarker(marker);
    });
  }

  Future<void> ensureReadyForNewAuthorization() {
    return _operationLock.synchronized(() async {
      final pending = await _readMarker();
      if (pending != null) {
        await _resumeMarker(pending);
        return;
      }
      final owner = await _readAccountOwner();
      if (owner == null) return;
      final marker = const _CleanupMarker(
        stage: _CleanupStage.started,
        preserveEncryptedVaultFiles: false,
      );
      await _writeMarker(marker);
      await _resumeMarker(marker);
    });
  }

  Future<void> bindCurrentAccount(String accountFingerprint) {
    return _operationLock.synchronized(() async {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(accountFingerprint)) {
        throw const LocalAccountCleanupException(
          LocalAccountCleanupErrorCode.invalidAccountBinding,
          'The Telegram account binding is invalid.',
        );
      }
      final existing = await _readAccountOwner();
      if (existing != null && existing != accountFingerprint) {
        // A different authenticated account must never see the previous Drift
        // state. TDLib is not cleared here because it now belongs to the newly
        // authenticated account; normal logout clears it before phone entry.
        var marker = const _CleanupMarker(
          stage: _CleanupStage.started,
          preserveEncryptedVaultFiles: false,
        );
        await _writeMarker(marker);
        await _stopAccountWorkers();
        marker = marker.copyWith(stage: _CleanupStage.workersStopped);
        await _writeMarker(marker);
        await _clearLocalState(
          preserveEncryptedVaultFiles: false,
          clearTdlib: false,
          initialStage: marker.stage,
        );
        await _deleteMarker();
      }
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: accountOwnerSettingKey,
              value: accountFingerprint,
            ),
          );
    });
  }

  Future<void> _resumeMarker(_CleanupMarker marker) async {
    try {
      var current = marker;
      if (current.stage.index < _CleanupStage.workersStopped.index) {
        await _stopAccountWorkers();
        current = current.copyWith(stage: _CleanupStage.workersStopped);
        await _writeMarker(current);
      }
      await _clearLocalState(
        preserveEncryptedVaultFiles: current.preserveEncryptedVaultFiles,
        clearTdlib: true,
        initialStage: current.stage,
      );
      await _deleteMarker();
    } catch (error) {
      if (error is LocalAccountCleanupException) rethrow;
      throw LocalAccountCleanupException(
        LocalAccountCleanupErrorCode.localCleanupFailed,
        'TeleVault local account cleanup is incomplete and will resume on the next launch.',
        cause: error,
      );
    }
  }

  Future<void> _clearLocalState({
    required bool preserveEncryptedVaultFiles,
    required bool clearTdlib,
    _CleanupStage initialStage = _CleanupStage.telegramLoggedOut,
  }) async {
    var stage = initialStage;
    if (stage.index < _CleanupStage.databaseCleared.index) {
      await _clearReliabilityState();
      await _db.transaction(() async {
        await _db.delete(_db.files).go();
        await _db.delete(_db.buckets).go();
        await _db.delete(_db.labels).go();
        await _db.delete(_db.telegramAccountStates).go();
        await _db.delete(_db.appSettings).go();
      });
      stage = _CleanupStage.databaseCleared;
      await _writeMarker(
        _CleanupMarker(
          stage: stage,
          preserveEncryptedVaultFiles: preserveEncryptedVaultFiles,
        ),
      );
    }
    if (stage.index < _CleanupStage.localFilesCleared.index) {
      if (preserveEncryptedVaultFiles) {
        await _clearVaultTemporaryFiles();
      } else {
        await _deleteVaultFiles();
      }
      await _deleteMetadataTemporaryFiles();
      stage = _CleanupStage.localFilesCleared;
      await _writeMarker(
        _CleanupMarker(
          stage: stage,
          preserveEncryptedVaultFiles: preserveEncryptedVaultFiles,
        ),
      );
    }
    if (stage.index < _CleanupStage.secureStorageCleared.index) {
      await _clearVaultAccessSecrets();
      if (!preserveEncryptedVaultFiles) await _clearRecoveryKey();
      stage = _CleanupStage.secureStorageCleared;
      await _writeMarker(
        _CleanupMarker(
          stage: stage,
          preserveEncryptedVaultFiles: preserveEncryptedVaultFiles,
        ),
      );
    }
    if (clearTdlib && stage.index < _CleanupStage.tdlibCleared.index) {
      await _clearTdlibStorage();
      await _writeMarker(
        _CleanupMarker(
          stage: _CleanupStage.tdlibCleared,
          preserveEncryptedVaultFiles: preserveEncryptedVaultFiles,
        ),
      );
    }
  }

  Future<String?> _readAccountOwner() async {
    final row =
        await (_db.select(_db.appSettings)
              ..where((table) => table.key.equals(accountOwnerSettingKey)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> _deleteMetadataTemporaryFiles() async {
    final root = await _temporaryDirectoryProvider();
    for (final directoryName in [
      AppRuntimeEnvironment.cacheDirectory('televault_metadata'),
      AppRuntimeEnvironment.cacheDirectory('televault_metadata_downloads'),
    ]) {
      final directory = io.Directory(path.join(root.path, directoryName));
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! io.File) continue;
      final name = path.basename(entity.path);
      if ((name.startsWith('tele_vault_metadata_') ||
              name.startsWith('televault_metadata_')) &&
          name.endsWith('.tvmeta')) {
        await entity.delete();
      }
    }
  }

  Future<_CleanupMarker?> _readMarker() async {
    final file = await _markerFileProvider();
    final temporary = io.File('${file.path}.tmp');
    final source = await file.exists()
        ? file
        : await temporary.exists()
        ? temporary
        : null;
    if (source == null) return null;
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _markerVersion) {
        throw const FormatException();
      }
      final stageName = decoded['stage']?.toString();
      final stage = _CleanupStage.values.where(
        (value) => value.name == stageName,
      );
      if (stage.isEmpty || decoded['preserve_encrypted_vault_files'] is! bool) {
        throw const FormatException();
      }
      return _CleanupMarker(
        stage: stage.first,
        preserveEncryptedVaultFiles:
            decoded['preserve_encrypted_vault_files'] as bool,
      );
    } catch (error) {
      throw LocalAccountCleanupException(
        LocalAccountCleanupErrorCode.localCleanupFailed,
        'The resumable local cleanup marker is invalid.',
        cause: error,
      );
    }
  }

  Future<void> _writeMarker(_CleanupMarker marker) async {
    final file = await _markerFileProvider();
    await file.parent.create(recursive: true);
    final temporary = io.File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': _markerVersion,
        'stage': marker.stage.name,
        'preserve_encrypted_vault_files': marker.preserveEncryptedVaultFiles,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> _deleteMarker() async {
    final file = await _markerFileProvider();
    if (await file.exists()) await file.delete();
    final temporary = io.File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }

  static Future<io.File> _defaultMarkerFile() async {
    final support = await getApplicationSupportDirectory();
    return io.File(
      path.join(
        support.path,
        AppRuntimeEnvironment.cacheDirectory('account'),
        'pending-local-cleanup.json',
      ),
    );
  }
}

class _CleanupMarker {
  final _CleanupStage stage;
  final bool preserveEncryptedVaultFiles;

  const _CleanupMarker({
    required this.stage,
    required this.preserveEncryptedVaultFiles,
  });

  _CleanupMarker copyWith({_CleanupStage? stage}) {
    return _CleanupMarker(
      stage: stage ?? this.stage,
      preserveEncryptedVaultFiles: preserveEncryptedVaultFiles,
    );
  }
}
