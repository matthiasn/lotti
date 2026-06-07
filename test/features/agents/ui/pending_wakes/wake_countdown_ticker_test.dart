import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';

void main() {
  group('formatWakeCountdown', () {
    test('returns 00:00 when due in the past', () {
      final now = DateTime(2026, 3, 31, 9);
      final due = now.subtract(const Duration(seconds: 5));
      expect(formatWakeCountdown(due, now), '00:00');
    });

    test('returns 00:00 when due exactly now', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(formatWakeCountdown(now, now), '00:00');
    });

    test('drops the hour cell below 60 minutes', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(now.add(const Duration(seconds: 12)), now),
        '00:12',
      );
    });

    test('zero-pads sub-hour countdowns as MM:SS', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(minutes: 2, seconds: 5)),
          now,
        ),
        '02:05',
      );
    });

    test('adds the hour cell once over 60 minutes', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(hours: 1, minutes: 30, seconds: 7)),
          now,
        ),
        '01:30:07',
      );
    });

    test('keeps the minute slot zero-padded when hours present', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(hours: 1, seconds: 9)),
          now,
        ),
        '01:00:09',
      );
    });

    test('clamps to 99:59:59 when over 100 hours away', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(now.add(const Duration(hours: 200)), now),
        '99:59:59',
      );
    });

    // Property: the structural invariants of the formatter hold across the
    // full range from "already overdue" through "beyond the 100h clamp".
    // Seconds range spans negatives (past), zero, the sub-hour band, the
    // hour boundary, and past the 359999s clamp.
    glados.Glados(
      glados.any.intInRange(-3600, 400000),
      glados.ExploreConfig(numRuns: 160),
    ).test('formats any offset with stable structural invariants', (
      offsetSeconds,
    ) {
      final now = DateTime(2026, 3, 31, 9);
      final due = now.add(Duration(seconds: offsetSeconds));
      final result = formatWakeCountdown(due, now);

      // Overdue / due-now collapses to 00:00 iff the offset is non-positive.
      if (offsetSeconds <= 0) {
        expect(result, '00:00', reason: 'offset=$offsetSeconds');
        return;
      }

      // Never wider than HH:MM:SS — the hour cell is clamped to two digits.
      expect(
        result.length,
        lessThanOrEqualTo(8),
        reason: 'offset=$offsetSeconds',
      );

      // The hour cell appears iff the remaining time reaches one hour
      // (the clamp only lowers values, so anything >= 3600 stays >= 3600).
      final hasHourCell = result.length == 8;
      expect(
        hasHourCell,
        offsetSeconds >= 3600,
        reason: 'offset=$offsetSeconds result=$result',
      );

      // Shape is MM:SS (5 chars) below the hour or HH:MM:SS (8 chars) at or
      // above it — no other lengths, and every cell is two zero-padded digits.
      final pattern = hasHourCell
          ? RegExp(r'^\d{2}:\d{2}:\d{2}$')
          : RegExp(r'^\d{2}:\d{2}$');
      expect(
        pattern.hasMatch(result),
        isTrue,
        reason: 'offset=$offsetSeconds result=$result',
      );
    }, tags: 'glados');
  });
}
