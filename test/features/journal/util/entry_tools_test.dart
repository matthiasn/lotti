import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/util/entry_tools.dart';

/// Glados generators for entry-tools property tests.
extension _AnyDuration on glados.Any {
  /// Generates non-negative durations up to 99 hours 59 minutes 59 seconds,
  /// which keeps the formatted string predictably 8 or 9 characters wide.
  glados.Generator<Duration> get boundedDuration =>
      glados.any.intInRange(0, 359999).map((s) => Duration(seconds: s));
}

void main() {
  // ---------------------------------------------------------------------------
  // formatDuration — worked examples
  // ---------------------------------------------------------------------------

  group('formatDuration — worked examples', () {
    test('returns empty string for null', () {
      expect(formatDuration(null), '');
    });

    test('formats zero duration as 00:00:00 (zero-padded)', () {
      expect(formatDuration(Duration.zero), '00:00:00');
    });

    test('pads single-digit hours with leading zero (e.g. 1h → 01:…)', () {
      // 1 hour, 5 minutes, 3 seconds
      const d = Duration(hours: 1, minutes: 5, seconds: 3);
      final result = formatDuration(d);
      expect(result, '01:05:03');
      expect(result.length, 8);
    });

    test('does not pad double-digit hours (e.g. 10h → 10:…)', () {
      const d = Duration(hours: 10);
      final result = formatDuration(d);
      expect(result, '10:00:00');
      expect(result.length, 8);
    });

    test('formats sub-1-hour duration with leading zero (e.g. 0h30m45s)', () {
      const d = Duration(minutes: 30, seconds: 45);
      // '0:30:45'.substring(1,2) == ':' → padded to '00:30:45'
      expect(formatDuration(d), '00:30:45');
    });

    test('formats 9h 59m 59s correctly', () {
      const d = Duration(hours: 9, minutes: 59, seconds: 59);
      expect(formatDuration(d), '09:59:59');
    });

    test('does not truncate sub-second precision (only integer seconds shown)',
        () {
      const d = Duration(hours: 2, milliseconds: 500);
      // Duration.toString strips sub-second: "2:00:00.500000" → first split
      // on '.' → "2:00:00", then padded to "02:00:00".
      expect(formatDuration(d), '02:00:00');
    });
  });

  // ---------------------------------------------------------------------------
  // formatDuration — Glados property tests
  // ---------------------------------------------------------------------------

  group('formatDuration — properties', () {
    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test('output is never empty for a non-null Duration', (d) {
      expect(formatDuration(d), isNotEmpty);
    }, tags: 'glados');

    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test('output always matches HH:MM:SS or H:MM:SS pattern', (d) {
      final result = formatDuration(d);
      // Must match either "H:MM:SS" (7 chars) or "HH:MM:SS" (8 chars) etc.
      // The important invariant is that it ends with :XX:XX (seconds and
      // minutes each have exactly 2 digits after the first colon boundary).
      final parts = result.split(':');
      expect(parts, hasLength(3), reason: 'result=$result');
      expect(parts[1].length, 2, reason: 'minutes field must be 2 digits');
      expect(parts[2].length, 2, reason: 'seconds field must be 2 digits');
    }, tags: 'glados');

    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test(
        'durations below 10 hours are padded to start with a two-character '
        'hour field', (d) {
      if (d.inHours >= 10) return; // only test the padding branch
      final result = formatDuration(d);
      // The hour part is always at least 2 characters (zero-padded by the
      // padding branch).
      final hourPart = result.split(':').first;
      expect(hourPart.length, greaterThanOrEqualTo(2));
    }, tags: 'glados');
  });

  // ---------------------------------------------------------------------------
  // fromNullableBool
  // ---------------------------------------------------------------------------

  group('fromNullableBool', () {
    test('returns false for null', () {
      expect(fromNullableBool(null), isFalse);
    });

    test('returns true for true', () {
      expect(fromNullableBool(true), isTrue);
    });

    test('returns false for false', () {
      expect(fromNullableBool(false), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // formatType / formatUnit
  // ---------------------------------------------------------------------------

  group('formatType', () {
    test('strips HealthDataType. prefix', () {
      expect(formatType('HealthDataType.STEPS'), 'STEPS');
    });

    test('leaves string without prefix unchanged', () {
      expect(formatType('HEART_RATE'), 'HEART_RATE');
    });

    test('uses replaceAll: removes all occurrences of the prefix', () {
      // The function uses replaceAll, so both prefixes are stripped.
      expect(
        formatType('HealthDataType.HealthDataType.SLEEP'),
        'SLEEP',
      );
    });
  });

  group('formatUnit', () {
    test('strips HealthDataUnit. prefix', () {
      expect(formatUnit('HealthDataUnit.COUNT'), 'COUNT');
    });

    test('leaves string without prefix unchanged', () {
      expect(formatUnit('KILOCALORIE'), 'KILOCALORIE');
    });
  });
}
