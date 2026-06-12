import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_calculations.dart';

void main() {
  final testDate = DateTime(2026, 1, 15);

  JournalEntity createTestEntry({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      ),
    );
  }

  group('calculateBudgetProgressStatus — properties', () {
    glados.Glados(
      glados.CombinableAny(glados.any).combine2(
        // Seconds rather than minutes so sub-minute remainders exercise
        // the inMinutes truncation around the 15-minute threshold.
        glados.any.intInRange(0, 4 * 3600),
        glados.any.intInRange(0, 4 * 3600),
        (int planned, int recorded) => (planned: planned, recorded: recorded),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'classifies by remaining time exactly per the threshold spec',
      (scenario) {
        final planned = Duration(seconds: scenario.planned);
        final recorded = Duration(seconds: scenario.recorded);

        final status = calculateBudgetProgressStatus(planned, recorded);

        // Oracle over remaining seconds (15 min threshold compares whole
        // minutes, so it truncates toward zero like Duration.inMinutes).
        final remainingSeconds = scenario.planned - scenario.recorded;
        final expected = remainingSeconds < 0
            ? BudgetProgressStatus.overBudget
            : remainingSeconds == 0
            ? BudgetProgressStatus.exhausted
            : remainingSeconds ~/ 60 <= 15
            ? BudgetProgressStatus.nearLimit
            : BudgetProgressStatus.underBudget;
        expect(
          status,
          expected,
          reason: 'planned=${scenario.planned}s recorded=${scenario.recorded}s',
        );
      },
      tags: 'glados',
    );
  });

  group('calculateDayStartHour / calculateDayEndHour', () {
    PlannedTimeSlot plannedAt(int startHour, int endHour) {
      final start = testDate.add(Duration(hours: startHour));
      final end = testDate.add(Duration(hours: endHour));
      return PlannedTimeSlot(
        startTime: start,
        endTime: end,
        categoryId: 'cat',
        block: PlannedBlock(
          id: 'b-$startHour-$endHour',
          categoryId: 'cat',
          startTime: start,
          endTime: end,
        ),
      );
    }

    ActualTimeSlot actualAt(int startHour, int endHour) {
      final start = testDate.add(Duration(hours: startHour));
      final end = testDate.add(Duration(hours: endHour));
      return ActualTimeSlot(
        startTime: start,
        endTime: end,
        categoryId: 'cat',
        entry: createTestEntry(
          id: 'e-$startHour-$endHour',
          categoryId: 'cat',
          dateFrom: start,
          dateTo: end,
        ),
      );
    }

    test('defaults to 8 / 18 when there are no slots', () {
      expect(calculateDayStartHour(const [], const []), 8);
      expect(calculateDayEndHour(const [], const [], testDate), 18);
    });

    test('start hour subtracts a one-hour lead-in buffer', () {
      expect(calculateDayStartHour([plannedAt(9, 11)], const []), 8);
    });

    test('start hour takes the earliest across planned and actual', () {
      // earliest start = min(10, 7) = 7, minus the 1h buffer.
      expect(
        calculateDayStartHour([plannedAt(10, 11)], [actualAt(7, 8)]),
        6,
      );
    });

    test('start-hour buffer clamps at midnight (never below 0)', () {
      expect(calculateDayStartHour([plannedAt(0, 1)], const []), 0);
    });

    test('end hour buffers past the latest end (endHour+1, then +1)', () {
      // slot ends at 11:00 -> endHour 12 -> +1 buffer -> 13.
      expect(calculateDayEndHour([plannedAt(9, 11)], const [], testDate), 13);
    });

    test('end hour treats a slot ending at next midnight as hour 24', () {
      expect(calculateDayEndHour([plannedAt(22, 24)], const [], testDate), 24);
    });

    test('end hour takes the max across planned and actual', () {
      // latest end = 15:00 -> endHour 16 -> +1 buffer -> 17.
      expect(
        calculateDayEndHour([plannedAt(9, 10)], [actualAt(12, 15)], testDate),
        17,
      );
    });

    glados.Glados(
      glados.any.listWithLengthInRange(0, 8, glados.any.intInRange(0, 24)),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'derived render window always stays within a valid 0..24 hour grid',
      (startHours) {
        final slots = [for (final h in startHours) plannedAt(h, h + 1)];

        final start = calculateDayStartHour(slots, const []);
        final end = calculateDayEndHour(slots, const [], testDate);

        expect(start, inInclusiveRange(0, 23), reason: 'starts=$startHours');
        expect(end, inInclusiveRange(1, 24), reason: 'starts=$startHours');
        // The window is always non-empty so the timeline never collapses.
        expect(start, lessThan(end), reason: 'starts=$startHours');
      },
      tags: 'glados',
    );
  });
}
