import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';

void main() {
  group('formatWakeCountdown', () {
    test('returns 0s when due in the past', () {
      final now = DateTime(2026, 3, 31, 9);
      final due = now.subtract(const Duration(seconds: 5));
      expect(formatWakeCountdown(due, now), '0s');
    });

    test('returns 0s when due exactly now', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(formatWakeCountdown(now, now), '0s');
    });

    test('formats sub-minute countdowns as Ns', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(now.add(const Duration(seconds: 12)), now),
        '12s',
      );
    });

    test('formats sub-hour countdowns as Nm Ns', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(minutes: 2, seconds: 5)),
          now,
        ),
        '2m 5s',
      );
    });

    test('formats hour countdowns as Nh Nm Ns', () {
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(hours: 1, minutes: 30, seconds: 7)),
          now,
        ),
        '1h 30m 7s',
      );
    });

    test('keeps the minute slot when hours present and minutes are zero', () {
      // Without this guard "1h 0s" would be ambiguous; the formatter
      // emits the `0m` so the cell stays h-m-s aligned.
      final now = DateTime(2026, 3, 31, 9);
      expect(
        formatWakeCountdown(
          now.add(const Duration(hours: 1, seconds: 9)),
          now,
        ),
        '1h 0m 9s',
      );
    });
  });
}
