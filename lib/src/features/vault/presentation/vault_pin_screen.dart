import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/services/app_lock_controller.dart';
import '../services/vault_migration_service.dart';
import '../services/vault_pin_service.dart';
import '../services/vault_recovery_service.dart';
import 'vault_gallery_screen.dart';
import 'vault_recovery_key_screen.dart';

enum VaultPinMode { set, unlock }

class VaultPinScreen extends ConsumerStatefulWidget {
  final VaultPinMode mode;
  final Function(String)? onUnlock;
  final bool forceSecretEntry;

  const VaultPinScreen({
    super.key,
    this.mode = VaultPinMode.unlock,
    this.onUnlock,
    this.forceSecretEntry = false,
  });

  @override
  ConsumerState<VaultPinScreen> createState() => _VaultPinScreenState();
}

class _VaultPinScreenState extends ConsumerState<VaultPinScreen> {
  final _currentSecretCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  VaultAuthMethod _method = VaultAuthMethod.pin;
  VaultAuthMethod _storedMethod = VaultAuthMethod.pin;
  bool _hasExistingSecret = false;
  bool _biometricsAvailable = false;
  bool _loading = true;
  bool _processing = false;
  bool _obscureCurrentSecret = true;
  bool _obscureSecret = true;
  bool _obscureConfirm = true;
  bool _requireCurrentForBiometricRecovery = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMethod();
  }

  @override
  void dispose() {
    _currentSecretCtrl.dispose();
    _secretCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMethod() async {
    final service = ref.read(vaultPinServiceProvider);
    final hasExistingSecret = await service.isPinConfigured();
    final method = await service.getAuthMethod();
    final biometricsAvailable = await service.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _method = method;
      _storedMethod = method;
      _hasExistingSecret = hasExistingSecret;
      _biometricsAvailable = biometricsAvailable;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(vaultSecurityRevisionProvider, (_, _) {
      _loadMethod();
    });

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final setupRequired =
        widget.mode == VaultPinMode.unlock && !_hasExistingSecret;
    final isSet = widget.mode == VaultPinMode.set || setupRequired;
    final effectiveMethod =
        (widget.forceSecretEntry && _method == VaultAuthMethod.biometric)
        ? VaultAuthMethod.password
        : _method;
    final secretEntryMethod = _method == VaultAuthMethod.pin
        ? VaultAuthMethod.pin
        : VaultAuthMethod.password;
    final unlockEntryMethod = effectiveMethod == VaultAuthMethod.pin
        ? VaultAuthMethod.pin
        : VaultAuthMethod.password;
    final confirmSecret = isSet && _obscureSecret;
    final showCurrentCredential =
        isSet &&
        _hasExistingSecret &&
        (_method != VaultAuthMethod.biometric ||
            _requireCurrentForBiometricRecovery);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          setupRequired
              ? 'Set Vault Security'
              : isSet
              ? 'Vault Security'
              : 'Unlock Vault',
        ),
        leading: Navigator.canPop(context) ? const BackButton() : null,
      ),
      body: ListView(
        padding: AppResponsive.pagePaddingWithBottomSafe(
          context,
          horizontal: 20,
          top: 20,
          bottomExtra: 24,
        ),
        children: [
          if (setupRequired) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_person_rounded, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set a Vault PIN, password, or Phone Security before opening private files.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isSet) ...[
            const Text('Unlock method', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: VaultAuthMethod.values.map((method) {
                return ChoiceChip(
                  label: Text(_methodLabel(method)),
                  selected: _method == method,
                  onSelected: _processing
                      ? null
                      : (value) async {
                          if (!value) return;
                          if (method == VaultAuthMethod.biometric &&
                              !await ref
                                  .read(vaultPinServiceProvider)
                                  .canUseBiometrics()) {
                            setState(() {
                              _biometricsAvailable = false;
                              _error =
                                  'Phone security is not available. Add a screen lock, fingerprint, or face unlock in Android settings first.';
                            });
                            return;
                          }
                          _selectMethod(method);
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (isSet) ...[
            if (showCurrentCredential) ...[
              TextField(
                controller: _currentSecretCtrl,
                obscureText: _obscureCurrentSecret,
                keyboardType: _storedMethod == VaultAuthMethod.pin
                    ? TextInputType.number
                    : TextInputType.visiblePassword,
                maxLength: _storedMethod == VaultAuthMethod.pin ? 8 : 64,
                decoration: InputDecoration(
                  labelText: 'Current ${_credentialLabel(_storedMethod)}',
                  hintText: 'Required to update Vault security',
                  suffixIcon: IconButton(
                    tooltip: _obscureCurrentSecret ? 'Show' : 'Hide',
                    onPressed: () {
                      setState(() {
                        _obscureCurrentSecret = !_obscureCurrentSecret;
                      });
                    },
                    icon: Icon(
                      _obscureCurrentSecret
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_method == VaultAuthMethod.biometric)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _biometricsAvailable
                          ? Icons.fingerprint
                          : Icons.warning_amber_rounded,
                      color: _biometricsAvailable
                          ? AppTheme.primary
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _biometricsAvailable
                            ? 'Phone Security uses your device screen lock, fingerprint, or face unlock. A Vault password is still required for encrypted file recovery and security changes.'
                            : 'Phone security is not available. Add a screen lock, fingerprint, or face unlock in Android settings first.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _secretCtrl,
              obscureText: _obscureSecret,
              keyboardType: secretEntryMethod == VaultAuthMethod.pin
                  ? TextInputType.number
                  : TextInputType.visiblePassword,
              maxLength: secretEntryMethod == VaultAuthMethod.pin ? 8 : 64,
              decoration: InputDecoration(
                labelText: _hasExistingSecret
                    ? 'New ${_credentialLabel(secretEntryMethod)}'
                    : _credentialLabel(secretEntryMethod),
                hintText: secretEntryMethod == VaultAuthMethod.pin
                    ? '4-8 digits'
                    : 'At least 6 characters',
                suffixIcon: IconButton(
                  tooltip: _obscureSecret ? 'Show' : 'Hide',
                  onPressed: () {
                    setState(() {
                      _obscureSecret = !_obscureSecret;
                      _error = null;
                    });
                  },
                  icon: Icon(
                    _obscureSecret
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
            if (confirmSecret) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                keyboardType: secretEntryMethod == VaultAuthMethod.pin
                    ? TextInputType.number
                    : TextInputType.visiblePassword,
                maxLength: secretEntryMethod == VaultAuthMethod.pin ? 8 : 64,
                decoration: InputDecoration(
                  labelText: 'Confirm ${_credentialLabel(secretEntryMethod)}',
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm ? 'Show' : 'Hide',
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Confirmation is hidden because the new value is visible.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ] else ...[
            if (_method == VaultAuthMethod.biometric &&
                !widget.forceSecretEntry) ...[
              ElevatedButton.icon(
                onPressed: _processing ? null : _unlockWithBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text(
                  _processing ? 'Checking...' : 'Unlock with Phone Security',
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _secretCtrl,
              obscureText: _obscureSecret,
              keyboardType: unlockEntryMethod == VaultAuthMethod.pin
                  ? TextInputType.number
                  : TextInputType.visiblePassword,
              maxLength: unlockEntryMethod == VaultAuthMethod.pin ? 8 : 64,
              decoration: InputDecoration(
                labelText: _credentialLabel(unlockEntryMethod),
                hintText: unlockEntryMethod == VaultAuthMethod.pin
                    ? 'Enter your Vault PIN'
                    : 'Enter your Vault password',
                suffixIcon: IconButton(
                  tooltip: _obscureSecret ? 'Show' : 'Hide',
                  onPressed: () {
                    setState(() => _obscureSecret = !_obscureSecret);
                  },
                  icon: Icon(
                    _obscureSecret
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _processing
                ? null
                : () {
                    if (isSet) {
                      _setVaultSecurity();
                    } else {
                      _unlockWithSecret();
                    }
                  },
            child: Text(
              _processing ? 'Please wait...' : (isSet ? 'Save' : 'Unlock'),
            ),
          ),
          if (!isSet && _method == VaultAuthMethod.biometric)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Phone Security uses your device screen lock, fingerprint, or face unlock and previews encrypted items on this device.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _selectMethod(VaultAuthMethod method) {
    setState(() {
      _method = method;
      _secretCtrl.clear();
      _confirmCtrl.clear();
      _obscureSecret = true;
      _obscureConfirm = true;
      _requireCurrentForBiometricRecovery = false;
      _biometricsAvailable = method == VaultAuthMethod.biometric
          ? true
          : _biometricsAvailable;
      _error = null;
    });
  }

  Future<void> _setVaultSecurity() async {
    final secret = _secretCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    final currentSecret = _currentSecretCtrl.text.trim();
    final initialSetupFromVaultTab =
        widget.mode == VaultPinMode.unlock && !_hasExistingSecret;
    final secretEntryMethod = _method == VaultAuthMethod.pin
        ? VaultAuthMethod.pin
        : VaultAuthMethod.password;

    final minLength = (secretEntryMethod == VaultAuthMethod.pin) ? 4 : 6;
    final biometricSave = _method == VaultAuthMethod.biometric;
    final confirmSecret = _obscureSecret;
    final currentRequired =
        _hasExistingSecret &&
        (!biometricSave || _requireCurrentForBiometricRecovery);
    if (currentRequired && currentSecret.isEmpty) {
      setState(() => _error = 'Enter your current Vault credential first');
      return;
    }
    if (secret.length < minLength) {
      setState(() => _error = 'Value is too short');
      return;
    }
    if (confirmSecret && secret != confirm) {
      setState(() => _error = 'Values do not match');
      return;
    }
    if (_method == VaultAuthMethod.biometric && !_biometricsAvailable) {
      setState(() {
        _error =
            'Phone security is not available. Add a screen lock, fingerprint, or face unlock in Android settings first.';
      });
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final service = ref.read(vaultPinServiceProvider);
      var biometricConfirmed = false;
      String? legacyDecryptionSecret;

      if (biometricSave) {
        ref
            .read(appLockControllerProvider.notifier)
            .allowExternalSystemPrompt();
        biometricConfirmed = await service.authenticateBiometric(
          localizedReason: 'Confirm phone security for Vault',
        );
        if (!biometricConfirmed) {
          if (!mounted) return;
          setState(() {
            _processing = false;
            _error = 'Phone security confirmation failed';
          });
          return;
        }
      }

      if (_hasExistingSecret) {
        if (biometricSave) {
          legacyDecryptionSecret = await service.readVerifiedBiometricSecret();
          if (legacyDecryptionSecret == null &&
              await _legacyVaultFileCount() > 0) {
            if (currentSecret.isEmpty) {
              if (!mounted) return;
              setState(() {
                _processing = false;
                _requireCurrentForBiometricRecovery = true;
                _error =
                    'Phone Security was confirmed. Enter the current Vault credential once to keep encrypted files readable, then save again.';
              });
              return;
            }
            final currentCheck = await service.verifyPin(currentSecret);
            if (currentCheck.status != VaultPinCheckStatus.success) {
              if (!mounted) return;
              setState(() {
                _processing = false;
                _error = currentCheck.status == VaultPinCheckStatus.locked
                    ? 'Vault is locked. Try again later.'
                    : 'Current credential is incorrect';
              });
              return;
            }
            legacyDecryptionSecret = currentSecret;
          }
        } else {
          final currentCheck = await service.verifyPin(currentSecret);
          if (currentCheck.status != VaultPinCheckStatus.success) {
            if (!mounted) return;
            setState(() {
              _processing = false;
              _error = currentCheck.status == VaultPinCheckStatus.locked
                  ? 'Vault is locked. Try again later.'
                  : 'Current credential is incorrect';
            });
            return;
          }
          legacyDecryptionSecret = currentSecret;
        }

        if (legacyDecryptionSecret != null &&
            await _legacyVaultFileCount() > 0) {
          final recoveryReady = await _ensureRecoveryKeyConfirmed();
          if (!recoveryReady) {
            if (!mounted) return;
            setState(() {
              _processing = false;
              _error =
                  'Confirm a recovery key before migrating legacy vault files.';
            });
            return;
          }
          final report = await ref
              .read(vaultMigrationServiceProvider)
              .migratePending(legacyDecryptionSecret);
          if (report.failed > 0) {
            throw StateError(
              '${report.failed} legacy vault file(s) could not be migrated.',
            );
          }
        }
      }

      await service.setPin(secret);
      if (_method == VaultAuthMethod.biometric) {
        await service.saveBiometricSecret(secret);
      } else {
        await service.clearBiometricSecret();
      }
      await service.setAuthMethod(_method);
      final recoveryReady = await _ensureRecoveryKeyConfirmed();
      if (!recoveryReady) {
        if (!mounted) return;
        setState(() {
          _processing = false;
          _error =
              'Vault access was saved, but the recovery key must be confirmed before files can be vaulted.';
        });
        return;
      }
      final revision = ref.read(vaultSecurityRevisionProvider.notifier);
      revision.state = revision.state + 1;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vault security updated')));
      if (Navigator.canPop(context) && !initialSetupFromVaultTab) {
        Navigator.pop(context);
        return;
      }

      _currentSecretCtrl.clear();
      _secretCtrl.clear();
      _confirmCtrl.clear();
      setState(() {
        _hasExistingSecret = true;
        _storedMethod = _method;
        _obscureCurrentSecret = true;
        _obscureSecret = true;
        _obscureConfirm = true;
      });

      if (initialSetupFromVaultTab) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VaultGalleryScreen(unlockPin: secret),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to update Vault security. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<int> _legacyVaultFileCount() {
    final db = ref.read(databaseProvider);
    return db
        .customSelect(
          '''
          SELECT COUNT(*) AS c
          FROM files
          WHERE is_vaulted = 1
            AND is_encrypted = 1
            AND COALESCE(vault_format_version, encryption_version, 1) < 3
          ''',
          readsFrom: {db.files},
        )
        .map((row) => row.read<int>('c'))
        .getSingle();
  }

  Future<bool> _ensureRecoveryKeyConfirmed() async {
    final recovery = ref.read(vaultRecoveryServiceProvider);
    if (await recovery.isRecoveryKeyConfirmed()) return true;
    if (!mounted) return false;
    return await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const VaultRecoveryKeyScreen()),
        ) ==
        true;
  }

  Future<void> _unlockWithSecret() async {
    final secret = _secretCtrl.text.trim();
    if (secret.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    final result = await ref.read(vaultPinServiceProvider).verifyPin(secret);
    if (!mounted) return;

    if (result.status == VaultPinCheckStatus.success) {
      if (widget.onUnlock != null) {
        widget.onUnlock!(secret);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VaultGalleryScreen(unlockPin: secret),
          ),
        );
      }
    } else if (result.status == VaultPinCheckStatus.locked) {
      final seconds = result.lockoutRemaining?.inSeconds ?? 0;
      setState(() => _error = 'Vault locked. Try again in ${seconds}s.');
    } else {
      setState(() => _error = 'Invalid credentials');
    }

    if (mounted) {
      setState(() => _processing = false);
    }
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
    final secret = await ref
        .read(vaultPinServiceProvider)
        .unlockSecretWithBiometric(localizedReason: 'Unlock your Vault');

    if (!mounted) return;

    if (secret != null && secret.isNotEmpty) {
      setState(() => _processing = false);
      if (widget.onUnlock != null) {
        widget.onUnlock!(secret);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VaultGalleryScreen(unlockPin: secret),
        ),
      );
      return;
    }

    setState(() {
      _processing = false;
      _error =
          'Phone Security unlock failed or this device is missing the secure Vault key. Enter your Vault password once and save Phone Security again.';
    });
  }

  String _methodLabel(VaultAuthMethod method) {
    return switch (method) {
      VaultAuthMethod.pin => 'PIN',
      VaultAuthMethod.password => 'Password',
      VaultAuthMethod.biometric => 'Phone Security',
    };
  }

  String _credentialLabel(VaultAuthMethod method) {
    return switch (method) {
      VaultAuthMethod.pin => 'PIN',
      VaultAuthMethod.password || VaultAuthMethod.biometric => 'Password',
    };
  }
}
