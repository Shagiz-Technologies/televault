import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/presentation/splash_screen.dart';
import 'package:tele_vault/src/core/theme/app_theme.dart';

void main() {
  testWidgets('splash is branded and responsive in compact landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('TeleVault'), findsOneWidget);
    expect(find.text('Your media. Your Telegram space.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
