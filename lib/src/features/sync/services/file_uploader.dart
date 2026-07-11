import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_service.dart';
import '../../settings/services/settings_service.dart';
import 'sync_constraints_service.dart';

final fileUploaderProvider = Provider<FileUploader>((ref) {
  final uploader = FileUploader(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(diagnosticsServiceProvider),
    ref.watch(syncConstraintsServiceProvider),
  );
  ref.onDispose(() {
    uploader.dispose();
  });
  return uploader;
});

class FileUploader {
  final AppDatabase _db;
  final TelegramGateway _telegramService;
  final SettingsService _settingsService;
  final DiagnosticsService _diagnosticsService;
  final SyncConstraintsService _constraintsService;

  final _progressController = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _currentProgress = {};
  final Map<String, String> _uploadProgressAliases = {};

  StreamSubscription? _progressSub;
  StreamSubscription? _pendingSub;
  StreamSubscription? _constraintsSub;
  Timer? _retryWakeTimer;
  _UploadWakeRequest? _queuedWake;
  bool _isUploading = false;
  bool _started = false;
  bool _disposed = false;
  bool _backgroundWakesSuspended = false;

  FileUploader(
    this._db,
    this._telegramService,
    this._settingsService,
    this._diagnosticsService,
    this._constraintsService,
  ) {
    _initProgressListener();
  }

  Stream<Map<String, double>> get progress => _progressController.stream;

  void _initProgressListener() {
    _progressSub = _telegramService.updates.listen((update) {
      if (update['@type'] != 'updateFile') return;

      final file = update['file'] as Map<String, dynamic>?;
      if (file == null) return;

      final localPath = file['local']?['path'] as String?;
      final remote = file['remote'] as Map<String, dynamic>?;
      if (localPath == null || remote == null) return;
      final progressKey = _uploadProgressAliases[localPath] ?? localPath;

      final isUploading = remote['is_uploading_active'] == true;
      final uploadedSize = _extractInt(remote['uploaded_size']) ?? 0;
      final expectedSize = (_extractInt(file['expected_size']) ?? 1).clamp(
        1,
        1 << 31,
      );

      if (isUploading) {
        final percent = (uploadedSize / expectedSize)
            .clamp(0.0, 1.0)
            .toDouble();
        _currentProgress[progressKey] = percent;
        _progressController.add(Map.from(_currentProgress));
      } else if (remote['is_uploading_completed'] == true) {
        _currentProgress.remove(progressKey);
        _progressController.add(Map.from(_currentProgress));
      }
    });
  }

  Future<void> startUploadLoop() async {
    if (_started) {
      wake();
      return;
    }
    _started = true;

    _pendingSub =
        (_db.select(_db.files)..where(
              (t) => t.status.isIn([
                FileSyncStatus.pending.dbValue,
                FileSyncStatus.failed.dbValue,
              ]),
            ))
            .watch()
            .listen((_) => wake());
    _constraintsSub = _constraintsService.watchConstraintChanges().listen((_) {
      wake();
    });

    _retryWakeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      wake();
    });

    wake();
  }

  void wake({bool ignoreConstraints = false, int? bucketId}) {
    if (!_started || _disposed || _backgroundWakesSuspended) return;
    if (_isUploading) {
      _queuedWake = _mergeQueuedWake(
        _queuedWake,
        _UploadWakeRequest(
          ignoreConstraints: ignoreConstraints,
          bucketId: bucketId,
        ),
      );
      return;
    }
    unawaited(
      _processQueue(ignoreConstraints: ignoreConstraints, bucketId: bucketId),
    );
  }

  void suspendBackgroundWakes() {
    _backgroundWakesSuspended = true;
    _queuedWake = null;
  }

  void resumeBackgroundWakes() {
    if (!_backgroundWakesSuspended) return;
    _backgroundWakesSuspended = false;
    wake(ignoreConstraints: true);
  }

  _UploadWakeRequest _mergeQueuedWake(
    _UploadWakeRequest? current,
    _UploadWakeRequest next,
  ) {
    if (current == null || next.ignoreConstraints) return next;
    if (current.ignoreConstraints) return current;
    return next;
  }

  Future<void> drainQueueForTesting({
    bool ignoreConstraints = false,
    int? bucketId,
  }) {
    return drainQueue(ignoreConstraints: ignoreConstraints, bucketId: bucketId);
  }

  Future<void> drainQueue({bool ignoreConstraints = false, int? bucketId}) {
    if (_isUploading) {
      return _waitThenDrainQueue(
        ignoreConstraints: ignoreConstraints,
        bucketId: bucketId,
      );
    }
    return _processQueue(
      ignoreConstraints: ignoreConstraints,
      bucketId: bucketId,
    );
  }

  Future<void> _waitThenDrainQueue({
    required bool ignoreConstraints,
    int? bucketId,
  }) async {
    while (_isUploading && !_disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (_disposed) return;
    return _processQueue(
      ignoreConstraints: ignoreConstraints,
      bucketId: bucketId,
    );
  }

  Future<void> _processQueue({
    required bool ignoreConstraints,
    int? bucketId,
  }) async {
    if (_isUploading || _disposed) return;
    _isUploading = true;

    try {
      while (!_disposed) {
        if (!await _canUpload(ignoreConstraints: ignoreConstraints)) {
          break;
        }

        final nextFile = await _nextUploadCandidate(
          ignoreConstraints: ignoreConstraints,
          bucketId: bucketId,
        );
        if (nextFile == null) {
          break;
        }

        final bucket = await (_db.select(
          _db.buckets,
        )..where((t) => t.id.equals(nextFile.bucketId))).getSingleOrNull();
        if (bucket == null) {
          await _markFailed(nextFile, 'Active bucket no longer exists');
          continue;
        }

        await (_db.update(
          _db.files,
        )..where((t) => t.id.equals(nextFile.id))).write(
          FilesCompanion(
            status: Value(FileSyncStatus.uploading.dbValue),
            lastAttemptAt: Value(DateTime.now()),
            lastError: const Value(null),
          ),
        );

        _currentProgress[nextFile.localPath] = 0.0;
        _progressController.add(Map.from(_currentProgress));

        try {
          final messageId = await _uploadFile(nextFile, bucket.chatId);
          await (_db.update(
            _db.files,
          )..where((t) => t.id.equals(nextFile.id))).write(
            FilesCompanion(
              status: Value(FileSyncStatus.synced.dbValue),
              telegramMessageId: Value(messageId),
              retryCount: const Value(0),
              nextRetryAt: const Value(null),
              lastError: const Value(null),
            ),
          );
          unawaited(
            _diagnosticsService.increment(DiagnosticsService.uploadSuccessKey),
          );
        } catch (e) {
          await _markFailed(nextFile, e.toString());
        } finally {
          _currentProgress.remove(nextFile.localPath);
          _progressController.add(Map.from(_currentProgress));
        }
      }
    } finally {
      _isUploading = false;
      final queuedWake = _queuedWake;
      _queuedWake = null;
      if (queuedWake != null && !_disposed) {
        wake(
          ignoreConstraints: queuedWake.ignoreConstraints,
          bucketId: queuedWake.bucketId,
        );
      }
    }
  }

  Future<int> retryFailed({int? limit, int? bucketId}) async {
    final failedRows =
        await (_db.select(_db.files)
              ..where(
                (t) =>
                    t.status.equals(FileSyncStatus.failed.dbValue) &
                    (bucketId == null
                        ? const Constant(true)
                        : t.bucketId.equals(bucketId)),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.nextRetryAt,
                  mode: OrderingMode.asc,
                ),
                (t) => OrderingTerm.asc(t.dateAdded),
              ])
              ..limit(limit ?? 100000))
            .get();

    if (failedRows.isEmpty) return 0;

    final ids = failedRows.map((e) => e.id).toList();
    await (_db.update(_db.files)..where((t) => t.id.isIn(ids))).write(
      FilesCompanion(
        status: Value(FileSyncStatus.pending.dbValue),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
      ),
    );

    unawaited(
      _diagnosticsService.increment(
        DiagnosticsService.retryCountKey,
        by: ids.length,
      ),
    );

    wake(ignoreConstraints: true, bucketId: bucketId);
    return ids.length;
  }

  Future<bool> _canUpload({required bool ignoreConstraints}) async {
    return true;
  }

  Future<File?> _nextUploadCandidate({
    required bool ignoreConstraints,
    int? bucketId,
  }) async {
    final pending =
        await (_db.select(_db.files)
              ..where(
                (t) =>
                    t.status.equals(FileSyncStatus.pending.dbValue) &
                    (bucketId == null
                        ? const Constant(true)
                        : t.bucketId.equals(bucketId)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.dateAdded)])
              ..limit(100))
            .get();
    final pendingCandidate = await _firstAllowedCandidate(
      pending,
      ignoreConstraints: ignoreConstraints,
      bucketId: bucketId,
    );
    if (pendingCandidate != null) return pendingCandidate;

    final now = DateTime.now();
    final failedCandidates =
        await (_db.select(_db.files)
              ..where(
                (t) =>
                    t.status.equals(FileSyncStatus.failed.dbValue) &
                    (bucketId == null
                        ? const Constant(true)
                        : t.bucketId.equals(bucketId)) &
                    (t.nextRetryAt.isNull() |
                        t.nextRetryAt.isSmallerOrEqualValue(now)),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.nextRetryAt,
                  mode: OrderingMode.asc,
                ),
                (t) => OrderingTerm.asc(t.dateAdded),
              ])
              ..limit(100))
            .get();
    return _firstAllowedCandidate(
      failedCandidates,
      ignoreConstraints: ignoreConstraints,
      bucketId: bucketId,
    );
  }

  Future<File?> _firstAllowedCandidate(
    List<File> candidates, {
    required bool ignoreConstraints,
    int? bucketId,
  }) async {
    for (final candidate in candidates) {
      if (bucketId != null && candidate.bucketId != bucketId) continue;
      if (ignoreConstraints) return candidate;
      final preferences = await _settingsService.getSyncPreferences(
        bucketId: candidate.bucketId,
      );
      final constraintsAllowed = await _constraintsService.canRunAutomaticSync(
        bucketId: candidate.bucketId,
      );
      if (preferences.autoBackupEnabled && constraintsAllowed) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _markFailed(File file, String error) async {
    final retry = file.retryCount + 1;
    final normalizedRetry = retry < 1 ? 1 : (retry > 6 ? 6 : retry);
    final backoffSeconds = (15 * (1 << (normalizedRetry - 1))).clamp(15, 900);
    final retryAt = DateTime.now().add(Duration(seconds: backoffSeconds));

    await (_db.update(_db.files)..where((t) => t.id.equals(file.id))).write(
      FilesCompanion(
        status: Value(FileSyncStatus.failed.dbValue),
        retryCount: Value(retry),
        nextRetryAt: Value(retryAt),
        lastError: Value(error),
      ),
    );
    unawaited(
      _diagnosticsService.increment(DiagnosticsService.uploadFailureKey),
    );
  }

  Future<int> _uploadFile(File file, BigInt chatId) async {
    final localFile = await _resolveUploadFile(file);
    final uploadPath = localFile.absolute.path;
    _uploadProgressAliases[uploadPath] = file.localPath;

    try {
      return await _sendFile(file, chatId, uploadPath);
    } finally {
      _uploadProgressAliases.remove(uploadPath);
    }
  }

  Future<io.File> _resolveUploadFile(File file) async {
    final storedFile = io.File(file.localPath);
    if (await storedFile.exists()) return storedFile;

    // Encrypted vault paths must never fall back to the original gallery item.
    final assetId = file.assetId;
    if (file.isEncrypted || assetId == null || assetId.isEmpty) {
      throw Exception('The local media file is no longer available.');
    }

    final asset = await AssetEntity.fromId(assetId);
    final resolved = await asset?.originFile ?? await asset?.file;
    if (resolved == null || !await resolved.exists()) {
      throw Exception('The gallery item is no longer available.');
    }
    return resolved;
  }

  Future<int> _sendFile(File file, BigInt chatId, String uploadPath) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) {
      throw Exception('Invalid Telegram chat id');
    }

    final chatInfo = await _telegramService.request({
      '@type': 'getChat',
      'chat_id': chatIdInt,
    }, timeout: const Duration(seconds: 20));
    if (chatInfo['@type'] == 'error') {
      throw Exception(chatInfo['message'] ?? 'Unable to access bucket channel');
    }

    final preferences = await _settingsService.getSyncPreferences(
      bucketId: file.bucketId,
    );
    final content = _buildInputMessageContent(
      file,
      preferences.uploadFormat,
      uploadPath,
    );

    final response = await _telegramService.request({
      '@type': 'sendMessage',
      'chat_id': chatIdInt,
      'input_message_content': content,
    }, timeout: const Duration(seconds: 90));

    if (response['@type'] == 'error') {
      throw Exception(response['message'] ?? 'Telegram sendMessage failed');
    }
    if (response['@type'] != 'message') {
      throw Exception('Unexpected response: ${response['@type']}');
    }

    final tempMessageId = _extractInt(response['id']);
    if (tempMessageId == null) {
      throw Exception('Telegram message id missing');
    }

    final sendingStateType = response['sending_state']?['@type']?.toString();
    if (sendingStateType == null) {
      return tempMessageId;
    }

    final sendUpdate = await _telegramService.waitForUpdate((update) {
      final type = update['@type'];
      if (type == 'updateMessageSendSucceeded') {
        final oldId = _extractInt(update['old_message_id']);
        final updateChat = update['message']?['chat_id']?.toString();
        return oldId == tempMessageId && updateChat == chatId.toString();
      }
      if (type == 'updateMessageSendFailed') {
        final oldId = _extractInt(update['old_message_id']);
        final updateChat = update['message']?['chat_id']?.toString();
        return oldId == tempMessageId && updateChat == chatId.toString();
      }
      return false;
    }, timeout: _sendCompletionTimeout(file.size));

    if (sendUpdate['@type'] == 'updateMessageSendFailed') {
      final err =
          sendUpdate['error_message']?.toString() ?? 'Telegram send failed';
      throw Exception(err);
    }

    return _extractInt(sendUpdate['message']?['id']) ?? tempMessageId;
  }

  Map<String, dynamic> _buildInputMessageContent(
    File file,
    SyncUploadFormat uploadFormat,
    String uploadPath,
  ) {
    final caption = {
      '@type': 'formattedText',
      'text':
          uploadFormat == SyncUploadFormat.compressedMedia &&
              _isCompressibleMedia(file)
          ? 'Backed up by TeleVault (compressed media)'
          : 'Backed up by TeleVault',
    };
    final inputFile = {'@type': 'inputFileLocal', 'path': uploadPath};

    if (uploadFormat == SyncUploadFormat.compressedMedia &&
        _isCompressibleMedia(file)) {
      if (_isImagePath(uploadPath)) {
        return {
          '@type': 'inputMessagePhoto',
          'photo': inputFile,
          'thumbnail': null,
          'added_sticker_file_ids': <int>[],
          'width': 0,
          'height': 0,
          'caption': caption,
        };
      }
      if (_isVideoPath(uploadPath)) {
        return {
          '@type': 'inputMessageVideo',
          'video': inputFile,
          'thumbnail': null,
          'added_sticker_file_ids': <int>[],
          'duration': 0,
          'width': 0,
          'height': 0,
          'supports_streaming': true,
          'caption': caption,
        };
      }
    }

    return {
      '@type': 'inputMessageDocument',
      'document': inputFile,
      'caption': caption,
    };
  }

  bool _isCompressibleMedia(File file) {
    if (file.isEncrypted || file.isVaulted) return false;
    return _isImagePath(file.localPath) || _isVideoPath(file.localPath);
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.3gp');
  }

  Duration _sendCompletionTimeout(int sizeBytes) {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return const Duration(minutes: 35);
    }
    if (sizeBytes >= 500 * 1024 * 1024) {
      return const Duration(minutes: 25);
    }
    if (sizeBytes >= 100 * 1024 * 1024) {
      return const Duration(minutes: 15);
    }
    return const Duration(minutes: 8);
  }

  int? _toTdInt64(BigInt value) {
    try {
      return value.toInt();
    } catch (_) {
      return null;
    }
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queuedWake = null;
    await _progressSub?.cancel();
    await _pendingSub?.cancel();
    await _constraintsSub?.cancel();
    _retryWakeTimer?.cancel();
    await _progressController.close();
  }
}

class _UploadWakeRequest {
  final bool ignoreConstraints;
  final int? bucketId;

  const _UploadWakeRequest({required this.ignoreConstraints, this.bucketId});
}
