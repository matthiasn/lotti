import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_detail_record_provider.dart';

void main() {
  group('formatDurationForDetail', () {
    test('formats hours and minutes', () {
      expect(
        formatDurationForDetail(const Duration(hours: 2, minutes: 30)),
        '2h 30m',
      );
    });

    test('formats single hour with zero minutes', () {
      expect(
        formatDurationForDetail(const Duration(hours: 1)),
        '1h 0m',
      );
    });

    test('formats minutes and seconds', () {
      expect(
        formatDurationForDetail(const Duration(minutes: 11, seconds: 38)),
        '11m 38s',
      );
    });

    test('formats seconds only for sub-minute durations', () {
      expect(
        formatDurationForDetail(const Duration(seconds: 45)),
        '45s',
      );
    });

    test('formats zero duration', () {
      expect(
        formatDurationForDetail(Duration.zero),
        '0s',
      );
    });

    test('formats large duration', () {
      expect(
        formatDurationForDetail(const Duration(hours: 100, minutes: 5)),
        '100h 5m',
      );
    });
  });

  group('formatDateForDetail', () {
    test('formats date with leading-zero hours and minutes', () {
      expect(
        formatDateForDetail(DateTime(2026, 4, 1, 9, 5)),
        '1 Apr 26, 09:05',
      );
    });

    test('formats date in December', () {
      expect(
        formatDateForDetail(DateTime(2024, 12, 25, 14, 30)),
        '25 Dec 24, 14:30',
      );
    });

    test('formats date in January', () {
      expect(
        formatDateForDetail(DateTime(2025, 1, 3, 0, 0)),
        '3 Jan 25, 00:00',
      );
    });

    test('formats midnight correctly', () {
      expect(
        formatDateForDetail(DateTime(2026, 6, 15, 23, 59)),
        '15 Jun 26, 23:59',
      );
    });
  });

  group('taskDetailRecordProvider', () {
    test('provider family is parameterized by task ID', () {
      final providerA = taskDetailRecordProvider('task-a');
      final providerB = taskDetailRecordProvider('task-b');

      // Different task IDs produce different provider instances
      expect(providerA, isNot(equals(providerB)));
    });

    test('same task ID returns same provider instance', () {
      final providerA = taskDetailRecordProvider('task-same');
      final providerB = taskDetailRecordProvider('task-same');

      expect(providerA, equals(providerB));
    });
  });
}
