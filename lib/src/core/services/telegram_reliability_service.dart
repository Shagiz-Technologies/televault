import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import 'telegram_error.dart';
import 'telegram_gateway.dart';
import 'telegram_service.dart';

const int telegramFreeOperationalLimitMb = 1900;
const int telegramPremiumOperationalLimitMb = 3900;

final telegramReliabilityServiceProvider = Provider<TelegramReliabilityService>(
  (ref) {
    final service = TelegramReliabilityService(
      ref.watch(databaseProvider),
      ref.watch(telegramServiceProvider),
    );
    ref.onDispose(() => unawaited(service.dispose()));
    return service;
  },
);

typedef TelegramClock = DateTime Function();
typedef TelegramJitter = Duration Function();

class TelegramReliabilityState {
  final BigInt? accountId;
  final bool isPremium;
  final bool capabilityResolved;
  final DateTime? serverRetryUntil;
  final DateTime? blockedUntil;
  final String? pauseReason;
  final bool isPremiumFloodWait;

  const TelegramReliabilityState({
    this.accountId,
    this.isPremium = false,
    this.capabilityResolved = false,
    this.serverRetryUntil,
    this.blockedUntil,
    this.pauseReason,
    this.isPremiumFloodWait = false,
  });

  int get effectiveUploadLimitMb => isPremium
      ? telegramPremiumOperationalLimitMb
      : telegramFreeOperationalLimitMb;

  bool isBlockedAt(DateTime now) =>
      blockedUntil != null && blockedUntil!.isAfter(now);

  Duration remainingAt(DateTime now) {
    if (!isBlockedAt(now)) return Duration.zero;
    return blockedUntil!.difference(now);
  }

  TelegramReliabilityState copyWith({
    BigInt? accountId,
    bool? isPremium,
    bool? capabilityResolved,
    DateTime? serverRetryUntil,
    DateTime? blockedUntil,
    String? pauseReason,
    bool? isPremiumFloodWait,
    bool clearWait = false,
  }) {
    return TelegramReliabilityState(
      accountId: accountId ?? this.accountId,
      isPremium: isPremium ?? this.isPremium,
      capabilityResolved: capabilityResolved ?? this.capabilityResolved,
      serverRetryUntil: clearWait
          ? null
          : serverRetryUntil ?? this.serverRetryUntil,
      blockedUntil: clearWait ? null : blockedUntil ?? this.blockedUntil,
      pauseReason: clearWait ? null : pauseReason ?? this.pauseReason,
      isPremiumFloodWait: clearWait
          ? false
          : isPremiumFloodWait ?? this.isPremiumFloodWait,
    );
  }
}

class TelegramReliabilityService {
  final AppDatabase _db;
  final TelegramGateway _telegram;
  final TelegramClock _clock;
  final TelegramJitter _jitter;
  final _stateController =
      StreamController<TelegramReliabilityState>.broadcast();

  StreamSubscription<TelegramUpdate>? _updatesSubscription;
  Timer? _gateTimer;
  Future<void>? _initializing;
  Future<void> _writeTail = Future<void>.value();
  TelegramReliabilityState _state = const TelegramReliabilityState();
  bool _initialized = false;
  bool _disposed = false;

  TelegramReliabilityService(
    this._db,
    this._telegram, {
    TelegramClock? clock,
    TelegramJitter? jitter,
    bool autoInitialize = true,
  }) : _clock = clock ?? DateTime.now,
       _jitter = jitter ?? _defaultJitter {
    _updatesSubscription = _telegram.updates.listen(_handleUpdate);
    if (autoInitialize) unawaited(initialize());
  }

  TelegramReliabilityState get currentState => _normalizedState();
  Stream<TelegramReliabilityState> get states => _stateController.stream;
  int get effectiveUploadLimitMb => currentState.effectiveUploadLimitMb;
  bool get isPremium => currentState.isPremium;

  Future<void> initialize() {
    if (_initialized || _disposed) return Future<void>.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    final future = _initialize();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  Future<void> _initialize() async {
    await _restoreLatestAccountState();
    await refreshAccountCapabilities();
    _expireGateIfNeeded();
    _scheduleGateTimer();
    _initialized = true;
  }

  Future<void> refreshAccountCapabilities() async {
    if (_disposed) return;
    BigInt? accountId;
    bool? isPremium;

    try {
      final myId = await _telegram.request({
        '@type': 'getOption',
        'name': 'my_id',
      }, timeout: const Duration(seconds: 8));
      accountId = _bigInt(myId['value']);
    } catch (_) {
      // The last persisted account still protects a restart-time flood gate.
    }

    try {
      final premium = await _telegram.request({
        '@type': 'getOption',
        'name': 'is_premium',
      }, timeout: const Duration(seconds: 8));
      isPremium = premium['value'] is bool ? premium['value'] as bool : null;
    } catch (_) {
      // getMe below is a safe read fallback for older TDLib behavior.
    }

    if (accountId == null || isPremium == null) {
      try {
        final me = await _telegram.request({
          '@type': 'getMe',
        }, timeout: const Duration(seconds: 8));
        accountId ??= _bigInt(me['id']);
        isPremium ??= me['is_premium'] is bool
            ? me['is_premium'] as bool
            : null;
      } catch (_) {
        // A conservative free-account cap remains active while offline.
      }
    }

    if (accountId != null) {
      await updateAccountCapability(
        accountId: accountId,
        isPremium:
            isPremium ??
            (_state.accountId == accountId ? _state.isPremium : false),
      );
    }
  }

  Future<void> updateAccountCapability({
    required BigInt accountId,
    required bool isPremium,
  }) async {
    if (_disposed) return;
    final existing = await (_db.select(
      _db.telegramAccountStates,
    )..where((t) => t.accountId.equals(accountId))).getSingleOrNull();
    final now = _clock();
    await _db
        .into(_db.telegramAccountStates)
        .insertOnConflictUpdate(
          TelegramAccountStatesCompanion.insert(
            accountId: Value(accountId),
            isPremium: Value(isPremium),
            premiumUpdatedAt: Value(now),
            serverRetryUntil: Value(existing?.serverRetryUntil),
            writeBlockedUntil: Value(existing?.writeBlockedUntil),
            pauseReason: Value(existing?.pauseReason),
            isPremiumFloodWait: Value(existing?.isPremiumFloodWait ?? false),
            updatedAt: Value(now),
          ),
        );

    final accountChanged = _state.accountId != accountId;
    _state = TelegramReliabilityState(
      accountId: accountId,
      isPremium: isPremium,
      capabilityResolved: true,
      serverRetryUntil: accountChanged
          ? existing?.serverRetryUntil
          : _state.serverRetryUntil,
      blockedUntil: accountChanged
          ? existing?.writeBlockedUntil
          : _state.blockedUntil,
      pauseReason: accountChanged ? existing?.pauseReason : _state.pauseReason,
      isPremiumFloodWait: accountChanged
          ? existing?.isPremiumFloodWait ?? false
          : _state.isPremiumFloodWait,
    );
    _expireGateIfNeeded();
    _emitState();
    _scheduleGateTimer();
  }

  Future<TelegramResult> executeWrite(
    TelegramRequest request, {
    required String operation,
    BigInt? chatId,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _serializeWrite(
      () => _executeWriteNow(
        request,
        operation: operation,
        chatId: chatId,
        timeout: timeout,
      ),
    );
  }

  Future<TelegramResult> _executeWriteNow(
    TelegramRequest request, {
    required String operation,
    BigInt? chatId,
    required Duration timeout,
  }) async {
    await initialize();
    if (_state.accountId == null) await refreshAccountCapabilities();
    await ensureWriteAllowed(operation: operation, chatId: chatId);
    TelegramResult response;
    try {
      response = await _telegram.request(request, timeout: timeout);
    } catch (error) {
      throw TelegramErrorParser.fromThrown(
        error,
        operation: operation,
        chatId: chatId,
      );
    }
    final parsed = TelegramErrorParser.parse(
      response,
      operation: operation,
      chatId: chatId,
    );
    if (parsed != null) {
      await registerError(parsed);
      throw parsed;
    }
    return response;
  }

  Future<int> sendMessageAndWait({
    required String operation,
    required BigInt chatId,
    required Map<String, dynamic> inputMessageContent,
    required Duration timeout,
  }) {
    return _serializeWrite(
      () => _sendMessageAndWaitNow(
        operation: operation,
        chatId: chatId,
        inputMessageContent: inputMessageContent,
        timeout: timeout,
      ),
    );
  }

  Future<int> _sendMessageAndWaitNow({
    required String operation,
    required BigInt chatId,
    required Map<String, dynamic> inputMessageContent,
    required Duration timeout,
  }) async {
    final chatIdInt = _tdInt64(chatId);
    if (chatIdInt == null) {
      throw TelegramError(
        code: null,
        tdlibMessage: 'Invalid Telegram chat id',
        operation: operation,
        chatId: chatId,
        category: TelegramErrorCategory.permanent,
        canRetry: false,
      );
    }

    int? temporaryMessageId;
    final bufferedSendUpdates = <TelegramUpdate>[];
    final sendUpdateCompleter = Completer<TelegramUpdate>();
    late final StreamSubscription<TelegramUpdate> sendUpdateSubscription;
    sendUpdateSubscription = _telegram.updates.listen((candidate) {
      final type = candidate['@type'];
      if (type != 'updateMessageSendSucceeded' &&
          type != 'updateMessageSendFailed') {
        return;
      }
      if (temporaryMessageId == null) {
        bufferedSendUpdates.add(candidate);
        return;
      }
      if (!sendUpdateCompleter.isCompleted &&
          _matchesSendUpdate(candidate, temporaryMessageId, chatId)) {
        sendUpdateCompleter.complete(candidate);
      }
    });

    TelegramResult response;
    try {
      response = await _executeWriteNow(
        {
          '@type': 'sendMessage',
          'chat_id': chatIdInt,
          'input_message_content': inputMessageContent,
        },
        operation: operation,
        chatId: chatId,
        timeout: timeout,
      );
    } catch (_) {
      await sendUpdateSubscription.cancel();
      rethrow;
    }
    if (response['@type'] != 'message') {
      await sendUpdateSubscription.cancel();
      throw TelegramError(
        code: null,
        tdlibMessage: 'Unexpected TDLib send response',
        operation: operation,
        chatId: chatId,
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }

    final initialFailure = TelegramErrorParser.parse(
      response,
      operation: operation,
      chatId: chatId,
    );
    if (initialFailure != null) {
      await sendUpdateSubscription.cancel();
      await registerError(initialFailure);
      throw initialFailure;
    }

    temporaryMessageId = _int(response['id']);
    if (temporaryMessageId == null) {
      await sendUpdateSubscription.cancel();
      throw TelegramError(
        code: null,
        tdlibMessage: 'TDLib message identifier missing',
        operation: operation,
        chatId: chatId,
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }

    for (final candidate in bufferedSendUpdates) {
      if (!sendUpdateCompleter.isCompleted &&
          _matchesSendUpdate(candidate, temporaryMessageId, chatId)) {
        sendUpdateCompleter.complete(candidate);
        break;
      }
    }

    if (response['sending_state'] == null) {
      await sendUpdateSubscription.cancel();
      return _verifySentMessage(
        operation: operation,
        chatId: chatId,
        messageId: temporaryMessageId,
      );
    }

    TelegramUpdate update;
    try {
      update = await sendUpdateCompleter.future.timeout(timeout);
    } catch (error) {
      await sendUpdateSubscription.cancel();
      throw TelegramErrorParser.fromThrown(
        error,
        operation: operation,
        chatId: chatId,
      );
    }
    await sendUpdateSubscription.cancel();

    final failure = TelegramErrorParser.parse(
      update,
      operation: operation,
      chatId: chatId,
    );
    if (failure != null) {
      await registerError(failure);
      throw failure;
    }
    final confirmedMessageId =
        _int((update['message'] as Map?)?['id']) ?? temporaryMessageId;
    return _verifySentMessage(
      operation: operation,
      chatId: chatId,
      messageId: confirmedMessageId,
    );
  }

  Future<int> _verifySentMessage({
    required String operation,
    required BigInt chatId,
    required int messageId,
  }) async {
    final chatIdInt = _tdInt64(chatId)!;
    for (var attempt = 0; attempt < 4; attempt++) {
      TelegramResult response;
      try {
        response = await _telegram.request({
          '@type': 'getMessage',
          'chat_id': chatIdInt,
          'message_id': messageId,
        }, timeout: const Duration(seconds: 15));
      } catch (error) {
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 250 << attempt));
          continue;
        }
        throw TelegramErrorParser.fromThrown(
          error,
          operation: 'verify_sent_message',
          chatId: chatId,
        );
      }

      final error = TelegramErrorParser.parse(
        response,
        operation: 'verify_sent_message',
        chatId: chatId,
      );
      final responseId = _int(response['id']);
      final responseChatId = _bigInt(response['chat_id']);
      if (error == null &&
          response['@type'] == 'message' &&
          responseId == messageId &&
          responseChatId == chatId &&
          response['sending_state'] == null) {
        return messageId;
      }
      if (error != null && error.code != 404) {
        await registerError(error);
        throw error;
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 250 << attempt));
      }
    }

    throw TelegramError(
      code: 404,
      tdlibMessage: 'Telegram did not confirm the uploaded message',
      operation: operation,
      chatId: chatId,
      category: TelegramErrorCategory.transient,
      canRetry: true,
    );
  }

  Future<Set<int>> findConfirmedMessages({
    required BigInt chatId,
    required List<int> messageIds,
  }) async {
    if (messageIds.isEmpty) return const <int>{};
    final chatIdInt = _tdInt64(chatId);
    if (chatIdInt == null) return const <int>{};
    final response = await _telegram.request({
      '@type': 'getMessages',
      'chat_id': chatIdInt,
      'message_ids': messageIds,
    }, timeout: const Duration(seconds: 30));
    final error = TelegramErrorParser.parse(
      response,
      operation: 'verify_bucket_messages',
      chatId: chatId,
    );
    if (error != null) throw error;
    if (response['@type'] != 'messages') {
      throw TelegramError(
        code: null,
        tdlibMessage: 'Unexpected TDLib message verification response',
        operation: 'verify_bucket_messages',
        chatId: chatId,
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }
    final messages = response['messages'];
    if (messages is! List) return const <int>{};
    return messages
        .whereType<Map>()
        .where(
          (message) =>
              _bigInt(message['chat_id']) == chatId &&
              message['sending_state'] == null,
        )
        .map((message) => _int(message['id']))
        .whereType<int>()
        .toSet();
  }

  bool _matchesSendUpdate(
    TelegramUpdate candidate,
    int temporaryMessageId,
    BigInt chatId,
  ) {
    final oldId = _int(candidate['old_message_id']);
    final updateChatId = _bigInt((candidate['message'] as Map?)?['chat_id']);
    return oldId == temporaryMessageId && updateChatId == chatId;
  }

  Future<void> ensureWriteAllowed({
    required String operation,
    BigInt? chatId,
  }) async {
    _expireGateIfNeeded();
    final state = _state;
    final now = _clock();
    if (!state.isBlockedAt(now)) return;
    throw TelegramError(
      code: 429,
      tdlibMessage: 'Local persisted Telegram write gate is active',
      operation: operation,
      chatId: chatId,
      category: TelegramErrorCategory.exactWait,
      canRetry: true,
      retryAfter: state.blockedUntil!.difference(now),
      isFloodWait: true,
      isPremiumFloodWait: state.isPremiumFloodWait,
    );
  }

  Future<void> registerError(TelegramError error) async {
    final retryAfter = error.retryAfter;
    if (retryAfter == null) return;
    await initialize();
    final accountId = _state.accountId;
    final now = _clock();
    final requiredServerUntil = now.add(retryAfter);
    final requiredBlockedUntil = requiredServerUntil.add(_jitter());
    if (accountId == null) {
      _state = _state.copyWith(
        serverRetryUntil: requiredServerUntil,
        blockedUntil: requiredBlockedUntil,
        pauseReason: _pauseReasonFor(error),
        isPremiumFloodWait: error.isPremiumFloodWait,
      );
      _emitState();
      _scheduleGateTimer();
      return;
    }
    final existing = await (_db.select(
      _db.telegramAccountStates,
    )..where((t) => t.accountId.equals(accountId))).getSingleOrNull();
    final keepExisting =
        existing?.writeBlockedUntil?.isAfter(requiredBlockedUntil) ?? false;
    final blockedUntil = keepExisting
        ? existing!.writeBlockedUntil!
        : requiredBlockedUntil;
    final serverUntil = keepExisting
        ? existing!.serverRetryUntil ?? requiredServerUntil
        : requiredServerUntil;
    final premiumWait = keepExisting
        ? existing!.isPremiumFloodWait
        : error.isPremiumFloodWait;
    final reason = keepExisting
        ? existing!.pauseReason
        : _pauseReasonFor(error);

    await _db
        .into(_db.telegramAccountStates)
        .insertOnConflictUpdate(
          TelegramAccountStatesCompanion.insert(
            accountId: Value(accountId),
            isPremium: Value(_state.isPremium),
            premiumUpdatedAt: Value(existing?.premiumUpdatedAt),
            serverRetryUntil: Value(serverUntil),
            writeBlockedUntil: Value(blockedUntil),
            pauseReason: Value(reason),
            isPremiumFloodWait: Value(premiumWait),
            updatedAt: Value(now),
          ),
        );
    _state = _state.copyWith(
      serverRetryUntil: serverUntil,
      blockedUntil: blockedUntil,
      pauseReason: reason,
      isPremiumFloodWait: premiumWait,
    );
    _emitState();
    _scheduleGateTimer();
  }

  Future<void> clearAccountState() async {
    _gateTimer?.cancel();
    await _db.delete(_db.telegramAccountStates).go();
    _state = const TelegramReliabilityState();
    _initialized = false;
    _initializing = null;
    _emitState();
  }

  int normalizeUploadLimitMb(int requested) =>
      requested.clamp(32, effectiveUploadLimitMb).toInt();

  bool canUploadBytes(int bytes) =>
      bytes <= effectiveUploadLimitMb * 1024 * 1024;

  Future<T> _serializeWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeTail = _writeTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _restoreLatestAccountState() async {
    final row =
        await (_db.select(_db.telegramAccountStates)
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;
    _state = TelegramReliabilityState(
      accountId: row.accountId,
      isPremium: row.isPremium,
      capabilityResolved: row.premiumUpdatedAt != null,
      serverRetryUntil: row.serverRetryUntil,
      blockedUntil: row.writeBlockedUntil,
      pauseReason: row.pauseReason,
      isPremiumFloodWait: row.isPremiumFloodWait,
    );
    _emitState();
  }

  void _handleUpdate(TelegramUpdate update) {
    if (_disposed) return;
    if (update['@type'] == 'updateAuthorizationState' &&
        (update['authorization_state'] as Map?)?['@type'] ==
            'authorizationStateReady') {
      unawaited(refreshAccountCapabilities());
      return;
    }
    if (update['@type'] == 'updateOption') {
      final name = update['name']?.toString();
      final value = update['value'] as Map?;
      if (name == 'is_premium' && value?['value'] is bool) {
        final accountId = _state.accountId;
        if (accountId != null) {
          unawaited(
            updateAccountCapability(
              accountId: accountId,
              isPremium: value!['value'] as bool,
            ),
          );
        }
      } else if (name == 'my_id') {
        final accountId = _bigInt(value?['value']);
        if (accountId != null) {
          unawaited(
            updateAccountCapability(
              accountId: accountId,
              isPremium: _state.isPremium,
            ),
          );
        }
      }
      return;
    }
    if (update['@type'] == 'updateUser') {
      final user = update['user'] as Map?;
      final accountId = _bigInt(user?['id']);
      if (accountId != null &&
          accountId == _state.accountId &&
          user?['is_premium'] is bool) {
        unawaited(
          updateAccountCapability(
            accountId: accountId,
            isPremium: user!['is_premium'] as bool,
          ),
        );
      }
    }
  }

  TelegramReliabilityState _normalizedState() {
    _expireGateIfNeeded();
    return _state;
  }

  void _expireGateIfNeeded() {
    final blockedUntil = _state.blockedUntil;
    if (blockedUntil == null || blockedUntil.isAfter(_clock())) return;
    _state = _state.copyWith(clearWait: true);
    final accountId = _state.accountId;
    if (accountId != null) {
      unawaited(
        (_db.update(
          _db.telegramAccountStates,
        )..where((t) => t.accountId.equals(accountId))).write(
          TelegramAccountStatesCompanion(
            serverRetryUntil: const Value(null),
            writeBlockedUntil: const Value(null),
            pauseReason: const Value(null),
            isPremiumFloodWait: const Value(false),
            updatedAt: Value(_clock()),
          ),
        ),
      );
    }
    _emitState();
  }

  void _scheduleGateTimer() {
    _gateTimer?.cancel();
    final blockedUntil = _state.blockedUntil;
    if (blockedUntil == null) return;
    final delay = blockedUntil.difference(_clock());
    if (delay <= Duration.zero) {
      _expireGateIfNeeded();
      return;
    }
    _gateTimer = Timer(delay, _expireGateIfNeeded);
  }

  void _emitState() {
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  static Duration _defaultJitter() {
    final milliseconds = 250 + Random.secure().nextInt(751);
    return Duration(milliseconds: milliseconds);
  }

  static String _pauseReasonFor(TelegramError error) {
    if (error.isPremiumFloodWait) return 'Telegram Premium flood wait';
    if (error.isFloodWait) return 'Telegram flood wait';
    return 'Telegram required retry wait';
  }

  static int? _tdInt64(BigInt value) {
    try {
      return value.toInt();
    } catch (_) {
      return null;
    }
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static BigInt? _bigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is num) return BigInt.from(value.toInt());
    if (value is String) return BigInt.tryParse(value);
    return null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _gateTimer?.cancel();
    await _updatesSubscription?.cancel();
    await _stateController.close();
  }
}
