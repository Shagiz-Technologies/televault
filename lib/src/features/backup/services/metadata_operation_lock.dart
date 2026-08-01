import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef MetadataLockFileProvider = Future<File> Function();

final metadataOperationLockProvider = Provider<MetadataOperationLock>((ref) {
  return MetadataOperationLock();
});

/// Serializes metadata operations across service instances and app isolates.
///
/// The operating system releases the file lock if the process terminates, so a
/// crash cannot leave a permanently stale in-memory "busy" flag behind.
class MetadataOperationLock {
  static final Object _zoneKey = Object();
  static final Map<String, Future<void>> _inProcessTails = {};

  final MetadataLockFileProvider _lockFileProvider;

  MetadataOperationLock({MetadataLockFileProvider? lockFileProvider})
    : _lockFileProvider = lockFileProvider ?? _defaultLockFile;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final lockFile = await _lockFileProvider();
    final lockPath = path.normalize(path.absolute(lockFile.path));
    final heldPaths = Zone.current[_zoneKey] as Set<String>?;
    if (heldPaths?.contains(lockPath) ?? false) return operation();

    final previous = _inProcessTails[lockPath] ?? Future<void>.value();
    final releaseProcessLock = Completer<void>();
    final tail = previous
        .catchError((Object _) {})
        .then((_) => releaseProcessLock.future);
    _inProcessTails[lockPath] = tail;
    await previous.catchError((Object _) {});

    await lockFile.parent.create(recursive: true);
    final handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await runZoned(
        operation,
        zoneValues: <Object, Object>{
          _zoneKey: <String>{...?heldPaths, lockPath},
        },
      );
    } finally {
      try {
        await handle.unlock();
      } finally {
        await handle.close();
        releaseProcessLock.complete();
        if (identical(_inProcessTails[lockPath], tail)) {
          unawaited(
            tail.whenComplete(() {
              if (identical(_inProcessTails[lockPath], tail)) {
                _inProcessTails.remove(lockPath);
              }
            }),
          );
        }
      }
    }
  }

  static Future<File> _defaultLockFile() async {
    final support = await getApplicationSupportDirectory();
    return File(path.join(support.path, 'metadata', 'metadata-operation.lock'));
  }
}
