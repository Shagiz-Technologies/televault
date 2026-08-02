import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/telegram_service.dart';
import '../../sync/services/background_sync_coordinator.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_initializer.dart';
import '../../sync/services/sync_service.dart';

final productionRuntimeShutdownServiceProvider =
    Provider<ProductionRuntimeShutdownService>((ref) {
      final telegram = ref.watch(telegramServiceProvider);
      return ProductionRuntimeShutdownService(
        stopBackground: ref
            .watch(backgroundSyncCoordinatorProvider)
            .stopForAccountCleanup,
        stopSync: ref.watch(syncServiceProvider).stopSyncLoop,
        resetSyncInitializer: ref
            .watch(syncInitializerProvider)
            .resetForAccountCleanup,
        stopUploader: ref.watch(fileUploaderProvider).stopForAccountCleanup,
        closeTelegram: () => _closeTelegramForRuntimeSwitch(telegram),
      );
    });

Future<void> _closeTelegramForRuntimeSwitch(TelegramService telegram) async {
  if (!telegram.isAvailable) {
    await telegram.dispose();
    return;
  }

  try {
    final currentState = telegram.currentAuthorizationStateType;
    if (currentState != 'authorizationStateClosed') {
      final closed = telegram.waitForUpdate(
        (event) {
          if (event['@type'] != 'updateAuthorizationState') return false;
          final state =
              event['authorization_state'] as Map<String, dynamic>? ?? {};
          return state['@type'] == 'authorizationStateClosed';
        },
        timeout: const Duration(seconds: 15),
      );
      if (currentState != 'authorizationStateClosing') {
        telegram.send(const {'@type': 'close'});
      }
      await closed;
    }
  } finally {
    await telegram.dispose();
  }
}

class ProductionRuntimeShutdownService {
  final Future<void> Function() _stopBackground;
  final void Function() _stopSync;
  final void Function() _resetSyncInitializer;
  final Future<void> Function() _stopUploader;
  final Future<void> Function() _closeTelegram;
  bool _running = false;

  ProductionRuntimeShutdownService({
    required Future<void> Function() stopBackground,
    required void Function() stopSync,
    required void Function() resetSyncInitializer,
    required Future<void> Function() stopUploader,
    required Future<void> Function() closeTelegram,
  }) : _stopBackground = stopBackground,
       _stopSync = stopSync,
       _resetSyncInitializer = resetSyncInitializer,
       _stopUploader = stopUploader,
       _closeTelegram = closeTelegram;

  Future<void> shutdownForReviewerDemo() async {
    if (_running) return;
    _running = true;
    try {
      await _stopBackground();
      _stopSync();
      _resetSyncInitializer();
      await _stopUploader();
      await _closeTelegram();
    } finally {
      _running = false;
    }
  }
}
