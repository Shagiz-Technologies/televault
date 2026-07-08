import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/database/app_database.dart'; // For Bucket class
import '../../../core/theme/app_theme.dart';
import '../services/bucket_service.dart';
import 'bucket_setup_screen.dart'; // Reuse for creation

class BucketSelectorSheet extends ConsumerWidget {
  const BucketSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketService = ref.watch(bucketServiceProvider);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          Text(
            "Storage Buckets",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          FutureBuilder<List<Bucket>>(
            future: bucketService.getBuckets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final buckets = snapshot.data ?? [];

              if (buckets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "No buckets found yet. Create one to start syncing.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: buckets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bucket = buckets[index];
                    final activeId = buckets
                        .firstWhere(
                          (b) => b.isActive,
                          orElse: () => buckets.first,
                        )
                        .id;
                    final isActive = bucket.id == activeId;
                    return ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isActive ? AppTheme.primary : Colors.grey,
                      ),
                      title: Text(
                        bucket.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "ID: ${bucket.chatId}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        bucket.isActive
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_queue_rounded,
                        color: bucket.isActive ? AppTheme.primary : Colors.grey,
                      ),
                      onTap: isActive
                          ? null
                          : () async {
                              await bucketService.setActiveBucket(bucket.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                    );
                  },
                ),
              );
            },
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: FutureBuilder<int>(
                future: bucketService.getBucketCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  final limitReached = count >= BucketService.maxFreeBuckets;
                  return OutlinedButton.icon(
                    icon: Icon(
                      limitReached
                          ? Icons.lock_outline_rounded
                          : Icons.add_rounded,
                    ),
                    label: Text(
                      limitReached
                          ? "Bucket Limit Reached"
                          : "Create New Bucket",
                    ),
                    onPressed: limitReached
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BucketSetupScreen(),
                              ),
                            );
                          },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
