import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final vaultRecoveryServiceProvider = Provider<VaultRecoveryService>((ref) {
  return VaultRecoveryService();
});

enum VaultRecoveryErrorCode {
  confirmationRequired,
  missingKey,
  invalidKey,
  checksumMismatch,
  replacementDenied,
  secureStorageFailure,
}

class VaultRecoveryException implements Exception {
  final VaultRecoveryErrorCode code;
  final String message;

  const VaultRecoveryException(this.code, this.message);

  @override
  String toString() => message;
}

abstract interface class VaultSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterVaultSecretStore implements VaultSecretStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'tele_vault_vault_recovery',
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class VaultRecoveryKeyProvider {
  Future<Uint8List> requireConfirmedKey();
}

class VaultRecoveryService implements VaultRecoveryKeyProvider {
  static const String _keyStorageKey = 'vault_recovery_key_v1';
  static const String _confirmedStorageKey = 'vault_recovery_key_confirmed_v1';
  static const String recoveryPrefix = 'TVRK1-';
  static const int keyLength = 32;
  static const int checksumLength = 4;

  final VaultSecretStore _store;
  final Uint8List Function(int length) _randomBytes;

  VaultRecoveryService({
    VaultSecretStore? store,
    Uint8List Function(int length)? randomBytes,
  }) : _store = store ?? FlutterVaultSecretStore(),
       _randomBytes = randomBytes ?? _secureRandomBytes;

  Future<bool> hasRecoveryKey() async {
    final encoded = await _safeRead(_keyStorageKey);
    return encoded != null && encoded.isNotEmpty;
  }

  Future<bool> isRecoveryKeyConfirmed() async {
    if (!await hasRecoveryKey()) return false;
    return await _safeRead(_confirmedStorageKey) == 'true';
  }

  Future<String> ensureRecoveryKey() async {
    final existing = await _safeRead(_keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return formatRecoveryKey(_decodeStoredKey(existing));
    }

    final key = _randomBytes(keyLength);
    if (key.length != keyLength) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.secureStorageFailure,
        'Unable to generate a Vault Recovery Key.',
      );
    }
    await _safeWrite(_keyStorageKey, base64UrlEncode(key));
    await _safeWrite(_confirmedStorageKey, 'false');
    return formatRecoveryKey(key);
  }

  Future<String> exportRecoveryKey() async {
    final stored = await _safeRead(_keyStorageKey);
    if (stored == null || stored.isEmpty) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.missingKey,
        'No Vault Recovery Key is configured.',
      );
    }
    return formatRecoveryKey(_decodeStoredKey(stored));
  }

  Future<void> confirmRecoveryKey(String recoveryKey) async {
    final candidate = parseRecoveryKey(recoveryKey);
    final stored = await _safeRead(_keyStorageKey);
    if (stored == null || stored.isEmpty) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.missingKey,
        'No Vault Recovery Key is configured.',
      );
    }
    final active = _decodeStoredKey(stored);
    if (!_constantTimeEquals(active, candidate)) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.invalidKey,
        'The confirmation does not match this Vault Recovery Key.',
      );
    }
    await _safeWrite(_confirmedStorageKey, 'true');
  }

  Future<void> importRecoveryKey(
    String recoveryKey, {
    bool allowReplacement = false,
  }) async {
    final candidate = parseRecoveryKey(recoveryKey);
    final existing = await _safeRead(_keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      final active = _decodeStoredKey(existing);
      final existingConfirmed = await _safeRead(_confirmedStorageKey) == 'true';
      if (!_constantTimeEquals(active, candidate) &&
          !allowReplacement &&
          existingConfirmed) {
        throw const VaultRecoveryException(
          VaultRecoveryErrorCode.replacementDenied,
          'A different recovery key is already protecting this Vault.',
        );
      }
    }
    await _safeWrite(_keyStorageKey, base64UrlEncode(candidate));
    await _safeWrite(_confirmedStorageKey, 'true');
  }

  Future<void> clearRecoveryKey() async {
    try {
      await _store.delete(_keyStorageKey);
      await _store.delete(_confirmedStorageKey);
    } catch (_) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.secureStorageFailure,
        'The Vault Recovery Key could not be removed from secure storage.',
      );
    }
  }

  @override
  Future<Uint8List> requireConfirmedKey() async {
    if (!await isRecoveryKeyConfirmed()) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.confirmationRequired,
        'Record and confirm your Vault Recovery Key before vaulting files.',
      );
    }
    final stored = await _safeRead(_keyStorageKey);
    if (stored == null || stored.isEmpty) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.missingKey,
        'The Vault Recovery Key is unavailable on this device.',
      );
    }
    return _decodeStoredKey(stored);
  }

  static String formatRecoveryKey(Uint8List key) {
    if (key.length != keyLength) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.invalidKey,
        'A Vault Recovery Key must contain 256 bits.',
      );
    }
    final checksum = _checksum(key);
    final payload = Uint8List(keyLength + checksumLength)
      ..setRange(0, keyLength, key)
      ..setRange(keyLength, keyLength + checksumLength, checksum);
    return '$recoveryPrefix${base64UrlEncode(payload).replaceAll('=', '')}';
  }

  static Uint8List parseRecoveryKey(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (!compact.startsWith(recoveryPrefix)) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.invalidKey,
        'This is not a TeleVault Recovery Key.',
      );
    }

    final encoded = compact.substring(recoveryPrefix.length);
    try {
      final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
      final payload = Uint8List.fromList(base64Url.decode(padded));
      if (payload.length != keyLength + checksumLength) {
        throw const VaultRecoveryException(
          VaultRecoveryErrorCode.invalidKey,
          'The Vault Recovery Key has an invalid length.',
        );
      }
      final key = Uint8List.fromList(payload.sublist(0, keyLength));
      final actualChecksum = payload.sublist(keyLength);
      if (!_constantTimeEquals(_checksum(key), actualChecksum)) {
        throw const VaultRecoveryException(
          VaultRecoveryErrorCode.checksumMismatch,
          'The Vault Recovery Key contains a typing error.',
        );
      }
      return key;
    } on VaultRecoveryException {
      rethrow;
    } on FormatException {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.invalidKey,
        'The Vault Recovery Key is not valid.',
      );
    }
  }

  Uint8List _decodeStoredKey(String value) {
    try {
      final bytes = Uint8List.fromList(base64Url.decode(value));
      if (bytes.length != keyLength) throw const FormatException();
      return bytes;
    } on FormatException {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.secureStorageFailure,
        'The stored Vault Recovery Key is invalid.',
      );
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _store.read(key);
    } catch (_) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.secureStorageFailure,
        'Android secure storage could not be read.',
      );
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _store.write(key, value);
    } catch (_) {
      throw const VaultRecoveryException(
        VaultRecoveryErrorCode.secureStorageFailure,
        'Android secure storage could not be updated.',
      );
    }
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _checksum(Uint8List key) {
    final input = <int>[...utf8.encode('televault-recovery-key-v1'), ...key];
    return Uint8List.fromList(
      sha256.convert(input).bytes.take(checksumLength).toList(),
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
