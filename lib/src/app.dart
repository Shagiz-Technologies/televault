import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/presentation/splash_screen.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/password_screen.dart';
import 'features/buckets/presentation/bucket_setup_screen.dart';
import 'features/buckets/services/bucket_service.dart';
import 'features/home/presentation/main_screen.dart';
import 'features/settings/presentation/app_lock_gate_screen.dart';
import 'features/settings/services/app_lock_controller.dart';
import 'features/settings/services/settings_service.dart';
import 'features/sync/services/sync_initializer.dart';

class TeleVaultApp extends ConsumerStatefulWidget {
  const TeleVaultApp({super.key});

  @override
  ConsumerState<TeleVaultApp> createState() => _TeleVaultAppState();
}

class _TeleVaultAppState extends ConsumerState<TeleVaultApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(authControllerProvider.notifier)
          .refreshAuthorizationState(preserveCurrentState: true);
      unawaited(ref.read(syncInitializerProvider).ensureStarted());
      ref.read(appLockControllerProvider.notifier).onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(appLockControllerProvider.notifier).onAppBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final textScaleStream = ref
        .watch(settingsServiceProvider)
        .watchUiTextScale();

    ref.listen<AuthStatus>(authControllerProvider, (previous, next) {
      if (next == AuthStatus.loggedIn) {
        unawaited(ref.read(syncInitializerProvider).ensureStarted());
      }
    });

    return StreamBuilder<double>(
      stream: textScaleStream,
      initialData: 1.0,
      builder: (context, textScaleSnapshot) {
        final textScale = textScaleSnapshot.data ?? 1.0;

        return MaterialApp(
          title: 'TeleVault',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Consumer(
            builder: (context, ref, _) {
              final status = ref.watch(authControllerProvider);

              if (status == AuthStatus.loading) {
                return const SplashScreen();
              }

              final appHome = switch (status) {
                AuthStatus.loggedIn =>
                  ref
                      .watch(bucketPresenceProvider)
                      .when(
                        data: (hasBuckets) => hasBuckets
                            ? const MainScreen()
                            : const BucketSetupScreen(),
                        loading: () => const SplashScreen(),
                        error: (_, _) => const BucketSetupScreen(),
                      ),
                AuthStatus.enterPhone => const LoginScreen(),
                AuthStatus.enterCode => const OtpScreen(),
                AuthStatus.enterPassword => const PasswordScreen(),
                AuthStatus.error => const LoginScreen(),
                _ => const SplashScreen(),
              };

              if (status == AuthStatus.loggedIn &&
                  lockState.initialized &&
                  lockState.enabled &&
                  lockState.locked) {
                return Stack(
                  children: [
                    appHome,
                    const Positioned.fill(child: AppLockGateScreen()),
                  ],
                );
              }

              return appHome;
            },
          ),
        );
      },
    );
  }
}
