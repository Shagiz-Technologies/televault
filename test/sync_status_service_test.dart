import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/features/sync/services/sync_status_service.dart';

void main() {
  late AppDatabase db;
  late StreamController<Map<String, double>> progress;
  late SyncStatusService service;
  late int bucketId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    progress = StreamController<Map<String, double>>.broadcast();
    service = SyncStatusService(db, progress.stream);
    bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(chatId: BigInt.from(1001), name: 'Photos'),
        );
  });

  tearDown(() async {
    await progress.close();
    await db.close();
  });

  Future<int> insertFile({
    required String path,
    required int size,
    required FileSyncStatus status,
  }) {
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: path,
            folderName: 'Camera',
            size: size,
            bucketId: bucketId,
            status: Value(status.dbValue),
          ),
        );
  }

  test('reports live counts and byte progress for one bucket', () async {
    final pendingId = await insertFile(
      path: '/demo/pending.jpg',
      size: 100,
      status: FileSyncStatus.pending,
    );
    await insertFile(
      path: '/demo/done.jpg',
      size: 300,
      status: FileSyncStatus.synced,
    );
    await insertFile(
      path: '/demo/failed.jpg',
      size: 50,
      status: FileSyncStatus.failed,
    );

    final initial = await service
        .watch(bucketIds: {bucketId})
        .firstWhere((snapshot) => snapshot.totalCount == 3);

    expect(initial.pendingCount, 1);
    expect(initial.completedCount, 1);
    expect(initial.failedCount, 1);
    expect(initial.totalBytes, 450);
    expect(initial.completedBytes, 300);

    await (db.update(db.files)..where((row) => row.id.equals(pendingId))).write(
      FilesCompanion(status: Value(FileSyncStatus.uploading.dbValue)),
    );
    final uploadingFuture = service
        .watch(bucketIds: {bucketId})
        .firstWhere(
          (snapshot) =>
              snapshot.uploadingCount == 1 &&
              snapshot.activeUploadProgress == 0.5,
        );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    progress.add({'/demo/pending.jpg': 0.5});
    final uploading = await uploadingFuture;

    expect(uploading.pendingCount, 0);
    expect(uploading.transferredBytes, 350);
    expect(uploading.overallProgress, closeTo(350 / 450, 0.001));

    await (db.update(db.files)..where((row) => row.id.equals(pendingId))).write(
      FilesCompanion(status: Value(FileSyncStatus.synced.dbValue)),
    );
    final completed = await service
        .watch(bucketIds: {bucketId})
        .firstWhere((snapshot) => snapshot.completedCount == 2);

    expect(completed.uploadingCount, 0);
    expect(completed.completedBytes, 400);
    expect(completed.transferredBytes, 400);
  });

  test(
    'activity is scoped to one bucket and prioritizes live states',
    () async {
      final otherBucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(chatId: BigInt.from(1002), name: 'Other'),
          );
      final now = DateTime.now();
      for (final entry in [
        (
          'done.jpg',
          FileSyncStatus.synced,
          now.subtract(const Duration(days: 3)),
        ),
        (
          'queued.jpg',
          FileSyncStatus.pending,
          now.subtract(const Duration(days: 2)),
        ),
        (
          'failed.jpg',
          FileSyncStatus.failed,
          now.subtract(const Duration(days: 1)),
        ),
        ('uploading.jpg', FileSyncStatus.uploading, now),
      ]) {
        await db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                localPath: '/demo/${entry.$1}',
                folderName: 'Camera',
                size: 100,
                bucketId: bucketId,
                status: Value(entry.$2.dbValue),
                dateAdded: Value(entry.$3),
              ),
            );
      }
      await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/other.jpg',
              folderName: 'Camera',
              size: 100,
              bucketId: otherBucketId,
              status: Value(FileSyncStatus.uploading.dbValue),
            ),
          );

      final activity = await service
          .watchActivity(bucketId: bucketId)
          .firstWhere((items) => items.length == 4);

      expect(activity.map((item) => item.status), [
        FileSyncStatus.uploading,
        FileSyncStatus.synced,
        FileSyncStatus.pending,
        FileSyncStatus.failed,
      ]);
      expect(
        activity.every((item) => !item.localPath.endsWith('other.jpg')),
        isTrue,
      );
    },
  );
}
