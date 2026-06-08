import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

void main() {
  late MockDomainLogger loggingService;

  setUp(() {
    loggingService = MockDomainLogger();
  });

  group('vectorClockLogDomain', () {
    test('has expected value', () {
      expect(vectorClockLogDomain, 'VECTOR_CLOCK');
    });
  });

  group('logVectorClockAssignment', () {
    test('logs action with minimal parameters', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'ASSIGN',
      );

      // The contract: exactly one structured log line on the sync domain,
      // carrying the action plus the always-present clock fields.
      final message =
          verify(
                () => loggingService.log(
                  LogDomain.sync,
                  captureAny(),
                  subDomain: 'test',
                ),
              ).captured.single
              as String;
      expect(message, 'ASSIGN previous=null assigned=null');
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

      final message =
          verify(
                () => loggingService.log(
                  LogDomain.sync,
                  captureAny(),
                  subDomain: 'apply',
                ),
              ).captured.single
              as String;
      expect(message, contains('ASSIGN'));
      expect(message, contains('type=JournalEntry'));
      expect(message, contains('entryId=entry-123'));
      expect(message, contains('previous={node1: 1}'));
      expect(message, contains('assigned={node1: 2}'));
      expect(message, contains('covered=[{node1: 1}]'));
      expect(message, contains('extra_key=extra_value'));
    });

    test('null-valued extras are filtered out of the log line', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'ASSIGN',
        extras: {'present': 'yes', 'absent': null},
      );

      final message =
          verify(
                () => loggingService.log(
                  LogDomain.sync,
                  captureAny(),
                  subDomain: 'test',
                ),
              ).captured.single
              as String;
      // Non-null extras are appended; null-valued extras are omitted entirely.
      expect(message, contains('present=yes'));
      expect(message, isNot(contains('absent')));
    });

    test('empty extras map logs only action plus clock fields', () {
      logVectorClockAssignment(
        loggingService,
        subDomain: 'test',
        action: 'CHECK',
      );

      final message =
          verify(
                () => loggingService.log(
                  LogDomain.sync,
                  captureAny(),
                  subDomain: 'test',
                ),
              ).captured.single
              as String;
      expect(message, 'CHECK previous=null assigned=null');
    });
  });
}
