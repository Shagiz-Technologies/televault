import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_error.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/buckets/services/bucket_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';

import 'support/fake_telegram_gateway.dart';

void main() {
  late AppDatabase db;
  late BucketService service;
  late FakeTelegramGateway telegramGateway;
  late TelegramReliabilityService reliability;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    telegramGateway = FakeTelegramGateway();
    reliability = TelegramReliabilityService(
      db,
      telegramGateway,
      jitter: () => Duration.zero,
      autoInitialize: false,
    );
    await reliability.initialize();
    service = BucketService(
      db,
      telegramGateway,
      SettingsService(db),
      reliability,
    );
  });

  tearDown(() async {
    await reliability.dispose();
    await telegramGateway.dispose();
    await db.close();
  });

  Future<int> insertBucket(
    String name, {
    required int chatId,
    required bool isActive,
    required DateTime createdAt,
  }) {
    return db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(chatId),
            name: name,
            isActive: Value(isActive),
            createdAt: Value(createdAt),
          ),
        );
  }

  test('getActiveBucket promotes first bucket when none is active', () async {
    final firstId = await insertBucket(
      'Main',
      chatId: 1001,
      isActive: false,
      createdAt: DateTime(2026),
    );
    await insertBucket(
      'Videos',
      chatId: 1002,
      isActive: false,
      createdAt: DateTime(2026, 1, 2),
    );

    final active = await service.getActiveBucket();
    final rows = await service.getBuckets();

    expect(active?.id, firstId);
    expect(active?.isActive, isTrue);
    expect(rows.where((bucket) => bucket.isActive), hasLength(1));
    expect(rows.singleWhere((bucket) => bucket.id == firstId).isActive, isTrue);
  });

  test(
    'getActiveBucket keeps only first active bucket when multiple are active',
    () async {
      final firstId = await insertBucket(
        'Main',
        chatId: 1001,
        isActive: true,
        createdAt: DateTime(2026),
      );
      final secondId = await insertBucket(
        'Videos',
        chatId: 1002,
        isActive: true,
        createdAt: DateTime(2026, 1, 2),
      );

      final active = await service.getActiveBucket();
      final rows = await service.getBuckets();

      expect(active?.id, firstId);
      expect(rows.where((bucket) => bucket.isActive), hasLength(1));
      expect(
        rows.singleWhere((bucket) => bucket.id == firstId).isActive,
        isTrue,
      );
      expect(
        rows.singleWhere((bucket) => bucket.id == secondId).isActive,
        isFalse,
      );
    },
  );

  test('bucket creation uses the shared typed flood-wait path', () async {
    telegramGateway.handler = (request) {
      if (request['@type'] == 'createNewSupergroupChat') {
        return {'@type': 'error', 'code': 429, 'message': 'FLOOD_WAIT_60'};
      }
      throw UnimplementedError('Unexpected request: ${request['@type']}');
    };

    await expectLater(
      service.createBucket('Demo', 'Demo bucket'),
      throwsA(
        isA<TelegramError>()
            .having(
              (error) => error.category,
              'category',
              TelegramErrorCategory.exactWait,
            )
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 60),
            ),
      ),
    );
    expect(await service.getBucketCount(), 0);
    expect(reliability.currentState.isBlockedAt(DateTime.now()), isTrue);

    final requestsBefore = telegramGateway.requestCount(
      'createNewSupergroupChat',
    );
    await expectLater(
      service.createBucket('Blocked', 'Must not be sent'),
      throwsA(isA<TelegramError>()),
    );
    expect(
      telegramGateway.requestCount('createNewSupergroupChat'),
      requestsBefore,
    );
  });
}
