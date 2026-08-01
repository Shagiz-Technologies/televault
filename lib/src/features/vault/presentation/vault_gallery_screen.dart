import 'dart:async';
import 'dart:io' as io;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/file_sync_status.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/services/app_lock_controller.dart';
import '../services/vault_pin_service.dart';
import '../services/vault_service.dart';

class VaultGalleryScreen extends ConsumerStatefulWidget {
  final String? unlockPin;

  const VaultGalleryScreen({super.key, this.unlockPin});

  @override
  ConsumerState<VaultGalleryScreen> createState() => _VaultGalleryScreenState();
}

class _VaultGalleryScreenState extends ConsumerState<VaultGalleryScreen> {
  int? _busyFileId;
  bool _isSelecting = false;
  bool _bulkBusy = false;
  final Set<int> _selectedIds = {};
  final Map<int, Future<io.File?>> _previewFutures = {};
  final Map<int, io.File> _previewPlaintextFiles = {};

  @override
  void dispose() {
    final files = _previewPlaintextFiles.values.toList(growable: false);
    _previewPlaintextFiles.clear();
    for (final file in files) {
      unawaited(_deletePlaintext(file));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppTheme.secure,
      appBar: AppBar(
        title: _isSelecting
            ? Text('${_selectedIds.length} selected')
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vault'),
                  Text(
                    'Encrypted on this device',
                    style: TextStyle(
                      color: AppTheme.encrypted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
        backgroundColor: AppTheme.secure,
        foregroundColor: Colors.white,
        leading: _isSelecting
            ? IconButton(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close_rounded),
              )
            : const BackButton(),
        actions: [
          if (!_isSelecting)
            IconButton(
              tooltip: 'Select',
              onPressed: () => setState(() => _isSelecting = true),
              icon: const Icon(Icons.checklist_rtl_rounded),
            ),
        ],
      ),
      body: StreamBuilder<List<File>>(
        stream:
            (db.select(db.files)
                  ..where((t) => t.isVaulted.equals(true))
                  ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)]))
                .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Theme(
              data: AppTheme.darkTheme,
              child: const TeleVaultEmptyState(
                icon: Icons.lock_open_rounded,
                title: 'Your Vault is empty',
                message:
                    'Select media in Library and choose Vault to protect it.',
              ),
            );
          }

          final encryptedCount = files.where((f) => f.isEncrypted).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.secureSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.secureOutline),
                ),
                child: Row(
                  children: [
                    const TeleVaultIconBadge(
                      icon: Icons.shield_outlined,
                      color: AppTheme.encrypted,
                      backgroundColor: Color(0x22D7A54A),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${files.length} private items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$encryptedCount encrypted before upload',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const TeleVaultStatusPill(
                      label: 'Encrypted',
                      icon: Icons.shield_outlined,
                      color: AppTheme.encrypted,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const Gap(12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  final isVideo =
                      file.localPath.toLowerCase().endsWith('.mp4') ||
                      file.localPath.toLowerCase().endsWith('.mov');
                  final isEncrypted = file.isEncrypted;
                  final busy = _busyFileId == file.id;

                  final selected = _selectedIds.contains(file.id);

                  return InkWell(
                    onTap: busy
                        ? null
                        : () {
                            if (_isSelecting) {
                              _toggleSelection(file);
                            } else {
                              _showItemActions(file);
                            }
                          },
                    onLongPress: busy
                        ? null
                        : () {
                            if (!_isSelecting) {
                              setState(() => _isSelecting = true);
                            }
                            _toggleSelection(file);
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.secureSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secureOutline),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildVaultPreview(file),
                          ),
                          if (selected)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (_isSelecting)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: selected
                                    ? AppTheme.primary
                                    : Colors.white70,
                              ),
                            ),
                          if (isVideo)
                            const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.secure.withValues(alpha: 0.82),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.encrypted.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              child: Icon(
                                isEncrypted
                                    ? Icons.shield_rounded
                                    : Icons.lock_open_outlined,
                                size: 13,
                                color: AppTheme.encrypted,
                              ),
                            ),
                          ),
                          if (busy)
                            const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isSelecting && _selectedIds.isNotEmpty
          ? _buildSelectionBar()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSelectionBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.secureSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.secureOutline),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _bulkBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _selectionAction(
                    Icons.share_outlined,
                    'Share decrypted',
                    _shareSelected,
                  ),
                  const Gap(6),
                  _selectionAction(
                    Icons.outbox_outlined,
                    'Restore',
                    _restoreSelected,
                    color: AppTheme.success,
                  ),
                  const Gap(6),
                  _selectionAction(
                    Icons.delete_outline,
                    'Delete',
                    _deleteSelected,
                    color: AppTheme.error,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _selectionAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 78, minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              const Gap(4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showItemActions(File file) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share decrypted copy'),
              subtitle: const Text('Creates temporary decrypted file'),
              onTap: () {
                Navigator.pop(context);
                _shareDecrypted(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_rounded),
              title: const Text('Restore from Vault'),
              subtitle: const Text('Shows it in your Library again'),
              onTap: () {
                Navigator.pop(context);
                _restoreVaultItems([file]);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete from Vault',
                style: TextStyle(color: Colors.redAccent),
              ),
              subtitle: const Text('Removes encrypted copy and metadata'),
              onTap: () {
                Navigator.pop(context);
                _deleteVaultItem(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedIds.contains(file.id)) {
        _selectedIds.remove(file.id);
      } else {
        _selectedIds.add(file.id);
      }
      if (_selectedIds.isEmpty) {
        _isSelecting = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  Future<List<File>> _selectedRows() async {
    final db = ref.read(databaseProvider);
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return const [];
    return (db.select(db.files)..where((t) => t.id.isIn(ids))).get();
  }

  Future<void> _shareSelected() async {
    final rows = await _selectedRows();
    if (rows.isEmpty) return;
    await _shareVaultItems(rows);
  }

  Future<void> _restoreSelected() async {
    final rows = await _selectedRows();
    if (rows.isEmpty) return;
    await _restoreVaultItems(rows);
  }

  Future<void> _deleteSelected() async {
    final rows = await _selectedRows();
    if (rows.isEmpty) return;
    await _deleteVaultItems(rows);
  }

  Widget _buildVaultPreview(File row) {
    if (!row.isEncrypted) {
      return _imagePreview(io.File(row.localPath));
    }

    if (widget.unlockPin == null || widget.unlockPin!.isEmpty) {
      return Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, color: Colors.white70, size: 30),
              SizedBox(height: 8),
              Text(
                'Password required\nto preview',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final future = _previewFutures.putIfAbsent(
      row.id,
      () => _decryptPreview(row),
    );
    return FutureBuilder<io.File?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final decrypted = snapshot.data;
        if (decrypted == null) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          );
        }

        if (_isImagePath(decrypted.path)) {
          return _imagePreview(decrypted);
        }

        return Container(
          color: Colors.black54,
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 38,
            ),
          ),
        );
      },
    );
  }

  Widget _imagePreview(io.File file) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  Future<io.File?> _decryptPreview(File row) async {
    final pin = widget.unlockPin;
    if (pin == null || pin.isEmpty) return null;
    try {
      final source = io.File(row.localPath);
      if (!await source.exists()) return null;
      final decrypted = await ref
          .read(vaultServiceProvider)
          .decryptFile(source, pin);
      _previewPlaintextFiles[row.id] = decrypted;
      return decrypted;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareDecrypted(File row) async {
    await _shareVaultItems([row]);
  }

  Future<void> _shareVaultItems(List<File> rows) async {
    final pin = await _resolvePinForDecrypt();
    if (pin == null || pin.isEmpty) return;

    setState(() {
      _busyFileId = rows.length == 1 ? rows.first.id : null;
      _bulkBusy = rows.length > 1;
    });
    final temporaryFiles = <io.File>[];
    try {
      final service = ref.read(vaultServiceProvider);
      final files = <XFile>[];
      for (final row in rows) {
        final source = io.File(row.localPath);
        if (!source.existsSync()) continue;
        final decrypted = row.isEncrypted
            ? await service.decryptFile(source, pin)
            : source;
        if (row.isEncrypted) temporaryFiles.add(decrypted);
        files.add(XFile(decrypted.path));
      }
      if (files.isEmpty) {
        throw Exception('No local vault files were available');
      }
      await Share.shareXFiles(files, text: 'Shared via TeleVault');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to decrypt/share: $e')));
    } finally {
      for (final file in temporaryFiles) {
        await _deletePlaintext(file);
      }
      if (mounted) {
        setState(() {
          _busyFileId = null;
          _bulkBusy = false;
        });
      }
    }
  }

  Future<void> _deleteVaultItem(File row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete from Vault?'),
        content: const Text(
          'This removes the encrypted copy from TeleVault metadata. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _deleteVaultItems([row]);
  }

  Future<void> _deleteVaultItems(List<File> rows) async {
    if (rows.isEmpty) return;
    final confirmed = rows.length == 1
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Delete from Vault?'),
              content: Text(
                'Delete ${rows.length} item(s) from Vault metadata?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
    if (confirmed != true) return;

    setState(() {
      _busyFileId = rows.length == 1 ? rows.first.id : null;
      _bulkBusy = rows.length > 1;
    });
    try {
      final db = ref.read(databaseProvider);
      for (final row in rows) {
        final encryptedFile = io.File(row.localPath);
        if (encryptedFile.existsSync()) {
          await encryptedFile.delete();
        }
        await (db.delete(db.files)..where((t) => t.id.equals(row.id))).go();
        _previewFutures.remove(row.id);
        final preview = _previewPlaintextFiles.remove(row.id);
        if (preview != null) await _deletePlaintext(preview);
      }
      if (!mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed ${rows.length} item(s)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busyFileId = null;
          _bulkBusy = false;
        });
      }
    }
  }

  Future<void> _restoreVaultItems(List<File> rows) async {
    if (rows.isEmpty) return;

    final pin = await _resolvePinForDecrypt();
    if (pin == null || pin.isEmpty) return;

    setState(() {
      _busyFileId = rows.length == 1 ? rows.first.id : null;
      _bulkBusy = rows.length > 1;
    });

    var restored = 0;
    try {
      final db = ref.read(databaseProvider);
      for (final row in rows) {
        final assetId = row.assetId;
        if (assetId == null || assetId.isEmpty) continue;

        final asset = await AssetEntity.fromId(assetId);
        final original = await asset?.file;
        if (original == null || !original.existsSync()) continue;

        final encryptedFile = io.File(row.localPath);
        final originalSize = await original.length();
        await (db.update(db.files)..where((t) => t.id.equals(row.id))).write(
          FilesCompanion(
            localPath: Value(original.path),
            size: Value(originalSize),
            status: Value(FileSyncStatus.pending.dbValue),
            telegramMessageId: const Value(null),
            telegramFileId: const Value(null),
            retryCount: const Value(0),
            nextRetryAt: const Value(null),
            isVaulted: const Value(false),
            isEncrypted: const Value(false),
            encryptionVersion: const Value(null),
            ivB64: const Value(null),
            vaultFormatVersion: const Value(null),
            encryptedObjectId: const Value(null),
            encryptedSize: const Value(null),
            originalSize: const Value(null),
            vaultIntegrityStatus: const Value('unknown'),
            vaultMigrationStatus: const Value('notRequired'),
            keyWrappingVersion: const Value(null),
            lastVerifiedAt: const Value(null),
            lastError: const Value(null),
          ),
        );
        if (encryptedFile.existsSync()) {
          await encryptedFile.delete();
        }
        _previewFutures.remove(row.id);
        final preview = _previewPlaintextFiles.remove(row.id);
        if (preview != null) await _deletePlaintext(preview);
        restored++;
      }

      if (!mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored == rows.length
                ? 'Restored $restored item(s) from Vault'
                : 'Restored $restored of ${rows.length}; missing originals stay vaulted',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busyFileId = null;
          _bulkBusy = false;
        });
      }
    }
  }

  Future<String?> _resolvePinForDecrypt() async {
    if (widget.unlockPin != null && widget.unlockPin!.isNotEmpty) {
      return widget.unlockPin;
    }

    final service = ref.read(vaultPinServiceProvider);
    final method = await service.getAuthMethod();
    if (!mounted) return null;

    if (method == VaultAuthMethod.biometric) {
      ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
      final biometricSecret = await service.unlockSecretWithBiometric(
        localizedReason: 'Decrypt this Vault item',
      );
      if (biometricSecret != null && biometricSecret.isNotEmpty) {
        return biometricSecret;
      }
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your Vault password to decrypt this item'),
        ),
      );
    }

    final credentialLabel = method == VaultAuthMethod.pin ? 'PIN' : 'Password';
    final pinController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Enter Vault $credentialLabel'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: method == VaultAuthMethod.pin
              ? TextInputType.number
              : TextInputType.visiblePassword,
          maxLength: method == VaultAuthMethod.pin ? 8 : 64,
          decoration: InputDecoration(hintText: 'Vault $credentialLabel'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pinController.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    pinController.dispose();
    if (result == null || result.isEmpty) return null;

    final check = await service.verifyPin(result);
    if (check.status != VaultPinCheckStatus.success) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid vault credentials')),
      );
      return null;
    }
    return result;
  }

  Future<void> _deletePlaintext(io.File file) async {
    try {
      await ref.read(vaultServiceProvider).deleteTemporaryPlaintext(file);
    } on Object {
      // Startup cleanup is the fallback if immediate deletion is interrupted.
    }
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }
}
