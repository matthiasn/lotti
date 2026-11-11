import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';

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

  group('WakeResult.failed', () {
    test('reports a StateError by type only — its message may interpolate '
        'model-emitted tool names', () {
      final result = WakeResult.failed(
        kind: 'Task agent',
        error: StateError('tool "<whatever the model sent>" not allowed'),
      );

      expect(result.success, isFalse);
      expect(result.error, 'Task agent workflow failed (StateError)');
    });

    test('reports any other exception by type only', () {
      // A provider or filesystem exception carries response bodies and
      // paths; the reason reaches the PII-safe error log, so only the type
      // may travel.
      final result = WakeResult.failed(
        kind: 'Task agent',
        error: const FileSystemException('read failed', '/home/me/secret.txt'),
      );

      expect(result.error, 'Task agent workflow failed (FileSystemException)');
      expect(result.error, isNot(contains('secret')));
    });

    test('keeps the caught exception in memory for the waiting surface', () {
      final error = Exception('Insufficient credits');
      final result = WakeResult.failed(kind: 'Goal Phase B', error: error);

      expect(result.cause, same(error));
      expect(result.error, isNot(contains('Insufficient')));
    });
  });

  group('wakeFailureCause', () {
    test("reads the cause off a failed wake's exception, never its text", () {
      final cause = Exception('Insufficient credits');
      final exception = WakeFailedException(
        kind: 'goal',
        reason: 'Goal Phase B workflow failed (_Exception)',
        cause: cause,
      );

      expect(wakeFailureCause(exception), same(cause));
      // The PII-safe error log records toString: the cause stays out of it.
      expect(exception.toString(), isNot(contains('Insufficient')));
    });

    test('is null for anything but a failed wake', () {
      expect(wakeFailureCause(null), isNull);
      expect(wakeFailureCause(TimeoutException('timeout')), isNull);
      expect(
        wakeFailureCause(
          const WakeFailedException(kind: 'task', reason: 'wake failed'),
        ),
        isNull,
      );
    });
  });

  group('WakeFailedException', () {
    test('names the kind and the workflow reason', () {
      const exception = WakeFailedException(
        kind: 'task',
        reason: 'No template assigned to agent',
      );

      expect(exception.kind, 'task');
      expect(exception.reason, 'No template assigned to agent');
      expect(
        exception.toString(),
        'WakeFailedException(task): No template assigned to agent',
      );
    });
  });
}
