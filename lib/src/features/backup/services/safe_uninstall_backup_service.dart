import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/services/telegram_service.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_service.dart';
import 'metadata_backup_service.dart';

final safeUninstallBackupServiceProvider = Provider<SafeUninstallBackupService>(
  (ref) {
    return SafeUninstallBackupService(
      ref.watch(databaseProvider),
      ref.watch(telegramServiceProvider),
      ref.watch(metadataBackupServiceProvider),
      ref.watch(syncServiceProvider),
      ref.watch(fileUploaderProvider),
    );
  },
);

enum SafeUninstallStep {
  scanning,
  uploadingMedia,
  exportingMetadata,
  uploadingMetadata,
  complete,
}

class SafeUninstallBackupResult {
  final int messageId;
  final String bucketName;
  final DateTime completedAt;

  const SafeUninstallBackupResult({
    required this.messageId,
    required this.bucketName,
    required this.completedAt,
  });
}

class SafeUninstallRestoreResult {
  final int messageId;
  final BigInt chatId;

  const SafeUninstallRestoreResult({
    required this.messageId,
    required this.chatId,
  });
}

class SafeUninstallBackupService {
  final AppDatabase _db;
  final TelegramService _telegram;
  final MetadataBackupService _metadataBackupService;
  final SyncService _syncService;
  final FileUploader _fileUploader;

  static const marker = '#TeleVaultSafeUninstallMetadataV1';
  static const _captionPrefix = 'TeleVault Safe Uninstall Metadata';
  bool _safeUninstallRunning = false;

  SafeUninstallBackupService(
    this._db,
    this._telegram,
    this._metadataBackupService,
    this._syncService,
    this._fileUploader,
  );

  Future<SafeUninstallBackupResult> createSafeUninstallBackup({
    required String passphrase,
    void Function(SafeUninstallStep step)? onStep,
  }) async {
    if (_safeUninstallRunning) {
      throw Exception('Safe Uninstall backup is already running.');
    }
    _safeUninstallRunning = true;
    var completed = false;

    final bucket = await _activeBucket();
    if (bucket == null) {
      _safeUninstallRunning = false;
      throw Exception('Create or select a bucket before Safe Uninstall.');
    }

    // Stop periodic scanning before the final pass so nothing can be enqueued
    // after the metadata snapshot. This keeps metadata as the final Telegram
    // backup item for the Safe Uninstall sequence.
    _syncService.stopSyncLoop();
    _fileUploader.suspendBackgroundWakes();

    try {
      onStep?.call(SafeUninstallStep.scanning);
      await _syncService.scanAndEnqueueAllBucketsForSafeUninstall();

      onStep?.call(SafeUninstallStep.uploadingMedia);
      await _flushUploadsBeforeMetadata();

      // One final scan+drain pass closes the race between the first queue drain
      // and metadata export. If anything remains unresolved, metadata is not
      // uploaded.
      onStep?.call(SafeUninstallStep.scanning);
      await _syncService.scanAndEnqueueAllBucketsForSafeUninstall();
      onStep?.call(SafeUninstallStep.uploadingMedia);
      await _flushUploadsBeforeMetadata();

      onStep?.call(SafeUninstallStep.exportingMetadata);
      final snapshot = await _metadataBackupService.exportEncryptedSnapshot(
        passphrase: passphrase,
      );

      // No file rows should be pending immediately before the final metadata
      // send. This is intentionally after export so metadata is still blocked
      // if any last media item appeared during export.
      await _flushUploadsBeforeMetadata();

      onStep?.call(SafeUninstallStep.uploadingMetadata);
      final messageId = await _uploadMetadataSnapshot(snapshot, bucket);
      await _writeSafeUninstallAudit(messageId, bucket);

      completed = true;
      onStep?.call(SafeUninstallStep.complete);
      return SafeUninstallBackupResult(
        messageId: messageId,
        bucketName: bucket.name,
        completedAt: DateTime.now(),
      );
    } finally {
      _safeUninstallRunning = false;
      if (!completed) {
        _fileUploader.resumeBackgroundWakes();
        _syncService.startSyncLoop();
      }
    }
  }

  Future<SafeUninstallRestoreResult> restoreLatestFromTelegram({
    required String passphrase,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Looking for TeleVault metadata in your Telegram chats...');
    final message = await _findLatestSafeUninstallMessage();
    if (message == null) {
      throw Exception(
        'No Safe Uninstall metadata was found in your Telegram channels.',
      );
    }

    onStatus?.call('Downloading encrypted metadata...');
    final snapshot = await _downloadSnapshotFromMessage(message);

    onStatus?.call('Importing metadata...');
    await _metadataBackupService.importEncryptedSnapshot(
      snapshot,
      passphrase: passphrase,
    );

    final chatId = _extractBigInt(message['chat_id']) ?? BigInt.zero;
    final messageId = _extractInt(message['id']) ?? 0;
    return SafeUninstallRestoreResult(messageId: messageId, chatId: chatId);
  }

  Future<Bucket?> _activeBucket() async {
    final active =
        await (_db.select(_db.buckets)
              ..where((t) => t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (active.isNotEmpty) return active.first;

    final buckets =
        await (_db.select(_db.buckets)
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .get();
    if (buckets.isEmpty) return null;
    return buckets.first;
  }

  Future<void> _resetInterruptedUploads() async {
    await (_db.update(_db.files)
          ..where((t) => t.status.equals(FileSyncStatus.uploading.dbValue)))
        .write(FilesCompanion(status: Value(FileSyncStatus.pending.dbValue)));
  }

  Future<void> _flushUploadsBeforeMetadata() async {
    await _resetInterruptedUploads();
    await _fileUploader.retryFailed();
    await _fileUploader.drainQueue(ignoreConstraints: true);
    final unresolved = await _unresolvedUploadCount();
    if (unresolved > 0) {
      throw Exception(
        '$unresolved item(s) are still not backed up. Metadata was not uploaded, because it must be the final Safe Uninstall backup item.',
      );
    }
  }

  Future<int> _unresolvedUploadCount() {
    return _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM files WHERE status IN (?, ?, ?)',
          variables: [
            Variable<int>(FileSyncStatus.pending.dbValue),
            Variable<int>(FileSyncStatus.uploading.dbValue),
            Variable<int>(FileSyncStatus.failed.dbValue),
          ],
          readsFrom: {_db.files},
        )
        .map((row) => row.read<int>('c'))
        .getSingle();
  }

  Future<int> _uploadMetadataSnapshot(io.File snapshot, Bucket bucket) async {
    final chatId = _toTdInt64(bucket.chatId);
    if (chatId == null) {
      throw Exception('Invalid active bucket chat id.');
    }

    final captionText =
        '$_captionPrefix\n$marker\nCreated: ${DateTime.now().toIso8601String()}';

    final response = await _telegram.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': snapshot.path},
        'caption': {'@type': 'formattedText', 'text': captionText},
      },
    }, timeout: const Duration(minutes: 3));

    if (response['@type'] == 'error') {
      throw Exception(
        response['message'] ?? 'Unable to upload Safe Uninstall metadata.',
      );
    }
    if (response['@type'] != 'message') {
      throw Exception('Unexpected Telegram response: ${response['@type']}');
    }

    final tempMessageId = _extractInt(response['id']);
    if (tempMessageId == null) {
      throw Exception('Telegram message id missing for metadata upload.');
    }

    final sendingStateType = response['sending_state']?['@type']?.toString();
    if (sendingStateType == null) return tempMessageId;

    final update = await _telegram.waitForUpdate((event) {
      final type = event['@type'];
      if (type != 'updateMessageSendSucceeded' &&
          type != 'updateMessageSendFailed') {
        return false;
      }
      final oldId = _extractInt(event['old_message_id']);
      final updateChat = event['message']?['chat_id']?.toString();
      return oldId == tempMessageId && updateChat == bucket.chatId.toString();
    }, timeout: const Duration(minutes: 5));

    if (update['@type'] == 'updateMessageSendFailed') {
      throw Exception(
        update['error_message']?.toString() ??
            'Safe Uninstall metadata upload failed.',
      );
    }

    return _extractInt(update['message']?['id']) ?? tempMessageId;
  }

  Future<void> _writeSafeUninstallAudit(int messageId, Bucket bucket) async {
    final entries = {
      'safe_uninstall_last_backup_at': DateTime.now().toIso8601String(),
      'safe_uninstall_last_message_id': messageId.toString(),
      'safe_uninstall_last_bucket_chat_id': bucket.chatId.toString(),
    };

    for (final entry in entries.entries) {
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: entry.key, value: entry.value),
          );
    }
  }

  Future<Map<String, dynamic>?> _findLatestSafeUninstallMessage() async {
    final chatIds = await _loadChatIds();
    Map<String, dynamic>? latest;

    for (final chatId in chatIds) {
      final message = await _findSafeUninstallMessageInChat(chatId);
      if (message == null) continue;
      final latestDate = _extractInt(latest?['date']) ?? 0;
      final messageDate = _extractInt(message['date']) ?? 0;
      if (latest == null || messageDate >= latestDate) {
        latest = message;
      }
    }

    return latest;
  }

  Future<List<BigInt>> _loadChatIds() async {
    final response = await _telegram.request({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 500,
    }, timeout: const Duration(seconds: 30));

    if (response['@type'] == 'error') {
      throw Exception(response['message'] ?? 'Unable to read Telegram chats.');
    }

    final ids = response['chat_ids'] as List<dynamic>? ?? const [];
    return ids.map(_extractBigInt).whereType<BigInt>().toList();
  }

  Future<Map<String, dynamic>?> _findSafeUninstallMessageInChat(
    BigInt chatId,
  ) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) return null;

    final searched = await _searchChatMessages(chatIdInt);
    if (searched != null) return searched;

    final history = await _telegram.request({
      '@type': 'getChatHistory',
      'chat_id': chatIdInt,
      'from_message_id': 0,
      'offset': 0,
      'limit': 100,
      'only_local': false,
    }, timeout: const Duration(seconds: 20));

    if (history['@type'] == 'error') return null;
    final messages = history['messages'] as List<dynamic>? ?? const [];
    for (final raw in messages.cast<Map<String, dynamic>>()) {
      if (_messageHasSafeUninstallMarker(raw)) return raw;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _searchChatMessages(int chatId) async {
    final response = await _telegram.request({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': marker,
      'sender_id': null,
      'from_message_id': 0,
      'offset': 0,
      'limit': 10,
      'filter': {'@type': 'searchMessagesFilterDocument'},
      'message_thread_id': 0,
    }, timeout: const Duration(seconds: 20));

    if (response['@type'] == 'error') return null;
    final messages = response['messages'] as List<dynamic>? ?? const [];
    for (final raw in messages.cast<Map<String, dynamic>>()) {
      if (_messageHasSafeUninstallMarker(raw)) return raw;
    }
    return null;
  }

  bool _messageHasSafeUninstallMarker(Map<String, dynamic> message) {
    final content = message['content'] as Map<String, dynamic>?;
    final caption = content?['caption'] as Map<String, dynamic>?;
    final text = caption?['text']?.toString() ?? '';
    return text.contains(marker);
  }

  Future<io.File> _downloadSnapshotFromMessage(
    Map<String, dynamic> message,
  ) async {
    final content = message['content'] as Map<String, dynamic>?;
    final document = content?['document'] as Map<String, dynamic>?;
    final file = document?['document'] as Map<String, dynamic>?;
    final fileId = _extractInt(file?['id']);
    if (fileId == null) {
      throw Exception('Safe Uninstall metadata message has no document file.');
    }

    final response = await _telegram.request({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 32,
      'offset': 0,
      'limit': 0,
      'synchronous': true,
    }, timeout: const Duration(minutes: 3));

    if (response['@type'] == 'error') {
      throw Exception(response['message'] ?? 'Unable to download metadata.');
    }

    final localPath = response['local']?['path']?.toString();
    if (localPath == null || localPath.isEmpty) {
      throw Exception('Downloaded metadata file path is unavailable.');
    }

    final snapshot = io.File(localPath);
    if (!await snapshot.exists()) {
      throw Exception('Downloaded metadata file was not found on disk.');
    }
    return snapshot;
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

  BigInt? _extractBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) return BigInt.tryParse(value);
    return null;
  }
}
