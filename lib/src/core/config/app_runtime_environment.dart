import 'package:flutter/foundation.dart';

enum AppRuntimeMode {
  production('production'),
  reviewerDemo('reviewer_demo');

  final String wireName;

  const AppRuntimeMode(this.wireName);

  static AppRuntimeMode? fromWireName(String? value) {
    // PR #49 persisted this value for the retired Telegram Test DC flow.
    // Migrate it to the network-free demo instead of reopening TDLib.
    if (value == 'play_review') return AppRuntimeMode.reviewerDemo;
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

class AppRuntimeEnvironment {
  const AppRuntimeEnvironment._();

  static AppRuntimeNamespace? _current;
  static bool _locked = false;

  static bool get isConfigured => _current != null;

  static AppRuntimeNamespace get current {
    final configured = _current;
    if (configured == null) {
      throw StateError(
        'The TeleVault runtime environment must be selected before services start.',
      );
    }
    _locked = true;
    return configured;
  }

  static void configure(AppRuntimeMode mode) {
    final selected = AppRuntimeNamespace.forMode(mode);
    final existing = _current;
    if (_locked && existing != null && existing.mode != selected.mode) {
      throw StateError(
        'The TeleVault runtime environment cannot change while services are active.',
      );
    }
    _current = selected;
  }

  static bool get isReviewerDemo => current.isReviewerDemo;
  static String get name => current.name;
  static String get databaseFileName => current.databaseFileName;
  static String get tdlibDirectoryName => current.tdlibDirectoryName;
  static String get workerNamespace => current.workerNamespace;
  static String get queueOwnershipNamespace => current.queueOwnershipNamespace;
  static String get foregroundServiceNamespace =>
      current.foregroundServiceNamespace;
  static String get cleanupStateDirectoryName =>
      current.cleanupStateDirectoryName;
  static String get vaultSecretStorageNamespace =>
      current.vaultSecretStorageNamespace;
  static String get vaultRecoveryStorageNamespace =>
      current.vaultRecoveryStorageNamespace;

  static String cacheDirectory(String productionName) =>
      current.cacheDirectory(productionName);

  static String secureStorageKey(String productionKey) =>
      current.secureStorageKey(productionKey);

  // The caller must first stop workers, close TDLib, and dispose the active
  // ProviderScope. This is used only for the explicit review-to-production flow.
  static void resetAfterRuntimeShutdown() {
    _current = null;
    _locked = false;
  }

  @visibleForTesting
  static void resetForTesting() => resetAfterRuntimeShutdown();
}

class AppRuntimeNamespace {
  final AppRuntimeMode mode;

  const AppRuntimeNamespace({required bool isReviewerDemo})
    : mode = isReviewerDemo
          ? AppRuntimeMode.reviewerDemo
          : AppRuntimeMode.production;

  const AppRuntimeNamespace.forMode(this.mode);

  bool get isReviewerDemo => mode == AppRuntimeMode.reviewerDemo;
  String get name => mode.wireName;
  String get databaseFileName =>
      isReviewerDemo ? 'tele_vault_reviewer_demo.sqlite' : 'tele_vault.sqlite';
  String get tdlibDirectoryName {
    if (isReviewerDemo) {
      throw StateError('TDLib is unavailable in Reviewer Demo.');
    }
    return 'tdlib';
  }

  String get workerNamespace => isReviewerDemo
      ? 'et.shagiz.tele_vault.reviewer_demo'
      : 'et.shagiz.tele_vault.production';
  String get queueOwnershipNamespace =>
      isReviewerDemo ? 'upload_queue.reviewer_demo' : 'upload_queue.production';
  String get foregroundServiceNamespace => isReviewerDemo
      ? 'televault_background_sync_reviewer_demo'
      : 'televault_background_sync_production';
  String get cleanupStateDirectoryName =>
      isReviewerDemo ? 'account_reviewer_demo' : 'account';
  String get vaultSecretStorageNamespace => isReviewerDemo
      ? 'tele_vault_vault_secret_reviewer_demo'
      : 'tele_vault_vault_secret';
  String get vaultRecoveryStorageNamespace => isReviewerDemo
      ? 'tele_vault_vault_recovery_reviewer_demo'
      : 'tele_vault_vault_recovery';

  String cacheDirectory(String productionName) =>
      isReviewerDemo ? '${productionName}_reviewer_demo' : productionName;

  String secureStorageKey(String productionKey) =>
      isReviewerDemo ? 'reviewer_demo.$productionKey' : productionKey;
}
