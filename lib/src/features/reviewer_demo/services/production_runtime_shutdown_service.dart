import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/telegram_service.dart';
import '../../sync/services/background_sync_coordinator.dart';
import '../../sync/services/file_uploader.dart';
import '../../sync/services/sync_initializer.dart';
import '../../sync/services/sync_service.dart';

final productionRuntimeShutdownServiceProvider =
    Provider<ProductionRuntimeShutdownService>((ref) {
      return ProductionRuntimeShutdownService(
        stopBackground: ref
            .watch(backgroundSyncCoordinatorProvider)
            .stopForAccountCleanup,
        stopSync: ref.watch(syncServiceProvider).stopSyncLoop,
        resetSyncInitializer: ref
            .watch(syncInitializerProvider)
            .resetForAccountCleanup,
        stopUploader: ref.watch(fileUploaderProvider).stopForAccountCleanup,
        disposeTelegram: ref.watch(telegramServiceProvider).dispose,
      );
    });

class ProductionRuntimeShutdownService {
  final Future<void> Function() _stopBackground;
  final void Function() _stopSync;
  final void Function() _resetSyncInitializer;
  final Future<void> Function() _stopUploader;
  final Future<void> Function() _disposeTelegram;
  bool _running = false;

  ProductionRuntimeShutdownService({
    required Future<void> Function() stopBackground,
    required void Function() stopSync,
    required void Function() resetSyncInitializer,
    required Future<void> Function() stopUploader,
    required Future<void> Function() disposeTelegram,
  }) : _stopBackground = stopBackground,
       _stopSync = stopSync,
       _resetSyncInitializer = resetSyncInitializer,
       _stopUploader = stopUploader,
       _disposeTelegram = disposeTelegram;

  Future<void> shutdownForReviewerDemo() async {
    if (_running) return;
    _running = true;
    try {
      await _stopBackground();
      _stopSync();
      _resetSyncInitializer();
      await _stopUploader();
      await _disposeTelegram();
    } finally {
      _running = false;
    }
  }
}
