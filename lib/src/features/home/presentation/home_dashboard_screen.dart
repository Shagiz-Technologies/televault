import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/services/bucket_service.dart';
import '../../library/presentation/library_screen.dart';
import '../../sync/presentation/sync_dashboard_screen.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_service.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _runningSync = false;
  bool _retryingFailed = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final uploader = ref.watch(fileUploaderProvider);
    final bucketService = ref.watch(bucketServiceProvider);

    final countsStream = db
        .customSelect(
          'SELECT status, COUNT(*) AS c FROM files GROUP BY status',
          readsFrom: {db.files},
        )
        .watch();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TeleVault'),
        actions: [
          IconButton(
            tooltip: 'Open full sync dashboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncDashboardScreen()),
              );
            },
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<QueryRow>>(
        stream: countsStream,
        builder: (context, snapshot) {
          final map = <int, int>{};
          for (final row in snapshot.data ?? const <QueryRow>[]) {
            map[row.read<int>('status')] = row.read<int>('c');
          }

          final pending = map[FileSyncStatus.pending.dbValue] ?? 0;
          final uploading = map[FileSyncStatus.uploading.dbValue] ?? 0;
          final synced = map[FileSyncStatus.synced.dbValue] ?? 0;
          final failed = map[FileSyncStatus.failed.dbValue] ?? 0;
          final total = pending + uploading + synced + failed;
          final completion = total == 0 ? 0.0 : synced / total;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder(
                future: bucketService.getActiveBucket(),
                builder: (context, snapshot) {
                  final bucket = snapshot.data;
                  final bucketName = bucket?.name ?? 'No active bucket';
                  final bucketSubtitle = bucket == null
                      ? 'Create/select a bucket to start backup'
                      : 'Backups are saved to this private Telegram channel';
                  return _heroCard(
                    bucketName: bucketName,
                    bucketSubtitle: bucketSubtitle,
                    completion: completion,
                    pending: pending,
                    uploading: uploading,
                    failed: failed,
                  );
                },
              ),
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _countChip('Backed up', synced, Colors.green),
                  _countChip('Pending', pending, Colors.orange),
                  _countChip('Uploading', uploading, AppTheme.primary),
                  _countChip('Failed', failed, Colors.redAccent),
                ],
              ),
              const Gap(14),
              _quickActions(),
              const Gap(14),
              _achievementCard(synced),
              const Gap(14),
              StreamBuilder<Map<String, double>>(
                stream: uploader.progress,
                builder: (context, snapshot) {
                  final active = snapshot.data ?? const <String, double>{};
                  if (active.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _activeUploadsCard(active);
                },
              ),
              const Gap(14),
              _helpCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _heroCard({
    required String bucketName,
    required String bucketSubtitle,
    required double completion,
    required int pending,
    required int uploading,
    required int failed,
  }) {
    final healthText = failed > 0
        ? '$failed item(s) need attention'
        : (pending + uploading > 0)
        ? 'Backup in progress'
        : 'Everything is up to date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11233F), Color(0xFF0C1A2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backup Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Gap(4),
          Text(
            healthText,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Gap(16),
          Text(
            bucketName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(2),
          Text(
            bucketSubtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const Gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.lightBlueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Gap(8),
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _runningSync
                ? null
                : () async {
                    setState(() => _runningSync = true);
                    try {
                      await ref.read(syncServiceProvider).syncNow();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Manual sync started')),
                      );
                    } finally {
                      if (mounted) setState(() => _runningSync = false);
                    }
                  },
            icon: const Icon(Icons.sync),
            label: Text(_runningSync ? 'Starting...' : 'Sync Now'),
          ),
        ),
        const Gap(8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retryingFailed
                ? null
                : () async {
                    setState(() => _retryingFailed = true);
                    try {
                      final activeBucket = await ref
                          .read(bucketServiceProvider)
                          .getActiveBucket();
                      final retried = await ref
                          .read(fileUploaderProvider)
                          .retryFailed(bucketId: activeBucket?.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Retry queued for $retried item(s)'),
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _retryingFailed = false);
                    }
                  },
            icon: const Icon(Icons.refresh),
            label: Text(_retryingFailed ? 'Retrying...' : 'Retry Failed'),
          ),
        ),
      ],
    );
  }

  Widget _achievementCard(int synced) {
    String badge = 'Starter';
    String subtitle = 'First backup milestone';
    IconData icon = Icons.rocket_launch_outlined;
    Color color = Colors.orange;

    if (synced >= 500) {
      badge = 'Archivist';
      subtitle = '500+ files safely backed up';
      icon = Icons.verified_user_outlined;
      color = Colors.cyanAccent;
    } else if (synced >= 100) {
      badge = 'Collector';
      subtitle = '100+ files protected';
      icon = Icons.workspace_premium_outlined;
      color = Colors.lightGreenAccent;
    } else if (synced >= 10) {
      badge = 'Consistent';
      subtitle = '10+ files backed up';
      icon = Icons.check_circle_outline;
      color = Colors.lightBlueAccent;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text('Backup Badge: $badge'),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: Text(
          '$synced',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _activeUploadsCard(Map<String, double> active) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uploading Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Gap(10),
            ...active.entries.take(3).map((entry) {
              final name = entry.key.split(RegExp(r'[/\\]')).last;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Gap(4),
                    LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 5,
                      backgroundColor: Colors.white10,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _helpCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white70,
            ),
            title: const Text('Review Library'),
            subtitle: const Text(
              'Select photos and videos to vault or delete',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              );
            },
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.shield_outlined, color: Colors.white70),
            title: Text('Tip'),
            subtitle: Text(
              'Turn on Wi-Fi only in Sync Preferences to reduce mobile data usage.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
