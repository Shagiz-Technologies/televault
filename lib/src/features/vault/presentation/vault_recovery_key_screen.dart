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
      appBar: AppBar(title: const Text('Recovery key')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Icon(Icons.key_rounded, color: AppTheme.primary, size: 54),
            const SizedBox(height: 14),
            const Text(
              'Save your recovery key',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'This key lets you restore protected Vault files and metadata after reinstalling TeleVault or moving to another phone. Your PIN, password, or phone security cannot replace it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 18),
            const _RecoveryStep(
              number: '1',
              title: 'Save a private copy',
              text:
                  'Tap Copy recovery key. Paste it into a password manager, or write it down and keep it locked away. Do not share it.',
            ),
            const _RecoveryStep(
              number: '2',
              title: 'Check the saved copy',
              text:
                  'Enter the last 8 characters from your saved copy below. This checks that you saved the full key.',
            ),
            const _RecoveryStep(
              number: '3',
              title: 'Keep it available',
              text:
                  'You will need this key if TeleVault is removed, your phone is lost, or you restore on another phone.',
            ),
            const SizedBox(height: 16),
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
                  'TeleVault found protected data, but this phone does not have the key that was used to protect it. Enter your previously saved recovery key below. A new key cannot open older protected data.',
                  style: TextStyle(color: AppTheme.ink, height: 1.4),
                ),
              )
            else if (_recoveryKey != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outline),
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
                  'Important: if this phone and your saved key are both lost, protected Vault files and metadata backups cannot be restored. TeleVault and Shagiz Technologies cannot create a replacement key for you.',
                  style: TextStyle(color: AppTheme.ink, height: 1.4),
                ),
              ),
              if (!_confirmed) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _recorded,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _recorded = value ?? false),
                  title: const Text('I saved this key somewhere private'),
                  subtitle: const Text(
                    'Do not continue until you can find and open your saved copy.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                TextField(
                  controller: _confirmationController,
                  enabled: !_busy,
                  maxLength: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Last 8 characters from your saved copy',
                    hintText: 'Example: Ab12Cd34',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('Confirm my saved key'),
                ),
              ] else
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_rounded, color: Colors.green),
                  title: Text('Recovery key confirmed'),
                  subtitle: Text(
                    'Your protected backups can now be restored with the saved key.',
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
                'Already have a recovery key?',
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
                  labelText: 'Paste your saved recovery key',
                  helperText:
                      'Recovery keys begin with TVRK1-. Spaces are ignored.',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : _import,
                child: const Text('Use this recovery key'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoveryStep extends StatelessWidget {
  final String number;
  final String title;
  final String text;

  const _RecoveryStep({
    required this.number,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppTheme.primarySoft,
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
