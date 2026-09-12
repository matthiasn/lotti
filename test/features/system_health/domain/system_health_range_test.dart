import 'package:flutter_test/flutter_test.dart';
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
}
