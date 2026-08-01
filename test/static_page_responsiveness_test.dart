import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/theme/app_theme.dart';
import 'package:tele_vault/src/features/settings/presentation/about_screen.dart';
import 'package:tele_vault/src/features/settings/presentation/privacy_policy_screen.dart';
import 'package:tele_vault/src/features/settings/presentation/release_log_screen.dart';

void main() {
  for (final page in <({String title, Widget widget})>[
    (title: 'About TeleVault', widget: const AboutScreen()),
    (title: 'Privacy & transparency', widget: const PrivacyPolicyScreen()),
    (title: "What's new", widget: const ReleaseLogScreen()),
  ]) {
    testWidgets('${page.title} is responsive in compact landscape', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(640, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: page.widget),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(page.title), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
