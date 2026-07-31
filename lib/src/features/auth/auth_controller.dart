import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/services/diagnostics_service.dart';
import '../../core/services/telegram_error.dart';
import '../../core/services/telegram_service.dart';

enum AuthStatus {
  loading,
  enterPhone,
  enterCode,
  enterPassword,
  loggedIn,
  error,
}

final authErrorMessageProvider = StateProvider<String?>((ref) => null);
final authBusyProvider = StateProvider<bool>((ref) => false);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthStatus>((ref) {
      return AuthController(
        ref.watch(telegramServiceProvider),
        ref.watch(diagnosticsServiceProvider),
        ref,
      );
    });

class AuthController extends StateNotifier<AuthStatus> {
  final TelegramService _tg;
  final DiagnosticsService _diagnosticsService;
  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _startupFallbackTimer;

  AuthController(this._tg, this._diagnosticsService, this._ref)
    : super(AuthStatus.loading) {
    _startStartupFallbackTimer();
    _sub = _tg.updates.listen((update) async {
      if (update['@type'] == 'updateAuthorizationState') {
        final authState =
            update['authorization_state'] as Map<String, dynamic>? ?? {};
        await _mapAuthorizationState(authState);
      }

      if (update['@type'] == 'error' && update['@extra'] == null) {
        final error = TelegramErrorParser.parse(
          update,
          operation: 'telegram_authentication',
        );
        if (error != null) _setError(_friendlyAuthError(error));
      }
    });
    unawaited(refreshAuthorizationState());
  }

  void _clearError() {
    _ref.read(authErrorMessageProvider.notifier).state = null;
  }

  Future<void> sendPhone(String phone) async {
    final normalizedPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalizedPhone.isEmpty) {
      _setError('Enter your phone number with country code.');
      return;
    }

    await _runAuthAction(() async {
      final authState = await _tg.prepareAuthorization(
        timeout: const Duration(seconds: 45),
      );
      final type = authState['@type']?.toString();
      if (type != 'authorizationStateWaitPhoneNumber') {
        await _mapAuthorizationState(authState);
        if (type == 'authorizationStateReady') return;
        throw StateError(
          'Telegram is not ready for phone login yet. Current state: $type',
        );
      }

      final response = await _tg.request({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': normalizedPhone,
        'settings': {
          '@type': 'phoneNumberAuthenticationSettings',
          'allow_flash_call': false,
          'allow_missed_call': false,
          'is_current_phone_number': false,
          'allow_sms_retriever_api': false,
        },
      }, timeout: const Duration(seconds: 25));
      _throwIfTdError(response);
      await _refreshOrWaitForState({
        'authorizationStateWaitCode',
        'authorizationStateWaitPassword',
        'authorizationStateReady',
      });
    });
  }

  Future<void> sendCode(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      _setError('Enter the code Telegram sent you.');
      return;
    }

    await _runAuthAction(() async {
      final authState = await _tg.prepareAuthorization(
        timeout: const Duration(seconds: 30),
      );
      final type = authState['@type']?.toString();
      if (type != 'authorizationStateWaitCode') {
        await _mapAuthorizationState(authState);
        throw StateError(
          'Telegram is not waiting for a login code. Current state: $type',
        );
      }

      final response = await _tg.request({
        '@type': 'checkAuthenticationCode',
        'code': normalizedCode,
      }, timeout: const Duration(seconds: 25));
      _throwIfTdError(response);
      await _refreshOrWaitForState({
        'authorizationStateWaitPassword',
        'authorizationStateReady',
      });
    });
  }

  Future<void> resendCode() async {
    await _runAuthAction(() async {
      final authState = await _tg.prepareAuthorization(
        timeout: const Duration(seconds: 30),
      );
      final type = authState['@type']?.toString();
      if (type != 'authorizationStateWaitCode') {
        await _mapAuthorizationState(authState);
        throw StateError(
          'Telegram is not waiting for a login code. Current state: $type',
        );
      }

      final response = await _tg.request({
        '@type': 'resendAuthenticationCode',
      }, timeout: const Duration(seconds: 25));
      _throwIfTdError(response);
      await _refreshOrWaitForState({'authorizationStateWaitCode'});
    });
  }

  Future<void> sendPassword(String password) async {
    if (password.isEmpty) {
      _setError('Enter your Telegram password.');
      return;
    }

    await _runAuthAction(() async {
      final authState = await _tg.prepareAuthorization(
        timeout: const Duration(seconds: 30),
      );
      final type = authState['@type']?.toString();
      if (type != 'authorizationStateWaitPassword') {
        await _mapAuthorizationState(authState);
        throw StateError(
          'Telegram is not waiting for a password. Current state: $type',
        );
      }

      final response = await _tg.request({
        '@type': 'checkAuthenticationPassword',
        'password': password,
      }, timeout: const Duration(seconds: 25));
      _throwIfTdError(response);
      await _refreshOrWaitForState({'authorizationStateReady'});
    });
  }

  Future<void> backToPhoneInput() async {
    await _runAuthAction(() async {
      final authState = await _tg.prepareAuthorization(
        timeout: const Duration(seconds: 30),
      );
      final type = authState['@type']?.toString();
      if (type == 'authorizationStateWaitCode' ||
          type == 'authorizationStateWaitPassword' ||
          type == 'authorizationStateWaitPhoneNumberConfirmation') {
        final resetState = await _tg.resetAuthorization(
          timeout: const Duration(seconds: 45),
        );
        await _mapAuthorizationState(resetState);
        return;
      }

      await _mapAuthorizationState(authState);
    });
  }

  Future<void> refreshAuthorizationState({
    bool preserveCurrentState = false,
  }) async {
    try {
      final authState = await _tg
          .prepareAuthorization(timeout: const Duration(seconds: 20))
          .timeout(const Duration(seconds: 24));
      await _mapAuthorizationState(
        authState,
        preserveCurrentState: preserveCurrentState,
      );
    } catch (e) {
      if (state == AuthStatus.loading) {
        state = AuthStatus.enterPhone;
      }
      _setError(_friendlyAuthError(e));
    }
  }

  Future<void> _mapAuthorizationState(
    Map<String, dynamic> authState, {
    bool preserveCurrentState = false,
  }) async {
    final type = authState['@type'];
    _clearError();

    if (type == 'authorizationStateWaitPhoneNumber') {
      _cancelStartupFallbackTimer();
      state = AuthStatus.enterPhone;
      return;
    }
    if (type == 'authorizationStateWaitCode') {
      _cancelStartupFallbackTimer();
      state = AuthStatus.enterCode;
      return;
    }
    if (type == 'authorizationStateWaitPassword') {
      _cancelStartupFallbackTimer();
      state = AuthStatus.enterPassword;
      return;
    }
    if (type == 'authorizationStateReady') {
      _cancelStartupFallbackTimer();
      state = AuthStatus.loggedIn;
      return;
    }
    if (type == 'authorizationStateWaitTdlibParameters' ||
        type == 'authorizationStateWaitEncryptionKey' ||
        type == 'authorizationStateWaitPhoneNumberConfirmation') {
      if (state == AuthStatus.loggedIn ||
          (preserveCurrentState && state != AuthStatus.loading)) {
        return;
      }
      state = AuthStatus.loading;
      return;
    }
    if (type == 'authorizationStateLoggingOut' ||
        type == 'authorizationStateClosed') {
      final db = _ref.read(databaseProvider);
      await db.transaction(() async {
        await db.delete(db.files).go();
        await db.delete(db.buckets).go();
        await db.delete(db.appSettings).go();
        await db.delete(db.telegramAccountStates).go();
      });
      _cancelStartupFallbackTimer();
      state = AuthStatus.enterPhone;
      return;
    }
    if (type != null &&
        state != AuthStatus.loggedIn &&
        !(preserveCurrentState && state != AuthStatus.loading)) {
      state = AuthStatus.loading;
    }
  }

  void _startStartupFallbackTimer() {
    _startupFallbackTimer?.cancel();
    _startupFallbackTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || state != AuthStatus.loading) return;
      state = AuthStatus.enterPhone;
      _setError(
        'Telegram startup took too long. Check your connection and try again.',
      );
    });
  }

  void _cancelStartupFallbackTimer() {
    _startupFallbackTimer?.cancel();
    _startupFallbackTimer = null;
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_ref.read(authBusyProvider)) return;

    _clearError();
    _ref.read(authBusyProvider.notifier).state = true;
    try {
      await action();
    } catch (e) {
      _setError(_friendlyAuthError(e));
    } finally {
      _ref.read(authBusyProvider.notifier).state = false;
    }
  }

  Future<void> _refreshOrWaitForState(Set<String> acceptedTypes) async {
    final refreshed = await _tg.refreshAuthorizationState(
      timeout: const Duration(seconds: 8),
    );
    await _mapAuthorizationState(refreshed);
    final refreshedType = refreshed['@type']?.toString();
    if (refreshedType != null && acceptedTypes.contains(refreshedType)) {
      return;
    }

    final update = await _tg.waitForUpdate((event) {
      if (event['@type'] != 'updateAuthorizationState') return false;
      final authState =
          event['authorization_state'] as Map<String, dynamic>? ?? {};
      final type = authState['@type']?.toString();
      return type != null && acceptedTypes.contains(type);
    }, timeout: const Duration(seconds: 25));

    final authState =
        update['authorization_state'] as Map<String, dynamic>? ?? {};
    await _mapAuthorizationState(authState);
  }

  void _throwIfTdError(Map<String, dynamic> response) {
    if (response['@type'] != 'error') return;
    throw TelegramErrorParser.parse(
      response,
      operation: 'telegram_authentication',
    )!;
  }

  void _setError(String message) {
    _ref.read(authErrorMessageProvider.notifier).state = message;
    unawaited(_diagnosticsService.increment(DiagnosticsService.authFailureKey));
  }

  String _friendlyAuthError(Object error) {
    if (error is TelegramError) {
      if (error.code == 406) return error.userMessage;
      if (error.operation == 'configure_tdlib' && error.userActionRequired) {
        return 'Telegram API credentials are missing. Configure TELEGRAM_API_ID and TELEGRAM_API_HASH.';
      }
      final message = error.tdlibMessage;
      if (message.contains('PHONE_NUMBER_INVALID')) {
        return 'That phone number is invalid. Use the full number with country code.';
      }
      if (message.contains('PHONE_CODE_INVALID')) {
        return 'That login code is incorrect.';
      }
      if (message.contains('PHONE_CODE_EXPIRED')) {
        return 'That login code expired. Request a new code.';
      }
      if (message.contains('PASSWORD_HASH_INVALID')) {
        return 'That Telegram password is incorrect.';
      }
      if (error.hasExactRetryAfter) {
        return 'Telegram is rate limiting login attempts. Try again after the displayed wait.';
      }
      return error.userMessage;
    }
    if (error is TimeoutException) {
      return 'Telegram did not respond in time. Check your connection and try again.';
    }
    if (error is StateError) {
      return 'Telegram is not ready for that step yet. Wait a moment and try again.';
    }
    return 'Telegram could not complete this request. Check your connection and try again.';
  }

  @override
  void dispose() {
    _cancelStartupFallbackTimer();
    _sub?.cancel();
    super.dispose();
  }
}
