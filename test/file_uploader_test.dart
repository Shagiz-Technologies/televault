import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/core/services/diagnostics_service.dart';
import 'package:tele_vault/src/core/services/telegram_gateway.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';
import 'package:tele_vault/src/features/sync/services/file_uploader.dart';
import 'package:tele_vault/src/features/sync/services/sync_constraints_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settingsService;
  late _FakeTelegramGateway telegramGateway;
  late FileUploader uploader;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settingsService = SettingsService(db);
    telegramGateway = _FakeTelegramGateway();
    uploader = FileUploader(
      db,
      telegramGateway,
      settingsService,
      DiagnosticsService(db),
      _NoopSyncConstraintsService(settingsService),
    );
  });

  tearDown(() async {
    await uploader.dispose();
    await db.close();
  });

  Future<int> insertBucket(String name, int chatId) {
    return db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(chatId: BigInt.from(chatId), name: name),
        );
  }

  Future<int> insertFile({
    required int bucketId,
    required String path,
    required FileSyncStatus status,
    DateTime? dateAdded,
  }) {
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: path,
            folderName: 'Camera',
            size: 42,
            bucketId: bucketId,
            status: Value(status.dbValue),
            dateAdded: Value(dateAdded ?? DateTime.now()),
          ),
        );
  }

  test('retryFailed can be scoped to one bucket', () async {
    final photosBucket = await insertBucket('Photos', 1001);
    final videosBucket = await insertBucket('Videos', 1002);
    await insertFile(
      bucketId: photosBucket,
      path: '/storage/photos/a.jpg',
      status: FileSyncStatus.failed,
    );
    await insertFile(
      bucketId: videosBucket,
      path: '/storage/videos/b.mp4',
      status: FileSyncStatus.failed,
    );

    final retried = await uploader.retryFailed(bucketId: photosBucket);

    final rows = await db.select(db.files).get();
    final photosRow = rows.singleWhere((row) => row.bucketId == photosBucket);
    final videosRow = rows.singleWhere((row) => row.bucketId == videosBucket);

    expect(retried, 1);
    expect(photosRow.status, FileSyncStatus.pending.dbValue);
    expect(videosRow.status, FileSyncStatus.failed.dbValue);
  });

  test('upload loop sends older media before newer media', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final dir = await io.Directory.systemTemp.createTemp(
      'televault_upload_order_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final newerFile = io.File('${dir.path}/newer.jpg');
    final olderFile = io.File('${dir.path}/older.jpg');
    await newerFile.writeAsBytes([2, 3, 4]);
    await olderFile.writeAsBytes([1, 2, 3]);

    await insertFile(
      bucketId: bucketId,
      path: newerFile.path,
      status: FileSyncStatus.pending,
      dateAdded: DateTime(2026, 6, 1),
    );
    await insertFile(
      bucketId: bucketId,
      path: olderFile.path,
      status: FileSyncStatus.pending,
      dateAdded: DateTime(2020, 1, 1),
    );

    telegramGateway.completeSendMessages = true;
    await uploader.drainQueueForTesting(ignoreConstraints: true);

    final rows = await db.select(db.files).get();
    expect(
      rows.every((row) => row.status == FileSyncStatus.synced.dbValue),
      isTrue,
    );
    expect(telegramGateway.uploadedPaths, [olderFile.path, newerFile.path]);
  });

  test('suspended background wakes still allow explicit queue drain', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final dir = await io.Directory.systemTemp.createTemp(
      'televault_upload_suspend_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final image = io.File('${dir.path}/image.jpg');
    await image.writeAsBytes([1, 2, 3]);
    await insertFile(
      bucketId: bucketId,
      path: image.path,
      status: FileSyncStatus.pending,
    );

    telegramGateway.completeSendMessages = true;
    uploader.suspendBackgroundWakes();
    await uploader.startUploadLoop();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(telegramGateway.uploadedPaths, isEmpty);

    await uploader.drainQueueForTesting(ignoreConstraints: true);

    final row = await db.select(db.files).getSingle();
    expect(row.status, FileSyncStatus.synced.dbValue);
    expect(telegramGateway.uploadedPaths, [image.path]);
  });
}

class _FakeTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  final List<String> uploadedPaths = [];
  bool completeSendMessages = false;
  int _nextMessageId = 100;

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  @override
  void send(TelegramRequest request) {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    if (!completeSendMessages) {
      throw UnimplementedError(
        'No Telegram requests are expected in this test',
      );
    }
    final type = request['@type'];
    if (type == 'getChat') {
      return Future.value({'@type': 'chat', 'id': request['chat_id']});
    }
    if (type == 'sendMessage') {
      uploadedPaths.add(_extractUploadPath(request));
      return Future.value({'@type': 'message', 'id': _nextMessageId++});
    }
    throw UnimplementedError('Unexpected Telegram request: $type');
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('No Telegram updates are expected in this test');
  }

  @override
  Future<void> dispose() async {
    await _updates.close();
  }

  String _extractUploadPath(TelegramRequest request) {
    final content =
        request['input_message_content'] as Map<String, dynamic>? ?? {};
    final inputFile =
        (content['document'] ?? content['photo'] ?? content['video'])
            as Map<String, dynamic>?;
    return inputFile?['path'] as String? ?? '';
  }
}

class _NoopSyncConstraintsService extends SyncConstraintsService {
  _NoopSyncConstraintsService(super.settingsService);

  @override
  Future<bool> canRunAutomaticSync({int? bucketId}) async => true;

  @override
  Stream<void> watchConstraintChanges() => const Stream.empty();
}
