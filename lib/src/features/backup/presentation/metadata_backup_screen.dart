import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/secure_text_dialog.dart';
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
  String? _safeUninstallStatus;

  @override
  void initState() {
    super.initState();
    _loadAutoMetadataSettings();
  }

  Future<void> _loadAutoMetadataSettings() async {
    final interval = await ref
        .read(autoMetadataBackupServiceProvider)
        .getBackupEveryFiles();
    if (!mounted) return;
    setState(() => _autoMetadataEveryFiles = interval);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Metadata Backup')),
      body: ResponsivePage(
        maxWidth: 560,
        centerVertically: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metadata is protected by your TeleVault Recovery Key and bound to your Telegram account. Manual exports also require their passphrase.',
              style: TextStyle(color: Colors.grey),
            ),
            const Gap(20),
            _metadataAutoBackupCard(),
            const Gap(10),
            _actionCard(
              icon: Icons.upload_file,
              title: 'Export Metadata Snapshot',
              subtitle: 'Recovery key + passphrase protected .tvmeta',
              loading: _exporting,
              onTap: _exporting ? null : _exportMetadata,
            ),
            const Gap(10),
            _actionCard(
              icon: Icons.download_rounded,
              title: 'Import Metadata Snapshot',
              subtitle:
                  'Requires the original recovery key, account, and passphrase',
              loading: _importing,
              onTap: _importing ? null : _importMetadata,
            ),
            const Gap(10),
            _actionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Safe Uninstall Backup',
              subtitle:
                  'Pauses auto-backup, finishes the current upload, then saves metadata',
              loading: _safeUninstallBackingUp,
              onTap: _safeUninstallBackingUp ? null : _safeUninstallBackup,
            ),
            if (_safeUninstallStatus != null) ...[
              const Gap(12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _safeUninstallStatus!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
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
    );
  }

  Widget _metadataAutoBackupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppTheme.primary),
              const Gap(12),
              const Expanded(
                child: Text(
                  'Automatic Metadata Backup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _savingAutoMetadataInterval
                    ? null
                    : _editAutoMetadataInterval,
                child: Text('Every $_autoMetadataEveryFiles'),
              ),
            ],
          ),
          const Gap(6),
          const Text(
            'Updates a private “TeleVault” Telegram channel after successful uploads, so a fresh install can restore metadata after login.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Gap(10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _metadataBackupNow ? null : _runMetadataBackupNow,
              icon: _metadataBackupNow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: Text(_metadataBackupNow ? 'Backing up...' : 'Back up now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
            ],
          ),
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
              setState(
                () => _safeUninstallStatus = _safeUninstallStepText(step),
              );
            },
          );

      if (!mounted) return;
      setState(() {
        _safeUninstallCompleted = true;
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
        'Creating a Recovery-Key protected account-bound snapshot...',
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
