import 'package:flutter_riverpod/flutter_riverpod.dart';

class RuntimeHostActions {
  final Future<void> Function() activateReviewerDemoAfterProduction;

  const RuntimeHostActions({required this.activateReviewerDemoAfterProduction});
}

final runtimeHostActionsProvider = Provider<RuntimeHostActions>((ref) {
  throw StateError('Runtime host actions are not configured.');
});
