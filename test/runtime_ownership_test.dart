import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/services/runtime_ownership.dart';

void main() {
  test('only one owner can hold a runtime queue or TDLib storage lease', () {
    final first = RuntimeOwnershipLease('test.queue');
    final second = RuntimeOwnershipLease('test.queue');

    expect(first.tryAcquire(), isTrue);
    expect(first.tryAcquire(), isTrue);
    expect(second.tryAcquire(), isFalse);

    first.release();
    expect(second.tryAcquire(), isTrue);
    second.release();
  });
}
