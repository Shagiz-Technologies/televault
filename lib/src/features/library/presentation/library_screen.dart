import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../core/database/file_sync_status.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/presentation/bucket_selector_sheet.dart';
import '../../buckets/services/bucket_service.dart';
import '../../settings/services/app_lock_controller.dart';
import '../../sync/services/sync_status_service.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import '../../vault/presentation/vault_recovery_key_screen.dart';
import '../../vault/services/vault_recovery_service.dart';
import 'image_viewer_screen.dart';
import 'library_controller.dart';
import '../services/media_permission_service.dart';
import 'widgets/media_access_notice.dart';
import 'widgets/label_editor_dialog.dart';
import 'widgets/media_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final String? albumId;

  const LibraryScreen({super.key, this.albumId});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _MediaPermissionGate extends StatelessWidget {
  final MediaPermissionStatus status;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  const _MediaPermissionGate({
    required this.status,
    required this.busy,
    required this.onRequest,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final permanent = status.requiresSettings;
    final unsupported = status.scope == MediaAccessScope.unsupported;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    size: 34,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  permanent ? 'Media access is off' : 'Back up your gallery',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _message(permanent, unsupported),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (!unsupported)
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : permanent
                        ? onOpenSettings
                        : onRequest,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            permanent
                                ? Icons.settings_outlined
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(permanent ? 'Open settings' : 'Continue'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'You can still use Settings and recovery tools without gallery access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _message(bool permanent, bool unsupported) {
    if (unsupported) {
      return 'Media access is not supported on this platform.';
    }
    if (permanent) {
      return 'TeleVault cannot scan new photos or videos. Open Android settings only if you want to enable continuous gallery backup.';
    }
    if (status.scope == MediaAccessScope.denied) {
      return 'Access was not granted. You can try again when you are ready; TeleVault will not open Android settings automatically.';
    }
    return 'TeleVault needs ongoing photo and video access to discover new gallery items and back them up automatically. You can choose full or selected access in Android.';
  }
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();
  bool _permissionActionInProgress = false;

  String _searchQuery = '';
  _LibraryStatusFilter _statusFilter = _LibraryStatusFilter.all;
  _LibraryMediaFilter _mediaFilter = _LibraryMediaFilter.all;
  int? _labelFilterId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _permissionActionInProgress) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      if (!mounted || _permissionActionInProgress) return;
      await ref.read(libraryControllerProvider.notifier).refreshPermission();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent * 0.8) {
      ref.read(libraryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final activeBucket = ref.watch(activeBucketProvider).asData?.value;
    final bucketStatus = ref.watch(bucketSyncStatusProvider(activeBucket?.id));

    if (!state.hasPermission) {
      if (state.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Library')),
        body: _MediaPermissionGate(
          status: state.permissionStatus,
          busy: _permissionActionInProgress,
          onRequest: _requestMediaAccess,
          onOpenSettings: _openMediaSettings,
        ),
      );
    }

    if (state.isLoading && state.assets.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredAssets = _applyFilters(state);
    final groupedAssets = <String, List<AssetEntity>>{};
    for (final asset in filteredAssets) {
      final key = DateFormat.yMMMM().format(asset.createDateTime);
      groupedAssets.putIfAbsent(key, () => []);
      groupedAssets[key]!.add(asset);
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: state.isSelecting ? 64 : 78,
        leading: state.isSelecting
            ? IconButton(
                onPressed: () => ref
                    .read(libraryControllerProvider.notifier)
                    .toggleSelectionMode(),
                icon: const Icon(Icons.close),
              )
            : null,
        titleSpacing: state.isSelecting ? 8 : 16,
        title: state.isSelecting
            ? Text('${state.selectedIds.length} selected')
            : Row(
                children: [
                  if (state.isAllPhotos) ...[
                    const TeleVaultLogoMark(size: 32, shadow: false),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.isAllPhotos
                              ? 'TeleVault'
                              : state.currentAlbum?.name ?? 'Library',
                        ),
                        if (activeBucket != null)
                          Text(
                            '${activeBucket.name} - ${_bucketStatusText(bucketStatus.asData?.value)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _bucketStatusColor(
                                    bucketStatus.asData?.value,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (!state.isSelecting) ...[
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _openFiltersSheet(),
              icon: Icon(
                _hasActiveFilters
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: _hasActiveFilters ? AppTheme.primary : AppTheme.ink,
              ),
            ),
            LibraryBucketStatusAction(
              bucketName: activeBucket?.name,
              status: bucketStatus,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const BucketSelectorSheet(),
                );
              },
            ),
            IconButton(
              tooltip: 'Select',
              onPressed: () => ref
                  .read(libraryControllerProvider.notifier)
                  .toggleSelectionMode(),
              icon: const Icon(Icons.checklist_rtl_outlined),
            ),
          ],
        ],
      ),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: Scrollbar(
          controller: _scrollCtrl,
          interactive: true,
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              if (state.permissionStatus.scope ==
                  MediaAccessScope.limitedAccess)
                SliverToBoxAdapter(
                  child: MediaAccessNotice(
                    status: state.permissionStatus,
                    onManageAccess: _manageMediaAccess,
                  ),
                ),
              if (_hasActiveFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          _activeFilterPill(
                            label: 'Search: "$_searchQuery"',
                            icon: Icons.search,
                            onDeleted: () => setState(() => _searchQuery = ''),
                          ),
                        if (_statusFilter != _LibraryStatusFilter.all)
                          _activeFilterPill(
                            label: _statusFilter.label,
                            icon: Icons.cloud_done_outlined,
                            onDeleted: () => setState(
                              () => _statusFilter = _LibraryStatusFilter.all,
                            ),
                          ),
                        if (_mediaFilter != _LibraryMediaFilter.all)
                          _activeFilterPill(
                            label: _mediaFilter.label,
                            icon: Icons.photo_library_outlined,
                            onDeleted: () => setState(
                              () => _mediaFilter = _LibraryMediaFilter.all,
                            ),
                          ),
                        if (_labelFilterId != null)
                          _activeFilterPill(
                            label: 'Label',
                            icon: Icons.label_outline,
                            onDeleted: () =>
                                setState(() => _labelFilterId = null),
                          ),
                        _clearFiltersPill(),
                      ],
                    ),
                  ),
                ),
              for (final month in groupedAssets.keys) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                    child: _monthHeader(month, groupedAssets[month]!, state),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final asset = groupedAssets[month]![index];
                      final isSelected = state.selectedIds.contains(asset.id);
                      final syncStatus = state.assetStatus[asset.id];
                      final label = state.assetLabels[asset.id];

                      return MediaTile(
                        asset: asset,
                        selectionMode: state.isSelecting,
                        isSelected: isSelected,
                        syncStatus: syncStatus,
                        label: label,
                        onTap: () {
                          if (state.isSelecting) {
                            ref
                                .read(libraryControllerProvider.notifier)
                                .toggleItemSelection(asset);
                          } else {
                            final visibleIndex = filteredAssets.indexOf(asset);
                            if (visibleIndex != -1) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(
                                    assets: filteredAssets,
                                    initialIndex: visibleIndex,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        onLongPress: () {
                          if (!state.isSelecting) {
                            ref
                                .read(libraryControllerProvider.notifier)
                                .toggleSelectionMode();
                            ref
                                .read(libraryControllerProvider.notifier)
                                .toggleItemSelection(asset);
                          }
                        },
                      );
                    }, childCount: groupedAssets[month]!.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                  ),
                ),
              ],
              if (filteredAssets.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: TeleVaultEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'No media found',
                    message:
                        'Try changing your filters or choosing another album.',
                  ),
                ),
              if (state.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: state.isSelecting && state.selectedIds.isNotEmpty
          ? _buildSelectionBar(ref, state)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _bucketStatusText(SyncStatusSnapshot? snapshot) {
    if (snapshot == null) return 'Checking backup';
    if (snapshot.uploadingCount > 0) {
      return 'Backing up ${snapshot.uploadingCount}';
    }
    if (snapshot.failedCount > 0) return '${snapshot.failedCount} failed';
    if (snapshot.pendingCount > 0) return '${snapshot.pendingCount} waiting';
    if (snapshot.completedCount > 0) return 'Up to date';
    return 'Ready';
  }

  Color _bucketStatusColor(SyncStatusSnapshot? snapshot) {
    if (snapshot == null) return AppTheme.inkMuted;
    if (snapshot.failedCount > 0) return AppTheme.error;
    if (snapshot.uploadingCount > 0) return AppTheme.primary;
    if (snapshot.pendingCount > 0) return AppTheme.warning;
    return AppTheme.success;
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _statusFilter != _LibraryStatusFilter.all ||
        _mediaFilter != _LibraryMediaFilter.all ||
        _labelFilterId != null;
  }

  Widget _activeFilterPill({
    required String label,
    required IconData icon,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      avatar: Icon(icon, size: 15, color: AppTheme.primary),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.34)),
      backgroundColor: AppTheme.primarySoft,
      labelStyle: const TextStyle(
        color: AppTheme.primaryDeep,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _requestMediaAccess() async {
    if (_permissionActionInProgress) return;
    setState(() => _permissionActionInProgress = true);
    try {
      await ref.read(libraryControllerProvider.notifier).requestMediaAccess();
    } on MediaPermissionException catch (error) {
      _showPermissionError(error.message);
    } finally {
      if (mounted) setState(() => _permissionActionInProgress = false);
    }
  }

  Future<void> _manageMediaAccess() async {
    if (_permissionActionInProgress) return;
    final status = ref.read(libraryControllerProvider).permissionStatus;
    setState(() => _permissionActionInProgress = true);
    try {
      if (status.canRequestAgain) {
        await ref
            .read(libraryControllerProvider.notifier)
            .updateSelectedAccess();
      } else {
        await ref.read(libraryControllerProvider.notifier).openMediaSettings();
      }
    } on MediaPermissionException catch (error) {
      _showPermissionError(error.message);
    } finally {
      if (mounted) setState(() => _permissionActionInProgress = false);
    }
  }

  Future<void> _openMediaSettings() async {
    await ref.read(libraryControllerProvider.notifier).openMediaSettings();
  }

  void _showPermissionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _clearFiltersPill() {
    return ActionChip(
      avatar: const Icon(Icons.filter_alt_off_rounded, size: 15),
      label: const Text('Clear filters'),
      onPressed: _clearFilters,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppTheme.outline),
      backgroundColor: AppTheme.surface,
      labelStyle: const TextStyle(
        color: AppTheme.inkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = _LibraryStatusFilter.all;
      _mediaFilter = _LibraryMediaFilter.all;
      _labelFilterId = null;
    });
  }

  Widget _monthHeader(
    String month,
    List<AssetEntity> monthAssets,
    LibraryState state,
  ) {
    final selectedCount = monthAssets
        .where((a) => state.selectedIds.contains(a.id))
        .length;
    final allSelected =
        selectedCount == monthAssets.length && monthAssets.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            month,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (state.isSelecting)
          Semantics(
            button: true,
            label: allSelected
                ? 'Clear selection for $month'
                : 'Select all media from $month',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                ref
                    .read(libraryControllerProvider.notifier)
                    .setItemsSelection(monthAssets, selected: !allSelected);
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  allSelected
                      ? Icons.check_circle_rounded
                      : selectedCount > 0
                      ? Icons.indeterminate_check_box_rounded
                      : Icons.circle_outlined,
                  color: allSelected || selectedCount > 0
                      ? AppTheme.primary
                      : AppTheme.inkMuted,
                  size: 22,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<AssetEntity> _applyFilters(LibraryState state) {
    return _filterAssets(
      state,
      search: _searchQuery,
      status: _statusFilter,
      media: _mediaFilter,
      labelId: _labelFilterId,
    );
  }

  int _filteredCountFor({
    required LibraryState state,
    required String search,
    required _LibraryStatusFilter status,
    required _LibraryMediaFilter media,
    required int? labelId,
  }) {
    return _filterAssets(
      state,
      search: search,
      status: status,
      media: media,
      labelId: labelId,
    ).length;
  }

  List<AssetEntity> _filterAssets(
    LibraryState state, {
    required String search,
    required _LibraryStatusFilter status,
    required _LibraryMediaFilter media,
    required int? labelId,
  }) {
    final query = search.trim().toLowerCase();

    return state.assets
        .where((asset) {
          final syncStatus = state.assetStatus[asset.id];
          final label = state.assetLabels[asset.id];

          final statusMatch = switch (status) {
            _LibraryStatusFilter.all => true,
            _LibraryStatusFilter.needsBackup =>
              syncStatus == null ||
                  syncStatus == FileSyncStatus.pending.dbValue ||
                  syncStatus == FileSyncStatus.uploading.dbValue ||
                  syncStatus == FileSyncStatus.failed.dbValue,
            _LibraryStatusFilter.backedUp =>
              syncStatus == FileSyncStatus.synced.dbValue,
            _LibraryStatusFilter.failedOnly =>
              syncStatus == FileSyncStatus.failed.dbValue,
            _LibraryStatusFilter.vaulted =>
              syncStatus == FileSyncStatus.vaultedEncrypted.dbValue,
          };
          if (!statusMatch) return false;

          final mediaMatch = switch (media) {
            _LibraryMediaFilter.all => true,
            _LibraryMediaFilter.photos => asset.type == AssetType.image,
            _LibraryMediaFilter.videos => asset.type == AssetType.video,
          };
          if (!mediaMatch) return false;

          if (labelId != null) {
            if (label == null || label.id != labelId) {
              return false;
            }
          }

          if (query.isEmpty) return true;
          final title = (asset.title ?? '').toLowerCase();
          return title.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openFiltersSheet() async {
    final labels = await ref
        .read(libraryControllerProvider.notifier)
        .getLabels();

    var localSearch = _searchQuery;
    var localStatus = _statusFilter;
    var localMedia = _mediaFilter;
    int? localLabel = _labelFilterId;
    final searchCtrl = TextEditingController(text: localSearch);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Filter your library',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  localSearch = '';
                                  localStatus = _LibraryStatusFilter.all;
                                  localMedia = _LibraryMediaFilter.all;
                                  localLabel = null;
                                  searchCtrl.clear();
                                });
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: searchCtrl,
                        onChanged: (v) => localSearch = v,
                        decoration: const InputDecoration(
                          hintText: 'Search by filename',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TeleVaultSectionTitle(title: 'Backup status'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _LibraryStatusFilter.values.map((filter) {
                          return ChoiceChip(
                            label: Text(filter.label),
                            selected: localStatus == filter,
                            onSelected: (_) =>
                                setModalState(() => localStatus = filter),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const TeleVaultSectionTitle(title: 'Media type'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _LibraryMediaFilter.values.map((filter) {
                          return ChoiceChip(
                            label: Text(filter.label),
                            selected: localMedia == filter,
                            onSelected: (_) =>
                                setModalState(() => localMedia = filter),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const TeleVaultSectionTitle(title: 'Label'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('All Labels'),
                            selected: localLabel == null,
                            onSelected: (_) =>
                                setModalState(() => localLabel = null),
                          ),
                          ...labels.map(
                            (label) => ChoiceChip(
                              label: Text(label.name),
                              selected: localLabel == label.id,
                              onSelected: (_) =>
                                  setModalState(() => localLabel = label.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _statusFilter = _LibraryStatusFilter.all;
                                  _mediaFilter = _LibraryMediaFilter.all;
                                  _labelFilterId = null;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = localSearch;
                                  _statusFilter = localStatus;
                                  _mediaFilter = localMedia;
                                  _labelFilterId = localLabel;
                                });
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Show ${_filteredCountFor(state: ref.read(libraryControllerProvider), search: localSearch, status: localStatus, media: localMedia, labelId: localLabel)} items',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  Widget _buildSelectionBar(WidgetRef ref, LibraryState state) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: AppTheme.surface,
        elevation: 12,
        shadowColor: AppTheme.ink.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppTheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.label_outline, 'Label', _handleLabel),
              _buildActionButton(
                Icons.share_outlined,
                'Share',
                () => _handleShare(ref, state),
              ),
              _buildActionButton(
                Icons.lock_outline_rounded,
                'Vault',
                () => _handleVault(context),
              ),
              _buildActionButton(
                Icons.delete_outline_rounded,
                'Delete',
                () => _handleDelete(ref, state),
                color: AppTheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = AppTheme.ink,
  }) {
    return Semantics(
      button: true,
      label: '$label selected media',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 68, minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLabel() async {
    final notifier = ref.read(libraryControllerProvider.notifier);
    final labels = await notifier.getLabels();

    if (!mounted) return;
    final action = await showModalBottomSheet<_LabelSheetAction>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create Label'),
                onTap: () async {
                  Navigator.pop(context, const _LabelSheetAction.create());
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear Label'),
                onTap: () async {
                  Navigator.pop(context, const _LabelSheetAction.clear());
                },
              ),
              if (labels.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No labels yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...labels.map((label) {
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: _parseColor(label.colorHex),
                      child: label.emoji != null && label.emoji!.isNotEmpty
                          ? Text(
                              label.emoji!,
                              style: const TextStyle(fontSize: 10),
                            )
                          : null,
                    ),
                    title: Text(label.name),
                    onTap: () async {
                      Navigator.pop(context, _LabelSheetAction.apply(label.id));
                    },
                  );
                }),
            ],
          ),
        );
      },
    );

    if (action == null) return;

    final handled = switch (action.type) {
      _LabelSheetActionType.create => await _openCreateLabelDialog(),
      _LabelSheetActionType.clear => await _applyExistingLabel(null),
      _LabelSheetActionType.apply => await _applyExistingLabel(action.labelId),
    };

    if (handled) {
      notifier.exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Label updated')));
      }
    }
  }

  Future<bool> _applyExistingLabel(int? labelId) async {
    await ref
        .read(libraryControllerProvider.notifier)
        .applyLabelToSelection(labelId);
    return true;
  }

  Future<bool> _openCreateLabelDialog() async {
    if (!mounted) return false;
    final result = await showLabelEditorDialog(context);

    if (result == null) return false;

    final notifier = ref.read(libraryControllerProvider.notifier);
    final labelId = await notifier.createLabel(
      name: result.name,
      colorHex: result.colorHex,
    );
    if (labelId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use 11 characters or fewer')),
        );
      }
      return false;
    }

    await notifier.applyLabelToSelection(labelId);
    return true;
  }

  Future<void> _handleShare(WidgetRef ref, LibraryState state) async {
    final assets = state.assets
        .where((a) => state.selectedIds.contains(a.id))
        .toList();
    if (assets.isEmpty) return;

    try {
      final files = <share_plus.XFile>[];
      for (final asset in assets) {
        final file = await asset.file;
        if (file != null) files.add(share_plus.XFile(file.path));
      }

      if (files.isNotEmpty) {
        await share_plus.Share.shareXFiles(
          files,
          text: 'Shared from TeleVault',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }

    ref.read(libraryControllerProvider.notifier).toggleSelectionMode();
  }

  Future<void> _handleVault(BuildContext context) async {
    final notifier = ref.read(libraryControllerProvider.notifier);
    final count = ref.read(libraryControllerProvider).selectedIds.length;

    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Move to Vault?'),
        content: Text(
          'Move $count item(s) to your private vault? They will be hidden from the library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Vault',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      String? unlockedPin;
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (pinContext) => VaultPinScreen(
              mode: VaultPinMode.unlock,
              onUnlock: (pin) {
                unlockedPin = pin;
                Navigator.pop(pinContext);
              },
            ),
          ),
        );
      }
      if (unlockedPin == null) return;

      final recoveryService = ref.read(vaultRecoveryServiceProvider);
      if (!await recoveryService.isRecoveryKeyConfirmed()) {
        if (!context.mounted) return;
        final ready = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const VaultRecoveryKeyScreen()),
        );
        if (ready != true || !context.mounted) return;
      }

      await notifier.moveToVault(pin: unlockedPin!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved $count item(s) to encrypted Vault')),
        );
      }
    }
  }

  Future<void> _handleDelete(WidgetRef ref, LibraryState state) async {
    final count = state.selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Delete $count photo(s) from your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final assets = state.assets
          .where((a) => state.selectedIds.contains(a.id))
          .toList();
      final notifier = ref.read(libraryControllerProvider.notifier);

      try {
        final ids = assets.map((a) => a.id).toList();
        ref
            .read(appLockControllerProvider.notifier)
            .allowExternalSystemPrompt();
        final deletedIds = (await PhotoManager.editor.deleteWithIds(
          ids,
        )).toSet();

        if (!mounted) return;

        if (deletedIds.isEmpty) {
          await notifier.refreshCurrentView();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delete cancelled or nothing removed'),
            ),
          );
          return;
        }

        await notifier.markAssetsDeletedLocally(deletedIds);
        if (!mounted) return;
        final skipped = ids.length - deletedIds.length;
        final message = skipped > 0
            ? 'Deleted ${deletedIds.length}; $skipped item(s) were not removed'
            : 'Deleted ${deletedIds.length} photo(s)';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        notifier.exitSelectionMode();
      } on PlatformException catch (e) {
        await notifier.refreshCurrentView();
        notifier.exitSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ??
                    'Could not delete. The item may already be missing or not stored locally.',
              ),
            ),
          );
        }
      } catch (e) {
        await notifier.refreshCurrentView();
        notifier.exitSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  Color _parseColor(String value) {
    final normalized = value.replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return AppTheme.primary;
  }
}

class LibraryBucketStatusAction extends StatelessWidget {
  final String? bucketName;
  final AsyncValue<SyncStatusSnapshot> status;
  final VoidCallback onPressed;

  const LibraryBucketStatusAction({
    super.key,
    required this.bucketName,
    required this.status,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = status.asData?.value;
    final tooltip = _tooltip(snapshot);
    final badgeCount = snapshot == null
        ? 0
        : snapshot.failedCount > 0
        ? snapshot.failedCount
        : snapshot.pendingCount + snapshot.uploadingCount;
    final badgeColor = snapshot != null && snapshot.failedCount > 0
        ? AppTheme.error
        : AppTheme.warning;

    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _statusIcon(snapshot),
              if (badgeCount > 0 && snapshot?.uploadingCount == 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppTheme.surface, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(SyncStatusSnapshot? snapshot) {
    if (snapshot == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (snapshot.uploadingCount > 0) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              value: snapshot.activeUploadProgress > 0
                  ? snapshot.activeUploadProgress
                  : null,
              strokeWidth: 2,
              backgroundColor: AppTheme.paperMuted,
              color: AppTheme.primary,
            ),
          ),
          const Icon(
            Icons.cloud_upload_rounded,
            size: 16,
            color: AppTheme.primary,
          ),
        ],
      );
    }
    if (snapshot.failedCount > 0) {
      return const Icon(
        Icons.cloud_off_rounded,
        color: AppTheme.error,
        size: 24,
      );
    }
    if (snapshot.pendingCount > 0) {
      return const Icon(
        Icons.cloud_upload_outlined,
        color: AppTheme.warning,
        size: 24,
      );
    }
    if (snapshot.completedCount > 0) {
      return const Icon(
        Icons.cloud_done_rounded,
        color: AppTheme.success,
        size: 24,
      );
    }
    return const Icon(Icons.cloud_queue_outlined, color: AppTheme.inkMuted);
  }

  String _tooltip(SyncStatusSnapshot? snapshot) {
    final name = bucketName ?? 'Current bucket';
    if (snapshot == null) return '$name: loading backup status';
    if (snapshot.uploadingCount > 0) {
      return '$name: uploading ${snapshot.uploadingCount}';
    }
    if (snapshot.failedCount > 0) {
      return '$name: ${snapshot.failedCount} failed';
    }
    if (snapshot.pendingCount > 0) {
      return '$name: ${snapshot.pendingCount} waiting';
    }
    if (snapshot.completedCount > 0) return '$name: backup up to date';
    return '$name: no media queued';
  }
}

enum _LibraryStatusFilter {
  all('All'),
  needsBackup('Need Backup'),
  backedUp('Backed Up'),
  failedOnly('Failed'),
  vaulted('Vaulted');

  final String label;
  const _LibraryStatusFilter(this.label);
}

enum _LibraryMediaFilter {
  all('All Types'),
  photos('Photos'),
  videos('Videos');

  final String label;
  const _LibraryMediaFilter(this.label);
}

enum _LabelSheetActionType { create, clear, apply }

class _LabelSheetAction {
  final _LabelSheetActionType type;
  final int? labelId;

  const _LabelSheetAction._(this.type, [this.labelId]);
  const _LabelSheetAction.create() : this._(_LabelSheetActionType.create);
  const _LabelSheetAction.clear() : this._(_LabelSheetActionType.clear);
  const _LabelSheetAction.apply(int labelId)
    : this._(_LabelSheetActionType.apply, labelId);
}
