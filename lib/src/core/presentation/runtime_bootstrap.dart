import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app.dart';
import '../../features/settings/presentation/privacy_policy_screen.dart';
import '../../features/settings/presentation/terms_summary_screen.dart';
import '../../features/reviewer_demo/presentation/reviewer_demo_app.dart';
import '../../features/vault/services/vault_service.dart';
import '../config/app_runtime_environment.dart';
import '../config/runtime_environment_store.dart';
import '../theme/app_theme.dart';
import 'responsive_layout.dart';
import 'tele_vault_ui.dart';
import 'televault_logo_mark.dart';

class TeleVaultRuntimeBootstrap extends StatefulWidget {
  final RuntimeEnvironmentStore environmentStore;
  final Future<void> Function() initializeRuntime;

  const TeleVaultRuntimeBootstrap({
    super.key,
    this.environmentStore = const PlatformRuntimeEnvironmentStore(),
    this.initializeRuntime = VaultService.cleanupDefaultTemporaryFiles,
  });

  @override
  State<TeleVaultRuntimeBootstrap> createState() =>
      _TeleVaultRuntimeBootstrapState();
}

class _TeleVaultRuntimeBootstrapState extends State<TeleVaultRuntimeBootstrap> {
  late final RuntimeEnvironmentBootstrapper _bootstrapper;
  AppRuntimeMode? _activeMode;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrapper = RuntimeEnvironmentBootstrapper(widget.environmentStore);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final selected = await _bootstrapper.readInitialMode();
      if (selected != null) {
        await _bootstrapper.initializePersisted(
          selected,
          initializeServices: widget.initializeRuntime,
        );
      }
      if (!mounted) return;
      setState(() {
        _activeMode = selected;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'TeleVault could not prepare its local environment.';
        _busy = false;
      });
    }
  }

  Future<void> _select(AppRuntimeMode mode) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _bootstrapper.activate(
        mode,
        initializeServices: widget.initializeRuntime,
      );
      if (!mounted) return;
      setState(() {
        _activeMode = mode;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'TeleVault could not start the selected environment.';
        _busy = false;
      });
    }
  }

  Future<void> _activateProductionAfterDemo() async {
    if (mounted) {
      setState(() {
        _activeMode = null;
        _busy = true;
        _error = null;
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    await _bootstrapper.activateProductionAfterShutdown(
      initializeServices: widget.initializeRuntime,
    );
    if (!mounted) return;
    setState(() {
      _activeMode = AppRuntimeMode.production;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _activeMode;
    if (mode != null) {
      if (mode == AppRuntimeMode.reviewerDemo) {
        return ReviewerDemoApp(onExitDemo: _activateProductionAfterDemo);
      }
      return ProviderScope(key: ValueKey(mode), child: const TeleVaultApp());
    }

    return MaterialApp(
      title: 'TeleVault',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      home: _RuntimeChoiceScreen(
        busy: _busy,
        error: _error,
        onProduction: () => _select(_bootstrapper.defaultMode),
        onReview: () => _select(AppRuntimeMode.reviewerDemo),
      ),
    );
  }
}

class _RuntimeChoiceScreen extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onProduction;
  final VoidCallback onReview;

  const _RuntimeChoiceScreen({
    required this.busy,
    required this.error,
    required this.onProduction,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TeleVaultPage(
        child: ResponsivePage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TeleVaultLogoMark(size: 82),
              const Gap(24),
              Text(
                'Connect Telegram',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(8),
              const Text(
                'Choose how you are connecting before TeleVault opens any local account data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.inkMuted, height: 1.4),
              ),
              const Gap(28),
              SizedBox(
                width: double.infinity,
                height: AppResponsive.buttonHeight(context),
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onProduction,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.telegram_rounded),
                  label: const Text('Continue with Telegram'),
                ),
              ),
              const Gap(10),
              TextButton.icon(
                onPressed: busy ? null : onReview,
                icon: const Icon(Icons.fact_check_outlined, size: 19),
                label: const Text('Google Play Reviewer Demo'),
              ),
              const Gap(8),
              const Text(
                'Explore sample workflows without signing in. Demo activity stays on this device and never contacts Telegram.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (error != null) ...[
                const Gap(14),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ],
              const Gap(18),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsSummaryScreen(),
                      ),
                    ),
                    child: const Text('Terms'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                    child: const Text('Privacy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
