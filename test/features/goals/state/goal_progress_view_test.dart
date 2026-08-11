import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final today = DateTime(2026, 8, 11);
  DateTime day(int offset) => GoalWindow.dayUtc(
    today.subtract(Duration(days: offset)),
  );

  test('habit projection keeps the slipped day, active window, deficit and '
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
    expect(habit.days, hasLength(8));
    expect(habit.days.first.day, day(7), reason: 'slipped day stays visible');
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
    expect(view.compactWindow, [true, false, false, false, true, false, false]);
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

  test('alternative composite shapes collect their visible leaves and ignore '
      'unsupported measurable presentation', () {
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
      signals: const GoalSignalWindow(),
      reference: today,
    );

    expect(view.habits.single.name, 'walk-id');
    expect(view.metric?.name, 'steps');
    expect(view.metric?.days, hasLength(7));
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
    expect(view?.habits.single.days, hasLength(8));
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
