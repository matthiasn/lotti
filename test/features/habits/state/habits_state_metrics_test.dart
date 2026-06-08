import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'habits_state_test_helpers.dart';

void main() {
  group('dayPercentages', () {
    // Habits active before the selected day so totalForDay counts them.
    final activeDate = DateTime(2025, 12, 20);

    HabitDefinition createHabit(String id) {
      return HabitDefinition(
        id: id,
        name: 'Habit $id',
        description: 'Description',
        createdAt: activeDate,
        updatedAt: activeDate,
        vectorClock: null,
        private: false,
        active: true,
        activeFrom: activeDate,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );
    }

    HabitsState stateWith({
      Set<String> successful = const {},
      Set<String> skipped = const {},
      Set<String> failed = const {},
    }) {
      return HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
          createHabit('4'),
        ],
        successfulByDay: {'2025-12-30': successful},
        skippedByDay: {'2025-12-30': skipped},
        failedByDay: {'2025-12-30': failed},
      );
    }

    test('returns the raw rate for each band when they fit under 100', () {
      // 4 habits: 2 success (50%), 1 skipped (25%), 1 failed (25%).
      final result = dayPercentages(
        stateWith(
          successful: {'1', '2'},
          skipped: {'3'},
          failed: {'4'},
        ),
      );

      expect(result.success, 50);
      expect(result.skipped, 25);
      expect(result.failed, 25);
    });

    test(
      'clamps failed to the remaining headroom (success + skipped = 100)',
      () {
        // 3 success (75%) + 1 skipped (25%) leaves 0 headroom, so even though
        // the raw failed rate would be 50%, the clamp drops it to 0.
        final result = dayPercentages(
          stateWith(
            successful: {'1', '2', '3'},
            skipped: {'4'},
            failed: {'1', '2'}, // raw failed = 50%
          ),
        );

        expect(result.success, 75);
        expect(result.skipped, 25);
        expect(result.failed, 0);
      },
    );

    test('returns all zeros when there are no completions', () {
      final result = dayPercentages(stateWith());

      expect(result.success, 0);
      expect(result.skipped, 0);
      expect(result.failed, 0);
    });
  });

  group('habitMinY', () {
    // Use fixed dates to ensure habits are active before the test dates (2025-12-29, 2025-12-30)
    final activeDate = DateTime(2025, 12, 20);

    HabitDefinition createHabit(String id) {
      return HabitDefinition(
        id: id,
        name: 'Habit $id',
        description: 'Description',
        createdAt: activeDate,
        updatedAt: activeDate,
        vectorClock: null,
        private: false,
        active: true,
        activeFrom: activeDate,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );
    }

    test('returns 0 when no habits', () {
      final state = HabitsState.initial();
      final days = ['2025-12-29', '2025-12-30'];
      final result = habitMinY(days: days, state: state);

      expect(result, 0);
    });

    test('returns 0 when lowest is below 20', () {
      final state = HabitsState.initial().copyWith(
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
          createHabit('4'),
          createHabit('5'),
        ],
        successfulByDay: {
          '2025-12-30': {'1'}, // 1 out of 5 = 20%
        },
      );
      final days = ['2025-12-30'];
      final result = habitMinY(days: days, state: state);

      // 20% - 20 = 0%
      expect(result, 0);
    });

    test('calculates minY based on lowest success rate', () {
      final state = HabitsState.initial().copyWith(
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
        ],
        successfulByDay: {
          '2025-12-29': {'1', '2'}, // 100%
          '2025-12-30': {'1'}, // 50%
        },
      );
      final days = ['2025-12-29', '2025-12-30'];
      final result = habitMinY(days: days, state: state);

      // lowest is 50%, so minY = 50 - 20 = 30
      expect(result, 30);
    });

    test('never returns negative value', () {
      final state = HabitsState.initial().copyWith(
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
          createHabit('4'),
          createHabit('5'),
          createHabit('6'),
          createHabit('7'),
          createHabit('8'),
          createHabit('9'),
          createHabit('10'),
        ],
        successfulByDay: {
          '2025-12-30': {'1'}, // 10%
        },
      );
      final days = ['2025-12-30'];
      final result = habitMinY(days: days, state: state);

      // 10% - 20 would be -10, but should clamp to 0
      expect(result, 0);
    });
  });

  group('HabitDisplayFilter', () {
    test('has all expected values', () {
      expect(HabitDisplayFilter.values.length, 4);
      expect(HabitDisplayFilter.values, contains(HabitDisplayFilter.openNow));
      expect(
        HabitDisplayFilter.values,
        contains(HabitDisplayFilter.pendingLater),
      );
      expect(HabitDisplayFilter.values, contains(HabitDisplayFilter.completed));
      expect(HabitDisplayFilter.values, contains(HabitDisplayFilter.all));
    });
  });

  group('completionRate — properties', () {
    glados.Glados(
      glados.CombinableAny(glados.any).combine2(
        glados.any.intInRange(1, 15),
        glados.any.intInRange(0, 15),
        (int total, int n) => (total: total, n: n > total ? total : n),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always in [0, 100]',
      (pair) {
        final state = hStateWithHabits(
          pair.total,
          byDay: {
            '2025-01-01': {for (var i = 0; i < pair.n; i++) 'h$i'},
          },
        );
        final rate = completionRate(state, state.allByDay);
        expect(rate, greaterThanOrEqualTo(0));
        expect(rate, lessThanOrEqualTo(100));
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.intInRange(1, 15),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returns 100 when all habits completed',
      (n) {
        final state = hStateWithHabits(
          n,
          byDay: {
            '2025-01-01': {for (var i = 0; i < n; i++) 'h$i'},
          },
        );
        final rate = completionRate(state, state.allByDay);
        expect(rate, equals(100));
      },
      tags: 'glados',
    );
  });

  group('habitMinY — properties', () {
    glados.Glados(
      glados.any.intInRange(0, 15),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always >= 0',
      (n) {
        final successCount = n > 0 ? n ~/ 2 : 0;
        final state = hStateWithHabits(
          n,
          successfulByDay: n > 0
              ? {
                  '2025-01-01': {
                    for (var i = 0; i < successCount; i++) 'h$i',
                  },
                }
              : {},
        );
        final result = habitMinY(days: const ['2025-01-01'], state: state);
        expect(result, greaterThanOrEqualTo(0.0));
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.intInRange(1, 15),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always <= 80 when all habits succeed (100% - 20 = 80)',
      (n) {
        final state = hStateWithHabits(
          n,
          successfulByDay: {
            '2025-01-01': {for (var i = 0; i < n; i++) 'h$i'},
          },
        );
        final result = habitMinY(days: const ['2025-01-01'], state: state);
        // At 100% success rate, minY = max(100-20, 0) = 80.
        expect(result, lessThanOrEqualTo(100.0));
      },
      tags: 'glados',
    );
  });

  group('activeBy — properties', () {
    glados.Glados(
      glados.CombinableAny(glados.any).combine2(
        glados.ListAnys(glados.any).listWithLengthInRange(
          0,
          12,
          // -1 → null activeFrom; 0..40 → day offset from the base date.
          glados.any.intInRange(-1, 41),
        ),
        glados.any.intInRange(0, 40),
        (List<int> offsets, int queryOffset) =>
            (offsets: offsets, queryOffset: queryOffset),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returns exactly the habits whose activeFrom date is on or before '
      'the query day, preserving order',
      (scenario) {
        // January window: multi-day Duration arithmetic is DST-safe here.
        final base = DateTime(2024, 1, 10);
        final habits = <HabitDefinition>[
          for (var i = 0; i < scenario.offsets.length; i++)
            hMakeHabitForActiveBy(
              'h$i',
              scenario.offsets[i] == -1
                  ? null
                  // Mix in a time-of-day so the property proves activeFrom
                  // is compared date-only (same-day boundary included).
                  : base.add(
                      Duration(days: scenario.offsets[i], hours: i % 24),
                    ),
            ),
        ];
        final queryDay = base.add(Duration(days: scenario.queryOffset));
        final ymd =
            '${queryDay.year}-'
            '${queryDay.month.toString().padLeft(2, '0')}-'
            '${queryDay.day.toString().padLeft(2, '0')}';

        final result = activeBy(habits, ymd);

        // Oracle: date-only activeFrom (null → DateTime(0)) must be on or
        // before the parsed query day; order of survivors is preserved.
        final expectedIds = <String>[
          for (final habit in habits)
            if (!DateTime(
              (habit.activeFrom ?? DateTime(0)).year,
              (habit.activeFrom ?? DateTime(0)).month,
              (habit.activeFrom ?? DateTime(0)).day,
            ).isAfter(queryDay))
              habit.id,
        ];
        expect(
          result.map((habit) => habit.id).toList(),
          expectedIds,
          reason: 'offsets=${scenario.offsets} query=$ymd',
        );
      },
      tags: 'glados',
    );
  });
}
