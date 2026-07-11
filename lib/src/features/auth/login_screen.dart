import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/presentation/responsive_layout.dart';
import '../../core/presentation/televault_logo_mark.dart';
import '../../core/services/telegram_service.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider);
    final authError = ref.watch(authErrorMessageProvider);
    final telegramAvailable = ref.watch(telegramServiceProvider).isAvailable;
    final isLoading =
        status == AuthStatus.loading || ref.watch(authBusyProvider);
    final logoSize = AppResponsive.iconSize(context, regular: 92, compact: 58);

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TeleVaultLogoMark(size: logoSize)
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 600.ms),
            Gap(AppResponsive.gap(context, 30, compact: 14)),
            Text(
              'TeleVault',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ).animate().slideY(begin: 0.3, end: 0, delay: 200.ms).fadeIn(),
            Gap(AppResponsive.gap(context, 10, compact: 6)),
            Text(
              'Enter your phone number to access your secure cloud storage.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ).animate().slideY(begin: 0.3, end: 0, delay: 300.ms).fadeIn(),
            Gap(AppResponsive.gap(context, 40, compact: 18)),
            TextField(
              controller: _phoneCtrl,
              focusNode: _focusNode,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+1 234 567 8900',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
            ).animate().slideY(begin: 0.2, end: 0, delay: 400.ms).fadeIn(),
            Gap(AppResponsive.gap(context, 30, compact: 14)),
            SizedBox(
              width: double.infinity,
              height: AppResponsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: isLoading || !telegramAvailable
                    ? null
                    : () async {
                        if (_phoneCtrl.text.isNotEmpty) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .sendPhone(_phoneCtrl.text);
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
                    : const Text('Continue'),
              ),
            ).animate().slideY(begin: 0.2, end: 0, delay: 500.ms).fadeIn(),
            if (authError != null) ...[
              Gap(AppResponsive.gap(context, 14, compact: 10)),
              Text(
                authError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ],
            Gap(AppResponsive.gap(context, 20, compact: 12)),
            Text(
              'By continuing, you agree to our Terms of Service.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
