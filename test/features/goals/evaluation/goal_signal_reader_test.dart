import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb journalDb;
  late MockTimeService timeService;
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
    timeService = MockTimeService();
    when(timeService.getCurrent).thenReturn(null);
    when(() => timeService.linkedFrom).thenReturn(null);
    when(
      () => journalDb.insightsTimeCategoryForEntry(any()),
    ).thenAnswer((_) async => null);
    reader = GoalSignalReader(
      journalDb: journalDb,
      timeService: timeService,
    );
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
            meta: meta(DateTime(2026, 8, 8, 13)),
            data: QuantitativeData.discreteQuantityData(
              dateFrom: DateTime(2026, 8, 8, 13),
              dateTo: DateTime(2026, 8, 8, 13),
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
      expect(
        window.habitCompletionsByDay['gym-habit'],
        {
          DateTime.utc(2026, 8, 3): HabitCompletionType.success,
          DateTime.utc(2026, 8, 5): HabitCompletionType.skip,
          DateTime.utc(2026, 8, 6): HabitCompletionType.fail,
        },
      );
    },
  );

  test(
    'point-sample aggregate and raw evidence share the evaluation cutoff',
    () async {
      const weight = GoalCriterion.metric(
        criterionId: 'weight',
        dataType: 'HealthDataType.WEIGHT',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.max,
        target: 80,
        direction: GoalDirection.atMost,
      );
      JournalEntity sample(DateTime at, num value) =>
          JournalEntity.quantitative(
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
          // This row arrived after the wake captured its reference. Neither the
          // deterministic aggregate nor the exact model evidence may include it.
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
        81.2,
      );
      final observations =
          window.quantitativeObservationsByType['HealthDataType.WEIGHT']!;
      expect(
        observations.map((observation) => observation.recordedAt),
        [DateTime(2026, 8, 8, 7)],
        reason: 'both representations stop at the captured reference instant',
      );
      expect(observations.map((observation) => observation.value), [81.2]);
      expect(
        observations.map((observation) => observation.tieBreaker),
        [
          'e-${DateTime(2026, 8, 8, 7).millisecondsSinceEpoch}',
        ],
        reason: 'equal timestamps need a stable replica-independent ordering',
      );
    },
  );

  test('identical point-sample timestamps break the tie by entity id, '
      'independent of query return order', () async {
    const weight = GoalCriterion.metric(
      criterionId: 'weight',
      dataType: 'HealthDataType.WEIGHT',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.max,
      target: 80,
      direction: GoalDirection.atMost,
    );
    final at = DateTime(2026, 8, 8, 7);
    JournalEntity sample(String id, num value) => JournalEntity.quantitative(
      meta: meta(at, id: id),
      data: QuantitativeData.discreteQuantityData(
        dateFrom: at,
        dateTo: at,
        value: value,
        dataType: 'HealthDataType.WEIGHT',
        unit: 'kg',
      ),
    );
    final a = sample('id-a', 81.2);
    final b = sample('id-b', 79.4);

    for (final rows in [
      [a, b],
      [b, a],
    ]) {
      when(
        () => journalDb.getQuantitativeByType(
          type: 'HealthDataType.WEIGHT',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => rows);
      final window = await reader.read(criteria: weight, reference: reference);
      expect(
        window.quantitativeDailySums['HealthDataType.WEIGHT']![DateTime.utc(
          2026,
          8,
          8,
        )],
        79.4,
        reason: 'the greater id must win regardless of row order',
      );
    }
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
    expect(
      window.quantitativeObservationsByType,
      isEmpty,
      reason: 'only goal-supported health series add model-facing raw data',
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
      {
        ...goalImmediateSignalTriggerTokens(composite),
        ...goalStaleSignalTriggerTokens(composite),
      },
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

  test(
    'category time reuses Insights union semantics for all-day totals',
    () async {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'coding-cap',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 8,
      );
      when(
        () => journalDb.insightsTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => [
          (
            entryId: 'coding-a',
            dateFrom: DateTime(2026, 8, 8, 18),
            dateTo: DateTime(2026, 8, 8, 20),
            categoryId: 'vibe-coding',
          ),
          (
            entryId: 'coding-b',
            dateFrom: DateTime(2026, 8, 8, 19),
            dateTo: DateTime(2026, 8, 8, 21),
            categoryId: 'vibe-coding',
          ),
          (
            entryId: 'other',
            dateFrom: DateTime(2026, 8, 8, 17),
            dateTo: DateTime(2026, 8, 8, 22),
            categoryId: 'other',
          ),
        ],
      );

      final window = await reader.read(
        criteria: criterion,
        reference: DateTime(2026, 8, 8, 22),
      );

      expect(
        window.categoryTimeDailyHours['coding-cap'],
        {DateTime.utc(2026, 8, 8): 3},
      );
    },
  );

  test(
    'label time filters across categories and retains markdown evidence',
    () async {
      const criterion = GoalCriterion.labelTime(
        criterionId: 'daily-content',
        labelId: 'content',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1,
      );
      when(
        () => journalDb.goalLabelTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer(
        (_) async => [
          (
            entryId: 'draft',
            labelId: 'content',
            dateFrom: DateTime(2026, 8, 8, 9),
            dateTo: DateTime(2026, 8, 8, 9, 45),
            categoryId: 'writing',
            markdown: 'Drafted **three** sections.',
          ),
          (
            entryId: 'edit',
            labelId: 'content',
            dateFrom: DateTime(2026, 8, 8, 11),
            dateTo: DateTime(2026, 8, 8, 11, 20),
            categoryId: 'marketing',
            markdown: 'Edited launch copy.',
          ),
        ],
      );

      final window = await reader.read(
        criteria: criterion,
        reference: DateTime(2026, 8, 8, 12),
      );

      expect(window.labelTimeDailyHours['daily-content'], {
        DateTime.utc(2026, 8, 8): closeTo(65 / 60, 1e-9),
      });
      final evidence = window.labelTimeEntriesByCriterion['daily-content']!;
      expect(evidence.map((entry) => entry.categoryId), [
        'writing',
        'marketing',
      ]);
      expect(evidence.first.markdown, 'Drafted **three** sections.');
      verify(
        () => journalDb.goalLabelTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
          labelIds: const {'content'},
        ),
      ).called(1);
    },
  );

  test('category time excludes entries after the evaluation instant', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    final reference = DateTime(2026, 8, 8, 12);
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'spans-now',
          dateFrom: DateTime(2026, 8, 8, 11),
          dateTo: DateTime(2026, 8, 8, 13),
          categoryId: 'vibe-coding',
        ),
        (
          entryId: 'future',
          dateFrom: DateTime(2026, 8, 8, 13),
          dateTo: DateTime(2026, 8, 8, 14),
          categoryId: 'vibe-coding',
        ),
      ],
    );

    final window = await reader.read(
      criteria: criterion,
      reference: reference,
    );

    final queryEnd = verify(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: captureAny(named: 'end'),
      ),
    ).captured.single;
    expect(queryEnd, reference);
    expect(
      window.categoryTimeDailyHours['coding-cap'],
      {DateTime.utc(2026, 8, 8): 1},
    );
    expect(
      window.categoryTimeSessionsByCategory['vibe-coding']?.single.dateTo,
      reference,
    );
    expect(window.categoryTimeEvidenceEnd, reference);
  });

  test('a completed historical day uses the next midnight as its exclusive '
      'category-time endpoint', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    final reference = DateTime(2026, 8, 8, 23, 59, 59);
    final endExclusive = DateTime(2026, 8, 9);
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'final-second',
          dateFrom: reference,
          dateTo: endExclusive,
          categoryId: 'vibe-coding',
        ),
      ],
    );

    final window = await reader.read(
      criteria: criterion,
      reference: reference,
      timeEntryEndExclusive: endExclusive,
    );

    final queryEnd = verify(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: captureAny(named: 'end'),
      ),
    ).captured.single;
    expect(queryEnd, endExclusive);
    expect(
      window.categoryTimeSessionsByCategory['vibe-coding']?.single.dateTo,
      endExclusive,
      reason: 'the final second belongs to the completed period',
    );
    expect(window.categoryTimeEvidenceEnd, endExclusive);
  });

  test('category time replaces a persisted active timer prefix', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    final startedAt = DateTime(2026, 8, 8, 22);
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'running',
          dateFrom: startedAt,
          dateTo: DateTime(2026, 8, 8, 22, 15),
          categoryId: 'vibe-coding',
        ),
        (
          entryId: 'unrelated-same-start',
          dateFrom: startedAt,
          dateTo: DateTime(2026, 8, 8, 22, 30),
          categoryId: 'vibe-coding',
        ),
      ],
    );
    when(
      () => journalDb.getConfigFlag('private'),
    ).thenAnswer((_) async => false);
    final running = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'running',
        createdAt: startedAt,
        updatedAt: startedAt,
        dateFrom: startedAt,
        dateTo: startedAt,
        categoryId: 'entry-category',
      ),
    );
    final linkedTask = JournalEntity.task(
      meta: Metadata(
        id: 'task',
        createdAt: startedAt,
        updatedAt: startedAt,
        dateFrom: startedAt,
        dateTo: startedAt,
        categoryId: 'wrong-linked-category',
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status',
          createdAt: startedAt,
          utcOffset: 0,
        ),
        dateFrom: startedAt,
        dateTo: startedAt,
        statusHistory: const [],
        title: 'Coding',
      ),
    );
    when(timeService.getCurrent).thenReturn(running);
    when(() => timeService.linkedFrom).thenReturn(linkedTask);
    when(
      () => journalDb.insightsTimeCategoryForEntry('running'),
    ).thenAnswer((_) async => 'vibe-coding');

    final window = await reader.read(
      criteria: criterion,
      reference: DateTime(2026, 8, 8, 23, 30),
    );

    expect(
      window.categoryTimeDailyHours['coding-cap'],
      {DateTime.utc(2026, 8, 8): 1.5},
    );
    expect(
      window.categoryTimeSessionsByCategory['vibe-coding'],
      hasLength(2),
      reason:
          'the persisted timer prefix is replaced by id without deleting an '
          'unrelated session that happens to share its start and category',
    );
    expect(
      window.categoryTimeSessionsByCategory['vibe-coding']?.map(
        (session) => session.dateTo,
      ),
      contains(DateTime(2026, 8, 8, 23, 30)),
      reason: 'the in-memory timer endpoint must advance beyond persisted data',
    );
    expect(window.hasActiveCategoryTimer, isTrue);
  });

  test(
    'label time replaces a running prefix and exposes live markdown',
    () async {
      const criterion = GoalCriterion.labelTime(
        criterionId: 'daily-content',
        labelId: 'content',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1,
      );
      final startedAt = DateTime(2026, 8, 8, 22);
      when(
        () => journalDb.goalLabelTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer(
        (_) async => [
          (
            entryId: 'running',
            labelId: 'content',
            dateFrom: startedAt,
            dateTo: DateTime(2026, 8, 8, 22, 15),
            categoryId: 'writing',
            markdown: 'Old persisted text',
          ),
        ],
      );
      when(timeService.getCurrent).thenReturn(
        JournalEntity.journalEntry(
          meta: Metadata(
            id: 'running',
            createdAt: startedAt,
            updatedAt: startedAt,
            dateFrom: startedAt,
            dateTo: startedAt,
            categoryId: 'writing',
            labelIds: const ['content'],
          ),
          entryText: const EntryText(
            plainText: 'Drafting the release notes',
            markdown: 'Drafting the **release notes**',
          ),
        ),
      );
      when(
        () => journalDb.insightsTimeCategoryForEntry('running'),
      ).thenAnswer((_) async => 'writing');

      final window = await reader.read(
        criteria: criterion,
        reference: DateTime(2026, 8, 8, 23),
      );

      expect(window.labelTimeDailyHours['daily-content'], {
        DateTime.utc(2026, 8, 8): 1,
      });
      expect(
        window.labelTimeEntriesByCriterion['daily-content']?.single.markdown,
        'Drafting the **release notes**',
      );
      expect(window.hasActiveLabelTimer, isTrue);
    },
  );

  test('a hidden private active timer contributes no category time', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => journalDb.getConfigFlag('private'),
    ).thenAnswer((_) async => false);
    final startedAt = DateTime(2026, 8, 8, 22);
    when(timeService.getCurrent).thenReturn(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'private-running',
          createdAt: startedAt,
          updatedAt: startedAt,
          dateFrom: startedAt,
          dateTo: startedAt,
          categoryId: 'vibe-coding',
          private: true,
        ),
      ),
    );

    final window = await reader.read(
      criteria: criterion,
      reference: DateTime(2026, 8, 8, 23),
    );

    expect(window.categoryTimeDailyHours['coding-cap'], isEmpty);
    expect(window.hasActiveCategoryTimer, isFalse);
    verify(() => journalDb.getConfigFlag('private')).called(1);
  });

  test('an unadvanced active timer remains zero-duration evidence', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 2,
    );
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => []);
    final startedAt = DateTime(2026, 8, 8, 22);
    when(timeService.getCurrent).thenReturn(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'just-started',
          createdAt: startedAt,
          updatedAt: startedAt,
          dateFrom: startedAt,
          dateTo: startedAt,
          categoryId: 'vibe-coding',
        ),
      ),
    );

    final window = await reader.read(
      criteria: criterion,
      reference: startedAt,
    );

    expect(window.hasActiveCategoryTimer, isTrue);

    expect(window.categoryTimeDailyHours['coding-cap'], isEmpty);
    expect(window.categoryTimeSessionsByCategory, isEmpty);
  });

  test(
    'category session evidence spans goal lifetime without widening evaluation',
    () async {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'coding-today',
        categoryId: 'vibe-coding',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 2,
      );
      when(
        () => journalDb.insightsTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => [
          (
            entryId: 'old-session',
            dateFrom: DateTime(2026, 8),
            dateTo: DateTime(2026, 8, 1, 1),
            categoryId: 'vibe-coding',
          ),
          (
            entryId: 'current-session',
            dateFrom: DateTime(2026, 8, 8, 10),
            dateTo: DateTime(2026, 8, 8, 11, 30),
            categoryId: 'vibe-coding',
          ),
        ],
      );

      final window = await reader.read(
        criteria: criterion,
        reference: reference,
        timeEntryEvidenceStart: DateTime(2026, 8),
      );

      final captured = verify(
        () => journalDb.insightsTimeRows(
          start: captureAny(named: 'start'),
          end: any(named: 'end'),
        ),
      ).captured;
      expect(captured.single, DateTime(2026, 8));
      expect(
        window.categoryTimeSessionsByCategory['vibe-coding'],
        hasLength(2),
      );
      expect(window.categoryTimeEvidenceStart, DateTime(2026, 8));
      expect(
        window.categoryTimeDailyHours['coding-today'],
        {DateTime.utc(2026, 8, 8): 1.5},
        reason: 'historical pattern evidence must not alter the authored day',
      );
    },
  );

  test(
    'sleep duration uses the health pipeline minutes-to-hours semantics',
    () async {
      const sleep = GoalCriterion.metric(
        criterionId: 'sleep',
        dataType: 'HealthDataType.SLEEP_ASLEEP',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 7.5,
      );
      when(
        () => journalDb.getQuantitativeByType(
          type: 'HealthDataType.SLEEP_ASLEEP',
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
              value: 300,
              dataType: 'HealthDataType.SLEEP_ASLEEP',
              unit: 'min',
            ),
          ),
          JournalEntity.quantitative(
            meta: meta(DateTime(2026, 8, 8, 8)),
            data: QuantitativeData.discreteQuantityData(
              dateFrom: DateTime(2026, 8, 8, 8),
              dateTo: DateTime(2026, 8, 8, 8),
              value: 150,
              dataType: 'HealthDataType.SLEEP_ASLEEP',
              unit: 'min',
            ),
          ),
        ],
      );

      final window = await reader.read(criteria: sleep, reference: reference);

      expect(
        window.quantitativeDailySums['HealthDataType.SLEEP_ASLEEP'],
        {DateTime.utc(2026, 8, 8): 7.5},
      );
    },
  );

  test('cross-midnight category band clips each local day precisely', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'late-coding',
      categoryId: 'vibe-coding',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      targetHours: 0,
      dailyTimeRange: GoalDailyTimeRange(
        startMinute: 21 * 60 + 30,
        endMinute: 7 * 60,
      ),
    );
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'overnight',
          dateFrom: DateTime(2026, 8, 7, 20),
          dateTo: DateTime(2026, 8, 8, 8),
          categoryId: 'vibe-coding',
        ),
        (
          entryId: 'midday',
          dateFrom: DateTime(2026, 8, 8, 12),
          dateTo: DateTime(2026, 8, 8, 13),
          categoryId: 'vibe-coding',
        ),
      ],
    );

    final window = await reader.read(
      criteria: criterion,
      reference: reference,
    );

    expect(
      window.categoryTimeDailyHours['late-coding'],
      {
        DateTime.utc(2026, 8, 7): 2.5,
        DateTime.utc(2026, 8, 8): 7,
      },
    );
    final sessions =
        window.categoryTimeSessionsByCategory['vibe-coding'] ?? const [];
    expect(sessions, hasLength(2));
    expect(sessions.first.dateFrom, DateTime(2026, 8, 7, 20));
    expect(sessions.last.dateFrom, DateTime(2026, 8, 8, 12));
    expect(
      window.categoryTimeDailyHours['late-coding']![DateTime.utc(2026, 8, 8)],
      7,
      reason:
          'the model sees the midday session, but the curfew does not count it',
    );
  });

  test('a cutoff is half-open: time ending at 22:00 is allowed', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'after-ten',
      categoryId: 'screen-time',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 0,
      dailyTimeRange: GoalDailyTimeRange(
        startMinute: 22 * 60,
        endMinute: 0,
      ),
    );
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'allowed',
          dateFrom: DateTime(2026, 8, 8, 21),
          dateTo: DateTime(2026, 8, 8, 22),
          categoryId: 'screen-time',
        ),
        (
          entryId: 'prohibited',
          dateFrom: DateTime(2026, 8, 8, 22),
          dateTo: DateTime(2026, 8, 8, 22, 30),
          categoryId: 'screen-time',
        ),
      ],
    );

    final window = await reader.read(
      criteria: criterion,
      reference: DateTime(2026, 8, 8, 23),
    );

    expect(
      window.categoryTimeDailyHours['after-ten'],
      {DateTime.utc(2026, 8, 8): 0.5},
    );
  });

  test('a same-day UTC band clips tracked time to both endpoints', () async {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'workday-coding',
      categoryId: 'vibe-coding',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 8,
      dailyTimeRange: GoalDailyTimeRange(
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      ),
    );
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (
          entryId: 'workday',
          dateFrom: DateTime.utc(2026, 8, 8, 8),
          dateTo: DateTime.utc(2026, 8, 8, 18),
          categoryId: 'vibe-coding',
        ),
      ],
    );

    final window = await reader.read(
      criteria: criterion,
      reference: DateTime.utc(2026, 8, 8, 20),
    );

    expect(
      window.categoryTimeDailyHours['workday-coding'],
      {DateTime.utc(2026, 8, 8): 8},
      reason: 'only the authored 09:00–17:00 UTC band should count',
    );
  });

  test(
    'category time uses stale-only triggers for attribution changes',
    () {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'coding-cap',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 8,
      );

      const expected = {
        textEntryNotification,
        linkNotification,
        taskNotification,
        categoriesNotification,
        privateToggleNotification,
      };
      expect(goalImmediateSignalTriggerTokens(criterion), isEmpty);
      expect(goalStaleSignalTriggerTokens(criterion), expected);
    },
  );

  test('label time also invalidates on label assignment changes', () {
    const criterion = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );

    expect(goalImmediateSignalTriggerTokens(criterion), isEmpty);
    expect(goalStaleSignalTriggerTokens(criterion), {
      textEntryNotification,
      linkNotification,
      taskNotification,
      categoriesNotification,
      labelUsageNotification,
      labelsNotification,
      privateToggleNotification,
    });
  });

  test('bounded observations stay on the immediate trigger path', () {
    const criterion = GoalCriterion.allOf(
      criterionId: 'bounded',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'walk',
          habitId: 'walk-habit',
          window: GoalWindow.day(),
          targetCount: 1,
        ),
        GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'HealthDataType.STEPS',
          window: GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          target: 10000,
        ),
      ],
    );

    expect(
      goalImmediateSignalTriggerTokens(criterion),
      {'walk-habit', 'HealthDataType.STEPS'},
    );
    expect(goalStaleSignalTriggerTokens(criterion), isEmpty);
  });

  test('supported health samples evaluate immediately and dirty exact report '
      'evidence', () {
    const criterion = GoalCriterion.metric(
      criterionId: 'weight',
      dataType: GoalHealthDataTypes.weight,
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 88,
      direction: GoalDirection.atMost,
    );

    expect(
      goalImmediateSignalTriggerTokens(criterion),
      {GoalHealthDataTypes.weight},
    );
    expect(
      goalStaleSignalTriggerTokens(criterion),
      {GoalHealthDataTypes.weight},
    );
  });
}
