import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/presentation/secure_text_dialog.dart';
import 'package:tele_vault/src/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'secure text dialog has visible borders, safe cancel, and optional confirmation',
    (tester) async {
      String? result = 'unchanged';

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.light,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showSecureTextDialog(
                      context,
                      title: 'Set Password',
                      fieldLabel: 'Password',
                      actionLabel: 'Save',
                      confirmLabel: 'Confirm password',
                      minLength: 6,
                      requireConfirmation: true,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      final border = field.decoration?.enabledBorder;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border as OutlineInputBorder).borderSide.style,
        BorderStyle.solid,
      );
      expect(border.borderSide.width, greaterThan(0));
      expect(field.style?.color, isNot(Colors.white));

      await tester.tap(find.byTooltip('Show').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm password'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'secret1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, 'secret1');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('secure text dialog remains usable in compact landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                showSecureTextDialog(
                  context,
                  title: 'Safe Uninstall',
                  description:
                      'Protect the metadata snapshot with a passphrase.',
                  fieldLabel: 'Passphrase',
                  actionLabel: 'Continue',
                  confirmLabel: 'Confirm passphrase',
                  minLength: 8,
                  requireConfirmation: true,
                );
              },
              child: const Text('Open compact dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open compact dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Safe Uninstall'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
