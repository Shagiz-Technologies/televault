import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/presentation/responsive_layout.dart';
import '../../core/presentation/tele_vault_ui.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _pwCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider);
    final authError = ref.watch(authErrorMessageProvider);
    final isLoading =
        status == AuthStatus.loading || ref.watch(authBusyProvider);
    final iconSize = AppResponsive.iconSize(context, regular: 60, compact: 42);

    return Scaffold(
      appBar: AppBar(),
      body: TeleVaultPage(
        child: ResponsivePage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.password_rounded,
                size: iconSize,
                color: AppTheme.primary,
              ).animate().scale(duration: 500.ms),
              Gap(AppResponsive.gap(context, 20, compact: 10)),
              Text(
                'Telegram password',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn().slideY(begin: 0.3, end: 0),
              Gap(AppResponsive.gap(context, 10, compact: 6)),
              Text(
                'Your Telegram account uses two-step verification.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ).animate().fadeIn().slideY(begin: 0.3, end: 0, delay: 100.ms),
              Gap(AppResponsive.gap(context, 40, compact: 18)),
              TextField(
                controller: _pwCtrl,
                focusNode: _focusNode,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 18),
                onSubmitted: (val) async {
                  if (val.isNotEmpty) {
                    await ref
                        .read(authControllerProvider.notifier)
                        .sendPassword(val);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 200.ms),
              if (authError != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: AppResponsive.gap(context, 8, compact: 6),
                  ),
                  child: Text(
                    authError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                ),
              Gap(AppResponsive.gap(context, 28, compact: 14)),
              SizedBox(
                width: double.infinity,
                height: AppResponsive.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_pwCtrl.text.isNotEmpty) {
                            await ref
                                .read(authControllerProvider.notifier)
                                .sendPassword(_pwCtrl.text);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Unlock'),
                ),
              ).animate().fadeIn().slideY(begin: 0.5, end: 0, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
