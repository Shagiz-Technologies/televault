import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_gateway.dart';
import '../../../core/services/telegram_error.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/services/telegram_service.dart';
import '../../settings/services/settings_service.dart';

final bucketServiceProvider = Provider<BucketService>((ref) {
  return BucketService(
    ref.watch(databaseProvider),
    ref.watch(telegramServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(telegramReliabilityServiceProvider),
  );
});

final bucketListProvider = StreamProvider<List<Bucket>>((ref) {
  return ref.watch(bucketServiceProvider).watchBuckets();
});

final activeBucketProvider = Provider<AsyncValue<Bucket?>>((ref) {
  return ref.watch(bucketListProvider).whenData((buckets) {
    if (buckets.isEmpty) return null;
    return buckets.firstWhere(
      (bucket) => bucket.isActive,
      orElse: () => buckets.first,
    );
  });
});

final bucketPresenceProvider =
    StateNotifierProvider<BucketPresenceController, AsyncValue<bool>>((ref) {
      return BucketPresenceController(ref.watch(bucketServiceProvider));
    });

class BucketPresenceController extends StateNotifier<AsyncValue<bool>> {
  final BucketService _bucketService;

  BucketPresenceController(this._bucketService)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<bool> refresh({bool showLoading = false}) async {
    if (showLoading || !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final hasBuckets = await _bucketService.hasBuckets().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return false;
      state = AsyncValue.data(hasBuckets);
      return hasBuckets;
    } catch (error, stackTrace) {
      if (!mounted) return false;
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  void setHasBuckets(bool hasBuckets) {
    state = AsyncValue.data(hasBuckets);
  }
}

enum BucketMediaType { photo, video, document, app, other }

class BucketService {
  static const int maxFreeBuckets = 3;

  final AppDatabase _db;
  final TelegramGateway _telegramService;
  final SettingsService _settingsService;
  final TelegramReliabilityService _telegramReliability;

  BucketService(
    this._db,
    this._telegramService,
    this._settingsService,
    this._telegramReliability,
  );

  Future<bool> hasBuckets() async {
    return getBucketCount().then((count) => count > 0);
  }

  Future<int> getBucketCount() {
    return _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM buckets',
          readsFrom: {_db.buckets},
        )
        .map((row) => row.read<int>('c'))
        .getSingle();
  }

  Future<int> createBucket(
    String name,
    String description, {
    Set<BucketMediaType> allowedTypes = const {
      BucketMediaType.photo,
      BucketMediaType.video,
    },
    SyncPreferences? preferences,
  }) async {
    final existingBuckets = await getBuckets();
    if (existingBuckets.length >= maxFreeBuckets) {
      throw BucketLimitException(maxFreeBuckets);
    }
    await _telegramService.waitUntilReady(timeout: const Duration(seconds: 45));

    final response = await _telegramReliability.executeWrite(
      {
        '@type': 'createNewSupergroupChat',
        'title': name,
        'is_channel': true,
        'description': description,
      },
      operation: 'create_bucket',
      timeout: const Duration(seconds: 20),
    );

    var chatId = _extractInt(response['id']);

    if (chatId == null) {
      TelegramUpdate event;
      try {
        event = await _telegramService.waitForUpdate(
          (u) => u['@type'] == 'updateNewChat' && u['chat']?['title'] == name,
          timeout: const Duration(seconds: 20),
        );
      } catch (error) {
        throw TelegramErrorParser.fromThrown(error, operation: 'create_bucket');
      }
      chatId = _extractInt(event['chat']?['id']);
    }

    if (chatId == null) {
      throw const TelegramError(
        code: null,
        tdlibMessage: 'Telegram did not return a chat identifier',
        operation: 'create_bucket',
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }

    final isFirst = existingBuckets.isEmpty;

    final entry = BucketsCompanion(
      chatId: Value(BigInt.from(chatId)),
      name: Value(name),
      allowedMediaTypes: Value(_serializeAllowedTypes(allowedTypes)),
      isActive: Value(isFirst),
      createdAt: Value(DateTime.now()),
    );

    final bucketId = await _db.into(_db.buckets).insert(entry);
    final inheritedPreferences =
        preferences ??
        (isFirst
            ? await _settingsService.getSyncPreferences()
            : await _settingsService.getSyncPreferences(
                bucketId: existingBuckets.first.id,
              ));
    await _settingsService.seedBucketSyncPreferences(
      bucketId,
      preferences ?? inheritedPreferences.copyWith(autoBackupEnabled: isFirst),
    );
    await setActiveBucket(bucketId);
    return bucketId;
  }

  Future<List<Bucket>> getBuckets() async {
    return _orderedBucketsQuery().get();
  }

  Stream<List<Bucket>> watchBuckets() {
    return _orderedBucketsQuery().watch();
  }

  Future<void> setActiveBucket(int bucketId) async {
    await _db.transaction(() async {
      final target = await (_db.select(
        _db.buckets,
      )..where((bucket) => bucket.id.equals(bucketId))).getSingleOrNull();
      if (target == null) {
        throw StateError('The selected bucket no longer exists.');
      }

      await (_db.update(
        _db.buckets,
      )).write(const BucketsCompanion(isActive: Value(false)));

      await (_db.update(_db.buckets)..where((t) => t.id.equals(bucketId)))
          .write(const BucketsCompanion(isActive: Value(true)));
    });
  }

  Future<Bucket?> getActiveBucket() async {
    final buckets = await getBuckets();
    if (buckets.isEmpty) return null;

    final active = buckets.where((bucket) => bucket.isActive).toList();

    if (active.length > 1) {
      final first = active.first;
      await setActiveBucket(first.id);
      return first;
    }

    if (active.isEmpty) {
      final first = buckets.first;
      await setActiveBucket(first.id);
      return first.copyWith(isActive: true);
    }

    return active.first;
  }

  SimpleSelectStatement<$BucketsTable, Bucket> _orderedBucketsQuery() {
    return _db.select(_db.buckets)..orderBy([
      (bucket) => OrderingTerm.asc(bucket.createdAt),
      (bucket) => OrderingTerm.asc(bucket.id),
    ]);
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _serializeAllowedTypes(Set<BucketMediaType> types) {
    final normalized = types.isEmpty
        ? {BucketMediaType.photo, BucketMediaType.video}
        : types;
    return normalized.map((e) => e.name).join(',');
  }
}

class BucketLimitException implements Exception {
  final int maxBuckets;

  const BucketLimitException(this.maxBuckets);

  @override
  String toString() {
    return 'You can create up to $maxBuckets buckets in this version.';
  }
}
