import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../settings/services/settings_service.dart';
import 'media_permission_service.dart';

final mediaPermissionPolicyProvider = Provider<MediaPermissionPolicy>((ref) {
  return MediaPermissionPolicy(
    ref.watch(databaseProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(mediaPermissionServiceProvider),
  );
});

class MediaPermissionPolicy {
  final AppDatabase _database;
  final SettingsService _settings;
  final MediaPermissionService _permissions;

  const MediaPermissionPolicy(
    this._database,
    this._settings,
    this._permissions,
  );

  Future<MediaPermissionRequest> activeRequest() async {
    final activeBucket = await (_database.select(
      _database.buckets,
    )..where((row) => row.isActive.equals(true))).getSingleOrNull();
    if (activeBucket == null) {
      return const MediaPermissionRequest.photosAndVideos();
    }
    final preferences = await _settings.getSyncPreferences(
      bucketId: activeBucket.id,
    );
    final allowed = activeBucket.allowedMediaTypes.split(',').toSet();
    var includeImages = preferences.includePhotos && allowed.contains('photo');
    final includeVideos =
        preferences.includeVideos && allowed.contains('video');
    if (!includeImages && !includeVideos) includeImages = true;
    return MediaPermissionRequest(
      includeImages: includeImages,
      includeVideos: includeVideos,
    );
  }

  Future<MediaPermissionStatus> activeStatus() async {
    final request = await activeRequest();
    return _permissions.getStatus(request);
  }
}
