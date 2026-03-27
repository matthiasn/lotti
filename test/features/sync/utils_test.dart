import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/utils.dart';

void main() {
  group('sync utils constants', () {
    test('hostKey has expected value', () {
      expect(hostKey, 'VC_HOST');
    });

    test('nextAvailableCounterKey has expected value', () {
      expect(nextAvailableCounterKey, 'VC_NEXT_AVAILABLE_COUNTER');
    });
  });
}
