import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gallery_service.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(ref.watch(galleryServiceProvider));
});

class GalleryRepository {
  final GalleryService _service;

  GalleryRepository(this._service);

  Future<bool> requestPermission() async {
    final state = await _service.requestPermission();
    return state.hasAccess;
  }

  Future<List<AssetPathEntity>> getAlbums() => _service.getAlbums();

  Future<List<AssetEntity>> getAssets(
    AssetPathEntity album, {
    int page = 0,
    int size = 80,
  }) {
    return _service.getAssets(album, page: page, size: size);
  }

  Future<AssetPathEntity?> getRecentAlbum() => _service.getRecentAlbum();
}
