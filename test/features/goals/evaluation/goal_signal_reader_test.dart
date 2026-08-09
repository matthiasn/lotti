import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb journalDb;
  late GoalSignalReader reader;

  final reference = DateTime(2026, 8, 8, 14, 30);

  Metadata meta(DateTime dateFrom, {String? id}) => Metadata(
    id: id ?? 'e-${dateFrom.millisecondsSinceEpoch}',
    createdAt: dateFrom,
    updatedAt: dateFrom,
    dateFrom: dateFrom,
    dateTo: dateFrom,
  );

  JournalEntity steps(DateTime at, num value) => JournalEntity.quantitative(
    meta: meta(at),
    data: QuantitativeData.cumulativeQuantityData(
      dateFrom: at,
      dateTo: at,
      value: value,
      dataType: 'cumulative_step_count',
      unit: 'count',
    ),
  );

  JournalEntity habit(DateTime at, HabitCompletionType type) =>
      JournalEntity.habitCompletion(
        meta: meta(at),
        data: HabitCompletionData(
          habitId: 'gym-habit',
          dateFrom: at,
          dateTo: at,
          completionType: type,
        ),
      );

  JournalEntity measurement(DateTime at, num value) =>
      JournalEntity.measurement(
        meta: meta(at),
        data: MeasurementData(
          dateFrom: at,
          dateTo: at,
          value: value,
          dataTypeId: 'water-id',
        ),
      );

  setUp(() {
    journalDb = MockJournalDb();
    reader = GoalSignalReader(journalDb: journalDb);
    when(
      () => journalDb.getQuantitativeByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => journalDb.getHabitCompletionsByHabitId(
        habitId: any(named: 'habitId'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => journalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
  });

  const stepsCriterion = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  test(
    'cumulative step samples collapse to the day MAX, keyed dayUtc',
    () async {
      // A running counter sampled three times: the day total is the peak,
      // not the sum — matching the health chart the user actually sees.
      when(
        () => journalDb.getQuantitativeByType(
          type: 'cumulative_step_count',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) async => [
          steps(DateTime(2026, 8, 7, 9), 2100),
          steps(DateTime(2026, 8, 7, 15), 6400),
          steps(DateTime(2026, 8, 7, 21), 9800),
          steps(DateTime(2026, 8, 8, 8), 1200),
        ],
      );

      final window = await reader.read(
        criteria: stepsCriterion,
        reference: reference,
      );

      expect(
        window.quantitativeDailySums['cumulative_step_count'],
        {
          DateTime.utc(2026, 8, 7): 9800,
          DateTime.utc(2026, 8, 8): 1200,
        },
      );
    },
  );

  test(
    'unknown quantitative types fall back to a daily sum, not silence',
    () async {
      const custom = GoalCriterion.metric(
        criterionId: 'rows',
        dataType: 'custom_rowing_meters',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        target: 2000,
      );
      when(
        () => journalDb.getQuantitativeByType(
          type: 'custom_rowing_meters',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) async => [
          JournalEntity.quantitative(
            meta: meta(DateTime(2026, 8, 8, 7)),
            data: QuantitativeData.discreteQuantityData(
              dateFrom: DateTime(2026, 8, 8, 7),
              dateTo: DateTime(2026, 8, 8, 7),
              value: 800,
              dataType: 'custom_rowing_meters',
              unit: 'm',
            ),
          ),
          JournalEntity.quantitative(
            meta: meta(DateTime(2026, 8, 8, 18)),
            data: QuantitativeData.discreteQuantityData(
              dateFrom: DateTime(2026, 8, 8, 18),
              dateTo: DateTime(2026, 8, 8, 18),
              value: 1400,
              dataType: 'custom_rowing_meters',
              unit: 'm',
            ),
          ),
        ],
      );

      final window = await reader.read(criteria: custom, reference: reference);
      expect(
        window.quantitativeDailySums['custom_rowing_meters']![DateTime.utc(
          2026,
          8,
          8,
        )],
        2200,
      );
    },
  );

  test(
    'only success completions count; skip and fail days are absent',
    () async {
      const gym = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      );
      when(
        () => journalDb.getHabitCompletionsByHabitId(
          habitId: 'gym-habit',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) async => [
          habit(DateTime(2026, 8, 3, 18), HabitCompletionType.success),
          habit(DateTime(2026, 8, 5, 18), HabitCompletionType.skip),
          habit(DateTime(2026, 8, 6, 18), HabitCompletionType.fail),
          // Defensive: a stray non-habit entity in the result set is
          // skipped, never counted.
          measurement(DateTime(2026, 8, 4, 18), 1),
        ],
      );

      final window = await reader.read(criteria: gym, reference: reference);
      expect(
        window.habitSuccessesByDay['gym-habit'],
        {DateTime.utc(2026, 8, 3): 1},
      );
    },
  );

  test("point-sample types (aggregation none) keep the day's LATEST "
      'sample', () async {
    const weight = GoalCriterion.metric(
      criterionId: 'weight',
      dataType: 'HealthDataType.WEIGHT',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.max,
      target: 80,
      direction: GoalDirection.atMost,
    );
    JournalEntity sample(DateTime at, num value) => JournalEntity.quantitative(
      meta: meta(at),
      data: QuantitativeData.discreteQuantityData(
        dateFrom: at,
        dateTo: at,
        value: value,
        dataType: 'HealthDataType.WEIGHT',
        unit: 'kg',
      ),
    );
    when(
      () => journalDb.getQuantitativeByType(
        type: 'HealthDataType.WEIGHT',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      // Newest-first, like the real query: without deterministic
      // reduction the OLDEST sample would win the day-keyed map.
      (_) async => [
        sample(DateTime(2026, 8, 8, 21), 79.4),
        sample(DateTime(2026, 8, 8, 7), 81.2),
        // Defensive: a stray non-quantitative row is skipped, not bucketed.
        measurement(DateTime(2026, 8, 8, 12), 1),
      ],
    );

    final window = await reader.read(criteria: weight, reference: reference);
    expect(
      window.quantitativeDailySums['HealthDataType.WEIGHT']![DateTime.utc(
        2026,
        8,
        8,
      )],
      79.4,
    );
  });

  test('percentage point samples are normalized to display units, '
      'matching the chart', () async {
    const bodyFat = GoalCriterion.metric(
      criterionId: 'bf',
      dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.max,
      target: 18,
      direction: GoalDirection.atMost,
    );
    when(
      () => journalDb.getQuantitativeByType(
        type: 'HealthDataType.BODY_FAT_PERCENTAGE',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [
        JournalEntity.quantitative(
          meta: meta(DateTime(2026, 8, 8, 8)),
          data: QuantitativeData.discreteQuantityData(
            dateFrom: DateTime(2026, 8, 8, 8),
            dateTo: DateTime(2026, 8, 8, 8),
            // Stored as a fraction; the chart — and a user target of
            // "18%" — read it ×100 (`aggregateNone` normalization).
            value: 0.18,
            dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
            unit: '%',
          ),
        ),
      ],
    );

    final window = await reader.read(criteria: bodyFat, reference: reference);
    expect(
      window
          .quantitativeDailySums['HealthDataType.BODY_FAT_PERCENTAGE']![DateTime.utc(
        2026,
        8,
        8,
      )],
      18,
    );
  });

  test('measurements sum per day', () async {
    const water = GoalCriterion.measurable(
      criterionId: 'water',
      dataTypeId: 'water-id',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      target: 2000,
    );
    when(
      () => journalDb.getMeasurementsByType(
        type: 'water-id',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [
        measurement(DateTime(2026, 8, 8, 9), 500),
        measurement(DateTime(2026, 8, 8, 13), 700),
      ],
    );

    final window = await reader.read(criteria: water, reference: reference);
    expect(
      window.measurableDailySums['water-id']![DateTime.utc(2026, 8, 8)],
      1200,
    );
  });

  test(
    'the query range covers the widest window plus a prior period',
    () async {
      await reader.read(criteria: stepsCriterion, reference: reference);
      final captured = verify(
        () => journalDb.getQuantitativeByType(
          type: 'cumulative_step_count',
          rangeStart: captureAny(named: 'rangeStart'),
          rangeEnd: captureAny(named: 'rangeEnd'),
        ),
      ).captured;
      final rangeStart = captured[0] as DateTime;
      final rangeEnd = captured[1] as DateTime;
      // Rolling 7 ending Aug 8 starts Aug 2; one extra period back for the
      // grace check reaches Jul 26.
      expect(rangeStart, DateTime(2026, 7, 26));
      // End of the reference day so late entries today are included.
      expect(rangeEnd, DateTime(2026, 8, 9));
    },
  );

  test('trigger tokens are exactly the leaf identifiers, through every '
      'composite shape', () {
    const composite = GoalCriterion.allOf(
      criterionId: 'root',
      criteria: [
        stepsCriterion,
        GoalCriterion.anyOf(
          criterionId: 'either',
          criteria: [
            GoalCriterion.habit(
              criterionId: 'gym',
              habitId: 'gym-habit',
              window: GoalWindow.calendarWeek(),
              targetCount: 3,
            ),
          ],
        ),
        GoalCriterion.atLeastCount(
          criterionId: 'some',
          criteria: [
            GoalCriterion.measurable(
              criterionId: 'water',
              dataTypeId: 'water-id',
              window: GoalWindow.day(),
              aggregation: GoalAggregation.sum,
              target: 2000,
            ),
          ],
          successes: 1,
        ),
      ],
    );
    expect(
      goalSignalTriggerTokens(composite),
      {'cumulative_step_count', 'gym-habit', 'water-id'},
    );
  });

  test('composite trees widen the query range across all leaf windows, and '
      'stray entity types in a result set are ignored', () async {
    const composite = GoalCriterion.anyOf(
      criterionId: 'either',
      criteria: [
        stepsCriterion,
        GoalCriterion.atLeastCount(
          criterionId: 'some',
          criteria: [
            GoalCriterion.measurable(
              criterionId: 'water',
              dataTypeId: 'water-id',
              window: GoalWindow.day(),
              aggregation: GoalAggregation.sum,
              target: 2000,
            ),
          ],
          successes: 1,
        ),
      ],
    );
    // A habit completion arriving in a quantitative/measurable result set
    // (defensive: the query filters by subtype, decode does not) must be
    // skipped, not crash or count.
    when(
      () => journalDb.getMeasurementsByType(
        type: 'water-id',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [
        habit(DateTime(2026, 8, 8, 9), HabitCompletionType.success),
        measurement(DateTime(2026, 8, 8, 9), 500),
      ],
    );
    when(
      () => journalDb.getQuantitativeByType(
        type: 'cumulative_step_count',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [measurement(DateTime(2026, 8, 8, 9), 500)],
    );

    final window = await reader.read(criteria: composite, reference: reference);
    expect(
      window.measurableDailySums['water-id']![DateTime.utc(2026, 8, 8)],
      500,
    );
    expect(window.quantitativeDailySums['cumulative_step_count'], isEmpty);

    // The rolling-7 leaf dominates the range: Jul 26 (window + one prior
    // period), even though the other leaf is a single day.
    final captured = verify(
      () => journalDb.getMeasurementsByType(
        type: 'water-id',
        rangeStart: captureAny(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).captured;
    expect(captured.single, DateTime(2026, 7, 26));
  });
}
