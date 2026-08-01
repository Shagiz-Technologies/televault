import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/library/presentation/library_screen.dart';
import 'package:tele_vault/src/features/sync/services/sync_status_service.dart';

void main() {
  testWidgets('shows live uploading, failed, and complete bucket states', (
    tester,
  ) async {
    var taps = 0;

    Future<void> pumpStatus(SyncStatusSnapshot status) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                LibraryBucketStatusAction(
                  bucketName: 'Main',
                  status: AsyncValue.data(status),
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
    }

    await pumpStatus(_status(pending: 2, uploading: 1, progress: 0.45));
    expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);

    await pumpStatus(_status(failed: 3));
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await pumpStatus(_status(completed: 8));
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}

SyncStatusSnapshot _status({
  int pending = 0,
  int uploading = 0,
  int completed = 0,
  int failed = 0,
  double progress = 0,
}) {
  final total = pending + uploading + completed + failed;
  return SyncStatusSnapshot(
    pendingCount: pending,
    uploadingCount: uploading,
    completedCount: completed,
    failedCount: failed,
    totalCount: total,
    totalBytes: total * 100,
    completedBytes: completed * 100,
    uploadingBytes: uploading * 100,
    failedBytes: failed * 100,
    activeUploadProgress: progress,
  );
}
