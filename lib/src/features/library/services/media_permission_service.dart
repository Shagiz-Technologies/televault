import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

enum MediaAccessScope {
  fullAccess,
  limitedAccess,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
  notDetermined,
}

enum MediaTypeAccess { full, selected, denied, notRequested }

class MediaPermissionRequest {
  final bool includeImages;
  final bool includeVideos;

  const MediaPermissionRequest({
    required this.includeImages,
    required this.includeVideos,
  });

  const MediaPermissionRequest.photosAndVideos()
    : includeImages = true,
      includeVideos = true;

  RequestType get requestType {
    if (includeImages && includeVideos) return RequestType.common;
    if (includeVideos) return RequestType.video;
    return RequestType.image;
  }
}

class MediaPermissionStatus {
  final MediaAccessScope scope;
  final MediaTypeAccess imageAccess;
  final MediaTypeAccess videoAccess;
  final int? androidSdkInt;
  final bool supportsSelectedAccess;
  final bool canRequestAgain;

  const MediaPermissionStatus({
    required this.scope,
    required this.imageAccess,
    required this.videoAccess,
    this.androidSdkInt,
    this.supportsSelectedAccess = false,
    this.canRequestAgain = true,
  });

  const MediaPermissionStatus.notDetermined()
    : scope = MediaAccessScope.notDetermined,
      imageAccess = MediaTypeAccess.notRequested,
      videoAccess = MediaTypeAccess.notRequested,
      androidSdkInt = null,
      supportsSelectedAccess = false,
      canRequestAgain = true;

  bool get canReadMedia =>
      scope == MediaAccessScope.fullAccess ||
      scope == MediaAccessScope.limitedAccess;

  bool get discoveryIsComplete => scope == MediaAccessScope.fullAccess;

  bool get requiresSettings =>
      scope == MediaAccessScope.permanentlyDenied ||
      scope == MediaAccessScope.restricted;

  factory MediaPermissionStatus.fromPlatformMap(Map<Object?, Object?> map) {
    return MediaPermissionStatus(
      scope: _scopeFromWire(map['scope']),
      imageAccess: _typeAccessFromWire(map['imageAccess']),
      videoAccess: _typeAccessFromWire(map['videoAccess']),
      androidSdkInt: map['androidSdkInt'] as int?,
      supportsSelectedAccess: map['supportsSelectedAccess'] == true,
      canRequestAgain: map['canRequestAgain'] != false,
    );
  }

  static MediaAccessScope _scopeFromWire(Object? value) {
    return MediaAccessScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => MediaAccessScope.unsupported,
    );
  }

  static MediaTypeAccess _typeAccessFromWire(Object? value) {
    return MediaTypeAccess.values.firstWhere(
      (access) => access.name == value,
      orElse: () => MediaTypeAccess.denied,
    );
  }
}

enum MediaPermissionErrorCode { platformFailure, requestInProgress }

class MediaPermissionException implements Exception {
  final MediaPermissionErrorCode code;
  final String message;
  final Object? cause;

  const MediaPermissionException(this.code, this.message, {this.cause});

  @override
  String toString() => message;
}

abstract interface class MediaPermissionPlatform {
  Future<MediaPermissionStatus> getStatus(MediaPermissionRequest request);

  Future<MediaPermissionStatus> requestAccess(MediaPermissionRequest request);
}

class AndroidMediaPermissionPlatform implements MediaPermissionPlatform {
  static const _channel = MethodChannel(
    'et.shagiz.tele_vault/media_permissions',
  );

  const AndroidMediaPermissionPlatform();

  @override
  Future<MediaPermissionStatus> getStatus(MediaPermissionRequest request) =>
      _invoke('getStatus', request);

  @override
  Future<MediaPermissionStatus> requestAccess(MediaPermissionRequest request) =>
      _invoke('requestAccess', request);

  Future<MediaPermissionStatus> _invoke(
    String method,
    MediaPermissionRequest request,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(method, {
        'includeImages': request.includeImages,
        'includeVideos': request.includeVideos,
      });
      if (result == null) {
        throw const MediaPermissionException(
          MediaPermissionErrorCode.platformFailure,
          'Android did not return a media permission state.',
        );
      }
      return MediaPermissionStatus.fromPlatformMap(result);
    } on PlatformException catch (error) {
      throw MediaPermissionException(
        error.code == 'request_in_progress'
            ? MediaPermissionErrorCode.requestInProgress
            : MediaPermissionErrorCode.platformFailure,
        'Android could not complete the media permission request.',
        cause: error,
      );
    }
  }
}

final mediaPermissionServiceProvider = Provider<MediaPermissionService>((ref) {
  return MediaPermissionService();
});

class MediaPermissionService {
  final MediaPermissionPlatform? _platform;
  final bool _isAndroid;

  MediaPermissionService({MediaPermissionPlatform? platform, bool? isAndroid})
    : _platform = platform,
      _isAndroid = isAndroid ?? io.Platform.isAndroid;

  MediaPermissionPlatform get _androidPlatform =>
      _platform ?? const AndroidMediaPermissionPlatform();

  Future<MediaPermissionStatus> getStatus(
    MediaPermissionRequest request,
  ) async {
    if (_isAndroid) return _androidPlatform.getStatus(request);
    final state = await PhotoManager.getPermissionState(
      requestOption: _requestOption(request),
    );
    return _fromPhotoManagerState(state, request);
  }

  Future<MediaPermissionStatus> requestAccess(
    MediaPermissionRequest request,
  ) async {
    if (_isAndroid) return _androidPlatform.requestAccess(request);
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _requestOption(request),
    );
    return _fromPhotoManagerState(state, request);
  }

  Future<MediaPermissionStatus> updateSelectedAccess(
    MediaPermissionRequest request,
  ) async {
    if (_isAndroid) return _androidPlatform.requestAccess(request);
    await PhotoManager.presentLimited(type: request.requestType);
    return getStatus(request);
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  Future<int> countAccessibleMedia(MediaPermissionRequest request) async {
    final paths = await PhotoManager.getAssetPathList(
      type: request.requestType,
      hasAll: true,
      onlyAll: true,
    );
    if (paths.isEmpty) return 0;
    return paths.first.assetCountAsync;
  }

  PermissionRequestOption _requestOption(MediaPermissionRequest request) {
    return PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: request.requestType,
        mediaLocation: false,
      ),
    );
  }

  MediaPermissionStatus _fromPhotoManagerState(
    PermissionState state,
    MediaPermissionRequest request,
  ) {
    final scope = switch (state) {
      PermissionState.authorized => MediaAccessScope.fullAccess,
      PermissionState.limited => MediaAccessScope.limitedAccess,
      PermissionState.denied => MediaAccessScope.denied,
      PermissionState.restricted => MediaAccessScope.restricted,
      PermissionState.notDetermined => MediaAccessScope.notDetermined,
    };
    final access = switch (state) {
      PermissionState.authorized => MediaTypeAccess.full,
      PermissionState.limited => MediaTypeAccess.selected,
      _ => MediaTypeAccess.denied,
    };
    return MediaPermissionStatus(
      scope: scope,
      imageAccess: request.includeImages
          ? access
          : MediaTypeAccess.notRequested,
      videoAccess: request.includeVideos
          ? access
          : MediaTypeAccess.notRequested,
      canRequestAgain: state != PermissionState.restricted,
    );
  }
}
