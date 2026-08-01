import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/secure_text_dialog.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_service.dart';
import '../../vault/presentation/vault_recovery_key_screen.dart';
import '../services/auto_metadata_backup_service.dart';
import '../services/metadata_backup_service.dart';
import '../services/safe_uninstall_backup_service.dart';

class MetadataBackupScreen extends ConsumerStatefulWidget {
  const MetadataBackupScreen({super.key});

  @override
  ConsumerState<MetadataBackupScreen> createState() =>
      _MetadataBackupScreenState();
}

class _MetadataBackupScreenState extends ConsumerState<MetadataBackupScreen> {
  bool _exporting = false;
  bool _importing = false;
  bool _safeUninstallBackingUp = false;
  bool _safeUninstallCompleted = false;
  bool _savingAutoMetadataInterval = false;
  bool _metadataBackupNow = false;
  int _autoMetadataEveryFiles =
      AutoMetadataBackupService.defaultBackupEveryFiles;
  DateTime? _lastMetadataBackupAt;
  SafeUninstallStep? _safeUninstallStep;
  String? _safeUninstallStatus;

  @override
  void initState() {
    super.initState();
    _loadAutoMetadataSettings();
  }

  Future<void> _loadAutoMetadataSettings() async {
    final service = ref.read(autoMetadataBackupServiceProvider);
    final interval = await service.getBackupEveryFiles();
    final lastBackupAt = await service.getLastBackupAt();
    if (!mounted) return;
    setState(() {
      _autoMetadataEveryFiles = interval;
      _lastMetadataBackupAt = lastBackupAt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metadata backup')),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: ResponsivePage(
          maxWidth: 560,
          centerVertically: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetadataHero(
                lastBackupAt: _lastMetadataBackupAt,
                running: _metadataBackupNow || _safeUninstallBackingUp,
              ),
              const Gap(14),
              const Center(
                child: Text(
                  'Keeps your TeleVault map recoverable.\n'
                  'It does not upload your media again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const Gap(14),
              TeleVaultCard(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    _MetadataSettingRow(
                      icon: Icons.ios_share_rounded,
                      color: AppTheme.primary,
                      title: 'Backup every',
                      value: '$_autoMetadataEveryFiles uploads',
                      loading: _savingAutoMetadataInterval,
                      onTap: _savingAutoMetadataInterval
                          ? null
                          : _editAutoMetadataInterval,
                    ),
                    const Divider(height: 1, indent: 48),
                    _MetadataSettingRow(
                      icon: Icons.lock_outline_rounded,
                      color: AppTheme.success,
                      title: 'Encrypted package',
                      trailingIcon: Icons.check_circle_rounded,
                      onTap: _showManualTools,
                    ),
                    const Divider(height: 1, indent: 48),
                    const _MetadataSettingRow(
                      icon: Icons.person_outline_rounded,
                      color: AppTheme.warning,
                      title: 'Current account only',
                      trailingIcon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
              ),
              const Gap(14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _metadataBackupNow || _safeUninstallBackingUp
                      ? null
                      : _runMetadataBackupNow,
                  icon: _metadataBackupNow
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shield_outlined),
                  label: Text(
                    _metadataBackupNow ? 'Backing up...' : 'Back up now',
                  ),
                ),
              ),
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  onPressed: _safeUninstallBackingUp || _metadataBackupNow
                      ? null
                      : _safeUninstallBackup,
                  icon: _safeUninstallBackingUp
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: const Text('Safe Uninstall'),
                ),
              ),
              const Gap(9),
              const Center(
                child: Text(
                  'Pause after the current upload,\n'
                  'save metadata last, then guide me.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.inkMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              if (_safeUninstallStatus != null) ...[
                const Gap(12),
                _SafeUninstallProgressCard(
                  status: _safeUninstallStatus!,
                  progress: _safeUninstallProgress,
                  completed: _safeUninstallCompleted,
                ),
                if (_safeUninstallCompleted) ...[
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resumeBackupAfterSafeUninstall,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume auto-backup'),
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

  double get _safeUninstallProgress {
    return switch (_safeUninstallStep) {
      SafeUninstallStep.uploadingMedia => 0.35,
      SafeUninstallStep.exportingMetadata => 0.65,
      SafeUninstallStep.uploadingMetadata => 0.85,
      SafeUninstallStep.complete => 1,
      _ => 0.12,
    };
  }

  Future<void> _showManualTools() {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          AppResponsive.bottomSafeGap(sheetContext, extra: 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encrypted metadata package',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const Gap(6),
            const Text(
              'Manual packages require the same Telegram account and your passphrase.',
              style: TextStyle(color: AppTheme.inkMuted),
            ),
            const Gap(14),
            TeleVaultCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TeleVaultSettingsTile(
                    icon: Icons.upload_file_rounded,
                    title: 'Export package',
                    subtitle: 'Create and share an encrypted .tvmeta file',
                    trailing: _exporting
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : null,
                    onTap: _exporting
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _exportMetadata();
                          },
                  ),
                  const Divider(height: 1, indent: 60),
                  TeleVaultSettingsTile(
                    icon: Icons.download_rounded,
                    title: 'Import package',
                    subtitle: 'Restore a package made by this account',
                    trailing: _importing
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : null,
                    onTap: _importing
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _importMetadata();
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMetadata() async {
    final passphrase = await _promptPassphrase(confirm: true);
    if (passphrase == null || passphrase.isEmpty) return;
    if (!mounted) return;

    setState(() => _exporting = true);
    io.File? file;
    try {
      final exported = await _withRecoveryKeyPrompt(
        () => ref
            .read(metadataBackupServiceProvider)
            .exportEncryptedSnapshot(passphrase: passphrase),
      );
      file = exported;
      await Share.shareXFiles([
        XFile(exported.path),
      ], text: 'TeleVault metadata snapshot');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encrypted metadata snapshot shared.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${_safeError(error)}')),
        );
      }
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importMetadata() async {
    final passphrase = await _promptPassphrase(confirm: false);
    if (passphrase == null || passphrase.isEmpty) return;
    if (!mounted) return;

    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['tvmeta'],
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;

      await _withRecoveryKeyPrompt(
        () => ref
            .read(metadataBackupServiceProvider)
            .importEncryptedSnapshot(io.File(path), passphrase: passphrase),
      );
      await ref.read(syncServiceProvider).syncNow(ignoreConstraints: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata imported. Restart sync to apply.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${_safeError(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _safeUninstallBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        title: const Text('Safe Uninstall Backup'),
        content: const Text(
          'TeleVault will pause new auto-backup work, wait only for the current uploading file to finish, then save the latest metadata in your private TeleVault metadata channel. Pending files stay pending for next install or resume.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _safeUninstallBackingUp = true;
      _safeUninstallCompleted = false;
      _safeUninstallStatus = 'Preparing Safe Uninstall backup...';
    });

    try {
      final result = await ref
          .read(safeUninstallBackupServiceProvider)
          .createSafeUninstallBackup(
            onStep: (step) {
              if (!mounted) return;
              setState(() {
                _safeUninstallStep = step;
                _safeUninstallStatus = _safeUninstallStepText(step);
              });
            },
          );

      if (!mounted) return;
      setState(() {
        _safeUninstallCompleted = true;
        _safeUninstallStep = SafeUninstallStep.complete;
        _safeUninstallStatus =
            'Safe Uninstall metadata backup completed. Metadata message id: ${result.messageId}. Pending media will resume later if you reinstall or resume auto-backup.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe Uninstall backup completed')),
      );
    } catch (error) {
      final message = _safeError(error);
      if (!mounted) return;
      setState(() {
        _safeUninstallCompleted = false;
        _safeUninstallStatus = 'Safe Uninstall failed: $message';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Safe Uninstall failed: $message')),
      );
    } finally {
      if (mounted) setState(() => _safeUninstallBackingUp = false);
    }
  }

  Future<void> _resumeBackupAfterSafeUninstall() async {
    final uploader = ref.read(fileUploaderProvider);
    uploader.resumeBackgroundWakes();
    await uploader.startUploadLoop();
    ref.read(syncServiceProvider).startSyncLoop();

    if (!mounted) return;
    setState(() {
      _safeUninstallCompleted = false;
      _safeUninstallStep = null;
      _safeUninstallStatus = 'Auto-backup resumed.';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Auto-backup resumed')));
  }

  String _safeUninstallStepText(SafeUninstallStep step) {
    return switch (step) {
      SafeUninstallStep.scanning => 'Scanning all buckets for pending media...',
      SafeUninstallStep.uploadingMedia =>
        'Auto-backup is paused. Waiting for the current upload to finish...',
      SafeUninstallStep.exportingMetadata =>
        'Creating the latest account-bound metadata snapshot...',
      SafeUninstallStep.uploadingMetadata =>
        'Uploading metadata to the private TeleVault metadata channel...',
      SafeUninstallStep.complete => 'Safe Uninstall backup completed.',
    };
  }

  Future<void> _runMetadataBackupNow() async {
    setState(() => _metadataBackupNow = true);
    try {
      final result = await _withRecoveryKeyPrompt(
        () => ref
            .read(autoMetadataBackupServiceProvider)
            .backupNow(reason: 'manual'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Metadata backed up: ${result.messageId}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Metadata backup failed: ${_safeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _metadataBackupNow = false);
    }
  }

  Future<T> _withRecoveryKeyPrompt<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on MetadataBackupException catch (error) {
      if (error.code != MetadataBackupErrorCode.recoveryKeyRequired ||
          !mounted) {
        rethrow;
      }
      final ready = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VaultRecoveryKeyScreen(
            requireExistingKey: error.requiresExistingRecoveryKey,
          ),
        ),
      );
      if (ready != true) rethrow;
      return operation();
    }
  }

  String _safeError(Object error) {
    if (error is MetadataBackupException) return error.message;
    if (error is SafeUninstallBackupException) return error.message;
    return 'The operation did not complete. Check your connection and try again.';
  }

  Future<void> _editAutoMetadataInterval() async {
    final value = await showSecureTextDialog(
      context,
      title: 'Metadata Backup Frequency',
      description:
          'TeleVault updates its metadata channel after this many successful media uploads. Minimum is 5.',
      fieldLabel: 'Files',
      actionLabel: 'Save',
      minLength: 1,
      keyboardType: TextInputType.number,
    );
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return;

    setState(() => _savingAutoMetadataInterval = true);
    try {
      await ref
          .read(autoMetadataBackupServiceProvider)
          .setBackupEveryFiles(parsed);
      await _loadAutoMetadataSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Metadata backup frequency set to $_autoMetadataEveryFiles files',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAutoMetadataInterval = false);
    }
  }

  Future<String?> _promptPassphrase({required bool confirm}) async {
    return showSecureTextDialog(
      context,
      title: confirm ? 'Set Export Passphrase' : 'Import Passphrase',
      description: confirm
          ? 'Use at least 8 characters. This passphrase is required to restore the encrypted metadata snapshot later.'
          : 'Enter the passphrase used to encrypt this metadata snapshot.',
      fieldLabel: 'Passphrase',
      actionLabel: 'Continue',
      confirmLabel: 'Confirm passphrase',
      minLength: 8,
      minLengthMessage: 'Use at least 8 characters.',
      requireConfirmation: confirm,
      hideConfirmationWhenVisible: false,
    );
  }
}

class _MetadataHero extends StatelessWidget {
  final DateTime? lastBackupAt;
  final bool running;

  const _MetadataHero({required this.lastBackupAt, required this.running});

  @override
  Widget build(BuildContext context) {
    return TeleVaultCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  color: AppTheme.primary,
                  size: 42,
                ),
              ),
              const Gap(12),
              Row(
                children: List.generate(
                  4,
                  (_) => Container(
                    width: 7,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Gap(12),
              const Stack(
                clipBehavior: Clip.none,
                children: [
                  TeleVaultLogoMark(size: 78, shadow: false),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: TeleVaultIconBadge(
                      icon: Icons.lock_rounded,
                      color: AppTheme.success,
                      backgroundColor: AppTheme.successSoft,
                      size: 31,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (running)
                const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 18,
                ),
              const Gap(6),
              Flexible(
                child: Text(
                  running
                      ? 'Updating recovery copy...'
                      : lastBackupAt == null
                      ? 'Ready for your first recovery copy'
                      : 'Up to date · ${_metadataRelativeTime(lastBackupAt!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetadataSettingRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? value;
  final IconData? trailingIcon;
  final bool loading;
  final VoidCallback? onTap;

  const _MetadataSettingRow({
    required this.icon,
    required this.color,
    required this.title,
    this.value,
    this.trailingIcon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 52,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      trailing: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(
                    value!,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (value != null && onTap != null) const Gap(4),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: AppTheme.success, size: 19)
                else if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.inkMuted,
                    size: 20,
                  ),
              ],
            ),
      onTap: onTap,
    );
  }
}

class _SafeUninstallProgressCard extends StatelessWidget {
  final String status;
  final double progress;
  final bool completed;

  const _SafeUninstallProgressCard({
    required this.status,
    required this.progress,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return TeleVaultCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TeleVaultIconBadge(
            icon: completed ? Icons.check_rounded : Icons.cloud_upload_outlined,
            color: completed ? AppTheme.success : AppTheme.primary,
            size: 42,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(7),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: completed ? AppTheme.success : AppTheme.primary,
                ),
              ],
            ),
          ),
          const Gap(10),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _metadataRelativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';
  return '${time.day}/${time.month}/${time.year}';
}
