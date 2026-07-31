import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/services/telegram_error.dart';

void main() {
  group('TelegramErrorParser', () {
    test('parses direct TDLib errors', () {
      final error = TelegramErrorParser.parse(
        {'@type': 'error', 'code': 403, 'message': 'CHAT_WRITE_FORBIDDEN'},
        operation: 'create_bucket',
        chatId: BigInt.from(42),
      )!;

      expect(error.code, 403);
      expect(error.tdlibMessage, 'CHAT_WRITE_FORBIDDEN');
      expect(error.operation, 'create_bucket');
      expect(error.chatId, BigInt.from(42));
      expect(error.category, TelegramErrorCategory.permission);
      expect(error.canRetry, isFalse);
      expect(error.userActionRequired, isTrue);
    });

    test('parses nested updateMessageSendFailed.error', () {
      final error = TelegramErrorParser.parse({
        '@type': 'updateMessageSendFailed',
        'message': {
          '@type': 'message',
          'sending_state': {
            '@type': 'messageSendingStateFailed',
            'can_retry': true,
            'retry_after': 17,
            'error': {
              '@type': 'error',
              'code': 429,
              'message': 'TOO_MANY_REQUESTS',
            },
          },
        },
        'error': {'@type': 'error', 'code': 429, 'message': 'FLOOD_WAIT_9'},
      }, operation: 'upload_media')!;

      expect(error.code, 429);
      expect(error.retryAfter, const Duration(seconds: 17));
      expect(error.category, TelegramErrorCategory.exactWait);
    });

    test('parses messageSendingStateFailed on a message response', () {
      final error = TelegramErrorParser.parse({
        '@type': 'message',
        'sending_state': {
          '@type': 'messageSendingStateFailed',
          'can_retry': true,
          'retry_after': 4,
          'error': {
            '@type': 'error',
            'code': 429,
            'message': 'TOO_MANY_REQUESTS',
          },
        },
      }, operation: 'upload_media')!;

      expect(error.retryAfter, const Duration(seconds: 4));
      expect(error.canRetry, isTrue);
    });

    for (final seconds in [1, 3600]) {
      test('parses FLOOD_WAIT_$seconds', () {
        final error = TelegramErrorParser.parse({
          '@type': 'error',
          'code': 429,
          'message': 'FLOOD_WAIT_$seconds',
        }, operation: 'upload_media')!;

        expect(error.retryAfter, Duration(seconds: seconds));
        expect(error.isFloodWait, isTrue);
        expect(error.isPremiumFloodWait, isFalse);
      });
    }

    test('parses FLOOD_PREMIUM_WAIT_120', () {
      final error = TelegramErrorParser.parse({
        '@type': 'error',
        'code': 429,
        'message': 'FLOOD_PREMIUM_WAIT_120',
      }, operation: 'upload_media')!;

      expect(error.retryAfter, const Duration(seconds: 120));
      expect(error.isFloodWait, isTrue);
      expect(error.isPremiumFloodWait, isTrue);
    });

    test('structured retry_after takes precedence over message text', () {
      final error = TelegramErrorParser.parse({
        '@type': 'messageSendingStateFailed',
        'retry_after': 33,
        'can_retry': true,
        'error': {'@type': 'error', 'code': 429, 'message': 'FLOOD_WAIT_2'},
      }, operation: 'upload_media')!;

      expect(error.retryAfter, const Duration(seconds: 33));
    });

    test('uses textual retry fallback only without structured data', () {
      final error = TelegramErrorParser.parse({
        '@type': 'error',
        'code': 429,
        'message': 'Please retry after 12 seconds',
      }, operation: 'upload_media')!;

      expect(error.retryAfter, const Duration(seconds: 12));
    });

    test('does not process or expose TDLib error 406 message text', () {
      const privateMessage = 'FLOOD_WAIT_999 internal secret detail';
      final error = TelegramErrorParser.parse({
        '@type': 'error',
        'code': 406,
        'message': privateMessage,
      }, operation: 'upload_media')!;

      expect(error.tdlibMessage, privateMessage);
      expect(error.retryAfter, isNull);
      expect(error.userMessage, isNot(contains(privateMessage)));
      expect(error.toString(), isNot(contains(privateMessage)));
    });
  });
}
