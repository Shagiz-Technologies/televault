import '../../../core/services/telegram_gateway.dart';

class MetadataRemoteReconciliation {
  final Set<int> verifiedBucketIds;
  final Set<String> verifiedMessages;

  const MetadataRemoteReconciliation({
    required this.verifiedBucketIds,
    required this.verifiedMessages,
  });

  bool isMessageVerified(int bucketId, int messageId) =>
      verifiedMessages.contains(messageKey(bucketId, messageId));

  static String messageKey(int bucketId, int messageId) =>
      '$bucketId:$messageId';
}

abstract interface class MetadataRemoteStateVerifier {
  Future<MetadataRemoteReconciliation> reconcile({
    required Map<int, BigInt> bucketChatIds,
    required Map<int, Set<int>> messageIdsByBucket,
  });
}

class TelegramMetadataRemoteStateVerifier
    implements MetadataRemoteStateVerifier {
  final TelegramGateway _telegram;

  TelegramMetadataRemoteStateVerifier(this._telegram);

  @override
  Future<MetadataRemoteReconciliation> reconcile({
    required Map<int, BigInt> bucketChatIds,
    required Map<int, Set<int>> messageIdsByBucket,
  }) async {
    final verifiedBuckets = <int>{};
    final verifiedMessages = <String>{};

    for (final entry in bucketChatIds.entries) {
      final chatId = _toTdInt64(entry.value);
      if (chatId == null) continue;
      final chat = await _safeRequest({'@type': 'getChat', 'chat_id': chatId});
      if (chat == null || chat['@type'] == 'error') continue;
      verifiedBuckets.add(entry.key);

      final messageIds = messageIdsByBucket[entry.key]?.toList() ?? const [];
      for (var offset = 0; offset < messageIds.length; offset += 100) {
        final end = (offset + 100).clamp(0, messageIds.length);
        final chunk = messageIds.sublist(offset, end);
        final response = await _safeRequest({
          '@type': 'getMessages',
          'chat_id': chatId,
          'message_ids': chunk,
        });
        if (response == null || response['@type'] == 'error') continue;
        final messages = response['messages'] as List<dynamic>? ?? const [];
        for (final candidate in messages) {
          if (candidate is! Map) continue;
          final messageId = _int(candidate['id']);
          if (messageId != null && chunk.contains(messageId)) {
            verifiedMessages.add(
              MetadataRemoteReconciliation.messageKey(entry.key, messageId),
            );
          }
        }
      }
    }

    return MetadataRemoteReconciliation(
      verifiedBucketIds: verifiedBuckets,
      verifiedMessages: verifiedMessages,
    );
  }

  Future<TelegramResult?> _safeRequest(TelegramRequest request) async {
    try {
      return await _telegram.request(
        request,
        timeout: const Duration(seconds: 20),
      );
    } catch (_) {
      // Reconciliation is conservative: an unavailable remote reference is
      // imported as unverified instead of being treated as synced.
      return null;
    }
  }

  static int? _toTdInt64(BigInt value) {
    try {
      return value.toInt();
    } catch (_) {
      return null;
    }
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
