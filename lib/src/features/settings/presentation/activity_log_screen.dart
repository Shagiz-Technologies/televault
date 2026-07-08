import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../sync/services/file_uploader.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final uploader = ref.watch(fileUploaderProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Active Uploads Section
          StreamBuilder<Map<String, double>>(
            stream: uploader.progress,
            builder: (context, progressSnapshot) {
              if (!progressSnapshot.hasData || progressSnapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final active = progressSnapshot.data!;
              return Column(
                children: active.entries.map((e) {
                  final path = e.key.split(RegExp(r'[/\\]')).last;
                  final percent = e.value;
                  return Container(
                    color: Colors.grey[900],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Uploading $path",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "${(percent * 100).toInt()}%",
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Gap(4),
                        LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey[800],
                          color: AppTheme.primary,
                          minHeight: 4,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // History List
          Expanded(
            child: StreamBuilder<List<File>>(
              stream:
                  (db.select(db.files)
                        ..where((t) => t.status.equals(2)) // Synced
                        ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])
                        ..limit(100))
                      .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final files = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = file.localPath.split('/').last;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.cloud_done,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Backed up $fileName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatDate(file.dateAdded),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          _formatFileSize(file.size),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
