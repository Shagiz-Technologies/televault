import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';

void main() {
  test('Play review and production storage namespaces never overlap', () {
    const production = AppRuntimeNamespace(isPlayStoreReview: false);
    const review = AppRuntimeNamespace(isPlayStoreReview: true);

    expect(review.databaseFileName, isNot(production.databaseFileName));
    expect(review.tdlibDirectoryName, isNot(production.tdlibDirectoryName));
    expect(review.workerNamespace, isNot(production.workerNamespace));
    expect(
      review.vaultSecretStorageNamespace,
      isNot(production.vaultSecretStorageNamespace),
    );
    expect(
      review.vaultRecoveryStorageNamespace,
      isNot(production.vaultRecoveryStorageNamespace),
    );
    expect(
      review.cacheDirectory('televault_metadata'),
      isNot(production.cacheDirectory('televault_metadata')),
    );
    expect(
      review.secureStorageKey('tdlib_database_key'),
      isNot(production.secureStorageKey('tdlib_database_key')),
    );
  });
}
