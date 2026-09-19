import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/system_health/domain/system_health_range.dart';

void main() {
  final now = DateTime(2026, 9, 12, 14, 30);

  group('SystemHealthRange.forPreset', () {
    test('subtracts the preset window from now', () {
      final range = SystemHealthRange.forPreset(
        SystemHealthPreset.last7Days,
        now: now,
      );
      expect(range.start, DateTime(2026, 9, 5, 14, 30));
      expect(range.end, now);
      expect(range.preset, SystemHealthPreset.last7Days);
    });

    test('rejects the custom preset', () {
      expect(
        () => SystemHealthRange.forPreset(SystemHealthPreset.custom, now: now),
        throwsArgumentError,
      );
    });

    test('presets carry their windows', () {
      expect(SystemHealthPreset.last24Hours.window, const Duration(hours: 24));
      expect(SystemHealthPreset.last14Days.window, const Duration(days: 14));
      expect(SystemHealthPreset.custom.window, isNull);
    });
  });

  group('SystemHealthRange.days', () {
    test('covers whole days from midnight to the last microsecond', () {
      final range = SystemHealthRange.days(
        firstDay: DateTime(2026, 9, 10, 9),
        lastDay: DateTime(2026, 9, 12, 18),
      );
      expect(range.start, DateTime(2026, 9, 10));
      expect(range.end, DateTime(2026, 9, 12, 23, 59, 59, 999, 999));
      expect(range.preset, SystemHealthPreset.custom);
    });

    test('swaps reversed bounds instead of throwing', () {
      final range = SystemHealthRange.days(
        firstDay: DateTime(2026, 9, 12),
        lastDay: DateTime(2026, 9, 10),
      );
      expect(range.start, DateTime(2026, 9, 10));
      expect(range.end.day, 12);
    });
  });

  group('days', () {
    test('lists every calendar day the window touches, oldest first', () {
      final range = SystemHealthRange(
        preset: SystemHealthPreset.custom,
        start: DateTime(2026, 9, 10, 23, 50),
        end: DateTime(2026, 9, 12, 0, 10),
      );
      expect(range.days, [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 12),
      ]);
    });

    test('a window inside one day lists that day only', () {
      final range = SystemHealthRange.forPreset(
        SystemHealthPreset.last24Hours,
        now: DateTime(2026, 9, 12, 23, 59),
      );
      expect(range.days, [DateTime(2026, 9, 11), DateTime(2026, 9, 12)]);
    });
  });

  group('contains', () {
    final range = SystemHealthRange(
      preset: SystemHealthPreset.custom,
      start: DateTime(2026, 9, 10, 12),
      end: DateTime(2026, 9, 11, 12),
    );

    test('is inclusive at both ends', () {
      expect(range.contains(DateTime(2026, 9, 10, 12)), isTrue);
      expect(range.contains(DateTime(2026, 9, 11, 12)), isTrue);
    });

    test('excludes instants outside', () {
      expect(range.contains(DateTime(2026, 9, 10, 11, 59)), isFalse);
      expect(range.contains(DateTime(2026, 9, 11, 12, 0, 1)), isFalse);
    });
  });

  group('calendar arithmetic', () {
    test('nextCalendarDay rolls over months and years', () {
      expect(
        SystemHealthRange.nextCalendarDay(DateTime(2026, 9, 30, 13)),
        DateTime(2026, 10),
      );
      expect(
        SystemHealthRange.nextCalendarDay(DateTime(2026, 12, 31)),
        DateTime(2027),
      );
    });

    test('calendarDaysBefore counts whole days back across a month', () {
      expect(
        SystemHealthRange.calendarDaysBefore(DateTime(2026, 9, 3, 8), 6),
        DateTime(2026, 8, 28),
      );
    });

    test('days is built from calendar days, never a fixed 24 h step', () {
      final range = SystemHealthRange.days(
        firstDay: DateTime(2026, 10, 24),
        lastDay: DateTime(2026, 10, 26),
      );
      expect(range.days, [
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
      ]);
      expect(range.end, DateTime(2026, 10, 26, 23, 59, 59, 999, 999));
    });
  });

  test('constructor rejects a start after the end', () {
    expect(
      () => SystemHealthRange(
        preset: SystemHealthPreset.custom,
        start: DateTime(2026, 9, 12),
        end: DateTime(2026, 9, 11),
      ),
      throwsAssertionError,
    );
  });

  group('properties', () {
    // Instants across 2026, biased to the EU and US DST switch weeks.
    final day = glados.any.oneOf([
      glados.any
          .intInRange(0, 365 * 24)
          .map((h) => DateTime(2026).add(Duration(hours: h))),
      glados.any.combine2(
        glados.any.choose([
          DateTime(2026, 3, 7),
          DateTime(2026, 3, 27),
          DateTime(2026, 10, 23),
          DateTime(2026, 10, 30),
        ]),
        glados.any.intInRange(0, 4 * 24),
        (DateTime base, int h) => base.add(Duration(hours: h)),
      ),
    ]);

    glados.Glados2(day, day, glados.ExploreConfig(numRuns: 300)).test(
      'whole-day windows are ordered, symmetric and list consecutive days',
      (a, b) {
        final range = SystemHealthRange.days(firstDay: a, lastDay: b);
        final swapped = SystemHealthRange.days(firstDay: b, lastDay: a);

        expect(range.start.isAfter(range.end), isFalse);
        expect((swapped.start, swapped.end), (range.start, range.end));
        expect(range.contains(range.start), isTrue);
        expect(range.contains(range.end), isTrue);
        expect(
          range.contains(range.end.add(const Duration(microseconds: 1))),
          isFalse,
        );

        final days = range.days;
        final earlier = a.isBefore(b) ? a : b;
        final later = a.isBefore(b) ? b : a;
        expect(days.first, DateTime(earlier.year, earlier.month, earlier.day));
        expect(days.last, DateTime(later.year, later.month, later.day));
        for (final (i, d) in days.indexed) {
          expect((d.hour, d.minute), (0, 0));
          if (i > 0) {
            expect(d, SystemHealthRange.nextCalendarDay(days[i - 1]));
          }
        }
      },
      tags: 'glados',
    );
  });
}
