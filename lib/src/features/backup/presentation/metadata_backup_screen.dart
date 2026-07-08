import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_service.dart';
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
  String? _safeUninstallStatus;

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
              'Export or import encrypted metadata snapshots (.tvmeta). Imports only work when logged in with the same Telegram account that created the snapshot.',
              style: TextStyle(color: Colors.grey),
            ),
            const Gap(20),
            _actionCard(
              icon: Icons.upload_file,
              title: 'Export Metadata Snapshot',
              subtitle: 'Creates account-bound encrypted .tvmeta',
              loading: _exporting,
              onTap: _exporting ? null : _exportMetadata,
            ),
            const Gap(10),
            _actionCard(
              icon: Icons.download_rounded,
              title: 'Import Metadata Snapshot',
              subtitle: 'Requires the same Telegram account and passphrase',
              loading: _importing,
              onTap: _importing ? null : _importMetadata,
            ),
            const Gap(10),
            _actionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Safe Uninstall Backup',
              subtitle:
                  'Uploads pending media first, then metadata last to the active bucket',
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

    setState(() => _exporting = true);
    try {
      final file = await ref
          .read(metadataBackupServiceProvider)
          .exportEncryptedSnapshot(passphrase: passphrase);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'TeleVault metadata snapshot');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snapshot exported: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importMetadata() async {
    final passphrase = await _promptPassphrase(confirm: false);
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['tvmeta'],
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;

      await ref
          .read(metadataBackupServiceProvider)
          .importEncryptedSnapshot(io.File(path), passphrase: passphrase);
      ref.read(fileUploaderProvider).wake();
      await ref.read(syncServiceProvider).syncNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata imported. Restart sync to apply.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
        title: const Text('Safe Uninstall Backup'),
        content: const Text(
          'TeleVault will first scan and upload pending media. Only after that succeeds, it uploads the encrypted metadata snapshot as the final item in your active Telegram bucket. Do not uninstall until this finishes.',
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

    final passphrase = await _promptPassphrase(confirm: true);
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() {
      _safeUninstallBackingUp = true;
      _safeUninstallCompleted = false;
      _safeUninstallStatus = 'Preparing Safe Uninstall backup...';
    });

    try {
      final result = await ref
          .read(safeUninstallBackupServiceProvider)
          .createSafeUninstallBackup(
            passphrase: passphrase,
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
            'Safe Uninstall backup completed in "${result.bucketName}". Metadata message id: ${result.messageId}. You can now uninstall the app if you need to.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe Uninstall backup completed')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _safeUninstallCompleted = false;
        _safeUninstallStatus = 'Safe Uninstall failed: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Safe Uninstall failed: $e')));
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
        'Auto-sync is paused. Uploading pending media first so metadata can be backed up last...',
      SafeUninstallStep.exportingMetadata =>
        'Media queue is clear. Creating encrypted metadata snapshot...',
      SafeUninstallStep.uploadingMetadata =>
        'Uploading metadata as the final Safe Uninstall item...',
      SafeUninstallStep.complete => 'Safe Uninstall backup completed.',
    };
  }

  Future<String?> _promptPassphrase({required bool confirm}) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscure = true;
    var validation = '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                confirm ? 'Set Export Passphrase' : 'Import Passphrase',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Passphrase',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() => obscure = !obscure);
                        },
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (confirm) ...[
                    const Gap(8),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm passphrase',
                      ),
                    ),
                  ],
                  if (validation.isNotEmpty) ...[
                    const Gap(8),
                    Text(
                      validation,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final value = ctrl.text.trim();
                    if (value.length < 8) {
                      setDialogState(() {
                        validation = 'Use at least 8 characters';
                      });
                      return;
                    }
                    if (confirm && value != confirmCtrl.text.trim()) {
                      setDialogState(() {
                        validation = 'Passphrases do not match';
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
    confirmCtrl.dispose();
    return result;
  }
}
