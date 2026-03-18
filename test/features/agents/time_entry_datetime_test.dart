import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';

void main() {
  group('parseTimeEntryLocalDateTime', () {
    test('parses a valid local ISO 8601 datetime', () {
      final result = parseTimeEntryLocalDateTime('2026-03-17T14:00:00');
      expect(result, equals(DateTime(2026, 3, 17, 14)));
    });

    test('parses datetime with seconds', () {
      final result = parseTimeEntryLocalDateTime('2026-03-17T09:05:30');
      expect(result, equals(DateTime(2026, 3, 17, 9, 5, 30)));
    });

    test('returns null for date-only string', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17'), isNull);
    });

    test('returns null for UTC string with Z suffix', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00Z'), isNull);
    });

    test('returns null for UTC string with lowercase z suffix', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00z'), isNull);
    });

    test('returns null for string with positive timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00+01:00'), isNull);
    });

    test('returns null for string with negative timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00-05:00'), isNull);
    });

    test('returns null for string with compact timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00+0100'), isNull);
    });

    test('returns null for completely invalid string', () {
      expect(parseTimeEntryLocalDateTime('not-a-date'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseTimeEntryLocalDateTime(''), isNull);
    });
  });

  group('formatTimeEntryHhMm', () {
    test('formats midnight as 00:00', () {
      expect(formatTimeEntryHhMm(DateTime(2026, 3, 17)), equals('00:00'));
    });

    test('pads single-digit hour and minute', () {
      expect(formatTimeEntryHhMm(DateTime(2026, 3, 17, 9, 5)), equals('09:05'));
    });

    test('formats noon correctly', () {
      expect(
        formatTimeEntryHhMm(DateTime(2026, 3, 17, 12)),
        equals('12:00'),
      );
    });

    test('formats end of day', () {
      expect(
        formatTimeEntryHhMm(DateTime(2026, 3, 17, 23, 59)),
        equals('23:59'),
      );
    });
  });
}
