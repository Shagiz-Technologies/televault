import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';

class UploadProgressPill extends ConsumerWidget {
  const UploadProgressPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<int>>(
      // Watch counts of pending & uploading
      stream: db
          .customSelect(
            'SELECT status, COUNT(*) as c FROM files WHERE status IN (0, 1) GROUP BY status',
            readsFrom: {db.files},
          )
          .watch()
          .map((rows) {
            // Return list of counts? Or just total pending.
            // Let's just Map specific statuses.
            int pending = 0;
            int uploading = 0;
            for (var row in rows) {
              final s = row.read<int>('status');
              final c = row.read<int>('c');
              if (s == 0) pending = c;
              if (s == 1) uploading = c;
            }
            return [pending, uploading];
          }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final pending = snapshot.data![0];
        final uploading = snapshot.data![1];
        final total = pending + uploading;

        if (total == 0) {
          // Maybe show "All Synced" for a few seconds then hide?
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E), // Dark grey/black
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Syncing $total items...",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
