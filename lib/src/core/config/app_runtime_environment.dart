class AppRuntimeEnvironment {
  const AppRuntimeEnvironment._();

  static const bool isPlayStoreReview = bool.fromEnvironment(
    'TELEVAULT_PLAY_REVIEW',
  );

  static const AppRuntimeNamespace current = AppRuntimeNamespace(
    isPlayStoreReview: isPlayStoreReview,
  );

  static const String name = isPlayStoreReview ? 'play_review' : 'production';
  static const String databaseFileName = isPlayStoreReview
      ? 'tele_vault_play_review.sqlite'
      : 'tele_vault.sqlite';
  static const String tdlibDirectoryName = isPlayStoreReview
      ? 'tdlib_play_review'
      : 'tdlib';
  static const String workerNamespace = isPlayStoreReview
      ? 'et.shagiz.tele_vault.play_review'
      : 'et.shagiz.tele_vault.production';
  static const String vaultSecretStorageNamespace = isPlayStoreReview
      ? 'tele_vault_vault_secret_play_review'
      : 'tele_vault_vault_secret';
  static const String vaultRecoveryStorageNamespace = isPlayStoreReview
      ? 'tele_vault_vault_recovery_play_review'
      : 'tele_vault_vault_recovery';

  static String cacheDirectory(String productionName) =>
      current.cacheDirectory(productionName);

  static String secureStorageKey(String productionKey) =>
      current.secureStorageKey(productionKey);
}

class AppRuntimeNamespace {
  final bool isPlayStoreReview;

  const AppRuntimeNamespace({required this.isPlayStoreReview});

  String get name => isPlayStoreReview ? 'play_review' : 'production';
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
