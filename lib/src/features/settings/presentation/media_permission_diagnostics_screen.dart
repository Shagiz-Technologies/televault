import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/services/media_permission_policy.dart';
import '../../library/services/media_permission_service.dart';

class MediaPermissionDiagnosticsScreen extends ConsumerStatefulWidget {
  const MediaPermissionDiagnosticsScreen({super.key});

  @override
  ConsumerState<MediaPermissionDiagnosticsScreen> createState() =>
      _MediaPermissionDiagnosticsScreenState();
}

class _MediaPermissionDiagnosticsScreenState
    extends ConsumerState<MediaPermissionDiagnosticsScreen>
    with WidgetsBindingObserver {
  late Future<_MediaDiagnostics> _diagnostics;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _diagnostics = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      setState(() => _diagnostics = _load());
    }
  }

  Future<_MediaDiagnostics> _load() async {
    final policy = ref.read(mediaPermissionPolicyProvider);
    final request = await policy.activeRequest();
    final service = ref.read(mediaPermissionServiceProvider);
    final status = await service.getStatus(request);
    final count = status.canReadMedia
        ? await service.countAccessibleMedia(request)
        : 0;
    return _MediaDiagnostics(request: request, status: status, count: count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Access')),
      body: FutureBuilder<_MediaDiagnostics>(
        future: _diagnostics,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _summary(data),
              const SizedBox(height: 16),
              _row('Android version', _androidVersion(data.status)),
              _row('Granted scope', _scopeLabel(data.status.scope)),
              _row('Photos', _typeLabel(data.status.imageAccess)),
              _row('Videos', _typeLabel(data.status.videoAccess)),
              _row('Accessible items', '${data.count}'),
              _row(
                'Automatic discovery',
                data.status.discoveryIsComplete ? 'Complete' : 'Partial',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : () => _manage(data),
                icon: const Icon(Icons.tune_rounded),
                label: Text(_actionLabel(data.status)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(_MediaDiagnostics data) {
    final partial = !data.status.discoveryIsComplete;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: partial
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: partial
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partial ? 'Gallery coverage is partial' : 'Full gallery access',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            partial
                ? 'TeleVault counts and scans only media currently available to the app. Remote Telegram backups are not removed when access changes.'
                : 'TeleVault can discover new requested media for continuous backup.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _manage(_MediaDiagnostics data) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(mediaPermissionServiceProvider);
      if (data.status.requiresSettings || !data.status.canRequestAgain) {
        final confirmed = await _confirmSettings();
        if (confirmed) await service.openSettings();
      } else if (data.status.scope == MediaAccessScope.limitedAccess) {
        await service.updateSelectedAccess(data.request);
      } else {
        final confirmed = await _confirmRequest();
        if (confirmed) await service.requestAccess(data.request);
      }
      if (mounted) setState(() => _diagnostics = _load());
    } on MediaPermissionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRequest() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Allow continuous gallery backup?'),
            content: const Text(
              'TeleVault uses media access to discover new photos and videos for automatic backup. Android will let you choose full or selected access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmSettings() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open Android settings?'),
            content: const Text(
              'Media access is disabled. Enable it only if you want TeleVault to scan and automatically back up your gallery.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _androidVersion(MediaPermissionStatus status) {
    final sdk = status.androidSdkInt;
    return sdk == null ? 'Not Android' : 'API $sdk';
  }

  String _scopeLabel(MediaAccessScope scope) => switch (scope) {
    MediaAccessScope.fullAccess => 'Full access',
    MediaAccessScope.limitedAccess => 'Limited access',
    MediaAccessScope.denied => 'Denied',
    MediaAccessScope.permanentlyDenied => 'Denied in settings',
    MediaAccessScope.restricted => 'Restricted',
    MediaAccessScope.unsupported => 'Unsupported',
    MediaAccessScope.notDetermined => 'Not requested',
  };

  String _typeLabel(MediaTypeAccess access) => switch (access) {
    MediaTypeAccess.full => 'Full',
    MediaTypeAccess.selected => 'Selected only',
    MediaTypeAccess.denied => 'Not granted',
    MediaTypeAccess.notRequested => 'Not requested',
  };

  String _actionLabel(MediaPermissionStatus status) {
    if (status.requiresSettings || !status.canRequestAgain) {
      return 'Open Android settings';
    }
    if (status.scope == MediaAccessScope.limitedAccess) {
      return 'Update selected media';
    }
    return 'Request media access';
  }
}

class _MediaDiagnostics {
  final MediaPermissionRequest request;
  final MediaPermissionStatus status;
  final int count;

  const _MediaDiagnostics({
    required this.request,
    required this.status,
    required this.count,
  });
}
