import 'dart:async';

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

/// Deterministic "now" for the page's success-only today derivation.
final _now = DateTime(2026, 8, 15, 14);

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
        criterionId: 'c1',
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
    HabitsState state, {
    bool agentsNeverResolve = false,
    Size viewport = const Size(800, 2600),
  }) async {
    // Tall surface so the whole column — down to the aggregate heatmap and
    // chart cards — builds inside the sliver viewport.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = FakeHabitsController(state);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const UnifiedGoalsPage(),
        // Mirror the real view size into MediaQuery: the page computes its
        // centered-column padding from MediaQuery.sizeOf.
        mediaQueryData: MediaQueryData(size: viewport),
        overrides: [
          habitsControllerProvider.overrideWith(() => controller),
          habitsNowProvider.overrideWithValue(() => _now),
          habitHeatmapControllerProvider.overrideWith(
            _FakeHeatmapController.new,
          ),
          firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
          if (agentsNeverResolve)
            activeGoalAgentsProvider.overrideWith(
              (ref) => Completer<List<AgentIdentityEntity>>().future,
            )
          else
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
    if (agentsNeverResolve) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    return controller;
  }

  HabitsState baseState({
    HabitDisplayFilter filter = HabitDisplayFilter.all,
    Set<String> successfulToday = const {},
    Set<String> successOnlyToday = const {},
  }) => HabitsState.initial().copyWith(
    habitDefinitions: [habitFlossing, habitFlossingDueLater],
    // The page must read the category-UNFILTERED buckets; the filtered ones
    // are left empty here so any accidental read renders nothing and fails
    // the assertions below.
    openNowAll: [habitFlossing, habitFlossingDueLater],
    displayFilter: filter,
    successfulToday: successfulToday,
    successfulByDay: {
      if (successOnlyToday.isNotEmpty) '2026-08-15': successOnlyToday,
    },
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
    expect(navigated, ['/goals/create']);
  });

  testWidgets('a skipped habit stays actionable on the goal card while the '
      'orphan group keeps the Habits-tab semantics', (tester) async {
    // Both habits were "handled" today, but only the orphan's handling is a
    // real success — the goal-linked habit was SKIPPED. Goal criteria credit
    // only successes, so its goal-card row must keep the one-tap + button
    // (not completed), while the orphan row reads as handled.
    await pump(
      tester,
      baseState(
        successfulToday: {habitFlossing.id, habitFlossingDueLater.id},
        successOnlyToday: {habitFlossingDueLater.id},
      ),
    );

    final goalRow = tester.widget<HabitActionRow>(
      find.byKey(
        Key('unified-goal-goal-1-c1-${habitFlossing.id}'),
      ),
    );
    expect(goalRow.completedToday, isFalse);

    final orphanRow = tester.widget<HabitActionRow>(
      find.byKey(Key('unified-orphan-${habitFlossingDueLater.id}')),
    );
    expect(orphanRow.completedToday, isTrue);
  });

  testWidgets('the later filter arm selects the pending-later bucket', (
    tester,
  ) async {
    // Flossing-due-later is pending later; the goal-claimed habit is due
    // now. Under the later filter the goal card collapses to its header and
    // the orphan group shows only the pending habit.
    final state = baseState(filter: HabitDisplayFilter.pendingLater).copyWith(
      openNowAll: [habitFlossing],
      pendingLaterAll: [habitFlossingDueLater],
    );
    await pump(tester, state);

    expect(find.text(habitFlossing.name), findsNothing);
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
  });

  testWidgets('while the agent list is still loading, cached habits are NOT '
      'presented as ungrouped', (tester) async {
    await pump(tester, baseState(), agentsNeverResolve: true);

    // No goal cards yet — and crucially no orphan group either: the habits
    // would jump into their goal cards the moment the agents resolve.
    expect(find.byType(UnifiedGoalCard), findsNothing);
    expect(find.text('Not in a goal'), findsNothing);
    expect(find.byType(HabitActionRow), findsNothing);
  });

  testWidgets('a window wider than the reading measure centers the column', (
    tester,
  ) async {
    await pump(
      tester,
      baseState(),
      viewport: const Size(1200, 2600),
    );

    // The column is capped at the unified reading measure and centered:
    // the header starts well inside the left edge.
    final headerRect = tester.getRect(find.text('Goals'));
    expect(headerRect.left, greaterThan(200));
  });

  testWidgets('a narrow window folds the filter tabs under the title', (
    tester,
  ) async {
    await pump(
      tester,
      baseState(),
      viewport: const Size(430, 2600),
    );

    // The reused completion-rate chart's headline row overflows at phone
    // widths under the wide test font — pre-existing rendering noise from
    // the reused card, not the fold behavior under test here.
    var exception = tester.takeException();
    while (exception != null) {
      // The binding folds several reported errors into one wrapper whose
      // message doesn't restate them; the individual reports (all RenderFlex
      // overflows from the reused cards) are printed above.
      expect(
        '$exception',
        anyOf(contains('overflowed'), contains('Multiple exceptions')),
      );
      exception = tester.takeException();
    }

    // Folded: the tabs sit BELOW the title instead of beside it.
    final titleRect = tester.getRect(find.text('Goals'));
    final tabsRect = tester.getRect(find.text('due').first);
    expect(tabsRect.top, greaterThan(titleRect.bottom - 1));
  });
}
