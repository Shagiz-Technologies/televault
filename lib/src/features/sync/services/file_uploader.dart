import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/database/local_media_access_state.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../core/services/telegram_error.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/services/telegram_service.dart';
import '../../backup/services/auto_metadata_backup_service.dart';
import '../../settings/services/settings_service.dart';
import 'sync_constraints_service.dart';

final fileUploaderProvider = Provider<FileUploader>((ref) {
  final uploader = FileUploader(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(diagnosticsServiceProvider),
    ref.watch(syncConstraintsServiceProvider),
    ref.watch(telegramReliabilityServiceProvider),
    ref.watch(autoMetadataBackupServiceProvider),
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
  final AutoMetadataBackupService? _autoMetadataBackupService;
  final TelegramReliabilityService _telegramReliability;

  final _progressController = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _currentProgress = {};
  final Map<String, String> _uploadProgressAliases = {};

  StreamSubscription? _progressSub;
  StreamSubscription? _pendingSub;
  StreamSubscription? _constraintsSub;
  StreamSubscription<TelegramReliabilityState>? _telegramStateSub;
  Timer? _retryWakeTimer;
  DateTime? _scheduledWakeAt;
  _UploadWakeRequest? _queuedWake;
  bool _isUploading = false;
  bool _started = false;
  bool _disposed = false;
  bool _backgroundWakesSuspended = false;
  bool _accountCleanupRequested = false;

  FileUploader(
    this._db,
    this._telegramService,
    this._settingsService,
    this._diagnosticsService,
    this._constraintsService,
    this._telegramReliability, [
    this._autoMetadataBackupService,
  ]) {
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
    _accountCleanupRequested = false;
    if (_started) {
      wake();
      return;
    }
    _started = true;

    await _recoverInterruptedUploads();
    await _retryLegacyInputFileFailures();

    _pendingSub =
        (_db.select(_db.files)..where(
              (t) =>
                  t.status.isIn([
                    FileSyncStatus.pending.dbValue,
                    FileSyncStatus.failed.dbValue,
                  ]) &
                  t.localMediaAccessState.equals(
                    LocalMediaAccessState.available.dbValue,
                  ),
            ))
            .watch()
            .listen((_) => wake());
    _constraintsSub = _constraintsService.watchConstraintChanges().listen((_) {
      wake();
    });
    _telegramStateSub = _telegramReliability.states.listen((state) {
      unawaited(_handleTelegramState(state));
    });

    await _handleTelegramState(_telegramReliability.currentState);
    wake();
  }

  Future<void> _handleTelegramState(TelegramReliabilityState state) async {
    if (_disposed) return;
    await _applyAccountUploadLimit(state);
    if (state.isBlockedAt(DateTime.now())) {
      _scheduleWakeAt(state.blockedUntil);
    } else {
      wake();
    }
  }

  Future<void> _applyAccountUploadLimit(TelegramReliabilityState state) async {
    if (!state.capabilityResolved) return;
    final maxBytes = state.effectiveUploadLimitMb * 1024 * 1024;
    await (_db.update(_db.files)..where(
          (t) =>
              t.status.isIn([
                FileSyncStatus.pending.dbValue,
                FileSyncStatus.failed.dbValue,
              ]) &
              t.size.isBiggerThanValue(maxBytes),
        ))
        .write(
          FilesCompanion(
            status: Value(FileSyncStatus.failed.dbValue),
            lastError: Value(
              'This file exceeds the current Telegram account limit of '
              '${state.effectiveUploadLimitMb} MiB.',
            ),
            nextRetryAt: const Value(null),
            telegramErrorCode: const Value(null),
            telegramErrorCategory: Value(
              TelegramErrorCategory.userActionRequired.name,
            ),
            telegramRetryAfter: const Value(null),
            lastTelegramOperation: const Value('validate_upload_limit'),
            userActionRequired: const Value(true),
          ),
        );

    await (_db.update(_db.files)..where(
          (t) =>
              t.status.equals(FileSyncStatus.failed.dbValue) &
              t.lastTelegramOperation.equals('validate_upload_limit') &
              t.size.isSmallerOrEqualValue(maxBytes),
        ))
        .write(
          FilesCompanion(
            status: Value(FileSyncStatus.pending.dbValue),
            lastError: const Value(null),
            nextRetryAt: const Value(null),
            telegramErrorCode: const Value(null),
            telegramErrorCategory: const Value(null),
            telegramRetryAfter: const Value(null),
            lastTelegramOperation: const Value(null),
            userActionRequired: const Value(false),
          ),
        );
  }

  Future<void> _recoverInterruptedUploads() async {
    await (_db.update(
      _db.files,
    )..where((t) => t.status.equals(FileSyncStatus.uploading.dbValue))).write(
      FilesCompanion(
        status: Value(FileSyncStatus.pending.dbValue),
        lastError: const Value('Upload interrupted before completion'),
        nextRetryAt: const Value(null),
      ),
    );
  }

  Future<void> _retryLegacyInputFileFailures() async {
    await (_db.update(_db.files)..where(
          (t) =>
              t.status.equals(FileSyncStatus.failed.dbValue) &
              t.lastError.contains('InputFile is not specified'),
        ))
        .write(
          FilesCompanion(
            status: Value(FileSyncStatus.pending.dbValue),
            nextRetryAt: const Value(null),
            lastError: const Value(null),
            telegramErrorCode: const Value(null),
            telegramErrorCategory: const Value(null),
            telegramRetryAfter: const Value(null),
            lastTelegramOperation: const Value(null),
            userActionRequired: const Value(false),
          ),
        );
  }

  void wake({bool ignoreConstraints = false, int? bucketId}) {
    if (!_started ||
        _disposed ||
        _backgroundWakesSuspended ||
        _accountCleanupRequested) {
      return;
    }
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
    if (_accountCleanupRequested) return;
    if (!_backgroundWakesSuspended) return;
    _backgroundWakesSuspended = false;
    wake();
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

  Future<void> waitForCurrentUploadToFinish({
    Duration timeout = const Duration(minutes: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_isUploading && !_disposed) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Timed out waiting for the current upload.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
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
      while (!_disposed && !_accountCleanupRequested) {
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
          await _markFailed(
            nextFile,
            const _UploadFailure(
              message: 'The selected backup bucket no longer exists.',
              category: TelegramErrorCategory.permanent,
              canRetry: false,
              operation: 'resolve_bucket',
              continueQueue: true,
            ),
          );
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
              telegramErrorCode: const Value(null),
              telegramErrorCategory: const Value(null),
              telegramRetryAfter: const Value(null),
              lastTelegramOperation: const Value(null),
              userActionRequired: const Value(false),
            ),
          );
          unawaited(
            _diagnosticsService.increment(DiagnosticsService.uploadSuccessKey),
          );
          final autoMetadataBackupService = _autoMetadataBackupService;
          if (autoMetadataBackupService != null) {
            unawaited(autoMetadataBackupService.noteMediaUploadCompleted());
          }
        } on _LocalMediaAccessException {
          await (_db.update(
            _db.files,
          )..where((t) => t.id.equals(nextFile.id))).write(
            FilesCompanion(
              status: Value(FileSyncStatus.pending.dbValue),
              localMediaAccessState: Value(
                LocalMediaAccessState.accessUnavailable.dbValue,
              ),
              nextRetryAt: const Value(null),
              lastError: const Value(null),
            ),
          );
        } catch (error) {
          final failure = _normalizeFailure(error);
          await _markFailed(nextFile, failure);
          if (!failure.continueQueue) {
            break;
          }
        } finally {
          _currentProgress.remove(nextFile.localPath);
          _progressController.add(Map.from(_currentProgress));
        }

        if (_backgroundWakesSuspended) {
          break;
        }
      }
    } finally {
      _isUploading = false;
      unawaited(_scheduleNextWake());
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
    final gate = _telegramReliability.currentState;
    if (gate.isBlockedAt(DateTime.now())) {
      _scheduleWakeAt(gate.blockedUntil);
      return 0;
    }
    final failedRows =
        await (_db.select(_db.files)
              ..where(
                (t) =>
                    t.status.equals(FileSyncStatus.failed.dbValue) &
                    t.localMediaAccessState.equals(
                      LocalMediaAccessState.available.dbValue,
                    ) &
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

    final retryableRows = failedRows
        .where(
          (row) =>
              row.lastTelegramOperation != 'validate_upload_limit' ||
              _telegramReliability.canUploadBytes(row.size),
        )
        .toList();
    if (retryableRows.isEmpty) return 0;

    final ids = retryableRows.map((e) => e.id).toList();
    await (_db.update(_db.files)..where((t) => t.id.isIn(ids))).write(
      FilesCompanion(
        status: Value(FileSyncStatus.pending.dbValue),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
        telegramErrorCode: const Value(null),
        telegramErrorCategory: const Value(null),
        telegramRetryAfter: const Value(null),
        lastTelegramOperation: const Value(null),
        userActionRequired: const Value(false),
      ),
    );

    unawaited(
      _diagnosticsService.increment(
        DiagnosticsService.retryCountKey,
        by: ids.length,
      ),
    );

    wake(bucketId: bucketId);
    return ids.length;
  }

  Future<void> stopForAccountCleanup({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    _accountCleanupRequested = true;
    _backgroundWakesSuspended = true;
    _queuedWake = null;
    _retryWakeTimer?.cancel();
    _scheduledWakeAt = null;
    await _pendingSub?.cancel();
    await _constraintsSub?.cancel();
    await _telegramStateSub?.cancel();
    _pendingSub = null;
    _constraintsSub = null;
    _telegramStateSub = null;
    try {
      await waitForCurrentUploadToFinish(timeout: timeout);
    } on TimeoutException {
      // TDLib logout below terminates a request that did not finish in time.
    }
    _started = false;
    _currentProgress.clear();
    if (!_progressController.isClosed) {
      _progressController.add(const <String, double>{});
    }
  }

  Future<bool> _canUpload({required bool ignoreConstraints}) async {
    final reliability = _telegramReliability.currentState;
    if (reliability.isBlockedAt(DateTime.now())) {
      _scheduleWakeAt(reliability.blockedUntil);
      return false;
    }
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
                    t.localMediaAccessState.equals(
                      LocalMediaAccessState.available.dbValue,
                    ) &
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
                    t.localMediaAccessState.equals(
                      LocalMediaAccessState.available.dbValue,
                    ) &
                    (bucketId == null
                        ? const Constant(true)
                        : t.bucketId.equals(bucketId)) &
                    t.nextRetryAt.isNotNull() &
                    t.nextRetryAt.isSmallerOrEqualValue(now),
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

  Future<void> _markFailed(File file, _UploadFailure failure) async {
    final retry = file.retryCount + 1;
    final normalizedRetry = retry < 1 ? 1 : (retry > 6 ? 6 : retry);
    final backoffSeconds = (15 * (1 << (normalizedRetry - 1))).clamp(15, 900);
    final gate = _telegramReliability.currentState;
    final retryAt = failure.retryAfter != null
        ? gate.blockedUntil ?? DateTime.now().add(failure.retryAfter!)
        : failure.category == TelegramErrorCategory.transient &&
              failure.canRetry
        ? DateTime.now().add(Duration(seconds: backoffSeconds))
        : null;

    await (_db.update(_db.files)..where((t) => t.id.equals(file.id))).write(
      FilesCompanion(
        status: Value(FileSyncStatus.failed.dbValue),
        retryCount: Value(retry),
        nextRetryAt: Value(retryAt),
        lastError: Value(failure.message),
        telegramErrorCode: Value(failure.code),
        telegramErrorCategory: Value(failure.category.name),
        telegramRetryAfter: Value(
          failure.retryAfter == null
              ? null
              : gate.serverRetryUntil ??
                    DateTime.now().add(failure.retryAfter!),
        ),
        lastTelegramOperation: Value(failure.operation),
        userActionRequired: Value(failure.userActionRequired),
      ),
    );
    _scheduleWakeAt(retryAt);
    unawaited(
      _diagnosticsService.increment(DiagnosticsService.uploadFailureKey),
    );
  }

  _UploadFailure _normalizeFailure(Object error) {
    if (error is _LocalUploadException) return error.failure;
    if (error is TelegramError) {
      return _UploadFailure(
        message: error.userMessage,
        category: error.category,
        canRetry: error.canRetry,
        operation: error.operation,
        code: error.code,
        retryAfter: error.retryAfter,
        userActionRequired: error.userActionRequired,
        continueQueue: error.category == TelegramErrorCategory.permanent,
      );
    }
    final typed = TelegramErrorParser.fromThrown(
      error,
      operation: 'upload_media',
    );
    return _UploadFailure(
      message: typed.userMessage,
      category: typed.category,
      canRetry: typed.canRetry,
      operation: typed.operation,
      code: typed.code,
      retryAfter: typed.retryAfter,
      userActionRequired: typed.userActionRequired,
      continueQueue: false,
    );
  }

  Future<int> _uploadFile(File file, BigInt chatId) async {
    if (!_telegramReliability.canUploadBytes(file.size)) {
      final limit = _telegramReliability.effectiveUploadLimitMb;
      throw _LocalUploadException(
        _UploadFailure(
          message:
              'This file exceeds the current Telegram account limit of $limit MiB.',
          category: TelegramErrorCategory.userActionRequired,
          canRetry: false,
          operation: 'validate_upload_limit',
          userActionRequired: true,
          continueQueue: true,
        ),
      );
    }
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
      throw const _LocalUploadException(
        _UploadFailure(
          message: 'The local media file is no longer available.',
          category: TelegramErrorCategory.permanent,
          canRetry: false,
          operation: 'resolve_local_file',
          continueQueue: true,
        ),
      );
    }

    final asset = await AssetEntity.fromId(assetId);
    final resolved = await asset?.originFile ?? await asset?.file;
    if (resolved == null || !await resolved.exists()) {
      throw const _LocalMediaAccessException();
    }
    await (_db.update(
      _db.files,
    )..where((table) => table.id.equals(file.id))).write(
      FilesCompanion(
        localPath: Value(resolved.absolute.path),
        localPathResolved: const Value(true),
        localMediaAccessState: Value(LocalMediaAccessState.available.dbValue),
        size: Value(await resolved.length()),
      ),
    );
    return resolved;
  }

  Future<int> _sendFile(File file, BigInt chatId, String uploadPath) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) {
      throw TelegramError(
        code: null,
        tdlibMessage: 'Invalid Telegram chat id',
        operation: 'validate_bucket_chat',
        chatId: chatId,
        category: TelegramErrorCategory.permanent,
        canRetry: false,
      );
    }

    final chatInfo = await _telegramService.request({
      '@type': 'getChat',
      'chat_id': chatIdInt,
    }, timeout: const Duration(seconds: 20));
    if (chatInfo['@type'] == 'error') {
      final error = TelegramErrorParser.parse(
        chatInfo,
        operation: 'read_bucket_chat',
        chatId: chatId,
      )!;
      await _telegramReliability.registerError(error);
      throw error;
    }

    final preferences = await _settingsService.getSyncPreferences(
      bucketId: file.bucketId,
    );
    final content = _buildInputMessageContent(
      file,
      preferences.uploadFormat,
      uploadPath,
      {'@type': 'inputFileLocal', 'path': uploadPath},
    );
    return _telegramReliability.sendMessageAndWait(
      operation: 'upload_media',
      chatId: chatId,
      inputMessageContent: content,
      timeout: _sendCompletionTimeout(file.size),
    );
  }

  Map<String, dynamic> _buildInputMessageContent(
    File file,
    SyncUploadFormat uploadFormat,
    String uploadPath,
    Map<String, dynamic> inputFile,
  ) {
    final caption = {
      '@type': 'formattedText',
      'text':
          uploadFormat == SyncUploadFormat.compressedMedia &&
              _isCompressibleMedia(file)
          ? 'Backed up by TeleVault (compressed media)'
          : 'Backed up by TeleVault',
    };
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
      'thumbnail': null,
      'disable_content_type_detection': false,
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

  Future<void> _scheduleNextWake() async {
    if (_disposed) return;
    final gate = _telegramReliability.currentState;
    if (gate.isBlockedAt(DateTime.now())) {
      _scheduleWakeAt(gate.blockedUntil);
      return;
    }
    final row =
        await (_db.select(_db.files)
              ..where(
                (t) =>
                    t.status.equals(FileSyncStatus.failed.dbValue) &
                    t.localMediaAccessState.equals(
                      LocalMediaAccessState.available.dbValue,
                    ) &
                    t.nextRetryAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.nextRetryAt)])
              ..limit(1))
            .getSingleOrNull();
    _scheduleWakeAt(row?.nextRetryAt);
  }

  void _scheduleWakeAt(DateTime? wakeAt) {
    if (_disposed || wakeAt == null) return;
    if (_scheduledWakeAt == wakeAt && _retryWakeTimer?.isActive == true) {
      return;
    }
    _retryWakeTimer?.cancel();
    _scheduledWakeAt = wakeAt;
    final delay = wakeAt.difference(DateTime.now());
    _retryWakeTimer = Timer(delay > Duration.zero ? delay : Duration.zero, () {
      _scheduledWakeAt = null;
      wake();
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queuedWake = null;
    await _progressSub?.cancel();
    await _pendingSub?.cancel();
    await _constraintsSub?.cancel();
    await _telegramStateSub?.cancel();
    _retryWakeTimer?.cancel();
    await _progressController.close();
  }
}

class _UploadWakeRequest {
  final bool ignoreConstraints;
  final int? bucketId;

  const _UploadWakeRequest({required this.ignoreConstraints, this.bucketId});
}

class _UploadFailure {
  final String message;
  final TelegramErrorCategory category;
  final bool canRetry;
  final String operation;
  final int? code;
  final Duration? retryAfter;
  final bool userActionRequired;
  final bool continueQueue;

  const _UploadFailure({
    required this.message,
    required this.category,
    required this.canRetry,
    required this.operation,
    required this.continueQueue,
    this.code,
    this.retryAfter,
    this.userActionRequired = false,
  });
}

class _LocalUploadException implements Exception {
  final _UploadFailure failure;

  const _LocalUploadException(this.failure);

  @override
  String toString() => failure.message;
}

class _LocalMediaAccessException implements Exception {
  const _LocalMediaAccessException();
}
