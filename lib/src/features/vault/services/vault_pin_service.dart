import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final vaultPinServiceProvider = Provider<VaultPinService>((ref) {
  return VaultPinService(ref.watch(databaseProvider));
});

final vaultSecurityRevisionProvider = StateProvider<int>((ref) => 0);

enum VaultPinCheckStatus { success, incorrect, locked, notSet }

enum VaultAuthMethod { pin, password, biometric }

class VaultPinCheckResult {
  final VaultPinCheckStatus status;
  final Duration? lockoutRemaining;
  final int remainingAttempts;

  const VaultPinCheckResult({
    required this.status,
    this.lockoutRemaining,
    this.remainingAttempts = 0,
  });
}

class VaultPinService {
  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _legacyPinKey = 'vault_pin';
  static const _biometricSecretKey = 'vault_biometric_secret';
  static const _authMethodKey = 'vault_auth_method';
  static const _pinHashKey = 'vault_pin_hash';
  static const _pinSaltKey = 'vault_pin_salt';
  static const _pinIterationsKey = 'vault_pin_iter';
  static const _failedAttemptsKey = 'vault_pin_failed_attempts';
  static const _lockoutUntilKey = 'vault_pin_lockout_until';
  static const _defaultIterations = 120000;
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 5);

  static const _defaultSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'tele_vault_vault_secret',
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  VaultPinService(this._db, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? _defaultSecureStorage;

  Future<bool> isPinConfigured() async {
    await migrateLegacyPinIfNeeded();
    final hash = await _getSetting(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<VaultAuthMethod> getAuthMethod() async {
    final raw = await _getSetting(_authMethodKey);
    return VaultAuthMethod.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => VaultAuthMethod.pin,
    );
  }

  Future<void> setAuthMethod(VaultAuthMethod method) async {
    await _upsert(_authMethodKey, method.name);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String localizedReason = 'Unlock your Vault',
  }) async {
    if (!await canUseBiometrics()) return false;
    try {
      return _localAuth.authenticate(
        localizedReason: localizedReason,
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

  Future<void> saveBiometricSecret(String secret) async {
    if (secret.isEmpty) {
      await clearBiometricSecret();
      return;
    }
    await _secureStorage.write(key: _biometricSecretKey, value: secret);
  }

  Future<void> clearBiometricSecret() async {
    await _secureStorage.delete(key: _biometricSecretKey);
  }

  Future<String?> readVerifiedBiometricSecret() async {
    final secret = await _secureStorage.read(key: _biometricSecretKey);
    if (secret == null || secret.isEmpty) return null;

    final matches = await _credentialMatches(secret);
    if (matches == true) return secret;

    await clearBiometricSecret();
    return null;
  }

  Future<String?> unlockSecretWithBiometric({
    String localizedReason = 'Unlock your Vault',
  }) async {
    final ok = await authenticateBiometric(localizedReason: localizedReason);
    if (!ok) return null;
    return readVerifiedBiometricSecret();
  }

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(
      password: utf8.encode(pin),
      salt: salt,
      iterations: _defaultIterations,
      keyLength: 32,
    );

    await _db.transaction(() async {
      await _upsert(_pinHashKey, base64Encode(hash));
      await _upsert(_pinSaltKey, base64Encode(salt));
      await _upsert(_pinIterationsKey, _defaultIterations.toString());
      await _upsert(_failedAttemptsKey, '0');
      await _upsert(_lockoutUntilKey, '');
      await _deleteSetting(_legacyPinKey);
    });
  }

  Future<VaultPinCheckResult> verifyPin(String pin) async {
    await migrateLegacyPinIfNeeded();

    final hashB64 = await _getSetting(_pinHashKey);
    final saltB64 = await _getSetting(_pinSaltKey);
    final iterValue = await _getSetting(_pinIterationsKey);
    if (hashB64 == null || saltB64 == null || iterValue == null) {
      return const VaultPinCheckResult(status: VaultPinCheckStatus.notSet);
    }

    final lockoutUntilIso = await _getSetting(_lockoutUntilKey);
    if (lockoutUntilIso != null && lockoutUntilIso.isNotEmpty) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilIso);
      if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
        return VaultPinCheckResult(
          status: VaultPinCheckStatus.locked,
          lockoutRemaining: lockoutUntil.difference(DateTime.now()),
        );
      }
    }

    if (await _credentialMatches(
          pin,
          hashB64: hashB64,
          saltB64: saltB64,
          iterValue: iterValue,
        ) ==
        true) {
      await _upsert(_failedAttemptsKey, '0');
      await _upsert(_lockoutUntilKey, '');
      return const VaultPinCheckResult(status: VaultPinCheckStatus.success);
    }

    final attempts =
        (int.tryParse(await _getSetting(_failedAttemptsKey) ?? '0') ?? 0) + 1;
    if (attempts >= _maxAttempts) {
      final until = DateTime.now().add(_lockoutDuration).toIso8601String();
      await _upsert(_failedAttemptsKey, '0');
      await _upsert(_lockoutUntilKey, until);
      return const VaultPinCheckResult(
        status: VaultPinCheckStatus.locked,
        lockoutRemaining: _lockoutDuration,
      );
    }

    await _upsert(_failedAttemptsKey, attempts.toString());
    return VaultPinCheckResult(
      status: VaultPinCheckStatus.incorrect,
      remainingAttempts: _maxAttempts - attempts,
    );
  }

  Future<void> migrateLegacyPinIfNeeded() async {
    final hash = await _getSetting(_pinHashKey);
    if (hash != null && hash.isNotEmpty) return;

    final legacy = await _getSetting(_legacyPinKey);
    if (legacy == null || legacy.isEmpty) return;
    await setPin(legacy);
  }

  Future<bool?> _credentialMatches(
    String pin, {
    String? hashB64,
    String? saltB64,
    String? iterValue,
  }) async {
    await migrateLegacyPinIfNeeded();

    final storedHashB64 = hashB64 ?? await _getSetting(_pinHashKey);
    final storedSaltB64 = saltB64 ?? await _getSetting(_pinSaltKey);
    final storedIterValue = iterValue ?? await _getSetting(_pinIterationsKey);
    if (storedHashB64 == null ||
        storedSaltB64 == null ||
        storedIterValue == null) {
      return null;
    }

    final iterations = int.tryParse(storedIterValue) ?? _defaultIterations;
    final expectedHash = base64Decode(storedHashB64);
    final salt = base64Decode(storedSaltB64);
    final actualHash = _pbkdf2(
      password: utf8.encode(pin),
      salt: Uint8List.fromList(salt),
      iterations: iterations,
      keyLength: expectedHash.length,
    );

    return _constantTimeEquals(expectedHash, actualHash);
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

  Future<String?> _getSetting(String key) async {
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

  Future<void> _deleteSetting(String key) async {
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
  }
}
