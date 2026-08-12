import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final today = DateTime.utc(2026, 8, 11);
  DateTime day(int offset) => GoalWindow.dayUtc(
    today.subtract(Duration(days: offset)),
  );

  test('habit projection separates the slipped day, active window, deficit and '
      'six-week reliability on the evaluator signal source', () {
    final successes = <DateTime, int>{
      day(7): 1,
      day(6): 1,
      day(3): 1,
      day(0): 1,
      for (final offset in [8, 10, 12, 13, 15, 17, 19, 20, 22, 24, 26])
        day(offset): 1,
    };
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 4,
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {'gym-id': successes},
      ),
      reference: today,
      habitNames: const {'gym-id': 'Gym'},
    );

    final habit = view.habits.single;
    expect(habit.name, 'Gym');
    expect(habit.days, hasLength(7));
    expect(habit.days.first.day, day(6));
    expect(habit.slippedDay?.day, day(7));
    expect(habit.successesInWindow, 3);
    expect(habit.deficit, 1);
    expect(habit.oldestSuccessAgesOutTonight, isFalse);
    expect(habit.successfulWeeks, 2);
    expect(view.compactWindow, [true, false, false, true, false, false, true]);
  });

  test('an at-rate habit marks the oldest active success as aging out', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
        title: 'Walk',
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk-id': {day(6): 1, day(0): 1},
        },
      ),
      reference: today,
    );

    final habit = view.habits.single;
    expect(habit.deficit, 0);
    expect(habit.oldestSuccessAgesOutTonight, isTrue);
  });

  test('a surplus success does not warn when the oldest success ages out', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk-id': {day(6): 1, day(3): 1, day(0): 1},
        },
      ),
      reference: today,
    );

    final habit = view.habits.single;
    expect(habit.successesInWindow, 3);
    expect(habit.oldestSuccessAgesOutTonight, isFalse);
  });

  test('metric projection supplies seven values and target-clearing compact '
      'days', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'steps',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 8000,
        title: 'Daily steps',
      ),
      signals: GoalSignalWindow(
        quantitativeDailySums: {
          'steps': {day(6): 9000, day(2): 8000, day(0): 7999},
        },
      ),
      reference: today,
    );

    expect(view.metric?.days, hasLength(7));
    expect(view.metric?.aggregation, GoalAggregation.dailySumThenAverage);
    expect(view.compactWindow, [true, false, false, false, true, false, true]);
  });

  test('an at-most metric marks values at or below its ceiling', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'screen-time',
        dataType: 'screen-time',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        target: 60,
        direction: GoalDirection.atMost,
      ),
      signals: GoalSignalWindow(
        quantitativeDailySums: {
          'screen-time': {day(1): 61, day(0): 60},
        },
      ),
      reference: today,
    );

    expect(view.metric?.direction, GoalDirection.atMost);
    expect(view.compactWindow.take(5), everyElement(isFalse));
    expect(view.compactWindow.last, isFalse);
    expect(view.compactWindow[5], isFalse);
  });

  test('a health metric with a bounded improving trend is on track', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'weight',
        dataType: 'HealthDataType.WEIGHT',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 80,
        direction: GoalDirection.atMost,
        title: 'Weight',
      ),
      signals: GoalSignalWindow(
        quantitativeDailySums: {
          'HealthDataType.WEIGHT': {
            day(6): 88,
            day(5): 87.5,
            day(4): 87,
            day(3): 86.5,
            day(2): 86,
            day(1): 85.5,
            day(0): 85,
          },
        },
      ),
      reference: today,
    );

    expect(view.rootOnTrack, isTrue);
    expect(view.metric?.projectedOnTrack, isTrue);
    expect(view.metric?.days.last.value, 85);
    expect(view.metric?.unitName, 'kg');
  });

  test('blood-pressure health metrics keep mmHg in projection', () {
    for (final dataType in [
      GoalHealthDataTypes.bloodPressureSystolic,
      GoalHealthDataTypes.bloodPressureDiastolic,
    ]) {
      final view = buildGoalProgressView(
        criteria: GoalCriterion.metric(
          criterionId: dataType,
          dataType: dataType,
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 120,
          direction: GoalDirection.atMost,
        ),
        signals: GoalSignalWindow(
          quantitativeDailySums: {
            dataType: {day(0): 120},
          },
        ),
        reference: today,
      );

      expect(view.metric?.sourceId, dataType);
      expect(view.metric?.unitName, 'mmHg', reason: dataType);
    }
  });

  test('category time projects tracked hours and treats an empty elapsed day '
      'as an observed zero', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 0,
        title: 'Late vibe coding',
      ),
      signals: GoalSignalWindow(
        categoryTimeDailyHours: {
          'late-coding': {day(1): 0.75},
        },
      ),
      reference: today,
    );

    final metric = view.metric!;
    expect(metric.name, 'Late vibe coding');
    expect(metric.target, 0);
    expect(metric.direction, GoalDirection.atMost);
    expect(metric.days[5].value, 0.75);
    expect(metric.days[5].isObserved, isTrue);
    expect(metric.days.last.value, 0);
    expect(metric.days.last.isObserved, isTrue);
    expect(
      view.compactWindow,
      [true, true, true, true, true, false, false],
      reason: 'a late session keeps the rolling at-most-zero window failed',
    );
  });

  test('category time falls back to its category identifier when untitled', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.categoryTime(
        criterionId: 'coding-cap',
        categoryId: 'vibe-coding',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 2,
      ),
      signals: const GoalSignalWindow(),
      reference: today,
    );

    expect(view.metric?.name, 'vibe-coding');
  });

  test('sum and count metrics compare the aggregated rolling period', () {
    GoalProgressView build(GoalAggregation aggregation) =>
        buildGoalProgressView(
          criteria: GoalCriterion.metric(
            criterionId: 'sessions',
            dataType: 'sessions',
            window: const GoalWindow.rollingDays(count: 5),
            aggregation: aggregation,
            target: 5,
          ),
          signals: GoalSignalWindow(
            quantitativeDailySums: {
              'sessions': {
                for (var offset = 4; offset >= 0; offset--) day(offset): 1,
              },
            },
          ),
          reference: today,
        );

    final sum = build(GoalAggregation.sum);
    final count = build(GoalAggregation.count);

    expect(sum.metric?.aggregation, GoalAggregation.sum);
    expect(sum.compactWindow, [false, false, false, false, true]);
    expect(count.metric?.aggregation, GoalAggregation.count);
    expect(count.compactWindow, [false, false, false, false, true]);
  });

  test(
    'habit projection follows day, calendar-month and rolling-N windows',
    () {
      GoalHabitProgressView project(GoalWindow window) => buildGoalProgressView(
        criteria: GoalCriterion.habit(
          criterionId: 'walk',
          habitId: 'walk',
          window: window,
          targetCount: 1,
        ),
        signals: const GoalSignalWindow(),
        reference: today,
      ).habits.single;

      final daily = project(const GoalWindow.day());
      final month = project(const GoalWindow.calendarMonth());
      final rolling = project(const GoalWindow.rollingDays(count: 10));

      expect(daily.days, hasLength(1));
      expect(daily.slippedDay, isNull);
      expect(month.days, hasLength(31));
      expect(month.days.first.day, DateTime.utc(2026, 8));
      expect(month.slippedDay, isNull);
      expect(month.successfulWeeks, isNull);
      expect(rolling.days, hasLength(10));
      expect(rolling.days.first.day, day(9));
      expect(rolling.slippedDay?.day, day(10));
    },
  );

  test('metric projection follows the criterion day and calendar-month '
      'windows instead of forcing seven days', () {
    final dayView = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'steps',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        target: 8000,
      ),
      signals: GoalSignalWindow(
        quantitativeDailySums: {
          'steps': {day(0): 9000},
        },
      ),
      reference: today,
    );
    final monthView = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'steps',
        window: GoalWindow.calendarMonth(),
        aggregation: GoalAggregation.sum,
        target: 8000,
      ),
      signals: const GoalSignalWindow(),
      reference: today,
    );

    expect(dayView.metric?.days, hasLength(1));
    expect(dayView.metric?.window, const GoalWindow.day());
    expect(dayView.compactWindow, [true]);
    expect(monthView.metric?.days, hasLength(31));
    expect(monthView.metric?.days.first.day, DateTime.utc(2026, 8));
    expect(monthView.metric?.days.last.day, DateTime.utc(2026, 8, 31));
    expect(monthView.metric?.window, const GoalWindow.calendarMonth());
    expect(
      monthView.compactWindow,
      hasLength(7),
      reason: 'the list-row summary is capped to the latest seven days',
    );
  });

  test('composite compact strip requires every watched habit on that day', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'a',
            habitId: 'a',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
          GoalCriterion.habit(
            criterionId: 'b',
            habitId: 'b',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'a': {day(1): 1, day(0): 1},
          'b': {day(0): 1},
        },
      ),
      reference: today,
    );

    expect(view.compactWindow, [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ]);
  });

  test('alternative composite shapes preserve habit, metric, and measurable '
      'leaves', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.anyOf(
        criterionId: 'options',
        criteria: [
          GoalCriterion.atLeastCount(
            criterionId: 'pick-one',
            successes: 1,
            criteria: [
              GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk-id',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 2,
              ),
              GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'steps',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 8000,
              ),
            ],
          ),
          GoalCriterion.measurable(
            criterionId: 'weight',
            dataTypeId: 'weight-id',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.sum,
            target: 80,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk-id': {day(1): 1},
        },
        quantitativeDailySums: {
          'steps': {day(0): 9000},
        },
        measurableDailySums: {
          'weight-id': {day(0): 81},
        },
      ),
      reference: today,
    );

    expect(view.habits.single.name, 'walk-id');
    expect(view.metric?.name, 'steps');
    expect(view.metric?.days, hasLength(7));
    expect(view.metrics.map((metric) => metric.name), ['steps', 'weight-id']);
    expect(view.metrics.last.days.last.value, 81);
    expect(view.compactWindow[5], isTrue);
    expect(view.compactWindow.last, isTrue);
  });

  test('composite strip rewards a fully completed day independently of the '
      'rolling quota', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'walk',
            habitId: 'walk',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
          GoalCriterion.habit(
            criterionId: 'stretch',
            habitId: 'stretch',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk': {day(2): 1, day(1): 1},
          'stretch': {day(3): 1, day(1): 1},
        },
      ),
      reference: today,
    );

    expect(view.compactWindow[5], isTrue);
    expect(view.compactWindow.last, isFalse);
  });

  test('composite strip stays green when the rolling quota is met', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'walk',
            habitId: 'walk',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.habit(
            criterionId: 'stretch',
            habitId: 'stretch',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk': {day(2): 1, day(1): 1},
          'stretch': {day(3): 1, day(1): 1},
        },
      ),
      reference: today,
    );

    expect(view.compactWindow.last, isTrue);
  });

  test('composite progress preserves every metric leaf', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'metrics',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'steps',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.sum,
            target: 50000,
            title: 'Steps',
          ),
          GoalCriterion.metric(
            criterionId: 'sleep',
            dataType: 'sleep',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 8,
            title: 'Sleep',
          ),
        ],
      ),
      signals: const GoalSignalWindow(),
      reference: today,
    );

    expect(view.metrics.map((metric) => metric.name), ['Steps', 'Sleep']);
    expect(view.metrics.map((metric) => metric.aggregation), [
      GoalAggregation.sum,
      GoalAggregation.dailySumThenAverage,
    ]);
  });

  test('at-least-count requires the configured number of daily children', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.atLeastCount(
        criterionId: 'two-of-three',
        successes: 2,
        criteria: [
          GoalCriterion.habit(
            criterionId: 'a',
            habitId: 'a',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
          GoalCriterion.habit(
            criterionId: 'b',
            habitId: 'b',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
          GoalCriterion.habit(
            criterionId: 'c',
            habitId: 'c',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'a': {day(1): 1, day(0): 1},
          'b': {day(0): 1},
        },
      ),
      reference: today,
    );

    expect(view.compactWindow[5], isFalse);
    expect(view.compactWindow.last, isTrue);
  });

  test('provider reads the active spec, resolves habit names and preserves the '
      'fixed evaluation date', () async {
    final reference = DateTime(2026, 8, 11, 14);
    final db = MockJournalDb();
    when(
      () => db.getHabitCompletionsByHabitId(
        habitId: any(named: 'habitId'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => db.getHabitById(habitFlossing.id),
    ).thenAnswer((_) async => habitFlossing);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Floss consistently',
              statement: 'Floss twice each rolling week.',
              criteria: GoalCriterion.anyOf(
                criterionId: 'either',
                criteria: [
                  GoalCriterion.atLeastCount(
                    criterionId: 'one-of-one',
                    successes: 1,
                    criteria: [
                      GoalCriterion.allOf(
                        criterionId: 'routine',
                        criteria: [
                          GoalCriterion.habit(
                            criterionId: 'floss',
                            habitId: habitFlossing.id,
                            window: const GoalWindow.rollingDays(count: 7),
                            targetCount: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(db),
        goalAgentHealthProvider('goal-1').overrideWith(
          (ref) async => (
            trackStatus: GoalTrackStatus.onTrack,
            attainment: 1.0,
            reportOneLiner: null,
            pendingProposals: 0,
            spec: spec,
            direction: null,
            deficit: 0,
            buffer: 1,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final view = await withClock(
      Clock.fixed(reference),
      () => container.read(goalAgentProgressViewProvider('goal-1').future),
    );

    expect(view?.today, DateTime.utc(2026, 8, 11));
    expect(view?.habits.single.name, habitFlossing.name);
    expect(view?.habits.single.days, hasLength(7));
    verify(() => db.getHabitById(habitFlossing.id)).called(1);
  });

  test(
    'provider returns no presentation when the goal has no active spec',
    () async {
      final container = ProviderContainer(
        overrides: [
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: null,
              attainment: null,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(goalAgentProgressViewProvider('goal-1').future),
        isNull,
      );
    },
  );
}
