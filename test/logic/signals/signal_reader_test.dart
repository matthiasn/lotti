import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/signals/signal_reader.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import 'signal_test_fixtures.dart';

void main() {
  late MockJournalDb journalDb;
  late SignalReader reader;

  final reference = DateTime(2026, 8, 8, 14, 30);
  final todayKey = DateTime.utc(2026, 8, 8);

  setUp(() {
    journalDb = MockJournalDb();
    reader = SignalReader(journalDb: journalDb);
  });

  void stubQuantitative(List<JournalEntity> entities) => when(
    () => journalDb.getQuantitativeByType(
      type: any(named: 'type'),
      rangeStart: any(named: 'rangeStart'),
      rangeEnd: any(named: 'rangeEnd'),
    ),
  ).thenAnswer((_) async => entities);

  void stubMeasurements(List<JournalEntity> entities) => when(
    () => journalDb.getMeasurementsByType(
      type: any(named: 'type'),
      rangeStart: any(named: 'rangeStart'),
      rangeEnd: any(named: 'rangeEnd'),
    ),
  ).thenAnswer((_) async => entities);

  void stubWorkouts(List<JournalEntity> entities) => when(
    () => journalDb.getWorkoutsByType(
      workoutType: any(named: 'workoutType'),
      rangeStart: any(named: 'rangeStart'),
      rangeEnd: any(named: 'rangeEnd'),
    ),
  ).thenAnswer((_) async => entities);

  void stubHabit(List<JournalEntity> entities) => when(
    () => journalDb.getHabitCompletionsByHabitId(
      habitId: any(named: 'habitId'),
      rangeStart: any(named: 'rangeStart'),
      rangeEnd: any(named: 'rangeEnd'),
    ),
  ).thenAnswer((_) async => entities);

  test('the window spans `days` calendar days ending today', () async {
    stubMeasurements(const []);
    final window = await reader.read(
      rule: const AutoCompleteRule.measurable(dataTypeId: 'water'),
      reference: reference,
    );
    expect(window.end, todayKey);
    expect(window.start, DateTime.utc(2026, 7, 26));

    final captured = verify(
      () => journalDb.getMeasurementsByType(
        type: 'water',
        rangeStart: captureAny(named: 'rangeStart'),
        rangeEnd: captureAny(named: 'rangeEnd'),
      ),
    ).captured;
    expect(captured[0], DateTime(2026, 7, 26));
    // Next local midnight, so the reference day keeps its final hour.
    expect(captured[1], DateTime(2026, 8, 9));
  });

  test(
    'each series is queried once however often the tree names it',
    () async {
      stubMeasurements(const []);
      stubQuantitative(const []);
      stubHabit(const []);
      await reader.read(
        rule: const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water'),
            AutoCompleteRule.or(
              rules: [
                AutoCompleteRule.measurable(dataTypeId: 'water'),
                AutoCompleteRule.health(dataType: 'cumulative_step_count'),
                AutoCompleteRule.habit(habitId: 'habit-a'),
              ],
            ),
          ],
        ),
        reference: reference,
      );
      verify(
        () => journalDb.getMeasurementsByType(
          type: 'water',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(1);
      verify(
        () => journalDb.getQuantitativeByType(
          type: 'cumulative_step_count',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(1);
      verify(
        () => journalDb.getHabitCompletionsByHabitId(
          habitId: 'habit-a',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(1);
    },
  );

  test(
    'buckets every series by day and drops rows after the reference',
    () async {
      stubMeasurements([
        measurementEntity(DateTime(2026, 8, 8, 8), 250),
        measurementEntity(DateTime(2026, 8, 8, 12), 500),
        // Written after the reference instant: not part of this snapshot.
        measurementEntity(DateTime(2026, 8, 8, 16), 9999),
      ]);
      stubQuantitative([
        stepsEntity(DateTime(2026, 8, 8, 9), 2000),
        stepsEntity(DateTime(2026, 8, 8, 13), 4120),
        stepsEntity(DateTime(2026, 8, 8, 20), 9000),
      ]);
      stubHabit([
        habitCompletionEntity(
          DateTime(2026, 8, 7, 9),
          HabitCompletionType.success,
        ),
        habitCompletionEntity(
          DateTime(2026, 8, 8, 9),
          HabitCompletionType.skip,
        ),
        // A success stamped after the reference instant is not part of this
        // snapshot either — same rule as every other series.
        habitCompletionEntity(
          DateTime(2026, 8, 8, 16),
          HabitCompletionType.success,
        ),
      ]);
      final run = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30),
        distance: 5000,
      );
      stubWorkouts([
        run,
        workoutEntity(
          DateTime(2026, 8, 8, 18),
          length: const Duration(minutes: 30),
        ),
      ]);

      final window = await reader.read(
        rule: const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water'),
            AutoCompleteRule.health(dataType: 'cumulative_step_count'),
            AutoCompleteRule.workout(dataType: 'running'),
            AutoCompleteRule.habit(habitId: 'habit-a'),
          ],
        ),
        reference: reference,
      );

      expect(
        window,
        SignalWindow(
          start: DateTime.utc(2026, 7, 26),
          end: todayKey,
          measurableTotalsByDay: {
            'water': {todayKey: 750},
          },
          quantitativeByDay: {
            'cumulative_step_count': {todayKey: 4120},
          },
          workoutsByDay: {
            'running': {
              todayKey: [(run as WorkoutEntry).data],
            },
          },
          habitSuccessDays: {
            'habit-a': {DateTime.utc(2026, 8, 7)},
          },
        ),
      );
      verify(
        () => journalDb.getWorkoutsByType(
          workoutType: 'running',
          rangeStart: DateTime(2026, 7, 26),
          rangeEnd: DateTime(2026, 8, 9),
        ),
      ).called(1);
    },
  );

  group('workoutEntities across spelling eras', () {
    final rangeStart = DateTime(2026, 8);
    final rangeEnd = DateTime(2026, 8, 9);

    void stubSpelling(String spelling, List<JournalEntity> entities) => when(
      () => journalDb.getWorkoutsByType(
        workoutType: spelling,
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => entities);

    // The picker persisted whatever spelling the rows carried at the time, so
    // a rule keyed `RUNNING` (created against plugin-era rows) must keep
    // matching once new rows are stored as `running` — and vice versa.
    test('merges rows stored in either spelling, newest first', () async {
      final older = workoutEntity(
        DateTime(2026, 8, 5, 7),
        length: const Duration(minutes: 30),
      );
      final newer = workoutEntity(
        DateTime(2026, 8, 7, 7),
        length: const Duration(minutes: 45),
      );
      stubWorkouts(const []);
      stubSpelling('running', [older]);
      stubSpelling('RUNNING', [newer]);

      final entities = await reader.workoutEntities(
        workoutType: 'RUNNING',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entities, [newer, older]);
      for (final spelling in ['running', 'RUNNING']) {
        verify(
          () => journalDb.getWorkoutsByType(
            workoutType: spelling,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ).called(1);
      }
    });

    test('a row answering under both spellings counts once', () async {
      final run = workoutEntity(
        DateTime(2026, 8, 5, 7),
        length: const Duration(minutes: 30),
      );
      stubWorkouts(const []);
      stubSpelling('running', [run]);
      stubSpelling('RUNNING', [run]);

      final entities = await reader.workoutEntities(
        workoutType: 'running',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entities, [run]);
    });

    test('a plugin-era rule reads canonical rows through read()', () async {
      stubWorkouts(const []);
      final run = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30),
      );
      stubSpelling('running', [run]);

      final window = await reader.read(
        rule: const AutoCompleteRule.workout(dataType: 'RUNNING'),
        reference: reference,
      );

      // Bucketed under the rule's own key, so the evaluator finds it.
      expect(window.workoutsByDay['RUNNING'], {
        todayKey: [(run as WorkoutEntry).data],
      });
    });
  });

  test('a rule that needs nothing touches the database not at all', () async {
    final window = await reader.read(
      rule: const AutoCompleteRule.and(rules: []),
      reference: reference,
    );
    expect(window.measurableTotalsByDay, isEmpty);
    verifyNever(
      () => journalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    );
  });
}
