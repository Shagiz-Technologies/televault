import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtdjson/libtdjson.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'telegram_gateway.dart';

final telegramServiceProvider = Provider<TelegramService>((ref) {
  final service = TelegramService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class TelegramService implements TelegramGateway {
  late final NativeClient _tdJson;
  late int _clientId;

  final _updatesController = StreamController<Map<String, dynamic>>.broadcast();
  final _authStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Uuid _uuid = const Uuid();
  final Duration _minRequestSpacing = const Duration(milliseconds: 120);
  final Duration _idlePollDelay = const Duration(milliseconds: 40);

  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _tdlibParametersSent = false;
  bool _databaseEncryptionKeyChecked = false;
  Future<void>? _setParametersInFlight;
  Future<void>? _checkEncryptionKeyInFlight;
  Map<String, dynamic>? _currentAuthState;

  @override
  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  String? get currentAuthorizationStateType =>
      _currentAuthState?['@type']?.toString();

  TelegramService() {
    _init();
  }

  void _init() {
    try {
      _tdJson = NativeClient();
      _clientId = _tdJson.td_create_client_id();
      _isInitialized = true;
      debugPrint('TDLib client initialized: $_clientId');
      _startEventLoop();
    } catch (e) {
      debugPrint('TDLib initialization failed: $e');
    }
  }

  void _startEventLoop() {
    unawaited(_runEventLoop());
  }

  Future<void> _runEventLoop() async {
    while (!_isDisposed) {
      var hadUpdate = false;
      for (var i = 0; i < 32 && !_isDisposed; i++) {
        final event = _receiveRawUpdate();
        if (event == null || event.isEmpty) {
          break;
        }
        hadUpdate = true;
        _handleRawUpdate(event);
      }

      if (!hadUpdate) {
        await Future<void>.delayed(_idlePollDelay);
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  String? _receiveRawUpdate() {
    if (!_isInitialized || _isDisposed) return null;
    final dynamic result = _tdJson.td_receive(0.0);
    if (result is String) {
      return result;
    }
    if (result is Pointer<Utf8> && result.address != 0) {
      return result.toDartString();
    }
    return null;
  }

  void _handleRawUpdate(String event) {
    try {
      final update = jsonDecode(event) as Map<String, dynamic>;
      _captureAuthorizationState(update);
      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
    } catch (e) {
      debugPrint('TDLib update parse error: $e');
    }
  }

  void _captureAuthorizationState(Map<String, dynamic> update) {
    if (update['@type'] != 'updateAuthorizationState') return;

    final authState =
        update['authorization_state'] as Map<String, dynamic>? ?? {};
    _currentAuthState = Map<String, dynamic>.from(authState);
    if (!_authStateController.isClosed) {
      _authStateController.add(Map<String, dynamic>.from(authState));
    }

    final type = authState['@type']?.toString();
    if (type == 'authorizationStateWaitTdlibParameters') {
      unawaited(_setTdlibParametersSafely());
    } else if (type == 'authorizationStateWaitEncryptionKey') {
      unawaited(_checkDatabaseEncryptionKeySafely());
    }
  }

  @override
  void send(Map<String, dynamic> request) {
    if (!_isInitialized || _isDisposed) {
      debugPrint('TDLib send skipped: service is not initialized');
      return;
    }
    final payload = Map<String, dynamic>.from(request);
    payload.putIfAbsent('@extra', _uuid.v4);

    final jsonPointer = jsonEncode(payload).toNativeUtf8();
    try {
      _tdJson.td_send(_clientId, jsonPointer);
    } finally {
      malloc.free(jsonPointer);
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!_isInitialized || _isDisposed) {
      throw Exception('TDLib is not initialized');
    }
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestAt);
    if (elapsed < _minRequestSpacing) {
      await Future.delayed(_minRequestSpacing - elapsed);
    }
    _lastRequestAt = DateTime.now();
    return sendAndWait(request, timeout: timeout);
  }

  Future<Map<String, dynamic>> sendAndWait(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final extra = _uuid.v4();
    final payload = Map<String, dynamic>.from(request);
    payload['@extra'] = extra;

    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription sub;
    sub = updates.listen((update) {
      if (!completer.isCompleted && update['@extra'] == extra) {
        completer.complete(update);
        sub.cancel();
      }
    });

    send(payload);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('TDLib request timed out');
      },
    );
  }

  @override
  Future<Map<String, dynamic>> waitForUpdate(
    bool Function(Map<String, dynamic> update) predicate, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription sub;
    sub = updates.listen((update) {
      if (!completer.isCompleted && predicate(update)) {
        completer.complete(update);
        sub.cancel();
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('TDLib update wait timed out');
      },
    );
  }

  Future<void> setTdlibParameters() async {
    if (_tdlibParametersSent) return;

    final existing = _setParametersInFlight;
    if (existing != null) return existing;

    final future = _setTdlibParameters();
    _setParametersInFlight = future;
    try {
      await future;
    } catch (_) {
      _setParametersInFlight = null;
      rethrow;
    }
  }

  Future<void> _setTdlibParameters() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'tdlib');

    const apiIdDefine = String.fromEnvironment('TELEGRAM_API_ID');
    const apiHashDefine = String.fromEnvironment('TELEGRAM_API_HASH');
    const apiIdString = apiIdDefine;
    const apiHash = apiHashDefine;
    final apiId = int.tryParse(apiIdString) ?? 0;

    if (apiId <= 0 || apiHash.isEmpty) {
      throw StateError('Telegram API credentials are missing or invalid.');
    }

    await Directory(dbPath).create(recursive: true);

    final response = await request({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': dbPath,
      'files_directory': dbPath,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': true,
      'api_id': apiId,
      'api_hash': apiHash,
      'system_language_code': 'en',
      'device_model': _deviceModel,
      'system_version': Platform.operatingSystemVersion,
      'application_version': '1.0.0',
      'enable_storage_optimizer': true,
      'ignore_file_names': false,
    }, timeout: const Duration(seconds: 20));

    if (response['@type'] == 'error') {
      throw Exception(response['message'] ?? 'Unable to configure Telegram');
    }

    _tdlibParametersSent = true;
  }

  Future<Map<String, dynamic>> prepareAuthorization({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var authState = _currentAuthState;

    while (!_isDisposed) {
      authState ??= await _getAuthorizationState(
        timeout: _shortTimeoutBefore(deadline),
      );

      final type = authState['@type']?.toString();
      if (type == null) {
        throw StateError('Telegram authorization state is unavailable');
      }

      if (type == 'authorizationStateWaitTdlibParameters') {
        await setTdlibParameters();
        authState = await _waitForAuthorizationState(
          (next) => next != type,
          timeout: _remainingBefore(deadline),
        );
        continue;
      }

      if (type == 'authorizationStateWaitEncryptionKey') {
        await checkDatabaseEncryptionKey();
        authState = await _waitForAuthorizationState(
          (next) => next != type,
          timeout: _remainingBefore(deadline),
        );
        continue;
      }

      return Map<String, dynamic>.from(authState);
    }

    throw StateError('Telegram service is disposed');
  }

  Future<Map<String, dynamic>> refreshAuthorizationState({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _getAuthorizationState(timeout: timeout);
  }

  Future<Map<String, dynamic>> resetAuthorization({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized || _isDisposed) {
      throw Exception('TDLib is not initialized');
    }

    try {
      await request({'@type': 'destroy'}, timeout: const Duration(seconds: 8));
      await waitForUpdate((event) {
        if (event['@type'] != 'updateAuthorizationState') return false;
        final authState =
            event['authorization_state'] as Map<String, dynamic>? ?? {};
        return authState['@type'] == 'authorizationStateClosed';
      }, timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint('TDLib auth reset continued after destroy warning: $e');
    }

    _clientId = _tdJson.td_create_client_id();
    _tdlibParametersSent = false;
    _databaseEncryptionKeyChecked = false;
    _setParametersInFlight = null;
    _checkEncryptionKeyInFlight = null;
    _currentAuthState = null;

    return prepareAuthorization(timeout: timeout);
  }

  Future<Map<String, dynamic>> _getAuthorizationState({
    required Duration timeout,
  }) async {
    final response = await request({
      '@type': 'getAuthorizationState',
    }, timeout: timeout);
    if (response['@type'] == 'authorizationState') {
      final authState =
          response['authorization_state'] as Map<String, dynamic>? ?? {};
      _currentAuthState = Map<String, dynamic>.from(authState);
      return Map<String, dynamic>.from(authState);
    }
    final responseType = response['@type']?.toString();
    if (responseType != null && responseType.startsWith('authorizationState')) {
      _currentAuthState = Map<String, dynamic>.from(response);
      return Map<String, dynamic>.from(response);
    }
    if (response['@type'] == 'error') {
      throw Exception(response['message'] ?? 'Unable to read auth state');
    }
    throw Exception('Unexpected auth state response: ${response['@type']}');
  }

  Future<void> checkDatabaseEncryptionKey() async {
    if (_databaseEncryptionKeyChecked) return;

    final existing = _checkEncryptionKeyInFlight;
    if (existing != null) return existing;

    final future = _checkDatabaseEncryptionKey();
    _checkEncryptionKeyInFlight = future;
    try {
      await future;
    } catch (_) {
      _checkEncryptionKeyInFlight = null;
      rethrow;
    }
  }

  Future<void> _checkDatabaseEncryptionKey() async {
    final response = await request({
      '@type': 'checkDatabaseEncryptionKey',
      'encryption_key': '',
    }, timeout: const Duration(seconds: 20));

    if (response['@type'] == 'error') {
      throw Exception(
        response['message'] ?? 'Unable to unlock Telegram database',
      );
    }

    _databaseEncryptionKeyChecked = true;
  }

  Future<Map<String, dynamic>> _waitForAuthorizationState(
    bool Function(String type) predicate, {
    required Duration timeout,
  }) async {
    final current = _currentAuthState;
    final currentType = current?['@type']?.toString();
    if (current != null && currentType != null && predicate(currentType)) {
      return Map<String, dynamic>.from(current);
    }

    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription sub;
    sub = _authStateController.stream.listen((authState) {
      final type = authState['@type']?.toString();
      if (!completer.isCompleted && type != null && predicate(type)) {
        completer.complete(Map<String, dynamic>.from(authState));
        sub.cancel();
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Telegram authorization timed out');
      },
    );
  }

  Future<void> _setTdlibParametersSafely() async {
    try {
      await setTdlibParameters();
    } catch (e) {
      debugPrint('TDLib parameter setup failed: $e');
    }
  }

  Future<void> _checkDatabaseEncryptionKeySafely() async {
    try {
      await checkDatabaseEncryptionKey();
    } catch (e) {
      debugPrint('TDLib database key check failed: $e');
    }
  }

  Duration _remainingBefore(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('Telegram authorization timed out');
    }
    return remaining;
  }

  Duration _shortTimeoutBefore(DateTime deadline) {
    final remaining = _remainingBefore(deadline);
    const short = Duration(seconds: 6);
    return remaining < short ? remaining : short;
  }

  String get _deviceModel {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'TeleVault';
  }

  Future<void> sendVerificationCode(String code) async {
    final me = await request({'@type': 'getMe'});
    final chatId = me['id'];

    await request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': 'Your TeleVault Reset Code is: $code',
        },
      },
    });
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    if (!_updatesController.isClosed) {
      await _updatesController.close();
    }
    if (!_authStateController.isClosed) {
      await _authStateController.close();
    }
  }
}
