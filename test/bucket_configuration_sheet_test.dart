import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/buckets/presentation/bucket_configuration_sheet.dart';
import 'package:tele_vault/src/features/buckets/services/bucket_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';

void main() {
  testWidgets('returns the bucket choices selected before creation', (
    tester,
  ) async {
    BucketCreationConfiguration? selectedConfiguration;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedConfiguration = await showBucketConfigurationSheet(
                    context: context,
                    bucketName: 'Demo',
                    initialPreferences: const SyncPreferences(),
                    albums: const [],
                    isTelegramPremium: false,
                  );
                },
                child: const Text('Configure'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();

    expect(find.text('New backup space'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);

    await tester.tap(find.text('Videos'));
    await tester.tap(find.text('Auto-sync this bucket'));
    final compressedOption = find.widgetWithText(ListTile, 'Compressed media');
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(compressedOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create bucket'));
    await tester.pumpAndSettle();

    final configuration = selectedConfiguration;
    expect(configuration, isNotNull);
    expect(configuration!.allowedTypes, {BucketMediaType.photo});
    expect(configuration.preferences.includePhotos, isTrue);
    expect(configuration.preferences.includeVideos, isFalse);
    expect(configuration.preferences.autoBackupEnabled, isFalse);
    expect(
      configuration.preferences.uploadFormat,
      SyncUploadFormat.compressedMedia,
    );
  });
}
