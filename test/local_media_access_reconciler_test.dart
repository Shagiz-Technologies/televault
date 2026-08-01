import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/core/database/local_media_access_state.dart';
import 'package:tele_vault/src/features/library/services/media_permission_service.dart';
import 'package:tele_vault/src/features/sync/services/local_media_access_reconciler.dart';

void main() {
  late AppDatabase database;
  late int bucketId;
  var accessible = false;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    bucketId = await database
        .into(database.buckets)
        .insert(
          BucketsCompanion.insert(chatId: BigInt.from(77), name: 'Photos'),
        );
  });

  tearDown(() => database.close());

  test('inaccessible media is not classified as deleted', () async {
    await _insertMedia(database, bucketId);
    final reconciler = LocalMediaAccessReconciler(
      database,
      assetAccessLookup: (_) async => accessible,
    );

    await reconciler.reconcile(
      bucketId: bucketId,
      permission: _permission(MediaAccessScope.limitedAccess),
    );
    final row = await database.select(database.files).getSingle();

    expect(
      row.localMediaAccessState,
      LocalMediaAccessState.accessUnavailable.dbValue,
    );
    expect(row.status, FileSyncStatus.pending.dbValue);
    expect(row.telegramMessageId, 123);
    expect(row.telegramFileId, 456);
    expect(row.deletedLocallyAt, isNull);
  });

  test('limited-to-full transition restores accessible state', () async {
    await _insertMedia(database, bucketId);
    final reconciler = LocalMediaAccessReconciler(
      database,
      assetAccessLookup: (_) async => accessible,
    );
    await reconciler.reconcile(
      bucketId: bucketId,
      permission: _permission(MediaAccessScope.limitedAccess),
    );
    accessible = true;

    await reconciler.reconcile(
      bucketId: bucketId,
      permission: _permission(MediaAccessScope.fullAccess),
    );
    final row = await database.select(database.files).getSingle();

    expect(row.localMediaAccessState, LocalMediaAccessState.available.dbValue);
    expect(row.telegramMessageId, 123);
  });

  test(
    'denied access pauses local media without deleting remote state',
    () async {
      await _insertMedia(database, bucketId);
      final reconciler = LocalMediaAccessReconciler(
        database,
        assetAccessLookup: (_) async => true,
      );

      await reconciler.reconcile(
        bucketId: bucketId,
        permission: _permission(MediaAccessScope.permanentlyDenied),
      );
      final row = await database.select(database.files).getSingle();

      expect(
        row.localMediaAccessState,
        LocalMediaAccessState.accessUnavailable.dbValue,
      );
      expect(row.telegramMessageId, 123);
    },
  );
}

Future<void> _insertMedia(AppDatabase database, int bucketId) {
  return database
      .into(database.files)
      .insert(
        FilesCompanion.insert(
          localPath: '/untrusted/device/path.jpg',
          assetId: const Value('asset-1'),
          folderName: 'Camera',
          size: 42,
          bucketId: bucketId,
          status: Value(FileSyncStatus.pending.dbValue),
          telegramMessageId: const Value(123),
          telegramFileId: const Value(456),
        ),
      );
}

MediaPermissionStatus _permission(MediaAccessScope scope) {
  return MediaPermissionStatus(
    scope: scope,
    imageAccess: scope == MediaAccessScope.fullAccess
        ? MediaTypeAccess.full
        : MediaTypeAccess.selected,
    videoAccess: scope == MediaAccessScope.fullAccess
        ? MediaTypeAccess.full
        : MediaTypeAccess.selected,
    androidSdkInt: 34,
  );
}
