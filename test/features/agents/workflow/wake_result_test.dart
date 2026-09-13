import 'dart:io';

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

  group('WakeResult.failed', () {
    test("keeps a StateError message — the workflows' own abort signal", () {
      final result = WakeResult.failed(
        kind: 'Project agent',
        error: StateError('No active project ID'),
      );

      expect(result.success, isFalse);
      expect(
        result.error,
        'Project agent workflow failed: No active project ID',
      );
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
