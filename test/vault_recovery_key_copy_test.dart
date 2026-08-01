import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Recovery Key instructions give clear, ordered actions', () {
    final source = File(
      'lib/src/features/vault/presentation/vault_recovery_key_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Save a private copy'));
    expect(source, contains('Tap Copy recovery key'));
    expect(source, contains('Do not share it'));
    expect(source, contains('Check the saved copy'));
    expect(source, contains('Enter the last 8 characters'));
    expect(source, contains('Keep it available'));
    expect(source, contains('cannot create a replacement key'));
  });
}
