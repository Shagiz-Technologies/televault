import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../sync/services/file_uploader.dart';
import '../../vault/services/vault_service.dart';
import '../../vault/services/vault_migration_service.dart';
import '../repositories/gallery_repository.dart';
import '../services/media_permission_service.dart';
import '../services/media_permission_policy.dart';

class LibraryState {
  final bool isLoading;
  final MediaPermissionStatus permissionStatus;
  final MediaPermissionRequest permissionRequest;
  final AssetPathEntity? currentAlbum;
  final bool isAllPhotos;
  final List<AssetEntity> assets;
  final int currentPage;
  final bool hasMore;
  final bool isSelecting;
  final Set<String> selectedIds;
  final Map<String, int> assetStatus;
  final Map<String, MediaLabelInfo?> assetLabels;

  const LibraryState({
    this.isLoading = true,
    this.permissionStatus = const MediaPermissionStatus.notDetermined(),
    this.permissionRequest = const MediaPermissionRequest.photosAndVideos(),
    this.currentAlbum,
    this.isAllPhotos = true,
    this.assets = const [],
    this.currentPage = 0,
    this.hasMore = true,
    this.isSelecting = false,
    this.selectedIds = const {},
    this.assetStatus = const {},
    this.assetLabels = const {},
  });

  LibraryState copyWith({
    bool? isLoading,
    MediaPermissionStatus? permissionStatus,
    MediaPermissionRequest? permissionRequest,
    AssetPathEntity? currentAlbum,
    bool? isAllPhotos,
    List<AssetEntity>? assets,
    int? currentPage,
    bool? hasMore,
    bool? isSelecting,
    Set<String>? selectedIds,
    Map<String, int>? assetStatus,
    Map<String, MediaLabelInfo?>? assetLabels,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      permissionRequest: permissionRequest ?? this.permissionRequest,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      isAllPhotos: isAllPhotos ?? this.isAllPhotos,
      assets: assets ?? this.assets,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isSelecting: isSelecting ?? this.isSelecting,
      selectedIds: selectedIds ?? this.selectedIds,
      assetStatus: assetStatus ?? this.assetStatus,
      assetLabels: assetLabels ?? this.assetLabels,
    );
  }

  bool get hasPermission => permissionStatus.canReadMedia;
}

class MediaLabelInfo {
  final int id;
  final String name;
  final String colorHex;
  final String? emoji;

  const MediaLabelInfo({
    required this.id,
    required this.name,
    required this.colorHex,
    this.emoji,
  });
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
      return LibraryController(
        ref.watch(galleryRepositoryProvider),
        ref.watch(databaseProvider),
        ref.watch(vaultServiceProvider),
        ref.watch(fileUploaderProvider),
        ref.watch(mediaPermissionPolicyProvider),
      );
    });

class LibraryController extends StateNotifier<LibraryState> {
  final GalleryRepository _repo;
  final AppDatabase _db;
  final VaultService _vaultService;
  final FileUploader _uploader;
  final MediaPermissionPolicy _permissionPolicy;
  StreamSubscription? _statusSub;

  LibraryController(
    this._repo,
    this._db,
    this._vaultService,
    this._uploader,
    this._permissionPolicy,
  ) : super(const LibraryState()) {
    _init();
  }

  Future<void> _init() async {
    final request = await _resolvePermissionRequest();
    final permission = await _repo.getPermissionStatus(request);
    state = state.copyWith(
      permissionRequest: request,
      permissionStatus: permission,
    );
    if (!permission.canReadMedia) {
      state = state.copyWith(isLoading: false, assets: const []);
      return;
    }

    await _loadInitialAlbum();
  }

  Future<MediaPermissionStatus> requestMediaAccess() async {
    final permission = await _repo.requestPermission(state.permissionRequest);
    await _applyPermission(permission);
    return permission;
  }

  Future<MediaPermissionStatus> updateSelectedAccess() async {
    final permission = await _repo.updateSelectedAccess(
      state.permissionRequest,
    );
    await _applyPermission(permission, forceReload: true);
    return permission;
  }

  Future<MediaPermissionStatus> refreshPermission() async {
    final request = await _resolvePermissionRequest();
    final permission = await _repo.getPermissionStatus(request);
    state = state.copyWith(permissionRequest: request);
    await _applyPermission(
      permission,
      forceReload: permission.scope == MediaAccessScope.limitedAccess,
    );
    return permission;
  }

  Future<void> openMediaSettings() => _repo.openSettings();

  Future<void> _applyPermission(
    MediaPermissionStatus permission, {
    bool forceReload = false,
  }) async {
    final previouslyReadable = state.permissionStatus.canReadMedia;
    final scopeChanged = state.permissionStatus.scope != permission.scope;
    final mediaTypesChanged =
        state.permissionStatus.imageAccess != permission.imageAccess ||
        state.permissionStatus.videoAccess != permission.videoAccess;
    state = state.copyWith(permissionStatus: permission, isLoading: false);
    if (!permission.canReadMedia) {
      state = state.copyWith(
        assets: const [],
        assetStatus: const {},
        assetLabels: const {},
        currentPage: 0,
        hasMore: false,
      );
      return;
    }
    if (forceReload ||
        !previouslyReadable ||
        scopeChanged ||
        mediaTypesChanged) {
      await _loadInitialAlbum();
    }
  }

  Future<void> _loadInitialAlbum() async {
    final album = await _repo.getRecentAlbum(request: state.permissionRequest);
    if (album != null) {
      await _loadAssets(album, page: 0, clearExisting: true);
    } else {
      state = state.copyWith(
        isLoading: false,
        assets: const [],
        currentPage: 0,
        hasMore: false,
      );
    }
  }

  Future<MediaPermissionRequest> _resolvePermissionRequest() async {
    return _permissionPolicy.activeRequest();
  }

  Future<void> _loadAssets(
    AssetPathEntity album, {
    required int page,
    bool clearExisting = false,
  }) async {
    state = state.copyWith(isLoading: true, currentAlbum: album);

    final newAssets = await _repo.getAssets(album, page: page);
    newAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    final vaultedAssetIds =
        (await (_db.select(_db.files)..where(
                  (t) =>
                      t.isVaulted.equals(true) &
                      t.localPathResolved.equals(true),
                ))
                .get())
            .map((f) => f.assetId)
            .whereType<String>()
            .toSet();

    final visibleAssets = newAssets
        .where((a) => !vaultedAssetIds.contains(a.id))
        .toList();

    final combinedAssets = clearExisting
        ? visibleAssets
        : [...state.assets, ...visibleAssets];

    state = state.copyWith(
      isLoading: false,
      currentAlbum: album,
      assets: combinedAssets,
      currentPage: page,
      hasMore: newAssets.isNotEmpty,
    );

    if (combinedAssets.isNotEmpty) {
      _watchStatuses(combinedAssets);
    }
  }

  void _watchStatuses(List<AssetEntity> assets) {
    _statusSub?.cancel();
    final ids = assets.map((e) => e.id).toList();

    if (ids.isEmpty) {
      state = state.copyWith(assetStatus: const {}, assetLabels: const {});
      return;
    }

    final placeholders = List.filled(ids.length, '?').join(', ');
    final variables = ids.map(Variable.withString).toList(growable: false);
    _statusSub = _db
        .customSelect(
          '''
          SELECT
            f.asset_id,
            f.status,
            f.label_id,
            l.name AS label_name,
            l.color_hex AS label_color_hex,
            l.emoji AS label_emoji
          FROM files f
          INNER JOIN buckets b ON b.id = f.bucket_id
          LEFT JOIN labels l ON l.id = f.label_id
          WHERE b.is_active = 1
            AND f.asset_id IN ($placeholders)
          ''',
          variables: variables,
          readsFrom: {_db.files, _db.buckets, _db.labels},
        )
        .watch()
        .listen((rows) {
          final statusMap = <String, int>{};
          final labelMap = <String, MediaLabelInfo?>{};

          for (final row in rows) {
            final assetId = row.readNullable<String>('asset_id');
            if (assetId == null) continue;

            statusMap[assetId] = row.read<int>('status');
            final labelId = row.readNullable<int>('label_id');
            if (labelId == null) {
              labelMap[assetId] = null;
              continue;
            }

            labelMap[assetId] = MediaLabelInfo(
              id: labelId,
              name: row.read<String>('label_name'),
              colorHex: row.read<String>('label_color_hex'),
              emoji: row.readNullable<String>('label_emoji'),
            );
          }

          state = state.copyWith(assetStatus: statusMap, assetLabels: labelMap);
        });
  }

  Future<void> _refreshVisibleStatuses() async {
    if (state.assets.isEmpty) {
      state = state.copyWith(assetStatus: const {}, assetLabels: const {});
    } else {
      _watchStatuses(state.assets);
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.currentAlbum == null) return;
    await _loadAssets(state.currentAlbum!, page: state.currentPage + 1);
  }

  Future<void> selectAlbum(AssetPathEntity? album) async {
    if (album == null) {
      await showAllPhotos();
      return;
    }

    state = state.copyWith(
      currentAlbum: album,
      isAllPhotos: false,
      isLoading: true,
      assets: [],
      currentPage: 0,
      hasMore: true,
    );
    await _loadAssets(album, page: 0, clearExisting: true);
  }

  Future<void> showAllPhotos() async {
    final album = await _repo.getRecentAlbum();
    if (album == null) return;

    state = state.copyWith(
      currentAlbum: null,
      isAllPhotos: true,
      isLoading: true,
      assets: [],
      currentPage: 0,
      hasMore: true,
    );
    await _loadAssets(album, page: 0, clearExisting: true);
  }

  void toggleSelectionMode() {
    if (state.isSelecting) {
      state = state.copyWith(isSelecting: false, selectedIds: {});
    } else {
      state = state.copyWith(isSelecting: true);
    }
  }

  void toggleItemSelection(AssetEntity asset) {
    if (!state.isSelecting) return;
    final newSet = Set<String>.from(state.selectedIds);
    if (newSet.contains(asset.id)) {
      newSet.remove(asset.id);
    } else {
      newSet.add(asset.id);
    }
    state = state.copyWith(selectedIds: newSet);
  }

  void setItemsSelection(List<AssetEntity> assets, {required bool selected}) {
    if (!state.isSelecting) return;
    final newSet = Set<String>.from(state.selectedIds);
    for (final asset in assets) {
      if (selected) {
        newSet.add(asset.id);
      } else {
        newSet.remove(asset.id);
      }
    }
    state = state.copyWith(selectedIds: newSet);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  void exitSelectionMode() {
    state = state.copyWith(isSelecting: false, selectedIds: {});
  }

  Future<void> refreshCurrentView() async {
    if (!state.permissionStatus.canReadMedia) return;
    final album =
        state.currentAlbum ??
        await _repo.getRecentAlbum(request: state.permissionRequest);
    if (album == null) {
      state = state.copyWith(
        isLoading: false,
        assets: const [],
        currentPage: 0,
        hasMore: false,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      assets: const [],
      currentPage: 0,
      hasMore: true,
    );
    await _loadAssets(album, page: 0, clearExisting: true);
  }

  Future<int> markAssetsDeletedLocally(Set<String> assetIds) async {
    if (assetIds.isEmpty) return 0;

    final ids = assetIds.toList(growable: false);
    final updated =
        await (_db.update(_db.files)..where((t) => t.assetId.isIn(ids))).write(
          FilesCompanion(
            status: Value(FileSyncStatus.deletedLocal.dbValue),
            deletedLocallyAt: Value(DateTime.now()),
          ),
        );

    final remainingAssets = state.assets
        .where((asset) => !assetIds.contains(asset.id))
        .toList(growable: false);
    final remainingSelection = Set<String>.from(state.selectedIds)
      ..removeAll(assetIds);
    final nextStatus = Map<String, int>.from(state.assetStatus)
      ..removeWhere((id, _) => assetIds.contains(id));
    final nextLabels = Map<String, MediaLabelInfo?>.from(state.assetLabels)
      ..removeWhere((id, _) => assetIds.contains(id));

    state = state.copyWith(
      assets: remainingAssets,
      selectedIds: remainingSelection,
      isSelecting: state.isSelecting && remainingSelection.isNotEmpty,
      assetStatus: nextStatus,
      assetLabels: nextLabels,
    );

    await _refreshVisibleStatuses();
    return updated;
  }

  Future<void> moveToVault({required String pin}) async {
    if (state.selectedIds.isEmpty) return;

    final ids = state.selectedIds.toList();
    final selectedAssets = state.assets
        .where((asset) => ids.contains(asset.id))
        .toList(growable: false);

    await moveAssetsToVault(selectedAssets, pin: pin);

    if (state.currentAlbum != null) {
      await _loadAssets(state.currentAlbum!, page: 0, clearExisting: true);
    }

    _uploader.wake();
    toggleSelectionMode();
  }

  Future<int> moveSingleAssetToVault(
    AssetEntity asset, {
    required String pin,
  }) async {
    final moved = await moveAssetsToVault([asset], pin: pin);
    if (moved > 0) {
      if (state.currentAlbum != null) {
        await _loadAssets(state.currentAlbum!, page: 0, clearExisting: true);
      }
      _uploader.wake();
    }
    return moved;
  }

  Future<int> moveAssetsToVault(
    List<AssetEntity> selectedAssets, {
    required String pin,
  }) async {
    if (selectedAssets.isEmpty) return 0;

    final ids = selectedAssets.map((asset) => asset.id).toList(growable: false);
    final activeBucketId = await _getActiveBucketId();
    if (activeBucketId == null) return 0;

    final rows =
        await (_db.select(_db.files)..where(
              (t) => t.assetId.isIn(ids) & t.bucketId.equals(activeBucketId),
            ))
            .get();
    final rowByAssetId = {
      for (final row in rows)
        if (row.assetId != null) row.assetId!: row,
    };

    var moved = 0;
    for (final selectedAsset in selectedAssets) {
      final assetId = selectedAsset.id;

      final existing = rowByAssetId[assetId];
      final sourceFile = await selectedAsset.file;
      if (sourceFile == null) continue;

      final source = io.File(sourceFile.path);
      final encrypted = await _vaultService.encryptFile(source);
      final encryptedFile = io.File(encrypted.path);
      try {
        final verifiedAt = await _vaultService.verifyFile(
          encryptedFile,
          expectedPlaintext: source,
        );
        final vaultFields = FilesCompanion(
          localPath: Value(encrypted.path),
          size: Value(encrypted.encryptedSize),
          status: Value(FileSyncStatus.pending.dbValue),
          isVaulted: const Value(true),
          isEncrypted: const Value(true),
          encryptionVersion: Value(encrypted.version),
          ivB64: Value(encrypted.ivB64),
          vaultFormatVersion: Value(encrypted.version),
          encryptedObjectId: Value(encrypted.objectId),
          encryptedSize: Value(encrypted.encryptedSize),
          originalSize: Value(encrypted.originalSize),
          vaultIntegrityStatus: const Value(VaultIntegrityStates.verified),
          vaultMigrationStatus: const Value(VaultMigrationStates.notRequired),
          keyWrappingVersion: Value(encrypted.keyWrappingVersion),
          lastVerifiedAt: Value(verifiedAt),
          telegramMessageId: const Value(null),
          telegramFileId: const Value(null),
          lastError: const Value(null),
          retryCount: const Value(0),
          nextRetryAt: const Value(null),
          dateAdded: Value(selectedAsset.createDateTime),
        );

        if (existing == null) {
          await _db
              .into(_db.files)
              .insert(
                vaultFields.copyWith(
                  assetId: Value(assetId),
                  folderName: Value(selectedAsset.title ?? 'Unknown'),
                  bucketId: Value(activeBucketId),
                ),
              );
        } else {
          await (_db.update(
            _db.files,
          )..where((t) => t.id.equals(existing.id))).write(vaultFields);
        }
      } on Object {
        if (await encryptedFile.exists()) await encryptedFile.delete();
        rethrow;
      }
      moved++;
    }

    return moved;
  }

  Future<List<Label>> getLabels() async {
    return (_db.select(
      _db.labels,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<int?> createLabel({
    required String name,
    required String colorHex,
    String? emoji,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 11) return null;

    final existing =
        await (_db.select(_db.labels)
              ..where((t) => t.name.lower().equals(trimmed.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    return _db
        .into(_db.labels)
        .insert(
          LabelsCompanion.insert(
            name: trimmed,
            colorHex: Value(colorHex),
            emoji: Value(emoji?.trim().isEmpty == true ? null : emoji?.trim()),
          ),
        );
  }

  Future<int> applyLabelToSelection(int? labelId) async {
    if (state.selectedIds.isEmpty) return 0;
    final activeBucketId = await _getActiveBucketId();
    if (activeBucketId == null) return 0;

    final selectedIds = state.selectedIds.toList(growable: false);
    final selectedAssets = {
      for (final asset in state.assets)
        if (state.selectedIds.contains(asset.id)) asset.id: asset,
    };

    final existingRows =
        await (_db.select(_db.files)..where(
              (t) =>
                  t.assetId.isIn(selectedIds) &
                  t.bucketId.equals(activeBucketId),
            ))
            .get();
    final existingAssetIds = {
      for (final row in existingRows)
        if (row.assetId != null) row.assetId!,
    };

    final updated =
        await (_db.update(_db.files)..where(
              (t) =>
                  t.assetId.isIn(selectedIds) &
                  t.bucketId.equals(activeBucketId),
            ))
            .write(FilesCompanion(labelId: Value(labelId)));

    var inserted = 0;
    if (labelId != null) {
      final missingIds = selectedIds.where(
        (id) => !existingAssetIds.contains(id),
      );
      for (final assetId in missingIds) {
        final asset = selectedAssets[assetId];
        if (asset == null) continue;

        final file = await asset.file;
        if (file == null) continue;

        final size = await io.File(file.path).length();
        await _db
            .into(_db.files)
            .insertOnConflictUpdate(
              FilesCompanion.insert(
                localPath: file.path,
                assetId: Value(assetId),
                folderName: asset.title ?? 'Unknown',
                size: size,
                bucketId: activeBucketId,
                status: Value(FileSyncStatus.pending.dbValue),
                labelId: Value(labelId),
                dateAdded: Value(asset.createDateTime),
              ),
            );
        inserted++;
      }
    }

    await _refreshVisibleStatuses();
    return updated + inserted;
  }

  Future<int?> _getActiveBucketId() async {
    final bucket =
        await (_db.select(_db.buckets)
              ..where((t) => t.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();
    return bucket?.id;
  }
}
