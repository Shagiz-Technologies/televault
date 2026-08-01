import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../services/vault_recovery_service.dart';

class VaultRecoveryKeyScreen extends ConsumerStatefulWidget {
  final bool allowImport;
  final bool requireExistingKey;

  const VaultRecoveryKeyScreen({
    super.key,
    this.allowImport = true,
    this.requireExistingKey = false,
  });

  @override
  ConsumerState<VaultRecoveryKeyScreen> createState() =>
      _VaultRecoveryKeyScreenState();
}

class _VaultRecoveryKeyScreenState
    extends ConsumerState<VaultRecoveryKeyScreen> {
  final TextEditingController _confirmationController = TextEditingController();
  final TextEditingController _importController = TextEditingController();
  String? _recoveryKey;
  String? _error;
  bool _confirmed = false;
  bool _recorded = false;
  bool _busy = true;
  bool _requiresExistingKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _importController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(vaultRecoveryServiceProvider);
      final confirmed = await service.isRecoveryKeyConfirmed();
      final hasRecoveryKey = await service.hasRecoveryKey();
      final database = ref.read(databaseProvider);
      final existingV3Count = await database
          .customSelect(
            '''
            SELECT COUNT(*) AS c
            FROM files
            WHERE is_vaulted = 1
              AND is_encrypted = 1
              AND COALESCE(vault_format_version, encryption_version, 1) = 3
            ''',
            readsFrom: {database.files},
          )
          .map((row) => row.read<int>('c'))
          .getSingle();
      if ((widget.requireExistingKey || existingV3Count > 0) &&
          !hasRecoveryKey) {
        if (!mounted) return;
        setState(() {
          _requiresExistingKey = true;
          _busy = false;
        });
        return;
      }
      final recoveryKey = await service.ensureRecoveryKey();
      if (!mounted) return;
      setState(() {
        _confirmed = confirmed;
        _recoveryKey = recoveryKey;
        _busy = false;
      });
    } on VaultRecoveryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _copy() async {
    final recoveryKey = _recoveryKey;
    if (recoveryKey == null) return;
    await Clipboard.setData(ClipboardData(text: recoveryKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery key copied. Store it somewhere private.'),
      ),
    );
  }

  Future<void> _confirm() async {
    final recoveryKey = _recoveryKey;
    if (recoveryKey == null || !_recorded) {
      setState(() => _error = 'Confirm that you stored the recovery key.');
      return;
    }
    final expectedSuffix = recoveryKey.substring(recoveryKey.length - 8);
    if (_confirmationController.text.trim() != expectedSuffix) {
      setState(() => _error = 'The final 8 characters do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vaultRecoveryServiceProvider)
          .confirmRecoveryKey(recoveryKey);
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _busy = false;
        _confirmationController.clear();
      });
      Navigator.pop(context, true);
    } on VaultRecoveryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _import() async {
    final value = _importController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vaultRecoveryServiceProvider).importRecoveryKey(value);
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _requiresExistingKey = false;
        _recoveryKey = value.replaceAll(RegExp(r'\s+'), '');
        _busy = false;
      });
      Navigator.pop(context, true);
    } on VaultRecoveryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('TeleVault Recovery Key')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Icon(Icons.key_rounded, color: AppTheme.primary, size: 54),
            const SizedBox(height: 14),
            const Text(
              'Your portable recovery key',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'This key, not your short PIN or biometrics, recovers encrypted vault files and metadata backups on another installation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_busy && _recoveryKey == null)
              const Center(child: CircularProgressIndicator())
            else if (_requiresExistingKey)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Protected TeleVault data was found, but this installation does not have its recovery key. Import the original TVRK1 key below. Creating a new key would not unlock that data.',
                  style: TextStyle(color: Colors.orangeAccent, height: 1.4),
                ),
              )
            else if (_recoveryKey != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectableText(
                  _recoveryKey!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _copy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy recovery key'),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'If you uninstall TeleVault or lose this phone without saving this key, encrypted vault files and v5 metadata snapshots cannot be recovered. Shagiz Technologies cannot reset it.',
                  style: TextStyle(color: Colors.orangeAccent, height: 1.4),
                ),
              ),
              if (!_confirmed) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _recorded,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _recorded = value ?? false),
                  title: const Text('I stored this key somewhere private'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                TextField(
                  controller: _confirmationController,
                  enabled: !_busy,
                  maxLength: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Final 8 characters',
                    hintText: 'Confirm your saved copy',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('Confirm recovery key'),
                ),
              ] else
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_rounded, color: Colors.green),
                  title: Text('Recovery key confirmed'),
                  subtitle: Text(
                    'Keep your exported copy private and offline.',
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.allowImport && !_confirmed) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Restore an existing vault',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _importController,
                enabled: !_busy,
                minLines: 2,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Existing TVRK1 recovery key',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : _import,
                child: const Text('Import recovery key'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
