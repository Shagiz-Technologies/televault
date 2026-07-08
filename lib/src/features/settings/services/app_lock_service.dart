import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Kept for backward compatibility with stored settings. The UI now presents this
// as two simple choices: phone security or a TeleVault password.
enum AppLockMethod { pin, password, biometric }

enum AppLockSecretAttemptStatus {
  success,
  invalid,
  notConfigured,
  temporarilyLocked,
  permanentlyLocked,
}

class AppLockConfig {
  final bool enabled;
  final AppLockMethod method;
  final int timeoutSeconds;
  final bool lockOnBackground;

  const AppLockConfig({
    this.enabled = false,
    this.method = AppLockMethod.biometric,
    this.timeoutSeconds = 60,
    this.lockOnBackground = true,
  });

  AppLockConfig copyWith({
    bool? enabled,
    AppLockMethod? method,
    int? timeoutSeconds,
    bool? lockOnBackground,
  }) {
    return AppLockConfig(
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      lockOnBackground: lockOnBackground ?? this.lockOnBackground,
    );
  }
}

class AppCredentialLockState {
  final int failedAttempts;
  final int timedLockouts;
  final DateTime? lockedUntil;
  final bool permanentlyLocked;

  const AppCredentialLockState({
    required this.failedAttempts,
    required this.timedLockouts,
    this.lockedUntil,
    this.permanentlyLocked = false,
  });

  static const maxAttemptsBeforeLockout = 5;

  bool get isTemporarilyLocked {
    final until = lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  int get attemptsRemaining {
    if (permanentlyLocked || isTemporarilyLocked) return 0;
    return (maxAttemptsBeforeLockout - failedAttempts).clamp(
      0,
      maxAttemptsBeforeLockout,
    );
  }

  Duration remainingLockout([DateTime? now]) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final diff = until.difference(now ?? DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class AppLockSecretAttemptResult {
  final AppLockSecretAttemptStatus status;
  final AppCredentialLockState lockState;

  const AppLockSecretAttemptResult({
    required this.status,
    required this.lockState,
  });

  bool get success => status == AppLockSecretAttemptStatus.success;
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(ref.watch(databaseProvider));
});

class AppLockService {
  final AppDatabase _db;
  final LocalAuthentication _auth = LocalAuthentication();
  final int _iterations;

  static const _enabledKey = 'app_lock_enabled';
  static const _methodKey = 'app_lock_method';
  static const _timeoutKey = 'app_lock_timeout_sec';
  static const _lockOnBackgroundKey = 'app_lock_bg';
  static const _hashKey = 'app_lock_hash';
  static const _saltKey = 'app_lock_salt';
  static const _iterKey = 'app_lock_iter';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';
  static const _timedLockoutsKey = 'app_lock_timed_lockouts';
  static const _lockedUntilKey = 'app_lock_locked_until';
  static const _passwordPermanentlyLockedKey =
      'app_lock_password_permanently_locked';

  static const _defaultIterations = 120000;
  static const _maxTimedLockouts = 3;
  static const _firstLockoutSeconds = 30;

  AppLockService(this._db, {int iterations = _defaultIterations})
    : _iterations = iterations;

  Future<AppLockConfig> getConfig() async {
    final map = await _readMany({
      _enabledKey,
      _methodKey,
      _timeoutKey,
      _lockOnBackgroundKey,
    });
    final methodName = map[_methodKey] ?? AppLockMethod.biometric.name;
    final storedMethod = AppLockMethod.values.firstWhere(
      (m) => m.name == methodName,
      orElse: () => AppLockMethod.biometric,
    );
    final method = storedMethod == AppLockMethod.pin
        ? AppLockMethod.password
        : storedMethod;

    return AppLockConfig(
      enabled: (map[_enabledKey] ?? 'false') == 'true',
      method: method,
      timeoutSeconds: int.tryParse(map[_timeoutKey] ?? '60') ?? 60,
      lockOnBackground: (map[_lockOnBackgroundKey] ?? 'true') == 'true',
    );
  }

  Future<void> saveConfig(AppLockConfig config, {String? secret}) async {
    final normalizedMethod = config.method == AppLockMethod.pin
        ? AppLockMethod.password
        : config.method;

    await _db.transaction(() async {
      await _upsert(_enabledKey, config.enabled.toString());
      await _upsert(_methodKey, normalizedMethod.name);
      await _upsert(_timeoutKey, config.timeoutSeconds.toString());
      await _upsert(_lockOnBackgroundKey, config.lockOnBackground.toString());

      if (secret != null && secret.isNotEmpty) {
        await _writeSecret(secret);
        await clearCredentialFailures(includePermanent: true);
      }
    });
  }

  Future<void> savePassword(String secret) async {
    await _db.transaction(() async {
      await _writeSecret(secret);
      await _upsert(_methodKey, AppLockMethod.password.name);
      await clearCredentialFailures(includePermanent: true);
    });
  }

  Future<void> removePassword() async {
    await _db.transaction(() async {
      await _deleteKeys({_hashKey, _saltKey, _iterKey});
      await clearCredentialFailures(includePermanent: true);
    });
  }

  Future<bool> hasSecretConfigured() async {
    final hash = await _read(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<AppLockSecretAttemptResult> verifySecretForUnlock(
    String secret,
  ) async {
    final currentState = await getCredentialLockState();
    if (currentState.permanentlyLocked) {
      return AppLockSecretAttemptResult(
        status: AppLockSecretAttemptStatus.permanentlyLocked,
        lockState: currentState,
      );
    }
    if (currentState.isTemporarilyLocked) {
      return AppLockSecretAttemptResult(
        status: AppLockSecretAttemptStatus.temporarilyLocked,
        lockState: currentState,
      );
    }

    if (!await hasSecretConfigured()) {
      return AppLockSecretAttemptResult(
        status: AppLockSecretAttemptStatus.notConfigured,
        lockState: currentState,
      );
    }

    final ok = await _verifySecretHash(secret);
    if (ok) {
      await clearCredentialFailures(includePermanent: true);
      return AppLockSecretAttemptResult(
        status: AppLockSecretAttemptStatus.success,
        lockState: await getCredentialLockState(),
      );
    }

    final nextState = await _recordFailedCredentialAttempt(currentState);
    return AppLockSecretAttemptResult(
      status: nextState.permanentlyLocked
          ? AppLockSecretAttemptStatus.permanentlyLocked
          : nextState.isTemporarilyLocked
          ? AppLockSecretAttemptStatus.temporarilyLocked
          : AppLockSecretAttemptStatus.invalid,
      lockState: nextState,
    );
  }

  Future<AppCredentialLockState> getCredentialLockState() async {
    final map = await _readMany({
      _failedAttemptsKey,
      _timedLockoutsKey,
      _lockedUntilKey,
      _passwordPermanentlyLockedKey,
    });

    var permanentlyLocked =
        (map[_passwordPermanentlyLockedKey] ?? 'false') == 'true';
    final timedLockouts = int.tryParse(map[_timedLockoutsKey] ?? '0') ?? 0;
    var failedAttempts = int.tryParse(map[_failedAttemptsKey] ?? '0') ?? 0;
    var lockedUntil = DateTime.tryParse(map[_lockedUntilKey] ?? '');

    if (lockedUntil != null && !lockedUntil.isAfter(DateTime.now())) {
      lockedUntil = null;
      failedAttempts = 0;
      await _deleteKeys({_lockedUntilKey});
      await _upsert(_failedAttemptsKey, '0');
      if (timedLockouts >= _maxTimedLockouts) {
        permanentlyLocked = true;
        await _upsert(_passwordPermanentlyLockedKey, 'true');
      }
    }

    return AppCredentialLockState(
      failedAttempts: failedAttempts.clamp(
        0,
        AppCredentialLockState.maxAttemptsBeforeLockout,
      ),
      timedLockouts: timedLockouts.clamp(0, _maxTimedLockouts),
      lockedUntil: lockedUntil,
      permanentlyLocked: permanentlyLocked,
    );
  }

  Future<void> clearCredentialFailures({required bool includePermanent}) async {
    await _upsert(_failedAttemptsKey, '0');
    await _upsert(_timedLockoutsKey, '0');
    await _deleteKeys({_lockedUntilKey});
    if (includePermanent) {
      await _upsert(_passwordPermanentlyLockedKey, 'false');
    }
  }

  Future<bool> canUsePhoneUnlock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticatePhoneUnlock({String? reason}) async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.authenticate(
        localizedReason:
            reason ?? 'Unlock TeleVault with your phone screen lock',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeSecret(String secret) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(
      password: utf8.encode(secret),
      salt: salt,
      iterations: _iterations,
      keyLength: 32,
    );
    await _upsert(_hashKey, base64Encode(hash));
    await _upsert(_saltKey, base64Encode(salt));
    await _upsert(_iterKey, _iterations.toString());
  }

  Future<bool> _verifySecretHash(String secret) async {
    final hashB64 = await _read(_hashKey);
    final saltB64 = await _read(_saltKey);
    final iterRaw = await _read(_iterKey);
    if (hashB64 == null || saltB64 == null || iterRaw == null) {
      return false;
    }

    final expected = base64Decode(hashB64);
    final salt = base64Decode(saltB64);
    final iter = int.tryParse(iterRaw) ?? _iterations;
    final actual = _pbkdf2(
      password: utf8.encode(secret),
      salt: Uint8List.fromList(salt),
      iterations: iter,
      keyLength: expected.length,
    );
    return _constantTimeEquals(expected, actual);
  }

  Future<AppCredentialLockState> _recordFailedCredentialAttempt(
    AppCredentialLockState current,
  ) async {
    final failedAttempts = current.failedAttempts + 1;
    if (failedAttempts < AppCredentialLockState.maxAttemptsBeforeLockout) {
      await _upsert(_failedAttemptsKey, failedAttempts.toString());
      return AppCredentialLockState(
        failedAttempts: failedAttempts,
        timedLockouts: current.timedLockouts,
      );
    }

    final nextTimedLockouts = current.timedLockouts + 1;
    if (nextTimedLockouts > _maxTimedLockouts) {
      await _upsert(_failedAttemptsKey, '0');
      await _upsert(_timedLockoutsKey, _maxTimedLockouts.toString());
      await _deleteKeys({_lockedUntilKey});
      await _upsert(_passwordPermanentlyLockedKey, 'true');
      return const AppCredentialLockState(
        failedAttempts: 0,
        timedLockouts: _maxTimedLockouts,
        permanentlyLocked: true,
      );
    }

    final lockoutSeconds =
        _firstLockoutSeconds * (1 << (nextTimedLockouts - 1));
    final lockedUntil = DateTime.now().add(Duration(seconds: lockoutSeconds));
    await _upsert(_failedAttemptsKey, '0');
    await _upsert(_timedLockoutsKey, nextTimedLockouts.toString());
    await _upsert(_lockedUntilKey, lockedUntil.toIso8601String());
    await _upsert(_passwordPermanentlyLockedKey, 'false');

    return AppCredentialLockState(
      failedAttempts: 0,
      timedLockouts: nextTimedLockouts,
      lockedUntil: lockedUntil,
    );
  }

  Future<Map<String, String>> _readMany(Set<String> keys) async {
    final rows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(keys.toList()))).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<String?> _read(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _upsert(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> _deleteKeys(Set<String> keys) async {
    if (keys.isEmpty) return;
    await (_db.delete(
      _db.appSettings,
    )..where((t) => t.key.isIn(keys.toList()))).go();
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  Uint8List _pbkdf2({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final hashLength = sha256.convert(const []).bytes.length;
    final blockCount = (keyLength / hashLength).ceil();
    final output = Uint8List(keyLength);
    var offset = 0;

    for (var block = 1; block <= blockCount; block++) {
      final blockInput = BytesBuilder()
        ..add(salt)
        ..add(_int32BigEndian(block));
      var u = Uint8List.fromList(hmac.convert(blockInput.toBytes()).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }

      final toCopy = (keyLength - offset).clamp(0, hashLength);
      output.setRange(offset, offset + toCopy, t);
      offset += toCopy;
    }

    return output;
  }

  List<int> _int32BigEndian(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
