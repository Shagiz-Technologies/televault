import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_error.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';

import 'support/fake_telegram_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeTelegramGateway gateway;
  late DateTime now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeTelegramGateway();
    now = DateTime(2026, 7, 31, 12);
  });

  tearDown(() async {
    await gateway.dispose();
    await db.close();
  });

  TelegramReliabilityService createService() {
    return TelegramReliabilityService(
      db,
      gateway,
      clock: () => now,
      jitter: () => Duration.zero,
      autoInitialize: false,
    );
  }

  TelegramError floodWait(int seconds, {bool premium = false}) {
    return TelegramErrorParser.parse({
      '@type': 'error',
      'code': 429,
      'message': premium
          ? 'FLOOD_PREMIUM_WAIT_$seconds'
          : 'FLOOD_WAIT_$seconds',
    }, operation: 'upload_media')!;
  }

  test('a later blockedUntil is never shortened', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();

    await service.registerError(floodWait(3600));
    final later = service.currentState.blockedUntil;
    await service.registerError(floodWait(1));

    expect(later, now.add(const Duration(hours: 1)));
    expect(service.currentState.blockedUntil, later);
  });

  test('restores the account-scoped gate after restart', () async {
    final first = createService();
    await first.initialize();
    await first.registerError(floodWait(3600));
    await first.dispose();

    final second = createService();
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.currentState.accountId, BigInt.from(123));
    expect(second.currentState.blockedUntil, now.add(const Duration(hours: 1)));
    expect(second.currentState.isBlockedAt(now), isTrue);
  });

  test('does not send a write while the durable gate is active', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    await service.registerError(floodWait(60));
    final writesBefore = gateway.requestCount('createNewSupergroupChat');

    await expectLater(
      service.executeWrite({
        '@type': 'createNewSupergroupChat',
        'title': 'Blocked',
      }, operation: 'create_bucket'),
      throwsA(
        isA<TelegramError>().having(
          (error) => error.category,
          'category',
          TelegramErrorCategory.exactWait,
        ),
      ),
    );

    expect(gateway.requestCount('createNewSupergroupChat'), writesBefore);
  });

  test('clears the gate only after the exact resume time', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    await service.registerError(floodWait(1));

    now = now.add(const Duration(milliseconds: 999));
    expect(service.currentState.isBlockedAt(now), isTrue);
    now = now.add(const Duration(milliseconds: 1));
    expect(service.currentState.isBlockedAt(now), isFalse);
  });

  test('uses live Premium capability and responds to option updates', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.effectiveUploadLimitMb, telegramFreeOperationalLimitMb);

    gateway.emit({
      '@type': 'updateOption',
      'name': 'is_premium',
      'value': {'@type': 'optionValueBoolean', 'value': true},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isPremium, isTrue);
    expect(service.effectiveUploadLimitMb, telegramPremiumOperationalLimitMb);
  });

  test('refreshes capability when TDLib becomes ready after startup', () async {
    gateway.handler = (_) => throw TimeoutException('TDLib not ready');
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.currentState.accountId, isNull);

    gateway.handler = (request) => switch ((
      request['@type'],
      request['name'],
    )) {
      ('getOption', 'my_id') => {'@type': 'optionValueInteger', 'value': 789},
      ('getOption', 'is_premium') => {
        '@type': 'optionValueBoolean',
        'value': true,
      },
      _ => throw UnimplementedError('Unexpected request: ${request['@type']}'),
    };
    gateway.emit({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateReady'},
    });
    for (var i = 0; i < 20 && service.currentState.accountId == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(service.currentState.accountId, BigInt.from(789));
    expect(service.isPremium, isTrue);
  });

  test('a gate is restored only when its Telegram account is active', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    await service.registerError(floodWait(3600));

    await service.updateAccountCapability(
      accountId: BigInt.from(456),
      isPremium: false,
    );
    expect(service.currentState.isBlockedAt(now), isFalse);

    await service.updateAccountCapability(
      accountId: BigInt.from(123),
      isPremium: false,
    );
    expect(service.currentState.isBlockedAt(now), isTrue);
  });

  test('records success only after updateMessageSendSucceeded', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    gateway.handler = (request) {
      if (request['@type'] == 'sendMessage') {
        Timer.run(() {
          gateway.emit({
            '@type': 'updateMessageSendSucceeded',
            'old_message_id': 71,
            'message': {'@type': 'message', 'id': 72, 'chat_id': 9001},
          });
        });
        return {
          '@type': 'message',
          'id': 71,
          'chat_id': 9001,
          'sending_state': {'@type': 'messageSendingStatePending'},
        };
      }
      if (request['@type'] == 'getMessage') {
        return {
          '@type': 'message',
          'id': 72,
          'chat_id': 9001,
          'sending_state': null,
        };
      }
      throw UnimplementedError('Unexpected request: ${request['@type']}');
    };

    final messageId = await service.sendMessageAndWait(
      operation: 'upload_media',
      chatId: BigInt.from(9001),
      inputMessageContent: const {'@type': 'inputMessageDocument'},
      timeout: const Duration(seconds: 1),
    );

    expect(messageId, 72);
    expect(gateway.requestCount('getMessage'), 1);
  });

  test(
    'captures a send-success update emitted before request returns',
    () async {
      final service = createService();
      addTearDown(service.dispose);
      await service.initialize();
      gateway.handler = (request) {
        if (request['@type'] == 'sendMessage') {
          gateway.emit({
            '@type': 'updateMessageSendSucceeded',
            'old_message_id': 73,
            'message': {'@type': 'message', 'id': 74, 'chat_id': 9001},
          });
          return {
            '@type': 'message',
            'id': 73,
            'chat_id': 9001,
            'sending_state': {'@type': 'messageSendingStatePending'},
          };
        }
        if (request['@type'] == 'getMessage') {
          return {
            '@type': 'message',
            'id': 74,
            'chat_id': 9001,
            'sending_state': null,
          };
        }
        throw UnimplementedError('Unexpected request: ${request['@type']}');
      };

      final messageId = await service.sendMessageAndWait(
        operation: 'upload_media',
        chatId: BigInt.from(9001),
        inputMessageContent: const {'@type': 'inputMessageDocument'},
        timeout: const Duration(seconds: 1),
      );

      expect(messageId, 74);
    },
  );

  test(
    'a send response is not success until the message is retrievable',
    () async {
      final service = createService();
      addTearDown(service.dispose);
      await service.initialize();
      gateway.handler = (request) {
        if (request['@type'] == 'sendMessage') {
          return {'@type': 'message', 'id': 91, 'chat_id': 9001};
        }
        if (request['@type'] == 'getMessage') {
          return {
            '@type': 'error',
            'code': 404,
            'message': 'MESSAGE_NOT_FOUND',
          };
        }
        throw UnimplementedError('Unexpected request: ${request['@type']}');
      };

      await expectLater(
        service.sendMessageAndWait(
          operation: 'upload_media',
          chatId: BigInt.from(9001),
          inputMessageContent: const {'@type': 'inputMessageDocument'},
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<TelegramError>()
              .having((error) => error.canRetry, 'canRetry', isTrue)
              .having((error) => error.code, 'code', 404),
        ),
      );
      expect(gateway.requestCount('getMessage'), 4);
    },
  );

  test('nested send failure registers an exact gate', () async {
    final service = createService();
    addTearDown(service.dispose);
    await service.initialize();
    gateway.handler = (request) {
      if (request['@type'] == 'sendMessage') {
        Timer.run(() {
          gateway.emit({
            '@type': 'updateMessageSendFailed',
            'old_message_id': 81,
            'message': {
              '@type': 'message',
              'id': 81,
              'chat_id': 9001,
              'sending_state': {
                '@type': 'messageSendingStateFailed',
                'can_retry': true,
                'retry_after': 30,
                'error': {
                  '@type': 'error',
                  'code': 429,
                  'message': 'TOO_MANY_REQUESTS',
                },
              },
            },
            'error': {'@type': 'error', 'code': 429, 'message': 'FLOOD_WAIT_1'},
          });
        });
        return {
          '@type': 'message',
          'id': 81,
          'chat_id': 9001,
          'sending_state': {'@type': 'messageSendingStatePending'},
        };
      }
      throw UnimplementedError('Unexpected request: ${request['@type']}');
    };

    await expectLater(
      service.sendMessageAndWait(
        operation: 'upload_media',
        chatId: BigInt.from(9001),
        inputMessageContent: const {'@type': 'inputMessageDocument'},
        timeout: const Duration(seconds: 1),
      ),
      throwsA(
        isA<TelegramError>().having(
          (error) => error.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
    expect(
      service.currentState.blockedUntil,
      now.add(const Duration(seconds: 30)),
    );
  });
}
