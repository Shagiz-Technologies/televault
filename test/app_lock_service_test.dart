import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/features/settings/services/app_lock_service.dart';

void main() {
  late AppDatabase db;
  late AppLockService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AppLockService(db, iterations: 10);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'password attempts lock in five-try windows and reset with new password',
    () async {
      await service.savePassword('correct-password');

      for (var i = 1; i <= 4; i++) {
        final result = await service.verifySecretForUnlock('wrong-password');
        expect(result.status, AppLockSecretAttemptStatus.invalid);
        expect(result.lockState.attemptsRemaining, 5 - i);
      }

      var result = await service.verifySecretForUnlock('wrong-password');
      expect(result.status, AppLockSecretAttemptStatus.temporarilyLocked);
      expect(result.lockState.timedLockouts, 1);
      expect(result.lockState.isTemporarilyLocked, isTrue);

      result = await service.verifySecretForUnlock('correct-password');
      expect(result.status, AppLockSecretAttemptStatus.temporarilyLocked);

      await _expireLockout(db);
      expect(
        (await service.getCredentialLockState()).isTemporarilyLocked,
        isFalse,
      );

      for (var block = 2; block <= 3; block++) {
        for (var i = 1; i <= 5; i++) {
          result = await service.verifySecretForUnlock('wrong-password');
        }
        expect(result.status, AppLockSecretAttemptStatus.temporarilyLocked);
        expect(result.lockState.timedLockouts, block);
        await _expireLockout(db);
      }

      await service.getCredentialLockState();
      result = await service.verifySecretForUnlock('wrong-password');
      expect(result.status, AppLockSecretAttemptStatus.permanentlyLocked);
      expect(result.lockState.permanentlyLocked, isTrue);

      result = await service.verifySecretForUnlock('correct-password');
      expect(result.status, AppLockSecretAttemptStatus.permanentlyLocked);

      await service.savePassword('new-password');
      result = await service.verifySecretForUnlock('new-password');
      expect(result.status, AppLockSecretAttemptStatus.success);
    },
  );
}

Future<void> _expireLockout(AppDatabase db) async {
  await db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: 'app_lock_locked_until',
          value: DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        ),
      );
}
