import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/settings/presentation/privacy_policy_screen.dart';
import 'package:tele_vault/src/features/settings/presentation/terms_summary_screen.dart';

void main() {
  testWidgets('privacy summary states the Telegram and encryption boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

    expect(find.textContaining('not affiliated'), findsOneWidget);
    expect(
      find.textContaining('Normal non-vault photos and videos are not'),
      findsOneWidget,
    );
    expect(find.textContaining('Recovery Key'), findsWidgets);
    expect(find.textContaining('do not automatically delete'), findsOneWidget);
  });

  testWidgets('terms summary avoids unconditional storage guarantees', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TermsSummaryScreen()));

    expect(find.textContaining('Android may defer'), findsOneWidget);
    expect(
      find.textContaining('not client-side end-to-end encrypted'),
      findsOneWidget,
    );
    expect(find.textContaining('independent backup'), findsOneWidget);
  });
}
