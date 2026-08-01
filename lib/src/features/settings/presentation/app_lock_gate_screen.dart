import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/secure_text_dialog.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';
import '../services/app_lock_controller.dart';
import '../services/app_lock_service.dart';

class AppLockGateScreen extends ConsumerStatefulWidget {
  const AppLockGateScreen({super.key});

  @override
  ConsumerState<AppLockGateScreen> createState() => _AppLockGateScreenState();
}

class _AppLockGateScreenState extends ConsumerState<AppLockGateScreen> {
  final _passwordCtrl = TextEditingController();
  late Future<_AppLockAccess> _accessFuture;
  Timer? _lockoutTimer;

  AppCredentialLockState? _credentialLockState;
  bool _processing = false;
  bool _resetting = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
    _loadCredentialLockState();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = _credentialLockState;
      if (!mounted || state?.lockedUntil == null) return;
      if (state!.lockedUntil!.isAfter(DateTime.now())) {
        setState(() {});
      } else {
        _loadCredentialLockState();
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<_AppLockAccess> _loadAccess() async {
    final service = ref.read(appLockServiceProvider);
    final results = await Future.wait([
      service.canUsePhoneUnlock(),
      service.hasSecretConfigured(),
    ]);
    return _AppLockAccess(
      phoneSecurityAvailable: results[0],
      passwordConfigured: results[1],
    );
  }

  Future<void> _loadCredentialLockState() async {
    final state = await ref
        .read(appLockServiceProvider)
        .getCredentialLockState();
    if (!mounted) return;
    setState(() => _credentialLockState = state);
  }

  Future<void> _refreshAccess() async {
    setState(() => _accessFuture = _loadAccess());
    await _loadCredentialLockState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LockBackdrop(),
          ResponsivePage(
            maxWidth: 430,
            child: FutureBuilder<_AppLockAccess>(
              future: _accessFuture,
              builder: (context, snapshot) {
                final access = snapshot.data;
                return _LockCard(
                  access: access,
                  loadingAccess:
                      snapshot.connectionState != ConnectionState.done,
                  processing: _processing,
                  resetting: _resetting,
                  error: _error,
                  notice: _notice,
                  credentialLockState: _credentialLockState,
                  passwordController: _passwordCtrl,
                  onPhoneUnlock: _unlockWithPhoneSecurity,
                  onPasswordUnlock: _unlockWithPassword,
                  onResetPassword: _resetPasswordWithPhoneSecurity,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockWithPassword() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() {
        _notice = null;
        _error = 'Enter your TeleVault password first.';
      });
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _notice = null;
    });

    final result = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithSecret(password);
    if (!mounted) return;

    setState(() {
      _processing = false;
      _credentialLockState = result.lockState;
      _error = result.success ? null : _messageForAttempt(result);
      if (result.success) _passwordCtrl.clear();
    });
  }

  Future<void> _unlockWithPhoneSecurity() async {
    setState(() {
      _processing = true;
      _error = null;
      _notice = null;
    });

    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPhoneSecurity();
    if (!mounted) return;

    setState(() {
      _processing = false;
      _error = ok
          ? null
          : 'Phone security was cancelled or is not available on this device.';
      if (ok) _passwordCtrl.clear();
    });
    if (ok) await _loadCredentialLockState();
  }

  Future<void> _resetPasswordWithPhoneSecurity() async {
    setState(() {
      _resetting = true;
      _error = null;
      _notice = null;
    });

    final service = ref.read(appLockServiceProvider);
    ref.read(appLockControllerProvider.notifier).allowExternalSystemPrompt();
    final ok = await service.authenticatePhoneUnlock(
      reason: 'Confirm phone security to reset your TeleVault password',
    );
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _resetting = false;
        _error = 'Phone security was cancelled. Password was not reset.';
      });
      return;
    }

    final newPassword = await _promptNewPassword();
    if (!mounted) return;
    if (newPassword == null || newPassword.isEmpty) {
      setState(() => _resetting = false);
      return;
    }

    await service.savePassword(newPassword);
    await ref.read(appLockControllerProvider.notifier).refresh();
    final result = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithSecret(newPassword);
    if (!mounted) return;

    setState(() {
      _resetting = false;
      _credentialLockState = result.lockState;
      _passwordCtrl.clear();
      _notice = 'TeleVault password reset.';
      _error = result.success ? null : 'Password was reset but unlock failed.';
    });
    await _refreshAccess();
  }

  Future<String?> _promptNewPassword() async {
    return showSecureTextDialog(
      context,
      title: 'Set TeleVault Password',
      fieldLabel: 'New password',
      actionLabel: 'Save',
      confirmLabel: 'Confirm password',
      minLength: 6,
      minLengthMessage: 'Use at least 6 characters.',
      requireConfirmation: true,
    );
  }

  String _messageForAttempt(AppLockSecretAttemptResult result) {
    final state = result.lockState;
    return switch (result.status) {
      AppLockSecretAttemptStatus.notConfigured =>
        'No TeleVault password is set. Use phone security to unlock.',
      AppLockSecretAttemptStatus.temporarilyLocked =>
        'Too many wrong attempts. Try again in ${_formatDuration(state.remainingLockout())}.',
      AppLockSecretAttemptStatus.permanentlyLocked =>
        'TeleVault password is locked after repeated attempts. Use phone security to reset it.',
      AppLockSecretAttemptStatus.invalid =>
        'Wrong password. ${state.attemptsRemaining} attempt(s) left before a wait is required.',
      AppLockSecretAttemptStatus.success => '',
    };
  }
}

class _AppLockAccess {
  final bool phoneSecurityAvailable;
  final bool passwordConfigured;

  const _AppLockAccess({
    required this.phoneSecurityAvailable,
    required this.passwordConfigured,
  });
}

class _LockCard extends StatelessWidget {
  final _AppLockAccess? access;
  final bool loadingAccess;
  final bool processing;
  final bool resetting;
  final AppCredentialLockState? credentialLockState;
  final TextEditingController passwordController;
  final String? error;
  final String? notice;
  final VoidCallback onPhoneUnlock;
  final VoidCallback onPasswordUnlock;
  final VoidCallback onResetPassword;

  const _LockCard({
    required this.access,
    required this.loadingAccess,
    required this.processing,
    required this.resetting,
    required this.credentialLockState,
    required this.passwordController,
    required this.onPhoneUnlock,
    required this.onPasswordUnlock,
    required this.onResetPassword,
    this.error,
    this.notice,
  });

  @override
  Widget build(BuildContext context) {
    final phoneAvailable = access?.phoneSecurityAvailable == true;
    final passwordConfigured = access?.passwordConfigured == true;
    final state = credentialLockState;
    final passwordTemporarilyLocked = state?.isTemporarilyLocked == true;
    final passwordPermanentlyLocked = state?.permanentlyLocked == true;
    final canUsePassword =
        passwordConfigured &&
        !passwordTemporarilyLocked &&
        !passwordPermanentlyLocked &&
        !processing &&
        !resetting;
    final compact = AppResponsive.isCompactHeight(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            22,
            compact ? 18 : 24,
            22,
            compact ? 18 : 22,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.18),
                blurRadius: 42,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TeleVaultLogoMark(
                  size: AppResponsive.iconSize(
                    context,
                    regular: 88,
                    compact: 54,
                  ),
                ),
              ),
              SizedBox(height: AppResponsive.gap(context, 20, compact: 10)),
              const Text(
                'TeleVault is locked',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.ink,
                ),
              ),
              SizedBox(height: AppResponsive.gap(context, 8, compact: 6)),
              const Text(
                'Use your phone security to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14.5,
                  height: 1.35,
                ),
              ),
              SizedBox(height: AppResponsive.gap(context, 22, compact: 12)),
              if (phoneAvailable) ...[
                SizedBox(
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton.icon(
                    onPressed: processing || resetting ? null : onPhoneUnlock,
                    icon: Icon(
                      processing
                          ? Icons.hourglass_top_rounded
                          : Icons.phonelink_lock_rounded,
                    ),
                    label: Text(
                      processing
                          ? 'Checking phone security...'
                          : 'Unlock with phone',
                    ),
                  ),
                ),
                SizedBox(height: AppResponsive.gap(context, 12, compact: 8)),
                const _TrustHint(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Works with fingerprint, face unlock, phone PIN, pattern, or phone password depending on this device.',
                ),
              ] else if (!loadingAccess) ...[
                const _TrustHint(
                  icon: Icons.phonelink_erase_rounded,
                  text:
                      'Phone security is not available. Set up a device passcode or biometric in system settings to use it here.',
                ),
              ],
              if (passwordConfigured) ...[
                SizedBox(height: AppResponsive.gap(context, 18, compact: 10)),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.outline)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.outline)),
                  ],
                ),
                SizedBox(height: AppResponsive.gap(context, 18, compact: 10)),
                _PasswordUnlockForm(
                  controller: passwordController,
                  enabled: canUsePassword,
                  lockState: state,
                  processing: processing,
                  onSubmit: onPasswordUnlock,
                ),
                if (phoneAvailable) ...[
                  SizedBox(height: AppResponsive.gap(context, 8, compact: 6)),
                  TextButton.icon(
                    onPressed: resetting ? null : onResetPassword,
                    icon: Icon(
                      resetting
                          ? Icons.hourglass_top_rounded
                          : Icons.restart_alt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      resetting
                          ? 'Resetting password...'
                          : 'Forgot password? Reset with phone security',
                    ),
                  ),
                ],
              ],
              SizedBox(height: AppResponsive.gap(context, 18, compact: 10)),
              const Text(
                'By Shagiz Technologies',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.2,
                ),
              ),
              if (notice != null) ...[
                SizedBox(height: AppResponsive.gap(context, 14, compact: 8)),
                _MessageBox(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.success,
                  text: notice!,
                ),
              ],
              if (error != null) ...[
                SizedBox(height: AppResponsive.gap(context, 14, compact: 8)),
                _MessageBox(
                  icon: Icons.info_outline_rounded,
                  color: AppTheme.error,
                  text: error!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordUnlockForm extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool processing;
  final AppCredentialLockState? lockState;
  final VoidCallback onSubmit;

  const _PasswordUnlockForm({
    required this.controller,
    required this.enabled,
    required this.processing,
    required this.lockState,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final lockedUntil = lockState?.lockedUntil;
    final temporarilyLocked = lockState?.isTemporarilyLocked == true;
    final permanentlyLocked = lockState?.permanentlyLocked == true;

    final helperText = permanentlyLocked
        ? 'Password unlock is disabled until reset.'
        : temporarilyLocked
        ? 'Try again in ${_formatDuration(lockState!.remainingLockout())}.'
        : '5 wrong attempts trigger a short wait.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.visiblePassword,
          obscureText: true,
          maxLength: 128,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (enabled) onSubmit();
          },
          decoration: InputDecoration(
            labelText: 'TeleVault password',
            helperText: helperText,
            prefixIcon: const Icon(Icons.key_rounded),
            counterText: '',
          ),
        ),
        SizedBox(height: AppResponsive.gap(context, 14, compact: 8)),
        SizedBox(
          height: AppResponsive.buttonHeight(context),
          child: ElevatedButton.icon(
            onPressed: enabled ? onSubmit : null,
            icon: Icon(
              processing ? Icons.hourglass_top_rounded : Icons.lock_open,
            ),
            label: Text(
              processing
                  ? 'Unlocking...'
                  : temporarilyLocked && lockedUntil != null
                  ? 'Wait ${_formatDuration(lockState!.remainingLockout())}'
                  : permanentlyLocked
                  ? 'Password Locked'
                  : 'Unlock with Password',
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MessageBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBackdrop extends StatelessWidget {
  const _LockBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF6FF), AppTheme.paper],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _GlowOrb(
              size: 260,
              color: AppTheme.primary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            left: -130,
            bottom: 120,
            child: _GlowOrb(
              size: 320,
              color: AppTheme.success.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 35)],
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
