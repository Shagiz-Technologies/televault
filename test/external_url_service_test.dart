import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/services/external_url_service.dart';

void main() {
  test('opens a valid HTTPS URL with the injected launcher', () async {
    Uri? launched;
    final service = ExternalUrlService(
      launcher: (uri) async {
        launched = uri;
        return true;
      },
    );

    final result = await service.openHttps('https://example.com/legal');

    expect(result, ExternalUrlOpenResult.opened);
    expect(launched, Uri.parse('https://example.com/legal'));
  });

  test('rejects non-HTTPS and malformed URLs without launching', () async {
    var launchCount = 0;
    final service = ExternalUrlService(
      launcher: (_) async {
        launchCount++;
        return true;
      },
    );

    expect(
      await service.openHttps('http://example.com'),
      ExternalUrlOpenResult.invalidUrl,
    );
    expect(
      await service.openHttps('not a URL'),
      ExternalUrlOpenResult.invalidUrl,
    );
    expect(launchCount, 0);
  });

  test('reports unavailable when the browser cannot launch', () async {
    final unavailable = ExternalUrlService(launcher: (_) async => false);
    final throwing = ExternalUrlService(
      launcher: (_) async => throw StateError('No browser'),
    );

    expect(
      await unavailable.openHttps('https://example.com'),
      ExternalUrlOpenResult.unavailable,
    );
    expect(
      await throwing.openHttps('https://example.com'),
      ExternalUrlOpenResult.unavailable,
    );
  });
}
