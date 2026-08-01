import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/backup/services/auto_metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_operation_lock.dart';

import 'support/fake_telegram_gateway.dart';

void main() {
  test('retains two verified snapshots when old deletion fails', () async {
    final fixture = await _RemoteBackupFixture.create(failDeletes: true);
    addTearDown(fixture.dispose);

    final first = await fixture.service.backupNow(reason: 'first');
    final second = await fixture.service.backupNow(reason: 'second');
    final third = await fixture.service.backupNow(reason: 'third');

    expect(first.messageId, 101);
    expect(second.messageId, 102);
    expect(third.messageId, 103);
    expect(fixture.metadata.verifyCount, 3);
    expect(fixture.deleteAttempts, 1);
    final setting =
        await (fixture.db.select(fixture.db.appSettings)..where(
              (table) => table.key.equals('metadata_verified_snapshots_v5'),
            ))
            .getSingle();
    final history = jsonDecode(setting.value) as List<dynamic>;
    expect(history, hasLength(2));
    expect((history[0] as Map)['message_id'], '103');
    expect((history[1] as Map)['message_id'], '102');
  });

  test(
    'legacy v4 restore immediately uploads and verifies v5 migration',
    () async {
      final fixture = await _RemoteBackupFixture.create(
        importRequiresMigration: true,
        includeRestoreMessage: true,
      );
      addTearDown(fixture.dispose);

      final result = await fixture.service.restoreLatestIfAvailable();

      expect(result, isNotNull);
      expect(result!.messageId, 91);
      expect(fixture.metadata.importCount, 1);
      expect(fixture.metadata.exportCount, 1);
      expect(fixture.metadata.verifyCount, 1);
      expect(fixture.gateway.requestCount('sendMessage'), 1);
    },
  );
}

class _RemoteBackupFixture {
  final AppDatabase db;
  final FakeTelegramGateway gateway;
  final TelegramReliabilityService reliability;
  final _TrackingMetadataService metadata;
  final AutoMetadataBackupService service;
  final io.Directory directory;
  final bool failDeletes;
  final bool includeRestoreMessage;
  int nextMessageId = 101;
  int deleteAttempts = 0;

  _RemoteBackupFixture({
    required this.db,
    required this.gateway,
    required this.reliability,
    required this.metadata,
    required this.service,
    required this.directory,
    required this.failDeletes,
    required this.includeRestoreMessage,
  });

  static Future<_RemoteBackupFixture> create({
    bool failDeletes = false,
    bool importRequiresMigration = false,
    bool includeRestoreMessage = false,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = FakeTelegramGateway();
    final reliability = TelegramReliabilityService(
      db,
      gateway,
      autoInitialize: false,
      jitter: () => Duration.zero,
    );
    await reliability.initialize();
    final directory = await io.Directory.systemTemp.createTemp(
      'televault_remote_metadata_',
    );
    final metadata = _TrackingMetadataService(
      directory,
      importRequiresMigration: importRequiresMigration,
    );
    final operationLock = MetadataOperationLock(
      lockFileProvider: () async => io.File('${directory.path}/metadata.lock'),
    );
    late _RemoteBackupFixture fixture;
    final service = AutoMetadataBackupService(
      db,
      gateway,
      metadata,
      reliability,
      operationLock,
      () async => directory,
    );
    fixture = _RemoteBackupFixture(
      db: db,
      gateway: gateway,
      reliability: reliability,
      metadata: metadata,
      service: service,
      directory: directory,
      failDeletes: failDeletes,
      includeRestoreMessage: includeRestoreMessage,
    );
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'metadata_default_channel_chat_id',
            value: '-1009001',
          ),
        );
    final remoteFile = io.File('${directory.path}/remote.tvmeta');
    await remoteFile.writeAsBytes([5, 4, 3, 2, 1]);
    gateway.handler = (request) async {
      switch (request['@type']) {
        case 'getChat':
          return {
            '@type': 'chat',
            'id': request['chat_id'],
            'title': AutoMetadataBackupService.channelTitle,
          };
        case 'getChats':
          return {
            '@type': 'chats',
            'chat_ids': [-1009001],
          };
        case 'searchChatMessages':
          return {
            '@type': 'foundChatMessages',
            'messages': includeRestoreMessage
                ? [fixture._message(91)]
                : <dynamic>[],
          };
        case 'getChatHistory':
          return {
            '@type': 'messages',
            'messages': includeRestoreMessage
                ? [fixture._message(91)]
                : <dynamic>[],
          };
        case 'sendMessage':
          final id = fixture.nextMessageId++;
          return {'@type': 'message', 'id': id, 'chat_id': request['chat_id']};
        case 'getMessage':
          return fixture._message(request['message_id'] as int);
        case 'downloadFile':
          return {
            '@type': 'file',
            'id': request['file_id'],
            'local': {'path': remoteFile.path},
          };
        case 'deleteMessages':
          fixture.deleteAttempts++;
          return failDeletes
              ? {'@type': 'error', 'code': 500, 'message': 'DELETE_FAILED'}
              : {'@type': 'ok'};
        default:
          throw UnimplementedError('Unexpected request: ${request['@type']}');
      }
    };
    return fixture;
  }

  Map<String, dynamic> _message(int id) {
    return {
      '@type': 'message',
      'id': id,
      'chat_id': -1009001,
      'date': id,
      'content': {
        '@type': 'messageDocument',
        'caption': {
          '@type': 'formattedText',
          'text': AutoMetadataBackupService.marker,
        },
        'document': {
          '@type': 'document',
          'document': {'@type': 'file', 'id': id + 1000},
        },
      },
    };
  }

  Future<void> dispose() async {
    await service.dispose();
    await reliability.dispose();
    await gateway.dispose();
    await db.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

class _TrackingMetadataService implements MetadataBackupService {
  final io.Directory directory;
  final bool importRequiresMigration;
  int exportCount = 0;
  int importCount = 0;
  int verifyCount = 0;

  _TrackingMetadataService(
    this.directory, {
    required this.importRequiresMigration,
  });

  @override
  Future<io.File> exportAccountBoundSnapshot() async {
    exportCount++;
    final file = io.File('${directory.path}/export-$exportCount.tvmeta');
    await file.writeAsBytes([exportCount]);
    return file;
  }

  @override
  Future<io.File> exportEncryptedSnapshot({required String passphrase}) {
    return exportAccountBoundSnapshot();
  }

  @override
  Future<MetadataImportResult> importAccountBoundSnapshot(
    io.File snapshot,
  ) async {
    importCount++;
    return MetadataImportResult(
      sourceFormatVersion: importRequiresMigration ? 4 : 5,
      generationId: importRequiresMigration ? 'legacy-test' : 'v5-test',
      requiresSecureMigration: importRequiresMigration,
    );
  }

  @override
  Future<MetadataImportResult> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  }) {
    return importAccountBoundSnapshot(snapshot);
  }

  @override
  Future<MetadataSnapshotInspection> inspectSnapshot(io.File snapshot) async {
    return const MetadataSnapshotInspection(
      formatVersion: 5,
      protection: MetadataSnapshotProtection.recoveryKey,
    );
  }

  @override
  Future<void> verifyAccountBoundSnapshot(io.File snapshot) async {
    verifyCount++;
  }
}
