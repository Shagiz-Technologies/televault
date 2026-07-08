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

      expect(find.text('Set Vault Security'), findsOneWidget);
      expect(find.textContaining('Set a Vault PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(1), '1234');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Password'));
      await tester.pumpAndSettle();

      final passwordFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(passwordFields, hasLength(2));
      expect(passwordFields[0].controller?.text, isEmpty);
      expect(passwordFields[1].controller?.text, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'secret1');
      await tester.tap(find.byTooltip('Show').first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Confirm Password'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'secret1',
      );
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

      expect(find.text('Vault Security'), findsOneWidget);
      expect(find.text('Phone Security'), findsOneWidget);
      expect(find.text('Current Password'), findsNothing);
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
