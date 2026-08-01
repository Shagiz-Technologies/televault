import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/services/settings_service.dart';

final syncConstraintsServiceProvider = Provider<SyncConstraintsService>((ref) {
  return SyncConstraintsService(ref.watch(settingsServiceProvider));
});

class SyncConstraintsService {
  final SettingsService _settingsService;
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  SyncConstraintsService(this._settingsService);

  Future<bool> canRunAutomaticSync({int? bucketId}) async {
    return await automaticSyncBlockReason(bucketId: bucketId) == null;
  }

  Future<String?> automaticSyncBlockReason({int? bucketId}) async {
    final prefs = await _settingsService.getSyncPreferences(bucketId: bucketId);
    var waitingForWifi = false;
    var waitingForCharging = false;

    if (prefs.wifiOnly) {
      try {
        waitingForWifi = !await _isWifiConnected();
      } catch (_) {
        waitingForWifi = true;
      }
    }

    if (prefs.chargingOnly) {
      try {
        final batteryState = await _battery.batteryState;
        waitingForCharging =
            batteryState != BatteryState.charging &&
            batteryState != BatteryState.full;
      } catch (_) {
        waitingForCharging = true;
      }
    }

    if (waitingForWifi && waitingForCharging) {
      return 'Waiting for Wi-Fi and charging';
    }
    if (waitingForWifi) return 'Waiting for Wi-Fi';
    if (waitingForCharging) return 'Waiting for charging';
    return null;
  }

  Stream<void> watchConstraintChanges() {
    final connectivityStream = _connectivity.onConnectivityChanged.map((_) {});
    final batteryStream = _battery.onBatteryStateChanged.map((_) {});
    return StreamGroup.merge<void>([connectivityStream, batteryStream]);
  }

  Future<bool> _isWifiConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }
}

class StreamGroup<T> {
  StreamGroup._();

  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    final subscriptions = <StreamSubscription<T>>[];

    controller = StreamController<T>(
      onListen: () {
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(controller.add, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }
}
