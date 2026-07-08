import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';

class SyncProgressIcon extends ConsumerWidget {
  final VoidCallback onTap;

  const SyncProgressIcon({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Map<String, int>>(
      stream: db
          .customSelect(
            'SELECT status, COUNT(*) as c FROM files GROUP BY status',
            readsFrom: {db.files},
          )
          .watch()
          .map((rows) {
            int total = 0;
            int synced = 0;
            int pending = 0;
            for (var row in rows) {
              final s = row.read<int>('status');
              final c = row.read<int>('c');
              if (s == 0 || s == 1) pending += c;
              if (s == 2) synced += c;
              total += c;
            }
            return {'pending': pending, 'synced': synced, 'total': total};
          }),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'pending': 0, 'synced': 0, 'total': 0};
        final pending = data['pending']!;
        final total = data['total']!;

        // If nothing pending, show normal icon
        if (pending == 0) {
          return IconButton(
            icon: const Icon(Icons.cloud_done, color: Colors.green),
            onPressed: onTap,
          );
        }

        // Calculate percentage
        final progress = total > 0 ? (total - pending) / total : 0.0;

        return GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: Colors.blue,
                ),
                if (progress > 0)
                  Positioned(
                    bottom: -2,
                    child: Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
