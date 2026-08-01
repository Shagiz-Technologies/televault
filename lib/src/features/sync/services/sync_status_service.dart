import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/file_sync_status.dart';
import 'file_uploader.dart';

final syncStatusServiceProvider = Provider<SyncStatusService>((ref) {
  return SyncStatusService(
    ref.watch(databaseProvider),
    ref.watch(fileUploaderProvider).progress,
  );
});

final bucketSyncStatusProvider = StreamProvider.autoDispose
    .family<SyncStatusSnapshot, int?>((ref, bucketId) {
      return ref
          .watch(syncStatusServiceProvider)
          .watch(bucketIds: bucketId == null ? null : {bucketId});
    });

typedef BackupActivityQuery = ({int bucketId, bool oldestFirst});

final bucketBackupActivityProvider = StreamProvider.autoDispose
    .family<List<BackupActivityItem>, BackupActivityQuery>((ref, query) {
      return ref
          .watch(syncStatusServiceProvider)
          .watchActivity(
            bucketId: query.bucketId,
            oldestFirst: query.oldestFirst,
          );
    });

class BackupActivityItem {
  final int id;
  final String localPath;
  final String? assetId;
  final int size;
  final FileSyncStatus status;
  final DateTime dateAdded;
  final DateTime? lastAttemptAt;
  final String? lastError;

  const BackupActivityItem({
    required this.id,
    required this.localPath,
    required this.assetId,
    required this.size,
    required this.status,
    required this.dateAdded,
    required this.lastAttemptAt,
    required this.lastError,
  });
}

class SyncStatusSnapshot {
  final int pendingCount;
  final int uploadingCount;
  final int completedCount;
  final int failedCount;
  final int totalCount;
  final int totalBytes;
  final int completedBytes;
  final int uploadingBytes;
  final int failedBytes;
  final double activeUploadProgress;

  const SyncStatusSnapshot({
    required this.pendingCount,
    required this.uploadingCount,
    required this.completedCount,
    required this.failedCount,
    required this.totalCount,
    required this.totalBytes,
    required this.completedBytes,
    required this.uploadingBytes,
    required this.failedBytes,
    required this.activeUploadProgress,
  });

  const SyncStatusSnapshot.empty()
    : pendingCount = 0,
      uploadingCount = 0,
      completedCount = 0,
      failedCount = 0,
      totalCount = 0,
      totalBytes = 0,
      completedBytes = 0,
      uploadingBytes = 0,
      failedBytes = 0,
      activeUploadProgress = 0;

  int get transferredBytes {
    final activeBytes = (uploadingBytes * activeUploadProgress).round();
    return (completedBytes + activeBytes).clamp(0, totalBytes).toInt();
  }

  double get overallProgress {
    if (totalBytes <= 0) {
      return totalCount == 0 ? 1 : completedCount / totalCount;
    }
    return (transferredBytes / totalBytes).clamp(0, 1).toDouble();
  }
}

class SyncStatusService {
  final AppDatabase _db;
  final Stream<Map<String, double>> _uploadProgress;

  SyncStatusService(this._db, this._uploadProgress);

  Stream<List<BackupActivityItem>> watchActivity({
    required int bucketId,
    bool oldestFirst = true,
    int limit = 8,
  }) {
    final dateDirection = oldestFirst ? 'ASC' : 'DESC';
    return _db
        .customSelect(
          '''
            SELECT
              id,
              local_path,
              asset_id,
              size,
              status,
              date_added,
              last_attempt_at,
              last_error
            FROM files
            WHERE bucket_id = ?
              AND status IN (0, 1, 2, 3)
            ORDER BY
              CASE WHEN status = 1 THEN 0 ELSE 1 END ASC,
              date_added $dateDirection
            LIMIT ?
          ''',
          variables: [Variable.withInt(bucketId), Variable.withInt(limit)],
          readsFrom: {_db.files},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => BackupActivityItem(
                  id: row.read<int>('id'),
                  localPath: row.read<String>('local_path'),
                  assetId: row.readNullable<String>('asset_id'),
                  size: row.read<int>('size'),
                  status: fileSyncStatusFromDb(row.read<int>('status')),
                  dateAdded: row.read<DateTime>('date_added'),
                  lastAttemptAt: row.readNullable<DateTime>('last_attempt_at'),
                  lastError: row.readNullable<String>('last_error'),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<SyncStatusSnapshot> watch({Set<int>? bucketIds}) {
    if (bucketIds != null && bucketIds.isEmpty) {
      return Stream.value(const SyncStatusSnapshot.empty());
    }

    late StreamController<SyncStatusSnapshot> controller;
    StreamSubscription? databaseSubscription;
    StreamSubscription? progressSubscription;
    QueryRow? latestRow;
    Map<String, double> latestProgress = const {};

    void emit() {
      final row = latestRow;
      if (row == null || controller.isClosed) return;
      final uploadingCount = row.read<int>('uploading_count');
      final progress = uploadingCount == 0 || latestProgress.isEmpty
          ? 0.0
          : latestProgress.values.reduce((a, b) => a + b) /
                latestProgress.length;
      controller.add(
        SyncStatusSnapshot(
          pendingCount: row.read<int>('pending_count'),
          uploadingCount: uploadingCount,
          completedCount: row.read<int>('completed_count'),
          failedCount: row.read<int>('failed_count'),
          totalCount: row.read<int>('total_count'),
          totalBytes: row.read<int>('total_bytes'),
          completedBytes: row.read<int>('completed_bytes'),
          uploadingBytes: row.read<int>('uploading_bytes'),
          failedBytes: row.read<int>('failed_bytes'),
          activeUploadProgress: progress.clamp(0, 1).toDouble(),
        ),
      );
    }

    controller = StreamController<SyncStatusSnapshot>(
      onListen: () {
        final ids = bucketIds == null ? null : (bucketIds.toList()..sort());
        final whereClause = ids == null
            ? ''
            : 'WHERE bucket_id IN (${List.filled(ids.length, '?').join(',')})';
        final variables = ids
            ?.map<Variable<int>>((id) => Variable.withInt(id))
            .toList();
        final query = _db.customSelect(
          '''
            SELECT
              COALESCE(SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END), 0) AS pending_count,
              COALESCE(SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END), 0) AS uploading_count,
              COALESCE(SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END), 0) AS completed_count,
              COALESCE(SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END), 0) AS failed_count,
              COALESCE(SUM(CASE WHEN status IN (0, 1, 2, 3) THEN 1 ELSE 0 END), 0) AS total_count,
              COALESCE(SUM(CASE WHEN status IN (0, 1, 2, 3) THEN size ELSE 0 END), 0) AS total_bytes,
              COALESCE(SUM(CASE WHEN status = 2 THEN size ELSE 0 END), 0) AS completed_bytes,
              COALESCE(SUM(CASE WHEN status = 1 THEN size ELSE 0 END), 0) AS uploading_bytes,
              COALESCE(SUM(CASE WHEN status = 3 THEN size ELSE 0 END), 0) AS failed_bytes
            FROM files
            $whereClause
          ''',
          variables: variables ?? const [],
          readsFrom: {_db.files},
        );
        databaseSubscription = query.watchSingle().listen((row) {
          latestRow = row;
          emit();
        }, onError: controller.addError);
        progressSubscription = _uploadProgress.listen((progress) {
          latestProgress = progress;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await databaseSubscription?.cancel();
        await progressSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}

String formatSyncBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}
