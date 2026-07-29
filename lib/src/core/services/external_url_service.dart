import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

enum ExternalUrlOpenResult { opened, invalidUrl, unavailable }

class ExternalUrlService {
  ExternalUrlService({ExternalUriLauncher? launcher})
    : _launcher = launcher ?? _launchExternal;

  final ExternalUriLauncher _launcher;

  Future<ExternalUrlOpenResult> openHttps(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return ExternalUrlOpenResult.invalidUrl;
    }

    try {
      final opened = await _launcher(uri);
      return opened
          ? ExternalUrlOpenResult.opened
          : ExternalUrlOpenResult.unavailable;
    } catch (_) {
      return ExternalUrlOpenResult.unavailable;
    }
  }

  static Future<bool> _launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final externalUrlServiceProvider = Provider<ExternalUrlService>(
  (_) => ExternalUrlService(),
);

Future<bool> openExternalUrl(
  BuildContext context,
  ExternalUrlService service,
  String url,
) async {
  final result = await service.openHttps(url);
  if (result == ExternalUrlOpenResult.opened) return true;
  if (!context.mounted) return false;

  final message = switch (result) {
    ExternalUrlOpenResult.invalidUrl =>
      'This link is not a valid secure web address.',
    ExternalUrlOpenResult.unavailable =>
      'No browser is available to open this link.',
    ExternalUrlOpenResult.opened => '',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return false;
}
