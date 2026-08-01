import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent Android sync uses unique constrained WorkManager jobs', () {
    final source = File(
      'android/app/src/main/kotlin/et/shagiz/tele_vault/'
      'TeleVaultSyncWorker.kt',
    ).readAsStringSync();

    expect(source, contains('PeriodicWorkRequestBuilder<TeleVaultSyncWorker>'));
    expect(source, contains('NetworkType.UNMETERED'));
    expect(source, contains('NetworkType.CONNECTED'));
    expect(source, contains('enqueueUniquePeriodicWork'));
    expect(source, contains('enqueueUniqueWork'));
    expect(source, contains('ExistingPeriodicWorkPolicy.UPDATE'));
    expect(source, contains('ExistingWorkPolicy.KEEP'));
    expect(source, contains('Result.retry()'));
  });
}
