import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';

void main() {
  test('reviewer demo and production storage namespaces never overlap', () {
    const production = AppRuntimeNamespace(isReviewerDemo: false);
    const demo = AppRuntimeNamespace(isReviewerDemo: true);

    expect(demo.databaseFileName, isNot(production.databaseFileName));
    expect(() => demo.tdlibDirectoryName, throwsStateError);
    expect(demo.workerNamespace, isNot(production.workerNamespace));
    expect(
      demo.queueOwnershipNamespace,
      isNot(production.queueOwnershipNamespace),
    );
    expect(
      demo.foregroundServiceNamespace,
      isNot(production.foregroundServiceNamespace),
    );
    expect(
      demo.cleanupStateDirectoryName,
      isNot(production.cleanupStateDirectoryName),
    );
    expect(
      demo.vaultSecretStorageNamespace,
      isNot(production.vaultSecretStorageNamespace),
    );
    expect(
      demo.vaultRecoveryStorageNamespace,
      isNot(production.vaultRecoveryStorageNamespace),
    );
    expect(
      demo.cacheDirectory('televault_metadata'),
      isNot(production.cacheDirectory('televault_metadata')),
    );
    expect(
      demo.secureStorageKey('tdlib_database_key'),
      isNot(production.secureStorageKey('tdlib_database_key')),
    );
  });

  test('retired play review selection migrates to reviewer demo', () {
    expect(
      AppRuntimeMode.fromWireName('play_review'),
      AppRuntimeMode.reviewerDemo,
    );
  });
}
