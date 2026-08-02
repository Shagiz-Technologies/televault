import 'dart:async';

import '../../../core/services/telegram_gateway.dart';

class ReviewerDemoUploadResult {
  final String operationId;
  final bool simulated;

  const ReviewerDemoUploadResult({
    required this.operationId,
    this.simulated = true,
  });
}

/// A deterministic, network-free gateway used only by Reviewer Demo.
class ReviewerDemoGateway implements TelegramGateway {
  final _updates = StreamController<TelegramUpdate>.broadcast();
  int _operationCount = 0;
  bool _disposed = false;

  int get simulatedOperationCount => _operationCount;

  @override
  Stream<TelegramUpdate> get updates => _updates.stream;

  Future<ReviewerDemoUploadResult> simulateUpload() async {
    if (_disposed) throw StateError('Reviewer Demo gateway is closed.');
    _operationCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return ReviewerDemoUploadResult(
      operationId: 'reviewer-demo-$_operationCount',
    );
  }

  Never _networkDisabled() => throw UnsupportedError(
    'Reviewer Demo does not initialize TDLib or send data to Telegram.',
  );

  @override
  void send(TelegramRequest request) => _networkDisabled();

  @override
  Future<TelegramResult> request(
    TelegramRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async => _networkDisabled();

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 45),
  }) async => _networkDisabled();

  @override
  Future<TelegramUpdate> waitForUpdate(
    bool Function(TelegramUpdate update) predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) async => _networkDisabled();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _updates.close();
  }
}
