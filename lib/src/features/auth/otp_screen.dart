import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pinput/pinput.dart';

import '../../core/presentation/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _resendTimer;
  int _resendCountdown = 59;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown -= 1);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authError = ref.watch(authErrorMessageProvider);
    final isBusy = ref.watch(authBusyProvider);
    final iconSize = AppResponsive.iconSize(context, regular: 60, compact: 42);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            unawaited(
              ref.read(authControllerProvider.notifier).backToPhoneInput(),
            );
          },
        ),
      ),
      body: ResponsivePage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_unread_rounded,
              size: iconSize,
              color: AppTheme.primary,
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            Gap(AppResponsive.gap(context, 20, compact: 10)),
            Text(
              'Check your Telegram',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn().slideY(begin: 0.3, end: 0),
            Gap(AppResponsive.gap(context, 10, compact: 6)),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                children: const [
                  TextSpan(text: 'Enter the verification code sent to your '),
                  TextSpan(
                    text: 'Telegram app',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.3, end: 0, delay: 100.ms),
            Gap(AppResponsive.gap(context, 42, compact: 18)),
            LayoutBuilder(
              builder: (context, constraints) {
                final pinWidth = ((constraints.maxWidth - 40) / 5)
                    .clamp(42.0, 56.0)
                    .toDouble();
                final pinHeight = AppResponsive.isCompactHeight(context)
                    ? 54.0
                    : 64.0;
                final pinTheme = PinTheme(
                  width: pinWidth,
                  height: pinHeight,
                  textStyle: TextStyle(
                    fontSize: AppResponsive.isCompactHeight(context) ? 20 : 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.transparent),
                  ),
                );
                return Pinput(
                  controller: _codeCtrl,
                  focusNode: _focusNode,
                  length: 5,
                  defaultPinTheme: pinTheme,
                  focusedPinTheme: pinTheme.copyWith(
                    decoration: pinTheme.decoration!.copyWith(
                      border: Border.all(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onCompleted: (pin) {
                    unawaited(
                      ref.read(authControllerProvider.notifier).sendCode(pin),
                    );
                  },
                );
              },
            ).animate().fadeIn().slideY(begin: 0.2, end: 0, delay: 200.ms),
            if (isBusy) ...[
              Gap(AppResponsive.gap(context, 16, compact: 10)),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
            if (authError != null) ...[
              Gap(AppResponsive.gap(context, 16, compact: 10)),
              Text(
                authError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ],
            Gap(AppResponsive.gap(context, 26, compact: 14)),
            TextButton(
              onPressed: _resendCountdown == 0 && !isBusy
                  ? () {
                      unawaited(
                        ref.read(authControllerProvider.notifier).resendCode(),
                      );
                      _startResendTimer();
                    }
                  : null,
              child: Text(
                _resendCountdown == 0
                    ? 'Resend Code'
                    : 'Resend Code in 00:${_resendCountdown.toString().padLeft(2, '0')}',
              ),
            ).animate().fadeIn(delay: 1.seconds),
          ],
        ),
      ),
    );
  }
}
