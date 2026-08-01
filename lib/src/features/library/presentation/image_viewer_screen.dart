import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../../core/database/file_sync_status.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/services/app_lock_controller.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import '../../vault/presentation/vault_recovery_key_screen.dart';
import '../../vault/services/vault_recovery_service.dart';
import 'library_controller.dart';
import 'widgets/label_editor_dialog.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _vaulting = false;
  bool _currentImageZoomed = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _initMedia();
  }

  void _initMedia() {
    final asset = widget.assets[_currentIndex];
    if (asset.type == AssetType.video) {
      _initVideo(asset);
    }
  }

  Future<void> _initVideo(AssetEntity asset) async {
    _disposeVideo();
    final file = await asset.file;
    if (file == null) return;

    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
      allowFullScreen: false,
    );

    if (mounted) setState(() {});
  }

  void _disposeVideo() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideo();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _showControls ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentImageZoomed = false;
    });
    _initMedia();
  }

  void _onImageZoomChanged(bool isZoomed) {
    if (!mounted || _currentImageZoomed == isZoomed) return;
    setState(() {
      _currentImageZoomed = isZoomed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.assets[_currentIndex];
    final syncStatus = ref.watch(
      libraryControllerProvider.select((state) => state.assetStatus[asset.id]),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Media Page View (Image or Video)
          PageView.builder(
            controller: _pageController,
            physics: _currentImageZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.assets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final currentAsset = widget.assets[index];

              // Check if video
              if (currentAsset.type == AssetType.video) {
                if (index == _currentIndex &&
                    _chewieController != null &&
                    _chewieController!
                        .videoPlayerController
                        .value
                        .isInitialized) {
                  return GestureDetector(
                    onTap: _toggleControls,
                    child: Center(
                      child: Chewie(controller: _chewieController!),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: _toggleControls,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AssetEntityImage(
                          currentAsset,
                          isOriginal: false,
                          fit: BoxFit.contain,
                        ),
                        const CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
                  ),
                );
              }

              // Image
              return _ZoomableOriginalImage(
                key: ValueKey(currentAsset.id),
                asset: currentAsset,
                onTap: _toggleControls,
                onZoomChanged: index == _currentIndex
                    ? _onImageZoomChanged
                    : null,
              );
            },
          ),

          // 2. Top Bar (AppBar equivalent)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _showControls ? Offset.zero : const Offset(0, -1.1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _showControls ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.66),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 10, 34),
                      child: Row(
                        children: [
                          _viewerCircleButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat.yMMMd().format(
                                    asset.createDateTime,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormat.jm().format(asset.createDateTime),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _viewerCircleButton(
                            icon: Icons.info_outline_rounded,
                            tooltip: 'Media information',
                            onPressed: () => _showInfoDialog(asset),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Bar Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _showControls ? Offset.zero : const Offset(0, 1.1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _showControls ? 1 : 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _backupStatusPill(syncStatus),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF17242C,
                          ).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              Icons.share_outlined,
                              'Share',
                              () => _handleShare(asset),
                            ),
                            _buildActionButton(
                              Icons.label_outline_rounded,
                              'Label',
                              () => _handleLabel(asset),
                            ),
                            _buildActionButton(
                              _vaulting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.lock_outline_rounded,
                              _vaulting ? 'Vaulting' : 'Vault',
                              _vaulting ? null : () => _handleVault(asset),
                            ),
                            _buildActionButton(
                              Icons.delete_outline_rounded,
                              'Delete',
                              () => _confirmDelete(asset),
                              color: AppTheme.error,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color color = Colors.white,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.86),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewerCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.34),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }

  Widget _backupStatusPill(int? status) {
    final (label, icon, color) = switch (status) {
      final value when value == FileSyncStatus.synced.dbValue => (
        'Backed up',
        Icons.cloud_done_rounded,
        AppTheme.success,
      ),
      final value when value == FileSyncStatus.uploading.dbValue => (
        'Uploading',
        Icons.cloud_upload_rounded,
        AppTheme.primary,
      ),
      final value when value == FileSyncStatus.failed.dbValue => (
        'Backup failed',
        Icons.cloud_off_rounded,
        AppTheme.error,
      ),
      _ => ('Waiting to back up', Icons.cloud_queue_rounded, AppTheme.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfoDialog(AssetEntity asset) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => FutureBuilder<_MediaDetails>(
        future: _loadMediaDetails(asset),
        builder: (context, snapshot) {
          final details = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const TeleVaultIconBadge(icon: Icons.info_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Media details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _detailRow(
                    Icons.insert_drive_file_outlined,
                    'Name',
                    details?.name ?? 'Unknown',
                  ),
                  _detailRow(
                    asset.type == AssetType.video
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                    'Type',
                    asset.type == AssetType.video ? 'Video' : 'Photo',
                  ),
                  _detailRow(
                    Icons.aspect_ratio_rounded,
                    'Resolution',
                    '${asset.width} × ${asset.height}',
                  ),
                  _detailRow(
                    Icons.data_usage_rounded,
                    'File size',
                    details?.formattedSize ?? 'Unavailable',
                  ),
                  if (asset.type == AssetType.video)
                    _detailRow(
                      Icons.timer_outlined,
                      'Duration',
                      _formatMediaDuration(asset.videoDuration),
                    ),
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Created',
                    DateFormat.yMMMd().add_jm().format(asset.createDateTime),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.inkMuted, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<_MediaDetails> _loadMediaDetails(AssetEntity asset) async {
    final file = await asset.file;
    final bytes = file == null ? null : await file.length();
    return _MediaDetails(
      name: asset.title?.trim().isNotEmpty == true
          ? asset.title!.trim()
          : 'Untitled media',
      formattedSize: bytes == null ? 'Unavailable' : _formatBytes(bytes),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    final megabytes = kilobytes / 1024;
    if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }

  String _formatMediaDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleShare(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        await share_plus.Share.shareXFiles([
          share_plus.XFile(file.path),
        ], text: 'Shared from TeleVault');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<void> _handleLabel(AssetEntity asset) async {
    final notifier = ref.read(libraryControllerProvider.notifier);
    final labels = await notifier.getLabels();
    if (!mounted) return;

    final labelId = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Label this item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const TeleVaultIconBadge(
                  icon: Icons.add_rounded,
                  color: AppTheme.primary,
                ),
                title: const Text('Create a label'),
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
              if (labels.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: labels.length,
                    itemBuilder: (context, index) {
                      final label = labels[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 10,
                          backgroundColor: _labelColor(label.colorHex),
                        ),
                        title: Text(label.name),
                        onTap: () => Navigator.pop(sheetContext, label.id),
                      );
                    },
                  ),
                ),
              TextButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 0),
                icon: const Icon(Icons.label_off_outlined),
                label: const Text('Remove label'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || labelId == null) return;
    int? resolvedLabelId = labelId;
    if (labelId == -1) {
      final label = await showLabelEditorDialog(context);
      if (label == null || !mounted) return;
      resolvedLabelId = await notifier.createLabel(
        name: label.name,
        colorHex: label.colorHex,
      );
      if (resolvedLabelId == null) return;
    } else if (labelId == 0) {
      resolvedLabelId = null;
    }

    final updated = await notifier.applyLabelToAsset(asset, resolvedLabelId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated > 0
              ? resolvedLabelId == null
                    ? 'Label removed'
                    : 'Label applied'
              : 'Label could not be changed',
        ),
      ),
    );
  }

  Color _labelColor(String value) {
    final normalized = value.replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    return AppTheme.primary;
  }

  Future<void> _handleVault(AssetEntity asset) async {
    String? unlockedSecret;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pinContext) => VaultPinScreen(
          mode: VaultPinMode.unlock,
          onUnlock: (secret) {
            unlockedSecret = secret;
            Navigator.pop(pinContext);
          },
        ),
      ),
    );

    if (unlockedSecret == null || unlockedSecret!.isEmpty || !mounted) return;

    final recoveryService = ref.read(vaultRecoveryServiceProvider);
    if (!await recoveryService.isRecoveryKeyConfirmed()) {
      if (!mounted) return;
      final ready = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const VaultRecoveryKeyScreen()),
      );
      if (ready != true || !mounted) return;
    }

    setState(() => _vaulting = true);
    try {
      final moved = await ref
          .read(libraryControllerProvider.notifier)
          .moveSingleAssetToVault(asset, pin: unlockedSecret!);
      if (!mounted) return;

      if (moved > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved to encrypted Vault')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not move this item to Vault')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vault failed: $e')));
    } finally {
      if (mounted) setState(() => _vaulting = false);
    }
  }

  Future<void> _confirmDelete(AssetEntity asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
          'Are you sure you want to delete this photo from your device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(libraryControllerProvider.notifier);
      try {
        ref
            .read(appLockControllerProvider.notifier)
            .allowExternalSystemPrompt();
        final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
        if (!mounted) return;

        if (deleted.isNotEmpty) {
          await notifier.markAssetsDeletedLocally(deleted.toSet());
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Photo deleted')));
          Navigator.pop(context); // Go back to library
        } else {
          await notifier.refreshCurrentView();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delete cancelled or nothing removed'),
            ),
          );
        }
      } on PlatformException catch (e) {
        await notifier.refreshCurrentView();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ??
                    'Could not delete. The item may already be missing or not stored locally.',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        await notifier.refreshCurrentView();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }
}

class _ZoomableOriginalImage extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomableOriginalImage({
    super.key,
    required this.asset,
    required this.onTap,
    this.onZoomChanged,
  });

  @override
  State<_ZoomableOriginalImage> createState() => _ZoomableOriginalImageState();
}

class _ZoomableOriginalImageState extends State<_ZoomableOriginalImage> {
  final TransformationController _transformationController =
      TransformationController();
  late Future<File?> _originalFile;
  Offset _doubleTapPosition = Offset.zero;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _originalFile = widget.asset.file;
    _transformationController.addListener(_reportZoomState);
  }

  @override
  void didUpdateWidget(covariant _ZoomableOriginalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _originalFile = widget.asset.file;
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_reportZoomState);
    _transformationController.dispose();
    super.dispose();
  }

  void _reportZoomState() {
    final isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (_isZoomed == isZoomed) return;
    _isZoomed = isZoomed;
    widget.onZoomChanged?.call(isZoomed);
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    const scale = 2.5;
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(
        _doubleTapPosition.dx * (1 - scale),
        _doubleTapPosition.dy * (1 - scale),
        0,
      );
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            _doubleTapPosition = details.localPosition;
          },
          onTap: widget.onTap,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformationController,
            alignment: Alignment.center,
            minScale: 1,
            maxScale: 6,
            panEnabled: _isZoomed,
            boundaryMargin: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(constraints),
                  FutureBuilder<File?>(
                    future: _originalFile,
                    builder: (context, snapshot) {
                      final file = snapshot.data;
                      if (file == null) return const SizedBox.shrink();
                      return Image.file(
                        file,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(BoxConstraints constraints) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final width = (constraints.maxWidth * pixelRatio)
        .round()
        .clamp(1, 4096)
        .toInt();
    final height = (constraints.maxHeight * pixelRatio)
        .round()
        .clamp(1, 4096)
        .toInt();

    return AssetEntityImage(
      widget.asset,
      isOriginal: false,
      thumbnailSize: ThumbnailSize(width, height),
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
    );
  }
}

class _MediaDetails {
  final String name;
  final String formattedSize;

  const _MediaDetails({required this.name, required this.formattedSize});
}
