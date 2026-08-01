import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainActivity preserves the application-owned Flutter engine', () {
    final source = File(
      'android/app/src/main/kotlin/et/shagiz/tele_vault/MainActivity.kt',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'override fun getCachedEngineId(): String = '
        'TeleVaultApplication.ENGINE_ID',
      ),
    );
    expect(
      source,
      contains('override fun shouldDestroyEngineWithHost(): Boolean = false'),
    );
    expect(source, isNot(contains('provideFlutterEngine')));
  });
}
