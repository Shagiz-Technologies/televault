import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = SettingsService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertBucket(
    String name, {
    int chatId = 1,
    DateTime? createdAt,
    bool isActive = false,
  }) {
    return db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(chatId),
            name: name,
            isActive: Value(isActive),
            createdAt: Value(createdAt ?? DateTime.now()),
          ),
        );
  }

  test(
    'default sync preferences enable auto backup for first bucket',
    () async {
      final preferences = await service.getSyncPreferences();

      expect(preferences.autoBackupEnabled, isTrue);
      expect(preferences.includePhotos, isTrue);
      expect(preferences.includeVideos, isTrue);
      expect(preferences.maxFileSizeMb, defaultSyncMaxFileSizeMb);
      expect(preferences.uploadFormat, SyncUploadFormat.originalFile);
    },
  );

  test('main bucket preferences are stored globally and scoped', () async {
    final mainBucketId = await insertBucket(
      'Main',
      chatId: 1001,
      createdAt: DateTime(2026),
      isActive: true,
    );

    const preferences = SyncPreferences(
      autoBackupEnabled: true,
      includePhotos: true,
      includeVideos: false,
      wifiOnly: true,
      chargingOnly: true,
      albumMode: SyncAlbumMode.include,
      albumIds: {'camera'},
      maxFileSizeMb: 512,
      uploadFormat: SyncUploadFormat.compressedMedia,
      diagnosticsEnabled: true,
    );

    await service.saveSyncPreferences(preferences, bucketId: mainBucketId);

    final global = await service.getSyncPreferences();
    final scoped = await service.getSyncPreferences(bucketId: mainBucketId);

    expect(global.includeVideos, isFalse);
    expect(global.wifiOnly, isTrue);
    expect(global.albumMode, SyncAlbumMode.include);
    expect(global.albumIds, {'camera'});
    expect(global.uploadFormat, SyncUploadFormat.compressedMedia);
    expect(scoped.includeVideos, global.includeVideos);
    expect(scoped.uploadFormat, global.uploadFormat);
  });

  test(
    'later buckets inherit main settings with auto backup disabled',
    () async {
      final mainBucketId = await insertBucket(
        'Main',
        chatId: 1001,
        createdAt: DateTime(2026),
        isActive: true,
      );
      final secondBucketId = await insertBucket(
        'Videos',
        chatId: 1002,
        createdAt: DateTime(2026, 1, 2),
      );

      await service.saveSyncPreferences(
        const SyncPreferences(
          autoBackupEnabled: true,
          includePhotos: false,
          includeVideos: true,
          wifiOnly: true,
          albumMode: SyncAlbumMode.exclude,
          albumIds: {'screenshots'},
          maxFileSizeMb: 1024,
          uploadFormat: SyncUploadFormat.compressedMedia,
        ),
        bucketId: mainBucketId,
      );

      final inherited = await service.getSyncPreferences(
        bucketId: secondBucketId,
      );

      expect(inherited.autoBackupEnabled, isFalse);
      expect(inherited.includePhotos, isFalse);
      expect(inherited.includeVideos, isTrue);
      expect(inherited.wifiOnly, isTrue);
      expect(inherited.albumMode, SyncAlbumMode.exclude);
      expect(inherited.albumIds, {'screenshots'});
      expect(inherited.maxFileSizeMb, 1024);
      expect(inherited.uploadFormat, SyncUploadFormat.compressedMedia);
    },
  );

  test('bucket scoped preferences remain isolated after edits', () async {
    final mainBucketId = await insertBucket(
      'Main',
      chatId: 1001,
      createdAt: DateTime(2026),
      isActive: true,
    );
    final secondBucketId = await insertBucket(
      'Photos',
      chatId: 1002,
      createdAt: DateTime(2026, 1, 2),
    );

    await service.saveSyncPreferences(
      const SyncPreferences(
        autoBackupEnabled: true,
        includePhotos: true,
        includeVideos: true,
        maxFileSizeMb: defaultSyncMaxFileSizeMb,
      ),
      bucketId: mainBucketId,
    );
    await service.seedBucketSyncPreferences(
      secondBucketId,
      const SyncPreferences(
        autoBackupEnabled: false,
        includePhotos: true,
        includeVideos: false,
        maxFileSizeMb: 256,
        uploadFormat: SyncUploadFormat.compressedMedia,
      ),
    );
    await service.saveSyncPreferences(
      const SyncPreferences(
        autoBackupEnabled: true,
        includePhotos: false,
        includeVideos: true,
        maxFileSizeMb: 512,
      ),
      bucketId: mainBucketId,
    );

    final main = await service.getSyncPreferences(bucketId: mainBucketId);
    final second = await service.getSyncPreferences(bucketId: secondBucketId);

    expect(main.autoBackupEnabled, isTrue);
    expect(main.includePhotos, isFalse);
    expect(main.includeVideos, isTrue);
    expect(main.maxFileSizeMb, 512);

    expect(second.autoBackupEnabled, isFalse);
    expect(second.includePhotos, isTrue);
    expect(second.includeVideos, isFalse);
    expect(second.maxFileSizeMb, 256);
    expect(second.uploadFormat, SyncUploadFormat.compressedMedia);
  });

  test(
    'stored and imported upload limits are clamped to live capability',
    () async {
      var effectiveLimit = telegramFreeMaxFileSizeMb;
      final constrained = SettingsService(
        db,
        effectiveMaxFileSizeMb: () => effectiveLimit,
      );
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: SettingsService.keySyncMaxFileSizeMb,
              value: '3900',
            ),
          );
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'bucket.8.${SettingsService.keySyncMaxFileSizeMb}',
              value: '5000',
            ),
          );

      await constrained.normalizeStoredUploadLimits();

      expect(
        (await constrained.getSyncPreferences()).maxFileSizeMb,
        telegramFreeMaxFileSizeMb,
      );
      expect(
        (await constrained.getSyncPreferences(bucketId: 8)).maxFileSizeMb,
        telegramFreeMaxFileSizeMb,
      );

      effectiveLimit = telegramPremiumMaxFileSizeMb;
      await constrained.saveSyncPreferences(
        const SyncPreferences(maxFileSizeMb: 5000),
      );
      expect(
        (await constrained.getSyncPreferences()).maxFileSizeMb,
        telegramPremiumMaxFileSizeMb,
      );
    },
  );
}
