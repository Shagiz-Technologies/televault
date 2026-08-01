import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'vault_recovery_service.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(
    recoveryKeyProvider: ref.watch(vaultRecoveryServiceProvider),
  );
});

enum VaultErrorCode {
  sourceMissing,
  sourceChanged,
  destinationExists,
  invalidContainer,
  unsupportedVersion,
  integrityFailure,
  wrongRecoveryKey,
  truncatedContainer,
  insufficientStorage,
  temporaryFileFailure,
}

class VaultException implements Exception {
  final VaultErrorCode code;
  final String message;
  final Object? cause;

  const VaultException(this.code, this.message, {this.cause});

  @override
  String toString() => message;
}

class VaultEncryptionResult {
  final String path;
  final String objectId;
  final String ivB64;
  final int version;
  final int encryptedSize;
  final int originalSize;
  final int keyWrappingVersion;

  const VaultEncryptionResult({
    required this.path,
    required this.objectId,
    required this.ivB64,
    required this.version,
    required this.encryptedSize,
    required this.originalSize,
    required this.keyWrappingVersion,
  });
}

class VaultPrivateMetadata {
  final String displayName;
  final String mimeType;

  const VaultPrivateMetadata({
    required this.displayName,
    required this.mimeType,
  });
}

typedef VaultDirectoryProvider = Future<Directory> Function();
typedef VaultObjectIdFactory = String Function();
typedef VaultRandomBytes = Uint8List Function(int length);

class VaultService {
  static const int currentVersion = 3;
  static const int keyWrappingVersion = 1;
  static const int defaultChunkSize = 2 * 1024 * 1024;
  static const int minimumChunkSize = 64 * 1024;
  static const int maximumChunkSize = 4 * 1024 * 1024;
  static const int _legacyVersionV2 = 2;
  static const int _legacyIterations = 120000;
  static const int _saltLength = 32;
  static const int _legacySaltLength = 16;
  static const int _nonceLength = 12;
  static const int _noncePrefixLength = 8;
  static const int _tagLength = 16;
  static const int _maximumHeaderLength = 64 * 1024;
  static const int _metadataNonceIndex = 0xffffffff;
  static const String _cipherId = 'AES-256-GCM';
  static const String _kdfId = 'HKDF-HMAC-SHA256';
  static const String _keyWrapId = 'AES-256-GCM';
  static final Uint8List _magic = Uint8List.fromList(ascii.encode('TVLT0003'));
  static const List<String> _headerKeys = [
    'version',
    'cipher',
    'kdf',
    'keyWrap',
    'keyWrappingVersion',
    'chunkSize',
    'originalLength',
    'chunkCount',
    'objectId',
    'salt',
    'noncePrefix',
    'wrapNonce',
    'wrappedKey',
    'wrappedKeyTag',
    'metadataCiphertext',
    'metadataTag',
  ];

  final VaultRecoveryKeyProvider _recoveryKeyProvider;
  final VaultDirectoryProvider _vaultDirectoryProvider;
  final VaultDirectoryProvider _temporaryDirectoryProvider;
  final VaultObjectIdFactory _objectIdFactory;
  final VaultRandomBytes _randomBytes;
  final AesGcm _aesGcm;
  final Hkdf _hkdf;
  final int chunkSize;

  VaultService({
    required VaultRecoveryKeyProvider recoveryKeyProvider,
    VaultDirectoryProvider? vaultDirectoryProvider,
    VaultDirectoryProvider? temporaryDirectoryProvider,
    VaultObjectIdFactory? objectIdFactory,
    VaultRandomBytes? randomBytes,
    AesGcm? aesGcm,
    Hkdf? hkdf,
    this.chunkSize = defaultChunkSize,
  }) : _recoveryKeyProvider = recoveryKeyProvider,
       _vaultDirectoryProvider =
           vaultDirectoryProvider ?? _defaultVaultDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? _defaultTemporaryDirectory,
       _objectIdFactory = objectIdFactory ?? const Uuid().v4,
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _aesGcm = aesGcm ?? AesGcm.with256bits(),
       _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32) {
    if (chunkSize < minimumChunkSize || chunkSize > maximumChunkSize) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'must be between 64 KiB and 4 MiB',
      );
    }
  }

  String newObjectId() => _objectIdFactory();

  Future<File> destinationForObjectId(String objectId) async {
    _validateObjectId(objectId);
    final directory = await _vaultDirectoryProvider();
    return File(path.join(directory.path, '$objectId.tvv3'));
  }

  Future<VaultEncryptionResult> encryptFile(
    File source, {
    String? mimeType,
    String? objectId,
  }) async {
    if (!await source.exists()) {
      throw const VaultException(
        VaultErrorCode.sourceMissing,
        'The source file is no longer available.',
      );
    }

    final recoveryKey = await _recoveryKeyProvider.requireConfirmedKey();
    final sourceStat = await source.stat();
    final originalLength = sourceStat.size;
    final resolvedObjectId = objectId ?? newObjectId();
    _validateObjectId(resolvedObjectId);
    final destination = await destinationForObjectId(resolvedObjectId);
    if (await destination.exists()) {
      throw const VaultException(
        VaultErrorCode.destinationExists,
        'The generated vault destination already exists.',
      );
    }

    final directory = destination.parent;
    await directory.create(recursive: true);
    final partial = File('${destination.path}.partial-${_objectIdFactory()}');
    if (await partial.exists()) {
      throw const VaultException(
        VaultErrorCode.destinationExists,
        'A temporary vault destination already exists.',
      );
    }

    RandomAccessFile? input;
    RandomAccessFile? output;
    try {
      final salt = _requireRandomBytes(_saltLength);
      final noncePrefix = _requireRandomBytes(_noncePrefixLength);
      final wrapNonce = _requireRandomBytes(_nonceLength);
      final dataKeyBytes = _requireRandomBytes(32);
      final dataKey = SecretKey(dataKeyBytes);
      final wrappingKey = await _deriveWrappingKey(recoveryKey, salt);
      final chunkCount = originalLength == 0
          ? 0
          : (originalLength + chunkSize - 1) ~/ chunkSize;
      if (chunkCount >= _metadataNonceIndex) {
        throw const VaultException(
          VaultErrorCode.invalidContainer,
          'The source file exceeds the v3 container chunk limit.',
        );
      }

      final context = _buildPublicContext(
        chunkSize: chunkSize,
        originalLength: originalLength,
        chunkCount: chunkCount,
        objectId: resolvedObjectId,
        salt: salt,
        noncePrefix: noncePrefix,
      );
      final contextBytes = _encodeJson(context);
      final wrapAad = _join([_magic, contextBytes]);
      final wrappedKey = await _aesGcm.encrypt(
        dataKeyBytes,
        secretKey: wrappingKey,
        nonce: wrapNonce,
        aad: wrapAad,
      );

      final metadataAad = _join([
        wrapAad,
        wrapNonce,
        wrappedKey.cipherText,
        wrappedKey.mac.bytes,
      ]);
      final privateMetadata = _encodeJson({
        'displayName': path.basename(source.path),
        'mimeType': mimeType ?? _mimeTypeForPath(source.path),
      });
      final metadataBox = await _aesGcm.encrypt(
        privateMetadata,
        secretKey: dataKey,
        nonce: _nonceForIndex(noncePrefix, _metadataNonceIndex),
        aad: metadataAad,
      );

      final header = LinkedHashMap<String, Object?>.from(context)
        ..['wrapNonce'] = base64Encode(wrapNonce)
        ..['wrappedKey'] = base64Encode(wrappedKey.cipherText)
        ..['wrappedKeyTag'] = base64Encode(wrappedKey.mac.bytes)
        ..['metadataCiphertext'] = base64Encode(metadataBox.cipherText)
        ..['metadataTag'] = base64Encode(metadataBox.mac.bytes);
      final headerBytes = _encodeJson(header);
      if (headerBytes.length > _maximumHeaderLength) {
        throw const VaultException(
          VaultErrorCode.invalidContainer,
          'The vault header exceeds the supported size.',
        );
      }

      input = await source.open(mode: FileMode.read);
      output = await partial.open(mode: FileMode.writeOnly);
      await output.writeFrom(_magic);
      await output.writeFrom(_uint32(headerBytes.length));
      await output.writeFrom(headerBytes);

      var totalRead = 0;
      for (var index = 0; index < chunkCount; index++) {
        final expectedLength = min(chunkSize, originalLength - totalRead);
        final plaintext = await input.read(expectedLength);
        if (plaintext.length != expectedLength) {
          throw const VaultException(
            VaultErrorCode.sourceChanged,
            'The source file changed while it was being encrypted.',
          );
        }
        final aad = _chunkAad(headerBytes, index, expectedLength);
        final secretBox = await _aesGcm.encrypt(
          plaintext,
          secretKey: dataKey,
          nonce: _nonceForIndex(noncePrefix, index),
          aad: aad,
        );
        await output.writeFrom(_uint32(index));
        await output.writeFrom(_uint32(expectedLength));
        await output.writeFrom(_uint32(secretBox.cipherText.length));
        await output.writeFrom(secretBox.cipherText);
        await output.writeFrom(secretBox.mac.bytes);
        totalRead += expectedLength;
      }

      if ((await input.read(1)).isNotEmpty ||
          !await source.exists() ||
          (await source.stat()).size != originalLength) {
        throw const VaultException(
          VaultErrorCode.sourceChanged,
          'The source file changed while it was being encrypted.',
        );
      }

      await output.flush();
      await output.close();
      output = null;
      await input.close();
      input = null;
      if (await destination.exists()) {
        throw const VaultException(
          VaultErrorCode.destinationExists,
          'The vault destination appeared during encryption.',
        );
      }
      final committed = await partial.rename(destination.path);
      final encryptedSize = await committed.length();
      return VaultEncryptionResult(
        path: committed.path,
        objectId: resolvedObjectId,
        ivB64: base64Encode(noncePrefix),
        version: currentVersion,
        encryptedSize: encryptedSize,
        originalSize: originalLength,
        keyWrappingVersion: keyWrappingVersion,
      );
    } on VaultException {
      rethrow;
    } on FileSystemException catch (error) {
      throw _translateFileError(error);
    } finally {
      await input?.close();
      await output?.close();
      if (await partial.exists()) {
        await partial.delete();
      }
    }
  }

  Future<File> decryptFile(File encryptedFile, [String? legacySecret]) async {
    final format = await detectFormatVersion(encryptedFile);
    if (format == currentVersion) {
      return _decryptV3(encryptedFile);
    }
    if (legacySecret == null || legacySecret.isEmpty) {
      throw const VaultException(
        VaultErrorCode.wrongRecoveryKey,
        'The legacy Vault credential is required for this file.',
      );
    }
    return _decryptLegacy(
      encryptedFile,
      legacySecret,
      // Legacy v1 has no version marker, so its random IV can begin with the
      // v2 marker. Authenticated fallback resolves that ambiguity safely.
      formatVersion: format == 1 ? 1 : null,
    );
  }

  Future<File> decryptLegacyFile(
    File encryptedFile,
    String legacySecret, {
    required int formatVersion,
  }) {
    if (formatVersion != 1 && formatVersion != _legacyVersionV2) {
      throw const VaultException(
        VaultErrorCode.unsupportedVersion,
        'The legacy vault format version is unsupported.',
      );
    }
    if (legacySecret.isEmpty) {
      throw const VaultException(
        VaultErrorCode.wrongRecoveryKey,
        'The legacy Vault credential is required for this file.',
      );
    }
    return _decryptLegacy(
      encryptedFile,
      legacySecret,
      formatVersion: formatVersion,
    );
  }

  Future<int> detectFormatVersion(File encryptedFile) async {
    if (!await encryptedFile.exists()) {
      throw const VaultException(
        VaultErrorCode.sourceMissing,
        'The encrypted vault file is unavailable.',
      );
    }
    final input = await encryptedFile.open(mode: FileMode.read);
    try {
      final prefix = await input.read(_magic.length);
      if (_constantTimeEquals(prefix, _magic)) return currentVersion;
      if (prefix.isNotEmpty && prefix.first == _legacyVersionV2) return 2;
      return 1;
    } finally {
      await input.close();
    }
  }

  Future<DateTime> verifyFile(
    File encryptedFile, {
    File? expectedPlaintext,
    String? legacySecret,
  }) async {
    final decrypted = await decryptFile(encryptedFile, legacySecret);
    try {
      if (expectedPlaintext != null) {
        if (await decrypted.length() != await expectedPlaintext.length()) {
          throw const VaultException(
            VaultErrorCode.integrityFailure,
            'The verified plaintext length does not match the source.',
          );
        }
        final digests = await Future.wait([
          hashes.sha256.bind(decrypted.openRead()).first,
          hashes.sha256.bind(expectedPlaintext.openRead()).first,
        ]);
        if (!_constantTimeEquals(digests[0].bytes, digests[1].bytes)) {
          throw const VaultException(
            VaultErrorCode.integrityFailure,
            'The verified plaintext does not match the source.',
          );
        }
      }
      return DateTime.now().toUtc();
    } finally {
      await deleteTemporaryPlaintext(decrypted);
    }
  }

  Future<void> deleteTemporaryPlaintext(File file) async {
    final root = await _temporaryDirectoryProvider();
    final normalizedRoot = path.normalize(path.absolute(root.path));
    final normalizedFile = path.normalize(path.absolute(file.path));
    if (!path.isWithin(normalizedRoot, normalizedFile)) return;
    if (await file.exists()) await file.delete();
  }

  Future<void> cleanupStaleTemporaryFiles() async {
    final tempDirectory = await _temporaryDirectoryProvider();
    if (await tempDirectory.exists()) {
      await for (final entity in tempDirectory.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }

    final vaultDirectory = await _vaultDirectoryProvider();
    if (!await vaultDirectory.exists()) return;
    await for (final entity in vaultDirectory.list(followLinks: false)) {
      if (entity is File && path.basename(entity.path).contains('.partial-')) {
        await entity.delete();
      }
    }
  }

  Future<void> deleteAllLocalVaultFiles() async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
    final vaultDirectory = await _vaultDirectoryProvider();
    if (await vaultDirectory.exists()) {
      await vaultDirectory.delete(recursive: true);
    }
  }

  static Future<void> cleanupDefaultTemporaryFiles() async {
    final service = VaultService(
      recoveryKeyProvider: _UnavailableRecoveryKeyProvider(),
    );
    await service.cleanupStaleTemporaryFiles();
  }

  Future<File> _decryptV3(File encryptedFile) async {
    final recoveryKey = await _recoveryKeyProvider.requireConfirmedKey();
    RandomAccessFile? input;
    RandomAccessFile? output;
    File? partial;
    try {
      input = await encryptedFile.open(mode: FileMode.read);
      final magic = await _readExact(input, _magic.length);
      if (!_constantTimeEquals(magic, _magic)) {
        throw const VaultException(
          VaultErrorCode.invalidContainer,
          'The file is not a TeleVault v3 container.',
        );
      }
      final headerLength = _readUint32(await _readExact(input, 4));
      if (headerLength <= 0 || headerLength > _maximumHeaderLength) {
        throw const VaultException(
          VaultErrorCode.invalidContainer,
          'The vault header length is invalid.',
        );
      }
      final headerBytes = await _readExact(input, headerLength);
      final parsed = _parseHeader(headerBytes);
      final wrappingKey = await _deriveWrappingKey(recoveryKey, parsed.salt);
      final contextBytes = _encodeJson(parsed.publicContext);
      final wrapAad = _join([_magic, contextBytes]);

      late final List<int> dataKeyBytes;
      try {
        dataKeyBytes = await _aesGcm.decrypt(
          SecretBox(
            parsed.wrappedKey,
            nonce: parsed.wrapNonce,
            mac: Mac(parsed.wrappedKeyTag),
          ),
          secretKey: wrappingKey,
          aad: wrapAad,
        );
      } on SecretBoxAuthenticationError catch (error) {
        throw VaultException(
          VaultErrorCode.wrongRecoveryKey,
          'The recovery key cannot unlock this vault object.',
          cause: error,
        );
      }
      if (dataKeyBytes.length != 32) {
        throw const VaultException(
          VaultErrorCode.integrityFailure,
          'The wrapped data key has an invalid length.',
        );
      }
      final dataKey = SecretKey(dataKeyBytes);
      final metadataAad = _join([
        wrapAad,
        parsed.wrapNonce,
        parsed.wrappedKey,
        parsed.wrappedKeyTag,
      ]);

      late final List<int> metadataBytes;
      try {
        metadataBytes = await _aesGcm.decrypt(
          SecretBox(
            parsed.metadataCiphertext,
            nonce: _nonceForIndex(parsed.noncePrefix, _metadataNonceIndex),
            mac: Mac(parsed.metadataTag),
          ),
          secretKey: dataKey,
          aad: metadataAad,
        );
      } on SecretBoxAuthenticationError catch (error) {
        throw VaultException(
          VaultErrorCode.integrityFailure,
          'Vault metadata authentication failed.',
          cause: error,
        );
      }
      final metadata = _parsePrivateMetadata(metadataBytes);
      final tempDirectory = await _temporaryDirectoryProvider();
      await tempDirectory.create(recursive: true);
      final extension = _safeExtension(metadata.displayName);
      final destination = File(
        path.join(tempDirectory.path, '${_objectIdFactory()}$extension'),
      );
      if (await destination.exists()) {
        throw const VaultException(
          VaultErrorCode.destinationExists,
          'The temporary plaintext destination already exists.',
        );
      }
      partial = File('${destination.path}.partial-${_objectIdFactory()}');
      output = await partial.open(mode: FileMode.writeOnly);

      var totalWritten = 0;
      for (
        var expectedIndex = 0;
        expectedIndex < parsed.chunkCount;
        expectedIndex++
      ) {
        final recordHeader = await _readExact(input, 12);
        final index = _readUint32(recordHeader, 0);
        final plaintextLength = _readUint32(recordHeader, 4);
        final ciphertextLength = _readUint32(recordHeader, 8);
        final expectedLength = min(
          parsed.chunkSize,
          parsed.originalLength - totalWritten,
        );
        if (index != expectedIndex ||
            plaintextLength != expectedLength ||
            ciphertextLength != plaintextLength) {
          throw const VaultException(
            VaultErrorCode.integrityFailure,
            'Vault chunk order or length is invalid.',
          );
        }
        final ciphertext = await _readExact(input, ciphertextLength);
        final tag = await _readExact(input, _tagLength);
        late final List<int> plaintext;
        try {
          plaintext = await _aesGcm.decrypt(
            SecretBox(
              ciphertext,
              nonce: _nonceForIndex(parsed.noncePrefix, index),
              mac: Mac(tag),
            ),
            secretKey: dataKey,
            aad: _chunkAad(headerBytes, index, plaintextLength),
          );
        } on SecretBoxAuthenticationError catch (error) {
          throw VaultException(
            VaultErrorCode.integrityFailure,
            'Vault chunk authentication failed.',
            cause: error,
          );
        }
        if (plaintext.length != plaintextLength) {
          throw const VaultException(
            VaultErrorCode.integrityFailure,
            'A decrypted vault chunk has an invalid length.',
          );
        }
        await output.writeFrom(plaintext);
        totalWritten += plaintext.length;
      }

      if (totalWritten != parsed.originalLength ||
          (await input.read(1)).isNotEmpty) {
        throw const VaultException(
          VaultErrorCode.integrityFailure,
          'The vault container has missing or unexpected data.',
        );
      }

      await output.flush();
      await output.close();
      output = null;
      await input.close();
      input = null;
      if (await destination.exists()) {
        throw const VaultException(
          VaultErrorCode.destinationExists,
          'The temporary plaintext destination appeared during decryption.',
        );
      }
      final completed = await partial.rename(destination.path);
      partial = null;
      return completed;
    } on VaultException {
      rethrow;
    } on FileSystemException catch (error) {
      throw _translateFileError(error);
    } on FormatException catch (error) {
      throw VaultException(
        VaultErrorCode.invalidContainer,
        'The vault container metadata is invalid.',
        cause: error,
      );
    } finally {
      await input?.close();
      await output?.close();
      if (partial != null && await partial.exists()) {
        await partial.delete();
      }
    }
  }

  // Legacy v1/v2 is deliberately read-only. New writes never use this path.
  Future<File> _decryptLegacy(
    File encryptedFile,
    String secret, {
    int? formatVersion,
  }) async {
    final bytes = await encryptedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const VaultException(
        VaultErrorCode.truncatedContainer,
        'The legacy vault object is empty.',
      );
    }

    final candidateVersions = formatVersion != null
        ? <int>[formatVersion]
        : bytes.first == _legacyVersionV2
        ? <int>[_legacyVersionV2, 1]
        : <int>[1];
    Uint8List? plaintext;
    Object? authenticationError;
    for (final candidateVersion in candidateVersions) {
      try {
        plaintext = _decryptLegacyBytes(
          bytes,
          secret,
          formatVersion: candidateVersion,
        );
        break;
      } catch (error) {
        authenticationError = error;
      }
    }
    if (plaintext == null) {
      throw VaultException(
        VaultErrorCode.integrityFailure,
        'The legacy vault object could not be authenticated.',
        cause: authenticationError,
      );
    }

    final directory = await _temporaryDirectoryProvider();
    await directory.create(recursive: true);
    final originalName = path
        .basename(encryptedFile.path)
        .replaceAll(RegExp(r'\.enc$'), '');
    final extension = _safeExtension(originalName);
    final destination = File(
      path.join(directory.path, '${_objectIdFactory()}$extension'),
    );
    final partial = File('${destination.path}.partial-${_objectIdFactory()}');
    try {
      await partial.writeAsBytes(plaintext, flush: true);
      return await partial.rename(destination.path);
    } on FileSystemException catch (error) {
      throw _translateFileError(error);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Uint8List _decryptLegacyBytes(
    Uint8List bytes,
    String secret, {
    required int formatVersion,
  }) {
    late final Uint8List ivBytes;
    late final Uint8List cipherBytes;
    late final legacy.Key key;
    if (formatVersion == _legacyVersionV2) {
      if (bytes.first != _legacyVersionV2 ||
          bytes.length <= (1 + _legacySaltLength + _nonceLength)) {
        throw const VaultException(
          VaultErrorCode.truncatedContainer,
          'The legacy v2 vault object is truncated.',
        );
      }
      final salt = Uint8List.fromList(bytes.sublist(1, 1 + _legacySaltLength));
      ivBytes = Uint8List.fromList(
        bytes.sublist(
          1 + _legacySaltLength,
          1 + _legacySaltLength + _nonceLength,
        ),
      );
      cipherBytes = Uint8List.fromList(
        bytes.sublist(1 + _legacySaltLength + _nonceLength),
      );
      key = _legacyPbkdf2Key(secret, salt);
    } else {
      if (bytes.length <= _nonceLength) {
        throw const VaultException(
          VaultErrorCode.truncatedContainer,
          'The legacy v1 vault object is truncated.',
        );
      }
      ivBytes = Uint8List.fromList(bytes.sublist(0, _nonceLength));
      cipherBytes = Uint8List.fromList(bytes.sublist(_nonceLength));
      key = _legacyShaKey(secret);
    }
    final encrypter = legacy.Encrypter(
      legacy.AES(key, mode: legacy.AESMode.gcm),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(
        legacy.Encrypted(cipherBytes),
        iv: legacy.IV(ivBytes),
      ),
    );
  }

  LinkedHashMap<String, Object?> _buildPublicContext({
    required int chunkSize,
    required int originalLength,
    required int chunkCount,
    required String objectId,
    required Uint8List salt,
    required Uint8List noncePrefix,
  }) {
    return LinkedHashMap<String, Object?>()
      ..['version'] = currentVersion
      ..['cipher'] = _cipherId
      ..['kdf'] = _kdfId
      ..['keyWrap'] = _keyWrapId
      ..['keyWrappingVersion'] = keyWrappingVersion
      ..['chunkSize'] = chunkSize
      ..['originalLength'] = originalLength
      ..['chunkCount'] = chunkCount
      ..['objectId'] = objectId
      ..['salt'] = base64Encode(salt)
      ..['noncePrefix'] = base64Encode(noncePrefix);
  }

  _ParsedHeader _parseHeader(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded.length != _headerKeys.length ||
        !const ListEquality<String>().equals(
          decoded.keys.toList(),
          _headerKeys,
        )) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault header schema is not supported.',
      );
    }
    if (decoded['version'] != currentVersion ||
        decoded['cipher'] != _cipherId ||
        decoded['kdf'] != _kdfId ||
        decoded['keyWrap'] != _keyWrapId ||
        decoded['keyWrappingVersion'] != keyWrappingVersion) {
      throw const VaultException(
        VaultErrorCode.unsupportedVersion,
        'This vault encryption format is not supported.',
      );
    }

    final parsedChunkSize = _requireInt(decoded, 'chunkSize');
    final originalLength = _requireInt(decoded, 'originalLength');
    final chunkCount = _requireInt(decoded, 'chunkCount');
    if (parsedChunkSize < minimumChunkSize ||
        parsedChunkSize > maximumChunkSize ||
        originalLength < 0 ||
        chunkCount < 0 ||
        chunkCount >= _metadataNonceIndex ||
        chunkCount !=
            (originalLength == 0
                ? 0
                : (originalLength + parsedChunkSize - 1) ~/ parsedChunkSize)) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault chunk parameters are invalid.',
      );
    }
    final objectId = decoded['objectId'];
    if (objectId is! String) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault object identifier is invalid.',
      );
    }
    _validateObjectId(objectId);
    final salt = _decodeFixed(decoded, 'salt', _saltLength);
    final noncePrefix = _decodeFixed(
      decoded,
      'noncePrefix',
      _noncePrefixLength,
    );
    final wrapNonce = _decodeFixed(decoded, 'wrapNonce', _nonceLength);
    final wrappedKey = _decodeFixed(decoded, 'wrappedKey', 32);
    final wrappedKeyTag = _decodeFixed(decoded, 'wrappedKeyTag', _tagLength);
    final metadataCiphertext = _decodeBounded(
      decoded,
      'metadataCiphertext',
      maximumLength: 16 * 1024,
    );
    final metadataTag = _decodeFixed(decoded, 'metadataTag', _tagLength);

    return _ParsedHeader(
      publicContext: _buildPublicContext(
        chunkSize: parsedChunkSize,
        originalLength: originalLength,
        chunkCount: chunkCount,
        objectId: objectId,
        salt: salt,
        noncePrefix: noncePrefix,
      ),
      chunkSize: parsedChunkSize,
      originalLength: originalLength,
      chunkCount: chunkCount,
      salt: salt,
      noncePrefix: noncePrefix,
      wrapNonce: wrapNonce,
      wrappedKey: wrappedKey,
      wrappedKeyTag: wrappedKeyTag,
      metadataCiphertext: metadataCiphertext,
      metadataTag: metadataTag,
    );
  }

  VaultPrivateMetadata _parsePrivateMetadata(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['displayName'] is! String ||
        decoded['mimeType'] is! String) {
      throw const VaultException(
        VaultErrorCode.integrityFailure,
        'The authenticated vault metadata is invalid.',
      );
    }
    final displayName = decoded['displayName'] as String;
    final mimeType = decoded['mimeType'] as String;
    if (displayName.isEmpty ||
        displayName.length > 1024 ||
        mimeType.length > 255) {
      throw const VaultException(
        VaultErrorCode.integrityFailure,
        'The authenticated vault metadata is outside supported limits.',
      );
    }
    return VaultPrivateMetadata(displayName: displayName, mimeType: mimeType);
  }

  Future<SecretKey> _deriveWrappingKey(
    Uint8List recoveryKey,
    Uint8List salt,
  ) async {
    if (recoveryKey.length != 32) {
      throw const VaultException(
        VaultErrorCode.wrongRecoveryKey,
        'The Vault Recovery Key has an invalid length.',
      );
    }
    return _hkdf.deriveKey(
      secretKey: SecretKey(recoveryKey),
      nonce: salt,
      info: utf8.encode('televault-v3-file-key-wrap'),
    );
  }

  Uint8List _chunkAad(List<int> header, int index, int plaintextLength) {
    return _join([_magic, header, _uint32(index), _uint32(plaintextLength)]);
  }

  static Uint8List _nonceForIndex(Uint8List prefix, int index) {
    if (prefix.length != _noncePrefixLength ||
        index < 0 ||
        index > 0xffffffff) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault nonce parameters are invalid.',
      );
    }
    return Uint8List(_nonceLength)
      ..setRange(0, _noncePrefixLength, prefix)
      ..setRange(_noncePrefixLength, _nonceLength, _uint32(index));
  }

  static Uint8List _encodeJson(Map<String, Object?> value) {
    return Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }

  static Uint8List _join(List<List<int>> parts) {
    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      builder.add(part);
    }
    return builder.takeBytes();
  }

  static Uint8List _uint32(int value) {
    if (value < 0 || value > 0xffffffff) {
      throw RangeError.range(value, 0, 0xffffffff);
    }
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static int _readUint32(List<int> value, [int offset = 0]) {
    if (offset < 0 || value.length < offset + 4) {
      throw const VaultException(
        VaultErrorCode.truncatedContainer,
        'The vault container is truncated.',
      );
    }
    return ByteData.sublistView(
      Uint8List.fromList(value),
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);
  }

  static Future<Uint8List> _readExact(
    RandomAccessFile input,
    int length,
  ) async {
    final output = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final chunk = await input.read(length - offset);
      if (chunk.isEmpty) {
        throw const VaultException(
          VaultErrorCode.truncatedContainer,
          'The vault container is truncated.',
        );
      }
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return output;
  }

  static int _requireInt(Map<String, dynamic> value, String key) {
    final item = value[key];
    if (item is! int) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault header contains an invalid integer.',
      );
    }
    return item;
  }

  static Uint8List _decodeFixed(
    Map<String, dynamic> value,
    String key,
    int length,
  ) {
    final result = _decodeBounded(value, key, maximumLength: length);
    if (result.length != length) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault header contains invalid binary metadata.',
      );
    }
    return result;
  }

  static Uint8List _decodeBounded(
    Map<String, dynamic> value,
    String key, {
    required int maximumLength,
  }) {
    final encoded = value[key];
    if (encoded is! String || encoded.length > maximumLength * 2) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault header contains invalid binary metadata.',
      );
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(encoded));
      if (bytes.length > maximumLength) throw const FormatException();
      return bytes;
    } on FormatException {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault header contains invalid binary metadata.',
      );
    }
  }

  Uint8List _requireRandomBytes(int length) {
    final value = _randomBytes(length);
    if (value.length != length) {
      throw StateError('Secure random source returned an invalid length.');
    }
    return value;
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static void _validateObjectId(String objectId) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(objectId)) {
      throw const VaultException(
        VaultErrorCode.invalidContainer,
        'The vault object identifier is invalid.',
      );
    }
  }

  static String _safeExtension(String displayName) {
    final extension = path.extension(displayName).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)) return extension;
    return '.bin';
  }

  static String _mimeTypeForPath(String value) {
    return switch (path.extension(value).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.heic' || '.heif' => 'image/heic',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.mkv' => 'video/x-matroska',
      _ => 'application/octet-stream',
    };
  }

  static VaultException _translateFileError(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 28 || code == 112) {
      return VaultException(
        VaultErrorCode.insufficientStorage,
        'There is not enough private storage to complete this vault operation.',
        cause: error,
      );
    }
    return VaultException(
      VaultErrorCode.temporaryFileFailure,
      'Private vault storage could not complete the operation.',
      cause: error,
    );
  }

  legacy.Key _legacyPbkdf2Key(String secret, Uint8List salt) {
    final keyBytes = _legacyPbkdf2(
      password: utf8.encode(secret),
      salt: salt,
      iterations: _legacyIterations,
      keyLength: 32,
    );
    return legacy.Key(keyBytes);
  }

  legacy.Key _legacyShaKey(String secret) {
    return legacy.Key(
      Uint8List.fromList(hashes.sha256.convert(utf8.encode(secret)).bytes),
    );
  }

  Uint8List _legacyPbkdf2({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = hashes.Hmac(hashes.sha256, password);
    final hashLength = hashes.sha256.convert(const []).bytes.length;
    final blocks = (keyLength / hashLength).ceil();
    final output = Uint8List(keyLength);
    var offset = 0;
    for (var block = 1; block <= blocks; block++) {
      final blockInput = BytesBuilder()
        ..add(salt)
        ..add(_uint32(block));
      var u = Uint8List.fromList(hmac.convert(blockInput.toBytes()).bytes);
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final copyLength = min(keyLength - offset, hashLength);
      output.setRange(offset, offset + copyLength, t);
      offset += copyLength;
    }
    return output;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final length = min(a.length, b.length);
    for (var i = 0; i < length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Future<Directory> _defaultVaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(path.join(documents.path, 'vault'));
  }

  static Future<Directory> _defaultTemporaryDirectory() async {
    final cache = await getTemporaryDirectory();
    return Directory(path.join(cache.path, 'vault_decrypted'));
  }
}

class _ParsedHeader {
  final LinkedHashMap<String, Object?> publicContext;
  final int chunkSize;
  final int originalLength;
  final int chunkCount;
  final Uint8List salt;
  final Uint8List noncePrefix;
  final Uint8List wrapNonce;
  final Uint8List wrappedKey;
  final Uint8List wrappedKeyTag;
  final Uint8List metadataCiphertext;
  final Uint8List metadataTag;

  const _ParsedHeader({
    required this.publicContext,
    required this.chunkSize,
    required this.originalLength,
    required this.chunkCount,
    required this.salt,
    required this.noncePrefix,
    required this.wrapNonce,
    required this.wrappedKey,
    required this.wrappedKeyTag,
    required this.metadataCiphertext,
    required this.metadataTag,
  });
}

class _UnavailableRecoveryKeyProvider implements VaultRecoveryKeyProvider {
  @override
  Future<Uint8List> requireConfirmedKey() {
    throw const VaultRecoveryException(
      VaultRecoveryErrorCode.missingKey,
      'The Vault Recovery Key is unavailable.',
    );
  }
}

class ListEquality<T> {
  const ListEquality();

  bool equals(List<T> first, List<T> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
