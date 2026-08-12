import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('WakeResult', () {
    test('success with mutated entries', () {
      const result = WakeResult(
        success: true,
        mutatedEntries: {
          'entity-1': VectorClock({'host-a': 1}),
        },
      );

      expect(result.success, isTrue);
      expect(result.mutatedEntries, {
        'entity-1': const VectorClock({'host-a': 1}),
      });
      expect(result.reportUpdated, isFalse);
      expect(result.error, isNull);
    });

    test('failure with error message', () {
      const result = WakeResult(success: false, error: 'Something went wrong');

      expect(result.success, isFalse);
      expect(result.mutatedEntries, isEmpty);
      expect(result.error, 'Something went wrong');
    });

    test('defaults mutatedEntries to empty map', () {
      const result = WakeResult(success: true, reportUpdated: true);

      expect(result.mutatedEntries, isEmpty);
      expect(result.reportUpdated, isTrue);
      expect(result.error, isNull);
    });
  });
}
