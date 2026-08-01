import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/vault/services/vault_recovery_service.dart';

void main() {
  test('generated recovery key must be confirmed before use', () async {
    final service = VaultRecoveryService(
      store: _MemorySecretStore(),
      randomBytes: (length) =>
          Uint8List.fromList(List<int>.generate(length, (index) => index)),
    );

    final exported = await service.ensureRecoveryKey();
    expect(exported, startsWith(VaultRecoveryService.recoveryPrefix));
    expect(
      service.requireConfirmedKey(),
      throwsA(isA<VaultRecoveryException>()),
    );

    await service.confirmRecoveryKey(exported);
    expect(await service.isRecoveryKeyConfirmed(), isTrue);
    expect(await service.requireConfirmedKey(), hasLength(32));
  });

  test('checksum detects a mistyped recovery key', () async {
    final key = Uint8List.fromList(List<int>.filled(32, 7));
    final formatted = VaultRecoveryService.formatRecoveryKey(key);
    final replacement = formatted.endsWith('A') ? 'B' : 'A';
    final mistyped =
        '${formatted.substring(0, formatted.length - 1)}$replacement';

    expect(
      () => VaultRecoveryService.parseRecoveryKey(mistyped),
      throwsA(
        isA<VaultRecoveryException>().having(
          (error) => error.code,
          'code',
          VaultRecoveryErrorCode.checksumMismatch,
        ),
      ),
    );
  });

  test('import can replace only an unconfirmed generated key', () async {
    final store = _MemorySecretStore();
    final service = VaultRecoveryService(
      store: store,
      randomBytes: (length) => Uint8List.fromList(List<int>.filled(length, 1)),
    );
    await service.ensureRecoveryKey();

    final imported = VaultRecoveryService.formatRecoveryKey(
      Uint8List.fromList(List<int>.filled(32, 2)),
    );
    await service.importRecoveryKey(imported);
    expect(await service.exportRecoveryKey(), imported);

    final replacement = VaultRecoveryService.formatRecoveryKey(
      Uint8List.fromList(List<int>.filled(32, 3)),
    );
    expect(
      service.importRecoveryKey(replacement),
      throwsA(
        isA<VaultRecoveryException>().having(
          (error) => error.code,
          'code',
          VaultRecoveryErrorCode.replacementDenied,
        ),
      ),
    );
  });
}

class _MemorySecretStore implements VaultSecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
