import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_error.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/services/telegram_service.dart';
import 'metadata_backup_service.dart';

final autoMetadataBackupServiceProvider = Provider<AutoMetadataBackupService>((
  ref,
) {
  final service = AutoMetadataBackupService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(metadataBackupServiceProvider),
    ref.watch(telegramReliabilityServiceProvider),
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

class AutoMetadataBackupService {
  final AppDatabase _db;
  final TelegramGateway _telegram;
  final MetadataBackupService _metadataBackupService;
  final TelegramReliabilityService _telegramReliability;

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
  static const _captionPrefix = 'TeleVault Metadata Backup';

  bool _backupRunning = false;
  bool _restoreRunning = false;
  StreamSubscription<TelegramReliabilityState>? _telegramStateSubscription;

  AutoMetadataBackupService(
    this._db,
    this._telegram,
    this._metadataBackupService,
    this._telegramReliability,
  ) {
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

  Future<void> noteMediaUploadCompleted() async {
    final current = int.tryParse(
      await _getSetting(_keyUploadedSinceBackup) ?? '',
    );
    final next = (current ?? 0) + 1;
    await _setSetting(_keyUploadedSinceBackup, next.toString());

    final threshold = await getBackupEveryFiles();
    if (next < threshold) return;
    unawaited(_triggerBackup(reason: 'upload_threshold'));
  }

  Future<void> _retryThresholdBackup() async {
    final uploaded =
        int.tryParse(await _getSetting(_keyUploadedSinceBackup) ?? '') ?? 0;
    if (uploaded >= await getBackupEveryFiles()) {
      await _triggerBackup(reason: 'flood_wait_resume');
    }
  }

  Future<void> _triggerBackup({required String reason}) async {
    if (_backupRunning ||
        _telegramReliability.currentState.isBlockedAt(DateTime.now())) {
      return;
    }
    try {
      await backupNow(reason: reason);
    } on TelegramError {
      // Exact waits remain persisted by the shared write coordinator. The
      // threshold count is intentionally retained for the resume event.
    } catch (_) {
      // Automatic metadata backup is retried by the next completed upload or
      // explicit user action; background failures must not escape unawaited.
    }
  }

  Future<AutoMetadataBackupResult> backupNow({required String reason}) async {
    if (_backupRunning) {
      throw Exception('Metadata backup is already running.');
    }
    _backupRunning = true;
    io.File? snapshot;
    try {
      final chatId = await ensureMetadataChannel(createIfMissing: true);
      snapshot = await _metadataBackupService.exportAccountBoundSnapshot();
      final previousMessageId = int.tryParse(
        await _getSetting(_keyLastMessageId) ?? '',
      );
      final messageId = await _uploadSnapshot(snapshot, chatId, reason);

      await _setSetting(_keyChatId, chatId.toString());
      await _setSetting(_keyLastMessageId, messageId.toString());
      await _setSetting(_keyUploadedSinceBackup, '0');

      if (previousMessageId != null && previousMessageId != messageId) {
        unawaited(_deletePreviousSnapshot(chatId, previousMessageId));
      }

      return AutoMetadataBackupResult(
        chatId: chatId,
        messageId: messageId,
        completedAt: DateTime.now(),
      );
    } finally {
      _backupRunning = false;
      if (snapshot != null && await snapshot.exists()) {
        unawaited(snapshot.delete());
      }
    }
  }

  Future<AutoMetadataRestoreResult?> restoreLatestIfAvailable({
    void Function(String status)? onStatus,
  }) async {
    if (_restoreRunning) return null;
    _restoreRunning = true;
    try {
      onStatus?.call('Looking for the TeleVault metadata channel...');
      final found = await _findLatestMetadataMessage();
      if (found == null) return null;

      onStatus?.call('Downloading TeleVault metadata...');
      final snapshot = await _downloadSnapshotFromMessage(found.message);
      try {
        onStatus?.call('Restoring TeleVault metadata...');
        await _metadataBackupService.importAccountBoundSnapshot(snapshot);
      } finally {
        if (await snapshot.exists()) {
          unawaited(snapshot.delete());
        }
      }

      await _setSetting(_keyChatId, found.chatId.toString());
      await _setSetting(_keyLastMessageId, found.messageId.toString());
      await _setSetting(_keyUploadedSinceBackup, '0');

      return AutoMetadataRestoreResult(
        chatId: found.chatId,
        messageId: found.messageId,
      );
    } finally {
      _restoreRunning = false;
    }
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

  Future<_FoundMetadataMessage?> _findLatestMetadataMessage() async {
    final chatIds = await _loadChatIds();
    _FoundMetadataMessage? latest;

    for (final chatId in chatIds) {
      final chat = await _getChat(chatId);
      if (chat?['title']?.toString() != channelTitle) continue;

      final message = await _findMetadataMessageInChat(chatId);
      if (message == null) continue;
      final messageId = _extractInt(message['id']);
      if (messageId == null) continue;

      final found = _FoundMetadataMessage(
        chatId: chatId,
        messageId: messageId,
        date: _extractInt(message['date']) ?? 0,
        message: message,
      );
      if (latest == null || found.date >= latest.date) {
        latest = found;
      }
    }

    return latest;
  }

  Future<Map<String, dynamic>?> _findMetadataMessageInChat(
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
      if (_messageHasMarker(raw)) return raw;
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

    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'read_metadata_chat',
        chatId: BigInt.from(chatId),
      )!;
    }
    final messages = response['messages'] as List<dynamic>? ?? const [];
    for (final raw in messages.cast<Map<String, dynamic>>()) {
      if (_messageHasMarker(raw)) return raw;
    }
    return null;
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
      inputMessageContent: {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': snapshot.path},
        'thumbnail': null,
        'disable_content_type_detection': false,
        'caption': {'@type': 'formattedText', 'text': captionText},
      },
      timeout: const Duration(minutes: 5),
    );
  }

  Future<void> _deletePreviousSnapshot(BigInt chatId, int messageId) async {
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
        operation: 'delete_previous_metadata',
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
      throw Exception('TeleVault metadata message has no document file.');
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
      throw Exception('Downloaded metadata file path is unavailable.');
    }

    final snapshot = io.File(localPath);
    if (!await snapshot.exists()) {
      throw Exception('Downloaded metadata file was not found on disk.');
    }
    return snapshot;
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
