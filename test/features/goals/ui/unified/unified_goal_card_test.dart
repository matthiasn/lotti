import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockEntitiesCacheService = MockEntitiesCacheService();

  AgentIdentityEntity identity(String id, String name) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: AgentKinds.goalAgent,
            displayName: name,
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

  GoalSpecVersionEntity spec(String agentId) =>
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec-v1',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Fitness',
            statement: 'Stay in motion.',
            criteria: GoalCriterion.allOf(
              criterionId: 'root',
              criteria: [
                GoalCriterion.habit(
                  criterionId: 'c1',
                  habitId: habitFlossing.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
                GoalCriterion.habit(
                  criterionId: 'c2',
                  habitId: habitFlossingDueLater.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
              ],
            ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalAgentHealth health({
    required String agentId,
    GoalTrackStatus? trackStatus,
    String? reportOneLiner,
    int? deficit,
    GoalHealthDirection? direction,
    bool withSpec = true,
  }) => (
    trackStatus: trackStatus,
    attainment: null,
    reportOneLiner: reportOneLiner,
    pendingProposals: 0,
    spec: withSpec ? spec(agentId) : null,
    direction: direction,
    deficit: deficit,
    buffer: null,
  );

  GoalProgressView progress() => GoalProgressView(
    today: DateTime.utc(2026, 8, 15),
    habits: [
      GoalHabitProgressView(
        habitId: habitFlossing.id,
        name: habitFlossing.name,
        targetCount: 4,
        days: const [],
        successfulWeeks: 1,
        evaluatedSuccesses: 4,
      ),
      GoalHabitProgressView(
        habitId: habitFlossingDueLater.id,
        name: habitFlossingDueLater.name,
        targetCount: 4,
        days: const [],
        successfulWeeks: 0,
        evaluatedSuccesses: 2,
      ),
    ],
  );

  setUp(() {
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
    ).thenAnswer((_) => habitFlossing);
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossingDueLater.id),
    ).thenAnswer((_) => habitFlossingDueLater);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  Future<void> pump(
    WidgetTester tester, {
    required GoalAgentHealth agentHealth,
    GoalProgressView? progressView,
    Set<String>? visibleHabitIds,
    Set<String> successfulToday = const {},
    Map<String, int> streaks = const {},
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        UnifiedGoalCard(
          identity: identity('goal-1', 'Fitness'),
          successfulToday: successfulToday,
          streaksByHabit: streaks,
          visibleHabitIds: visibleHabitIds,
        ),
        overrides: [
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => agentHealth),
          goalAgentProgressViewProvider(
            'goal-1',
          ).overrideWith((ref) async => progressView),
          goalAssessmentHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the pill with the folded recovery hint, the '
      'templated summary and one action row per habit with its window '
      'reading', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.offTrack,
        reportOneLiner: 'The gym has been quiet.',
        deficit: 2,
      ),
      progressView: progress(),
      streaks: {habitFlossing.id: 3},
    );

    expect(find.text('Fitness'), findsOneWidget);
    // Behind pill with the deterministic recovery door folded in.
    expect(find.text('Behind · 2 days to recover'), findsOneWidget);
    // The summary is TEMPLATED from live state — the agent's one-liner does
    // not reach the list level for habit goals.
    expect(find.text('1 of 2 habits on track'), findsOneWidget);
    expect(find.text('The gym has been quiet.'), findsNothing);

    // Both habit rows render with their window readings; only the lagging
    // one carries the off-track word.
    expect(find.byType(HabitActionRow), findsNWidgets(2));
    expect(find.text(habitFlossing.name), findsOneWidget);
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);
    expect(find.text('4 of 4 this window'), findsOneWidget);
    expect(find.text('2 of 4 this window'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('a filter that hides every habit collapses the card to its '
      'header — the goal itself never vanishes', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
      visibleHabitIds: const {},
    );

    expect(find.text('Fitness'), findsOneWidget);
    expect(find.byType(HabitActionRow), findsNothing);
    // The pill still reflects FULL state — filters act on rows, never on
    // verdicts.
    expect(find.text('On track'), findsOneWidget);
  });

  testWidgets('no-data with a standing one-liner shows the one-liner and '
      'suppresses the pill (never contradict a standing assessment)', (
    tester,
  ) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        reportOneLiner: 'Waiting on the first samples.',
        withSpec: false,
      ),
    );

    expect(find.text('No data'), findsNothing);
    expect(find.text('Waiting on the first samples.'), findsOneWidget);
  });

  testWidgets('tapping the header opens the goal detail route', (
    tester,
  ) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );

    await tester.tap(find.text('Fitness'));
    await tester.pump();
    expect(navigated, ['/agents/details/goal-1']);
  });
}
