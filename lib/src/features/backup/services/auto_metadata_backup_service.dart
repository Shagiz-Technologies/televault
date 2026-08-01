import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_runtime_environment.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_error.dart';
import '../../../core/services/telegram_message_content.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/services/telegram_service.dart';
import 'metadata_backup_service.dart';
import 'metadata_operation_lock.dart';

final autoMetadataBackupServiceProvider = Provider<AutoMetadataBackupService>((
  ref,
) {
  final service = AutoMetadataBackupService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(metadataBackupServiceProvider),
    ref.watch(telegramReliabilityServiceProvider),
    ref.watch(metadataOperationLockProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

class AutoMetadataBackupResult {
  final BigInt chatId;
  final int messageId;
  final DateTime completedAt;

  const AutoMetadataBackupResult({
    required this.chatId,
    required this.messageId,
    required this.completedAt,
  });
}

class AutoMetadataRestoreResult {
  final BigInt chatId;
  final int messageId;

  const AutoMetadataRestoreResult({
    required this.chatId,
    required this.messageId,
  });
}

class AutoMetadataBackupStatus {
  final int uploadedSinceBackup;
  final int backupEveryFiles;
  final DateTime? lastBackupAt;
  final String? lastError;

  const AutoMetadataBackupStatus({
    required this.uploadedSinceBackup,
    required this.backupEveryFiles,
    required this.lastBackupAt,
    required this.lastError,
  });
}

class AutoMetadataBackupService {
  final AppDatabase _db;
  final TelegramGateway _telegram;
  final MetadataBackupService _metadataBackupService;
  final TelegramReliabilityService _telegramReliability;
  final MetadataOperationLock _operationLock;
  final Future<io.Directory> Function() _temporaryDirectoryProvider;

  static const channelTitle = 'TeleVault';
  static const channelDescription =
      'Created by Televault - By Shagiz Technologies';
  static const marker = '#TeleVaultMetadataBackupV1';
  static const defaultBackupEveryFiles = 5;
  static const minBackupEveryFiles = 5;

  static const _keyChatId = 'metadata_default_channel_chat_id';
  static const _keyLastMessageId = 'metadata_default_channel_message_id';
  static const _keyUploadedSinceBackup = 'metadata_uploaded_since_backup';
  static const _keyBackupEveryFiles = 'metadata_backup_every_files';
  static const _keyLastBackupAt = 'metadata_last_backup_at';
  static const _keyLastError = 'metadata_last_backup_error';
  static const _keyVerifiedSnapshots = 'metadata_verified_snapshots_v5';
  static const _captionPrefix = 'TeleVault Metadata Backup';
  static const remoteSnapshotRetention = 2;

  bool _automaticBackupQueued = false;
  StreamSubscription<TelegramReliabilityState>? _telegramStateSubscription;

  AutoMetadataBackupService(
    this._db,
    this._telegram,
    this._metadataBackupService,
    this._telegramReliability, [
    MetadataOperationLock? operationLock,
    Future<io.Directory> Function()? temporaryDirectoryProvider,
  ]) : _operationLock = operationLock ?? MetadataOperationLock(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory {
    _telegramStateSubscription = _telegramReliability.states.listen((state) {
      if (!state.isBlockedAt(DateTime.now())) {
        unawaited(_retryThresholdBackup());
      }
    });
  }

  Future<int> getBackupEveryFiles() async {
    final raw = await _getSetting(_keyBackupEveryFiles);
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed < minBackupEveryFiles) {
      return defaultBackupEveryFiles;
    }
    return parsed;
  }

  Future<void> setBackupEveryFiles(int value) async {
    final normalized = value < minBackupEveryFiles
        ? minBackupEveryFiles
        : value;
    await _setSetting(_keyBackupEveryFiles, normalized.toString());
  }

  Future<DateTime?> getLastBackupAt() async {
    return DateTime.tryParse(await _getSetting(_keyLastBackupAt) ?? '');
  }

  Future<AutoMetadataBackupStatus> getStatus() async {
    return AutoMetadataBackupStatus(
      uploadedSinceBackup:
          int.tryParse(await _getSetting(_keyUploadedSinceBackup) ?? '') ?? 0,
      backupEveryFiles: await getBackupEveryFiles(),
      lastBackupAt: await getLastBackupAt(),
      lastError: await _getSetting(_keyLastError),
    );
  }

  Future<void> noteMediaUploadCompleted() async {
    final current = int.tryParse(
      await _getSetting(_keyUploadedSinceBackup) ?? '',
    );
    final next = (current ?? 0) + 1;
    await _setSetting(_keyUploadedSinceBackup, next.toString());

    final threshold = await getBackupEveryFiles();
    if (next < threshold) return;
    await _triggerBackup(reason: 'upload_threshold');
  }

  Future<void> _retryThresholdBackup() async {
    final uploaded =
        int.tryParse(await _getSetting(_keyUploadedSinceBackup) ?? '') ?? 0;
    if (uploaded >= await getBackupEveryFiles()) {
      await _triggerBackup(reason: 'flood_wait_resume');
    }
  }

  Future<void> _triggerBackup({required String reason}) async {
    if (_automaticBackupQueued ||
        _telegramReliability.currentState.isBlockedAt(DateTime.now())) {
      return;
    }
    _automaticBackupQueued = true;
    try {
      await backupNow(reason: reason);
    } on TelegramError catch (error) {
      await _setSetting(_keyLastError, error.userMessage);
      // Exact waits remain persisted by the shared write coordinator. The
      // threshold count is intentionally retained for the resume event.
    } on MetadataBackupException catch (error) {
      await _setSetting(_keyLastError, error.message);
    } catch (_) {
      await _setSetting(
        _keyLastError,
        'Metadata backup did not finish. TeleVault will retry after another successful upload.',
      );
      // Automatic metadata backup is retried by the next completed upload or
      // explicit user action; background failures must not escape unawaited.
    } finally {
      _automaticBackupQueued = false;
    }
  }

  Future<AutoMetadataBackupResult> backupNow({required String reason}) {
    return _operationLock.synchronized(() => _backupNow(reason: reason));
  }

  Future<AutoMetadataBackupResult> _backupNow({required String reason}) async {
    io.File? snapshot;
    try {
      final chatId = await ensureMetadataChannel(createIfMissing: true);
      snapshot = await _metadataBackupService.exportAccountBoundSnapshot();
      final previousMessageId = int.tryParse(
        await _getSetting(_keyLastMessageId) ?? '',
      );
      final messageId = await _uploadSnapshot(snapshot, chatId, reason);
      final verified = await _verifyRemoteSnapshot(chatId, messageId);
      final history = await _loadVerifiedSnapshots();
      if (history.isEmpty && previousMessageId != null) {
        final previous = await _tryVerifyRemoteSnapshot(
          chatId,
          previousMessageId,
        );
        if (previous != null) history.add(previous);
      }
      history.removeWhere(
        (entry) => entry.chatId == chatId && entry.messageId == messageId,
      );
      history.insert(0, verified);
      final completedAt = DateTime.now();

      await _setSetting(_keyChatId, chatId.toString());
      await _setSetting(_keyLastMessageId, messageId.toString());
      await _setSetting(_keyLastBackupAt, completedAt.toIso8601String());
      await _setSetting(_keyUploadedSinceBackup, '0');
      await _setSetting(_keyLastError, '');
      await _saveVerifiedSnapshots(history);
      await _pruneVerifiedSnapshots(history);

      return AutoMetadataBackupResult(
        chatId: chatId,
        messageId: messageId,
        completedAt: completedAt,
      );
    } finally {
      if (snapshot != null && await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  Future<AutoMetadataRestoreResult?> restoreLatestIfAvailable({
    void Function(String status)? onStatus,
  }) {
    return _operationLock.synchronized(
      () => _restoreLatestIfAvailable(onStatus: onStatus),
    );
  }

  Future<AutoMetadataRestoreResult?> _restoreLatestIfAvailable({
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Looking for the TeleVault metadata channel...');
    final found = await _findMetadataMessages();
    if (found.isEmpty) return null;

    MetadataBackupException? lastSnapshotError;
    for (final candidate in found) {
      io.File? snapshot;
      try {
        onStatus?.call('Downloading TeleVault metadata...');
        snapshot = await _downloadSnapshotFromMessage(candidate.message);
        onStatus?.call('Authenticating and restoring TeleVault metadata...');
        final imported = await _metadataBackupService
            .importAccountBoundSnapshot(snapshot);

        await _setSetting(_keyChatId, candidate.chatId.toString());
        await _setSetting(_keyLastMessageId, candidate.messageId.toString());
        await _setSetting(_keyUploadedSinceBackup, '0');
        final history = await _loadVerifiedSnapshots();
        history.removeWhere(
          (entry) =>
              entry.chatId == candidate.chatId &&
              entry.messageId == candidate.messageId,
        );
        history.insert(
          0,
          _VerifiedRemoteSnapshot(
            chatId: candidate.chatId,
            messageId: candidate.messageId,
            verifiedAt: DateTime.now().toUtc(),
          ),
        );
        await _saveVerifiedSnapshots(history);

        if (imported.requiresSecureMigration) {
          onStatus?.call(
            'Replacing legacy weak metadata protection with secure v5...',
          );
          await _backupNow(reason: 'legacy_v4_migration');
        }
        return AutoMetadataRestoreResult(
          chatId: candidate.chatId,
          messageId: candidate.messageId,
        );
      } on MetadataBackupException catch (error) {
        lastSnapshotError = error;
        if (error.code == MetadataBackupErrorCode.wrongTelegramAccount ||
            error.code == MetadataBackupErrorCode.recoveryKeyRequired) {
          rethrow;
        }
      } finally {
        if (snapshot != null && await snapshot.exists()) {
          await snapshot.delete();
        }
      }
    }
    if (lastSnapshotError != null) throw lastSnapshotError;
    return null;
  }

  Future<BigInt> ensureMetadataChannel({required bool createIfMissing}) async {
    final stored = BigInt.tryParse(await _getSetting(_keyChatId) ?? '');
    if (stored != null && await _chatExists(stored)) {
      return stored;
    }

    final existing = await _findMetadataChannel();
    if (existing != null) {
      await _setSetting(_keyChatId, existing.toString());
      return existing;
    }

    if (!createIfMissing) {
      throw const TelegramError(
        code: null,
        tdlibMessage: 'TeleVault metadata channel was not found',
        operation: 'find_metadata_channel',
        category: TelegramErrorCategory.userActionRequired,
        canRetry: false,
        userActionRequired: true,
      );
    }

    final response = await _telegramReliability.executeWrite(
      {
        '@type': 'createNewSupergroupChat',
        'title': channelTitle,
        'is_channel': true,
        'description': channelDescription,
      },
      operation: 'create_metadata_channel',
      timeout: const Duration(seconds: 30),
    );

    var chatId = _extractBigInt(response['id']);
    if (chatId == null) {
      TelegramUpdate event;
      try {
        event = await _telegram.waitForUpdate(
          (u) =>
              u['@type'] == 'updateNewChat' &&
              u['chat']?['title'] == channelTitle,
          timeout: const Duration(seconds: 30),
        );
      } catch (error) {
        throw TelegramErrorParser.fromThrown(
          error,
          operation: 'create_metadata_channel',
        );
      }
      chatId = _extractBigInt(event['chat']?['id']);
    }

    if (chatId == null) {
      throw const TelegramError(
        code: null,
        tdlibMessage: 'Telegram did not return the metadata channel id',
        operation: 'create_metadata_channel',
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }

    await _setSetting(_keyChatId, chatId.toString());
    return chatId;
  }

  Future<BigInt?> _findMetadataChannel() async {
    final chatIds = await _loadChatIds();
    for (final chatId in chatIds) {
      final chat = await _getChat(chatId);
      if (chat?['title']?.toString() == channelTitle) {
        return chatId;
      }
    }
    return null;
  }

  Future<List<_FoundMetadataMessage>> _findMetadataMessages() async {
    final chatIds = await _loadChatIds();
    final found = <_FoundMetadataMessage>[];

    for (final chatId in chatIds) {
      final chat = await _getChat(chatId);
      if (chat?['title']?.toString() != channelTitle) continue;
      for (final message in await _findMetadataMessagesInChat(chatId)) {
        final messageId = _extractInt(message['id']);
        if (messageId == null) continue;
        found.add(
          _FoundMetadataMessage(
            chatId: chatId,
            messageId: messageId,
            date: _extractInt(message['date']) ?? 0,
            message: message,
          ),
        );
      }
    }
    found.sort((left, right) => right.date.compareTo(left.date));
    return found;
  }

  Future<List<Map<String, dynamic>>> _findMetadataMessagesInChat(
    BigInt chatId,
  ) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) return const [];
    final matches = <int, Map<String, dynamic>>{};
    for (final message in await _searchChatMessages(chatIdInt)) {
      final id = _extractInt(message['id']);
      if (id != null) matches[id] = message;
    }

    final history = await _telegram.request({
      '@type': 'getChatHistory',
      'chat_id': chatIdInt,
      'from_message_id': 0,
      'offset': 0,
      'limit': 100,
      'only_local': false,
    }, timeout: const Duration(seconds: 20));

    if (history['@type'] == 'error') return matches.values.toList();
    final messages = history['messages'] as List<dynamic>? ?? const [];
    for (final raw in messages.whereType<Map>()) {
      final message = Map<String, dynamic>.from(raw);
      final id = _extractInt(message['id']);
      if (id != null && _messageHasMarker(message)) matches[id] = message;
    }
    return matches.values.toList();
  }

  Future<List<Map<String, dynamic>>> _searchChatMessages(int chatId) async {
    final response = await _telegram.request({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': marker,
      'sender_id': null,
      'from_message_id': 0,
      'offset': 0,
      'limit': 100,
      'filter': {'@type': 'searchMessagesFilterDocument'},
      'message_thread_id': 0,
    }, timeout: const Duration(seconds: 20));

    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'read_metadata_chat',
        chatId: BigInt.from(chatId),
      )!;
    }
    final messages = response['messages'] as List<dynamic>? ?? const [];
    return messages
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where(_messageHasMarker)
        .toList(growable: false);
  }

  Future<List<BigInt>> _loadChatIds() async {
    final response = await _telegram.request({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 500,
    }, timeout: const Duration(seconds: 30));

    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'read_metadata_chats',
      )!;
    }

    final ids = response['chat_ids'] as List<dynamic>? ?? const [];
    return ids.map(_extractBigInt).whereType<BigInt>().toList();
  }

  Future<Map<String, dynamic>?> _getChat(BigInt chatId) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) return null;
    final response = await _telegram.request({
      '@type': 'getChat',
      'chat_id': chatIdInt,
    }, timeout: const Duration(seconds: 10));
    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'read_metadata_chat',
        chatId: chatId,
      )!;
    }
    return response;
  }

  Future<bool> _chatExists(BigInt chatId) async {
    return _getChat(chatId).then((chat) => chat != null);
  }

  Future<int> _uploadSnapshot(
    io.File snapshot,
    BigInt chatId,
    String reason,
  ) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) {
      throw TelegramError(
        code: null,
        tdlibMessage: 'Invalid TeleVault metadata channel id',
        operation: 'upload_metadata',
        chatId: chatId,
        category: TelegramErrorCategory.permanent,
        canRetry: false,
      );
    }

    final captionText =
        '$_captionPrefix\n$marker\nReason: $reason\nCreated: ${DateTime.now().toIso8601String()}';

    return _telegramReliability.sendMessageAndWait(
      operation: 'upload_metadata',
      chatId: chatId,
      inputMessageContent: TelegramMessageContent.document(
        file: TelegramMessageContent.localFile(snapshot.path),
        caption: captionText,
      ),
      timeout: const Duration(minutes: 5),
    );
  }

  Future<_VerifiedRemoteSnapshot> _verifyRemoteSnapshot(
    BigInt chatId,
    int messageId,
  ) async {
    final message = await _getMessage(chatId, messageId);
    final downloaded = await _downloadSnapshotFromMessage(message);
    try {
      await _metadataBackupService.verifyAccountBoundSnapshot(downloaded);
      return _VerifiedRemoteSnapshot(
        chatId: chatId,
        messageId: messageId,
        verifiedAt: DateTime.now().toUtc(),
      );
    } finally {
      if (await downloaded.exists()) await downloaded.delete();
    }
  }

  Future<_VerifiedRemoteSnapshot?> _tryVerifyRemoteSnapshot(
    BigInt chatId,
    int messageId,
  ) async {
    try {
      return await _verifyRemoteSnapshot(chatId, messageId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getMessage(BigInt chatId, int messageId) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null || messageId <= 0) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.validationFailed,
        'The remote metadata reference is invalid.',
      );
    }
    final response = await _telegram.request({
      '@type': 'getMessage',
      'chat_id': chatIdInt,
      'message_id': messageId,
    }, timeout: const Duration(seconds: 20));
    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'verify_metadata_message',
        chatId: chatId,
      )!;
    }
    if (response['@type'] != 'message') {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'Telegram did not return the uploaded metadata message.',
      );
    }
    return response;
  }

  Future<List<_VerifiedRemoteSnapshot>> _loadVerifiedSnapshots() async {
    final raw = await _getSetting(_keyVerifiedSnapshots);
    if (raw == null || raw.isEmpty) return <_VerifiedRemoteSnapshot>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <_VerifiedRemoteSnapshot>[];
      final results = <_VerifiedRemoteSnapshot>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final chatId = _extractBigInt(value['chat_id']);
        final messageId = _extractInt(value['message_id']);
        final verifiedAt = DateTime.tryParse(
          value['verified_at']?.toString() ?? '',
        );
        if (chatId == null || messageId == null || verifiedAt == null) continue;
        results.add(
          _VerifiedRemoteSnapshot(
            chatId: chatId,
            messageId: messageId,
            verifiedAt: verifiedAt.toUtc(),
          ),
        );
      }
      results.sort(
        (left, right) => right.verifiedAt.compareTo(left.verifiedAt),
      );
      return results;
    } catch (_) {
      return <_VerifiedRemoteSnapshot>[];
    }
  }

  Future<void> _saveVerifiedSnapshots(List<_VerifiedRemoteSnapshot> snapshots) {
    final unique = <String, _VerifiedRemoteSnapshot>{};
    for (final snapshot in snapshots) {
      unique['${snapshot.chatId}:${snapshot.messageId}'] = snapshot;
    }
    final sorted = unique.values.toList()
      ..sort((left, right) => right.verifiedAt.compareTo(left.verifiedAt));
    return _setSetting(
      _keyVerifiedSnapshots,
      jsonEncode(
        sorted
            .map(
              (snapshot) => <String, String>{
                'chat_id': snapshot.chatId.toString(),
                'message_id': snapshot.messageId.toString(),
                'verified_at': snapshot.verifiedAt.toIso8601String(),
              },
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _pruneVerifiedSnapshots(
    List<_VerifiedRemoteSnapshot> snapshots,
  ) async {
    snapshots.sort(
      (left, right) => right.verifiedAt.compareTo(left.verifiedAt),
    );
    if (snapshots.length <= remoteSnapshotRetention) {
      await _saveVerifiedSnapshots(snapshots);
      return;
    }
    final retained = snapshots.take(remoteSnapshotRetention).toList();
    final obsolete = snapshots.skip(remoteSnapshotRetention).toList();
    for (final snapshot in obsolete) {
      await _deleteRemoteSnapshot(snapshot.chatId, snapshot.messageId);
    }
    await _saveVerifiedSnapshots(retained);
  }

  Future<void> _deleteRemoteSnapshot(BigInt chatId, int messageId) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) return;
    try {
      await _telegramReliability.executeWrite(
        {
          '@type': 'deleteMessages',
          'chat_id': chatIdInt,
          'message_ids': [messageId],
          'revoke': true,
        },
        operation: 'prune_verified_metadata',
        chatId: chatId,
        timeout: const Duration(seconds: 20),
      );
    } catch (_) {
      // Keeping an older metadata package is safer than risking the new one.
    }
  }

  Future<io.File> _downloadSnapshotFromMessage(
    Map<String, dynamic> message,
  ) async {
    final content = message['content'] as Map<String, dynamic>?;
    final document = content?['document'] as Map<String, dynamic>?;
    final file = document?['document'] as Map<String, dynamic>?;
    final fileId = _extractInt(file?['id']);
    if (fileId == null) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.invalidSnapshot,
        'The TeleVault metadata message has no document file.',
      );
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
      throw TelegramErrorParser.parse(
        response,
        operation: 'download_metadata',
      )!;
    }

    final localPath = response['local']?['path']?.toString();
    if (localPath == null || localPath.isEmpty) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.ioFailure,
        'The downloaded metadata file is unavailable.',
      );
    }

    final snapshot = io.File(localPath);
    if (!await snapshot.exists()) {
      throw const MetadataBackupException(
        MetadataBackupErrorCode.ioFailure,
        'The downloaded metadata file was not found.',
      );
    }
    final temporaryRoot = await _temporaryDirectoryProvider();
    final temporaryDirectory = io.Directory(
      path.join(
        temporaryRoot.path,
        AppRuntimeEnvironment.cacheDirectory('televault_metadata_downloads'),
      ),
    );
    await temporaryDirectory.create(recursive: true);
    final copy = io.File(
      path.join(temporaryDirectory.path, '${const Uuid().v4()}.tvmeta'),
    );
    return snapshot.copy(copy.path);
  }

  bool _messageHasMarker(Map<String, dynamic> message) {
    final content = message['content'] as Map<String, dynamic>?;
    final caption = content?['caption'] as Map<String, dynamic>?;
    final text = caption?['text']?.toString() ?? '';
    return text.contains(marker);
  }

  Future<String?> _getSetting(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSetting(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
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

  Future<void> dispose() async {
    await _telegramStateSubscription?.cancel();
  }
}

class _FoundMetadataMessage {
  final BigInt chatId;
  final int messageId;
  final int date;
  final Map<String, dynamic> message;

  const _FoundMetadataMessage({
    required this.chatId,
    required this.messageId,
    required this.date,
    required this.message,
  });
}

class _VerifiedRemoteSnapshot {
  final BigInt chatId;
  final int messageId;
  final DateTime verifiedAt;

  const _VerifiedRemoteSnapshot({
    required this.chatId,
    required this.messageId,
    required this.verifiedAt,
  });
}
