import 'package:flutter_test/flutter_test.dart';
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
  });
}
