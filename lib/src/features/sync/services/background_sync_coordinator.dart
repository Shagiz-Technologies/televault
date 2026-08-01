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
  bool _nativeServiceStarting = false;
  bool _stopWhenCurrentUploadFinishes = false;
  bool _nativeWakeRunning = false;
  bool? _persistentWifiOnly;
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

  Future<bool> _handleNativeWake() async {
    final onNativeWake = _onNativeWake;
    if (!_started ||
        _nativeWakeRunning ||
        _autoBucketIds.isEmpty ||
        onNativeWake == null) {
      return false;
    }

    _nativeWakeRunning = true;
    try {
      await onNativeWake();
      return true;
    } catch (_) {
      debugPrint('Background sync heartbeat failed.');
      return false;
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
    var wifiOnly = false;
    final activeBuckets = buckets.where((bucket) => bucket.isActive).toList();
    if (activeBuckets.isNotEmpty) {
      final bucket = activeBuckets.first;
      final preferences = await _settings.getSyncPreferences(
        bucketId: bucket.id,
      );
      if (preferences.autoBackupEnabled) {
        autoBucketIds.add(bucket.id);
        wifiOnly = preferences.wifiOnly;
      }
    }
    final constraintBlockReason = await _blockReasonFor(autoBucketIds);
    final persistentWifiOnly = autoBucketIds.isEmpty ? null : wifiOnly;
    if (!_started || generation != _configurationGeneration) return;
    if (_sameIds(_autoBucketIds, autoBucketIds) &&
        constraintBlockReason == _constraintBlockReason &&
        persistentWifiOnly == _persistentWifiOnly &&
        _statusSubscription != null) {
      return;
    }

    _autoBucketIds = Set.unmodifiable(autoBucketIds);
    _constraintBlockReason = constraintBlockReason;
    _persistentWifiOnly = persistentWifiOnly;
    if (_autoBucketIds.isEmpty) {
      await _runNative(_bridge.cancelPersistentWork);
    } else {
      await _runNative(
        () => _bridge.configurePersistentWork(wifiOnly: wifiOnly),
      );
    }
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
    if (status.pendingCount == 0 && status.uploadingCount == 0) {
      unawaited(_stopNativeService(keepStatusSubscription: true));
      return;
    }
    if (!_nativeServiceStarted) {
      unawaited(_startNativeService(status));
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

  Future<void> _startNativeService(SyncStatusSnapshot status) async {
    if (!_started ||
        _nativeServiceStarted ||
        _nativeServiceStarting ||
        _trackedBucketIds.isEmpty) {
      return;
    }
    _nativeServiceStarting = true;
    try {
      await _runNative(_bridge.requestNotificationPermission);
      final started = await _runNative(
        () => _bridge.start(status, pauseReason: _constraintBlockReason),
      );
      if (!_started || _trackedBucketIds.isEmpty) {
        if (started) await _runNative(_bridge.stop);
        return;
      }
      _nativeServiceStarted = started;
      final latest = _latestStatus;
      if (started && latest != null && !identical(latest, status)) {
        _queueNotificationUpdate(latest);
      }
    } finally {
      _nativeServiceStarting = false;
    }
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

  Future<void> _stopNativeService({bool keepStatusSubscription = false}) async {
    if (!keepStatusSubscription) {
      await _statusSubscription?.cancel();
      _statusSubscription = null;
    }
    _notificationThrottle?.cancel();
    _notificationThrottle = null;
    _pendingNotification = null;
    if (!keepStatusSubscription) {
      _latestStatus = null;
      _constraintBlockReason = null;
      _trackedBucketIds = const {};
      _stopWhenCurrentUploadFinishes = false;
    }
    if (!_nativeServiceStarted) return;
    _nativeServiceStarted = false;
    await _runNative(_bridge.stop);
  }

  Future<void> stopForAccountCleanup() async {
    _started = false;
    _configurationGeneration++;
    _bridge.clearSyncWakeHandler();
    _configureDebounce?.cancel();
    _notificationThrottle?.cancel();
    await _bucketsSubscription?.cancel();
    await _settingsSubscription?.cancel();
    await _constraintsSubscription?.cancel();
    await _statusSubscription?.cancel();
    _bucketsSubscription = null;
    _settingsSubscription = null;
    _constraintsSubscription = null;
    _statusSubscription = null;
    _autoBucketIds = const {};
    _persistentWifiOnly = null;
    await _runNative(_bridge.cancelPersistentWork);
    await _stopNativeService();
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
