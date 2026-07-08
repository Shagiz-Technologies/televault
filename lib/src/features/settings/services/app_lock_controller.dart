import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_service.dart';

class AppLockState {
  final bool enabled;
  final bool locked;
  final bool initialized;
  final DateTime? lastBackgroundAt;
  final AppLockConfig config;

  const AppLockState({
    required this.enabled,
    required this.locked,
    required this.initialized,
    required this.config,
    this.lastBackgroundAt,
  });

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? initialized,
    DateTime? lastBackgroundAt,
    bool clearLastBackgroundAt = false,
    AppLockConfig? config,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      initialized: initialized ?? this.initialized,
      config: config ?? this.config,
      lastBackgroundAt: clearLastBackgroundAt
          ? null
          : lastBackgroundAt ?? this.lastBackgroundAt,
    );
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
      return AppLockController(ref.watch(appLockServiceProvider));
    });

class AppLockController extends StateNotifier<AppLockState> {
  final AppLockService _service;
  DateTime? _externalSystemPromptUntil;

  AppLockController(this._service)
    : super(
        const AppLockState(
          enabled: false,
          locked: false,
          initialized: false,
          config: AppLockConfig(),
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    final config = await _service.getConfig();
    state = state.copyWith(
      enabled: config.enabled,
      config: config,
      initialized: true,
      locked: config.enabled,
    );
  }

  Future<void> refresh() async {
    final config = await _service.getConfig();
    state = state.copyWith(enabled: config.enabled, config: config);
  }

  Future<void> onAppBackgrounded() async {
    if (!state.initialized) return;

    if (_isExternalSystemPromptActive()) {
      state = state.copyWith(clearLastBackgroundAt: true);
      return;
    }

    state = state.copyWith(lastBackgroundAt: DateTime.now());
    if (state.config.enabled && state.config.lockOnBackground) {
      state = state.copyWith(locked: true);
    }
  }

  Future<void> onAppResumed() async {
    if (!state.initialized || !state.config.enabled) return;

    if (_isExternalSystemPromptActive()) {
      _externalSystemPromptUntil = null;
      state = state.copyWith(clearLastBackgroundAt: true);
      return;
    }

    final backgroundAt = state.lastBackgroundAt;
    if (backgroundAt == null) return;

    final diff = DateTime.now().difference(backgroundAt).inSeconds;
    if (diff >= state.config.timeoutSeconds) {
      state = state.copyWith(locked: true);
    }
  }

  Future<AppLockSecretAttemptResult> unlockWithSecret(String secret) async {
    final result = await _service.verifySecretForUnlock(secret);
    if (result.success) {
      state = state.copyWith(locked: false);
    }
    return result;
  }

  Future<bool> unlockWithPhoneSecurity() async {
    allowExternalSystemPrompt();
    final ok = await _service.authenticatePhoneUnlock();
    if (ok) {
      await _service.clearCredentialFailures(includePermanent: false);
      state = state.copyWith(locked: false);
    }
    return ok;
  }

  Future<bool> unlockWithBiometric() => unlockWithPhoneSecurity();

  void lockNow() {
    if (!state.config.enabled) return;
    state = state.copyWith(locked: true);
  }

  void allowExternalSystemPrompt({
    Duration duration = const Duration(minutes: 2),
  }) {
    _externalSystemPromptUntil = DateTime.now().add(duration);
  }

  bool _isExternalSystemPromptActive() {
    final until = _externalSystemPromptUntil;
    if (until == null) return false;
    if (until.isAfter(DateTime.now())) return true;
    _externalSystemPromptUntil = null;
    return false;
  }
}
