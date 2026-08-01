import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/database/file_sync_status.dart';
import 'package:tele_vault/src/features/settings/services/settings_service.dart';
import 'package:tele_vault/src/features/sync/services/android_background_sync_bridge.dart';
import 'package:tele_vault/src/features/sync/services/background_sync_coordinator.dart';
import 'package:tele_vault/src/features/sync/services/sync_constraints_service.dart';
import 'package:tele_vault/src/features/sync/services/sync_status_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settings;
  late StreamController<Map<String, double>> progress;
  late _FakeBackgroundSyncBridge bridge;
  late _FakeSyncConstraintsService constraints;
  late BackgroundSyncCoordinator coordinator;
  late int nativeWakeCount;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
    progress = StreamController<Map<String, double>>.broadcast();
    bridge = _FakeBackgroundSyncBridge();
    constraints = _FakeSyncConstraintsService(settings);
    nativeWakeCount = 0;
    coordinator = BackgroundSyncCoordinator(
      db,
      settings,
      constraints,
      SyncStatusService(db, progress.stream),
      bridge,
      onNativeWake: () async {
        nativeWakeCount++;
      },
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await constraints.dispose();
    await progress.close();
    await db.close();
  });

  test(
    'auto-sync off keeps current upload visible then stops the service',
    () async {
      final bucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(
              chatId: BigInt.from(1001),
              name: 'Photos',
              isActive: const Value(true),
            ),
          );
      await settings.seedBucketSyncPreferences(
        bucketId,
        const SyncPreferences(autoBackupEnabled: true),
      );
      final fileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/uploading.jpg',
              folderName: 'Camera',
              size: 200,
              bucketId: bucketId,
              status: Value(FileSyncStatus.uploading.dbValue),
            ),
          );

      await coordinator.start();
      await _waitUntil(() => bridge.startCount == 1);

      await settings.setAutoBackup(false, bucketId: bucketId);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(bridge.stopCount, 0);

      await (db.update(db.files)..where((file) => file.id.equals(fileId)))
          .write(FilesCompanion(status: Value(FileSyncStatus.synced.dbValue)));
      await _waitUntil(() => bridge.stopCount == 1);

      expect(bridge.startCount, 1);
      expect(bridge.stopCount, 1);
    },
  );

  test(
    'refresh restarts a timed-out service when auto-sync is enabled',
    () async {
      final bucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(
              chatId: BigInt.from(1001),
              name: 'Photos',
              isActive: const Value(true),
            ),
          );
      await settings.seedBucketSyncPreferences(
        bucketId,
        const SyncPreferences(autoBackupEnabled: true),
      );
      await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              localPath: '/demo/pending-refresh.jpg',
              folderName: 'Camera',
              size: 100,
              bucketId: bucketId,
              status: Value(FileSyncStatus.pending.dbValue),
            ),
          );

      await coordinator.start();
      await _waitUntil(() => bridge.startCount == 1);
      expect(bridge.startCount, 1);

      bridge.running = false;
      await coordinator.refresh();
      await _waitUntil(() => bridge.startCount == 2);

      expect(bridge.startCount, 2);
      expect(bridge.running, isTrue);
    },
  );

  test('refresh retries a failed native service start', () async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(1001),
            name: 'Photos',
            isActive: const Value(true),
          ),
        );
    await settings.seedBucketSyncPreferences(
      bucketId,
      const SyncPreferences(autoBackupEnabled: true),
    );
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/pending-retry.jpg',
            folderName: 'Camera',
            size: 100,
            bucketId: bucketId,
            status: Value(FileSyncStatus.pending.dbValue),
          ),
        );
    bridge.startFailuresRemaining = 1;

    await coordinator.start();
    await _waitUntil(() => bridge.startCount == 1);
    expect(bridge.startCount, 1);
    expect(bridge.running, isFalse);

    await coordinator.refresh();
    await _waitUntil(() => bridge.startCount == 2);

    expect(bridge.startCount, 2);
    expect(bridge.running, isTrue);
  });

  test('constraint changes refresh the notification pause reason', () async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(1001),
            name: 'Photos',
            isActive: const Value(true),
          ),
        );
    await settings.seedBucketSyncPreferences(
      bucketId,
      const SyncPreferences(autoBackupEnabled: true, wifiOnly: true),
    );
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/pending.jpg',
            folderName: 'Camera',
            size: 200,
            bucketId: bucketId,
            status: Value(FileSyncStatus.pending.dbValue),
          ),
        );
    constraints.blockReason = 'Waiting for Wi-Fi';

    await coordinator.start();
    await _waitUntil(() => bridge.startPauseReasons.isNotEmpty);
    expect(bridge.startPauseReasons.last, 'Waiting for Wi-Fi');

    constraints.blockReason = null;
    constraints.emitChange();
    await _waitUntil(
      () =>
          bridge.updatePauseReasons.isNotEmpty &&
          bridge.updatePauseReasons.last == null,
    );
  });

  test('notification totals only include the selected bucket', () async {
    final activeBucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(1001),
            name: 'Active',
            isActive: const Value(true),
          ),
        );
    final inactiveBucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(chatId: BigInt.from(1002), name: 'Inactive'),
        );
    await settings.seedBucketSyncPreferences(
      activeBucketId,
      const SyncPreferences(autoBackupEnabled: true),
    );
    await settings.seedBucketSyncPreferences(
      inactiveBucketId,
      const SyncPreferences(autoBackupEnabled: true),
    );
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/active.jpg',
            folderName: 'Camera',
            size: 100,
            bucketId: activeBucketId,
            status: Value(FileSyncStatus.pending.dbValue),
          ),
        );
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            localPath: '/demo/inactive.jpg',
            folderName: 'Camera',
            size: 200,
            bucketId: inactiveBucketId,
            status: Value(FileSyncStatus.pending.dbValue),
          ),
        );

    await coordinator.start();
    await _waitUntil(() => bridge.startedStatuses.isNotEmpty);

    expect(bridge.startedStatuses.last.totalCount, 1);
    expect(bridge.startedStatuses.last.totalBytes, 100);
  });

  test(
    'native heartbeat wakes automatic sync for the selected bucket',
    () async {
      final bucketId = await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(
              chatId: BigInt.from(1001),
              name: 'Photos',
              isActive: const Value(true),
            ),
          );
      await settings.seedBucketSyncPreferences(
        bucketId,
        const SyncPreferences(autoBackupEnabled: true),
      );

      await coordinator.start();
      await bridge.emitSyncWake();

      expect(nativeWakeCount, 1);
    },
  );

  test('restart recovery schedules one Wi-Fi constrained worker', () async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(1001),
            name: 'Photos',
            isActive: const Value(true),
          ),
        );
    await settings.seedBucketSyncPreferences(
      bucketId,
      const SyncPreferences(autoBackupEnabled: true, wifiOnly: true),
    );

    await coordinator.start();

    expect(bridge.persistentConfigureCount, 1);
    expect(bridge.lastPersistentWifiOnly, isTrue);
    expect(await bridge.emitSyncWake(), isTrue);
    expect(nativeWakeCount, 1);
  });

  test('logout cancels persistent work and removes the Dart wake', () async {
    final bucketId = await db
        .into(db.buckets)
        .insert(
          BucketsCompanion.insert(
            chatId: BigInt.from(1001),
            name: 'Photos',
            isActive: const Value(true),
          ),
        );
    await settings.seedBucketSyncPreferences(
      bucketId,
      const SyncPreferences(autoBackupEnabled: true),
    );
    await coordinator.start();

    await coordinator.stopForAccountCleanup();

    expect(bridge.persistentCancelCount, 1);
    expect(bridge.syncWakeHandler, isNull);
    expect(bridge.running, isFalse);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not reached before the deadline.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

class _FakeBackgroundSyncBridge extends AndroidBackgroundSyncBridge {
  int startCount = 0;
  int startFailuresRemaining = 0;
  int stopCount = 0;
  bool running = false;
  final updates = <SyncStatusSnapshot>[];
  final startedStatuses = <SyncStatusSnapshot>[];
  final startPauseReasons = <String?>[];
  final updatePauseReasons = <String?>[];
  int persistentConfigureCount = 0;
  int persistentCancelCount = 0;
  bool? lastPersistentWifiOnly;
  Future<bool> Function()? syncWakeHandler;

  @override
  void setSyncWakeHandler(Future<bool> Function() handler) {
    syncWakeHandler = handler;
  }

  @override
  void clearSyncWakeHandler() {
    syncWakeHandler = null;
  }

  Future<bool> emitSyncWake() async {
    return await syncWakeHandler?.call() ?? false;
  }

  @override
  Future<void> configurePersistentWork({required bool wifiOnly}) async {
    persistentConfigureCount++;
    lastPersistentWifiOnly = wifiOnly;
  }

  @override
  Future<void> cancelPersistentWork() async {
    persistentCancelCount++;
  }

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> start(SyncStatusSnapshot status, {String? pauseReason}) async {
    startCount++;
    if (startFailuresRemaining > 0) {
      startFailuresRemaining--;
      throw StateError('Native service start failed');
    }
    running = true;
    startedStatuses.add(status);
    startPauseReasons.add(pauseReason);
  }

  @override
  Future<void> update(SyncStatusSnapshot status, {String? pauseReason}) async {
    updates.add(status);
    updatePauseReasons.add(pauseReason);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;
}

class _FakeSyncConstraintsService extends SyncConstraintsService {
  final _changes = StreamController<void>.broadcast();
  String? blockReason;

  _FakeSyncConstraintsService(super.settingsService);

  @override
  Future<String?> automaticSyncBlockReason({int? bucketId}) async {
    return blockReason;
  }

  @override
  Stream<void> watchConstraintChanges() => _changes.stream;

  void emitChange() => _changes.add(null);

  Future<void> dispose() => _changes.close();
}
