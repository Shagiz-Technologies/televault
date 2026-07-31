import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/telegram_service.dart';
import '../../backup/presentation/metadata_backup_screen.dart';
import '../../buckets/services/bucket_service.dart';
import '../../buckets/presentation/bucket_selector_sheet.dart';
import '../../sync/presentation/sync_dashboard_screen.dart';
import '../../vault/presentation/vault_pin_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_screen.dart';
import 'release_log_screen.dart';
import 'app_lock_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'sync_preferences_screen.dart';
import '../../../core/database/app_database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active bucket for the "Current Bucket" tile
    final bucketFuture = ref.watch(bucketServiceProvider).getActiveBucket();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppResponsive.pagePaddingWithBottomSafe(
          context,
          horizontal: 16,
          top: 16,
          bottomExtra: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Card
            _buildProfileCard(context),
            const Gap(24),

            // 2. Backup Storage Section
            const Text(
              "Backup Storage",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Gap(12),
            FutureBuilder(
              future: bucketFuture,
              builder: (context, snapshot) {
                final bucketName = snapshot.data?.name ?? "No Bucket Selected";
                return _buildSectionTile(
                  context,
                  icon: Icons.cloud_outlined,
                  title: "Current Bucket",
                  subtitle: bucketName,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const BucketSelectorSheet(),
                    ).then((_) {
                      // Force rebuild? relying on riverpod provider invalidation usually better
                      // Ideally SettingsScreen listens to a Stream or StateNotifier.
                    });
                  },
                );
              },
            ),
            const Gap(24),
            const Text(
              "Sync & Recovery",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Gap(12),
            _buildSectionTile(
              context,
              icon: Icons.dashboard_customize_outlined,
              title: "Sync Dashboard",
              subtitle: "Queue status, sync now, retry failed",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyncDashboardScreen(),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.tune,
              title: "Sync Preferences",
              subtitle: "Albums, media types, size limits",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyncPreferencesScreen(),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.file_copy_outlined,
              title: "Metadata Backup",
              subtitle: "Export/import encrypted .tvmeta",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MetadataBackupScreen(),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.analytics_outlined,
              title: "Diagnostics",
              subtitle: "Operational counters only",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                );
              },
            ),

            const Gap(24),

            // 3. Preferences Section
            const Text(
              "Preferences",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Gap(12),
            _buildSectionTile(
              context,
              icon: Icons.lock,
              title: "Set Vault PIN",
              subtitle: "Protect your vaulted files",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const VaultPinScreen(mode: VaultPinMode.set),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.lock_clock_outlined,
              title: "App Lock",
              subtitle: "PIN, password, or biometric",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppLockSettingsScreen(),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.shield_outlined,
              title: "Privacy Policy",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.new_releases_outlined,
              title: "Release Log",
              subtitle: "Features included in each release",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReleaseLogScreen()),
                );
              },
            ),
            const Gap(8),
            _buildSectionTile(
              context,
              icon: Icons.info_outline,
              title: "About TeleVault",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const Gap(12),
          ],
        ),
      ),
    );
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

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary,
                        backgroundImage: photoPath != null
                            ? FileImage(io.File(photoPath))
                            : null,
                        onBackgroundImageError: photoPath != null
                            ? (_, _) {
                                // Handle error
                              }
                            : null,
                        child: photoPath == null
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FutureBuilder<Map<String, String>>(
                              future: storageFuture,
                              builder: (context, storeSnap) {
                                final stats = storeSnap.data?['stats'] ?? '';
                                if (stats.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  stats,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),
                  FutureBuilder<Map<String, String>>(
                    future: storageFuture,
                    builder: (context, storeSnap) {
                      final storage =
                          storeSnap.data?['storage'] ?? 'Calculating...';
                      final progress =
                          double.tryParse(storeSnap.data?['progress'] ?? '0') ??
                          0.0;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Storage Used",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                storage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[800],
                            color: AppTheme.primary,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    },
                  ),
                  const Gap(16),
                  _buildSectionTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    onTap: () => _handleLogout(context, ref, telegramService),
                  ),
                  const Gap(32),
                  // App Info
                  const Center(
                    child: Text(
                      "TeleVault",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
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

  Future<void> _handleLogout(
    BuildContext context,
    WidgetRef ref,
    TelegramService telegram,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Logout"),
        content: const Text(
          "Are you sure you want to logout? This will terminate your Telegram session on this device.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await telegram.sendAndWait({'@type': 'logOut'});
        // The AuthController will catch the authStateLoggingOut/Closed and redirect to login
      } catch (e) {
        debugPrint('Error during logout: $e');
        // Fallback: manually reset?
      }
    }
  }

  Stream<Map<String, dynamic>> _profileStream(TelegramService telegram) async* {
    int? myUserId;

    try {
      final me = await telegram.request({'@type': 'getMe'});
      myUserId = _extractInt(me['id']);
      yield await _parseUser(telegram, me);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
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
    final tdlibPath = p.join(dir.path, 'tdlib', rawPath);
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
    } catch (e) {
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

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: AppTheme.primary))
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
