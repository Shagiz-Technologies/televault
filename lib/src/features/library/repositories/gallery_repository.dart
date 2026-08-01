import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gallery_service.dart';
import '../services/media_permission_service.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(
    ref.watch(galleryServiceProvider),
    ref.watch(mediaPermissionServiceProvider),
  );
});

class GalleryRepository {
  final GalleryService _service;
  final MediaPermissionService _permissionService;

  GalleryRepository(this._service, this._permissionService);

  Future<MediaPermissionStatus> getPermissionStatus(
    MediaPermissionRequest request,
  ) => _permissionService.getStatus(request);

  Future<MediaPermissionStatus> requestPermission(
    MediaPermissionRequest request,
  ) => _permissionService.requestAccess(request);

  Future<MediaPermissionStatus> updateSelectedAccess(
    MediaPermissionRequest request,
  ) => _permissionService.updateSelectedAccess(request);

  Future<void> openSettings() => _permissionService.openSettings();

  Future<List<AssetPathEntity>> getAlbums({
    MediaPermissionRequest request =
        const MediaPermissionRequest.photosAndVideos(),
  }) => _service.getAlbums(request: request);

  Future<List<AssetEntity>> getAssets(
    AssetPathEntity album, {
    int page = 0,
    int size = 80,
  }) {
    return _service.getAssets(album, page: page, size: size);
  }

  Future<AssetPathEntity?> getRecentAlbum({
    MediaPermissionRequest request =
        const MediaPermissionRequest.photosAndVideos(),
  }) => _service.getRecentAlbum(request: request);

  Future<AssetEntity?> getAssetById(String assetId) {
    return _service.getAssetById(assetId);
  }
}
