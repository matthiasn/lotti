import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/logging_service.dart';

void main() {
  // LoggingService disables logging in test environments, so we use the real
  // instance and verify the function completes without errors. The function's
  // purpose is purely side-effectful (logging), so exercising its code paths
  // is the main value.
  late LoggingService loggingService;

  setUp(() {
    loggingService = LoggingService();
  });

  group('vectorClockLogDomain', () {
    test('has expected value', () {
      expect(vectorClockLogDomain, 'VECTOR_CLOCK');
    });
  });

  group('logVectorClockAssignment', () {
    test('logs action with minimal parameters without error', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'ASSIGN',
      );
    });

    test('logs action with all parameters without error', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'apply',
        action: 'ASSIGN',
        type: 'JournalEntry',
        entryId: 'entry-123',
        jsonPath: '/tmp/entry.json',
        reason: 'sync',
        previous: const VectorClock({'node1': 1}),
        assigned: const VectorClock({'node1': 2}),
        coveredVectorClocks: [
          const VectorClock({'node1': 1}),
        ],
        extras: {'extra_key': 'extra_value'},
      );
    });

    test('handles null extras without error', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'ASSIGN',
        extras: {'present': 'yes', 'absent': null},
      );
    });

    test('handles empty extras map without error', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'CHECK',
      );
    });
  });
}
