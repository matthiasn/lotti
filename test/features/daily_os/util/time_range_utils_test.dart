import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';

void main() {
  group('TimeRange', () {
    test('calculates duration correctly', () {
      final range = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11, 30),
      );

      expect(range.duration, const Duration(hours: 1, minutes: 30));
    });

    group('overlaps', () {
      test('returns true when ranges overlap', () {
        final range1 = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 12),
        );
        final range2 = TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 13),
        );

        expect(range1.overlaps(range2), isTrue);
        expect(range2.overlaps(range1), isTrue);
      });

      test('returns true when one range contains another', () {
        final outer = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 14),
        );
        final inner = TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 13),
        );

        expect(outer.overlaps(inner), isTrue);
        expect(inner.overlaps(outer), isTrue);
      });

      test('returns true when ranges touch at endpoints', () {
        final range1 = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 12),
        );
        final range2 = TimeRange(
          start: DateTime(2024, 1, 15, 12),
          end: DateTime(2024, 1, 15, 14),
        );

        expect(range1.overlaps(range2), isTrue);
        expect(range2.overlaps(range1), isTrue);
      });

      test('returns false when ranges do not overlap', () {
        final range1 = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 11),
        );
        final range2 = TimeRange(
          start: DateTime(2024, 1, 15, 12),
          end: DateTime(2024, 1, 15, 13),
        );

        expect(range1.overlaps(range2), isFalse);
        expect(range2.overlaps(range1), isFalse);
      });
    });

    group('merge', () {
      test('merges overlapping ranges correctly', () {
        final range1 = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 12),
        );
        final range2 = TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 13),
        );

        final merged = range1.merge(range2);

        expect(merged.start, DateTime(2024, 1, 15, 10));
        expect(merged.end, DateTime(2024, 1, 15, 13));
        expect(merged.duration, const Duration(hours: 3));
      });

      test('merges when one range contains another', () {
        final outer = TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 14),
        );
        final inner = TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 13),
        );

        final merged = outer.merge(inner);

        expect(merged.start, DateTime(2024, 1, 15, 10));
        expect(merged.end, DateTime(2024, 1, 15, 14));
        expect(merged.duration, const Duration(hours: 4));
      });
    });

    test('equality works correctly', () {
      final range1 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 12),
      );
      final range2 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 12),
      );
      final range3 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 13),
      );

      expect(range1, equals(range2));
      expect(range1, isNot(equals(range3)));
    });
  });

  group('mergeOverlappingRanges', () {
    test('returns empty list for empty input', () {
      expect(mergeOverlappingRanges([]), isEmpty);
    });

    test('returns single range for single input', () {
      final range = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 12),
      );

      expect(mergeOverlappingRanges([range]), [range]);
    });

    test('merges two overlapping ranges', () {
      final range1 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 12),
      );
      final range2 = TimeRange(
        start: DateTime(2024, 1, 15, 11),
        end: DateTime(2024, 1, 15, 13),
      );

      final merged = mergeOverlappingRanges([range1, range2]);

      expect(merged.length, 1);
      expect(merged[0].start, DateTime(2024, 1, 15, 10));
      expect(merged[0].end, DateTime(2024, 1, 15, 13));
    });

    test('keeps non-overlapping ranges separate', () {
      final range1 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11),
      );
      final range2 = TimeRange(
        start: DateTime(2024, 1, 15, 12),
        end: DateTime(2024, 1, 15, 13),
      );

      final merged = mergeOverlappingRanges([range1, range2]);

      expect(merged.length, 2);
    });

    test('merges multiple overlapping ranges into one', () {
      final ranges = [
        TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 11),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 10, 30),
          end: DateTime(2024, 1, 15, 11, 30),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 12),
        ),
      ];

      final merged = mergeOverlappingRanges(ranges);

      expect(merged.length, 1);
      expect(merged[0].start, DateTime(2024, 1, 15, 10));
      expect(merged[0].end, DateTime(2024, 1, 15, 12));
    });

    test('handles contained ranges (gym trip scenario)', () {
      // Gym trip: 10:00 - 11:30 (1.5 hours)
      // Fitness entry: 10:30 - 11:15 (45 minutes)
      // Should merge to a single 1.5 hour block

      final gymTrip = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11, 30),
      );
      final fitnessEntry = TimeRange(
        start: DateTime(2024, 1, 15, 10, 30),
        end: DateTime(2024, 1, 15, 11, 15),
      );

      final merged = mergeOverlappingRanges([gymTrip, fitnessEntry]);

      expect(merged.length, 1);
      expect(merged[0].start, DateTime(2024, 1, 15, 10));
      expect(merged[0].end, DateTime(2024, 1, 15, 11, 30));
      expect(merged[0].duration, const Duration(hours: 1, minutes: 30));
    });

    test('handles out-of-order input', () {
      final ranges = [
        TimeRange(
          start: DateTime(2024, 1, 15, 14),
          end: DateTime(2024, 1, 15, 15),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 11),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 10, 30),
          end: DateTime(2024, 1, 15, 11, 30),
        ),
      ];

      final merged = mergeOverlappingRanges(ranges);

      expect(merged.length, 2);
      // First merged group
      expect(merged[0].start, DateTime(2024, 1, 15, 10));
      expect(merged[0].end, DateTime(2024, 1, 15, 11, 30));
      // Separate later range
      expect(merged[1].start, DateTime(2024, 1, 15, 14));
      expect(merged[1].end, DateTime(2024, 1, 15, 15));
    });
  });

  group('calculateUnionDuration', () {
    test('returns zero for empty input', () {
      expect(calculateUnionDuration([]), Duration.zero);
    });

    test('returns duration of single range', () {
      final range = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11, 30),
      );

      expect(
        calculateUnionDuration([range]),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('calculates union for overlapping ranges (no double counting)', () {
      final range1 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 12),
      );
      final range2 = TimeRange(
        start: DateTime(2024, 1, 15, 11),
        end: DateTime(2024, 1, 15, 13),
      );

      // Without union: 2h + 2h = 4h
      // With union: 10:00 - 13:00 = 3h
      expect(
          calculateUnionDuration([range1, range2]), const Duration(hours: 3));
    });

    test('sums non-overlapping ranges', () {
      final range1 = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11),
      );
      final range2 = TimeRange(
        start: DateTime(2024, 1, 15, 12),
        end: DateTime(2024, 1, 15, 13),
      );

      expect(
          calculateUnionDuration([range1, range2]), const Duration(hours: 2));
    });

    test('gym trip scenario: prevents double counting', () {
      // This is the exact scenario from the requirements:
      // Gym trip: 10:00 - 11:30 (1.5 hours total including travel)
      // Fitness entry: 10:30 - 11:15 (45 minutes of actual lifting)
      //
      // OLD behavior (simple sum): 1.5h + 0.75h = 2.25h (WRONG)
      // NEW behavior (union): 1.5h (CORRECT)

      final gymTrip = TimeRange(
        start: DateTime(2024, 1, 15, 10),
        end: DateTime(2024, 1, 15, 11, 30),
      );
      final fitnessEntry = TimeRange(
        start: DateTime(2024, 1, 15, 10, 30),
        end: DateTime(2024, 1, 15, 11, 15),
      );

      // Simple sum would be 90 + 45 = 135 minutes = 2h 15m
      final simpleSumMinutes =
          gymTrip.duration.inMinutes + fitnessEntry.duration.inMinutes;
      expect(simpleSumMinutes, 135);

      // Union should be 90 minutes = 1h 30m
      final unionDuration = calculateUnionDuration([gymTrip, fitnessEntry]);
      expect(unionDuration, const Duration(hours: 1, minutes: 30));
    });

    test('multiple contained entries scenario', () {
      // Morning block: 9:00 - 12:00 (3 hours)
      // Call 1: 9:30 - 10:00 (30 min)
      // Call 2: 10:30 - 11:00 (30 min)
      // Call 3: 11:15 - 11:45 (30 min)
      //
      // All calls are within the morning block
      // Total should be 3 hours, not 3h + 1.5h = 4.5h

      final morningBlock = TimeRange(
        start: DateTime(2024, 1, 15, 9),
        end: DateTime(2024, 1, 15, 12),
      );
      final call1 = TimeRange(
        start: DateTime(2024, 1, 15, 9, 30),
        end: DateTime(2024, 1, 15, 10),
      );
      final call2 = TimeRange(
        start: DateTime(2024, 1, 15, 10, 30),
        end: DateTime(2024, 1, 15, 11),
      );
      final call3 = TimeRange(
        start: DateTime(2024, 1, 15, 11, 15),
        end: DateTime(2024, 1, 15, 11, 45),
      );

      final unionDuration = calculateUnionDuration([
        morningBlock,
        call1,
        call2,
        call3,
      ]);

      expect(unionDuration, const Duration(hours: 3));
    });

    test('partially overlapping multiple ranges', () {
      // Range 1: 10:00 - 11:00
      // Range 2: 10:30 - 11:30
      // Range 3: 11:00 - 12:00
      // Union: 10:00 - 12:00 = 2 hours

      final ranges = [
        TimeRange(
          start: DateTime(2024, 1, 15, 10),
          end: DateTime(2024, 1, 15, 11),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 10, 30),
          end: DateTime(2024, 1, 15, 11, 30),
        ),
        TimeRange(
          start: DateTime(2024, 1, 15, 11),
          end: DateTime(2024, 1, 15, 12),
        ),
      ];

      expect(calculateUnionDuration(ranges), const Duration(hours: 2));
    });

    test('complex scenario with gaps and overlaps', () {
      // Group 1: 9:00 - 10:30 (merged from overlaps)
      //   - Entry A: 9:00 - 10:00
      //   - Entry B: 9:30 - 10:30
      //
      // Gap: 10:30 - 11:00
      //
      // Group 2: 11:00 - 12:00
      //   - Entry C: 11:00 - 12:00
      //
      // Total: 1.5h + 1h = 2.5h

      final entryA = TimeRange(
        start: DateTime(2024, 1, 15, 9),
        end: DateTime(2024, 1, 15, 10),
      );
      final entryB = TimeRange(
        start: DateTime(2024, 1, 15, 9, 30),
        end: DateTime(2024, 1, 15, 10, 30),
      );
      final entryC = TimeRange(
        start: DateTime(2024, 1, 15, 11),
        end: DateTime(2024, 1, 15, 12),
      );

      final unionDuration = calculateUnionDuration([entryA, entryB, entryC]);

      expect(
        unionDuration,
        const Duration(hours: 2, minutes: 30),
      );
    });
  });
}
