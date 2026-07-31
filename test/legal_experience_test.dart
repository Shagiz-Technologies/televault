import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/legal_urls.dart';
import 'package:tele_vault/src/core/services/external_url_service.dart';
import 'package:tele_vault/src/features/auth/login_screen.dart';
import 'package:tele_vault/src/features/settings/presentation/legal_support_section.dart';
import 'package:tele_vault/src/features/settings/presentation/privacy_policy_screen.dart';

Widget _testApp({required Widget child, required ExternalUrlService service}) {
  return ProviderScope(
    overrides: [externalUrlServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('settings legal section exposes every required destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        child: const LegalSupportSection(),
        service: ExternalUrlService(launcher: (_) async => true),
      ),
    );

    expect(find.text('Legal & Support'), findsOneWidget);
    for (final label in <String>[
      'Privacy Policy',
      'Terms of Service',
      'Data & Deletion',
      'Support',
      'Security',
      'Open-source licenses',
      'Source code',
      'About TeleVault',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('login legal links open the canonical URLs', (tester) async {
    final opened = <Uri>[];
    final service = ExternalUrlService(
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.pumpWidget(
      _testApp(child: const LoginLegalNotice(), service: service),
    );

    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();

    expect(opened, [
      Uri.parse(LegalUrls.termsOfService),
      Uri.parse(LegalUrls.privacyPolicy),
    ]);
  });

  testWidgets('URL-opening failure shows a clear message', (tester) async {
    await tester.pumpWidget(
      _testApp(
        child: const LoginLegalNotice(),
        service: ExternalUrlService(launcher: (_) async => false),
      ),
    );

    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();

    expect(
      find.text('No browser is available to open this link.'),
      findsOneWidget,
    );
  });

  testWidgets('privacy summary states Telegram and encryption boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalUrlServiceProvider.overrideWithValue(
            ExternalUrlService(launcher: (_) async => true),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const PrivacyPolicyScreen(),
        ),
      ),
    );

    expect(find.text('Last policy update: July 29, 2026'), findsOneWidget);
    expect(find.text('Telegram is the storage provider'), findsOneWidget);
    expect(find.text('Encryption boundary'), findsOneWidget);
    expect(find.text('Read full Privacy Policy'), findsOneWidget);
    expect(
      find.textContaining(
        'Normal non-vault media is not currently client-side encrypted',
      ),
      findsOneWidget,
    );
  });
}
