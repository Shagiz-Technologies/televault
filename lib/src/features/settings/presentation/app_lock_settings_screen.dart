import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/secure_text_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../services/app_lock_controller.dart';
import '../services/app_lock_service.dart';

class AppLockSettingsScreen extends ConsumerStatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  ConsumerState<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends ConsumerState<AppLockSettingsScreen> {
  late Future<_AppLockSettingsAccess> _accessFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
  }

  Future<_AppLockSettingsAccess> _loadAccess() async {
    final service = ref.read(appLockServiceProvider);
    final results = await Future.wait([
      service.canUsePhoneUnlock(),
      service.hasSecretConfigured(),
    ]);
    final credentialState = await service.getCredentialLockState();
    return _AppLockSettingsAccess(
      phoneSecurityAvailable: results[0],
      passwordConfigured: results[1],
      credentialLockState: credentialState,
    );
  }

  Future<void> _refreshAccess() async {
    setState(() => _accessFuture = _loadAccess());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockControllerProvider);
    final config = state.config;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('App Lock')),
      body: FutureBuilder<_AppLockSettingsAccess>(
        future: _accessFuture,
        builder: (context, snapshot) {
          final access = snapshot.data;
          final loadingAccess =
              snapshot.connectionState != ConnectionState.done;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                value: config.enabled,
                onChanged: _saving ? null : (value) => _toggleEnabled(value),
                title: const Text('Enable App Lock'),
                subtitle: const Text(
                  'Lock TeleVault with phone security or a TeleVault password.',
                ),
              ),
              const SizedBox(height: 12),
              _SecurityCard(
                icon: Icons.phonelink_lock_rounded,
                title: 'Phone Security',
                subtitle: loadingAccess
                    ? 'Checking this device...'
                    : access?.phoneSecurityAvailable == true
                    ? 'Available: fingerprint, face unlock, phone PIN, pattern, or phone password.'
                    : 'Not available. Set a device passcode or biometric in system settings to use it here.',
                statusLabel: access?.phoneSecurityAvailable == true
                    ? 'Ready'
                    : 'Unavailable',
                statusColor: access?.phoneSecurityAvailable == true
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                actions: [
                  OutlinedButton.icon(
                    onPressed: _saving || access?.phoneSecurityAvailable != true
                        ? null
                        : _testPhoneSecurity,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Test'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SecurityCard(
                icon: Icons.password_rounded,
                title: 'TeleVault Password',
                subtitle: access?.passwordConfigured == true
                    ? _passwordStatusText(access!.credentialLockState)
                    : 'Optional. Use it as an alternative to phone security.',
                statusLabel: access?.passwordConfigured == true
                    ? 'Set'
                    : 'Optional',
                statusColor: access?.passwordConfigured == true
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                actions: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _setOrChangePassword,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      access?.passwordConfigured == true ? 'Change' : 'Set',
                    ),
                  ),
                  if (access?.passwordConfigured == true) ...[
                    OutlinedButton.icon(
                      onPressed:
                          _saving || access?.phoneSecurityAvailable != true
                          ? null
                          : _resetPasswordWithPhoneSecurity,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _removePassword,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ],
              ),
              if (config.enabled) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: config.timeoutSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Lock after inactivity',
                  ),
                  dropdownColor: AppTheme.surface,
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 seconds')),
                    DropdownMenuItem(value: 30, child: Text('30 seconds')),
                    DropdownMenuItem(value: 60, child: Text('1 minute')),
                    DropdownMenuItem(value: 300, child: Text('5 minutes')),
                    DropdownMenuItem(value: 900, child: Text('15 minutes')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await _saveConfig(
                            config.copyWith(timeoutSeconds: value),
                          );
                        },
                ),
                SwitchListTile(
                  value: config.lockOnBackground,
                  onChanged: _saving
                      ? null
                      : (value) async {
                          await _saveConfig(
                            config.copyWith(lockOnBackground: value),
                          );
                        },
                  title: const Text('Lock when app goes to background'),
                  subtitle: const Text(
                    'Locks immediately when switching apps.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            ref
                                .read(appLockControllerProvider.notifier)
                                .lockNow();
                            if (context.mounted) Navigator.pop(context);
                          },
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock Now'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final config = ref.read(appLockControllerProvider).config;
    final service = ref.read(appLockServiceProvider);
    final phoneAvailable = await service.canUsePhoneUnlock();
    final hasPassword = await service.hasSecretConfigured();

    if (!enabled) {
      await _saveConfig(config.copyWith(enabled: false));
      return;
    }

    if (phoneAvailable) {
      await _saveConfig(
        config.copyWith(enabled: true, method: AppLockMethod.biometric),
      );
      _showMessage('App Lock enabled with phone security.');
      return;
    }

    if (hasPassword) {
      await _saveConfig(
        config.copyWith(enabled: true, method: AppLockMethod.password),
      );
      _showMessage('App Lock enabled with your TeleVault password.');
      return;
    }

    final password = await _promptNewPassword(title: 'Set TeleVault Password');
    if (password == null || password.isEmpty) return;
    await _saveConfig(
      config.copyWith(enabled: true, method: AppLockMethod.password),
      secret: password,
    );
    _showMessage('App Lock enabled.');
  }

  Future<void> _setOrChangePassword() async {
    final service = ref.read(appLockServiceProvider);
    final hasPassword = await service.hasSecretConfigured();
    final phoneAvailable = await service.canUsePhoneUnlock();

    if (hasPassword) {
      if (phoneAvailable) {
        ref
            .read(appLockControllerProvider.notifier)
            .allowExternalSystemPrompt();
        final ok = await service.authenticatePhoneUnlock(
          reason: 'Confirm phone security to change your TeleVault password',
        );
        if (!ok) {
          _showMessage(
            'Phone security was cancelled. Password was not changed.',
          );
          return;
        }
      } else {
        final currentPassword = await _promptCurrentPassword();
        if (currentPassword == null || currentPassword.isEmpty) return;
        final result = await service.verifySecretForUnlock(currentPassword);
        if (!result.success) {
          _showMessage(_messageForAttempt(result));
          await _refreshAccess();
          return;
        }
      }
    }

    final password = await _promptNewPassword(
      title: hasPassword
          ? 'Change TeleVault Password'
          : 'Set TeleVault Password',
    );
    if (password == null || password.isEmpty) return;

    setState(() => _saving = true);
    try {
      await service.savePassword(password);
      await ref.read(appLockControllerProvider.notifier).refresh();
      _showMessage('TeleVault password saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
      await _refreshAccess();
    }
  }

  Future<void> _resetPasswordWithPhoneSecurity() async {
    final service = ref.read(appLockServiceProvider);
    ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
    final ok = await service.authenticatePhoneUnlock(
      reason: 'Confirm phone security to reset your TeleVault password',
    );
    if (!ok) {
      _showMessage('Phone security was cancelled. Password was not reset.');
      return;
    }

    final password = await _promptNewPassword(
      title: 'Reset TeleVault Password',
    );
    if (password == null || password.isEmpty) return;

    setState(() => _saving = true);
    try {
      await service.savePassword(password);
      await ref.read(appLockControllerProvider.notifier).refresh();
      _showMessage('TeleVault password reset.');
    } finally {
      if (mounted) setState(() => _saving = false);
      await _refreshAccess();
    }
  }

  Future<void> _removePassword() async {
    final service = ref.read(appLockServiceProvider);
    final config = ref.read(appLockControllerProvider).config;
    final phoneAvailable = await service.canUsePhoneUnlock();

    if (config.enabled && !phoneAvailable) {
      _showMessage(
        'Set up phone security or disable App Lock before removing the password.',
      );
      return;
    }

    if (phoneAvailable) {
      ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
      final ok = await service.authenticatePhoneUnlock(
        reason: 'Confirm phone security to remove your TeleVault password',
      );
      if (!ok) {
        _showMessage('Phone security was cancelled. Password was not removed.');
        return;
      }
    } else {
      final currentPassword = await _promptCurrentPassword();
      if (currentPassword == null || currentPassword.isEmpty) return;
      final result = await service.verifySecretForUnlock(currentPassword);
      if (!result.success) {
        _showMessage(_messageForAttempt(result));
        await _refreshAccess();
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await service.removePassword();
      if (config.enabled && phoneAvailable) {
        await service.saveConfig(
          config.copyWith(method: AppLockMethod.biometric),
        );
      }
      await ref.read(appLockControllerProvider.notifier).refresh();
      _showMessage('TeleVault password removed.');
    } finally {
      if (mounted) setState(() => _saving = false);
      await _refreshAccess();
    }
  }

  Future<void> _testPhoneSecurity() async {
    ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
    final ok = await ref
        .read(appLockServiceProvider)
        .authenticatePhoneUnlock(
          reason: 'Confirm phone security for TeleVault',
        );
    _showMessage(ok ? 'Phone security is working.' : 'Phone security failed.');
  }

  Future<void> _saveConfig(AppLockConfig config, {String? secret}) async {
    setState(() => _saving = true);
    try {
      await ref.read(appLockServiceProvider).saveConfig(config, secret: secret);
      await ref.read(appLockControllerProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _saving = false);
      await _refreshAccess();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _promptCurrentPassword() async {
    return showSecureTextDialog(
      context,
      title: 'Enter Current Password',
      fieldLabel: 'TeleVault password',
      actionLabel: 'Continue',
      minLength: 1,
    );
  }

  Future<String?> _promptNewPassword({required String title}) async {
    return showSecureTextDialog(
      context,
      title: title,
      fieldLabel: 'Password',
      actionLabel: 'Save',
      confirmLabel: 'Confirm password',
      minLength: 6,
      minLengthMessage: 'Use at least 6 characters.',
      requireConfirmation: true,
    );
  }

  String _passwordStatusText(AppCredentialLockState state) {
    if (state.permanentlyLocked) {
      return 'Locked after repeated attempts. Reset it with phone security.';
    }
    if (state.isTemporarilyLocked) {
      return 'Temporarily locked. Try again in ${_formatDuration(state.remainingLockout())}.';
    }
    return 'Configured. You can use it instead of phone security.';
  }

  String _messageForAttempt(AppLockSecretAttemptResult result) {
    final state = result.lockState;
    return switch (result.status) {
      AppLockSecretAttemptStatus.notConfigured =>
        'No TeleVault password is set.',
      AppLockSecretAttemptStatus.temporarilyLocked =>
        'Too many wrong attempts. Try again in ${_formatDuration(state.remainingLockout())}.',
      AppLockSecretAttemptStatus.permanentlyLocked =>
        'Password is locked after repeated attempts. Reset it with phone security.',
      AppLockSecretAttemptStatus.invalid =>
        'Wrong password. ${state.attemptsRemaining} attempt(s) left.',
      AppLockSecretAttemptStatus.success => '',
    };
  }
}

class _AppLockSettingsAccess {
  final bool phoneSecurityAvailable;
  final bool passwordConfigured;
  final AppCredentialLockState credentialLockState;

  const _AppLockSettingsAccess({
    required this.phoneSecurityAvailable,
    required this.passwordConfigured,
    required this.credentialLockState,
  });
}

class _SecurityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<Widget> actions;

  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds <= 0 ? 0 : duration.inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}
