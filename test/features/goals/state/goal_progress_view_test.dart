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
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
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

  test('without an evaluator figure, successesInWindow folds only the days '
      'inside the authored window — never the rendered history', () {
    final view = GoalHabitProgressView(
      habitId: 'gym',
      name: 'Gym',
      targetCount: 2,
      successfulWeeks: null,
      days: [
        for (var offset = 13; offset >= 0; offset--)
          GoalProgressDay(
            day: day(offset),
            // Successes at 12, 8 (history) and 5, 1 (in-window).
            value: offset == 12 || offset == 8 || offset == 5 || offset == 1
                ? 1
                : 0,
          ),
      ],
    );
    expect(view.successesInWindow, 2);
    expect(view.deficit, 0);
  });

  test('a shared history span extends every day track backwards without '
      'touching the window maths — and the ages-out ring stays anchored at '
      'the WINDOW, not the list head', () {
    final successes = <DateTime, int>{
      // Exactly at target inside the rolling week, with the oldest
      // in-window success sitting on the window\'s first day.
      day(6): 1,
      day(2): 1,
      // History beyond the window, visible only through the span.
      day(20): 1,
    };
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'gym-id',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 10000,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {'gym-id': successes},
        quantitativeDailySums: {
          'cumulative_step_count': {day(0): 12000, day(25): 8000},
        },
      ),
      reference: today,
      habitNames: const {'gym-id': 'Gym'},
      historyDays: 30,
    );

    final habit = view.habits.single;
    // 30 rendered days ending today, oldest first.
    expect(habit.days, hasLength(30));
    expect(habit.days.first.day, day(29));
    expect(habit.days.last.day, day(0));
    // The 20-days-ago success renders in the history…
    expect(
      habit.days.firstWhere((entry) => entry.day == day(20)).value,
      1,
    );
    // …but the WINDOW maths are untouched: two in-window successes, no
    // deficit, and the ages-out ring anchors at the window\'s first day
    // (day 6), not at the 30-day list head.
    expect(habit.successesInWindow, 2);
    expect(habit.deficit, 0);
    expect(habit.oldestSuccessAgesOutTonight, isTrue);

    final metric = view.metrics.single;
    expect(metric.days, hasLength(30));
    expect(metric.days.first.day, day(29));
    expect(
      metric.days.firstWhere((entry) => entry.day == day(25)).value,
      8000,
    );

    // The whole-goal strip follows the shared span too, so the hero card
    // renders the same days as every other track.
    expect(view.compositeCompactWindow, hasLength(30));
  });

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
    expect(view.compactWindow, [
      GoalCompactDayState.full,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      // Completed today, but only three of four successes in the window:
      // a partial success, not a full one.
      GoalCompactDayState.partial,
    ]);
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
    // Per-day policy: the 7,999 day is not full even though the rolling
    // average of the observed days clears 8,000 — a strip cell is a
    // statement about that day's own number.
    expect(view.compactWindow, [
      GoalCompactDayState.full,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
    ]);
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
    expect(
      view.compactWindow.take(5),
      everyElement(GoalCompactDayState.none),
    );
    expect(view.compactWindow.last, GoalCompactDayState.none);
    expect(view.compactWindow[5], GoalCompactDayState.none);
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
      [
        GoalCompactDayState.full,
        GoalCompactDayState.full,
        GoalCompactDayState.full,
        GoalCompactDayState.full,
        GoalCompactDayState.full,
        GoalCompactDayState.none,
        GoalCompactDayState.none,
      ],
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

  test('label time projects daily hours across its stable label id', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.labelTime(
        criterionId: 'daily-content',
        labelId: 'content',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1,
      ),
      signals: GoalSignalWindow(
        labelTimeDailyHours: {
          'daily-content': {today: 0.75},
        },
      ),
      reference: today,
      labelNames: const {'content': 'Content'},
    );

    expect(view.metric?.kind, GoalDimensionKind.labelTime);
    expect(view.metric?.name, 'Content');
    expect(view.metric?.target, 1);
    expect(view.metric?.days.single.value, 0.75);
    expect(view.metric?.days.single.isObserved, isTrue);
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
    expect(sum.compactWindow, [
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
    ]);
    expect(count.metric?.aggregation, GoalAggregation.count);
    expect(count.compactWindow, [
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
    ]);
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
    expect(dayView.compactWindow, [GoalCompactDayState.full]);
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
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
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
    // Completed via the habit leaf while no leaf's window target held yet:
    // the accomplishment shows as a partial success.
    expect(view.compactWindow[5], GoalCompactDayState.partial);
    expect(view.compactWindow.last, GoalCompactDayState.full);
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

    expect(view.compactWindow[5], GoalCompactDayState.partial);
    expect(view.compactWindow.last, GoalCompactDayState.none);
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

    expect(view.compactWindow.last, GoalCompactDayState.full);
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

    expect(view.compactWindow[5], GoalCompactDayState.none);
    expect(view.compactWindow.last, GoalCompactDayState.full);
  });

  test('habit days carry the as-of-day window verdict so completed days can '
      'render as partial successes', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk-id': {day(5): 1, day(0): 1},
        },
      ),
      reference: today,
    );

    final days = view.habits.single.days;
    // Window ending day(5) holds one success — completed but short of the
    // two-per-window target.
    expect(days[1].hasValue, isTrue);
    expect(days[1].targetSatisfied, isFalse);
    // Window ending today holds both successes — the target is met.
    expect(days.last.hasValue, isTrue);
    expect(days.last.targetSatisfied, isTrue);
    // An empty day still carries the window verdict without a completion.
    expect(days[3].hasValue, isFalse);
    expect(days[3].targetSatisfied, isFalse);
  });

  test('a matching health observation recorded today suggests checking off '
      'the still-blank habit', () {
    GoalProgressView build({
      Map<DateTime, int> habitDays = const {},
      Map<DateTime, num>? systolicDays,
      String habitTitle = 'Measure Blood Pressure',
    }) => buildGoalProgressView(
      criteria: GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'measure',
            habitId: 'measure-id',
            window: const GoalWindow.rollingDays(count: 7),
            targetCount: 5,
            title: habitTitle,
          ),
          const GoalCriterion.metric(
            criterionId: 'systolic',
            dataType: GoalHealthDataTypes.bloodPressureSystolic,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 125,
            direction: GoalDirection.atMost,
            title: 'Systolic blood pressure',
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {'measure-id': habitDays},
        quantitativeDailySums: {
          GoalHealthDataTypes.bloodPressureSystolic:
              systolicDays ?? {day(0): 127},
        },
      ),
      reference: today,
    );

    // Data recorded today + blank habit day + shared "blood pressure"
    // tokens: the card should offer the one-tap check-off.
    expect(
      build().habits.single.suggestedFromDimensionName,
      'Systolic blood pressure',
    );
    // Already completed today: nothing to suggest.
    expect(
      build(habitDays: {day(0): 1}).habits.single.suggestedFromDimensionName,
      isNull,
    );
    // No observation today: no evidence to suggest from.
    expect(
      build(
        systolicDays: {day(1): 127},
      ).habits.single.suggestedFromDimensionName,
      isNull,
    );
    // No distinctive word overlap ("BP" is not "blood pressure"): the
    // medication habit must not be suggested by a measurement.
    expect(
      build(habitTitle: 'BP meds').habits.single.suggestedFromDimensionName,
      isNull,
    );
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
  test('a day inside its ceiling is met, whatever the rolling average did', () {
    final day = DateTime.utc(2026, 8, 14);
    final systolic = GoalMetricProgressView(
      name: 'Systolic',
      target: 125,
      direction: GoalDirection.atMost,
      days: [
        // The evaluator's verdict for the WINDOW ending here is a miss: the
        // rolling average is still over the ceiling.
        GoalProgressDay(day: day, value: 122, targetSatisfied: false),
      ],
    );

    // The window verdict and the day's own value disagree, and each has its
    // own reader. The reflection sheet prints "122" beside a mark, so the
    // mark has to be about 122 — it used to print the number and cross it
    // out, contradicting the report one card above.
    expect(systolic.meetsTarget(systolic.days.single), isFalse);
    expect(systolic.valueMeetsTarget(systolic.days.single), isTrue);
  });

  test(
    'a calendar-window day verdict is as of that day, never retroactive',
    () {
      // Sum criterion over the calendar week: 6 hours on Monday, 6 on Tuesday,
      // 12-hour weekly target reached only on Tuesday. Monday's verdict must
      // be the running total AS OF Monday — evaluating the unclipped window
      // let Tuesday's hours repaint Monday retroactively, so reopening
      // Monday's reflection after the total landed suggested Met for a day
      // that had not met anything yet.
      final view = buildGoalProgressView(
        criteria: const GoalCriterion.metric(
          criterionId: 'deep-work',
          dataType: 'deep-work',
          window: GoalWindow.calendarWeek(),
          aggregation: GoalAggregation.sum,
          target: 12,
        ),
        signals: GoalSignalWindow(
          quantitativeDailySums: {
            'deep-work': {day(1): 6, day(0): 6},
          },
        ),
        reference: today,
      );

      final metric = view.metric!;
      final monday = metric.days.singleWhere((entry) => entry.day == day(1));
      final tuesday = metric.days.singleWhere((entry) => entry.day == day(0));
      expect(metric.meetsTarget(monday), isFalse);
      expect(metric.dayMark(monday), isFalse);
      expect(metric.meetsTarget(tuesday), isTrue);
      expect(metric.dayMark(tuesday), isTrue);
    },
  );

  test('the evaluator-supplied habit count outranks the view-side fold', () {
    // Three creditable days in the visible window, but the evaluator said
    // five (its window need not equal the visible one). The card must quote
    // the evaluator — the same number the agent's FACTS carry — or the two
    // can drift apart the way the metric headline once did.
    final habit = GoalHabitProgressView(
      habitId: 'walk-id',
      name: 'Walk',
      targetCount: 6,
      successfulWeeks: null,
      evaluatedSuccesses: 5,
      days: [
        for (var offset = 6; offset >= 0; offset--)
          GoalProgressDay(
            day: DateTime.utc(2026, 8, 11).subtract(Duration(days: offset)),
            value: offset.isEven && offset > 0 ? 1 : 0,
          ),
      ],
    );
    expect(habit.successesInWindow, 5);
    expect(habit.deficit, 1);
  });

  test('dayMark uses the day value for per-day targets and the window '
      'verdict for period totals', () {
    final perDay = GoalMetricProgressView(
      name: 'Steps',
      target: 10000,
      days: [
        GoalProgressDay(
          day: DateTime.utc(2026, 8, 10),
          value: 12400,
          targetSatisfied: false,
        ),
      ],
    );
    expect(perDay.dayMark(perDay.days.single), isTrue);
    expect(perDay.targetIsPerDay, isTrue);

    final periodTotal = GoalMetricProgressView(
      name: 'Deep work',
      target: 12,
      aggregation: GoalAggregation.sum,
      days: [
        // Two hours toward a twelve-hour week: the day's own value cannot be
        // judged against the period total, so the evaluator's verdict for
        // the window ending that day decides the mark.
        GoalProgressDay(
          day: DateTime.utc(2026, 8, 10),
          value: 2,
          targetSatisfied: true,
        ),
      ],
    );
    expect(periodTotal.targetIsPerDay, isFalse);
    expect(periodTotal.dayMark(periodTotal.days.single), isTrue);
    expect(periodTotal.valueMeetsTarget(periodTotal.days.single), isFalse);
  });

  test('provider resolves measurable and category definitions and folds '
      'recorded capture decisions into agent-recorded provenance', () async {
    final reference = DateTime(2026, 8, 11, 14);
    final db = MockJournalDb();
    when(
      () => db.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [
        // The entry the recorded capture decision points at — the reader
        // maps its id to a day, which is what turns a decision into
        // agent-recorded provenance on that day's bar.
        buildMeasurementEntry(
          id: 'entry-1',
          timestamp: DateTime(2026, 8, 10, 9),
          value: 500,
        ),
      ],
    );
    when(
      () => db.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => []);
    when(() => db.getConfigFlag(any())).thenAnswer((_) async => false);
    when(
      () => db.getMeasurableDataTypeById(measurableWater.id),
    ).thenAnswer((_) async => measurableWater);
    when(
      () => db.getCategoryById(categoryMindfulness.id),
    ).thenAnswer((_) async => categoryMindfulness);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Hydrate mindfully',
              statement: 'Water and quiet time.',
              criteria: GoalCriterion.allOf(
                criterionId: 'root',
                criteria: [
                  GoalCriterion.measurable(
                    criterionId: 'water',
                    dataTypeId: measurableWater.id,
                    window: const GoalWindow.rollingDays(count: 7),
                    aggregation: GoalAggregation.dailySumThenAverage,
                    target: 2000,
                  ),
                  GoalCriterion.categoryTime(
                    criterionId: 'calm',
                    categoryId: categoryMindfulness.id,
                    window: const GoalWindow.rollingDays(count: 7),
                    aggregation: GoalAggregation.sum,
                    targetHours: 2,
                    direction: GoalDirection.atLeast,
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
        goalMeasurableCaptureDecisionsProvider('goal-1').overrideWith(
          (ref) async => {
            'msg-1': GoalMeasurableCaptureDecision(
              sourceMessageId: 'msg-1',
              recorded: true,
              entryCount: 1,
              entryIds: const ['entry-1'],
              agentName: 'Hydrate mindfully',
              recordedAt: DateTime(2026, 8, 10),
            ),
            // Not recorded: contributes to neither set.
            const GoalMeasurableCaptureDecision(
              sourceMessageId: 'msg-2',
              recorded: false,
              entryCount: 0,
            ).sourceMessageId: const GoalMeasurableCaptureDecision(
              sourceMessageId: 'msg-2',
              recorded: false,
              entryCount: 0,
            ),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final view = await withClock(
      Clock.fixed(reference),
      () => container.read(goalAgentProgressViewProvider('goal-1').future),
    );

    // The measurable resolved its definition (name + unit), the category
    // resolved its display name.
    final names = {for (final metric in view!.metrics) metric.name};
    expect(names, contains(measurableWater.displayName));
    expect(names, contains(categoryMindfulness.name));
    verify(() => db.getMeasurableDataTypeById(measurableWater.id)).called(1);
    verify(() => db.getCategoryById(categoryMindfulness.id)).called(1);

    // The RECORDED decision's entry flows into agent-recorded provenance on
    // its day; the unrecorded msg-2 contributes nothing — so exactly one
    // day is marked, carrying the recording agent's name.
    final water = view.metrics.singleWhere(
      (metric) => metric.name == measurableWater.displayName,
    );
    final recordedDay = DateTime.utc(2026, 8, 10);
    expect(water.agentRecordedDays, {recordedDay});
    expect(
      water.agentRecordedProvenanceByDay[recordedDay]?.agentName,
      'Hydrate mindfully',
    );
  });
}
