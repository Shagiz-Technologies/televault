import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../repositories/gallery_repository.dart';
import 'library_controller.dart';
import 'library_screen.dart';
import 'package:gap/gap.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  late Future<List<AssetPathEntity>> _albumsFuture;

  @override
  void initState() {
    super.initState();
    _albumsFuture = ref.read(galleryRepositoryProvider).getAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Albums")),
      body: FutureBuilder<List<AssetPathEntity>>(
        future: _albumsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No albums found"));
          }

          final albums = snapshot.data!;

          return GridView.builder(
            padding: AppResponsive.pagePaddingWithBottomSafe(
              context,
              horizontal: 16,
              top: 16,
              bottomExtra: 18,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _AlbumCard(album: album);
            },
          );
        },
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final AssetPathEntity album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        // Select album
        await ref.read(libraryControllerProvider.notifier).selectAlbum(album);

        // Push Library Screen view for this album
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LibraryScreen()),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<AssetEntity>>(
                future: album.getAssetListRange(start: 0, end: 1),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return AssetEntityImage(
                      snapshot.data!.first,
                      isOriginal: false,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      thumbnailSize: const ThumbnailSize.square(400),
                    );
                  }
                  return const Center(
                    child: Icon(
                      Icons.folder_open_outlined,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Flexible(
                child: Text(
                  album.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Mock "Orange Dot" for Camera or specific albums if needed
              if (album.name == "Camera" || album.name == "WhatsApp") ...[
                const Gap(6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, snapshot) => Text(
              "(${snapshot.data ?? 0})",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
