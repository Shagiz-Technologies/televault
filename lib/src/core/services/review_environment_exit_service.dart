import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/services/local_account_cleanup_coordinator.dart';
import '../config/app_runtime_environment.dart';
import '../config/runtime_host_actions.dart';
import 'telegram_service.dart';

final reviewEnvironmentExitServiceProvider =
    Provider<ReviewEnvironmentExitService>((ref) {
      return ReviewEnvironmentExitService(
        cleanupReviewEnvironment: ref
            .watch(localAccountCleanupCoordinatorProvider)
            .clearReviewEnvironment,
        disposeTelegram: ref.watch(telegramServiceProvider).dispose,
        activateProduction: ref
            .watch(runtimeHostActionsProvider)
            .activateProductionAfterReview,
      );
    });

class ReviewEnvironmentExitService {
  final Future<void> Function() _cleanupReviewEnvironment;
  final Future<void> Function() _disposeTelegram;
  final Future<void> Function() _activateProduction;
  bool _running = false;

  ReviewEnvironmentExitService({
    required Future<void> Function() cleanupReviewEnvironment,
    required Future<void> Function() disposeTelegram,
    required Future<void> Function() activateProduction,
  }) : _cleanupReviewEnvironment = cleanupReviewEnvironment,
       _disposeTelegram = disposeTelegram,
       _activateProduction = activateProduction;

  Future<void> returnToProduction() async {
    if (_running) return;
    if (!AppRuntimeEnvironment.isPlayStoreReview) return;
    if (AppRuntimeEnvironment.compileTimeReviewEnabled) {
      throw StateError(
        'Compile-time review builds remain in the Test Environment.',
      );
    }
    _running = true;
    try {
      await _cleanupReviewEnvironment();
      await _disposeTelegram();
      await _activateProduction();
    } finally {
      _running = false;
    }
  }
}
