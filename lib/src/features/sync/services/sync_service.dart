import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/database/local_media_access_state.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../buckets/services/bucket_service.dart';
import '../../library/repositories/gallery_repository.dart';
import '../../library/services/media_permission_service.dart';
import '../../settings/services/settings_service.dart';
import 'file_uploader.dart';
import 'local_media_access_reconciler.dart';
import 'sync_constraints_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(databaseProvider),
    ref.watch(galleryRepositoryProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(diagnosticsServiceProvider),
    ref.watch(syncConstraintsServiceProvider),
    ref.watch(fileUploaderProvider),
    ref.watch(localMediaAccessReconcilerProvider),
  );
});

enum SyncStatus { idle, scanning, syncing }

class SyncService {
  final AppDatabase _db;
  final GalleryRepository _galleryRepo;
  final SettingsService _settingsService;
  final DiagnosticsService _diagnosticsService;
  final SyncConstraintsService _constraintsService;
  final FileUploader _uploader;
  final LocalMediaAccessReconciler _mediaAccessReconciler;

  static const _legacyLastScanAtKey = 'sync_last_scan_at';
  static const _legacyDeletedLocalRepairKey =
      'sync_deleted_local_repair_v1_completed';

  Timer? _syncTimer;
  StreamSubscription? _constraintsSub;
  bool _isScanning = false;

  SyncService(
    this._db,
    this._galleryRepo,
    this._settingsService,
    this._diagnosticsService,
    this._constraintsService,
    this._uploader,
    this._mediaAccessReconciler,
  );

  void startSyncLoop() {
    _syncTimer?.cancel();
    _constraintsSub ??= _constraintsService.watchConstraintChanges().listen((
      _,
    ) {
      scanAndEnqueue();
      _uploader.wake();
    });
    scanAndEnqueue();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      scanAndEnqueue();
    });
  }

  void stopSyncLoop() {
    _syncTimer?.cancel();
    _constraintsSub?.cancel();
    _constraintsSub = null;
  }

  Future<void> syncNow({bool ignoreConstraints = true}) async {
    unawaited(
      _diagnosticsService.increment(DiagnosticsService.syncManualRunKey),
    );
    final targetBucketId = ignoreConstraints
        ? (await _getActiveBucket())?.id
        : null;
    await scanAndEnqueue(ignoreConstraints: ignoreConstraints);
    if (ignoreConstraints && targetBucketId == null) return;
    _uploader.wake(
      ignoreConstraints: ignoreConstraints,
      bucketId: targetBucketId,
    );
  }

  Future<void> scanAndEnqueue({bool ignoreConstraints = false}) async {
    await _scanAndEnqueue(
      ignoreConstraints: ignoreConstraints,
      activeOnly: ignoreConstraints,
    );
  }

  Future<void> scanAndEnqueueAllBucketsForSafeUninstall() async {
    await _scanAndEnqueue(ignoreConstraints: true, activeOnly: false);
  }

  Future<void> _scanAndEnqueue({
    required bool ignoreConstraints,
    required bool activeOnly,
  }) async {
    if (_isScanning) return;
    _isScanning = true;
    try {
      final buckets = await _targetBuckets(activeOnly: activeOnly);
      if (buckets.isEmpty) return;

      for (final bucket in buckets) {
        final preferences = await _settingsService.getSyncPreferences(
          bucketId: bucket.id,
        );
        if (!ignoreConstraints) {
          if (!preferences.autoBackupEnabled) continue;
          final constraintsAllowed = await _constraintsService
              .canRunAutomaticSync(bucketId: bucket.id);
          if (!constraintsAllowed) continue;
        }
        final repairLegacyDeletedRows = await _needsLegacyDeletedLocalRepair(
          bucket.id,
        );
        final completedScan = await _scanBucket(
          bucket,
          preferences,
          repairLegacyDeletedRows: repairLegacyDeletedRows,
        );
        if (repairLegacyDeletedRows && completedScan) {
          await _markLegacyDeletedLocalRepairComplete(bucket.id);
        }
      }
    } finally {
      _isScanning = false;
    }
  }

  Future<bool> _scanBucket(
    Bucket bucket,
    SyncPreferences preferences, {
    required bool repairLegacyDeletedRows,
  }) async {
    final bucketId = bucket.id;
    final allowedTypes = _parseAllowedTypes(bucket.allowedMediaTypes);
    final permissionRequest = MediaPermissionRequest(
      includeImages:
          preferences.includePhotos &&
          allowedTypes.contains(BucketMediaType.photo),
      includeVideos:
          preferences.includeVideos &&
          allowedTypes.contains(BucketMediaType.video),
    );
    final permission = await _galleryRepo.getPermissionStatus(
      permissionRequest,
    );
    if (!permission.canReadMedia) {
      await _mediaAccessReconciler.reconcile(
        bucketId: bucketId,
        permission: permission,
      );
      return false;
    }

    final allAlbums = await _galleryRepo.getAlbums(request: permissionRequest);
    if (allAlbums.isEmpty) {
      await _mediaAccessReconciler.reconcile(
        bucketId: bucketId,
        permission: permission,
      );
      return true;
    }
    final albums = _filterAlbums(allAlbums, preferences);
    if (albums.isEmpty) {
      await _mediaAccessReconciler.reconcile(
        bucketId: bucketId,
        permission: permission,
      );
      return true;
    }

    final dbFiles = await (_db.select(
      _db.files,
    )..where((t) => t.bucketId.equals(bucketId))).get();

    final dbMapById = <String, File>{};
    final dbMapByPath = <String, File>{};
    for (final file in dbFiles) {
      if (file.assetId != null) dbMapById[file.assetId!] = file;
      dbMapByPath[file.localPath] = file;
    }

    final globallyVisitedAssets = <String>{};
    var newCount = 0;
    final lastScanAt =
        repairLegacyDeletedRows ||
            permission.scope == MediaAccessScope.limitedAccess
        ? null
        : await _getLastScanAt(bucketId);
    final maxBytes = preferences.maxFileSizeMb * 1024 * 1024;

    for (final album in albums) {
      var page = 0;
      var hasMore = true;
      var reachedOldAssets = false;
      const pageSize = 400;

      while (hasMore && !reachedOldAssets) {
        final assets = await _galleryRepo.getAssets(
          album,
          page: page,
          size: pageSize,
        );
        if (assets.isEmpty) break;
        if (assets.length < pageSize) hasMore = false;

        for (final asset in assets) {
          if (globallyVisitedAssets.contains(asset.id)) {
            continue;
          }
          globallyVisitedAssets.add(asset.id);
          final existingById = dbMapById[asset.id];
          if (existingById != null) {
            if (existingById.localMediaAccessState !=
                LocalMediaAccessState.available.dbValue) {
              await (_db.update(
                _db.files,
              )..where((t) => t.id.equals(existingById.id))).write(
                FilesCompanion(
                  localMediaAccessState: Value(
                    LocalMediaAccessState.available.dbValue,
                  ),
                ),
              );
            }
            if (!existingById.localPathResolved) {
              await _resolveRestoredLocalPath(existingById, asset, album.name);
            }
            await _repairQueueDateAdded(existingById, asset.createDateTime);
            if (repairLegacyDeletedRows &&
                existingById.status == FileSyncStatus.deletedLocal.dbValue) {
              await _restoreLegacyDeletedLocalRow(existingById);
            }
            if (lastScanAt != null &&
                asset.createDateTime.isBefore(lastScanAt)) {
              reachedOldAssets = true;
            }
            continue;
          }

          if (!_matchesMediaPreferences(asset, preferences, allowedTypes)) {
            continue;
          }

          final localFile = await asset.file;
          if (localFile == null) continue;

          final localPath = localFile.absolute.path;
          if (dbMapById.containsKey(asset.id)) continue;

          if (dbMapByPath.containsKey(localPath)) {
            final row = dbMapByPath[localPath]!;
            await (_db.update(
              _db.files,
            )..where((t) => t.id.equals(row.id))).write(
              FilesCompanion(
                assetId: Value(asset.id),
                localPathResolved: const Value(true),
                localMediaAccessState: Value(
                  LocalMediaAccessState.available.dbValue,
                ),
                dateAdded: Value(asset.createDateTime),
              ),
            );
            continue;
          }

          final size = await localFile.length();
          if (size > maxBytes) continue;

          await _db
              .into(_db.files)
              .insert(
                FilesCompanion(
                  localPath: Value(localPath),
                  localPathResolved: const Value(true),
                  localMediaAccessState: Value(
                    LocalMediaAccessState.available.dbValue,
                  ),
                  assetId: Value(asset.id),
                  folderName: Value(album.name),
                  size: Value(size),
                  bucketId: Value(bucketId),
                  status: Value(FileSyncStatus.pending.dbValue),
                  dateAdded: Value(asset.createDateTime),
                  isVaulted: const Value(false),
                ),
              );
          newCount++;
        }
        page++;
      }
    }

    // Incremental scans intentionally stop once known older media is reached.
    // That partial result cannot safely prove that unseen database rows were
    // deleted from the device.
    await _setLastScanAt(bucketId, DateTime.now());
    await _mediaAccessReconciler.reconcile(
      bucketId: bucketId,
      permission: permission,
      observedAssetIds: globallyVisitedAssets,
    );

    if (newCount > 0) {
      _uploader.wake();
    }
    return true;
  }

  Future<void> _resolveRestoredLocalPath(
    File row,
    AssetEntity asset,
    String folderName,
  ) async {
    final localFile = await asset.originFile ?? await asset.file;
    if (localFile == null || !await localFile.exists()) return;
    final size = await localFile.length();
    await (_db.update(
      _db.files,
    )..where((table) => table.id.equals(row.id))).write(
      FilesCompanion(
        localPath: Value(localFile.absolute.path),
        localPathResolved: const Value(true),
        localMediaAccessState: Value(LocalMediaAccessState.available.dbValue),
        folderName: Value(folderName),
        size: Value(size),
        dateAdded: Value(asset.createDateTime),
      ),
    );
  }

  Future<void> _restoreLegacyDeletedLocalRow(File row) async {
    final restoredStatus = row.telegramMessageId == null
        ? FileSyncStatus.pending
        : FileSyncStatus.synced;
    await (_db.update(_db.files)..where((t) => t.id.equals(row.id))).write(
      FilesCompanion(
        status: Value(restoredStatus.dbValue),
        deletedLocallyAt: const Value(null),
      ),
    );
  }

  Future<bool> _needsLegacyDeletedLocalRepair(int bucketId) async {
    final setting =
        await (_db.select(_db.appSettings)..where(
              (t) => t.key.equals('$_legacyDeletedLocalRepairKey.$bucketId'),
            ))
            .getSingleOrNull();
    return setting?.value != 'true';
  }

  Future<void> _markLegacyDeletedLocalRepairComplete(int bucketId) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: '$_legacyDeletedLocalRepairKey.$bucketId',
            value: 'true',
          ),
        );
  }

  List<AssetPathEntity> _filterAlbums(
    List<AssetPathEntity> allAlbums,
    SyncPreferences preferences,
  ) {
    if (preferences.albumMode == SyncAlbumMode.all) {
      return allAlbums;
    }

    if (preferences.albumMode == SyncAlbumMode.include &&
        preferences.albumIds.isEmpty) {
      return const [];
    }

    if (preferences.albumMode == SyncAlbumMode.exclude &&
        preferences.albumIds.isEmpty) {
      return allAlbums;
    }

    return allAlbums.where((album) {
      final selected = preferences.albumIds.contains(album.id);
      return switch (preferences.albumMode) {
        SyncAlbumMode.all => true,
        SyncAlbumMode.include => selected,
        SyncAlbumMode.exclude => !selected,
      };
    }).toList();
  }

  bool _matchesMediaPreferences(
    AssetEntity asset,
    SyncPreferences preferences,
    Set<BucketMediaType> allowedTypes,
  ) {
    if (asset.type == AssetType.image &&
        (!preferences.includePhotos ||
            !allowedTypes.contains(BucketMediaType.photo))) {
      return false;
    }
    if (asset.type == AssetType.video &&
        (!preferences.includeVideos ||
            !allowedTypes.contains(BucketMediaType.video))) {
      return false;
    }
    return true;
  }

  Future<void> _repairQueueDateAdded(File row, DateTime mediaCreatedAt) async {
    if (row.status == FileSyncStatus.synced.dbValue ||
        row.status == FileSyncStatus.deletedLocal.dbValue) {
      return;
    }
    if (row.dateAdded == mediaCreatedAt) return;
    await (_db.update(_db.files)..where((t) => t.id.equals(row.id))).write(
      FilesCompanion(dateAdded: Value(mediaCreatedAt)),
    );
  }

  Set<BucketMediaType> _parseAllowedTypes(String raw) {
    final items = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (items.isEmpty) {
      return {BucketMediaType.photo, BucketMediaType.video};
    }
    return BucketMediaType.values.where((t) => items.contains(t.name)).toSet();
  }

  Future<List<Bucket>> _targetBuckets({required bool activeOnly}) async {
    if (activeOnly) {
      final active = await _getActiveBucket();
      return active == null ? const [] : [active];
    }
    return (_db.select(_db.buckets)..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
        .get();
  }

  Future<Bucket?> _getActiveBucket() async {
    final buckets =
        await (_db.select(_db.buckets)..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    if (buckets.isEmpty) return null;

    final active = buckets.where((bucket) => bucket.isActive).toList();
    if (active.length == 1) return active.first;

    final normalized = active.isEmpty ? buckets.first : active.first;
    await (_db.update(
      _db.buckets,
    )).write(const BucketsCompanion(isActive: Value(false)));
    await (_db.update(_db.buckets)..where((t) => t.id.equals(normalized.id)))
        .write(const BucketsCompanion(isActive: Value(true)));
    return normalized.copyWith(isActive: true);
  }

  Future<DateTime?> _getLastScanAt(int bucketId) async {
    final scopedKey = _lastScanAtKey(bucketId);
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(scopedKey))).getSingleOrNull();

    if (row != null) return DateTime.tryParse(row.value);

    final mainBucketId = await _settingsService.getMainBucketId();
    if (mainBucketId != bucketId) return null;

    final legacyRow = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(_legacyLastScanAtKey))).getSingleOrNull();
    return legacyRow == null ? null : DateTime.tryParse(legacyRow.value);
  }

  Future<void> _setLastScanAt(int bucketId, DateTime value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _lastScanAtKey(bucketId),
            value: value.toIso8601String(),
          ),
        );
  }

  String _lastScanAtKey(int bucketId) {
    return '${SettingsService.bucketSettingPrefix}.$bucketId.$_legacyLastScanAtKey';
  }
}
