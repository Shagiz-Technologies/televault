import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:encrypt/encrypt.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:tele_vault/src/features/vault/services/vault_recovery_service.dart';
import 'package:tele_vault/src/features/vault/services/vault_service.dart';

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory tempDirectory;
  late Uint8List recoveryKey;
  late VaultService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('televault_v3_test_');
    vaultDirectory = Directory(path.join(root.path, 'vault'));
    tempDirectory = Directory(path.join(root.path, 'temp'));
    recoveryKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    service = _newService(recoveryKey, vaultDirectory, tempDirectory);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('v3 round-trips a file smaller than one chunk', () async {
    final source = await _source(root, 'camera/photo.jpg', 1024);
    final encrypted = await service.encryptFile(source, mimeType: 'image/jpeg');

    expect(encrypted.version, VaultService.currentVersion);
    expect(path.basename(encrypted.path), isNot(contains('photo.jpg')));
    expect(path.extension(encrypted.path), '.tvv3');

    final decrypted = await service.decryptFile(File(encrypted.path));
    expect(await decrypted.readAsBytes(), await source.readAsBytes());
    await service.deleteTemporaryPlaintext(decrypted);
  });

  test('v3 round-trips multiple authenticated chunks', () async {
    final source = await _source(root, 'multi.bin', 3 * 64 * 1024 + 117);
    final encrypted = await service.encryptFile(source);
    final decrypted = await service.decryptFile(File(encrypted.path));

    expect(await _digest(decrypted), await _digest(source));
    await service.deleteTemporaryPlaintext(decrypted);
  });

  test(
    'large synthetic file is processed with a fixed bounded chunk size',
    () async {
      final source = File(path.join(root.path, 'large.mp4'));
      final sink = source.openWrite();
      final block = Uint8List.fromList(
        List<int>.generate(64 * 1024, (index) => index & 0xff),
      );
      for (var i = 0; i < 128; i++) {
        sink.add(block);
      }
      await sink.flush();
      await sink.close();

      expect(await source.length(), greaterThan(service.chunkSize * 100));
      final encrypted = await service.encryptFile(source);
      final decrypted = await service.decryptFile(File(encrypted.path));
      expect(await _digest(decrypted), await _digest(source));
      await service.deleteTemporaryPlaintext(decrypted);
    },
  );

  test(
    'duplicate original basenames receive independent UUID objects',
    () async {
      final first = await _source(root, 'one/photo.jpg', 512);
      final second = await _source(root, 'two/photo.jpg', 512);

      final firstResult = await service.encryptFile(first);
      final secondResult = await service.encryptFile(second);

      expect(firstResult.objectId, isNot(secondResult.objectId));
      expect(firstResult.path, isNot(secondResult.path));
      expect(await File(firstResult.path).exists(), isTrue);
      expect(await File(secondResult.path).exists(), isTrue);
    },
  );

  test('wrong recovery key fails closed', () async {
    final source = await _source(root, 'wrong-key.jpg', 4096);
    final encrypted = await service.encryptFile(source);
    final otherService = _newService(
      Uint8List.fromList(List<int>.filled(32, 99)),
      vaultDirectory,
      tempDirectory,
    );

    expect(
      otherService.decryptFile(File(encrypted.path)),
      throwsA(_vaultError(VaultErrorCode.wrongRecoveryKey)),
    );
  });

  test('modified header fails closed', () async {
    final encrypted = await service.encryptFile(
      await _source(root, 'header.jpg', 4096),
    );
    final file = File(encrypted.path);
    final bytes = await file.readAsBytes();
    final headerLength = _uint32At(bytes, 8);
    final header = utf8.decode(bytes.sublist(12, 12 + headerLength));
    final modifiedHeader = header.replaceFirst('65536', '65537');
    expect(modifiedHeader, isNot(header));
    bytes.setRange(12, 12 + headerLength, utf8.encode(modifiedHeader));
    await file.writeAsBytes(bytes, flush: true);

    expect(
      service.decryptFile(file),
      throwsA(
        anyOf(
          _vaultError(VaultErrorCode.invalidContainer),
          _vaultError(VaultErrorCode.wrongRecoveryKey),
        ),
      ),
    );
  });

  test('modified middle chunk authentication tag fails closed', () async {
    final encrypted = await service.encryptFile(
      await _source(root, 'middle.bin', 3 * 64 * 1024),
    );
    final file = File(encrypted.path);
    final bytes = await file.readAsBytes();
    final records = _records(bytes);
    bytes[records[1].end - 1] ^= 0x01;
    await file.writeAsBytes(bytes, flush: true);

    expect(
      service.decryptFile(file),
      throwsA(_vaultError(VaultErrorCode.integrityFailure)),
    );
  });

  test('removed chunk is rejected', () async {
    final encrypted = await service.encryptFile(
      await _source(root, 'removed.bin', 3 * 64 * 1024),
    );
    final file = File(encrypted.path);
    final bytes = await file.readAsBytes();
    final records = _records(bytes);
    final modified = <int>[
      ...bytes.sublist(0, records[1].start),
      ...bytes.sublist(records[1].end),
    ];
    await file.writeAsBytes(modified, flush: true);

    expect(
      service.decryptFile(file),
      throwsA(
        anyOf(
          _vaultError(VaultErrorCode.integrityFailure),
          _vaultError(VaultErrorCode.truncatedContainer),
        ),
      ),
    );
  });

  test('reordered chunks are rejected', () async {
    final encrypted = await service.encryptFile(
      await _source(root, 'reordered.bin', 3 * 64 * 1024),
    );
    final file = File(encrypted.path);
    final bytes = await file.readAsBytes();
    final records = _records(bytes);
    final modified = <int>[
      ...bytes.sublist(0, records[0].start),
      ...bytes.sublist(records[1].start, records[1].end),
      ...bytes.sublist(records[0].start, records[0].end),
      ...bytes.sublist(records[2].start),
    ];
    await file.writeAsBytes(modified, flush: true);

    expect(
      service.decryptFile(file),
      throwsA(_vaultError(VaultErrorCode.integrityFailure)),
    );
  });

  test('truncated file is rejected and leaves no plaintext', () async {
    final encrypted = await service.encryptFile(
      await _source(root, 'truncated.bin', 2 * 64 * 1024),
    );
    final file = File(encrypted.path);
    final bytes = await file.readAsBytes();
    await file.writeAsBytes(bytes.sublist(0, bytes.length - 7), flush: true);

    expect(
      service.decryptFile(file),
      throwsA(_vaultError(VaultErrorCode.truncatedContainer)),
    );
    expect(await _fileCount(tempDirectory), 0);
  });

  test('legacy v1 and v2 remain readable', () async {
    const secret = 'legacy-password';
    final plaintext = Uint8List.fromList(
      List<int>.generate(4096, (index) => index & 0xff),
    );
    final v1 = File(path.join(root.path, 'legacy-one.jpg.enc'));
    final v2 = File(path.join(root.path, 'legacy-two.jpg.enc'));
    await _writeLegacy(
      v1,
      plaintext,
      secret,
      version: 1,
      ivBytes: Uint8List.fromList([2, ...List<int>.filled(11, 9)]),
    );
    await _writeLegacy(v2, plaintext, secret, version: 2);

    final decryptedV1 = await service.decryptFile(v1, secret);
    final decryptedV2 = await service.decryptFile(v2, secret);
    expect(await decryptedV1.readAsBytes(), plaintext);
    expect(await decryptedV2.readAsBytes(), plaintext);
    await service.deleteTemporaryPlaintext(decryptedV1);
    await service.deleteTemporaryPlaintext(decryptedV2);
  });

  test('startup cleanup removes plaintext and partial files', () async {
    await tempDirectory.create(recursive: true);
    await vaultDirectory.create(recursive: true);
    await File(
      path.join(tempDirectory.path, 'plaintext.jpg'),
    ).writeAsString('x');
    await File(
      path.join(vaultDirectory.path, 'object.tvv3.partial-test'),
    ).writeAsString('x');
    final completed = File(path.join(vaultDirectory.path, 'keep.tvv3'));
    await completed.writeAsString('keep');

    await service.cleanupStaleTemporaryFiles();

    expect(await _fileCount(tempDirectory), 0);
    expect(await completed.exists(), isTrue);
    expect(
      await File(
        path.join(vaultDirectory.path, 'object.tvv3.partial-test'),
      ).exists(),
      isFalse,
    );
  });

  test(
    'simulated UUID collision never overwrites an existing object',
    () async {
      const objectId = '11111111-1111-4111-8111-111111111111';
      final collisionService = _newService(
        recoveryKey,
        vaultDirectory,
        tempDirectory,
        objectIdFactory: () => objectId,
      );
      final first = await collisionService.encryptFile(
        await _source(root, 'first.bin', 2048),
        objectId: objectId,
      );
      final before = await _digest(File(first.path));

      expect(
        collisionService.encryptFile(
          await _source(root, 'second.bin', 1024),
          objectId: objectId,
        ),
        throwsA(_vaultError(VaultErrorCode.destinationExists)),
      );
      expect(await _digest(File(first.path)), before);
    },
  );
}

VaultService _newService(
  Uint8List recoveryKey,
  Directory vaultDirectory,
  Directory tempDirectory, {
  VaultObjectIdFactory? objectIdFactory,
}) {
  return VaultService(
    recoveryKeyProvider: _StaticRecoveryKeyProvider(recoveryKey),
    vaultDirectoryProvider: () async => vaultDirectory,
    temporaryDirectoryProvider: () async => tempDirectory,
    objectIdFactory: objectIdFactory,
    chunkSize: 64 * 1024,
  );
}

Matcher _vaultError(VaultErrorCode code) {
  return isA<VaultException>().having((error) => error.code, 'code', code);
}

Future<File> _source(Directory root, String relativePath, int length) async {
  final file = File(path.join(root.path, relativePath));
  await file.parent.create(recursive: true);
  final random = Random(relativePath.hashCode);
  final sink = file.openWrite();
  var remaining = length;
  while (remaining > 0) {
    final count = min(remaining, 16 * 1024);
    sink.add(List<int>.generate(count, (_) => random.nextInt(256)));
    remaining -= count;
  }
  await sink.flush();
  await sink.close();
  return file;
}

Future<String> _digest(File file) async {
  return (await hashes.sha256.bind(file.openRead()).first).toString();
}

Future<int> _fileCount(Directory directory) async {
  if (!await directory.exists()) return 0;
  return directory
      .list(followLinks: false)
      .where((entity) => entity is File)
      .length;
}

int _uint32At(List<int> bytes, int offset) {
  return ByteData.sublistView(
    Uint8List.fromList(bytes),
    offset,
    offset + 4,
  ).getUint32(0, Endian.big);
}

List<_Record> _records(List<int> bytes) {
  var offset = 12 + _uint32At(bytes, 8);
  final records = <_Record>[];
  while (offset < bytes.length) {
    final ciphertextLength = _uint32At(bytes, offset + 8);
    final end = offset + 12 + ciphertextLength + 16;
    records.add(_Record(offset, end));
    offset = end;
  }
  return records;
}

Future<void> _writeLegacy(
  File destination,
  Uint8List plaintext,
  String secret, {
  required int version,
  Uint8List? ivBytes,
}) async {
  final iv = ivBytes == null
      ? legacy.IV.fromSecureRandom(12)
      : legacy.IV(ivBytes);
  final output = BytesBuilder();
  late final legacy.Key key;
  if (version == 2) {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (index) => index + 1),
    );
    key = legacy.Key(_pbkdf2(secret, salt));
    output
      ..addByte(2)
      ..add(salt);
  } else {
    key = legacy.Key(
      Uint8List.fromList(hashes.sha256.convert(utf8.encode(secret)).bytes),
    );
  }
  final encrypted = legacy.Encrypter(
    legacy.AES(key, mode: legacy.AESMode.gcm),
  ).encryptBytes(plaintext, iv: iv);
  output
    ..add(iv.bytes)
    ..add(encrypted.bytes);
  await destination.writeAsBytes(output.takeBytes(), flush: true);
}

Uint8List _pbkdf2(String secret, Uint8List salt) {
  final hmac = hashes.Hmac(hashes.sha256, utf8.encode(secret));
  final output = Uint8List(32);
  final input = BytesBuilder()
    ..add(salt)
    ..add([0, 0, 0, 1]);
  var u = Uint8List.fromList(hmac.convert(input.takeBytes()).bytes);
  output.setAll(0, u);
  for (var iteration = 1; iteration < 120000; iteration++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var index = 0; index < output.length; index++) {
      output[index] ^= u[index];
    }
  }
  return output;
}

class _Record {
  final int start;
  final int end;

  const _Record(this.start, this.end);
}

class _StaticRecoveryKeyProvider implements VaultRecoveryKeyProvider {
  final Uint8List key;

  const _StaticRecoveryKeyProvider(this.key);

  @override
  Future<Uint8List> requireConfirmedKey() async => Uint8List.fromList(key);
}
