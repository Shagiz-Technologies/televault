import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/database/app_database.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/services/settings_service.dart';
import '../services/bucket_service.dart';
import 'bucket_setup_screen.dart';

class BucketSelectorSheet extends ConsumerWidget {
  const BucketSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(bucketListProvider);
    final buckets = bucketsAsync.asData?.value ?? const <Bucket>[];
    final limitReached = buckets.length >= BucketService.maxFreeBuckets;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup spaces',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Gap(3),
                          const Text(
                            'Choose where each kind of media goes.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TeleVaultStatusPill(
                      label:
                          '${buckets.length} of ${BucketService.maxFreeBuckets}',
                      color: limitReached ? AppTheme.warning : AppTheme.primary,
                      compact: true,
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: bucketsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  error: (error, _) => _BucketMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Buckets unavailable',
                    message: '$error',
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _BucketMessage(
                        icon: Icons.create_new_folder_outlined,
                        title: 'No buckets yet',
                        message: 'Create one to start backing up your media.',
                      );
                    }

                    final activeId = items
                        .firstWhere(
                          (bucket) => bucket.isActive,
                          orElse: () => items.first,
                        )
                        .id;
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Gap(10),
                      itemBuilder: (context, index) {
                        final bucket = items[index];
                        return _BucketTile(
                          bucket: bucket,
                          isActive: bucket.id == activeId,
                          preferences: ref.watch(
                            bucketSyncPreferencesProvider(bucket.id),
                          ),
                          onTap: () async {
                            if (bucket.id == activeId) return;
                            await ref
                                .read(bucketServiceProvider)
                                .setActiveBucket(bucket.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      limitReached
                          ? Icons.lock_outline_rounded
                          : Icons.add_rounded,
                    ),
                    label: Text(
                      limitReached
                          ? 'Bucket limit reached'
                          : 'Create new bucket',
                    ),
                    onPressed: bucketsAsync.isLoading || limitReached
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            await navigator.push<int>(
                              MaterialPageRoute(
                                builder: (_) => const BucketSetupScreen(),
                              ),
                            );
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketTile extends StatelessWidget {
  final Bucket bucket;
  final bool isActive;
  final AsyncValue<SyncPreferences> preferences;
  final VoidCallback onTap;

  const _BucketTile({
    required this.bucket,
    required this.isActive,
    required this.preferences,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = preferences.when(
      loading: () => _mediaScope(bucket.allowedMediaTypes),
      error: (_, _) => _mediaScope(bucket.allowedMediaTypes),
      data: (value) {
        final syncState = value.autoBackupEnabled
            ? 'Auto-sync on'
            : 'Auto-sync off';
        return '${_mediaScope(bucket.allowedMediaTypes)} - $syncState';
      },
    );

    return Semantics(
      selected: isActive,
      button: true,
      label: '${bucket.name}. $subtitle',
      child: TeleVaultCard(
        padding: EdgeInsets.zero,
        color: isActive ? const Color(0xFFF7FBFF) : AppTheme.surface,
        borderColor: isActive ? AppTheme.primary : AppTheme.outline,
        onTap: isActive ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TeleVaultIconBadge(
                icon: isActive
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_queue_rounded,
                color: isActive ? AppTheme.primary : AppTheme.inkMuted,
                size: 46,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bucket.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (isActive)
                          const TeleVaultStatusPill(
                            label: 'Active',
                            color: AppTheme.primary,
                            compact: true,
                          ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.inkMuted),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _mediaScope(String raw) {
    final types = raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final labels = <String>[
      if (types.contains(BucketMediaType.photo.name)) 'Photos',
      if (types.contains(BucketMediaType.video.name)) 'Videos',
    ];
    return labels.isEmpty ? 'Media' : labels.join(' + ');
  }
}

class _BucketMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BucketMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return TeleVaultEmptyState(icon: icon, title: title, message: message);
  }
}
