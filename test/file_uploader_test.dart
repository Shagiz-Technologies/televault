import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/core/database/local_media_access_state.dart';
import 'package:tele_vault/src/core/services/diagnostics_service.dart';
import 'package:tele_vault/src/core/services/telegram_error.dart';
import 'package:tele_vault/src/core/services/telegram_gateway.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';
import 'package:tele_vault/src/features/sync/services/file_uploader.dart';
import 'package:tele_vault/src/features/sync/services/sync_constraints_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settingsService;
  late _UploaderTelegramGateway telegramGateway;
  late TelegramReliabilityService reliability;
  late FileUploader uploader;
  var insertedBucketCount = 0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    insertedBucketCount = 0;
    telegramGateway = _UploaderTelegramGateway();
    reliability = TelegramReliabilityService(
      db,
      telegramGateway,
      jitter: () => Duration.zero,
      autoInitialize: false,
    );
    await reliability.initialize();
    settingsService = SettingsService(
      db,
      effectiveMaxFileSizeMb: () => reliability.effectiveUploadLimitMb,
    );
    uploader = FileUploader(
      db,
      telegramGateway,
      settingsService,
      DiagnosticsService(db),
      _NoopSyncConstraintsService(settingsService),
      reliability,
    );
  });

  tearDown(() async {
    await uploader.dispose();
    await reliability.dispose();
    await telegramGateway.dispose();
    await db.close();
  });

  Future<int> insertBucket(String name, int chatId) {
    final isFirstBucket = insertedBucketCount++ == 0;
    return db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(chatId),
            name: name,
            isActive: Value(isFirstBucket),
          ),
        );
  }

  Future<int> insertFile({
    required int bucketId,
    required String path,
    required FileSyncStatus status,
    DateTime? dateAdded,
    int size = 42,
    String? lastTelegramOperation,
    bool userActionRequired = false,
    LocalMediaAccessState localAccessState = LocalMediaAccessState.available,
    int? telegramMessageId,
  }) {
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: path,
            folderName: 'Camera',
            size: size,
            bucketId: bucketId,
            status: Value(status.dbValue),
            dateAdded: Value(dateAdded ?? DateTime.now()),
            lastTelegramOperation: Value(lastTelegramOperation),
            userActionRequired: Value(userActionRequired),
            localMediaAccessState: Value(localAccessState.dbValue),
            telegramMessageId: Value(telegramMessageId),
          ),
        );
  }

  Future<io.File> tempMedia(String name) async {
    final dir = await io.Directory.systemTemp.createTemp('televault_upload_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = io.File('${dir.path}/$name');
    await file.writeAsBytes([1, 2, 3]);
    return file;
  }

  test('retryFailed can be scoped to one bucket', () async {
    final photosBucket = await insertBucket('Photos', 1001);
    final videosBucket = await insertBucket('Videos', 1002);
    await insertFile(
      bucketId: photosBucket,
      path: '/missing/photos.jpg',
      status: FileSyncStatus.failed,
    );
    await insertFile(
      bucketId: videosBucket,
      path: '/missing/video.mp4',
      status: FileSyncStatus.failed,
    );

    final retried = await uploader.retryFailed(bucketId: photosBucket);
    final rows = await db.select(db.files).get();

    expect(retried, 1);
    expect(
      rows.singleWhere((row) => row.bucketId == photosBucket).status,
      FileSyncStatus.pending.dbValue,
    );
    expect(
      rows.singleWhere((row) => row.bucketId == videosBucket).status,
      FileSyncStatus.failed.dbValue,
    );
  });

  test('access-unavailable media is not uploaded or retried', () async {
    final bucketId = await insertBucket('Selected photos', 1001);
    await insertFile(
      bucketId: bucketId,
      path: '/not-currently-accessible/photo.jpg',
      status: FileSyncStatus.pending,
      localAccessState: LocalMediaAccessState.accessUnavailable,
    );

    await uploader.drainQueueForTesting(ignoreConstraints: true);
    final row = await db.select(db.files).getSingle();

    expect(row.status, FileSyncStatus.pending.dbValue);
    expect(telegramGateway.requestCount('sendMessage'), 0);
  });

  test(
    'claimed uploads missing from Telegram are returned to failed',
    () async {
      final bucketId = await insertBucket('Photos', 1001);
      await insertFile(
        bucketId: bucketId,
        path: '/not-currently-accessible/claimed.jpg',
        status: FileSyncStatus.synced,
        localAccessState: LocalMediaAccessState.accessUnavailable,
        telegramMessageId: 777,
      );

      await uploader.drainQueueForTesting(ignoreConstraints: true);
      final row = await db.select(db.files).getSingle();

      expect(row.status, FileSyncStatus.failed.dbValue);
      expect(row.telegramMessageId, isNull);
      expect(row.lastTelegramOperation, 'verify_remote_backup');
      expect(telegramGateway.requestCount('sendMessage'), 0);
    },
  );

  test('upload loop sends older media first using inputFileLocal', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final newer = await tempMedia('newer.jpg');
    final older = await tempMedia('older.jpg');
    await insertFile(
      bucketId: bucketId,
      path: newer.path,
      status: FileSyncStatus.pending,
      dateAdded: DateTime(2026),
    );
    await insertFile(
      bucketId: bucketId,
      path: older.path,
      status: FileSyncStatus.pending,
      dateAdded: DateTime(2020),
    );

    await uploader.drainQueueForTesting(ignoreConstraints: true);

    expect(telegramGateway.uploadedPaths, [older.path, newer.path]);
    expect(telegramGateway.sentInputFileTypes, [
      'inputFileLocal',
      'inputFileLocal',
    ]);
    expect(telegramGateway.requestCount('preliminaryUploadFile'), 0);
    final rows = await db.select(db.files).get();
    expect(
      rows.every((row) => row.status == FileSyncStatus.synced.dbValue),
      isTrue,
    );
  });

  test('queue keeps send concurrency at exactly one', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final first = await tempMedia('first.jpg');
    final second = await tempMedia('second.jpg');
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
    final releaseFirst = Completer<void>();
    telegramGateway.nextSendGate = releaseFirst;

    final drain = uploader.drainQueueForTesting(ignoreConstraints: true);
    await telegramGateway.firstSendStarted.future;
    expect(telegramGateway.activeSends, 1);
    expect(telegramGateway.uploadedPaths, [first.path]);
    releaseFirst.complete();
    await drain;

    expect(telegramGateway.maxConcurrentSends, 1);
    expect(telegramGateway.uploadedPaths, [first.path, second.path]);
  });

  test('transient failures use bounded exponential backoff', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final media = await tempMedia('temporary.jpg');
    await insertFile(
      bucketId: bucketId,
      path: media.path,
      status: FileSyncStatus.pending,
    );
    telegramGateway.sendError = {
      '@type': 'error',
      'code': 500,
      'message': 'TEMPORARILY_UNAVAILABLE',
    };
    final startedAt = DateTime.now();

    await uploader.drainQueueForTesting(ignoreConstraints: true);
    final row = await db.select(db.files).getSingle();

    expect(row.status, FileSyncStatus.failed.dbValue);
    expect(row.telegramErrorCategory, TelegramErrorCategory.transient.name);
    expect(row.nextRetryAt, isNotNull);
    expect(
      row.nextRetryAt!.isAfter(startedAt.add(const Duration(seconds: 14))),
      isTrue,
    );
    expect(row.telegramRetryAfter, isNull);
  });

  test('permanent errors are never automatically retried', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final media = await tempMedia('invalid-chat.jpg');
    await insertFile(
      bucketId: bucketId,
      path: media.path,
      status: FileSyncStatus.pending,
    );
    telegramGateway.sendError = {
      '@type': 'error',
      'code': 400,
      'message': 'CHAT_ID_INVALID',
    };

    await uploader.drainQueueForTesting(ignoreConstraints: true);
    final row = await db.select(db.files).getSingle();

    expect(row.status, FileSyncStatus.failed.dbValue);
    expect(row.telegramErrorCategory, TelegramErrorCategory.permanent.name);
    expect(row.nextRetryAt, isNull);
  });

  test('manual retry cannot bypass a Telegram flood gate', () async {
    final bucketId = await insertBucket('Photos', 1001);
    await insertFile(
      bucketId: bucketId,
      path: '/missing/waiting.jpg',
      status: FileSyncStatus.failed,
    );
    await reliability.registerError(
      TelegramErrorParser.parse({
        '@type': 'error',
        'code': 429,
        'message': 'FLOOD_WAIT_3600',
      }, operation: 'upload_media')!,
    );

    final retried = await uploader.retryFailed(bucketId: bucketId);
    final row = await db.select(db.files).getSingle();

    expect(retried, 0);
    expect(row.status, FileSyncStatus.failed.dbValue);
    expect(telegramGateway.requestCount('sendMessage'), 0);
  });

  test('free account rejects a 1950 MiB file', () async {
    final bucketId = await insertBucket('Photos', 1001);
    final media = await tempMedia('free-too-large.jpg');
    await insertFile(
      bucketId: bucketId,
      path: media.path,
      status: FileSyncStatus.pending,
      size: 1950 * 1024 * 1024,
    );

    await uploader.drainQueueForTesting(ignoreConstraints: true);
    final row = await db.select(db.files).getSingle();

    expect(row.status, FileSyncStatus.failed.dbValue);
    expect(row.userActionRequired, isTrue);
    expect(row.lastTelegramOperation, 'validate_upload_limit');
    expect(telegramGateway.requestCount('sendMessage'), 0);
  });

  test('Premium accepts 3900 MiB and rejects above the cap', () async {
    await reliability.updateAccountCapability(
      accountId: BigInt.from(123),
      isPremium: true,
    );
    final bucketId = await insertBucket('Premium', 1001);
    final accepted = await tempMedia('accepted.jpg');
    final rejected = await tempMedia('rejected.jpg');
    await insertFile(
      bucketId: bucketId,
      path: accepted.path,
      status: FileSyncStatus.pending,
      size: 3900 * 1024 * 1024,
      dateAdded: DateTime(2020),
    );
    await insertFile(
      bucketId: bucketId,
      path: rejected.path,
      status: FileSyncStatus.pending,
      size: 3901 * 1024 * 1024,
      dateAdded: DateTime(2021),
    );

    await uploader.drainQueueForTesting(ignoreConstraints: true);
    final rows = await db.select(db.files).get();

    expect(
      rows.singleWhere((row) => row.localPath == accepted.path).status,
      FileSyncStatus.synced.dbValue,
    );
    final rejectedRow = rows.singleWhere(
      (row) => row.localPath == rejected.path,
    );
    expect(rejectedRow.status, FileSyncStatus.failed.dbValue);
    expect(rejectedRow.userActionRequired, isTrue);
  });

  test('Premium expiry blocks oversized pending files', () async {
    await reliability.updateAccountCapability(
      accountId: BigInt.from(123),
      isPremium: true,
    );
    final bucketId = await insertBucket('Premium', 1001);
    await settingsService.saveSyncPreferences(
      const SyncPreferences(autoBackupEnabled: false),
      bucketId: bucketId,
    );
    final media = await tempMedia('premium-expired.jpg');
    await insertFile(
      bucketId: bucketId,
      path: media.path,
      status: FileSyncStatus.pending,
      size: 1950 * 1024 * 1024,
    );
    await uploader.startUploadLoop();

    await reliability.updateAccountCapability(
      accountId: BigInt.from(123),
      isPremium: false,
    );
    File row = await db.select(db.files).getSingle();
    for (
      var i = 0;
      i < 20 && row.status != FileSyncStatus.failed.dbValue;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      row = await db.select(db.files).getSingle();
    }

    expect(row.status, FileSyncStatus.failed.dbValue);
    expect(row.userActionRequired, isTrue);
    expect(row.nextRetryAt, isNull);
    expect(telegramGateway.requestCount('sendMessage'), 0);
  });
}

class _UploaderTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  final List<TelegramRequest> requests = [];
  final List<String> uploadedPaths = [];
  final List<String> sentInputFileTypes = [];
  final Completer<void> firstSendStarted = Completer<void>();
  Completer<void>? nextSendGate;
  TelegramResult? sendError;
  int activeSends = 0;
  int maxConcurrentSends = 0;
  int _nextMessageId = 100;
  final Map<int, TelegramResult> _sentMessages = {};

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  int requestCount(String type) =>
      requests.where((request) => request['@type'] == type).length;

  @override
  void send(TelegramRequest request) {
    requests.add(Map<String, dynamic>.from(request));
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    requests.add(Map<String, dynamic>.from(request));
    return switch ((request['@type'], request['name'])) {
      ('getOption', 'my_id') => {'@type': 'optionValueInteger', 'value': 123},
      ('getOption', 'is_premium') => {
        '@type': 'optionValueBoolean',
        'value': false,
      },
      ('getMe', _) => {'@type': 'user', 'id': 123, 'is_premium': false},
      ('getChat', _) => {'@type': 'chat', 'id': request['chat_id']},
      ('getMessage', _) =>
        _sentMessages[request['message_id']] ??
            {'@type': 'error', 'code': 404, 'message': 'MESSAGE_NOT_FOUND'},
      ('getMessages', _) => {
        '@type': 'messages',
        'total_count': (request['message_ids'] as List).length,
        'messages': (request['message_ids'] as List)
            .map((id) => _sentMessages[id])
            .toList(),
      },
      ('sendMessage', _) => await _sendMessage(request),
      _ => throw UnimplementedError(
        'Unexpected Telegram request: ${request['@type']}',
      ),
    };
  }

  Future<TelegramResult> _sendMessage(TelegramRequest request) async {
    activeSends++;
    if (activeSends > maxConcurrentSends) maxConcurrentSends = activeSends;
    if (!firstSendStarted.isCompleted) firstSendStarted.complete();
    final content = request['input_message_content'] as Map<String, dynamic>;
    final media =
        (content['document'] ?? content['photo'] ?? content['video'])
            as Map<String, dynamic>;
    final inputFile =
        (media['document'] ?? media['photo'] ?? media['video'])
            as Map<String, dynamic>;
    uploadedPaths.add(inputFile['path']?.toString() ?? '');
    sentInputFileTypes.add(inputFile['@type']?.toString() ?? '');
    try {
      final gate = nextSendGate;
      nextSendGate = null;
      if (gate != null) await gate.future;
      if (sendError != null) return sendError!;
      final id = _nextMessageId++;
      final message = {
        '@type': 'message',
        'id': id,
        'chat_id': request['chat_id'],
        'sending_state': null,
      };
      _sentMessages[id] = message;
      return message;
    } finally {
      activeSends--;
    }
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) => _updates.stream.firstWhere(predicate).timeout(timeout);

  @override
  Future<void> dispose() => _updates.close();
}

class _NoopSyncConstraintsService extends SyncConstraintsService {
  _NoopSyncConstraintsService(super.settingsService);

  @override
  Future<bool> canRunAutomaticSync({int? bucketId}) async => true;

  @override
  Stream<void> watchConstraintChanges() => const Stream.empty();
}
