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
          themeMode: ThemeMode.dark,
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
}
