import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../core/database/file_sync_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/presentation/bucket_selector_sheet.dart';
import '../../settings/services/app_lock_controller.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import 'image_viewer_screen.dart';
import 'library_controller.dart';
import 'widgets/media_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final String? albumId;

  const LibraryScreen({super.key, this.albumId});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  String _searchQuery = '';
  _LibraryStatusFilter _statusFilter = _LibraryStatusFilter.all;
  _LibraryMediaFilter _mediaFilter = _LibraryMediaFilter.all;
  int? _labelFilterId;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
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

    if (!state.hasPermission) {
      return const Scaffold(body: Center(child: Text('Permission denied')));
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
        leading: state.isSelecting
            ? IconButton(
                onPressed: () => ref
                    .read(libraryControllerProvider.notifier)
                    .toggleSelectionMode(),
                icon: const Icon(Icons.close),
              )
            : null,
        title: Text(
          state.isAllPhotos ? 'Library' : state.currentAlbum?.name ?? 'Library',
        ),
        actions: [
          if (state.isSelecting)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${state.selectedIds.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _openFiltersSheet(),
              icon: Icon(
                _hasActiveFilters
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: _hasActiveFilters ? AppTheme.primary : Colors.white,
              ),
            ),
            IconButton(
              tooltip: 'Bucket',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const BucketSelectorSheet(),
                );
              },
              icon: const Icon(Icons.cloud_outlined),
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
      body: Scrollbar(
        controller: _scrollCtrl,
        interactive: true,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            if (_hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
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
              ),
            for (final month in groupedAssets.keys) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                  child: _monthHeader(month, groupedAssets[month]!, state),
                ),
              ),
              SliverGrid(
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
              ),
            ],
            if (filteredAssets.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 52,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No media found',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
      floatingActionButton: state.isSelecting && state.selectedIds.isNotEmpty
          ? _buildSelectionBar(ref, state)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
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
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _clearFiltersPill() {
    return ActionChip(
      avatar: const Icon(Icons.filter_alt_off_rounded, size: 15),
      label: const Text('Clear filters'),
      onPressed: _clearFilters,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: const TextStyle(
        color: Colors.white,
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
          TextButton(
            onPressed: () {
              ref
                  .read(libraryControllerProvider.notifier)
                  .setItemsSelection(monthAssets, selected: !allSelected);
            },
            child: Text(allSelected ? 'Clear Month' : 'Select Month'),
          ),
      ],
    );
  }

  List<AssetEntity> _applyFilters(LibraryState state) {
    final query = _searchQuery.trim().toLowerCase();

    return state.assets
        .where((asset) {
          final syncStatus = state.assetStatus[asset.id];
          final label = state.assetLabels[asset.id];

          final statusMatch = switch (_statusFilter) {
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

          final mediaMatch = switch (_mediaFilter) {
            _LibraryMediaFilter.all => true,
            _LibraryMediaFilter.photos => asset.type == AssetType.image,
            _LibraryMediaFilter.videos => asset.type == AssetType.video,
          };
          if (!mediaMatch) return false;

          if (_labelFilterId != null) {
            if (label == null || label.id != _labelFilterId) {
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
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchCtrl,
                        onChanged: (v) => localSearch = v,
                        decoration: const InputDecoration(
                          hintText: 'Search by filename',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sync Status',
                        style: TextStyle(color: Colors.grey),
                      ),
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
                      const Text('Type', style: TextStyle(color: Colors.grey)),
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
                      const Text('Label', style: TextStyle(color: Colors.grey)),
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
                              child: const Text('Reset'),
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
                              child: const Text('Apply'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(Icons.label_outline, 'Label', _handleLabel),
          const SizedBox(width: 16),
          _buildActionButton(
            Icons.share,
            'Share',
            () => _handleShare(ref, state),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            Icons.lock_outline,
            'Vault',
            () => _handleVault(context),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            Icons.delete_outline,
            'Delete',
            () => _handleDelete(ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
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
    final result = await showDialog<_CreateLabelResult>(
      context: context,
      builder: (_) => const _CreateLabelDialog(),
    );

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

class _CreateLabelResult {
  final String name;
  final String colorHex;

  const _CreateLabelResult({required this.name, required this.colorHex});
}

class _CreateLabelDialog extends StatefulWidget {
  const _CreateLabelDialog();

  @override
  State<_CreateLabelDialog> createState() => _CreateLabelDialogState();
}

class _CreateLabelDialogState extends State<_CreateLabelDialog> {
  static const _colors = [
    '#0A84FF',
    '#22C55E',
    '#EF4444',
    '#F59E0B',
    '#A855F7',
    '#14B8A6',
  ];

  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedColor = _colors.first;
  String _validation = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Create Label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            maxLength: 11,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Trip, Mom, Work',
              helperText: 'Letters, numbers, symbols, and emojis are allowed.',
            ),
            onChanged: (_) {
              if (_validation.isNotEmpty) {
                setState(() => _validation = '');
              }
            },
          ),
          if (_validation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _validation,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map((color) {
              final picked = _selectedColor == color;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _parseLabelColor(color),
                    shape: BoxShape.circle,
                    border: picked
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              setState(() => _validation = 'Enter a label name');
              return;
            }
            Navigator.pop(
              context,
              _CreateLabelResult(name: name, colorHex: _selectedColor),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

Color _parseLabelColor(String value) {
  final normalized = value.replaceAll('#', '');
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  if (normalized.length == 8) {
    return Color(int.parse(normalized, radix: 16));
  }
  return AppTheme.primary;
}
