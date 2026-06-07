import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';

enum _GeneratedSnapGrid { one, five, ten, fifteen, thirty, sixty }

int _gridMinutes(_GeneratedSnapGrid grid) {
  return switch (grid) {
    _GeneratedSnapGrid.one => 1,
    _GeneratedSnapGrid.five => 5,
    _GeneratedSnapGrid.ten => 10,
    _GeneratedSnapGrid.fifteen => 15,
    _GeneratedSnapGrid.thirty => 30,
    _GeneratedSnapGrid.sixty => 60,
  };
}

class _GeneratedDragMathScenario {
  const _GeneratedDragMathScenario({
    required this.minutes,
    required this.grid,
    required this.deltaQuarterPixels,
  });

  final int minutes;
  final _GeneratedSnapGrid grid;
  final int deltaQuarterPixels;

  int get gridMinutes => _gridMinutes(grid);

  double get deltaY => deltaQuarterPixels / 4;

  @override
  String toString() {
    return '_GeneratedDragMathScenario('
        'minutes: $minutes, grid: $grid, '
        'deltaQuarterPixels: $deltaQuarterPixels)';
  }
}

class _GeneratedDateMinutesScenario {
  const _GeneratedDateMinutesScenario({
    required this.dayOffset,
    required this.hour,
    required this.minute,
  });

  final int dayOffset;
  final int hour;
  final int minute;

  DateTime get date => DateTime(2026, 1, 15);

  DateTime get time => DateTime(2026, 1, 15 + dayOffset, hour, minute);

  int get expectedMinutes => (dayOffset * kMaxMinutesInDay + hour * 60 + minute)
      .clamp(0, kMaxMinutesInDay);

  @override
  String toString() {
    return '_GeneratedDateMinutesScenario('
        'dayOffset: $dayOffset, hour: $hour, minute: $minute)';
  }
}

extension _AnyGeneratedDragPosition on glados.Any {
  glados.Generator<_GeneratedSnapGrid> get snapGrid =>
      glados.AnyUtils(this).choose(_GeneratedSnapGrid.values);

  glados.Generator<_GeneratedDragMathScenario> get dragMathScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(-2880, 2880),
        snapGrid,
        glados.IntAnys(this).intInRange(-2000, 2000),
        (
          int minutes,
          _GeneratedSnapGrid grid,
          int deltaQuarterPixels,
        ) => _GeneratedDragMathScenario(
          minutes: minutes,
          grid: grid,
          deltaQuarterPixels: deltaQuarterPixels,
        ),
      );

  glados.Generator<int> get durationMinutes =>
      glados.IntAnys(this).intInRange(0, 1440);

  glados.Generator<_GeneratedDateMinutesScenario> get dateMinutesScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(-2, 3),
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(0, 59),
        (int dayOffset, int hour, int minute) => _GeneratedDateMinutesScenario(
          dayOffset: dayOffset,
          hour: hour,
          minute: minute,
        ),
      );
}

void main() {
  group('Constants', () {
    test('drag/resize constants keep their documented values', () {
      // Table-driven pin of the geometry contract: a deliberate change to
      // any of these must touch this single test.
      final documented = <String, (num, num)>{
        'kHourHeight': (kHourHeight, 40.0),
        'kResizeHandleHeightDesktop': (kResizeHandleHeightDesktop, 12.0),
        'kResizeHandleHeightTouch': (kResizeHandleHeightTouch, 20.0),
        'kMinimumBlockMinutes': (kMinimumBlockMinutes, 15),
        'kMinimumBlockHeightForResize': (kMinimumBlockHeightForResize, 48.0),
        'kSnapToMinutes': (kSnapToMinutes, 5),
        'kMaxMinutesInDay': (kMaxMinutesInDay, 24 * 60),
      };
      for (final MapEntry(key: name, value: (actual, expected))
          in documented.entries) {
        expect(actual, expected, reason: name);
      }
    });
  });

  group('minutesFromDate', () {
    test('converts same-day time to minutes', () {
      final date = DateTime(2026, 1, 15);
      final time = DateTime(2026, 1, 15, 9, 15);
      expect(minutesFromDate(date, time), equals(9 * 60 + 15));
    });

    test('treats next-day midnight as 24:00 (1440 minutes)', () {
      final date = DateTime(2026, 1, 15);
      final nextDayMidnight = DateTime(2026, 1, 16);
      expect(minutesFromDate(date, nextDayMidnight), equals(1440));
    });

    test('clamps times beyond end of day to 1440', () {
      final date = DateTime(2026, 1, 15);
      final nextDayOneAm = DateTime(2026, 1, 16, 1);
      expect(minutesFromDate(date, nextDayOneAm), equals(1440));
    });
  });

  group('snapToGrid', () {
    test('snaps to nearest 5 minutes by default', () {
      expect(snapToGrid(62), equals(60)); // 1:02 -> 1:00
      expect(snapToGrid(63), equals(65)); // 1:03 -> 1:05
      expect(snapToGrid(67), equals(65)); // 1:07 -> 1:05
      expect(snapToGrid(68), equals(70)); // 1:08 -> 1:10
    });

    test('exact grid values stay unchanged', () {
      expect(snapToGrid(60), equals(60));
      expect(snapToGrid(65), equals(65));
      expect(snapToGrid(120), equals(120));
    });

    test('custom grid interval works', () {
      expect(snapToGrid(62, gridMinutes: 15), equals(60));
      expect(snapToGrid(68, gridMinutes: 15), equals(75));
    });

    test('clamps to 0 at minimum', () {
      expect(snapToGrid(-10), equals(0));
      expect(snapToGrid(-100), equals(0));
    });

    test('clamps to kMaxMinutesInDay at maximum', () {
      expect(snapToGrid(1450), equals(kMaxMinutesInDay)); // 1440
      expect(snapToGrid(2000), equals(kMaxMinutesInDay));
    });

    test('edge case: exactly midnight (1440) stays at 1440', () {
      expect(snapToGrid(1440), equals(1440));
    });

    test('snaps correctly around midnight', () {
      expect(snapToGrid(1438), equals(1440)); // 23:58 -> 24:00
      expect(snapToGrid(1437), equals(1435)); // 23:57 -> 23:55
    });

    glados.Glados(
      glados.any.dragMathScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('keeps generated snap results bounded and idempotent', (scenario) {
      final snapped = snapToGrid(
        scenario.minutes,
        gridMinutes: scenario.gridMinutes,
      );

      expect(snapped, inInclusiveRange(0, kMaxMinutesInDay));
      expect(snapped % scenario.gridMinutes, 0, reason: '$scenario');
      expect(
        snapToGrid(snapped, gridMinutes: scenario.gridMinutes),
        snapped,
        reason: '$scenario',
      );

      if (scenario.minutes >= 0 && scenario.minutes <= kMaxMinutesInDay) {
        expect(
          (snapped - scenario.minutes).abs(),
          lessThanOrEqualTo(scenario.gridMinutes / 2),
          reason: '$scenario',
        );
      }
    }, tags: 'glados');
  });

  group('deltaToMinutes', () {
    test('converts 0 delta to 0 minutes', () {
      expect(deltaToMinutes(0), equals(0));
    });

    test('converts positive delta correctly', () {
      expect(deltaToMinutes(40), equals(60)); // 1 hour
      expect(deltaToMinutes(20), equals(30)); // 30 minutes
      expect(deltaToMinutes(10), equals(15)); // 15 minutes
    });

    test('converts negative delta correctly', () {
      expect(deltaToMinutes(-40), equals(-60)); // -1 hour
      expect(deltaToMinutes(-20), equals(-30)); // -30 minutes
    });

    test('rounds to nearest minute', () {
      // 5px = 7.5 minutes, rounds to 8
      expect(deltaToMinutes(5), equals(8));
      // -5px = -7.5 minutes, rounds to -8
      expect(deltaToMinutes(-5), equals(-8));
    });

    test('small movements round appropriately', () {
      // Less than 0.67px per minute threshold
      expect(deltaToMinutes(0.5), equals(1)); // ~0.75 minutes, rounds to 1
      expect(deltaToMinutes(0.3), equals(0)); // ~0.45 minutes, rounds to 0
    });

    glados.Glados(
      glados.any.dragMathScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('converts generated pixel deltas using the timeline scale', (
      scenario,
    ) {
      expect(
        deltaToMinutes(scenario.deltaY),
        (scenario.deltaY / kHourHeight * 60).round(),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('formatMinutesAsTime', () {
    test('formats midnight correctly', () {
      expect(formatMinutesAsTime(0), equals('00:00'));
    });

    test('formats noon correctly', () {
      expect(formatMinutesAsTime(720), equals('12:00'));
    });

    test('formats end of day correctly', () {
      // 1440 minutes = 24:00 (end of day boundary)
      expect(formatMinutesAsTime(1440), equals('24:00'));
    });

    test('formats morning time correctly', () {
      expect(formatMinutesAsTime(555), equals('09:15'));
    });

    test('formats afternoon time correctly', () {
      expect(formatMinutesAsTime(870), equals('14:30'));
    });

    test('formats single digit hours with padding', () {
      expect(formatMinutesAsTime(60), equals('01:00'));
      expect(formatMinutesAsTime(125), equals('02:05'));
    });

    test('formats single digit minutes with padding', () {
      expect(formatMinutesAsTime(545), equals('09:05'));
      expect(formatMinutesAsTime(601), equals('10:01'));
    });

    test('clamps to 24:00 for values at or beyond end of day', () {
      // Edge case: if minutes exceed 1440, still show 24:00
      expect(formatMinutesAsTime(1500), equals('24:00'));
    });

    glados.Glados(
      glados.any.dragMathScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('formats generated snapped minutes as parseable day times', (
      scenario,
    ) {
      final snapped = snapToGrid(
        scenario.minutes,
        gridMinutes: scenario.gridMinutes,
      );
      final label = formatMinutesAsTime(snapped);

      expect(_parseTimeLabel(label), snapped, reason: '$scenario');
    }, tags: 'glados');
  });

  group('formatDurationMinutes', () {
    test('formats minutes only when less than 1 hour', () {
      expect(formatDurationMinutes(30), equals('30m'));
      expect(formatDurationMinutes(45), equals('45m'));
      expect(formatDurationMinutes(15), equals('15m'));
    });

    test('formats hours only when exact hours', () {
      expect(formatDurationMinutes(60), equals('1h'));
      expect(formatDurationMinutes(120), equals('2h'));
      expect(formatDurationMinutes(180), equals('3h'));
    });

    test('formats hours and minutes when both present', () {
      expect(formatDurationMinutes(90), equals('1h 30m'));
      expect(formatDurationMinutes(75), equals('1h 15m'));
      expect(formatDurationMinutes(145), equals('2h 25m'));
    });

    test('handles zero duration', () {
      expect(formatDurationMinutes(0), equals('0m'));
    });

    test('handles very long durations', () {
      expect(formatDurationMinutes(480), equals('8h'));
      expect(formatDurationMinutes(485), equals('8h 5m'));
    });

    test('negative input keeps a non-negative minute remainder', () {
      // Documents the current (unguarded) behavior for negative durations.
      // Dart `%` yields a non-negative remainder for a positive divisor and
      // `~/` truncates toward zero, so the minute part is never negative while
      // the hour part carries the sign.
      expect(formatDurationMinutes(-30), equals('30m'));
      expect(formatDurationMinutes(-60), equals('-1h'));
      expect(formatDurationMinutes(-90), equals('-1h 30m'));
    });

    glados.Glados(
      glados.any.durationMinutes,
      glados.ExploreConfig(numRuns: 120),
    ).test('round-trips non-negative durations through the label', (minutes) {
      // For any non-negative duration, the formatted label must parse back to
      // the exact same number of minutes.
      expect(_parseDurationLabel(formatDurationMinutes(minutes)), minutes);
    }, tags: 'glados');
  });

  group('Round-trip conversions', () {
    test('deltaToMinutes produces consistent results', () {
      // If we move 1 hour down (40px), we should get 60 minutes
      const delta = 40.0;
      final minutes = deltaToMinutes(delta);
      expect(minutes, equals(60));

      // If we convert 60 minutes to position offset
      const expectedPosition = 60 * kHourHeight / 60;
      expect(expectedPosition, equals(delta));
    });
  });

  group('minutesFromDate generated scenarios', () {
    glados.Glados(
      glados.any.dateMinutesScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test('uses calendar day offset and clamps to visible day', (scenario) {
      expect(
        minutesFromDate(scenario.date, scenario.time),
        scenario.expectedMinutes,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('Integration scenarios', () {
    test('drag move calculation: 30 min move down', () {
      const originalStartMinutes = 9 * 60 + 30; // 9:30
      const originalEndMinutes = 10 * 60 + 30; // 10:30

      // User drags 20px down (30 minutes)
      final deltaMinutes = deltaToMinutes(20);
      expect(deltaMinutes, equals(30));

      var newStartMinutes = originalStartMinutes + deltaMinutes;
      newStartMinutes = snapToGrid(newStartMinutes);
      expect(newStartMinutes, equals(10 * 60)); // 10:00

      final newEndMinutes =
          newStartMinutes + (originalEndMinutes - originalStartMinutes);
      expect(newEndMinutes, equals(11 * 60)); // 11:00
    });

    test('resize top calculation: shrink by 15 min', () {
      const originalStartMinutes = 9 * 60; // 9:00
      const originalEndMinutes = 10 * 60; // 10:00

      // User drags top edge down 10px (15 minutes)
      final deltaMinutes = deltaToMinutes(10);
      expect(deltaMinutes, equals(15));

      var newStartMinutes = originalStartMinutes + deltaMinutes;
      newStartMinutes = snapToGrid(newStartMinutes);
      expect(newStartMinutes, equals(9 * 60 + 15)); // 9:15

      // Duration shrinks from 60 to 45 minutes
      final newDuration = originalEndMinutes - newStartMinutes;
      expect(newDuration, equals(45));
    });
  });
}

int _parseTimeLabel(String label) {
  final parts = label.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Parses a `formatDurationMinutes` label (e.g. "1h 30m", "45m", "2h") back
/// into total minutes, the inverse of the formatter for non-negative inputs.
int _parseDurationLabel(String label) {
  var minutes = 0;
  final hoursMatch = RegExp(r'(\d+)h').firstMatch(label);
  if (hoursMatch != null) {
    minutes += int.parse(hoursMatch.group(1)!) * 60;
  }
  final minutesMatch = RegExp(r'(\d+)m').firstMatch(label);
  if (minutesMatch != null) {
    minutes += int.parse(minutesMatch.group(1)!);
  }
  return minutes;
}
