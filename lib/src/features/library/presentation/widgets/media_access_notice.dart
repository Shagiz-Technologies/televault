import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/media_permission_service.dart';

class MediaAccessNotice extends StatelessWidget {
  final MediaPermissionStatus status;
  final VoidCallback onManageAccess;

  const MediaAccessNotice({
    required this.status,
    required this.onManageAccess,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (status.scope != MediaAccessScope.limitedAccess) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.photo_library_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limited media access',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onManageAccess, child: const Text('Manage')),
        ],
      ),
    );
  }

  String get _message {
    if (status.imageAccess == MediaTypeAccess.full &&
        status.videoAccess == MediaTypeAccess.denied) {
      return 'Photos can be scanned, but videos are not available. Backup totals cover accessible media only.';
    }
    if (status.videoAccess == MediaTypeAccess.full &&
        status.imageAccess == MediaTypeAccess.denied) {
      return 'Videos can be scanned, but photos are not available. Backup totals cover accessible media only.';
    }
    return 'Only media selected in Android can be scanned. Existing Telegram backups stay unchanged.';
  }
}
