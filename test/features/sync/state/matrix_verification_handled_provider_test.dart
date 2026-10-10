import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  MatrixVerificationHandled notifier() =>
      container.read(matrixVerificationHandledProvider.notifier);
  Set<String> handled() => container.read(matrixVerificationHandledProvider);

  test('identityOf keys a device by user and device id', () {
    expect(
      MatrixVerificationHandled.identityOf(userId: '@a:x', deviceId: 'DEV'),
      '@a:x/DEV',
    );
    // Own-account roster rows omit the user; they must not collide with a
    // foreign user's device of the same id.
    expect(
      MatrixVerificationHandled.identityOf(userId: null, deviceId: 'DEV'),
      'self/DEV',
    );
  });

  test('markShown records the identity and remembers it as the last shown', () {
    notifier()
      ..markShown('@a:x/STALE')
      ..markShown('@a:x/NEW');

    expect(handled(), {'@a:x/STALE', '@a:x/NEW'});
    expect(notifier().contains('@a:x/NEW'), isTrue);
    expect(notifier().lastShown, '@a:x/NEW');
  });

  test('release frees one identity and keeps the last shown', () {
    notifier()
      ..markShown('@a:x/STALE')
      ..markShown('@a:x/NEW')
      ..release('@a:x/NEW');

    // What a relaunch needs: the device to reopen is eligible again *and*
    // still known as the one to prefer over the stale peer at the head.
    expect(handled(), {'@a:x/STALE'});
    expect(notifier().lastShown, '@a:x/NEW');
  });

  test('clear forgets everything, including the last shown', () {
    notifier()
      ..markShown('@a:x/NEW')
      ..clear();

    expect(handled(), isEmpty);
    expect(notifier().lastShown, isNull);
  });

  test('clear on an empty set does not notify', () {
    var notifications = 0;
    container.listen(
      matrixVerificationHandledProvider,
      (_, _) => notifications++,
    );

    notifier().clear();

    expect(notifications, 0);
  });
}
