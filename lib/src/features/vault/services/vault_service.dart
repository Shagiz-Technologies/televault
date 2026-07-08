import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

class VaultEncryptionResult {
  final String path;
  final String ivB64;
  final int version;

  const VaultEncryptionResult({
    required this.path,
    required this.ivB64,
    required this.version,
  });
}

class VaultService {
  static const int _versionV2 = 2;
  static const int _iterations = 120000;
  static const int _saltLength = 16;
  static const int _ivLength = 12;

  Future<VaultEncryptionResult> encryptFile(File file, String pin) async {
    final salt = Uint8List.fromList(enc.IV.fromSecureRandom(_saltLength).bytes);
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final key = _deriveKey(pin, salt);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final bytes = await file.readAsBytes();
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final combined = BytesBuilder()
      ..addByte(_versionV2)
      ..add(salt)
      ..add(iv.bytes)
      ..add(encrypted.bytes);

    final dir = await getApplicationDocumentsDirectory();
    final filename = '${path.basename(file.path)}.enc';
    final destPath = path.join(dir.path, 'vault', filename);
    final destFile = File(destPath);
    await destFile.create(recursive: true);
    await destFile.writeAsBytes(combined.toBytes(), flush: true);

    return VaultEncryptionResult(
      path: destPath,
      ivB64: base64Encode(iv.bytes),
      version: _versionV2,
    );
  }

  Future<File> decryptFile(File encryptedFile, String pin) async {
    final bytes = await encryptedFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('Encrypted file is empty');
    }

    Uint8List ivBytes;
    Uint8List cipherBytes;
    Uint8List? salt;
    var useLegacySha = false;

    final version = bytes.first;
    if (version == _versionV2 && bytes.length > (1 + _saltLength + _ivLength)) {
      salt = Uint8List.fromList(bytes.sublist(1, 1 + _saltLength));
      ivBytes = Uint8List.fromList(
        bytes.sublist(1 + _saltLength, 1 + _saltLength + _ivLength),
      );
      cipherBytes = Uint8List.fromList(
        bytes.sublist(1 + _saltLength + _ivLength),
      );
    } else {
      if (bytes.length <= _ivLength) {
        throw Exception('Encrypted payload is invalid');
      }
      useLegacySha = true;
      ivBytes = Uint8List.fromList(bytes.sublist(0, _ivLength));
      cipherBytes = Uint8List.fromList(bytes.sublist(_ivLength));
    }

    final key = useLegacySha
        ? _legacyKey(pin)
        : _deriveKey(pin, salt ?? Uint8List(0));
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decryptedBytes = encrypter.decryptBytes(
      enc.Encrypted(cipherBytes),
      iv: iv,
    );

    final tempDir = await getTemporaryDirectory();
    final basename = path.basename(encryptedFile.path).replaceAll('.enc', '');
    final tempFile = File(path.join(tempDir.path, basename));
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    return tempFile;
  }

  enc.Key _deriveKey(String pin, Uint8List salt) {
    final keyBytes = _pbkdf2(
      password: utf8.encode(pin),
      salt: salt,
      iterations: _iterations,
      keyLength: 32,
    );
    return enc.Key(keyBytes);
  }

  enc.Key _legacyKey(String pin) {
    final digest = sha256.convert(utf8.encode(pin));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  Uint8List _pbkdf2({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final hashLength = sha256.convert(const []).bytes.length;
    final blocks = (keyLength / hashLength).ceil();
    final output = Uint8List(keyLength);
    var offset = 0;

    for (var block = 1; block <= blocks; block++) {
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

      final copyLength = (keyLength - offset).clamp(0, hashLength);
      output.setRange(offset, offset + copyLength, t);
      offset += copyLength;
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
}
