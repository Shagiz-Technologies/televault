import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/database/local_media_access_state.dart';
import '../../library/repositories/gallery_repository.dart';
import '../../library/services/media_permission_service.dart';

typedef MediaAssetAccessLookup = Future<bool> Function(String assetId);

final localMediaAccessReconcilerProvider = Provider<LocalMediaAccessReconciler>(
  (ref) {
    final repository = ref.watch(galleryRepositoryProvider);
    return LocalMediaAccessReconciler(
      ref.watch(databaseProvider),
      assetAccessLookup: (assetId) async =>
          await repository.getAssetById(assetId) != null,
    );
  },
);

class MediaAccessReconciliation {
  final int available;
  final int unavailable;

  const MediaAccessReconciliation({
    required this.available,
    required this.unavailable,
  });
}

class LocalMediaAccessReconciler {
  final AppDatabase _database;
  final MediaAssetAccessLookup _assetAccessLookup;

  LocalMediaAccessReconciler(
    this._database, {
    required MediaAssetAccessLookup assetAccessLookup,
  }) : _assetAccessLookup = assetAccessLookup;

  Future<MediaAccessReconciliation> reconcile({
    required int bucketId,
    required MediaPermissionStatus permission,
    Set<String> observedAssetIds = const {},
  }) async {
    final rows =
        await (_database.select(_database.files)..where(
              (row) =>
                  row.bucketId.equals(bucketId) &
                  row.isVaulted.equals(false) &
                  row.isEncrypted.equals(false) &
                  row.status.equals(FileSyncStatus.deletedLocal.dbValue).not(),
            ))
            .get();
    var available = 0;
    var unavailable = 0;

    for (final row in rows) {
      final assetId = row.assetId;
      if (assetId == null || assetId.isEmpty) continue;

      final shouldBeAvailable =
          permission.canReadMedia &&
          (observedAssetIds.contains(assetId) ||
              await _assetAccessLookup(assetId));
      final nextState = shouldBeAvailable
          ? LocalMediaAccessState.available
          : LocalMediaAccessState.accessUnavailable;
      if (nextState == LocalMediaAccessState.available) {
        available++;
      } else {
        unavailable++;
      }
      if (row.localMediaAccessState == nextState.dbValue) continue;

      await (_database.update(
        _database.files,
      )..where((table) => table.id.equals(row.id))).write(
        FilesCompanion(
          localMediaAccessState: Value(nextState.dbValue),
          nextRetryAt: nextState == LocalMediaAccessState.accessUnavailable
              ? const Value(null)
              : const Value.absent(),
        ),
      );
    }
    return MediaAccessReconciliation(
      available: available,
      unavailable: unavailable,
    );
  }
}
