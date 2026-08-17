import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
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
import '../../../habits/habit_completion_record_fixtures.dart';
import '../../../habits/test_utils.dart';

/// Deterministic "now" for the page's success-only today derivation.
final _now = DateTime(2026, 8, 15, 14);

/// Serves a fixed [HabitHeatmapData] so the page's heatmap card renders
/// without the database-backed controller. Counts the preserve-state
/// refreshes so the midnight test can assert the projection was asked to
/// recompute WITHOUT being invalidated (no empty-grid flash).
int _heatmapRefreshes = 0;
int _heatmapBuilds = 0;

class _FakeHeatmapController extends HabitHeatmapController {
  _FakeHeatmapController([this.streaks = const {}]);

  final Map<String, int> streaks;

  @override
  HabitHeatmapData build() {
    _heatmapBuilds++;
    return HabitHeatmapData(
      days: const [],
      hasHabits: streaks.isNotEmpty,
      isLoading: false,
      streaksByHabit: streaks,
    );
  }

  @override
  Future<void> refreshNow() async {
    _heatmapRefreshes++;
  }
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
  GoalSpecVersionEntity spec(String agentId, {GoalCriterion? criteria}) =>
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec-v1',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Fitness',
            statement: 'Stay in motion.',
            criteria:
                criteria ??
                GoalCriterion.habit(
                  criterionId: 'c1',
                  habitId: habitFlossing.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalAgentHealth health(String agentId, {GoalCriterion? criteria}) => (
    trackStatus: GoalTrackStatus.onTrack,
    attainment: null,
    reportOneLiner: null,
    pendingProposals: 0,
    spec: spec(agentId, criteria: criteria),
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
    _heatmapBuilds = 0;
    _heatmapRefreshes = 0;
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
    bool agentsFail = false,
    bool healthFails = false,
    GoalProgressView? Function()? progressOverride,
    DateTime Function()? now,
    Map<String, int> streaks = const {},
    Size viewport = const Size(800, 2600),
    GoalCriterion? goalCriteria,
    List<Override> extraOverrides = const [],
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
          habitsNowProvider.overrideWithValue(now ?? () => _now),
          habitHeatmapControllerProvider.overrideWith(
            () => _FakeHeatmapController(streaks),
          ),
          firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
          if (agentsNeverResolve)
            activeGoalAgentsProvider.overrideWith(
              (ref) => Completer<List<AgentIdentityEntity>>().future,
            )
          else if (agentsFail)
            activeGoalAgentsProvider.overrideWith(
              (ref) async => throw StateError('agent db unavailable'),
            )
          else
            activeGoalAgentsProvider.overrideWith(
              (ref) async => [identity('goal-1', 'Fitness')],
            ),
          if (healthFails)
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => throw StateError('health unavailable'),
            )
          else
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => health('goal-1', criteria: goalCriteria),
            ),
          goalAgentProgressViewProvider('goal-1').overrideWith(
            (ref) async =>
                progressOverride != null ? progressOverride() : progress(),
          ),
          goalAssessmentHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          ...extraOverrides,
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
      // Wider than the 1100 measure plus its gutters, so the cap binds and
      // centering is observable.
      viewport: const Size(1600, 2600),
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

    // Nothing overflows even under the wide FlutterTest fallback font: the
    // folded tabs pan horizontally, the chart headline wraps, and the
    // summary card's streak pill drops under the fraction.
    expect(tester.takeException(), isNull);

    // Folded: the tabs sit BELOW the title instead of beside it.
    final titleRect = tester.getRect(find.text('Goals'));
    final tabsRect = tester.getRect(find.text('due').first);
    expect(tabsRect.top, greaterThan(titleRect.bottom - 1));
  });

  testWidgets('a FAILED first agent load says so instead of silently hiding '
      'goals and ungrouped habits', (tester) async {
    await pump(tester, baseState(), agentsFail: true);

    expect(
      find.text("Couldn't load your agents right now."),
      findsOneWidget,
    );
    expect(find.byType(UnifiedGoalCard), findsNothing);
    // Without the goal claims, orphan classification would be guesswork —
    // the error line carries the state instead of a misgrouped list.
    expect(find.text('Not in a goal'), findsNothing);
  });

  testWidgets('one goal whose health errored does not black out the orphan '
      'section — it settles as claiming nothing', (tester) async {
    await pump(tester, baseState(), healthFails: true);

    // Both habits render as ungrouped: the failing goal's claims are
    // unknowable, and hiding every habit indefinitely would be worse. The
    // goal card still renders header-only (no false verdict).
    expect(find.text('Not in a goal'), findsOneWidget);
    expect(find.text(habitFlossing.name), findsOneWidget);
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
  });

  testWidgets('a goal criterion referencing a deactivated habit renders no '
      'actionable row under the all filter', (tester) async {
    // The goal claims a habit that is no longer among the ACTIVE
    // definitions: its quick-complete would bypass the goal recording
    // path's lifecycle checks, so no row may render for it.
    await pump(
      tester,
      baseState(),
      progressOverride: () => GoalProgressView(
        today: DateTime.utc(2026, 8, 15),
        habits: [
          const GoalHabitProgressView(
            habitId: 'habit-retired',
            criterionId: 'c-retired',
            name: 'Retired habit',
            targetCount: 4,
            days: [],
            successfulWeeks: 0,
            evaluatedSuccesses: 1,
          ),
        ],
      ),
    );

    expect(find.byType(UnifiedGoalCard), findsOneWidget);
    expect(
      find.byKey(const Key('unified-goal-goal-1-c-retired-habit-retired')),
      findsNothing,
    );
  });

  testWidgets('a habit whose activeUntil has passed renders no actionable '
      'row even while its definition is still flagged active', (tester) async {
    // The boolean `active` flag alone is not the lifecycle: the goal
    // recording path also enforces the activeFrom/activeUntil window, and
    // the rows must not offer what the service would reject.
    final expired = habitFlossing.copyWith(
      activeUntil: DateTime(2026, 8, 10),
    );
    final expiredOrphan = habitFlossingDueLater.copyWith(
      id: 'habit-expired-orphan',
      name: 'Expired orphan',
      activeUntil: DateTime(2026, 8, 10),
    );
    when(
      () => mockEntitiesCacheService.getHabitById(expired.id),
    ).thenAnswer((_) => expired);
    when(
      () => mockEntitiesCacheService.getHabitById(expiredOrphan.id),
    ).thenAnswer((_) => expiredOrphan);
    final state = baseState().copyWith(
      habitDefinitions: [expired, expiredOrphan, habitFlossingDueLater],
      openNowAll: [expired, expiredOrphan, habitFlossingDueLater],
    );
    await pump(tester, state);

    expect(find.byType(UnifiedGoalCard), findsOneWidget);
    expect(
      find.byKey(Key('unified-goal-goal-1-c1-${expired.id}')),
      findsNothing,
    );
    // The same gate covers the orphan group: an out-of-window orphan gets no
    // actionable row either.
    expect(find.text(expiredOrphan.name), findsNothing);
    // The in-window habit keeps its row in the orphan group.
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);
  });

  testWidgets('the aggregate heatmap opts out of the category filter', (
    tester,
  ) async {
    await pump(tester, baseState());

    final heatmapCard = tester.widget<HabitHeatmapCard>(
      find.byType(HabitHeatmapCard),
    );
    expect(heatmapCard.ignoreCategoryFilter, isTrue);
  });

  testWidgets('the Done-today card is scoped to the recordable definitions', (
    tester,
  ) async {
    final expired = habitFlossing.copyWith(
      activeUntil: DateTime(2026, 8, 10),
    );
    final state = baseState().copyWith(
      habitDefinitions: [expired, habitFlossingDueLater],
      openNowAll: [habitFlossingDueLater],
    );
    await pump(tester, state);

    final summaryCard = tester.widget<HabitsSummaryCard>(
      find.byType(HabitsSummaryCard),
    );
    // Only the in-window definition counts — the expired one is invisible
    // and unrecordable on this surface, so it must not inflate "to go" —
    // and done counts SUCCESS-ONLY, matching the rows.
    expect(summaryCard.visibleHabitIds, {habitFlossingDueLater.id});
    expect(summaryCard.doneHabitIds, isNotNull);
  });

  testWidgets('the streak badge is scoped to recordable habits — a hidden '
      "out-of-window habit's streak is not advertised", (tester) async {
    final expired = habitFlossing.copyWith(
      activeUntil: DateTime(2026, 8, 10),
    );
    final state = baseState().copyWith(
      habitDefinitions: [expired, habitFlossingDueLater],
      openNowAll: [habitFlossingDueLater],
    );
    // The EXPIRED habit carries the only long streak.
    await pump(
      tester,
      state,
      streaks: {expired.id: 9, habitFlossingDueLater.id: 4},
    );

    final summaryCard = tester.widget<HabitsSummaryCard>(
      find.byType(HabitsSummaryCard),
    );
    expect(summaryCard.streakCounts, (short: 1, long: 0));
  });

  testWidgets("the summary's done set mirrors each group's semantics: a "
      'skipped or FAILED orphan counts as handled, a skipped goal habit '
      'stays to-go', (tester) async {
    // habitFlossing (goal-claimed) was skipped; habitFlossingDueLater
    // (ungrouped) was FAILED — in completedToday but not successfulToday.
    final state =
        baseState(
          successfulToday: {habitFlossing.id},
        ).copyWith(
          completedToday: {habitFlossing.id, habitFlossingDueLater.id},
          completedAll: [habitFlossing, habitFlossingDueLater],
        );
    await pump(tester, state);

    final summaryCard = tester.widget<HabitsSummaryCard>(
      find.byType(HabitsSummaryCard),
    );
    // The failed orphan is handled (its row files under Done)…
    expect(summaryCard.doneHabitIds, contains(habitFlossingDueLater.id));
    // …while the skipped goal habit stays to-go (its row stays due).
    expect(
      summaryCard.doneHabitIds,
      isNot(contains(habitFlossing.id)),
    );
  });

  testWidgets('a completion refetch invalidates the mounted goal progress '
      'projections, so window readings recompute in the same beat', (
    tester,
  ) async {
    var progressReads = 0;
    final controller = FakeHabitsController(baseState());
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const UnifiedGoalsPage(),
        mediaQueryData: const MediaQueryData(size: Size(800, 2600)),
        overrides: [
          habitsControllerProvider.overrideWith(() => controller),
          habitsNowProvider.overrideWithValue(() => _now),
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
          goalAgentProgressViewProvider('goal-1').overrideWith((ref) async {
            progressReads++;
            return progress();
          }),
          goalAssessmentHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(progressReads, 1);

    // The controller refetched completions (a quick-complete, a sync): the
    // mounted projection must recompute instead of serving its cached
    // pre-completion read. A REAL record, because the notifier only emits
    // when freezed equality changes.
    controller.emit(
      controller.state.copyWith(
        habitCompletions: habitCompletionRecordsFrom([
          testHabitCompletionEntry,
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(progressReads, 2);
  });

  testWidgets('a habit skipped today stays DUE on its goal card while the '
      'done filter shows only real successes', (tester) async {
    // habitFlossing was skipped today: the legacy buckets file it under
    // completed, but goal rows live in success-only terms.
    final state =
        baseState(
          successfulToday: {habitFlossing.id},
        ).copyWith(
          displayFilter: HabitDisplayFilter.openNow,
          openNowAll: [habitFlossingDueLater],
          completedAll: [habitFlossing],
        );
    await pump(tester, state);

    // Due filter: the skipped goal habit keeps its correctable row.
    final row = tester.widget<HabitActionRow>(
      find.byKey(Key('unified-goal-goal-1-c1-${habitFlossing.id}')),
    );
    expect(row.completedToday, isFalse);
  });

  testWidgets('the done filter shows a goal habit only for a REAL success, '
      'not a skip', (tester) async {
    final state =
        baseState(
          successfulToday: {habitFlossing.id},
        ).copyWith(
          displayFilter: HabitDisplayFilter.completed,
          completedAll: [habitFlossing],
        );
    await pump(tester, state);

    // Skipped ≠ done here: the goal card collapses to its header.
    expect(
      find.byKey(Key('unified-goal-goal-1-c1-${habitFlossing.id}')),
      findsNothing,
    );
    expect(find.text('Fitness'), findsOneWidget);
  });

  testWidgets('crossing midnight retires rows whose active window ended, '
      'without any new data event', (tester) async {
    var currentNow = DateTime(2026, 8, 15, 23);
    final endsTonight = habitFlossing.copyWith(
      activeUntil: DateTime(2026, 8, 16),
    );
    when(
      () => mockEntitiesCacheService.getHabitById(endsTonight.id),
    ).thenAnswer((_) => endsTonight);
    final state = baseState().copyWith(
      habitDefinitions: [endsTonight, habitFlossingDueLater],
      openNowAll: [endsTonight, habitFlossingDueLater],
    );
    final controller = await pump(tester, state, now: () => currentNow);

    expect(
      find.byKey(Key('unified-goal-goal-1-c1-${endsTonight.id}')),
      findsOneWidget,
    );

    // Midnight passes while the page stays mounted: the timer rebuild must
    // retire the row the recording path would now reject.
    currentNow = DateTime(2026, 8, 16, 0, 0, 30);
    await tester.pump(const Duration(hours: 1, minutes: 2));

    expect(
      find.byKey(Key('unified-goal-goal-1-c1-${endsTonight.id}')),
      findsNothing,
    );
    expect(find.text(habitFlossingDueLater.name), findsOneWidget);

    // And the CONTROLLER was asked to rebucket: `showFrom` bucketing and the
    // per-day maps are time-derived, so a bare rebuild would keep serving
    // yesterday's split. The heatmap projection has no clock of its own, so
    // it is asked to refresh too — PRESERVING its state: a provider
    // invalidation would flash the populated grid to the empty placeholder
    // (no-flash rule), so the controller must not have been rebuilt.
    expect(controller.refreshNowCalls, 1);
    expect(_heatmapRefreshes, 1);
    expect(_heatmapBuilds, 1);
  });

  testWidgets('entering Goals re-imports the health signals its goals watch', (
    tester,
  ) async {
    final healthImport = MockHealthImport();
    when(
      () => healthImport.fetchHealthDataDelta(any()),
    ).thenAnswer((_) async {});

    await pump(
      tester,
      HabitsState.initial(now: _now),
      goalCriteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'cumulative_step_count',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 10000,
      ),
      extraOverrides: [
        goalHealthRefreshServiceProvider.overrideWithValue(
          GoalHealthRefreshService(healthImport),
        ),
      ],
    );

    // Nothing on this surface would otherwise import: the goals list can
    // therefore show a step count the phone stopped agreeing with hours ago.
    verify(
      () => healthImport.fetchHealthDataDelta('cumulative_step_count'),
    ).called(1);
    // Once per visit — this page rebuilds on every controller tick.
    await tester.pump();
    await tester.pumpAndSettle();
    verifyNoMoreInteractions(healthImport);
  });
}
