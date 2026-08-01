import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/features/buckets/presentation/bucket_selector_sheet.dart';
import 'package:tele_vault/src/features/buckets/services/bucket_service.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';

void main() {
  testWidgets('shows safe bucket details and switches the active bucket', (
    tester,
  ) async {
    final rows = [
      Bucket(
        id: 1,
        chatId: BigInt.from(1001),
        name: 'Main Photos',
        allowedMediaTypes: 'photo,video',
        isActive: true,
        createdAt: DateTime(2026),
      ),
      Bucket(
        id: 2,
        chatId: BigInt.from(1002),
        name: 'Videos',
        allowedMediaTypes: 'video',
        isActive: false,
        createdAt: DateTime(2026, 1, 2),
      ),
    ];
    final service = _FakeBucketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bucketServiceProvider.overrideWithValue(service),
          bucketListProvider.overrideWith((ref) => Stream.value(rows)),
          bucketSyncPreferencesProvider.overrideWith((ref, bucketId) {
            return Stream.value(
              SyncPreferences(
                autoBackupEnabled: bucketId == 1,
                includePhotos: bucketId == 1,
                includeVideos: true,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const BucketSelectorSheet(),
                ),
                child: const Text('Buckets'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buckets'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Main Photos'), findsOneWidget);
    expect(find.text('Photos + Videos - Auto-sync on'), findsOneWidget);
    expect(find.text('Videos - Auto-sync off'), findsOneWidget);
    expect(find.textContaining('1001'), findsNothing);
    expect(find.textContaining('1002'), findsNothing);

    await tester.tap(find.text('Videos'));
    await tester.pump();

    expect(service.selectedBucketId, 2);
  });
}

class _FakeBucketService implements BucketService {
  int? selectedBucketId;

  @override
  Future<void> setActiveBucket(int bucketId) async {
    selectedBucketId = bucketId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
