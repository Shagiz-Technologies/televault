import 'dart:async';

import 'package:tele_vault/src/core/services/telegram_gateway.dart';

typedef TelegramRequestHandler =
    FutureOr<TelegramResult> Function(TelegramRequest request);

class FakeTelegramGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  final List<TelegramRequest> requests = [];
  TelegramRequestHandler? handler;

  FakeTelegramGateway({this.handler});

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  void emit(TelegramUpdate update) => _updates.add(update);

  int requestCount(String type) =>
      requests.where((request) => request['@type'] == type).length;

  @override
  void send(TelegramRequest request) {
    requests.add(Map<String, dynamic>.from(request));
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    requests.add(Map<String, dynamic>.from(request));
    final requestHandler = handler;
    if (requestHandler != null) return requestHandler(request);
    return switch ((request['@type'], request['name'])) {
      ('getOption', 'my_id') => {'@type': 'optionValueInteger', 'value': 123},
      ('getOption', 'is_premium') => {
        '@type': 'optionValueBoolean',
        'value': false,
      },
      ('getMe', _) => {'@type': 'user', 'id': 123, 'is_premium': false},
      _ => throw UnimplementedError(
        'Unexpected Telegram request: ${request['@type']}',
      ),
    };
  }

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return updates.firstWhere(predicate).timeout(timeout);
  }

  @override
  Future<void> dispose() => _updates.close();
}
