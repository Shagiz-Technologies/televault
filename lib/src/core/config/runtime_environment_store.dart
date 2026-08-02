import 'package:flutter/services.dart';

import 'app_runtime_environment.dart';

abstract interface class RuntimeEnvironmentStore {
  Future<AppRuntimeMode?> read();
  Future<void> write(AppRuntimeMode mode);
}

class PlatformRuntimeEnvironmentStore implements RuntimeEnvironmentStore {
  static const _channel = MethodChannel(
    'et.shagiz.tele_vault/runtime_environment',
  );

  const PlatformRuntimeEnvironmentStore();

  @override
  Future<AppRuntimeMode?> read() async {
    final value = await _channel.invokeMethod<String>('getSelectedMode');
    return AppRuntimeMode.fromWireName(value);
  }

  @override
  Future<void> write(AppRuntimeMode mode) =>
      _channel.invokeMethod<void>('setSelectedMode', mode.wireName);
}

class RuntimeEnvironmentBootstrapper {
  final RuntimeEnvironmentStore store;

  const RuntimeEnvironmentBootstrapper(this.store);

  AppRuntimeMode get defaultMode => AppRuntimeMode.production;

  Future<AppRuntimeMode?> readInitialMode() async {
    return store.read();
  }

  Future<void> activate(
    AppRuntimeMode mode, {
    required Future<void> Function() initializeServices,
  }) async {
    AppRuntimeEnvironment.configure(mode);
    await store.write(mode);
    if (mode == AppRuntimeMode.production) await initializeServices();
  }

  Future<void> initializePersisted(
    AppRuntimeMode mode, {
    required Future<void> Function() initializeServices,
  }) async {
    AppRuntimeEnvironment.configure(mode);
    if (mode == AppRuntimeMode.production) await initializeServices();
  }

  Future<void> activateProductionAfterShutdown({
    required Future<void> Function() initializeServices,
  }) async {
    await store.write(AppRuntimeMode.production);
    AppRuntimeEnvironment.resetAfterRuntimeShutdown();
    AppRuntimeEnvironment.configure(AppRuntimeMode.production);
    await initializeServices();
  }

  Future<void> activateReviewerDemoAfterShutdown() async {
    await store.write(AppRuntimeMode.reviewerDemo);
    AppRuntimeEnvironment.resetAfterRuntimeShutdown();
    AppRuntimeEnvironment.configure(AppRuntimeMode.reviewerDemo);
  }
}
