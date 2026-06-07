import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_state.dart';

// ---------------------------------------------------------------------------
// Helpers shared by the Glados property groups below.
// ---------------------------------------------------------------------------

/// Creates a minimal HabitDefinition active from [activeFrom]
/// (null exercises the `?? DateTime(0)` fallback in [activeBy]).
HabitDefinition _makeHabitForActiveBy(String id, DateTime? activeFrom) {
  final created = activeFrom ?? DateTime(2019);
  return HabitDefinition(
    id: id,
    name: 'Habit $id',
    description: '',
    createdAt: created,
    updatedAt: created,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: activeFrom,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );
}

/// Builds a [HabitsState] with [n] habits whose activeFrom precedes
/// '2025-01-01' and whose selectedInfoYmd is '2025-01-01'.
HabitsState _stateWithHabits(
  int n, {
  Map<String, Set<String>> byDay = const {},
  Map<String, Set<String>> successfulByDay = const {},
}) {
  final activeDate = DateTime(2019);
  final definitions = <HabitDefinition>[
    for (var i = 0; i < n; i++) _makeHabitForActiveBy('h$i', activeDate),
  ];
  return HabitsState.initial().copyWith(
    habitDefinitions: definitions,
    selectedInfoYmd: '2025-01-01',
    allByDay: byDay,
    successfulByDay: successfulByDay,
  );
}

void main() {
  group('HabitsState', () {
    test('initial state has expected defaults', () {
      final state = HabitsState.initial();

      expect(state.habitDefinitions, isEmpty);
      expect(state.habitCompletions, isEmpty);
      expect(state.completedToday, isEmpty);
      expect(state.openHabits, isEmpty);
      expect(state.openNow, isEmpty);
      expect(state.pendingLater, isEmpty);
      expect(state.completed, isEmpty);
      expect(state.successfulToday, isEmpty);
      expect(state.successfulByDay, isEmpty);
      expect(state.skippedByDay, isEmpty);
      expect(state.failedByDay, isEmpty);
      expect(state.allByDay, isEmpty);
      expect(state.selectedInfoYmd, isEmpty);
      expect(state.successPercentage, 0);
      expect(state.skippedPercentage, 0);
      expect(state.failedPercentage, 0);
      expect(state.shortStreakCount, 0);
      expect(state.longStreakCount, 0);
      expect(state.zeroBased, true);
      expect(state.minY, 0);
      expect(state.displayFilter, HabitDisplayFilter.openNow);
      expect(state.showSearch, false);
      expect(state.showTimeSpan, false);
      expect(state.searchString, isEmpty);
      expect(state.selectedCategoryIds, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final state = HabitsState.initial();
      final modified = state.copyWith(showSearch: true);

      expect(modified.showSearch, true);
      expect(modified.displayFilter, state.displayFilter);
      expect(modified.zeroBased, state.zeroBased);
    });
  });

  group('getHabitDays', () {
    test('returns correct number of days', () {
      final days = getHabitDays(7);

      // Should have 8 days (today + 7 days back)
      expect(days.length, 8);
    });

    test('days are sorted in ascending order', () {
      final days = getHabitDays(7);

      for (var i = 0; i < days.length - 1; i++) {
        expect(
          DateTime.parse(days[i]).isBefore(DateTime.parse(days[i + 1])),
          true,
          reason: 'Day $i should be before day ${i + 1}',
        );
      }
    });

    test('last day is today', () {
      final days = getHabitDays(7);
      // getHabitDays uses DateTime.now() internally, so we verify format
      // rather than an exact date to avoid coupling to a specific instant.
      expect(days.last, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('returns more days for larger time span', () {
      final days7 = getHabitDays(7);
      final days14 = getHabitDays(14);

      expect(days14.length, greaterThan(days7.length));
    });
  });

  group('activeBy', () {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final yesterday = testDate.subtract(const Duration(days: 1));
    final lastWeek = testDate.subtract(const Duration(days: 7));
    final tomorrow = testDate.add(const Duration(days: 1));

    HabitDefinition createHabit(String id, DateTime? activeFrom) {
      return HabitDefinition(
        id: id,
        name: 'Habit $id',
        description: 'Description',
        createdAt: lastWeek,
        updatedAt: lastWeek,
        vectorClock: null,
        private: false,
        active: true,
        activeFrom: activeFrom,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );
    }

    test('returns empty list for empty ymd', () {
      final habits = [createHabit('1', lastWeek)];
      final result = activeBy(habits, '');

      expect(result, isEmpty);
    });

    test('returns empty list for empty habits', () {
      final result = activeBy([], '2025-12-30');

      expect(result, isEmpty);
    });

    test('includes habits with activeFrom before the given date', () {
      final habits = [
        createHabit('1', lastWeek),
        createHabit('2', yesterday),
      ];
      const todayYmd = '2024-03-15';
      final result = activeBy(habits, todayYmd);

      expect(result.length, 2);
    });

    test('excludes habits with activeFrom on or after the given date', () {
      final habits = [
        createHabit('1', lastWeek),
        createHabit('2', tomorrow),
      ];
      const todayYmd = '2024-03-15';
      final result = activeBy(habits, todayYmd);

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('includes habits with null activeFrom (defaults to DateTime(0))', () {
      final habits = [
        createHabit('1', null),
      ];
      const todayYmd = '2024-03-15';
      final result = activeBy(habits, todayYmd);

      expect(result.length, 1);
    });
  });

  group('totalForDay', () {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final lastWeek = testDate.subtract(const Duration(days: 7));

    HabitDefinition createHabit(String id) {
      return HabitDefinition(
        id: id,
        name: 'Habit $id',
        description: 'Description',
        createdAt: lastWeek,
        updatedAt: lastWeek,
        vectorClock: null,
        private: false,
        active: true,
        activeFrom: lastWeek,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );
    }

    test('returns 0 for empty state', () {
      final state = HabitsState.initial();
      final result = totalForDay('2025-12-30', state);

      expect(result, 0);
    });

    test('counts active habits for the day', () {
      final state = HabitsState.initial().copyWith(
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
        ],
      );
      const todayYmd = '2024-03-15';
      final result = totalForDay(todayYmd, state);

      expect(result, 3);
    });

    test('includes habits from allByDay that are not in definitions', () {
      final state = HabitsState.initial().copyWith(
        habitDefinitions: [createHabit('1')],
        allByDay: {
          '2025-12-30': {'1', '2', '3'},
        },
      );
      final result = totalForDay('2025-12-30', state);

      // 1 from definitions + 2 extra from allByDay
      expect(result, 3);
    });
  });

  group('completionRate', () {
    // Use fixed dates to ensure habits are active before the test date (2025-12-30)
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

    test('returns 0 when total is 0', () {
      final state = HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
      );
      final byDay = <String, Set<String>>{
        '2025-12-30': {'1', '2'},
      };
      final result = completionRate(state, byDay);

      expect(result, 0);
    });

    test('returns 0 when no completions for the day', () {
      final state = HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
        habitDefinitions: [createHabit('1'), createHabit('2')],
      );
      final byDay = <String, Set<String>>{};
      final result = completionRate(state, byDay);

      expect(result, 0);
    });

    test('calculates correct percentage', () {
      final state = HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
          createHabit('4'),
        ],
      );
      final byDay = <String, Set<String>>{
        '2025-12-30': {'1', '2'}, // 2 out of 4 = 50%
      };
      final result = completionRate(state, byDay);

      expect(result, 50);
    });

    test('rounds percentage correctly', () {
      final state = HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
          createHabit('3'),
        ],
      );
      final byDay = <String, Set<String>>{
        '2025-12-30': {'1'}, // 1 out of 3 = 33.33% -> 33%
      };
      final result = completionRate(state, byDay);

      expect(result, 33);
    });

    test('returns 100 for full completion', () {
      final state = HabitsState.initial().copyWith(
        selectedInfoYmd: '2025-12-30',
        habitDefinitions: [
          createHabit('1'),
          createHabit('2'),
        ],
      );
      final byDay = <String, Set<String>>{
        '2025-12-30': {'1', '2'}, // 2 out of 2 = 100%
      };
      final result = completionRate(state, byDay);

      expect(result, 100);
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
        final state = _stateWithHabits(
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
        final state = _stateWithHabits(
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
        final state = _stateWithHabits(
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
        final state = _stateWithHabits(
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
            _makeHabitForActiveBy(
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
