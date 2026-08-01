import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/theme/app_theme.dart';
import 'package:tele_vault/src/features/library/presentation/widgets/label_editor_dialog.dart';

void main() {
  testWidgets('label editor accepts symbols and returns the selected color', (
    tester,
  ) async {
    LabelEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showLabelEditorDialog(context);
              },
              child: const Text('Open label editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open label editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('label-name-field')),
      '★Trip',
    );
    await tester.tap(find.byKey(const ValueKey('label-color-#14A37F')));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.name, '★Trip');
    expect(result?.colorHex, '#14A37F');
    expect(tester.takeException(), isNull);
  });

  testWidgets('label editor validates empty names in compact landscape', (
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
              onPressed: () => showLabelEditorDialog(context),
              child: const Text('Open label editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open label editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a label name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
