import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/immediate_exit.dart';

void main() {
  group('immediateExit', () {
    test('POSIX _exit symbol can be resolved via FFI', () {
      // Verify the FFI lookup succeeds without actually calling _exit.
      expect(canResolveImmediateExit(), isTrue);
    });

    test('canResolveImmediateExit returns consistent results', () {
      // The lazy field is already resolved after the first call,
      // so subsequent calls should also return true.
      final first = canResolveImmediateExit();
      final second = canResolveImmediateExit();
      expect(first, second);
    });

    test('immediateExit is a callable function', () {
      // Verify the function exists and has the correct type signature.
      // We cannot actually call it as it would terminate the process.
      expect(immediateExit, isA<Function>());
    });
  });
}
