import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';

void main() {
  group('MatrixVerificationModalLock', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state is false (unlocked)', () {
      final state = container.read(matrixVerificationModalLockProvider);

      expect(state, isFalse);
    });

    test('tryAcquire returns true on first call', () {
      final notifier = container.read(
        matrixVerificationModalLockProvider.notifier,
      );

      expect(notifier.tryAcquire(), isTrue);
      expect(
        container.read(matrixVerificationModalLockProvider),
        isTrue,
      );
    });

    test('tryAcquire returns false when already locked', () {
      final notifier = container.read(
        matrixVerificationModalLockProvider.notifier,
      )..tryAcquire();

      expect(notifier.tryAcquire(), isFalse);
    });

    test('release unlocks the state', () {
      final notifier = container.read(
        matrixVerificationModalLockProvider.notifier,
      )..tryAcquire();

      expect(
        container.read(matrixVerificationModalLockProvider),
        isTrue,
      );

      notifier.release();
      expect(
        container.read(matrixVerificationModalLockProvider),
        isFalse,
      );
    });

    test('tryAcquire succeeds after release', () {
      final notifier =
          container.read(
              matrixVerificationModalLockProvider.notifier,
            )
            ..tryAcquire()
            ..release();

      expect(notifier.tryAcquire(), isTrue);
    });
  });
}
