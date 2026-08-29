import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_habit_watchers.dart';

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

  ProviderContainer container({
    required List<AgentIdentityEntity> agents,
    required Map<String, GoalSpecVersionEntity?> specs,
  }) {
    final c = ProviderContainer(
      overrides: [
        activeGoalAgentsProvider.overrideWith((ref) async => agents),
        for (final entry in specs.entries)
          goalAgentHealthProvider(
            entry.key,
          ).overrideWith((ref) async => health(entry.value)),
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
}
