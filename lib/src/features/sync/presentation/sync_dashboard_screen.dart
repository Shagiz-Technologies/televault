import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/database/app_database.dart' show Bucket;
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/services/bucket_service.dart';
import '../../settings/services/settings_service.dart';
import '../services/file_uploader.dart';
import '../services/sync_constraints_service.dart';
import '../services/sync_service.dart';

class SyncDashboardScreen extends ConsumerStatefulWidget {
  const SyncDashboardScreen({super.key});

  @override
  ConsumerState<SyncDashboardScreen> createState() =>
      _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends ConsumerState<SyncDashboardScreen> {
  bool _syncingNow = false;
  bool _retrying = false;
  bool _loadingControls = true;
  bool _savingAutoBackup = false;
  bool _autoBackupEnabled = true;
  bool _constraintsAllowed = true;
  Bucket? _activeBucket;
  StreamSubscription? _constraintSub;

  @override
  void initState() {
    super.initState();
    _constraintSub = ref
        .read(syncConstraintsServiceProvider)
        .watchConstraintChanges()
        .listen((_) async {
          final allowed = await ref
              .read(syncConstraintsServiceProvider)
              .canRunAutomaticSync(bucketId: _activeBucket?.id);
          if (!mounted) return;
          setState(() => _constraintsAllowed = allowed);
        });
    _loadControls();
  }

  @override
  void dispose() {
    _constraintSub?.cancel();
    super.dispose();
  }

  Future<void> _loadControls() async {
    final settings = ref.read(settingsServiceProvider);
    final constraints = ref.read(syncConstraintsServiceProvider);
    final activeBucket = await ref
        .read(bucketServiceProvider)
        .getActiveBucket();
    final autoBackup = await settings.isAutoBackupEnabled(
      bucketId: activeBucket?.id,
    );
    final allowed = await constraints.canRunAutomaticSync(
      bucketId: activeBucket?.id,
    );
    if (!mounted) return;
    setState(() {
      _activeBucket = activeBucket;
      _autoBackupEnabled = autoBackup;
      _constraintsAllowed = allowed;
      _loadingControls = false;
    });
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _savingAutoBackup = true);
    try {
      await ref
          .read(settingsServiceProvider)
          .setAutoBackup(value, bucketId: _activeBucket?.id);
      if (value) {
        await ref.read(syncServiceProvider).syncNow(ignoreConstraints: false);
      }
      if (!mounted) return;
      setState(() => _autoBackupEnabled = value);
    } finally {
      if (mounted) setState(() => _savingAutoBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final uploader = ref.watch(fileUploaderProvider);

    final activeBucketId = _activeBucket?.id;
    final countsStream = activeBucketId == null
        ? db
              .customSelect(
                '''
                  SELECT status, COUNT(*) AS c
                  FROM files
                  GROUP BY status
                  ''',
                readsFrom: {db.files},
              )
              .watch()
        : db
              .customSelect(
                '''
                  SELECT status, COUNT(*) AS c
                  FROM files
                  WHERE bucket_id = ?
                  GROUP BY status
                  ''',
                variables: [Variable.withInt(activeBucketId)],
                readsFrom: {db.files},
              )
              .watch();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Sync Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingControls)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else
              Card(
                color: AppTheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _activeBucket == null
                                  ? 'Auto Backup'
                                  : 'Auto Backup: ${_activeBucket!.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Switch(
                            value: _autoBackupEnabled,
                            onChanged: _savingAutoBackup
                                ? null
                                : _toggleAutoBackup,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            _constraintsAllowed
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            size: 16,
                            color: _constraintsAllowed
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              _constraintsAllowed
                                  ? 'Sync constraints satisfied'
                                  : 'Waiting for Wi-Fi or charging state',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadControls,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const Gap(8),
            StreamBuilder<List<QueryRow>>(
              stream: countsStream,
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <QueryRow>[];
                final map = <int, int>{};
                for (final row in rows) {
                  map[row.read<int>('status')] = row.read<int>('c');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statPill(
                      'Pending',
                      map[FileSyncStatus.pending.dbValue] ?? 0,
                      Colors.orange,
                    ),
                    _statPill(
                      'Uploading',
                      map[FileSyncStatus.uploading.dbValue] ?? 0,
                      Colors.blue,
                    ),
                    _statPill(
                      'Synced',
                      map[FileSyncStatus.synced.dbValue] ?? 0,
                      Colors.green,
                    ),
                    _statPill(
                      'Failed',
                      map[FileSyncStatus.failed.dbValue] ?? 0,
                      Colors.redAccent,
                    ),
                  ],
                );
              },
            ),
            const Gap(16),
            StreamBuilder<Map<String, double>>(
              stream: uploader.progress,
              builder: (context, snapshot) {
                final active = snapshot.data ?? const <String, double>{};
                if (active.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Card(
                  color: AppTheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: active.entries.take(4).map((entry) {
                        final fileName = entry.key.split(RegExp(r'[/\\]')).last;
                        final pct = (entry.value * 100).toStringAsFixed(0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(4),
                              LinearProgressIndicator(
                                value: entry.value,
                                backgroundColor: Colors.white10,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _syncingNow
                        ? null
                        : () async {
                            setState(() => _syncingNow = true);
                            try {
                              await ref.read(syncServiceProvider).syncNow();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Manual sync started'),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _syncingNow = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.sync),
                    label: Text(_syncingNow ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retrying
                        ? null
                        : () async {
                            setState(() => _retrying = true);
                            try {
                              final retried = await ref
                                  .read(fileUploaderProvider)
                                  .retryFailed(bucketId: _activeBucket?.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Retried $retried failed item(s)',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _retrying = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(_retrying ? 'Retrying...' : 'Retry Failed'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Gap(8),
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
