import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_runtime_environment.dart';
import '../../sync/services/android_background_sync_bridge.dart';

typedef ReviewerDemoCleanupAction = Future<void> Function();

class ReviewerDemoCleanupService {
  final ReviewerDemoCleanupAction _cancelDemoWork;
  final ReviewerDemoCleanupAction _clearDemoSecrets;
  final ReviewerDemoCleanupAction _deleteDemoFiles;

  ReviewerDemoCleanupService({
    ReviewerDemoCleanupAction? cancelDemoWork,
    ReviewerDemoCleanupAction? clearDemoSecrets,
    ReviewerDemoCleanupAction? deleteDemoFiles,
  }) : _cancelDemoWork = cancelDemoWork ?? _cancelPlatformWork,
       _clearDemoSecrets = clearDemoSecrets ?? _clearPlatformSecrets,
       _deleteDemoFiles = deleteDemoFiles ?? _deletePlatformFiles;

  Future<void> clear() async {
    if (!AppRuntimeEnvironment.isReviewerDemo) {
      throw StateError('Reviewer Demo cleanup cannot run in production.');
    }
    await _cancelDemoWork();
    await _clearDemoSecrets();
    await _deleteDemoFiles();
  }

  static Future<void> _cancelPlatformWork() =>
      AndroidBackgroundSyncBridge().cancelPersistentWork();

  static Future<void> _clearPlatformSecrets() async {
    final vaultSecrets = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppRuntimeEnvironment.vaultSecretStorageNamespace,
      ),
    );
    final recoverySecrets = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppRuntimeEnvironment.vaultRecoveryStorageNamespace,
      ),
    );
    if (Platform.isAndroid) {
      await vaultSecrets.deleteAll();
      await recoverySecrets.deleteAll();
      return;
    }

    // Apple platforms share a Keychain service, so remove only demo-prefixed
    // keys instead of clearing the service.
    for (final key in [
      'vault_biometric_secret',
      'vault_recovery_key_v1',
      'vault_recovery_key_confirmed_v1',
    ]) {
      await vaultSecrets.delete(
        key: AppRuntimeEnvironment.secureStorageKey(key),
      );
      await recoverySecrets.delete(
        key: AppRuntimeEnvironment.secureStorageKey(key),
      );
    }
  }

  static Future<void> _deletePlatformFiles() async {
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final temporary = await getTemporaryDirectory();
    final database = File(
      path.join(documents.path, AppRuntimeEnvironment.databaseFileName),
    );
    for (final candidate in [
      database,
      File('${database.path}-wal'),
      File('${database.path}-shm'),
    ]) {
      if (await candidate.exists()) await candidate.delete();
    }

    final directoryNames = <String>{
      AppRuntimeEnvironment.cacheDirectory('vault'),
      AppRuntimeEnvironment.cacheDirectory('vault_decrypted'),
      AppRuntimeEnvironment.cacheDirectory('reviewer_demo_media'),
      AppRuntimeEnvironment.cacheDirectory('televault_metadata'),
      AppRuntimeEnvironment.cacheDirectory('televault_metadata_downloads'),
      AppRuntimeEnvironment.cleanupStateDirectoryName,
      // Remove the retired Test DC files during migration. Production names
      // are intentionally absent from this list.
      'tdlib_play_review',
      'televault_metadata_play_review',
      'televault_metadata_downloads_play_review',
      'vault_play_review',
      'vault_decrypted_play_review',
      'account_play_review',
    };
    for (final root in [documents, support, temporary]) {
      for (final name in directoryNames) {
        final directory = Directory(path.join(root.path, name));
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }

    for (final legacyName in [
      'tele_vault_play_review.sqlite',
      'tele_vault_play_review.sqlite-wal',
      'tele_vault_play_review.sqlite-shm',
    ]) {
      final file = File(path.join(documents.path, legacyName));
      if (await file.exists()) await file.delete();
    }
  }
}
