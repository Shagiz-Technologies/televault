import 'package:flutter_riverpod/flutter_riverpod.dart';

class RuntimeHostActions {
  final Future<void> Function() activateProductionAfterReview;

  const RuntimeHostActions({required this.activateProductionAfterReview});
}

final runtimeHostActionsProvider = Provider<RuntimeHostActions>((ref) {
  throw StateError('Runtime host actions are not configured.');
});
