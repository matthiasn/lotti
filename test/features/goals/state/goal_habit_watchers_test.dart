import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_habit_watchers.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

void main() {
  const window = GoalWindow.rollingDays(count: 7);
  const flossing = GoalCriterion.habit(
    criterionId: 'c-floss',
    habitId: 'floss',
    window: window,
    targetCount: 4,
  );
  const walking = GoalCriterion.habit(
    criterionId: 'c-walk',
    habitId: 'walk',
    window: window,
    targetCount: 3,
  );
  const steps = GoalCriterion.metric(
    criterionId: 'c-steps',
    dataType: 'steps',
    window: window,
    target: 10000,
    aggregation: GoalAggregation.sum,
  );

  AgentIdentityEntity identity(String id) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: AgentKinds.goalAgent,
            displayName: id,
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$id:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  GoalSpecVersionEntity spec(String agentId, GoalCriterion criteria) =>
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Goal $agentId',
            statement: '',
            criteria: criteria,
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalAgentHealth health(GoalSpecVersionEntity? spec) => (
    trackStatus: null,
    attainment: null,
    reportOneLiner: null,
    pendingProposals: 0,
    spec: spec,
    direction: null,
    deficit: null,
    buffer: null,
  );

  GoalAssessmentRecord record({
    required String id,
    required String specVersionId,
    required DateTime day,
    required DateTime createdAt,
    Map<String, DayVerdict> dimensions = const {},
  }) => GoalAssessmentRecord(
    id: id,
    day: day,
    specVersionId: specVersionId,
    rating: DayVerdict.mixed,
    createdAt: createdAt,
    provenance: DayVerdictProvenance.ratedByUser,
    dimensionRatings: dimensions,
  );

  ProviderContainer container({
    required List<AgentIdentityEntity> agents,
    required Map<String, GoalSpecVersionEntity?> specs,
    Map<String, List<GoalAssessmentRecord>> history = const {},
  }) {
    final c = ProviderContainer(
      overrides: [
        activeGoalAgentsProvider.overrideWith((ref) async => agents),
        for (final entry in specs.entries)
          goalAgentHealthProvider(
            entry.key,
          ).overrideWith((ref) async => health(entry.value)),
        for (final id in specs.keys)
          goalAssessmentHistoryProvider(
            id,
          ).overrideWith((ref) async => history[id] ?? const []),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('goalCriterionIdForHabit', () {
    test('finds the habit anywhere in a composite tree', () {
      const tree = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          steps,
          GoalCriterion.anyOf(
            criterionId: 'any',
            criteria: [walking, flossing],
          ),
        ],
      );
      expect(goalCriterionIdForHabit(tree, 'floss'), 'c-floss');
      expect(goalCriterionIdForHabit(tree, 'walk'), 'c-walk');
      expect(goalCriterionIdForHabit(tree, 'swim'), isNull);
      expect(goalCriterionIdForHabit(steps, 'floss'), isNull);
    });

    test('no leaf but a habit leaf can name a habit', () {
      const leaves = [
        steps,
        GoalCriterion.measurable(
          criterionId: 'm',
          dataTypeId: 'water',
          window: window,
          aggregation: GoalAggregation.sum,
          target: 2000,
        ),
        GoalCriterion.categoryTime(
          criterionId: 'ct',
          categoryId: 'work',
          window: window,
          aggregation: GoalAggregation.sum,
          targetHours: 8,
        ),
        GoalCriterion.labelTime(
          criterionId: 'lt',
          labelId: 'deep',
          window: window,
          aggregation: GoalAggregation.sum,
          targetHours: 2,
        ),
      ];
      for (final leaf in leaves) {
        expect(goalCriterionIdForHabit(leaf, 'floss'), isNull, reason: '$leaf');
      }
    });
  });

  group('goalsWatchingHabitProvider', () {
    test(
      'lists the active goals naming the habit, with their criterion',
      () async {
        final c = container(
          agents: [identity('g1'), identity('g2'), identity('g3')],
          specs: {
            'g1': spec('g1', flossing),
            'g2': spec('g2', walking),
            'g3': spec(
              'g3',
              const GoalCriterion.allOf(
                criterionId: 'root',
                criteria: [steps, flossing],
              ),
            ),
          },
        );
        final watchers = await c.read(
          goalsWatchingHabitProvider('floss').future,
        );
        expect(watchers.map((w) => w.identity.agentId), ['g1', 'g3']);
        expect(watchers.map((w) => w.criterionId), ['c-floss', 'c-floss']);
        expect(watchers.first.spec.id, 'g1:spec');
      },
    );

    test('a goal without a live spec is skipped, not an error', () async {
      final c = container(
        agents: [identity('g1'), identity('g2')],
        specs: {'g1': null, 'g2': spec('g2', flossing)},
      );
      final watchers = await c.read(goalsWatchingHabitProvider('floss').future);
      expect(watchers.map((w) => w.identity.agentId), ['g2']);
    });
  });

  group('habitDayVerdictsProvider', () {
    final day = DateTime.utc(2026, 8, 10);

    test('a habit no goal watches has no verdicts', () async {
      final c = container(
        agents: [identity('g1')],
        specs: {'g1': spec('g1', walking)},
      );
      expect(await c.read(habitDayVerdictsProvider('floss').future), isEmpty);
    });

    test('reads the habit dimension out of the latest record per day, '
        'scoped to the spec in force', () async {
      final c = container(
        agents: [identity('g1')],
        specs: {'g1': spec('g1', flossing)},
        history: {
          'g1': [
            record(
              id: 'old',
              specVersionId: 'g1:spec',
              day: day,
              createdAt: DateTime(2026, 8, 10, 20),
              dimensions: {'c-floss': DayVerdict.missed},
            ),
            record(
              id: 'revised',
              specVersionId: 'g1:spec',
              day: day,
              createdAt: DateTime(2026, 8, 10, 21),
              dimensions: {'c-floss': DayVerdict.improving},
            ),
            record(
              id: 'retired-spec',
              specVersionId: 'g1:spec-v0',
              day: day.subtract(const Duration(days: 1)),
              createdAt: DateTime(2026, 8, 9, 21),
              dimensions: {'c-floss': DayVerdict.met},
            ),
            record(
              id: 'untouched-row',
              specVersionId: 'g1:spec',
              day: day.subtract(const Duration(days: 2)),
              createdAt: DateTime(2026, 8, 8, 21),
            ),
          ],
        },
      );
      expect(await c.read(habitDayVerdictsProvider('floss').future), {
        day: DayVerdict.improving,
      });
    });

    test('equal timestamps across goals break by record id, whichever goal '
        'is iterated first', () async {
      for (final order in [
        ['g1', 'g2'],
        ['g2', 'g1'],
      ]) {
        final c = container(
          agents: [for (final id in order) identity(id)],
          specs: {'g1': spec('g1', flossing), 'g2': spec('g2', flossing)},
          history: {
            'g1': [
              record(
                id: 'a-lower',
                specVersionId: 'g1:spec',
                day: day,
                createdAt: DateTime(2026, 8, 10, 21),
                dimensions: {'c-floss': DayVerdict.missed},
              ),
            ],
            'g2': [
              record(
                id: 'b-higher',
                specVersionId: 'g2:spec',
                day: day,
                createdAt: DateTime(2026, 8, 10, 21),
                dimensions: {'c-floss': DayVerdict.met},
              ),
            ],
          },
        );
        expect(
          await c.read(habitDayVerdictsProvider('floss').future),
          {day: DayVerdict.met},
          reason: 'order $order',
        );
      }
    });

    test(
      'across two watching goals the most recent judgement of a day wins',
      () async {
        final c = container(
          agents: [identity('g1'), identity('g2')],
          specs: {'g1': spec('g1', flossing), 'g2': spec('g2', flossing)},
          history: {
            'g1': [
              record(
                id: 'g1-day',
                specVersionId: 'g1:spec',
                day: day,
                createdAt: DateTime(2026, 8, 10, 22),
                dimensions: {'c-floss': DayVerdict.met},
              ),
              record(
                id: 'g1-earlier-day',
                specVersionId: 'g1:spec',
                day: day.subtract(const Duration(days: 1)),
                createdAt: DateTime(2026, 8, 9, 22),
                dimensions: {'c-floss': DayVerdict.mixed},
              ),
            ],
            'g2': [
              record(
                id: 'g2-day',
                specVersionId: 'g2:spec',
                day: day,
                createdAt: DateTime(2026, 8, 10, 21),
                dimensions: {'c-floss': DayVerdict.missed},
              ),
            ],
          },
        );
        expect(await c.read(habitDayVerdictsProvider('floss').future), {
          day: DayVerdict.met,
          day.subtract(const Duration(days: 1)): DayVerdict.mixed,
        });
      },
    );
  });
}
