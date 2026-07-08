import 'dart:io' as io;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
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
  final Map<int, Future<io.File?>> _previewFutures = {};

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Vault'),
        backgroundColor: Colors.black,
        leading: const BackButton(),
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

                  return InkWell(
                    onTap: busy ? null : () => _showItemActions(file),
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
      errorBuilder: (_, __, ___) =>
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
    final pin = await _resolvePinForDecrypt();
    if (pin == null || pin.isEmpty) return;

    setState(() => _busyFileId = row.id);
    try {
      final service = ref.read(vaultServiceProvider);
      final source = io.File(row.localPath);
      if (!source.existsSync()) {
        throw Exception('Encrypted file not found');
      }
      final decrypted = await service.decryptFile(source, pin);
      await Share.shareXFiles([
        XFile(decrypted.path),
      ], text: 'Shared via TeleVault');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to decrypt/share: $e')));
    } finally {
      if (mounted) setState(() => _busyFileId = null);
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

    setState(() => _busyFileId = row.id);
    try {
      final db = ref.read(databaseProvider);
      final encryptedFile = io.File(row.localPath);
      if (encryptedFile.existsSync()) {
        await encryptedFile.delete();
      }
      await (db.delete(db.files)..where((t) => t.id.equals(row.id))).go();
      _previewFutures.remove(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from vault')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _busyFileId = null);
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
