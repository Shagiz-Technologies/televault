import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'media_permission_service.dart';

final galleryServiceProvider = Provider<GalleryService>((ref) {
  return GalleryService();
});

class GalleryService {
  /// Get list of albums (AssetPathEntity).
  Future<List<AssetPathEntity>> getAlbums({
    MediaPermissionRequest request =
        const MediaPermissionRequest.photosAndVideos(),
  }) async {
    // Only fetch albums that contain images or video
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: request.requestType,
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
  Future<AssetPathEntity?> getRecentAlbum({
    MediaPermissionRequest request =
        const MediaPermissionRequest.photosAndVideos(),
  }) async {
    final albums = await getAlbums(request: request);
    if (albums.isNotEmpty) {
      return albums.first; // Usually "Recent" or "Recents" is first
    }
    return null;
  }

  Future<AssetEntity?> getAssetById(String assetId) {
    return AssetEntity.fromId(assetId);
  }
}
