import 'package:flutter_test/flutter_test.dart';
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
}
