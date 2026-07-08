import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final galleryServiceProvider = Provider<GalleryService>((ref) {
  return GalleryService();
});

class GalleryService {
  /// Request permission to access the gallery.
  Future<PermissionState> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      // Open settings if permanently denied? For now just return state.
      return ps;
    }
    return ps;
  }

  /// Get list of albums (AssetPathEntity).
  Future<List<AssetPathEntity>> getAlbums() async {
    // Only fetch albums that contain images or video
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Image + Video
      hasAll: true, // "Recent" album
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    return paths;
  }

  /// Get assets from a specific album with pagination.
  Future<List<AssetEntity>> getAssets(
    AssetPathEntity album, {
    int page = 0,
    int size = 80,
  }) async {
    final List<AssetEntity> assets = await album.getAssetListPaged(
      page: page,
      size: size,
    );
    return assets;
  }

  /// Get "Recent" album directly (convenience method)
  Future<AssetPathEntity?> getRecentAlbum() async {
    final albums = await getAlbums();
    if (albums.isNotEmpty) {
      return albums.first; // Usually "Recent" or "Recents" is first
    }
    return null;
  }
}
