import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/database/file_sync_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../library_controller.dart';

class MediaTile extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;
  final int? syncStatus;
  final MediaLabelInfo? label;

  const MediaTile({
    super.key,
    required this.asset,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.isSelected = false,
    this.syncStatus,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSyncStatus = syncStatus ?? FileSyncStatus.pending.dbValue;

    return Semantics(
      button: true,
      selected: isSelected,
      label: asset.type == AssetType.video ? 'Video' : 'Photo',
      child: Material(
        color: AppTheme.paperMuted,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image Thumbnail
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(300),
                fit: BoxFit.cover,
                opacity: isSelected ? const AlwaysStoppedAnimation(0.7) : null,
              ),

              // 2. Selection Overlay (Top Right)
              if (selectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 23,
                    height: 23,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.black.withValues(alpha: 0.22),
                      border: Border.all(
                        color: Colors.white,
                        width: isSelected ? 1.5 : 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                ),

              // 3. Duration Badge for Videos (Bottom Left)
              if (asset.type == AssetType.video &&
                  asset.videoDuration.inSeconds > 0)
                Positioned(
                  bottom: label == null ? 6 : 28,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _formatDuration(asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              // 4. Sync Status Icon
              Positioned(
                top: selectionMode ? null : 6,
                bottom: selectionMode ? 6 : null,
                right: 6,
                child: _buildSyncStatusBadge(effectiveSyncStatus),
              ),

              if (label != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _parseColor(label!.colorHex),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _badgeText(label!),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(int status) {
    return Semantics(
      label: _syncStatusLabel(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.outline, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(status),
            child: _buildSyncStatusIcon(status),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusIcon(int status) {
    if (status == FileSyncStatus.uploading.dbValue) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      );
    }
    if (status == FileSyncStatus.synced.dbValue) {
      return const Icon(
        Icons.check_circle_rounded,
        color: AppTheme.success,
        size: 18,
      );
    }
    if (status == FileSyncStatus.failed.dbValue) {
      return const Icon(Icons.error_rounded, color: AppTheme.error, size: 18);
    }
    if (status == FileSyncStatus.deletedLocal.dbValue) {
      return const Icon(
        Icons.cloud_off_rounded,
        color: AppTheme.warning,
        size: 18,
      );
    }
    if (status == FileSyncStatus.vaultedEncrypted.dbValue) {
      return const Icon(
        Icons.lock_rounded,
        color: AppTheme.encrypted,
        size: 17,
      );
    }
    return const Icon(
      Icons.cloud_upload_outlined,
      color: AppTheme.primary,
      size: 17,
    );
  }

  String _syncStatusLabel(int status) {
    if (status == FileSyncStatus.uploading.dbValue) {
      return 'Uploading backup';
    }
    if (status == FileSyncStatus.synced.dbValue) {
      return 'Backed up';
    }
    if (status == FileSyncStatus.failed.dbValue) {
      return 'Backup failed';
    }
    if (status == FileSyncStatus.deletedLocal.dbValue) {
      return 'Deleted locally';
    }
    if (status == FileSyncStatus.vaultedEncrypted.dbValue) {
      return 'Vault protected';
    }
    return 'Waiting to back up';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _badgeText(MediaLabelInfo label) {
    final name = label.name.length <= 5
        ? label.name
        : label.name.substring(0, 5);
    if (label.emoji != null && label.emoji!.trim().isNotEmpty) {
      return '${label.emoji} $name';
    }
    return name;
  }

  Color _parseColor(String value) {
    final normalized = value.replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return Colors.blueGrey;
  }
}
