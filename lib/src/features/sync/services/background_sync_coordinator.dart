import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../settings/services/settings_service.dart';
import 'android_background_sync_bridge.dart';
import 'sync_constraints_service.dart';
import 'sync_service.dart';
import 'sync_status_service.dart';

final backgroundSyncCoordinatorProvider = Provider<BackgroundSyncCoordinator>((
  ref,
) {
  final bridge = AndroidBackgroundSyncBridge();
  final coordinator = BackgroundSyncCoordinator(
    ref.watch(databaseProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(syncConstraintsServiceProvider),
    ref.watch(syncStatusServiceProvider),
    bridge,
    onNativeWake: () =>
        ref.read(syncServiceProvider).runAutomaticSyncFromBackground(),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class BackgroundSyncCoordinator {
  final AppDatabase _db;
  final SettingsService _settings;
  final SyncConstraintsService _constraints;
  final SyncStatusService _statusService;
  final AndroidBackgroundSyncBridge _bridge;
  final Future<void> Function()? _onNativeWake;

  StreamSubscription? _bucketsSubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _constraintsSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _configureDebounce;
  Timer? _notificationThrottle;
  SyncStatusSnapshot? _pendingNotification;
  SyncStatusSnapshot? _latestStatus;
  String? _constraintBlockReason;
  Set<int> _autoBucketIds = const {};
  Set<int> _trackedBucketIds = const {};
  bool _started = false;
  bool _nativeServiceStarted = false;
  bool _stopWhenCurrentUploadFinishes = false;
  bool _nativeWakeRunning = false;
  int _configurationGeneration = 0;

  BackgroundSyncCoordinator(
    this._db,
    this._settings,
    this._constraints,
    this._statusService,
    this._bridge, {
    Future<void> Function()? onNativeWake,
  }) : _onNativeWake = onNativeWake;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _bridge.setSyncWakeHandler(_handleNativeWake);
    _bucketsSubscription = _db.select(_db.buckets).watch().listen((_) {
      _scheduleConfigure();
    });
    _settingsSubscription = _db.select(_db.appSettings).watch().listen((_) {
      _scheduleConfigure();
    });
    _constraintsSubscription = _constraints.watchConstraintChanges().listen(
      (_) {
        unawaited(_refreshConstraintBlockReason());
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to observe sync constraints.');
      },
    );
    await _configure();
  }

  Future<void> _handleNativeWake() async {
    final onNativeWake = _onNativeWake;
    if (!_started ||
        _nativeWakeRunning ||
        _autoBucketIds.isEmpty ||
        onNativeWake == null) {
      return;
    }

    _nativeWakeRunning = true;
    try {
      await onNativeWake();
    } catch (_) {
      debugPrint('Background sync heartbeat failed.');
    } finally {
      _nativeWakeRunning = false;
    }
  }

  Future<void> refresh() async {
    if (!_started) {
      await start();
      return;
    }
    bool isRunning;
    try {
      isRunning = await _bridge.isRunning();
    } catch (_) {
      debugPrint('Unable to read Android background service state.');
      return;
    }
    if (isRunning == _nativeServiceStarted &&
        (isRunning || _autoBucketIds.isEmpty)) {
      return;
    }

    _nativeServiceStarted = isRunning;
    if (!isRunning) {
      _autoBucketIds = const {};
      await _configure();
    }
  }

  void _scheduleConfigure() {
    _configureDebounce?.cancel();
    _configureDebounce = Timer(const Duration(milliseconds: 250), _configure);
  }

  Future<void> _configure() async {
    if (!_started) return;
    final generation = ++_configurationGeneration;
    final buckets = await _db.select(_db.buckets).get();
    final autoBucketIds = <int>{};
    final activeBuckets = buckets.where((bucket) => bucket.isActive).toList();
    if (activeBuckets.isNotEmpty) {
      final bucket = activeBuckets.first;
      final preferences = await _settings.getSyncPreferences(
        bucketId: bucket.id,
      );
      if (preferences.autoBackupEnabled) {
        autoBucketIds.add(bucket.id);
      }
    }
    final constraintBlockReason = await _blockReasonFor(autoBucketIds);
    if (!_started || generation != _configurationGeneration) return;
    if (_sameIds(_autoBucketIds, autoBucketIds) &&
        constraintBlockReason == _constraintBlockReason &&
        ((_autoBucketIds.isNotEmpty && _nativeServiceStarted) ||
            (_autoBucketIds.isEmpty && !_nativeServiceStarted))) {
      return;
    }

    _autoBucketIds = Set.unmodifiable(autoBucketIds);
    _constraintBlockReason = constraintBlockReason;
    await _statusSubscription?.cancel();
    _statusSubscription = null;

    if (_autoBucketIds.isEmpty) {
      final uploadingRows = await _db
          .customSelect(
            'SELECT DISTINCT bucket_id FROM files WHERE status = 1',
            readsFrom: {_db.files},
          )
          .get();
      final uploadingBucketIds = uploadingRows
          .map((row) => row.read<int>('bucket_id'))
          .toSet();
      if (uploadingBucketIds.isEmpty) {
        await _stopNativeService();
        return;
      }
      _trackedBucketIds = Set.unmodifiable(uploadingBucketIds);
      _stopWhenCurrentUploadFinishes = true;
    } else {
      _trackedBucketIds = _autoBucketIds;
      _stopWhenCurrentUploadFinishes = false;
    }

    if (!_nativeServiceStarted) {
      await _runNative(_bridge.requestNotificationPermission);
      const initial = SyncStatusSnapshot.empty();
      _nativeServiceStarted = await _runNative(
        () => _bridge.start(initial, pauseReason: _constraintBlockReason),
      );
      if (!_nativeServiceStarted) return;
    }
    _statusSubscription = _statusService
        .watch(bucketIds: _trackedBucketIds)
        .listen(_queueNotificationUpdate, onError: _onStatusError);
  }

  void _queueNotificationUpdate(SyncStatusSnapshot status) {
    _latestStatus = status;
    if (_stopWhenCurrentUploadFinishes && status.uploadingCount == 0) {
      unawaited(_stopNativeService());
      return;
    }
    _pendingNotification = status;
    if (_notificationThrottle != null) return;
    _notificationThrottle = Timer(
      const Duration(milliseconds: 700),
      _flushNotification,
    );
  }

  Future<void> _flushNotification() async {
    _notificationThrottle = null;
    final status = _pendingNotification;
    _pendingNotification = null;
    if (!_started ||
        !_nativeServiceStarted ||
        status == null ||
        _trackedBucketIds.isEmpty) {
      return;
    }
    await _runNative(
      () => _bridge.update(status, pauseReason: _constraintBlockReason),
    );
    if (_pendingNotification != null) {
      _queueNotificationUpdate(_pendingNotification!);
    }
  }

  void _onStatusError(Object _, StackTrace _) {
    debugPrint('Unable to update background sync status.');
  }

  Future<bool> _runNative(Future<Object?> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      debugPrint('Android background sync bridge failed.');
      return false;
    }
  }

  bool _sameIds(Set<int> first, Set<int> second) {
    return first.length == second.length && first.containsAll(second);
  }

  Future<String?> _blockReasonFor(Set<int> bucketIds) async {
    if (bucketIds.isEmpty) return null;
    final reasons = <String>{};
    for (final bucketId in bucketIds) {
      final reason = await _constraints.automaticSyncBlockReason(
        bucketId: bucketId,
      );
      if (reason == null) return null;
      reasons.add(reason);
    }
    return reasons.length == 1
        ? reasons.single
        : 'Waiting for configured network or power conditions';
  }

  Future<void> _refreshConstraintBlockReason() async {
    if (!_started || _autoBucketIds.isEmpty) return;
    final reason = await _blockReasonFor(_autoBucketIds);
    if (!_started || reason == _constraintBlockReason) return;
    _constraintBlockReason = reason;
    final status = _latestStatus;
    if (status != null) {
      _queueNotificationUpdate(status);
    }
  }

  Future<void> _stopNativeService() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    _notificationThrottle?.cancel();
    _notificationThrottle = null;
    _pendingNotification = null;
    _latestStatus = null;
    _constraintBlockReason = null;
    _trackedBucketIds = const {};
    _stopWhenCurrentUploadFinishes = false;
    if (!_nativeServiceStarted) return;
    _nativeServiceStarted = false;
    await _runNative(_bridge.stop);
  }

  Future<void> dispose() async {
    _started = false;
    _configurationGeneration++;
    _bridge.clearSyncWakeHandler();
    _configureDebounce?.cancel();
    _notificationThrottle?.cancel();
    await _bucketsSubscription?.cancel();
    await _settingsSubscription?.cancel();
    await _constraintsSubscription?.cancel();
    await _statusSubscription?.cancel();
  }
}
