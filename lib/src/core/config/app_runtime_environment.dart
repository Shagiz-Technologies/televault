import 'package:flutter/foundation.dart';

enum AppRuntimeMode {
  production('production'),
  playReview('play_review');

  final String wireName;

  const AppRuntimeMode(this.wireName);

  static AppRuntimeMode? fromWireName(String? value) {
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

class AppRuntimeEnvironment {
  const AppRuntimeEnvironment._();

  static const bool compileTimeReviewEnabled = bool.fromEnvironment(
    'TELEVAULT_PLAY_REVIEW',
  );

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

  static bool get isPlayStoreReview => current.isPlayStoreReview;
  static String get name => current.name;
  static String get databaseFileName => current.databaseFileName;
  static String get tdlibDirectoryName => current.tdlibDirectoryName;
  static String get workerNamespace => current.workerNamespace;
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

  const AppRuntimeNamespace({required bool isPlayStoreReview})
    : mode = isPlayStoreReview
          ? AppRuntimeMode.playReview
          : AppRuntimeMode.production;

  const AppRuntimeNamespace.forMode(this.mode);

  bool get isPlayStoreReview => mode == AppRuntimeMode.playReview;
  String get name => mode.wireName;
  String get databaseFileName =>
      isPlayStoreReview ? 'tele_vault_play_review.sqlite' : 'tele_vault.sqlite';
  String get tdlibDirectoryName =>
      isPlayStoreReview ? 'tdlib_play_review' : 'tdlib';
  String get workerNamespace => isPlayStoreReview
      ? 'et.shagiz.tele_vault.play_review'
      : 'et.shagiz.tele_vault.production';
  String get vaultSecretStorageNamespace => isPlayStoreReview
      ? 'tele_vault_vault_secret_play_review'
      : 'tele_vault_vault_secret';
  String get vaultRecoveryStorageNamespace => isPlayStoreReview
      ? 'tele_vault_vault_recovery_play_review'
      : 'tele_vault_vault_recovery';

  String cacheDirectory(String productionName) =>
      isPlayStoreReview ? '${productionName}_play_review' : productionName;

  String secureStorageKey(String productionKey) =>
      isPlayStoreReview ? 'play_review.$productionKey' : productionKey;
}
