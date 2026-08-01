import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../../core/database/file_sync_status.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/presentation/bucket_selector_sheet.dart';
import '../../buckets/services/bucket_service.dart';
import '../../library/presentation/widgets/media_access_notice.dart';
import '../../library/services/media_permission_policy.dart';
import '../../library/services/media_permission_service.dart';
import '../../settings/presentation/sync_preferences_screen.dart';
import '../../settings/services/settings_service.dart';
import '../services/file_uploader.dart';
import '../services/sync_constraints_service.dart';
import '../services/sync_service.dart';
import '../services/sync_status_service.dart';

class SyncDashboardScreen extends ConsumerStatefulWidget {
  const SyncDashboardScreen({super.key});

  @override
  ConsumerState<SyncDashboardScreen> createState() =>
      _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends ConsumerState<SyncDashboardScreen>
    with WidgetsBindingObserver {
  bool _syncingNow = false;
  bool _retrying = false;
  bool _savingAutoBackup = false;
  bool _oldestFirst = true;
  String? _constraintBlockReason;
  int? _constraintBucketId;
  StreamSubscription? _constraintSub;
  StreamSubscription<TelegramReliabilityState>? _telegramStateSub;
  Timer? _countdownTimer;
  TelegramReliabilityState _telegramState = const TelegramReliabilityState();
  late Future<MediaPermissionStatus> _mediaPermissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mediaPermissionStatus = ref
        .read(mediaPermissionPolicyProvider)
        .activeStatus();
    final reliability = ref.read(telegramReliabilityServiceProvider);
    _telegramState = reliability.currentState;
    _telegramStateSub = reliability.states.listen((state) {
      if (mounted) setState(() => _telegramState = state);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _telegramState.isBlockedAt(DateTime.now())) {
        setState(() {});
      }
    });
    _constraintSub = ref
        .read(syncConstraintsServiceProvider)
        .watchConstraintChanges()
        .listen(
          (_) => _refreshConstraintReason(_constraintBucketId),
          onError: (_, _) {
            if (!mounted) return;
            setState(() {
              _constraintBlockReason = 'Waiting for device status';
            });
          },
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _constraintSub?.cancel();
    _telegramStateSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _mediaPermissionStatus = ref
            .read(mediaPermissionPolicyProvider)
            .activeStatus();
      });
    }
  }

  Future<void> _manageMediaAccess(MediaPermissionStatus status) async {
    try {
      final policy = ref.read(mediaPermissionPolicyProvider);
      final service = ref.read(mediaPermissionServiceProvider);
      final request = await policy.activeRequest();
      if (status.canRequestAgain) {
        await service.updateSelectedAccess(request);
      } else {
        await service.openSettings();
      }
      if (mounted) {
        setState(() => _mediaPermissionStatus = policy.activeStatus());
      }
    } on MediaPermissionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _refreshConstraintReason(int? bucketId) async {
    final blockReason = bucketId == null
        ? null
        : await ref
              .read(syncConstraintsServiceProvider)
              .automaticSyncBlockReason(bucketId: bucketId);
    if (!mounted || bucketId != _constraintBucketId) return;
    setState(() => _constraintBlockReason = blockReason);
  }

  Future<void> _toggleAutoBackup(bool value, int bucketId) async {
    setState(() => _savingAutoBackup = true);
    try {
      await ref
          .read(settingsServiceProvider)
          .setAutoBackup(value, bucketId: bucketId);
      if (value) {
        await ref.read(syncServiceProvider).syncNow(ignoreConstraints: false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update backup right now')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAutoBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBucketAsync = ref.watch(activeBucketProvider);
    final activeBucket = activeBucketAsync.asData?.value;
    final activeBucketId = activeBucket?.id;
    final preferencesAsync = activeBucketId == null
        ? null
        : ref.watch(bucketSyncPreferencesProvider(activeBucketId));
    final autoBackupEnabled =
        preferencesAsync?.asData?.value.autoBackupEnabled ?? false;
    final loadingControls =
        activeBucketAsync.isLoading || (preferencesAsync?.isLoading ?? false);
    final statusAsync = ref.watch(bucketSyncStatusProvider(activeBucketId));
    final status =
        statusAsync.asData?.value ?? const SyncStatusSnapshot.empty();
    final AsyncValue<List<BackupActivityItem>> activityAsync =
        activeBucketId == null
        ? const AsyncData([])
        : ref.watch(
            bucketBackupActivityProvider((
              bucketId: activeBucketId,
              oldestFirst: _oldestFirst,
            )),
          );
    final activity =
        activityAsync.asData?.value ?? const <BackupActivityItem>[];
    final featuredItem = _featuredActivity(activity);

    if (_constraintBucketId != activeBucketId) {
      _constraintBucketId = activeBucketId;
      _constraintBlockReason = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshConstraintReason(activeBucketId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Status'),
        actions: [
          IconButton(
            tooltip: 'Sync preferences',
            onPressed: activeBucketId == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SyncPreferencesScreen(),
                    ),
                  ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: RefreshIndicator(
          onRefresh: _startManualSync,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppResponsive.pagePaddingWithBottomSafe(
              context,
              horizontal: 16,
              top: 8,
              bottomExtra: 18,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _BucketPill(
                  name: activeBucket?.name ?? 'No active bucket',
                  available: activeBucket != null,
                  onTap: _showBucketSelector,
                ),
              ),
              FutureBuilder<MediaPermissionStatus>(
                future: _mediaPermissionStatus,
                builder: (context, snapshot) {
                  final permission = snapshot.data;
                  if (permission == null ||
                      permission.scope != MediaAccessScope.limitedAccess) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MediaAccessNotice(
                      status: permission,
                      onManageAccess: () => _manageMediaAccess(permission),
                    ),
                  );
                },
              ),
              const Gap(14),
              TeleVaultCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _BackupHero(
                      status: status,
                      loading: statusAsync.isLoading,
                      item: featuredItem,
                    ),
                    if (_constraintBlockReason != null) ...[
                      const Gap(12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TeleVaultStatusPill(
                          label: _constraintBlockReason!,
                          icon: Icons.pause_circle_outline_rounded,
                          color: AppTheme.warning,
                          compact: true,
                        ),
                      ),
                    ],
                    const Gap(16),
                    _MetricsGrid(status: status),
                  ],
                ),
              ),
              const Gap(14),
              if (_telegramState.isBlockedAt(DateTime.now())) ...[
                _telegramPauseCard(context),
                const Gap(14),
              ],
              _StorageCard(status: status),
              const Gap(14),
              TeleVaultCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Activity',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<bool>(
                            tooltip: 'Activity order',
                            initialValue: _oldestFirst,
                            onSelected: (value) {
                              setState(() => _oldestFirst = value);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: true,
                                child: Text('Oldest first'),
                              ),
                              PopupMenuItem(
                                value: false,
                                child: Text('Newest first'),
                              ),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _oldestFirst
                                      ? 'Oldest first'
                                      : 'Newest first',
                                  style: const TextStyle(
                                    color: AppTheme.inkMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Gap(2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.inkMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activityAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else if (activity.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 10, 18, 22),
                        child: Text(
                          'No backup activity for this bucket yet.',
                          style: TextStyle(color: AppTheme.inkMuted),
                        ),
                      )
                    else
                      ...activity.map(
                        (item) => _BackupActivityTile(
                          item: item,
                          activeProgress:
                              item.status == FileSyncStatus.uploading
                              ? status.activeUploadProgress
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          loadingControls ||
                              activeBucketId == null ||
                              _savingAutoBackup
                          ? null
                          : () => _toggleAutoBackup(
                              !autoBackupEnabled,
                              activeBucketId,
                            ),
                      icon: Icon(
                        autoBackupEnabled
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(autoBackupEnabled ? 'Pause' : 'Resume'),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _retrying ||
                              status.failedCount == 0 ||
                              _telegramState.isBlockedAt(DateTime.now())
                          ? null
                          : () => _retryFailed(
                              activeBucketId,
                              activeBucket?.name,
                            ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        _retrying
                            ? 'Retrying...'
                            : 'Retry ${status.failedCount}',
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(14),
              _LiveBackupBanner(
                status: status,
                autoBackupEnabled: autoBackupEnabled,
                syncingNow: _syncingNow,
                onTap: _syncingNow ? null : _startManualSync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BackupActivityItem? _featuredActivity(List<BackupActivityItem> activity) {
    for (final item in activity) {
      if (item.status == FileSyncStatus.uploading) return item;
    }
    for (final item in activity) {
      if (item.status == FileSyncStatus.pending) return item;
    }
    return activity.isEmpty ? null : activity.first;
  }

  Future<void> _showBucketSelector() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const BucketSelectorSheet(),
    );
    if (mounted) {
      await ref.read(syncServiceProvider).syncNow(ignoreConstraints: false);
    }
  }

  Future<void> _startManualSync() async {
    if (_syncingNow) return;
    setState(() => _syncingNow = true);
    try {
      await ref.read(syncServiceProvider).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup scan started')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start backup right now')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

  Future<void> _retryFailed(int? bucketId, String? bucketName) async {
    setState(() => _retrying = true);
    try {
      final retried = await ref
          .read(fileUploaderProvider)
          .retryFailed(bucketId: bucketId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bucketName == null
                ? 'Retrying $retried failed item(s)'
                : 'Retrying $retried failed item(s) to $bucketName',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget _telegramPauseCard(BuildContext context) {
    final blockedUntil = _telegramState.blockedUntil!;
    final remaining = _telegramState.remainingAt(DateTime.now());
    final totalSeconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final countdown = hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : '${minutes}m ${seconds}s';
    final resumeTime = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(blockedUntil.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return TeleVaultCard(
      color: AppTheme.warning.withValues(alpha: 0.10),
      borderColor: AppTheme.warning.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppTheme.warning),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Telegram uploads paused',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Gap(3),
                Text(
                  _telegramState.pauseReason ??
                      'Telegram requested a temporary wait.',
                  style: const TextStyle(color: AppTheme.inkMuted),
                ),
                const Gap(3),
                Text(
                  'Resumes at $resumeTime ($countdown)',
                  style: const TextStyle(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketPill extends StatelessWidget {
  final String name;
  final bool available;
  final VoidCallback onTap;

  const _BucketPill({
    required this.name,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppTheme.outline)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                color: available ? AppTheme.success : AppTheme.inkMuted,
                size: 10,
              ),
              const Gap(7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Gap(4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.inkMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupHero extends StatelessWidget {
  final SyncStatusSnapshot status;
  final bool loading;
  final BackupActivityItem? item;

  const _BackupHero({
    required this.status,
    required this.loading,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final progress = status.totalCount == 0 ? 0.0 : status.overallProgress;
    final isUploading = status.uploadingCount > 0;
    final featuredItem = item;
    return Row(
      children: [
        SizedBox.square(
          dimension: 142,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: loading ? null : progress,
                strokeWidth: 9,
                strokeCap: StrokeCap.round,
                backgroundColor: AppTheme.paperMuted,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loading ? '...' : '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 36, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      isUploading
                          ? 'Uploading'
                          : status.pendingCount > 0
                          ? 'Waiting'
                          : 'Protected',
                      style: const TextStyle(
                        color: AppTheme.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${status.completedCount} of ${status.totalCount}',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(18),
        Expanded(
          child: Column(
            children: [
              _BackupThumbnail(item: item, size: 100),
              const Gap(8),
              Text(
                featuredItem == null
                    ? 'Ready'
                    : '${_mediaKind(featuredItem.localPath)} · '
                          '${formatSyncBytes(featuredItem.size)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final SyncStatusSnapshot status;

  const _MetricsGrid({required this.status});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Queued',
        status.pendingCount,
        Icons.hourglass_bottom_rounded,
        AppTheme.primary,
      ),
      (
        'Uploading',
        status.uploadingCount,
        Icons.arrow_upward_rounded,
        AppTheme.success,
      ),
      (
        'Failed',
        status.failedCount,
        Icons.warning_amber_rounded,
        AppTheme.error,
      ),
      (
        'Complete',
        status.completedCount,
        Icons.check_circle_outline_rounded,
        AppTheme.success,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const Gap(7),
          Expanded(
            child: _MetricTile(
              label: metrics[index].$1,
              count: metrics[index].$2,
              icon: metrics[index].$3,
              color: metrics[index].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const Gap(4),
          Text(
            '$count',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: AppTheme.inkMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final SyncStatusSnapshot status;

  const _StorageCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return TeleVaultCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Storage',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${formatSyncBytes(status.completedBytes)} protected',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Gap(8),
          LinearProgressIndicator(
            value: status.totalCount == 0 ? 0 : status.overallProgress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            color: AppTheme.success,
          ),
          const Gap(7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatSyncBytes(status.completedBytes)} of this bucket is confirmed on Telegram',
              style: const TextStyle(color: AppTheme.inkMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupActivityTile extends StatelessWidget {
  final BackupActivityItem item;
  final double? activeProgress;

  const _BackupActivityTile({required this.item, this.activeProgress});

  @override
  Widget build(BuildContext context) {
    final appearance = _statusAppearance(item.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(
        children: [
          _BackupThumbnail(item: item, size: 46),
          const Gap(10),
          if (item.status == FileSyncStatus.uploading)
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: activeProgress,
                strokeWidth: 3,
                backgroundColor: AppTheme.paperMuted,
              ),
            )
          else
            Icon(appearance.$1, color: appearance.$2, size: 23),
          const Gap(9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_mediaKind(item.localPath)} · ${formatSyncBytes(item.size)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  appearance.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appearance.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Text(
            _relativeTime(item.lastAttemptAt ?? item.dateAdded),
            style: const TextStyle(color: AppTheme.inkMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _LiveBackupBanner extends StatelessWidget {
  final SyncStatusSnapshot status;
  final bool autoBackupEnabled;
  final bool syncingNow;
  final VoidCallback? onTap;

  const _LiveBackupBanner({
    required this.status,
    required this.autoBackupEnabled,
    required this.syncingNow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uploading = status.uploadingCount > 0;
    final title = syncingNow
        ? 'TeleVault · Scanning'
        : uploading
        ? 'TeleVault · Backing up ${status.completedCount}/${status.totalCount}'
        : autoBackupEnabled
        ? 'TeleVault · Watching for new media'
        : 'TeleVault · Backup paused';
    return TeleVaultCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          const TeleVaultIconBadge(
            icon: Icons.send_rounded,
            color: AppTheme.primary,
            size: 42,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(2),
                Text(
                  '${formatSyncBytes(status.completedBytes)} complete · Tap to sync now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.inkMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            uploading ? Icons.circle : Icons.circle_outlined,
            color: uploading || autoBackupEnabled
                ? AppTheme.success
                : AppTheme.warning,
            size: 10,
          ),
        ],
      ),
    );
  }
}

class _BackupThumbnail extends StatefulWidget {
  final BackupActivityItem? item;
  final double size;

  const _BackupThumbnail({required this.item, required this.size});

  @override
  State<_BackupThumbnail> createState() => _BackupThumbnailState();
}

class _BackupThumbnailState extends State<_BackupThumbnail> {
  Future<AssetEntity?>? _asset;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(covariant _BackupThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.assetId != widget.item?.assetId) {
      _loadAsset();
    }
  }

  void _loadAsset() {
    final assetId = widget.item?.assetId;
    _asset = assetId == null ? Future.value() : AssetEntity.fromId(assetId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.paperMuted,
        borderRadius: BorderRadius.circular(widget.size > 60 ? 18 : 12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: FutureBuilder<AssetEntity?>(
        future: _asset,
        builder: (context, snapshot) {
          final asset = snapshot.data;
          if (asset != null) {
            return AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: ThumbnailSize.square(
                (widget.size * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(120, 600),
              ),
              fit: BoxFit.cover,
            );
          }
          final item = widget.item;
          if (item != null && _isImagePath(item.localPath)) {
            return Image.file(
              io.File(item.localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(item.localPath),
            );
          }
          return _placeholder(item?.localPath);
        },
      ),
    );
  }

  Widget _placeholder(String? path) {
    return Icon(
      path != null && _isVideoPath(path)
          ? Icons.videocam_outlined
          : Icons.photo_outlined,
      color: AppTheme.inkMuted,
      size: widget.size * 0.42,
    );
  }
}

(IconData, Color, String) _statusAppearance(FileSyncStatus status) {
  return switch (status) {
    FileSyncStatus.pending => (
      Icons.hourglass_bottom_rounded,
      AppTheme.primary,
      'Queued',
    ),
    FileSyncStatus.uploading => (
      Icons.arrow_upward_rounded,
      AppTheme.primary,
      'Uploading',
    ),
    FileSyncStatus.synced => (
      Icons.check_circle_rounded,
      AppTheme.success,
      'Complete',
    ),
    FileSyncStatus.failed => (
      Icons.error_outline_rounded,
      AppTheme.error,
      'Failed',
    ),
    _ => (Icons.info_outline_rounded, AppTheme.inkMuted, 'Updated'),
  };
}

String _mediaKind(String path) {
  if (_isVideoPath(path)) return 'Video';
  if (_isImagePath(path)) return 'Photo';
  return 'File';
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

bool _isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.3gp');
}

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';
  return '${time.day}/${time.month}/${time.year}';
}
