import 'dart:async';

enum TelegramErrorCategory {
  permanent,
  exactWait,
  transient,
  authentication,
  permission,
  userActionRequired,
}

class TelegramError implements Exception {
  final int? code;
  final String tdlibMessage;
  final String operation;
  final BigInt? chatId;
  final TelegramErrorCategory category;
  final bool canRetry;
  final Duration? retryAfter;
  final bool isFloodWait;
  final bool isPremiumFloodWait;
  final bool userActionRequired;

  const TelegramError({
    required this.code,
    required this.tdlibMessage,
    required this.operation,
    required this.category,
    required this.canRetry,
    this.chatId,
    this.retryAfter,
    this.isFloodWait = false,
    this.isPremiumFloodWait = false,
    this.userActionRequired = false,
  });

  bool get hasExactRetryAfter => retryAfter != null;

  String get userMessage {
    if (code == 406) {
      return 'Telegram temporarily rejected this operation.';
    }
    return switch (category) {
      TelegramErrorCategory.exactWait =>
        isPremiumFloodWait
            ? 'Telegram paused this operation. Telegram Premium may reduce this wait.'
            : 'Telegram paused this operation until the required wait ends.',
      TelegramErrorCategory.authentication =>
        'Reconnect your Telegram account to continue.',
      TelegramErrorCategory.permission =>
        'TeleVault cannot post to this Telegram channel. Check channel permissions.',
      TelegramErrorCategory.userActionRequired =>
        'Telegram requires an account or channel change before this can continue.',
      TelegramErrorCategory.permanent =>
        'Telegram cannot process this item in its current state.',
      TelegramErrorCategory.transient =>
        'Telegram is temporarily unavailable. TeleVault will retry safely.',
    };
  }

  @override
  String toString() => userMessage;
}

class TelegramErrorParser {
  static final RegExp _premiumFloodWait = RegExp(
    r'FLOOD_PREMIUM_WAIT_([0-9]+)',
    caseSensitive: false,
  );
  static final RegExp _floodWait = RegExp(
    r'FLOOD_WAIT_([0-9]+)',
    caseSensitive: false,
  );
  static final RegExp _textRetryAfter = RegExp(
    r'retry\s+after\s+([0-9]+)',
    caseSensitive: false,
  );

  const TelegramErrorParser._();

  static TelegramError? parse(
    Map<String, dynamic> payload, {
    required String operation,
    BigInt? chatId,
  }) {
    final type = payload['@type']?.toString();
    Map<String, dynamic>? error;
    Map<String, dynamic>? sendingState;

    if (type == 'error') {
      error = payload;
    } else if (type == 'updateMessageSendFailed') {
      error = _map(payload['error']);
      sendingState = _map(_map(payload['message'])?['sending_state']);
    } else if (type == 'message') {
      sendingState = _map(payload['sending_state']);
      if (sendingState?['@type'] == 'messageSendingStateFailed') {
        error = _map(sendingState?['error']);
      } else {
        return null;
      }
    } else if (type == 'messageSendingStateFailed') {
      sendingState = payload;
      error = _map(payload['error']);
    } else {
      return null;
    }

    final code = _int(error?['code']);
    final message = error?['message']?.toString() ?? '';
    // TDLib explicitly documents error 406 text as internal-only. Preserve it
    // for typed diagnostics, but never inspect it to drive app behavior.
    final processMessage = code != 406;
    final structuredRetry =
        _retryAfterFrom(sendingState) ??
        _retryAfterFrom(payload) ??
        _retryAfterFrom(error);
    final premiumMatch = processMessage
        ? _premiumFloodWait.firstMatch(message)
        : null;
    final floodMatch = processMessage ? _floodWait.firstMatch(message) : null;
    final premiumWait = premiumMatch != null;
    final standardWait = floodMatch != null;
    final stringRetry =
        processMessage && premiumMatch == null && floodMatch == null
        ? _textRetryAfter.firstMatch(message)
        : null;
    final parsedStringSeconds = _int(
      premiumMatch?.group(1) ?? floodMatch?.group(1) ?? stringRetry?.group(1),
    );
    final retryAfter =
        structuredRetry ??
        (parsedStringSeconds != null && parsedStringSeconds > 0
            ? Duration(seconds: parsedStringSeconds)
            : null);
    final exactWait = retryAfter != null;
    final explicitCanRetry =
        _bool(sendingState?['can_retry']) ??
        _bool(payload['can_retry']) ??
        _bool(error?['can_retry']);
    final category = _category(
      code: code,
      message: processMessage ? message : '',
      exactWait: exactWait,
      explicitCanRetry: explicitCanRetry,
    );
    final requiresAction =
        category == TelegramErrorCategory.permission ||
        category == TelegramErrorCategory.userActionRequired ||
        category == TelegramErrorCategory.authentication;

    return TelegramError(
      code: code,
      tdlibMessage: message,
      operation: operation,
      chatId: chatId,
      category: category,
      canRetry:
          exactWait ||
          (category == TelegramErrorCategory.transient &&
              explicitCanRetry != false),
      retryAfter: retryAfter,
      isFloodWait: standardWait || premiumWait,
      isPremiumFloodWait: premiumWait,
      userActionRequired: requiresAction,
    );
  }

  static TelegramError fromThrown(
    Object error, {
    required String operation,
    BigInt? chatId,
  }) {
    if (error is TelegramError) return error;
    if (error is TimeoutException) {
      return TelegramError(
        code: null,
        tdlibMessage: 'TDLib request timed out',
        operation: operation,
        chatId: chatId,
        category: TelegramErrorCategory.transient,
        canRetry: true,
      );
    }
    return TelegramError(
      code: null,
      tdlibMessage: 'TDLib request failed without a structured error',
      operation: operation,
      chatId: chatId,
      category: TelegramErrorCategory.transient,
      canRetry: true,
    );
  }

  static TelegramErrorCategory _category({
    required int? code,
    required String message,
    required bool exactWait,
    required bool? explicitCanRetry,
  }) {
    if (exactWait) return TelegramErrorCategory.exactWait;
    final normalized = message.toUpperCase();
    if (code == 401 ||
        normalized.contains('AUTH_KEY_UNREGISTERED') ||
        normalized.contains('SESSION_REVOKED') ||
        normalized.contains('USER_DEACTIVATED')) {
      return TelegramErrorCategory.authentication;
    }
    if (code == 403 ||
        normalized.contains('CHAT_WRITE_FORBIDDEN') ||
        normalized.contains('CHAT_ADMIN_REQUIRED') ||
        normalized.contains('CHANNEL_PRIVATE') ||
        normalized.contains('USER_BANNED_IN_CHANNEL')) {
      return TelegramErrorCategory.permission;
    }
    if (normalized.contains('PREMIUM_ACCOUNT_REQUIRED') ||
        normalized.contains('ACCOUNT_RESTRICTED')) {
      return TelegramErrorCategory.userActionRequired;
    }
    if ((code != null && code >= 500) ||
        code == 406 ||
        code == 420 ||
        code == 429 ||
        normalized.contains('TIMEOUT') ||
        normalized.contains('TEMPORARILY_UNAVAILABLE') ||
        normalized.contains('NETWORK')) {
      return TelegramErrorCategory.transient;
    }
    if (explicitCanRetry == true) {
      return TelegramErrorCategory.transient;
    }
    return TelegramErrorCategory.permanent;
  }

  static Duration? _retryAfterFrom(Map<String, dynamic>? value) {
    if (value == null) return null;
    final raw = value['retry_after'];
    final seconds = switch (raw) {
      num number => number.ceil(),
      String text => double.tryParse(text)?.ceil(),
      _ => null,
    };
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _bool(dynamic value) => value is bool ? value : null;
}
