import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/secure_text_dialog.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';
import '../../backup/services/auto_metadata_backup_service.dart';
import '../../backup/services/safe_uninstall_backup_service.dart';
import '../services/bucket_service.dart';
import '../../sync/services/sync_initializer.dart';

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
  final Set<BucketMediaType> _selectedTypes = {
    BucketMediaType.photo,
    BucketMediaType.video,
  };

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
    if (_nameCtrl.text.isEmpty) return;

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
      (b) => b.name.toLowerCase() == _nameCtrl.text.toLowerCase(),
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

    setState(() => _isLoading = true);

    try {
      await bucketService.createBucket(
        _nameCtrl.text,
        "TeleVault Storage Bucket for ${_nameCtrl.text}",
        allowedTypes: _selectedTypes,
      );
      await ref.read(syncInitializerProvider).ensureStarted();
      unawaited(
        ref
            .read(autoMetadataBackupServiceProvider)
            .backupNow(reason: 'bucket_created')
            .then<void>(
              (_) {},
              onError: (Object e, StackTrace stackTrace) {
                debugPrint('Initial metadata backup failed: $e');
              },
            ),
      );

      if (mounted) {
        final isFirstBucket = existingBuckets.isEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFirstBucket
                  ? 'Storage bucket created. Auto-sync is enabled.'
                  : 'Storage bucket created. It inherited settings, with auto-sync off.',
            ),
          ),
        );
        if (isFirstBucket) {
          ref.read(bucketPresenceProvider.notifier).setHasBuckets(true);
        } else {
          await _loadBucketCount();
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
      body: ResponsivePage(
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
              "Create Your Storage",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn().slideY(begin: 0.3, end: 0),

            Gap(AppResponsive.gap(context, 10, compact: 6)),

            Text(
              _bucketCount == 0
                  ? "To start backing up files, we need to create a private Telegram channel (Bucket) to store them."
                  : "Create another private Telegram bucket with its own album, quality, and auto-sync settings.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ).animate().fadeIn().slideY(begin: 0.3, end: 0, delay: 100.ms),

            Gap(AppResponsive.gap(context, 40, compact: 16)),

            if (!_loadingBucketCount)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  limitReached
                      ? "Bucket limit reached: ${BucketService.maxFreeBuckets}/${BucketService.maxFreeBuckets}. More buckets will be available with subscriptions later."
                      : "Bucket ${_bucketCount + 1} of ${BucketService.maxFreeBuckets}. New buckets inherit the main bucket settings, but auto-sync starts off.",
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
                labelText: "Bucket Name",
                hintText: "e.g., My Vault, Personal Backup",
                prefixIcon: Icon(Icons.folder_shared_rounded),
              ),
            ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 200.ms),

            Gap(AppResponsive.gap(context, 16, compact: 10)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Allowed Media Types",
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Gap(AppResponsive.gap(context, 8, compact: 6)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip(BucketMediaType.photo, enabled: true),
                _typeChip(BucketMediaType.video, enabled: true),
                _typeChip(BucketMediaType.document, enabled: false),
                _typeChip(BucketMediaType.app, enabled: false),
                _typeChip(BucketMediaType.other, enabled: false),
              ],
            ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 220.ms),

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
                    : const Text("Create Storage"),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
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
    );
  }

  Widget _typeChip(BucketMediaType type, {required bool enabled}) {
    final selected = _selectedTypes.contains(type);
    return FilterChip(
      label: Text(_typeLabel(type)),
      selected: selected,
      onSelected: enabled
          ? (value) {
              setState(() {
                if (value) {
                  _selectedTypes.add(type);
                } else {
                  _selectedTypes.remove(type);
                  if (_selectedTypes.isEmpty) {
                    _selectedTypes.addAll({
                      BucketMediaType.photo,
                      BucketMediaType.video,
                    });
                  }
                }
              });
            }
          : null,
    );
  }

  String _typeLabel(BucketMediaType type) {
    return switch (type) {
      BucketMediaType.photo => 'Photos',
      BucketMediaType.video => 'Videos',
      BucketMediaType.document => 'Documents',
      BucketMediaType.app => 'Apps',
      BucketMediaType.other => 'Others',
    };
  }

  Future<void> _restoreAutomaticMetadataBackup() async {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'Automatic metadata restore did not finish. You can create a new bucket or restore an older passphrase backup. Details: $e';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoreStatus =
            'No previous Safe Uninstall metadata was restored. You can create a new bucket to start over. Details: $e';
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
