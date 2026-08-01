import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'televault_logo_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.75, -0.9),
            radius: 1.35,
            colors: [Color(0xFFE9F6FF), AppTheme.paper],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _entrance,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(_entrance),
                child: Semantics(
                  label: 'TeleVault is starting',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.outline),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              blurRadius: 32,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const TeleVaultLogoMark(size: 86),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TeleVault',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your media. Your Telegram space.',
                        style: TextStyle(
                          color: AppTheme.inkMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 112,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
