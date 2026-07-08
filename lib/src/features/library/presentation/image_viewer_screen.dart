import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for PlatformException
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../settings/services/app_lock_controller.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import 'library_controller.dart';

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
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _initMedia();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.assets[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Media Page View (Image or Video)
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
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
                    return Center(
                      child: Chewie(controller: _chewieController!),
                    );
                  }
                  return Center(
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
                  );
                }

                // Image
                return Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: AssetEntityImage(
                      currentAsset,
                      isOriginal: true,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Top Bar (AppBar equivalent)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.yMMMd().add_jm().format(
                              asset.createDateTime,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            DateFormat.Hm().format(asset.createDateTime),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Bar Buttons
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(Icons.share, "Share", () async {
                      await _handleShare(asset);
                    }),
                    _buildActionButton(
                      _vaulting ? Icons.hourglass_top : Icons.lock_outline,
                      _vaulting ? "Vaulting" : "Vault",
                      _vaulting ? null : () => _handleVault(asset),
                    ),
                    _buildActionButton(Icons.info_outline, "Info", () {
                      _showInfoDialog(asset);
                    }),
                    _buildActionButton(
                      Icons.delete_outline,
                      "Delete",
                      () async {
                        await _confirmDelete(asset);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  void _showInfoDialog(AssetEntity asset) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Metadata"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Filename: ${asset.title}"),
            Text("Size: ${asset.width}x${asset.height}"),
            Text("Date: ${asset.createDateTime}"),
            // Add file size if async fetch possible
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
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

  Future<void> _handleVault(AssetEntity asset) async {
    String? unlockedSecret;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pinContext) => VaultPinScreen(
          mode: VaultPinMode.unlock,
          forceSecretEntry: true,
          onUnlock: (secret) {
            unlockedSecret = secret;
            Navigator.pop(pinContext);
          },
        ),
      ),
    );

    if (unlockedSecret == null || unlockedSecret!.isEmpty || !mounted) return;

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
