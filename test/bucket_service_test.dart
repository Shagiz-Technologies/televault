import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_gateway.dart';
import 'package:tele_vault/src/features/buckets/services/bucket_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';

void main() {
  late AppDatabase db;
  late BucketService service;
  late _FakeTelegramGateway telegramGateway;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    telegramGateway = _FakeTelegramGateway();
    service = BucketService(db, telegramGateway, SettingsService(db));
  });

  tearDown(() async {
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
}

class _FakeTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  @override
  void send(TelegramRequest request) {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('No Telegram requests are expected in this test');
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError('No Telegram updates are expected in this test');
  }

  @override
  Future<void> dispose() async {
    await _updates.close();
  }
}
