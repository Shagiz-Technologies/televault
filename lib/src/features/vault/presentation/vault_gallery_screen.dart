import 'dart:io' as io;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_isSelecting ? '${_selectedIds.length} selected' : 'Vault'),
        backgroundColor: Colors.black,
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Vault is Empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select items in Library to hide them here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final encryptedCount = files.where((f) => f.isEncrypted).length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0x222AA7FF),
                      child: Icon(Icons.lock, color: AppTheme.primary),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        '${files.length} secured item(s), $encryptedCount encrypted',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _buildVaultPreview(file),
                          ),
                          if (selected)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
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
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isEncrypted
                                        ? Icons.lock
                                        : Icons.lock_open_outlined,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const Gap(6),
                                  Expanded(
                                    child: Text(
                                      isEncrypted ? 'Encrypted' : 'Vaulted',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  if (busy)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
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
                _selectionAction(Icons.share_outlined, 'Share', _shareSelected),
                const Gap(16),
                _selectionAction(
                  Icons.lock_open_rounded,
                  'Restore',
                  _restoreSelected,
                ),
                const Gap(16),
                _selectionAction(
                  Icons.delete_outline,
                  'Delete',
                  _deleteSelected,
                  danger: true,
                ),
              ],
            ),
    );
  }

  Widget _selectionAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.redAccent : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const Gap(4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
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
      return ref.read(vaultServiceProvider).decryptFile(source, pin);
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
    try {
      final service = ref.read(vaultServiceProvider);
      final files = <XFile>[];
      for (final row in rows) {
        final source = io.File(row.localPath);
        if (!source.existsSync()) continue;
        final decrypted = row.isEncrypted
            ? await service.decryptFile(source, pin)
            : source;
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
            status: const Value(0),
            telegramMessageId: const Value(null),
            telegramFileId: const Value(null),
            retryCount: const Value(0),
            nextRetryAt: const Value(null),
            isVaulted: const Value(false),
            isEncrypted: const Value(false),
            encryptionVersion: const Value(null),
            ivB64: const Value(null),
            lastError: const Value(null),
          ),
        );
        if (encryptedFile.existsSync()) {
          await encryptedFile.delete();
        }
        _previewFutures.remove(row.id);
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
