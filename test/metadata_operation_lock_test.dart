import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/backup/services/metadata_operation_lock.dart';

void main() {
  test(
    'concurrent automatic and manual snapshot operations serialize',
    () async {
      final directory = await io.Directory.systemTemp.createTemp(
        'televault_metadata_operation_lock_',
      );
      addTearDown(() => directory.delete(recursive: true));
      Future<io.File> lockFile() async =>
          io.File('${directory.path}/metadata.lock');
      final automatic = MetadataOperationLock(lockFileProvider: lockFile);
      final manual = MetadataOperationLock(lockFileProvider: lockFile);
      var active = 0;
      var maximumActive = 0;
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();

      final first = automatic.synchronized(() async {
        active++;
        maximumActive = active;
        firstStarted.complete();
        await releaseFirst.future;
        active--;
      });
      await firstStarted.future;
      final second = manual.synchronized(() async {
        active++;
        if (active > maximumActive) maximumActive = active;
        active--;
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(maximumActive, 1);
      releaseFirst.complete();
      await Future.wait([first, second]);
      expect(maximumActive, 1);
    },
  );

  test(
    'nested Safe Uninstall operation is reentrant on the same lock',
    () async {
      final directory = await io.Directory.systemTemp.createTemp(
        'televault_metadata_reentrant_lock_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final lock = MetadataOperationLock(
        lockFileProvider: () async =>
            io.File('${directory.path}/metadata.lock'),
      );
      var completed = false;
      await lock.synchronized(() async {
        await lock.synchronized(() async => completed = true);
      });
      expect(completed, isTrue);
    },
  );
}
