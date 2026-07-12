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
    expect(telegramGateway.sentInputFileTypes, ['inputFileId', 'inputFileId']);
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

  test(
    'suspend lets current upload finish without starting next file',
    () async {
      final bucketId = await insertBucket('Photos', 1001);
      final dir = await io.Directory.systemTemp.createTemp(
        'televault_upload_pause_current_',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final first = io.File('${dir.path}/first.jpg');
      final second = io.File('${dir.path}/second.jpg');
      await first.writeAsBytes([1, 2, 3]);
      await second.writeAsBytes([4, 5, 6]);
      await insertFile(
        bucketId: bucketId,
        path: first.path,
        status: FileSyncStatus.pending,
        dateAdded: DateTime(2020),
      );
      await insertFile(
        bucketId: bucketId,
        path: second.path,
        status: FileSyncStatus.pending,
        dateAdded: DateTime(2021),
      );

      telegramGateway.completeSendMessages = true;
      final gate = Completer<void>();
      telegramGateway.nextSendGate = gate;
      await uploader.startUploadLoop();
      while (telegramGateway.uploadedPaths.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      uploader.suspendBackgroundWakes();
      gate.complete();
      await uploader.waitForCurrentUploadToFinish(
        timeout: const Duration(seconds: 2),
      );

      final rows = await (db.select(
        db.files,
      )..orderBy([(t) => OrderingTerm.asc(t.dateAdded)])).get();
      expect(telegramGateway.uploadedPaths, [first.path]);
      expect(rows.first.status, FileSyncStatus.synced.dbValue);
      expect(rows.last.status, FileSyncStatus.pending.dbValue);
    },
  );

  test('automatic retry respects disabled auto backup', () async {
    final bucketId = await insertBucket('Photos', 1001);
    await settingsService.saveSyncPreferences(
      const SyncPreferences(autoBackupEnabled: false),
      bucketId: bucketId,
    );
    final dir = await io.Directory.systemTemp.createTemp(
      'televault_upload_paused_',
    );
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final image = io.File('${dir.path}/paused.jpg');
    await image.writeAsBytes([1, 2, 3]);
    await insertFile(
      bucketId: bucketId,
      path: image.path,
      status: FileSyncStatus.failed,
    );

    telegramGateway.completeSendMessages = true;
    await uploader.startUploadLoop();
    await uploader.retryFailed(bucketId: bucketId);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final row = await db.select(db.files).getSingle();
    expect(row.status, FileSyncStatus.pending.dbValue);
    expect(telegramGateway.uploadedPaths, isEmpty);
  });

  test(
    'permanent TDLib input failures do not spin in the retry loop',
    () async {
      final bucketId = await insertBucket('Photos', 1001);
      final dir = await io.Directory.systemTemp.createTemp(
        'televault_upload_permanent_failure_',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final image = io.File('${dir.path}/broken.jpg');
      await image.writeAsBytes([1, 2, 3]);
      await insertFile(
        bucketId: bucketId,
        path: image.path,
        status: FileSyncStatus.pending,
      );

      telegramGateway.completeSendMessages = true;
      telegramGateway.preliminaryUploadError = 'InputFile is not specified';
      await uploader.drainQueueForTesting(ignoreConstraints: true);

      final row = await db.select(db.files).getSingle();
      expect(row.status, FileSyncStatus.failed.dbValue);
      expect(row.nextRetryAt, null);
      expect(telegramGateway.preliminaryUploadAttempts, 1);
    },
  );
}

class _FakeTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  final List<String> uploadedPaths = [];
  final List<String> sentInputFileTypes = [];
  bool completeSendMessages = false;
  Completer<void>? nextSendGate;
  String? preliminaryUploadError;
  int preliminaryUploadAttempts = 0;
  int _nextMessageId = 100;
  int _nextFileId = 1000;

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
    if (type == 'preliminaryUploadFile') {
      preliminaryUploadAttempts++;
      final error = preliminaryUploadError;
      if (error != null) {
        return Future.value({'@type': 'error', 'code': 400, 'message': error});
      }
      final inputFile = request['file'] as Map<String, dynamic>? ?? {};
      uploadedPaths.add(inputFile['path'] as String? ?? '');
      return Future.value({
        '@type': 'file',
        'id': _nextFileId++,
        'local': {'path': inputFile['path']},
      });
    }
    if (type == 'sendMessage') {
      sentInputFileTypes.add(_extractInputFileType(request));
      final response = {'@type': 'message', 'id': _nextMessageId++};
      final gate = nextSendGate;
      nextSendGate = null;
      if (gate == null) return Future.value(response);
      return gate.future.then((_) => response);
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

  String _extractInputFileType(TelegramRequest request) {
    final content =
        request['input_message_content'] as Map<String, dynamic>? ?? {};
    final inputFile =
        (content['document'] ?? content['photo'] ?? content['video'])
            as Map<String, dynamic>?;
    return inputFile?['@type'] as String? ?? '';
  }
}

class _NoopSyncConstraintsService extends SyncConstraintsService {
  _NoopSyncConstraintsService(super.settingsService);

  @override
  Future<bool> canRunAutomaticSync({int? bucketId}) async => true;

  @override
  Stream<void> watchConstraintChanges() => const Stream.empty();
}
