import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/theme/app_theme.dart';
import 'package:tele_vault/src/features/vault/presentation/vault_pin_screen.dart';
import 'package:tele_vault/src/features/vault/services/vault_pin_service.dart';

void main() {
  late AppDatabase db;
  late _FakeVaultPinService vaultPinService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    vaultPinService = _FakeVaultPinService(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'Vault entry redirects to setup when no credential exists and clears values across methods',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultPinServiceProvider.overrideWithValue(vaultPinService),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: AppTheme.darkTheme,
            home: const VaultPinScreen(mode: VaultPinMode.unlock),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Protect your Vault'), findsOneWidget);
      expect(
        find.text('Set Vault security before adding private files.'),
        findsOneWidget,
      );

      final scrollable = find.byType(Scrollable).first;
      final secretField = find.byKey(const ValueKey('vault-secret-field'));
      final confirmField = find.byKey(
        const ValueKey('vault-confirm-secret-field'),
      );
      await tester.scrollUntilVisible(secretField, 300, scrollable: scrollable);
      await tester.enterText(secretField, '1234');
      await tester.enterText(confirmField, '1234');

      await tester.scrollUntilVisible(
        find.text('Password'),
        -300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(secretField, 300, scrollable: scrollable);
      expect(tester.widget<TextField>(secretField).controller?.text, isEmpty);
      expect(tester.widget<TextField>(confirmField).controller?.text, isEmpty);

      await tester.enterText(secretField, 'secret1');
      await tester.tap(find.byTooltip('Show').first);
      await tester.pumpAndSettle();

      expect(secretField, findsOneWidget);
      expect(find.text('Confirm Password'), findsNothing);
      expect(tester.widget<TextField>(secretField).controller?.text, 'secret1');
    },
  );

  testWidgets(
    'Phone Security reset does not ask for current credential up front',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultPinServiceProvider.overrideWithValue(
              _ConfiguredPhoneSecurityVaultPinService(db),
            ),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: AppTheme.darkTheme,
            home: const VaultPinScreen(mode: VaultPinMode.set),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vault security'), findsOneWidget);
      expect(find.text('Phone Security'), findsOneWidget);
      expect(find.text('Current Password'), findsNothing);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('vault-secret-field')),
        300,
        scrollable: scrollable,
      );
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    },
  );
}

class _FakeVaultPinService extends VaultPinService {
  // ignore: use_super_parameters
  _FakeVaultPinService(AppDatabase db) : super(db);

  @override
  Future<bool> isPinConfigured() async => false;

  @override
  Future<VaultAuthMethod> getAuthMethod() async => VaultAuthMethod.pin;

  @override
  Future<bool> canUseBiometrics() async => true;
}

class _ConfiguredPhoneSecurityVaultPinService extends VaultPinService {
  // ignore: use_super_parameters
  _ConfiguredPhoneSecurityVaultPinService(AppDatabase db) : super(db);

  @override
  Future<bool> isPinConfigured() async => true;

  @override
  Future<VaultAuthMethod> getAuthMethod() async => VaultAuthMethod.biometric;

  @override
  Future<bool> canUseBiometrics() async => true;
}
