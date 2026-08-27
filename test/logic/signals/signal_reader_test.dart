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
      ]);

      final window = await reader.read(
        rule: const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water'),
            AutoCompleteRule.health(dataType: 'cumulative_step_count'),
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
          habitSuccessDays: {
            'habit-a': {DateTime.utc(2026, 8, 7)},
          },
        ),
      );
    },
  );

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
