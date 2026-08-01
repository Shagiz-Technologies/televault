import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../repositories/gallery_repository.dart';
import 'library_controller.dart';
import 'library_screen.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  late Future<List<AssetPathEntity>> _albumsFuture;
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _albumsFuture = ref.read(galleryRepositoryProvider).getAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Find an album',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Albums'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search albums',
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) _searchController.clear();
              });
            },
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Refresh albums',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: FutureBuilder<List<AssetPathEntity>>(
          future: _albumsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return TeleVaultEmptyState(
                icon: Icons.photo_album_outlined,
                title: 'Albums could not load',
                message: 'Check photo access and try again.',
                actionLabel: 'Try again',
                onAction: () => setState(_reload),
              );
            }

            final query = _searchController.text.trim().toLowerCase();
            final albums = (snapshot.data ?? const <AssetPathEntity>[])
                .where(
                  (album) =>
                      query.isEmpty || album.name.toLowerCase().contains(query),
                )
                .toList(growable: false);

            if (albums.isEmpty) {
              return TeleVaultEmptyState(
                icon: Icons.photo_album_outlined,
                title: query.isEmpty ? 'No albums found' : 'No matching albums',
                message: query.isEmpty
                    ? 'Albums from your device will appear here.'
                    : 'Try a different album name.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await _albumsFuture;
              },
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Text(
                        'Collections',
                        style: TextStyle(
                          color: AppTheme.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: AppResponsive.pagePaddingWithBottomSafe(
                      context,
                      horizontal: 16,
                      top: 0,
                      bottomExtra: 18,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        return _AlbumCard(album: albums[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final AssetPathEntity album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Open ${album.name} album',
      child: TeleVaultCard(
        padding: EdgeInsets.zero,
        onTap: () async {
          await ref.read(libraryControllerProvider.notifier).selectAlbum(album);
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LibraryScreen()),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<List<AssetEntity>>(
                    future: album.getAssetListRange(start: 0, end: 1),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return AssetEntityImage(
                          snapshot.data!.first,
                          isOriginal: false,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          thumbnailSize: const ThumbnailSize.square(500),
                        );
                      }
                      return const ColoredBox(
                        color: AppTheme.paperMuted,
                        child: Center(
                          child: Icon(
                            Icons.folder_open_outlined,
                            color: AppTheme.inkMuted,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        color: AppTheme.success,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<int>(
                          future: album.assetCountAsync,
                          builder: (context, snapshot) => Text(
                            '${snapshot.data ?? 0} items',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.inkMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
