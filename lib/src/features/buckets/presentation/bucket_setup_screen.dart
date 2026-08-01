import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/secure_text_dialog.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../backup/services/auto_metadata_backup_service.dart';
import '../../backup/services/metadata_backup_service.dart';
import '../../backup/services/safe_uninstall_backup_service.dart';
import '../../library/repositories/gallery_repository.dart';
import '../../settings/services/settings_service.dart';
import 'bucket_configuration_sheet.dart';
import '../services/bucket_service.dart';
import '../../sync/services/sync_initializer.dart';
import '../../vault/presentation/vault_recovery_key_screen.dart';
import '../../vault/services/vault_recovery_service.dart';

class BucketSetupScreen extends ConsumerStatefulWidget {
  const BucketSetupScreen({super.key});

  @override
  ConsumerState<BucketSetupScreen> createState() => _BucketSetupScreenState();
}

class _BucketSetupScreenState extends ConsumerState<BucketSetupScreen> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isRestoring = false;
  String? _restoreStatus;
  bool _loadingBucketCount = true;
  int _bucketCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBucketCount();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBucketCount() async {
    final count = await ref.read(bucketServiceProvider).getBucketCount();
    if (!mounted) return;
    setState(() {
      _bucketCount = count;
      _loadingBucketCount = false;
    });
    if (count == 0) {
      unawaited(_restoreAutomaticMetadataBackup());
    }
  }

  Future<void> _createBucket() async {
    final bucketName = _nameCtrl.text.trim();
    if (bucketName.isEmpty) return;

    // Check for duplicate bucket names
    final bucketService = ref.read(bucketServiceProvider);
    final existingBuckets = await bucketService.getBuckets();
    if (existingBuckets.length >= BucketService.maxFreeBuckets) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can create up to ${BucketService.maxFreeBuckets} buckets in this version.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    if (existingBuckets.any(
      (b) => b.name.toLowerCase() == bucketName.toLowerCase(),
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Bucket name already exists. Please choose a different name.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);
      final settings = ref.read(settingsServiceProvider);
      final inheritedPreferences = existingBuckets.isEmpty
          ? await settings.getSyncPreferences()
          : (await settings.getSyncPreferences(
              bucketId: existingBuckets.first.id,
            )).copyWith(autoBackupEnabled: false);
      List<AssetPathEntity> albums;
      try {
        albums = await ref.read(galleryRepositoryProvider).getAlbums();
      } catch (_) {
        debugPrint('Album choices are unavailable during bucket setup.');
        albums = const [];
      }
      final isTelegramPremium = await _loadTelegramPremiumStatus();
      if (!mounted) return;
      setState(() => _isLoading = false);

      final configuration = await showBucketConfigurationSheet(
        context: context,
        bucketName: bucketName,
        initialPreferences: inheritedPreferences,
        albums: albums,
        isTelegramPremium: isTelegramPremium,
      );
      if (configuration == null || !mounted) return;

      setState(() => _isLoading = true);
      final createdBucketId = await bucketService.createBucket(
        bucketName,
        "TeleVault Storage Bucket for $bucketName",
        allowedTypes: configuration.allowedTypes,
        preferences: configuration.preferences,
      );
      await ref.read(syncInitializerProvider).ensureStarted();
      final isFirstBucket = existingBuckets.isEmpty;
      var metadataProtectionReady = await ref
          .read(vaultRecoveryServiceProvider)
          .isRecoveryKeyConfirmed();
      if (isFirstBucket && !metadataProtectionReady && mounted) {
        metadataProtectionReady =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const VaultRecoveryKeyScreen()),
            ) ??
            false;
      }
      if (metadataProtectionReady) {
        unawaited(
          ref
              .read(autoMetadataBackupServiceProvider)
              .backupNow(reason: 'bucket_created')
              .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              configuration.preferences.autoBackupEnabled
                  ? 'Storage bucket created. Auto-sync is enabled.'
                  : 'Storage bucket created. Auto-sync is off.',
            ),
          ),
        );
        if (isFirstBucket) {
          ref.read(bucketPresenceProvider.notifier).setHasBuckets(true);
        } else {
          await _loadBucketCount();
          if (mounted) {
            Navigator.of(context).pop(createdBucketId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitReached = _bucketCount >= BucketService.maxFreeBuckets;
    return Scaffold(
      body: TeleVaultPage(
        child: ResponsivePage(
          maxWidth: 540,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TeleVaultLogoMark(
                size: AppResponsive.iconSize(context, regular: 92, compact: 56),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

              Gap(AppResponsive.gap(context, 30, compact: 12)),

              Text(
                _bucketCount == 0
                    ? 'Your first backup space'
                    : 'New backup space',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ).animate().fadeIn().slideY(begin: 0.3, end: 0),

              Gap(AppResponsive.gap(context, 10, compact: 6)),

              Text(
                _bucketCount == 0
                    ? 'Choose a friendly name. TeleVault will create a private Telegram channel and let you review every backup preference first.'
                    : 'Give this space its own media, quality, album, and auto-backup rules.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ).animate().fadeIn().slideY(begin: 0.3, end: 0, delay: 100.ms),

              Gap(AppResponsive.gap(context, 40, compact: 16)),

              if (!_loadingBucketCount)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    limitReached
                        ? "Bucket limit reached: ${BucketService.maxFreeBuckets}/${BucketService.maxFreeBuckets}. More buckets will be available with subscriptions later."
                        : 'Space ${_bucketCount + 1} of ${BucketService.maxFreeBuckets} - You will review media, quality, and auto-backup next.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: limitReached
                          ? AppTheme.error
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),

              if (!_loadingBucketCount)
                Gap(AppResponsive.gap(context, 16, compact: 10)),

              TextField(
                controller: _nameCtrl,
                enabled: !limitReached,
                decoration: const InputDecoration(
                  labelText: 'Space name',
                  hintText: 'Everyday, Photos, Videos',
                  prefixIcon: Icon(Icons.folder_shared_rounded),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 200.ms),

              Gap(AppResponsive.gap(context, 30, compact: 14)),

              SizedBox(
                width: double.infinity,
                height: AppResponsive.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: _isLoading || limitReached ? null : _createBucket,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 300.ms),

              if (!_loadingBucketCount && _bucketCount == 0) ...[
                Gap(AppResponsive.gap(context, 14, compact: 8)),
                TextButton.icon(
                  onPressed: _isLoading || _isRestoring
                      ? null
                      : _restoreSafeUninstallBackup,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_rounded),
                  label: Text(
                    _isRestoring
                        ? 'Looking for previous backup...'
                        : 'Restore older passphrase backup',
                  ),
                ),
                if (_restoreStatus != null) ...[
                  Gap(AppResponsive.gap(context, 10, compact: 8)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: Text(
                      _restoreStatus!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _loadTelegramPremiumStatus() async {
    final reliability = ref.read(telegramReliabilityServiceProvider);
    await reliability.refreshAccountCapabilities();
    return reliability.isPremium;
  }

  Future<void> _restoreAutomaticMetadataBackup({
    bool allowRecoveryPrompt = true,
  }) async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _restoreStatus = 'Checking Telegram for a TeleVault metadata channel...';
    });

    try {
      final result = await ref
          .read(autoMetadataBackupServiceProvider)
          .restoreLatestIfAvailable(
            onStatus: (status) {
              if (!mounted) return;
              setState(() => _restoreStatus = status);
            },
          );

      if (!mounted) return;
      if (result == null) {
        setState(() {
          _restoreStatus = null;
        });
        return;
      }

      setState(() {
        _restoreStatus =
            'Previous TeleVault metadata restored from message ${result.messageId}.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Previous TeleVault metadata restored')),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(ref.read(syncInitializerProvider).ensureStarted());
        ref.read(bucketPresenceProvider.notifier).setHasBuckets(true);
      });
    } on MetadataBackupException catch (error) {
      if (allowRecoveryPrompt &&
          error.code == MetadataBackupErrorCode.recoveryKeyRequired &&
          mounted) {
        final ready = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => VaultRecoveryKeyScreen(
              requireExistingKey: error.requiresExistingRecoveryKey,
            ),
          ),
        );
        if (ready == true && mounted) {
          setState(() => _isRestoring = false);
          await _restoreAutomaticMetadataBackup(allowRecoveryPrompt: false);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'Automatic metadata restore did not finish. ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'Automatic metadata restore did not finish. You can create a new bucket or restore an older passphrase backup.';
      });
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _restoreSafeUninstallBackup() async {
    final passphrase = await _promptRestorePassphrase();
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() {
      _isRestoring = true;
      _restoreStatus = 'Checking Telegram for Safe Uninstall metadata...';
    });

    try {
      final result = await ref
          .read(safeUninstallBackupServiceProvider)
          .restoreLatestFromTelegram(
            passphrase: passphrase,
            onStatus: (status) {
              if (!mounted) return;
              setState(() => _restoreStatus = status);
            },
          );

      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'Previous metadata restored from message ${result.messageId}. TeleVault will resume from your restored buckets.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe Uninstall metadata restored')),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(ref.read(syncInitializerProvider).ensureStarted());
        ref.read(bucketPresenceProvider.notifier).setHasBuckets(true);
      });
    } on MetadataBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'No previous Safe Uninstall metadata was restored. ${error.message}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Safe Uninstall metadata was restored'),
        ),
      );
    } on SafeUninstallBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'No previous Safe Uninstall metadata was restored. ${error.message}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Safe Uninstall metadata was restored'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'No previous Safe Uninstall metadata was restored. Check your connection or create a new bucket to start over.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Safe Uninstall metadata was restored'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<String?> _promptRestorePassphrase() async {
    return showSecureTextDialog(
      context,
      title: 'Restore Safe Uninstall backup',
      description:
          'Enter the passphrase you used during Safe Uninstall. TeleVault will search your Telegram chats for the latest metadata package.',
      fieldLabel: 'Passphrase',
      actionLabel: 'Restore',
      minLength: 8,
      minLengthMessage: 'Use at least 8 characters.',
    );
  }
}
