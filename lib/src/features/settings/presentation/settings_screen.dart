import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_runtime_environment.dart';
import '../../../core/services/review_environment_exit_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_service.dart';
import '../../auth/auth_controller.dart';
import '../../backup/presentation/metadata_backup_screen.dart';
import '../../buckets/services/bucket_service.dart';
import '../../buckets/presentation/bucket_selector_sheet.dart';
import '../../sync/presentation/sync_dashboard_screen.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import '../../vault/presentation/vault_recovery_key_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_screen.dart';
import 'release_log_screen.dart';
import 'app_lock_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'media_permission_diagnostics_screen.dart';
import 'sync_preferences_screen.dart';
import '../../../core/database/app_database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBucket = ref.watch(activeBucketProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: SingleChildScrollView(
          padding: AppResponsive.pagePaddingWithBottomSafe(
            context,
            horizontal: 16,
            top: 8,
            bottomExtra: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(context),
              if (AppRuntimeEnvironment.isPlayStoreReview &&
                  !AppRuntimeEnvironment.compileTimeReviewEnabled) ...[
                const Gap(16),
                _settingsGroup([
                  _buildSectionTile(
                    context,
                    icon: Icons.restart_alt_rounded,
                    title: 'Return to normal Telegram',
                    subtitle: 'Clear only Test Environment data',
                    onTap: () => _confirmReturnToProduction(context, ref),
                  ),
                ]),
              ],
              const Gap(20),
              const TeleVaultSectionTitle(title: 'Backup'),
              const Gap(7),
              _settingsGroup([
                _buildSectionTile(
                  context,
                  icon: Icons.cloud_outlined,
                  title: 'Backup spaces',
                  subtitle: activeBucket.when(
                    loading: () => 'Loading...',
                    error: (_, _) => 'Unable to load',
                    data: (bucket) => bucket?.name ?? 'No active space',
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const BucketSelectorSheet(),
                    );
                  },
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.donut_large_rounded,
                  title: 'Backup status',
                  subtitle: 'Live progress, queue, and retries',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SyncDashboardScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.perm_media_outlined,
                  title: 'Media access',
                  subtitle: 'Gallery scope and accessible item count',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MediaPermissionDiagnosticsScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.tune_rounded,
                  title: 'Sync preferences',
                  subtitle: 'Media, albums, quality, and limits',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SyncPreferencesScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.storage_outlined,
                  title: 'Metadata backup',
                  subtitle: 'Recovery and Safe Uninstall',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MetadataBackupScreen(),
                    ),
                  ),
                ),
              ]),
              const Gap(20),
              const TeleVaultSectionTitle(title: 'Security'),
              const Gap(7),
              _settingsGroup([
                _buildSectionTile(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Vault security',
                  subtitle: 'Password, PIN, or phone security',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const VaultPinScreen(mode: VaultPinMode.set),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.key_rounded,
                  title: 'Vault recovery key',
                  subtitle: 'Export or import your portable recovery key',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (unlockContext) => VaultPinScreen(
                        mode: VaultPinMode.unlock,
                        onUnlock: (_) {
                          Navigator.pop(unlockContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VaultRecoveryKeyScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.phonelink_lock_rounded,
                  title: 'App lock',
                  subtitle: 'Phone security or TeleVault password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppLockSettingsScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.visibility_outlined,
                  title: 'Privacy & transparency',
                  subtitle: 'What leaves your device and why',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
              ]),
              const Gap(20),
              const TeleVaultSectionTitle(title: 'TeleVault'),
              const Gap(7),
              _settingsGroup([
                _buildSectionTile(
                  context,
                  icon: Icons.monitor_heart_outlined,
                  title: 'Diagnostics',
                  subtitle: 'Local operational details',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.new_releases_outlined,
                  title: "What's new",
                  subtitle: 'Features in each release',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReleaseLogScreen()),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'About TeleVault',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReturnToProduction(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Return to normal Telegram?'),
        content: const Text(
          'Only Test Environment sessions, settings, metadata, Vault files, cache, and background work will be removed. Normal TeleVault data stays unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Return to normal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(reviewEnvironmentExitServiceProvider).returnToProduction();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The Test Environment could not be cleared. Normal Telegram data was not opened.',
          ),
        ),
      );
    }
  }

  Widget _buildProfileCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final telegramService = ref.watch(telegramServiceProvider);
        final db = ref.watch(databaseProvider);

        return StreamBuilder<Map<String, dynamic>>(
          stream: _profileStream(telegramService),
          builder: (context, snapshot) {
            // Initial load or stream update
            final data = snapshot.data ?? {};
            // If no data yet, try to fetch specific manually or show loader?
            // Better: Mix Future and Stream.
            // Actually, helper function can yield initial then listen.

            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              // Trigger initial fetch if stream is empty?
              // Let's make _profileStream yield current user first.
            }

            final userName = data['name'] as String? ?? 'User';
            final photoPath = data['photoPath'] as String?;

            // Storage Sync Stream (separate)
            final storageFuture = _getStorageStats(db);

            return TeleVaultCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: photoPath != null
                        ? FileImage(io.File(photoPath))
                        : null,
                    onBackgroundImageError: photoPath != null
                        ? (_, _) {}
                        : null,
                    child: photoPath == null
                        ? Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const Gap(13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Gap(3),
                        FutureBuilder<Map<String, String>>(
                          future: storageFuture,
                          builder: (context, storeSnap) {
                            final stats = storeSnap.data?['stats'] ?? '';
                            return Text(
                              stats.isEmpty ? 'Telegram connected' : stats,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.inkMuted),
                            );
                          },
                        ),
                        const Gap(6),
                        const TeleVaultStatusPill(
                          label: 'Telegram connected',
                          icon: Icons.circle,
                          color: AppTheme.success,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: () => _handleLogout(context, ref),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    var preserveVaultFiles = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Log out of Telegram?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deleted from this device: TeleVault buckets and media metadata, labels, settings, diagnostics, upload/retry state, decrypted temporary files, and the TDLib session/cache.',
                ),
                const Gap(12),
                const Text(
                  'Your private Telegram channels, uploaded media, and metadata messages remain in Telegram.',
                ),
                const Gap(12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: preserveVaultFiles,
                  onChanged: (value) =>
                      setDialogState(() => preserveVaultFiles = value ?? false),
                  title: const Text('Keep encrypted Vault files locally'),
                  subtitle: const Text(
                    'They remain unreadable without the TeleVault Recovery Key. Decrypted temporary files are always deleted.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete local data and log out',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref
          .read(authControllerProvider.notifier)
          .logout(preserveEncryptedVaultFiles: preserveVaultFiles);
    }
  }

  Stream<Map<String, dynamic>> _profileStream(TelegramService telegram) async* {
    int? myUserId;

    try {
      final me = await telegram.request({'@type': 'getMe'});
      myUserId = _extractInt(me['id']);
      yield await _parseUser(telegram, me);
    } catch (_) {
      debugPrint('Unable to refresh the Telegram profile.');
      return;
    }

    await for (final update in telegram.updates) {
      if (update['@type'] == 'updateUser') {
        final user = update['user'] as Map<String, dynamic>?;
        if (user == null) continue;

        final updateUserId = _extractInt(user['id']);
        if (myUserId != null && updateUserId != myUserId) {
          continue;
        }

        yield await _parseUser(telegram, user);
      }
    }
  }

  Future<Map<String, dynamic>> _parseUser(
    TelegramService telegram,
    Map<String, dynamic> user,
  ) async {
    final result = <String, dynamic>{};
    final firstName = (user['first_name'] as String?)?.trim() ?? '';
    final lastName = (user['last_name'] as String?)?.trim() ?? '';
    final username = _extractUsername(user);

    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) {
      result['name'] = fullName;
    } else if (username.isNotEmpty) {
      result['name'] = '@$username';
    } else {
      result['name'] = 'Telegram User';
    }

    final photoPath = await _resolveProfilePhotoPath(telegram, user);
    if (photoPath != null) {
      result['photoPath'] = photoPath;
    }
    return result;
  }

  Future<String?> _resolveProfilePhotoPath(
    TelegramService telegram,
    Map<String, dynamic> user,
  ) async {
    final profilePhoto = user['profile_photo'] as Map<String, dynamic>?;
    final smallFile = profilePhoto?['small'] as Map<String, dynamic>?;
    final fileId = _extractInt(smallFile?['id']);
    if (fileId == null) return null;

    try {
      var file = await telegram.request({
        '@type': 'getFile',
        'file_id': fileId,
      }, timeout: const Duration(seconds: 10));

      String? path = file['local']?['path']?.toString();
      final downloaded = file['local']?['is_downloading_completed'] == true;
      final normalized = await _normalizeTelegramPath(path);
      final exists = normalized != null && io.File(normalized).existsSync();
      if (downloaded && exists) {
        return normalized;
      }

      file = await telegram.request({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 1,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      }, timeout: const Duration(seconds: 30));

      path = file['local']?['path']?.toString();
      final normalizedPath = await _normalizeTelegramPath(path);
      if (normalizedPath != null && io.File(normalizedPath).existsSync()) {
        return normalizedPath;
      }
    } catch (_) {}

    return null;
  }

  String _extractUsername(Map<String, dynamic> user) {
    final direct = (user['username'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final usernames = user['usernames'] as Map<String, dynamic>?;
    final active = usernames?['active_usernames'] as List<dynamic>?;
    if (active != null && active.isNotEmpty) {
      final first = active.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    return '';
  }

  Future<String?> _normalizeTelegramPath(String? rawPath) async {
    if (rawPath == null || rawPath.isEmpty) return null;

    final asGiven = io.File(rawPath);
    if (asGiven.existsSync()) return rawPath;

    if (p.isAbsolute(rawPath)) return null;

    final dir = await getApplicationDocumentsDirectory();
    final tdlibPath = p.join(
      dir.path,
      AppRuntimeEnvironment.tdlibDirectoryName,
      rawPath,
    );
    if (io.File(tdlibPath).existsSync()) return tdlibPath;

    return null;
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<Map<String, String>> _getStorageStats(AppDatabase db) async {
    try {
      final allFiles = await db.select(db.files).get();
      final files = allFiles.where((f) => f.status == 2).toList();

      if (files.isEmpty) {
        return {
          'storage': '0 B',
          'stats': '0 photos | 0 videos',
          'progress': '0',
        };
      } else {
        final totalBytes = files.fold<int>(0, (sum, f) => sum + f.size);
        final images = files.where((f) => _isImage(f.localPath)).length;
        final videos = files.where((f) => _isVideo(f.localPath)).length;
        final totalTracked = allFiles.where((f) => f.status != 4).length;
        final progress = totalTracked == 0 ? 0.0 : files.length / totalTracked;
        return {
          'storage': _formatBytes(totalBytes),
          'stats': '$images photos | $videos videos',
          'progress': progress.toString(),
        };
      }
    } catch (_) {
      return {'storage': '0 B', 'stats': 'Error', 'progress': '0'};
    }
  }

  bool _isImage(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.heic');
  }

  bool _isVideo(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _settingsGroup(List<Widget> children) {
    return TeleVaultCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return TeleVaultSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
