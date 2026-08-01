import 'dart:async';

typedef TelegramUpdate = Map<String, dynamic>;
typedef TelegramRequest = Map<String, dynamic>;
typedef TelegramResult = Map<String, dynamic>;

abstract interface class TelegramGateway {
  Stream<TelegramUpdate> get updates;
  void send(TelegramRequest request);
  Future<void> waitUntilReady({Duration timeout});
  Future<TelegramResult> request(TelegramRequest request, {Duration timeout});
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout,
  });
  Future<void> dispose();
}
