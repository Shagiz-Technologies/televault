import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/privacy_policy_screen.dart';
import '../../settings/presentation/terms_summary_screen.dart';
import '../services/reviewer_demo_controller.dart';

class ReviewerDemoApp extends StatefulWidget {
  final Future<void> Function() onExitDemo;
  final ReviewerDemoController? controller;

  const ReviewerDemoApp({super.key, required this.onExitDemo, this.controller});

  @override
  State<ReviewerDemoApp> createState() => _ReviewerDemoAppState();
}

class _ReviewerDemoAppState extends State<ReviewerDemoApp> {
  late final ReviewerDemoController _controller;
  int _tab = 0;
  String? _error;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ReviewerDemoController();
    _controller.addListener(_refresh);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } catch (_) {
      if (mounted) setState(() => _error = 'Reviewer Demo could not start.');
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleVault Reviewer Demo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      builder: (context, child) => Column(
        children: [
          Material(
            color: const Color(0xFF0C7A55),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!_controller.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      _DemoLibrary(controller: _controller),
      _DemoAlbums(controller: _controller),
      _DemoVault(controller: _controller),
      _DemoSettings(controller: _controller, exiting: _exiting, onExit: _exit),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['Library', 'Albums & buckets', 'Vault', 'Settings'][_tab]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.science_outlined, size: 16),
              label: const Text('Demo'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_controller.busy || _controller.pauseReason != null)
            _ForegroundProgress(controller: _controller),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            selectedIcon: Icon(Icons.photo_album_rounded),
            label: 'Albums',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _exit() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    try {
      await _controller.clearAndClose();
      await widget.onExitDemo();
    } catch (_) {
      if (mounted) {
        setState(() {
          _exiting = false;
          _error = 'Reviewer Demo could not be cleared safely.';
        });
      }
    }
  }
}

class _ForegroundProgress extends StatelessWidget {
  final ReviewerDemoController controller;

  const _ForegroundProgress({required this.controller});

  @override
  Widget build(BuildContext context) {
    final paused = controller.pauseReason != null;
    return Material(
      color: paused ? const Color(0xFFFFF4DE) : const Color(0xFFE9F5FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Icon(
              paused ? Icons.wifi_off_rounded : Icons.cloud_upload_outlined,
              color: paused ? AppTheme.warning : AppTheme.primary,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paused
                        ? 'Simulated backup paused'
                        : 'Simulated foreground backup',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Gap(4),
                  LinearProgressIndicator(
                    value: paused ? 0 : controller.activeUploadProgress,
                  ),
                  const Gap(3),
                  Text(
                    paused
                        ? controller.pauseReason!
                        : '${(controller.activeUploadProgress * 100).round()}% — no Telegram network call',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoLibrary extends StatelessWidget {
  final ReviewerDemoController controller;

  const _DemoLibrary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _DemoNotice(text: controller.notice),
        _BackupSummary(controller: controller),
        const Gap(16),
        Row(
          children: [
            Text(
              'Sample media',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Text('Demo data only', style: TextStyle(fontSize: 12)),
          ],
        ),
        const Gap(10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: controller.media.length,
          itemBuilder: (context, index) =>
              _DemoMediaCard(item: controller.media[index], index: index),
        ),
      ],
    );
  }
}

class _BackupSummary extends StatelessWidget {
  final ReviewerDemoController controller;

  const _BackupSummary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.primary),
                Gap(8),
                Expanded(
                  child: Text(
                    'Backup status — simulated',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  'Pending',
                  controller.pendingCount,
                  AppTheme.warning,
                ),
                _CountChip(
                  'Uploading',
                  controller.uploadingCount,
                  AppTheme.primary,
                ),
                _CountChip('Synced', controller.syncedCount, AppTheme.success),
                _CountChip('Failed', controller.failedCount, AppTheme.error),
              ],
            ),
            const Gap(12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.wifiAvailable,
              onChanged: controller.setWifiAvailable,
              title: const Text('Demo Wi-Fi available'),
              subtitle: const Text(
                'Turn off to inspect safe pause and resume.',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : controller.startSimulatedBackup,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Run simulated backup'),
                  ),
                ),
                const Gap(8),
                IconButton.filledTonal(
                  tooltip: 'Retry failed demo items',
                  onPressed: controller.busy ? null : controller.retryFailed,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.14),
      child: Text('$count', style: TextStyle(color: color, fontSize: 11)),
    ),
    label: Text(label),
  );
}

class _DemoMediaCard extends StatelessWidget {
  final ReviewerDemoMedia item;
  final int index;

  const _DemoMediaCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final palettes = [
      const [Color(0xFFBDE3F6), Color(0xFF5DA6CF)],
      const [Color(0xFFF5D8A7), Color(0xFFD58B58)],
      const [Color(0xFFD5E8C3), Color(0xFF78A96A)],
      const [Color(0xFFE5D4EC), Color(0xFF9B7CAF)],
    ];
    final colors = palettes[index % palettes.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              item.isVideo ? Icons.videocam_rounded : Icons.landscape_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Chip(
              label: const Text('SAMPLE'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(3),
                    Row(
                      children: [
                        Icon(
                          _stateIcon(item.state),
                          size: 14,
                          color: _stateColor(item.state),
                        ),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            '${_stateLabel(item.state)} • simulated',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _stateIcon(ReviewerDemoUploadState state) => switch (state) {
    ReviewerDemoUploadState.pending => Icons.hourglass_empty_rounded,
    ReviewerDemoUploadState.uploading => Icons.sync_rounded,
    ReviewerDemoUploadState.synced => Icons.check_circle_rounded,
    ReviewerDemoUploadState.failed => Icons.error_rounded,
  };

  static Color _stateColor(ReviewerDemoUploadState state) => switch (state) {
    ReviewerDemoUploadState.pending => const Color(0xFFFFC857),
    ReviewerDemoUploadState.uploading => const Color(0xFF5CC8FF),
    ReviewerDemoUploadState.synced => const Color(0xFF58D68D),
    ReviewerDemoUploadState.failed => const Color(0xFFFF746C),
  };

  static String _stateLabel(ReviewerDemoUploadState state) => switch (state) {
    ReviewerDemoUploadState.pending => 'Pending',
    ReviewerDemoUploadState.uploading => 'Uploading',
    ReviewerDemoUploadState.synced => 'Synced',
    ReviewerDemoUploadState.failed => 'Failed',
  };
}

class _DemoAlbums extends StatelessWidget {
  final ReviewerDemoController controller;

  const _DemoAlbums({required this.controller});

  @override
  Widget build(BuildContext context) {
    final albums = <String, int>{};
    for (final item in controller.media) {
      albums.update(item.album, (value) => value + 1, ifAbsent: () => 1);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Albums',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Gap(8),
        ...albums.entries.map(
          (entry) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_album)),
              title: Text(entry.key),
              subtitle: Text('${entry.value} sample item(s)'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
        const Gap(18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Backup buckets',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showCreateBucket(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
            ),
          ],
        ),
        const Gap(8),
        ...controller.buckets.map(
          (bucket) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.telegram)),
              title: Text(bucket.name),
              subtitle: Text(
                '${bucket.mediaTypes} • local demo bucket${bucket.isActive ? ' • active' : ''}',
              ),
              trailing: bucket.isActive
                  ? const Icon(Icons.check_circle, color: AppTheme.success)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateBucket(BuildContext context) async {
    final nameController = TextEditingController();
    final selected = <String>{'photo', 'video'};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create demo bucket',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(6),
                const Text('Created locally. No Telegram channel is created.'),
                const Gap(16),
                TextField(
                  controller: nameController,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Bucket name'),
                ),
                CheckboxListTile(
                  value: selected.contains('photo'),
                  onChanged: (value) => setSheetState(() {
                    value == true
                        ? selected.add('photo')
                        : selected.remove('photo');
                  }),
                  title: const Text('Photos'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: selected.contains('video'),
                  onChanged: (value) => setSheetState(() {
                    value == true
                        ? selected.add('video')
                        : selected.remove('video');
                  }),
                  title: const Text('Videos'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Gap(8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await controller.createBucket(
                        nameController.text,
                        selected,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Create demo bucket'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
  }
}

class _DemoVault extends StatelessWidget {
  final ReviewerDemoController controller;

  const _DemoVault({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _InfoCard(
          icon: Icons.lock_rounded,
          title: 'Local Vault demonstration',
          body:
              'This flow creates an isolated demo Recovery Key and encrypts generated sample bytes on this device. Nothing is sent to Telegram.',
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Recovery Key',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(8),
                SelectableText(
                  controller.recoveryKeyDisplay,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (controller.recoveryKeyDisplay != 'Not created')
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show demo key'),
                    value: controller.revealRecoveryKey,
                    onChanged: controller.setRecoveryKeyVisible,
                  ),
                SizedBox(
                  width: double.infinity,
                  child: controller.recoveryKeyDisplay == 'Not created'
                      ? ElevatedButton.icon(
                          onPressed: controller.busy
                              ? null
                              : controller.prepareRecoveryKey,
                          icon: const Icon(Icons.key_rounded),
                          label: const Text('Create demo Recovery Key'),
                        )
                      : ElevatedButton.icon(
                          onPressed:
                              controller.recoveryKeyConfirmed || controller.busy
                              ? null
                              : controller.confirmRecoveryKey,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            controller.recoveryKeyConfirmed
                                ? 'Recovery Key confirmed'
                                : 'I saved the demo key',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Encrypt sample media',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(8),
                Text(
                  controller.vaultEncryptionComplete
                      ? 'Encrypted demo container created in isolated Vault storage.'
                      : 'Confirm the Recovery Key, then run real local encryption on generated demo bytes.',
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        !controller.recoveryKeyConfirmed || controller.busy
                        ? null
                        : controller.encryptDemoMedia,
                    icon: const Icon(Icons.enhanced_encryption_rounded),
                    label: const Text('Encrypt demo media locally'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoSettings extends StatelessWidget {
  final ReviewerDemoController controller;
  final bool exiting;
  final Future<void> Function() onExit;

  const _DemoSettings({
    required this.controller,
    required this.exiting,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metadata backup — simulated',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Gap(8),
                Text(
                  controller.metadataBackedUpAt == null
                      ? 'Demo snapshot is waiting. No Telegram channel is used.'
                      : 'Demo snapshot updated locally just now.',
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.simulateMetadataBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Simulate metadata backup'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy & transparency'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsSummaryScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Deletion information'),
                subtitle: const Text(
                  'Demo data can be cleared without touching normal TeleVault data.',
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Demo data deletion'),
                    content: const Text(
                      'Exit reviewer demo removes only its sample database, generated Vault files, demo secure-storage entries, cache and demo worker names. Production Telegram sessions and media metadata are never opened or deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        OutlinedButton.icon(
          onPressed: exiting ? null : onExit,
          icon: exiting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Exit reviewer demo'),
        ),
        const Gap(8),
        const Text(
          'Exiting clears only Reviewer Demo data and returns to normal Telegram startup.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.inkMuted),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(icon)),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Gap(4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DemoNotice extends StatelessWidget {
  final String? text;

  const _DemoNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text!, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
