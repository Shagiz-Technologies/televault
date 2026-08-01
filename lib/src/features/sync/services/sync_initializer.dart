import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../buckets/services/bucket_service.dart';
import 'file_uploader.dart';
import 'sync_service.dart';

final syncInitializerProvider = Provider<SyncInitializer>((ref) {
  return SyncInitializer(ref);
});

class SyncInitializer {
  final Ref _ref;
  bool _started = false;
  Future<void>? _starting;

  SyncInitializer(this._ref);

  Future<void> ensureStarted() {
    if (_started) {
      _ref.read(fileUploaderProvider).wake();
      return Future.value();
    }

    final inFlight = _starting;
    if (inFlight != null) return inFlight;

    final future = _startIfBucketsExist();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) {
        _starting = null;
      }
    });
  }

  void resetForAccountCleanup() {
    _started = false;
    _starting = null;
  }

  Future<void> _startIfBucketsExist() async {
    final bucketService = _ref.read(bucketServiceProvider);
    if (!await bucketService.hasBuckets()) return;

    _started = true;
    final syncService = _ref.read(syncServiceProvider);
    final uploader = _ref.read(fileUploaderProvider);

    syncService.startSyncLoop();
    await uploader.startUploadLoop();
  }
}
