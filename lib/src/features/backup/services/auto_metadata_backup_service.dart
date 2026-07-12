import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_service.dart';
import 'metadata_backup_service.dart';

final autoMetadataBackupServiceProvider = Provider<AutoMetadataBackupService>((
  ref,
) {
  return AutoMetadataBackupService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(metadataBackupServiceProvider),
  );
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

  AutoMetadataBackupService(
    this._db,
    this._telegram,
    this._metadataBackupService,
  );

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
    unawaited(backupNow(reason: 'upload_threshold'));
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
      throw Exception('TeleVault metadata channel was not found.');
    }

    final response = await _telegram.request({
      '@type': 'createNewSupergroupChat',
      'title': channelTitle,
      'is_channel': true,
      'description': channelDescription,
    }, timeout: const Duration(seconds: 30));

    if (response['@type'] == 'error') {
      throw Exception(
        response['message'] ?? 'Unable to create TeleVault metadata channel.',
      );
    }

    var chatId = _extractBigInt(response['id']);
    if (chatId == null) {
      final event = await _telegram.waitForUpdate(
        (u) =>
            u['@type'] == 'updateNewChat' &&
            u['chat']?['title'] == channelTitle,
        timeout: const Duration(seconds: 30),
      );
      chatId = _extractBigInt(event['chat']?['id']);
    }

    if (chatId == null) {
      throw Exception('Telegram did not return the metadata channel id.');
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

    if (response['@type'] == 'error') return null;
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
      throw Exception(response['message'] ?? 'Unable to read Telegram chats.');
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
    if (response['@type'] == 'error') return null;
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
      throw Exception('Invalid TeleVault metadata channel id.');
    }

    final captionText =
        '$_captionPrefix\n$marker\nReason: $reason\nCreated: ${DateTime.now().toIso8601String()}';

    final uploaded = await _telegram.request({
      '@type': 'preliminaryUploadFile',
      'file': {'@type': 'inputFileLocal', 'path': snapshot.path},
      'file_type': {'@type': 'fileTypeDocument'},
      'priority': 1,
    }, timeout: const Duration(minutes: 3));
    if (uploaded['@type'] == 'error') {
      throw Exception(
        uploaded['message'] ?? 'Unable to upload TeleVault metadata.',
      );
    }
    final uploadedFileId = _extractInt(uploaded['id']);
    if (uploaded['@type'] != 'file' || uploadedFileId == null) {
      throw Exception('Telegram metadata upload file id missing.');
    }

    final response = await _telegram.request({
      '@type': 'sendMessage',
      'chat_id': chatIdInt,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileId', 'id': uploadedFileId},
        'thumbnail': null,
        'disable_content_type_detection': false,
        'caption': {'@type': 'formattedText', 'text': captionText},
      },
    }, timeout: const Duration(minutes: 3));

    if (response['@type'] == 'error') {
      throw Exception(
        response['message'] ?? 'Unable to upload TeleVault metadata.',
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
      return oldId == tempMessageId && updateChat == chatId.toString();
    }, timeout: const Duration(minutes: 5));

    if (update['@type'] == 'updateMessageSendFailed') {
      throw Exception(
        update['error_message']?.toString() ??
            'TeleVault metadata upload failed.',
      );
    }

    return _extractInt(update['message']?['id']) ?? tempMessageId;
  }

  Future<void> _deletePreviousSnapshot(BigInt chatId, int messageId) async {
    final chatIdInt = _toTdInt64(chatId);
    if (chatIdInt == null) return;
    try {
      await _telegram.request({
        '@type': 'deleteMessages',
        'chat_id': chatIdInt,
        'message_ids': [messageId],
        'revoke': true,
      }, timeout: const Duration(seconds: 20));
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
