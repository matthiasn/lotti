import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../habits/test_utils.dart';

/// Serves a fixed [HabitHeatmapData] so the page's heatmap card renders
/// without the database-backed controller.
class _FakeHeatmapController extends HabitHeatmapController {
  @override
  HabitHeatmapData build() => HabitHeatmapData.empty();
}

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

  /// A goal spec claiming [habitFlossing] — [habitFlossingDueLater] stays
  /// unclaimed, so it must land in the "not in a goal" group.
  GoalSpecVersionEntity spec(String agentId) =>
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec-v1',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Fitness',
            statement: 'Stay in motion.',
            criteria: GoalCriterion.habit(
              criterionId: 'c1',
              habitId: habitFlossing.id,
              window: const GoalWindow.rollingDays(count: 7),
              targetCount: 4,
            ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalAgentHealth health(String agentId) => (
    trackStatus: GoalTrackStatus.onTrack,
    attainment: null,
    reportOneLiner: null,
    pendingProposals: 0,
    spec: spec(agentId),
    direction: null,
    deficit: null,
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
    ],
  );

  setUp(() {
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
    ).thenAnswer((_) => habitFlossing);
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossingDueLater.id),
    ).thenAnswer((_) => habitFlossingDueLater);
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UserActivityService>(UserActivityService());
  });

  tearDown(getIt.reset);

  Future<FakeHabitsController> pump(
    WidgetTester tester,
    HabitsState state,
  ) async {
    // Tall surface so the whole column — down to the aggregate heatmap and
    // chart cards — builds inside the sliver viewport.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = FakeHabitsController(state);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const UnifiedGoalsPage(),
        overrides: [
          habitsControllerProvider.overrideWith(() => controller),
          habitHeatmapControllerProvider.overrideWith(
            _FakeHeatmapController.new,
          ),
          firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-1', 'Fitness')],
          ),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => health('goal-1')),
          goalAgentProgressViewProvider(
            'goal-1',
          ).overrideWith((ref) async => progress()),
          goalAssessmentHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  HabitsState baseState({
    HabitDisplayFilter filter = HabitDisplayFilter.all,
  }) => HabitsState.initial().copyWith(
    habitDefinitions: [habitFlossing, habitFlossingDueLater],
    openNow: [habitFlossing, habitFlossingDueLater],
    displayFilter: filter,
  );

  testWidgets('renders the summary card, the goal card with its habit row, '
      'the orphan group, and the aggregate dashboard cards', (tester) async {
    await pump(tester, baseState());

    // Page header + reused Done-today summary card.
    expect(find.text('Goals'), findsOneWidget);
    expect(find.byType(HabitsSummaryCard), findsOneWidget);

    // The goal card renders EXPANDED by default: its claimed habit row is
    // directly visible (grouping never means hiding).
    expect(find.byType(UnifiedGoalCard), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text(habitFlossing.name), findsOneWidget);

    // The unclaimed habit lands in the "not in a goal" group, with the same
    // one-tap action row (the header shows label and count).
    expect(find.text('Not in a goal'), findsOneWidget);
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);
    expect(find.byType(HabitActionRow), findsNWidgets(2));

    // Aggregate dashboard band at the foot, reused as-is.
    expect(find.byType(HabitHeatmapCard), findsOneWidget);
    expect(find.byType(HabitsChartCard), findsOneWidget);
  });

  testWidgets('the done filter hides open rows everywhere while the goal '
      'header survives — filters act on rows, never on goals', (tester) async {
    await pump(
      tester,
      baseState(filter: HabitDisplayFilter.completed),
    );

    // No habit is completed, so no rows anywhere — but the goal card header
    // stays (pill, strip, summary keep reflecting full state).
    expect(find.byType(HabitActionRow), findsNothing);
    expect(find.text('Fitness'), findsOneWidget);
    // The orphan group has nothing to show and disappears entirely.
    expect(find.text('Not in a goal'), findsNothing);
  });

  testWidgets('the filter tabs drive the shared habits controller', (
    tester,
  ) async {
    final controller = await pump(tester, baseState());

    // The segmented toggle renders a sizing/active text pair per segment —
    // both share the same hit area, so tapping the first is unambiguous.
    await tester.tap(find.text('done').first);
    await tester.pump();

    expect(
      controller.displayFilterCalls,
      contains(HabitDisplayFilter.completed),
    );
  });

  testWidgets('the FAB opens the goal creation wizard', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await pump(tester, baseState());

    await tester.tap(find.byType(DesignSystemFloatingActionButton));
    await tester.pump();
    expect(navigated, ['/agents/create']);
  });
}
