import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libtdjson/libtdjson.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'telegram_gateway.dart';
import 'telegram_error.dart';

final telegramServiceProvider = Provider<TelegramService>((ref) {
  final service = TelegramService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class TelegramService implements TelegramGateway {
  static const _iosSmokeTest = bool.fromEnvironment('TELEVAULT_IOS_SMOKE_TEST');
  static const _iosDatabaseKeyName = 'telegram_tdlib_database_key_v1';
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

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
  Object? _initializationError;
  Future<void>? _setParametersInFlight;
  Future<void>? _checkEncryptionKeyInFlight;
  Map<String, dynamic>? _currentAuthState;

  @override
  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  bool get isAvailable => _isInitialized && !_isDisposed;

  String? get unavailableReason {
    if (isAvailable) return null;
    if (_isDisposed) return 'Telegram service is disposed.';
    final error = _initializationError;
    if (error != null) return 'TDLib initialization failed: $error';
    return 'TDLib is not initialized.';
  }

  String? get currentAuthorizationStateType =>
      _currentAuthState?['@type']?.toString();

  TelegramService() {
    _init();
  }

  void _init() {
    try {
      _tdJson = NativeClient();
      if (Platform.isIOS) {
        _configureIosNativeLogging();
      }
      _clientId = _tdJson.td_create_client_id();
      if (Platform.isIOS) {
        _runIosNativeSmokeTest();
      }
      _isInitialized = true;
      debugPrint('TDLib client initialized.');
      if (Platform.isIOS && _iosSmokeTest) {
        unawaited(_writeIosSmokeMarker());
      }
      _startEventLoop();
    } catch (error) {
      _initializationError = error;
      debugPrint('TDLib initialization failed.');
    }
  }

  void _configureIosNativeLogging() {
    _executeIosNativeRequest(
      const {'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 0},
      expectedType: 'ok',
      operation: 'privacy logging configuration',
    );
  }

  void _runIosNativeSmokeTest() {
    _executeIosNativeRequest(
      const {'@type': 'getTextEntities', 'text': 'TeleVault'},
      expectedType: 'textEntities',
      operation: 'startup smoke test',
    );
  }

  Map<String, dynamic> _executeIosNativeRequest(
    Map<String, dynamic> requestBody, {
    required String expectedType,
    required String operation,
  }) {
    final request = jsonEncode(requestBody).toNativeUtf8();
    try {
      final resultPointer = _tdJson.td_execute(request);
      if (resultPointer.address == 0) {
        throw StateError('TDLib $operation returned no response.');
      }
      final decoded = jsonDecode(resultPointer.toDartString());
      if (decoded is! Map<String, dynamic> ||
          decoded['@type'] != expectedType) {
        final responseType = decoded is Map<String, dynamic>
            ? decoded['@type']?.toString() ?? 'unknown'
            : decoded.runtimeType.toString();
        throw StateError(
          'TDLib $operation returned an unexpected response: '
          '$responseType.',
        );
      }
      return decoded;
    } finally {
      malloc.free(request);
    }
  }

  Future<void> _writeIosSmokeMarker() async {
    try {
      await File(
        p.join(Directory.systemTemp.path, 'televault_tdlib_ready'),
      ).writeAsString('ready', flush: true);
    } catch (_) {
      debugPrint('Unable to write the iOS smoke marker.');
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
    } catch (_) {
      debugPrint('TDLib update parsing failed.');
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
      debugPrint('TDLib send skipped because the engine is unavailable.');
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
    _ensureInitialized();
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
    _ensureInitialized();
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
    _ensureInitialized();
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
    _ensureInitialized();
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
    final storageRoot = Platform.isIOS
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    final tdlibRoot = p.join(storageRoot.path, 'tdlib');
    final dbPath = Platform.isIOS ? p.join(tdlibRoot, 'database') : tdlibRoot;
    final filesPath = Platform.isIOS ? p.join(tdlibRoot, 'files') : tdlibRoot;

    const apiIdDefine = String.fromEnvironment('TELEGRAM_API_ID');
    const apiHashDefine = String.fromEnvironment('TELEGRAM_API_HASH');
    const apiIdString = apiIdDefine;
    const apiHash = apiHashDefine;
    final apiId = int.tryParse(apiIdString) ?? 0;

    if (apiId <= 0 || apiHash.isEmpty) {
      throw const TelegramError(
        code: null,
        tdlibMessage: 'Telegram API credentials are missing or invalid',
        operation: 'configure_tdlib',
        category: TelegramErrorCategory.userActionRequired,
        canRetry: false,
        userActionRequired: true,
      );
    }

    await Directory(dbPath).create(recursive: true);
    await Directory(filesPath).create(recursive: true);

    final response = await request({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': dbPath,
      'files_directory': filesPath,
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
      throw TelegramErrorParser.parse(response, operation: 'configure_tdlib')!;
    }

    _tdlibParametersSent = true;
  }

  Future<Map<String, dynamic>> prepareAuthorization({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ensureInitialized();
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

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final authState = await prepareAuthorization(timeout: timeout);
    final type = authState['@type']?.toString();
    if (type != 'authorizationStateReady') {
      throw StateError('Telegram session is not ready. Current state: $type');
    }
  }

  Future<Map<String, dynamic>> refreshAuthorizationState({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _getAuthorizationState(timeout: timeout);
  }

  Future<Map<String, dynamic>> resetAuthorization({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ensureInitialized();

    try {
      await request({'@type': 'destroy'}, timeout: const Duration(seconds: 8));
      await waitForUpdate((event) {
        if (event['@type'] != 'updateAuthorizationState') return false;
        final authState =
            event['authorization_state'] as Map<String, dynamic>? ?? {};
        return authState['@type'] == 'authorizationStateClosed';
      }, timeout: const Duration(seconds: 10));
    } catch (_) {
      debugPrint('TDLib auth reset continued after a destroy warning.');
    }

    _clientId = _tdJson.td_create_client_id();
    _tdlibParametersSent = false;
    _databaseEncryptionKeyChecked = false;
    _setParametersInFlight = null;
    _checkEncryptionKeyInFlight = null;
    _currentAuthState = null;

    return prepareAuthorization(timeout: timeout);
  }

  Future<void> clearLocalAccountStorage() async {
    _ensureInitialized();
    try {
      await request({'@type': 'destroy'}, timeout: const Duration(seconds: 8));
    } catch (_) {
      // Cleanup remains safe to retry after TDLib has already closed.
    }

    _clientId = _tdJson.td_create_client_id();
    _tdlibParametersSent = false;
    _databaseEncryptionKeyChecked = false;
    _setParametersInFlight = null;
    _checkEncryptionKeyInFlight = null;
    _currentAuthState = null;

    final root = await _tdlibRootDirectory();
    for (var attempt = 0; attempt < 3 && await root.exists(); attempt++) {
      try {
        await root.delete(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (await root.exists()) {
      throw const FileSystemException(
        'TDLib local account storage could not be removed.',
      );
    }
    if (Platform.isIOS) {
      await _secureStorage.delete(key: _iosDatabaseKeyName);
    }
  }

  Future<Directory> _tdlibRootDirectory() async {
    final storageRoot = Platform.isIOS
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    return Directory(p.join(storageRoot.path, 'tdlib'));
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
      throw TelegramErrorParser.parse(
        response,
        operation: 'read_authorization_state',
      )!;
    }
    throw const TelegramError(
      code: null,
      tdlibMessage: 'Unexpected authorization state response',
      operation: 'read_authorization_state',
      category: TelegramErrorCategory.transient,
      canRetry: true,
    );
  }

  Future<void> checkDatabaseEncryptionKey() async {
    _ensureInitialized();
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
    final encryptionKey = await _databaseEncryptionKey();
    final response = await request({
      '@type': 'checkDatabaseEncryptionKey',
      'encryption_key': encryptionKey,
    }, timeout: const Duration(seconds: 20));

    if (response['@type'] == 'error') {
      throw TelegramErrorParser.parse(
        response,
        operation: 'unlock_tdlib_database',
      )!;
    }

    _databaseEncryptionKeyChecked = true;
  }

  Future<String> _databaseEncryptionKey() async {
    if (!Platform.isIOS) return '';

    final existing = await _secureStorage.read(key: _iosDatabaseKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final generated = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secureStorage.write(key: _iosDatabaseKeyName, value: generated);
    return generated;
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
    } catch (_) {
      debugPrint('TDLib parameter setup failed.');
    }
  }

  Future<void> _checkDatabaseEncryptionKeySafely() async {
    try {
      await checkDatabaseEncryptionKey();
    } catch (_) {
      debugPrint('TDLib database key check failed.');
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

  void _ensureInitialized() {
    if (_isInitialized && !_isDisposed) return;
    final reason = unavailableReason ?? 'TDLib is not initialized.';
    throw StateError(reason);
  }

  String get _deviceModel {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'TeleVault';
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
