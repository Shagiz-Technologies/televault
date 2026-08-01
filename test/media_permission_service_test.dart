import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/library/services/media_permission_service.dart';

void main() {
  const request = MediaPermissionRequest.photosAndVideos();

  test('Android 13 full access is represented explicitly', () async {
    final service = MediaPermissionService(
      platform: _FakeMediaPermissionPlatform([
        _status(MediaAccessScope.fullAccess, sdk: 33),
      ]),
      isAndroid: true,
    );

    final status = await service.getStatus(request);

    expect(status.scope, MediaAccessScope.fullAccess);
    expect(status.discoveryIsComplete, isTrue);
  });

  test('Android 14 selected access is limited', () async {
    final status = MediaPermissionStatus.fromPlatformMap(const {
      'scope': 'limitedAccess',
      'imageAccess': 'selected',
      'videoAccess': 'selected',
      'androidSdkInt': 34,
      'supportsSelectedAccess': true,
      'canRequestAgain': true,
    });

    expect(status.scope, MediaAccessScope.limitedAccess);
    expect(status.discoveryIsComplete, isFalse);
    expect(status.imageAccess, MediaTypeAccess.selected);
  });

  test(
    'limited-to-full and full-to-limited transitions remain typed',
    () async {
      final platform = _FakeMediaPermissionPlatform([
        _status(MediaAccessScope.limitedAccess, sdk: 34),
        _status(MediaAccessScope.fullAccess, sdk: 34),
        _status(MediaAccessScope.limitedAccess, sdk: 34),
      ]);
      final service = MediaPermissionService(
        platform: platform,
        isAndroid: true,
      );

      expect(
        (await service.getStatus(request)).scope,
        MediaAccessScope.limitedAccess,
      );
      expect(
        (await service.requestAccess(request)).scope,
        MediaAccessScope.fullAccess,
      );
      expect(
        (await service.getStatus(request)).scope,
        MediaAccessScope.limitedAccess,
      );
    },
  );

  test('denied and permanently denied remain distinct', () {
    expect(_status(MediaAccessScope.denied).requiresSettings, isFalse);
    expect(
      _status(
        MediaAccessScope.permanentlyDenied,
        canRequestAgain: false,
      ).requiresSettings,
      isTrue,
    );
  });

  test('image access can be full while video access is denied', () {
    const status = MediaPermissionStatus(
      scope: MediaAccessScope.limitedAccess,
      imageAccess: MediaTypeAccess.full,
      videoAccess: MediaTypeAccess.denied,
      androidSdkInt: 34,
    );

    expect(status.imageAccess, MediaTypeAccess.full);
    expect(status.videoAccess, MediaTypeAccess.denied);
    expect(status.discoveryIsComplete, isFalse);
  });
}

MediaPermissionStatus _status(
  MediaAccessScope scope, {
  int sdk = 34,
  bool canRequestAgain = true,
}) {
  return MediaPermissionStatus(
    scope: scope,
    imageAccess: scope == MediaAccessScope.fullAccess
        ? MediaTypeAccess.full
        : MediaTypeAccess.selected,
    videoAccess: scope == MediaAccessScope.fullAccess
        ? MediaTypeAccess.full
        : MediaTypeAccess.selected,
    androidSdkInt: sdk,
    supportsSelectedAccess: sdk >= 34,
    canRequestAgain: canRequestAgain,
  );
}

class _FakeMediaPermissionPlatform implements MediaPermissionPlatform {
  final List<MediaPermissionStatus> responses;
  var _index = 0;

  _FakeMediaPermissionPlatform(this.responses);

  @override
  Future<MediaPermissionStatus> getStatus(MediaPermissionRequest request) {
    return Future.value(responses[_index++]);
  }

  @override
  Future<MediaPermissionStatus> requestAccess(MediaPermissionRequest request) {
    return Future.value(responses[_index++]);
  }
}
