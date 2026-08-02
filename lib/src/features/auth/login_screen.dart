import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/presentation/responsive_layout.dart';
import '../../core/presentation/tele_vault_ui.dart';
import '../../core/presentation/televault_logo_mark.dart';
import '../../core/config/runtime_host_actions.dart';
import '../../core/services/telegram_service.dart';
import '../../core/theme/app_theme.dart';
import '../settings/presentation/privacy_policy_screen.dart';
import '../settings/presentation/terms_summary_screen.dart';
import '../reviewer_demo/services/production_runtime_shutdown_service.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _enteringReviewerDemo = false;

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
      body: TeleVaultPage(
        child: ResponsivePage(
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
                'Connect Telegram',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().slideY(begin: 0.3, end: 0, delay: 200.ms).fadeIn(),
              Gap(AppResponsive.gap(context, 10, compact: 6)),
              Text(
                'TeleVault uses your account to reach your private backup channels.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ).animate().slideY(begin: 0.3, end: 0, delay: 300.ms).fadeIn(),
              Gap(AppResponsive.gap(context, 40, compact: 18)),
              TeleVaultCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _phoneCtrl,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+000 000 000 000',
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                      ),
                    ),
                    const Gap(12),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TeleVaultIconBadge(
                          icon: Icons.verified_user_outlined,
                          color: AppTheme.success,
                          size: 38,
                        ),
                        Gap(10),
                        Expanded(
                          child: Text(
                            'Your login is handled by TDLib on this device.',
                            style: TextStyle(
                              color: AppTheme.inkMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading || _enteringReviewerDemo
                      ? null
                      : _openReviewerDemo,
                  icon: _enteringReviewerDemo
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: const Text('Google Play Reviewer Demo'),
                ),
              ),
              if (authError != null) ...[
                Gap(AppResponsive.gap(context, 14, compact: 10)),
                Text(
                  authError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],
              Gap(AppResponsive.gap(context, 18, compact: 10)),
              Text(
                'By continuing, you agree to the Terms of Service and acknowledge the Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 700.ms),
              const Gap(4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsSummaryScreen(),
                        ),
                      );
                    },
                    child: const Text('Terms of Service'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ).animate().fadeIn(delay: 800.ms),
              const Gap(4),
              Text(
                'TeleVault is independent and not affiliated with Telegram.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewerDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open Reviewer Demo?'),
        content: const Text(
          'TeleVault will pause normal background work and open a separate demo with sample data. Your Telegram session, media, buckets, and settings will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open demo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _enteringReviewerDemo = true);
    try {
      await ref
          .read(productionRuntimeShutdownServiceProvider)
          .shutdownForReviewerDemo();
      await ref
          .read(runtimeHostActionsProvider)
          .activateReviewerDemoAfterProduction();
    } catch (_) {
      if (!mounted) return;
      setState(() => _enteringReviewerDemo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reviewer Demo could not start. No data was deleted.'),
        ),
      );
    }
  }
}
