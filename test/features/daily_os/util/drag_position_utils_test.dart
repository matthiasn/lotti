import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Constants', () {
    test('kHourHeight has expected value', () {
      expect(kHourHeight, equals(40.0));
    });

    test('kResizeHandleHeightDesktop has expected value', () {
      expect(kResizeHandleHeightDesktop, equals(12.0));
    });

    test('kResizeHandleHeightTouch has expected value', () {
      expect(kResizeHandleHeightTouch, equals(20.0));
    });

    test('kMinimumBlockMinutes has expected value', () {
      expect(kMinimumBlockMinutes, equals(15));
    });

    test('kMinimumBlockHeightForResize has expected value', () {
      expect(kMinimumBlockHeightForResize, equals(48.0));
    });

    test('kSnapToMinutes has expected value', () {
      expect(kSnapToMinutes, equals(5));
    });

    test('kMaxMinutesInDay has expected value', () {
      expect(kMaxMinutesInDay, equals(24 * 60));
    });
  });

  group('positionToMinutes', () {
    test('converts 0 position at section start to section start minutes', () {
      final minutes = positionToMinutes(0, 9); // Section starts at 9 AM
      expect(minutes, equals(9 * 60)); // 540 minutes
    });

    test('converts position at 1 hour mark correctly', () {
      // 40px = 1 hour at kHourHeight=40
      final minutes = positionToMinutes(40, 9);
      expect(minutes, equals(10 * 60)); // 10:00 AM = 600 minutes
    });

    test('converts position at 30 minutes correctly', () {
      // 20px = 30 minutes at kHourHeight=40
      final minutes = positionToMinutes(20, 9);
      expect(minutes, equals(9 * 60 + 30)); // 9:30 AM = 570 minutes
    });

    test('converts position at 15 minutes correctly', () {
      // 10px = 15 minutes
      final minutes = positionToMinutes(10, 9);
      expect(minutes, equals(9 * 60 + 15)); // 9:15 AM = 555 minutes
    });

    test('handles different section start hours', () {
      final minutes = positionToMinutes(0, 14); // Section starts at 2 PM
      expect(minutes, equals(14 * 60)); // 840 minutes
    });

    test('rounds to nearest minute', () {
      // 5px = 7.5 minutes, should round to 8
      final minutes = positionToMinutes(5, 0);
      expect(minutes, equals(8));
    });
  });

  group('minutesToPosition', () {
    test('converts section start minutes to 0 position', () {
      final position = minutesToPosition(9 * 60, 9); // 9:00 AM, section at 9
      expect(position, equals(0.0));
    });

    test('converts 1 hour into section to 40px', () {
      final position = minutesToPosition(10 * 60, 9); // 10:00 AM
      expect(position, equals(40.0));
    });

    test('converts 30 minutes into section to 20px', () {
      final position = minutesToPosition(9 * 60 + 30, 9); // 9:30 AM
      expect(position, equals(20.0));
    });

    test('converts 15 minutes into section to 10px', () {
      final position = minutesToPosition(9 * 60 + 15, 9); // 9:15 AM
      expect(position, equals(10.0));
    });

    test('handles afternoon section correctly', () {
      final position = minutesToPosition(15 * 60, 14); // 3 PM, section at 2 PM
      expect(position, equals(40.0)); // 1 hour into section
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
  });

  group('clampToSection', () {
    test('keeps value in middle of section unchanged', () {
      final clamped = clampToSection(600, 9, 17); // 10:00 AM
      expect(clamped, equals(600));
    });

    test('clamps value below section start to section start', () {
      final clamped = clampToSection(500, 9, 17); // Before 9:00 AM
      expect(clamped, equals(9 * 60)); // 540
    });

    test('clamps value above section end to section end', () {
      final clamped = clampToSection(1100, 9, 17); // After 5:00 PM
      expect(clamped, equals(17 * 60)); // 1020
    });

    test('keeps value at section start unchanged', () {
      final clamped = clampToSection(540, 9, 17); // Exactly 9:00 AM
      expect(clamped, equals(540));
    });

    test('keeps value at section end unchanged', () {
      final clamped = clampToSection(1020, 9, 17); // Exactly 5:00 PM
      expect(clamped, equals(1020));
    });

    test('handles early morning section', () {
      final clamped = clampToSection(0, 0, 6);
      expect(clamped, equals(0));

      final clamped2 = clampToSection(400, 0, 6);
      expect(clamped2, equals(360)); // 6:00 AM
    });

    test('handles late night section', () {
      final clamped = clampToSection(1500, 22, 24);
      expect(clamped, equals(1440)); // 24:00
    });
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
  });

  group('Round-trip conversions', () {
    test('positionToMinutes and minutesToPosition are inverses', () {
      const sectionStart = 9;

      // Position -> Minutes -> Position
      for (var position = 0.0; position <= 320; position += 10) {
        final minutes = positionToMinutes(position, sectionStart);
        final backToPosition = minutesToPosition(minutes, sectionStart);
        expect(
          backToPosition,
          closeTo(position, 1.0),
          reason: 'Round-trip failed for position $position',
        );
      }
    });

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

    test('section boundary clamping', () {
      const sectionStart = 9;
      const sectionEnd = 12;
      const blockDuration = 60; // 1 hour

      // Try to move block starting at 9:00 up (before section)
      var newStartMinutes = 8 * 60; // 8:00, before section
      newStartMinutes =
          clampToSection(newStartMinutes, sectionStart, sectionEnd)
              .clamp(sectionStart * 60, sectionEnd * 60 - blockDuration);
      expect(newStartMinutes, equals(9 * 60)); // Clamped to 9:00

      // Try to move block ending after section
      var newStartMinutes2 = 11 * 60 + 30; // 11:30
      final newEndMinutes2 =
          newStartMinutes2 + blockDuration; // 12:30, after section
      if (newEndMinutes2 > sectionEnd * 60) {
        newStartMinutes2 = sectionEnd * 60 - blockDuration;
      }
      expect(newStartMinutes2, equals(11 * 60)); // 11:00, so end is 12:00
    });
  });
}
