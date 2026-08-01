import 'dart:async';
import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_gateway.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/backup/services/auto_metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_operation_lock.dart';

void main() {
  late AppDatabase db;
  late _FakeTelegramGateway telegram;
  late _FakeMetadataBackupService metadata;
  late TelegramReliabilityService reliability;
  late AutoMetadataBackupService service;
  late io.Directory tempDirectory;

  setUp(() async {
    tempDirectory = await io.Directory.systemTemp.createTemp(
      'televault_auto_metadata_test_',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    telegram = _FakeTelegramGateway();
    metadata = _FakeMetadataBackupService();
    reliability = TelegramReliabilityService(
      db,
      telegram,
      autoInitialize: false,
    );
    service = AutoMetadataBackupService(
      db,
      telegram,
      metadata,
      reliability,
      MetadataOperationLock(
        lockFileProvider: () async =>
            io.File('${tempDirectory.path}/metadata.lock'),
      ),
      () async => tempDirectory,
    );
  });

  tearDown(() async {
    await service.dispose();
    await reliability.dispose();
    await metadata.dispose();
    await telegram.dispose();
    await db.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'captures fast Telegram confirmation and stores completion time',
    () async {
      final before = DateTime.now();

      final result = await service.backupNow(reason: 'test');

      expect(result.chatId, BigInt.from(1001));
      expect(result.messageId, 1100);
      expect(result.completedAt.isBefore(before), isFalse);
      final stored = await service.getLastBackupAt();
      expect(stored, isNotNull);
      expect(stored!.difference(result.completedAt).abs().inMilliseconds, 0);
    },
  );
}

class _FakeTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  final List<TelegramUpdate> _bufferedUpdates = [];
  String? _uploadedPath;

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  @override
  void send(TelegramRequest request) {}

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return switch (request['@type']) {
      'getChats' => const {'@type': 'chats', 'chat_ids': <int>[]},
      'createNewSupergroupChat' => const {'@type': 'chat', 'id': 1001},
      'sendMessage' => _sendMessage(request),
      'getMessage' => const {
        '@type': 'message',
        'id': 1100,
        'chat_id': 1001,
        'content': {
          '@type': 'messageDocument',
          'document': {
            'document': {'@type': 'file', 'id': 77},
          },
        },
      },
      'downloadFile' => {
        '@type': 'file',
        'id': 77,
        'local': {'path': _uploadedPath, 'is_downloading_completed': true},
      },
      _ => throw UnimplementedError(
        'Unexpected Telegram request: ${request['@type']}',
      ),
    };
  }

  Future<TelegramResult> _sendMessage(TelegramRequest request) async {
    final content = request['input_message_content'] as Map<String, dynamic>;
    final document = content['document'] as Map<String, dynamic>;
    final inputFile = document['document'] as Map<String, dynamic>;
    _uploadedPath = inputFile['path'] as String?;
    final update = <String, dynamic>{
      '@type': 'updateMessageSendSucceeded',
      'old_message_id': 100,
      'message': {
        '@type': 'message',
        'id': 1100,
        'chat_id': request['chat_id'],
      },
    };
    _bufferedUpdates.add(update);
    _updates.add(update);
    await Future<void>.delayed(Duration.zero);
    return const {
      '@type': 'message',
      'id': 100,
      'sending_state': {'@type': 'messageSendingStatePending'},
    };
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final index = _bufferedUpdates.indexWhere(predicate);
    if (index >= 0) return _bufferedUpdates.removeAt(index);
    return _updates.stream.firstWhere(predicate).timeout(timeout);
  }

  @override
  Future<void> dispose() => _updates.close();
}

class _FakeMetadataBackupService implements MetadataBackupService {
  io.Directory? _directory;

  @override
  Future<io.File> exportAccountBoundSnapshot() async {
    final directory = await io.Directory.systemTemp.createTemp(
      'televault_metadata_test_',
    );
    _directory = directory;
    return io.File('${directory.path}/snapshot.tvmeta').writeAsBytes([1, 2, 3]);
  }

  Future<void> dispose() async {
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<io.File> exportEncryptedSnapshot({required String passphrase}) {
    throw UnimplementedError();
  }

  @override
  Future<MetadataImportResult> importAccountBoundSnapshot(io.File snapshot) {
    throw UnimplementedError();
  }

  @override
  Future<MetadataImportResult> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MetadataSnapshotInspection> inspectSnapshot(io.File snapshot) async {
    return const MetadataSnapshotInspection(
      formatVersion: 5,
      protection: MetadataSnapshotProtection.recoveryKey,
      generationId: 'test-generation',
    );
  }

  @override
  Future<void> verifyAccountBoundSnapshot(io.File snapshot) async {}
}
