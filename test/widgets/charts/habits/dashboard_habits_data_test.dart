import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';

HabitCompletionEntry _completion({
  required String id,
  required DateTime day,
  required DateTime writtenAt,
  required HabitCompletionType? completionType,
}) {
  return HabitCompletionEntry(
    meta: Metadata(
      id: id,
      createdAt: writtenAt,
      updatedAt: writtenAt,
      dateFrom: day,
      dateTo: day,
      private: false,
    ),
    data: HabitCompletionData(
      dateFrom: day,
      dateTo: day,
      habitId: 'habit-1',
      completionType: completionType,
    ),
  );
}

void main() {
  group('HabitResult', () {
    test('compares both day and completion type', () {
      const success = HabitResult(
        dayString: '2024-03-15',
        completionType: HabitCompletionType.success,
      );
      const fail = HabitResult(
        dayString: '2024-03-15',
        completionType: HabitCompletionType.fail,
      );

      expect(success, isNot(equals(fail)));
    });
  });

  group('habitResultsByDay', () {
    final habitDefinition = HabitDefinition(
      id: 'habit-1',
      name: 'Run',
      description: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
      active: true,
      activeFrom: DateTime(2024),
      habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    );

    test('uses the latest write for duplicate completions on one day', () {
      final day = DateTime(2024, 3, 15, 21);

      final results = habitResultsByDay(
        [
          _completion(
            id: 'latest-fail',
            day: day,
            writtenAt: DateTime(2024, 3, 15, 23),
            completionType: HabitCompletionType.fail,
          ),
          _completion(
            id: 'older-success',
            day: day,
            writtenAt: DateTime(2024, 3, 15, 22),
            completionType: HabitCompletionType.success,
          ),
        ],
        habitDefinition: habitDefinition,
        rangeStart: DateTime(2024, 3, 15),
        rangeEnd: DateTime(2024, 3, 15, 23),
      );

      expect(results, hasLength(1));
      expect(results.single.dayString, '2024-03-15');
      expect(results.single.completionType, HabitCompletionType.fail);
    });

    test('keeps the default day result when completion type is absent', () {
      final day = DateTime(2024, 3, 15, 21);

      final results = habitResultsByDay(
        [
          _completion(
            id: 'legacy-null-completion',
            day: day,
            writtenAt: DateTime(2024, 3, 15, 22),
            completionType: null,
          ),
        ],
        habitDefinition: habitDefinition,
        rangeStart: DateTime(2024, 3, 15),
        rangeEnd: DateTime(2024, 3, 15, 23),
      );

      expect(results, hasLength(1));
      expect(results.single.dayString, '2024-03-15');
      expect(results.single.completionType, HabitCompletionType.open);
    });
  });

  // -------------------------------------------------------------------------
  // habitResultsByDay — Glados deduplication property
  //
  // Invariant: regardless of how many duplicate completions exist for the
  // same day (i.e. the same `habitId:dayString` key), the output must
  // contain at most one HabitResult per dayString in the range.
  // -------------------------------------------------------------------------
  group('habitResultsByDay — Glados deduplication property', () {
    final habitDef = HabitDefinition(
      id: 'habit-glados',
      name: 'Exercise',
      description: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
      active: true,
      activeFrom: DateTime(2024),
      habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    );

    glados.Glados<_HabitDeduplicationScenario>(
      glados.any.habitDeduplicationScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output contains at most one HabitResult per dayString for any input',
      (scenario) {
        final results = habitResultsByDay(
          scenario.entities,
          habitDefinition: habitDef,
          rangeStart: scenario.rangeStart,
          rangeEnd: scenario.rangeEnd,
        );

        // Each dayString must appear at most once in the output.
        final dayStrings = results.map((r) => r.dayString).toList();
        expect(
          dayStrings.toSet().length,
          dayStrings.length,
          reason: 'duplicate dayString found — $scenario',
        );

        // Output length must match the number of days in the range + 1
        // (habitResultsByDay uses range.inDays + 1).
        final rangeDays =
            scenario.rangeEnd.difference(scenario.rangeStart).inDays + 1;
        expect(
          results.length,
          rangeDays,
          reason: 'result length must equal range span — $scenario',
        );
      },
      tags: 'glados',
    );
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for habitResultsByDay deduplication tests.
// ---------------------------------------------------------------------------

class _HabitDeduplicationScenario {
  const _HabitDeduplicationScenario({
    required this.rangeDays,
    required this.completionSpecs,
  });

  final int rangeDays;

  /// Each spec: (dayOffset within range, completionType index, writtenHour)
  final List<({int dayOffset, int typeIndex, int writtenHour})> completionSpecs;

  static final DateTime base = DateTime(2024, 4);

  DateTime get rangeStart => base;
  DateTime get rangeEnd => base.add(Duration(days: rangeDays - 1));

  List<JournalEntity> get entities {
    const types = HabitCompletionType.values;
    return <JournalEntity>[
      for (final (index, spec) in completionSpecs.indexed)
        HabitCompletionEntry(
          meta: Metadata(
            id: 'gc-$index',
            createdAt: base.add(
              Duration(
                days: spec.dayOffset % rangeDays,
                hours: spec.writtenHour % 24,
              ),
            ),
            updatedAt: base.add(
              Duration(
                days: spec.dayOffset % rangeDays,
                hours: spec.writtenHour % 24,
              ),
            ),
            dateFrom: base.add(Duration(days: spec.dayOffset % rangeDays)),
            dateTo: base.add(Duration(days: spec.dayOffset % rangeDays)),
            private: false,
          ),
          data: HabitCompletionData(
            dateFrom: base.add(Duration(days: spec.dayOffset % rangeDays)),
            dateTo: base.add(Duration(days: spec.dayOffset % rangeDays)),
            habitId: 'habit-glados',
            completionType: types[spec.typeIndex % types.length],
          ),
        ),
    ];
  }

  @override
  String toString() =>
      '_HabitDeduplicationScenario(rangeDays: $rangeDays, '
      'completionSpecs.length: ${completionSpecs.length})';
}

extension _AnyHabitDeduplication on glados.Any {
  glados.Generator<({int dayOffset, int typeIndex, int writtenHour})>
      get completionSpec => glados.CombinableAny(this).combine3(
            glados.IntAnys(this).intInRange(0, 6),
            glados.IntAnys(this).intInRange(0, 3),
            glados.IntAnys(this).intInRange(0, 23),
            (dayOffset, typeIndex, writtenHour) => (
              dayOffset: dayOffset,
              typeIndex: typeIndex,
              writtenHour: writtenHour,
            ),
          );

  glados.Generator<_HabitDeduplicationScenario>
      get habitDeduplicationScenario => glados.CombinableAny(this).combine2(
            glados.IntAnys(this).intInRange(1, 7),
            glados.ListAnys(this).listWithLengthInRange(0, 12, completionSpec),
            (rangeDays, completionSpecs) => _HabitDeduplicationScenario(
              rangeDays: rangeDays,
              completionSpecs: completionSpecs,
            ),
          );
}
