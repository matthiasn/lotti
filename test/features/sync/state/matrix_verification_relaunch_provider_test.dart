import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  MatrixVerificationHandled handled() =>
      container.read(matrixVerificationHandledProvider.notifier);

  test('request releases only the device shown last, then bumps', () {
    handled()
      ..markShown('@a:x/OLD')
      ..markShown('@a:x/NEW');
    final events = <int>[];
    container.listen<int>(
      matrixVerificationRelaunchProvider,
      (_, next) => events.add(next),
    );

    container.read(matrixVerificationRelaunchProvider.notifier).request();

    expect(container.read(matrixVerificationHandledProvider), {'@a:x/OLD'});
    expect(handled().lastShown, '@a:x/NEW');
    expect(events, [1]);
  });

  test('every listener sees the release already done', () {
    // Two launchers listen; the first re-records the device on launch. A
    // release per listener would undo that record in the second listener.
    handled().markShown('@a:x/DEV');
    final seen = <bool>[];
    for (var i = 0; i < 2; i++) {
      container.listen<int>(matrixVerificationRelaunchProvider, (_, _) {
        seen.add(handled().contains('@a:x/DEV'));
        if (seen.length == 1) handled().markShown('@a:x/DEV');
      });
    }

    container.read(matrixVerificationRelaunchProvider.notifier).request();

    expect(seen, [false, true]);
    expect(handled().contains('@a:x/DEV'), isTrue);
  });

  test('request with nothing shown yet only bumps', () {
    container.read(matrixVerificationRelaunchProvider.notifier).request();

    expect(container.read(matrixVerificationRelaunchProvider), 1);
    expect(container.read(matrixVerificationHandledProvider), isEmpty);
  });
}
