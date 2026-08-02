import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TDLib logging is disabled before every client is created', () {
    final source = File(
      'lib/src/core/services/telegram_service.dart',
    ).readAsStringSync();
    const configureCall = '_configureNativeLogging();';
    const createCall = '_tdJson.td_create_client_id();';

    expect(
      source,
      contains("'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 0"),
    );
    expect(source, contains("'use_test_dc': false"));
    expect(source, isNot(contains("'use_test_dc': true")));
    expect(source.indexOf(configureCall), lessThan(source.indexOf(createCall)));
    expect(
      configureCall.allMatches(source).length,
      greaterThanOrEqualTo(createCall.allMatches(source).length),
    );
  });
}
