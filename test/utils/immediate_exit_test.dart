import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/immediate_exit.dart';

void main() {
  group('immediateExit', () {
    test('POSIX _exit symbol can be resolved via FFI', () {
      // Verify the FFI lookup succeeds without actually calling _exit.
      expect(canResolveImmediateExit(), isTrue);
    });
  });
}
