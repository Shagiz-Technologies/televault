import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/core/services/diagnostics_service.dart';
import 'package:tele_vault/src/core/services/telegram_gateway.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/library/repositories/gallery_repository.dart';
import 'package:tele_vault/src/features/library/services/gallery_service.dart';
import 'package:tele_vault/src/features/library/services/media_permission_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';
import 'package:tele_vault/src/features/sync/services/file_uploader.dart';
import 'package:tele_vault/src/features/sync/services/local_media_access_reconciler.dart';
import 'package:tele_vault/src/features/sync/services/sync_constraints_service.dart';
import 'package:tele_vault/src/features/sync/services/sync_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settings;
  late FileUploader uploader;
  late _NoopTelegramGateway telegram;
  late TelegramReliabilityService reliability;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
    telegram = _NoopTelegramGateway();
    reliability = TelegramReliabilityService(
      db,
      telegram,
      autoInitialize: false,
    );
    uploader = FileUploader(
      db,
      telegram,
      settings,
      DiagnosticsService(db),
      _AlwaysAllowedConstraints(settings),
      reliability,
    );
  });

  tearDown(() async {
    await uploader.dispose();
    await reliability.dispose();
    await db.close();
  });

  test(
    'incremental scan does not mark unvisited old media as deleted',
    () async {
      final bucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(
              chatId: BigInt.from(1001),
              name: 'Photos',
              isActive: const Value(true),
            ),
          );
      await settings.seedBucketSyncPreferences(
        bucketId,
        const SyncPreferences(autoBackupEnabled: true),
      );

      final boundaryTime = DateTime(2025, 1, 2);
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'bucket.$bucketId.sync_last_scan_at',
              value: DateTime(2025, 1, 3).toIso8601String(),
            ),
          );
      final boundaryFileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/boundary.jpg',
              assetId: const Value('boundary'),
              folderName: 'Camera',
              size: 10,
              bucketId: bucketId,
              status: Value(FileSyncStatus.pending.dbValue),
              dateAdded: Value(DateTime(2024, 12, 31)),
            ),
          );
      final inactiveBucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(
              chatId: BigInt.from(1002),
              name: 'Inactive',
            ),
          );
      final inactiveDate = DateTime(2024, 12, 30);
      final inactiveFileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/inactive-boundary.jpg',
              assetId: const Value('boundary'),
              folderName: 'Camera',
              size: 10,
              bucketId: inactiveBucketId,
              status: Value(FileSyncStatus.pending.dbValue),
              dateAdded: Value(inactiveDate),
            ),
          );
      final olderFileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/older.jpg',
              assetId: const Value('older-unvisited'),
              folderName: 'Camera',
              size: 10,
              bucketId: bucketId,
              status: Value(FileSyncStatus.synced.dbValue),
              dateAdded: Value(DateTime(2025, 1, 1)),
            ),
          );

      final gallery = _BoundaryGalleryRepository(boundaryTime);
      final service = SyncService(
        db,
        gallery,
        settings,
        DiagnosticsService(db),
        _AlwaysAllowedConstraints(settings),
        uploader,
        LocalMediaAccessReconciler(db, assetAccessLookup: (_) async => true),
      );

      await service.scanAndEnqueue();

      final olderFile = await (db.select(
        db.files,
      )..where((file) => file.id.equals(olderFileId))).getSingle();
      expect(olderFile.status, FileSyncStatus.synced.dbValue);
      expect(olderFile.deletedLocallyAt, null);
      final boundaryFile = await (db.select(
        db.files,
      )..where((file) => file.id.equals(boundaryFileId))).getSingle();
      final inactiveFile = await (db.select(
        db.files,
      )..where((file) => file.id.equals(inactiveFileId))).getSingle();
      expect(boundaryFile.dateAdded, boundaryTime);
      expect(inactiveFile.dateAdded, inactiveDate);
    },
  );
}

class _BoundaryGalleryRepository extends GalleryRepository {
  final DateTime boundaryTime;
  final AssetPathEntity album = AssetPathEntity(id: 'camera', name: 'Camera');

  _BoundaryGalleryRepository(this.boundaryTime)
    : super(
        GalleryService(),
        MediaPermissionService(
          platform: const _FullMediaPermissionPlatform(),
          isAndroid: true,
        ),
      );

  @override
  Future<List<AssetPathEntity>> getAlbums({
    MediaPermissionRequest request =
        const MediaPermissionRequest.photosAndVideos(),
  }) async => [album];

  @override
  Future<List<AssetEntity>> getAssets(
    AssetPathEntity album, {
    int page = 0,
    int size = 80,
  }) async {
    if (page > 0) return const [];
    return [
      AssetEntity(
        id: 'boundary',
        typeInt: AssetType.image.index,
        width: 1,
        height: 1,
        createDateSecond: boundaryTime.millisecondsSinceEpoch ~/ 1000,
      ),
    ];
  }
}

class _FullMediaPermissionPlatform implements MediaPermissionPlatform {
  const _FullMediaPermissionPlatform();

  static const status = MediaPermissionStatus(
    scope: MediaAccessScope.fullAccess,
    imageAccess: MediaTypeAccess.full,
    videoAccess: MediaTypeAccess.full,
    androidSdkInt: 35,
    supportsSelectedAccess: true,
  );

  @override
  Future<MediaPermissionStatus> getStatus(
    MediaPermissionRequest request,
  ) async => status;

  @override
  Future<MediaPermissionStatus> requestAccess(
    MediaPermissionRequest request,
  ) async => status;
}

class _AlwaysAllowedConstraints extends SyncConstraintsService {
  _AlwaysAllowedConstraints(super.settingsService);

  @override
  Future<bool> canRunAutomaticSync({int? bucketId}) async => true;

  @override
  Stream<void> watchConstraintChanges() => const Stream.empty();
}

class _NoopTelegramGateway implements TelegramGateway {
  @override
  Stream<TelegramUpdate> get updates => const Stream.empty();

  @override
  void send(TelegramRequest request) {}

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return const {'@type': 'ok'};
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    throw TimeoutException('No updates are emitted.');
  }

  @override
  Future<void> dispose() async {}
}
