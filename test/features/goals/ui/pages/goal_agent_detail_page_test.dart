import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart'
    show WakeRunCompletion;
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_log_today_sheet.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_exposure_tracker.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';
import '../../../habits/test_utils.dart';

void main() {
  final goalIdentity =
      AgentDomainEntity.agent(
            id: 'goal-1',
            agentId: 'goal-1',
            kind: AgentKinds.goalAgent,
            displayName: 'Move more',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'goal-1:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;
  testWidgets('renders the health header and no-report hint without an empty '
      'timeline section', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final completionService = MockGoalHabitCompletionService();
    when(
      () => completionService.requestReportRefresh('goal-1'),
    ).thenReturn('refresh-run');
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Average 10,000 steps per day over a rolling week.',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.atRisk,
              attainment: 0.64,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: spec,
              direction: GoalHealthDirection.up,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: DateTime.utc(2026, 8, 11),
              metric: GoalMetricProgressView(
                name: 'Daily steps',
                target: 10000,
                days: [
                  for (var day = 5; day <= 11; day++)
                    GoalProgressDay(
                      day: DateTime.utc(2026, 8, day),
                      value: day.isEven ? 11000 : 7000,
                    ),
                ],
              ),
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // App bar + detail header + the read card's persona subtitle.
    expect(find.text('Move more'), findsNWidgets(3));
    // The SAME four-pill vocabulary as the unified Goals list: runtime
    // atRisk reads "At risk" here exactly as it does on the list row — and
    // the detail surface never displays a percentage.
    expect(find.text('At risk'), findsOneWidget);
    expect(find.text('Trending up'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.textContaining('% of target'), findsNothing);
    // The metric card (the §4b Signals section) carries the dimension name
    // under its section heading; the old Watching list is gone.
    expect(find.text('Daily steps'), findsOneWidget);
    expect(find.text('Signals'), findsOneWidget);
    expect(find.text('Watching'), findsNothing);
    expect(find.text('Health data'), findsOneWidget);
    // The statement no longer repeats in the header — the title carries the
    // goal's identity, and the full definition lives behind Edit goal.
    expect(
      find.textContaining(
        'Average 10,000 steps per day over a rolling week.',
      ),
      findsNothing,
    );
    // The narrative hero card wears the task agent section's shared panel
    // (same title, same chrome) with the no-report fallback.
    expect(find.text('AI summary'), findsOneWidget);
    expect(
      find.text(
        'No report yet — the agent reports after its first meaningful '
        'change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Interactions'), findsNothing);
    expect(
      find.byKey(const ValueKey('agentAutomationRowCompact')),
      findsOneWidget,
    );
    expect(find.text('Automatic updates'), findsNothing);

    // The reload affordances ride the read card itself, exactly like the
    // task agent section — no expander in between.
    expect(find.text('About this agent'), findsNothing);
    await tester.ensureVisible(
      find.widgetWithText(DesignSystemButton, 'Update now'),
    );
    final refreshButton = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Update now'),
    );
    expect(refreshButton.leadingIcon, Icons.refresh_rounded);
    expect(refreshButton.isLoading, isFalse);
    expect(refreshButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Update now'));
    verify(
      () => completionService.requestReportRefresh('goal-1'),
    ).called(1);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Automatic updates'), findsOneWidget);
    await tester.tap(find.text('Edit goal'));
    expect(navigated, ['/goals/details/goal-1/edit']);
    navigated.clear();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Signals'), findsOneWidget);
    await tester.tap(find.text('Talk to agent'));
    await tester.pump();
    expect(navigated, ['/goals/details/goal-1/chat']);
  });

  testWidgets('opening a goal re-imports the health signals it watches', (
    tester,
  ) async {
    final healthImport = MockHealthImport();
    when(
      () => healthImport.fetchHealthDataDelta(any()),
    ).thenAnswer((_) async {});
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Average 10,000 steps per day over a rolling week.',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 0.9,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: spec,
              direction: GoalHealthDirection.flat,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith((ref) async => null),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          goalHealthRefreshServiceProvider.overrideWithValue(
            GoalHealthRefreshService(healthImport),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Health samples reach the journal only through an import, and nothing
    // else on this page triggers one: without this the card can show
    // yesterday's steps beside today's date and be entirely correct about the
    // database while wrong about the user.
    verify(
      () => healthImport.fetchHealthDataDelta('cumulative_step_count'),
    ).called(1);

    // ...and exactly once per visit. This page rebuilds on every provider
    // tick, and a fetch per rebuild would hammer the health store.
    await tester.pump();
    await tester.pumpAndSettle();
    verifyNoMoreInteractions(healthImport);
  });

  group('update-failure feedback on the read card', () {
    Future<void> pump(
      WidgetTester tester, {
      required WakeRunCompletion outcome,
      AgentStateEntity? agentState,
      AgentReportEntity? report,
      GoalSpecVersionEntity? spec,
    }) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalReportWakeOutcomeProvider(
            'goal-1',
          ).overrideWith((ref) => Stream.value(outcome)),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => report),
          agentStateProvider('goal-1').overrideWith((ref) async => agentState),
        ],
      ),
    );

    testWidgets('a failed update surfaces its reason on the read card', (
      tester,
    ) async {
      await pump(
        tester,
        outcome: WakeRunCompletion(
          runKey: 'run-fail',
          agentId: 'goal-1',
          status: WakeRunStatus.failed,
          triggerTokens: const {goalReportRefreshTriggerToken},
          finishedAt: DateTime(2026, 8, 16, 19, 14),
          error: StateError(
            'MeliousInferenceException (HTTP 429): Insufficient balance '
            'for request. Required: 74, Available: 0',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fourteen silent failures cost a debugging session: the card must
      // SAY the update died, and say why in the provider's own words (the
      // "Bad state: " executor wrapping stripped).
      expect(
        find.byKey(const ValueKey('goal-agent-update-failed')),
        findsOneWidget,
      );
      expect(find.textContaining('Last update failed'), findsOneWidget);
      expect(find.textContaining('Insufficient balance'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
    });

    testWidgets('a successful update surfaces nothing — completed outcomes '
        'clear the failure line', (tester) async {
      await pump(
        tester,
        outcome: const WakeRunCompletion(
          runKey: 'run-ok',
          agentId: 'goal-1',
          status: WakeRunStatus.completed,
          triggerTokens: {goalReportRefreshTriggerToken},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('goal-agent-update-failed')),
        findsNothing,
      );
    });

    testWidgets('one mounted page walks failed → retrying → completed: the '
        'line shows, steps aside for the running state, and stays gone '
        'after the retry lands', (tester) async {
      final outcomes = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(outcomes.close);
      final running = StreamController<bool>.broadcast();
      addTearDown(running.close);
      final refreshRunning = StreamController<bool>.broadcast();
      addTearDown(refreshRunning.close);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalReportWakeOutcomeProvider(
              'goal-1',
            ).overrideWith((ref) => outcomes.stream),
            agentIsRunningProvider(
              'goal-1',
            ).overrideWith((ref) => running.stream),
            goalReportWakeInFlightProvider(
              'goal-1',
            ).overrideWith((ref) => refreshRunning.stream),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Seven for seven.',
                pendingProposals: 0,
                spec: null,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith((ref) async => null),
            agentStateProvider('goal-1').overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final failureLine = find.byKey(
        const ValueKey('goal-agent-update-failed'),
      );
      expect(failureLine, findsNothing);

      // The refresh dies: the line appears.
      running.add(false);
      outcomes.add(
        WakeRunCompletion(
          runKey: 'run-fail',
          agentId: 'goal-1',
          status: WakeRunStatus.failed,
          triggerTokens: const {goalReportRefreshTriggerToken},
          error: StateError('Insufficient balance for request'),
        ),
      );
      await tester.pumpAndSettle();
      expect(failureLine, findsOneWidget);

      // An UNRELATED wake for the same agent starts — a chat reply, a
      // Phase A subscription tick. The agent-wide running flag flips, but
      // the failure line must not blink away: only a report refresh
      // (workspace-scoped) takes its stage.
      running.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(failureLine, findsOneWidget);

      // A report-refresh RETRY starts: the running state takes the stage.
      // Bounded pumps — the automation row's progress affordance animates,
      // so the tree never settles while a run is active.
      refreshRunning.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(failureLine, findsNothing);

      // The retry lands: completed clears the failure for good.
      running.add(false);
      refreshRunning.add(false);
      outcomes.add(
        const WakeRunCompletion(
          runKey: 'run-ok',
          agentId: 'goal-1',
          status: WakeRunStatus.completed,
          triggerTokens: {goalReportRefreshTriggerToken},
        ),
      );
      await tester.pumpAndSettle();
      expect(failureLine, findsNothing);
    });

    testWidgets('a timed-out run that publishes LATE clears its own timeout '
        'error — the displayed report outranks the aborted outcome', (
      tester,
    ) async {
      await pump(
        tester,
        outcome: WakeRunCompletion(
          runKey: 'run-timeout',
          agentId: 'goal-1',
          status: WakeRunStatus.aborted,
          triggerTokens: const {goalReportRefreshTriggerToken},
          startedAt: DateTime(2026, 8, 16, 19),
          finishedAt: DateTime(2026, 8, 16, 19, 10),
          error: TimeoutException('timeout'),
        ),
        // The executor future was allowed to finish after the cap: its
        // report lands by notification, with no completed outcome and no
        // fresh watermark.
        report:
            AgentDomainEntity.agentReport(
                  id: 'report-late',
                  agentId: 'goal-1',
                  scope: AgentReportScopes.current,
                  createdAt: DateTime(2026, 8, 16, 19, 12),
                  vectorClock: null,
                  oneLiner: 'Late but landed.',
                  tldr: 'Late but landed.',
                  content: 'The slow run finished after the cap.',
                  provenance: const {'specVersionId': 'goal-1:spec-v1'},
                )
                as AgentReportEntity,
        spec:
            AgentDomainEntity.goalSpecVersion(
                  id: 'goal-1:spec-v1',
                  agentId: 'goal-1',
                  version: 1,
                  status: GoalSpecVersionStatus.active,
                  authoredBy: 'user',
                  title: 'Move more',
                  statement: 'Walk this week.',
                  criteria: const GoalCriterion.habit(
                    criterionId: 'walk',
                    habitId: 'walk',
                    window: GoalWindow.rollingDays(count: 7),
                    targetCount: 3,
                  ),
                  createdAt: DateTime(2026, 8),
                  vectorClock: null,
                )
                as GoalSpecVersionEntity,
      );
      await tester.pumpAndSettle();
      expect(find.text('Late but landed.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('goal-agent-update-failed')),
        findsNothing,
      );
    });

    testWidgets('a success synced from ANOTHER device outranks an older '
        'local failure — the freshness watermark hides the line', (
      tester,
    ) async {
      await pump(
        tester,
        outcome: WakeRunCompletion(
          runKey: 'run-fail',
          agentId: 'goal-1',
          status: WakeRunStatus.failed,
          triggerTokens: const {goalReportRefreshTriggerToken},
          startedAt: DateTime(2026, 8, 16, 19, 13),
          finishedAt: DateTime(2026, 8, 16, 19, 14),
          error: StateError('Insufficient balance for request'),
        ),
        // The other device's successful refresh arrives by sync as agent
        // state whose freshness watermark (the successful run's START)
        // postdates this failure's start.
        agentState:
            AgentDomainEntity.agentState(
                  id: 'goal-1:state',
                  agentId: 'goal-1',
                  slots: const AgentSlots(),
                  updatedAt: DateTime(2026, 8, 16, 19, 30),
                  vectorClock: null,
                  reportFreshAt: DateTime(2026, 8, 16, 19, 30),
                  reportStaleAt: DateTime(2026, 8, 16, 19, 13),
                )
                as AgentStateEntity,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('goal-agent-update-failed')),
        findsNothing,
      );
    });
  });

  testWidgets('a banner snoozed from the shell dock STAYS on its goal page, '
      'captioned with when it returns to the bar', (tester) async {
    final now = DateTime(2026, 8, 11, 12);
    final snoozed =
        AgentDomainEntity.goalNudge(
              id: 'ad-goal-1',
              agentId: 'goal-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Two walks left this window.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Seven for seven.',
                pendingProposals: 0,
                spec: null,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            activeGoalNudgesProvider.overrideWith(
              (ref) async => [
                (
                  nudge: NudgeEntityView.of(
                    snoozed.copyWith(
                      snoozedUntil: now.add(const Duration(hours: 1)),
                    ),
                  )!,
                  subjectTitle: 'Move more',
                  kind: NudgeBannerKind.goal,
                  tapRoute: '/goals/details/goal-1',
                ),
              ],
            ),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith((ref) async => null),
          ],
        ),
      );
      // Bounded pumps: the return countdown runs a real second-tick.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The shell dock filters this banner out (visibleNudgeBannerEntries),
      // but the goal page does NOT: the banner card stays, and the caption
      // says when it returns to the bar instead of letting it vanish.
      expect(find.text('Two walks left this window.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('goal-banner-shell-return-countdown')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Hidden from the banner bar'),
        findsOneWidget,
      );
      expect(find.textContaining('1:00:00'), findsOneWidget);
    });
  });

  testWidgets('the return countdown ticks down, disappears when the quiet '
      'interval passes, and re-arms when a new snooze lands on the same '
      'banner', (tester) async {
    var current = DateTime(2026, 8, 11, 12);
    final entriesNotifier = ValueNotifier<List<NudgeBannerEntry>>([]);
    addTearDown(entriesNotifier.dispose);
    NudgeBannerEntry snoozedEntry(DateTime until) => (
      nudge: NudgeEntityView.of(
        AgentDomainEntity.goalNudge(
          id: 'ad-goal-1',
          agentId: 'goal-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Two walks left this window.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'd',
          snoozedUntil: until,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
          vectorClock: null,
        ),
      )!,
      subjectTitle: 'Move more',
      kind: NudgeBannerKind.goal,
      tapRoute: '/goals/details/goal-1',
    );
    entriesNotifier.value = [
      snoozedEntry(current.add(const Duration(seconds: 2))),
    ];
    await withClock(Clock(() => current), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Seven for seven.',
                pendingProposals: 0,
                spec: null,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            activeGoalNudgesProvider.overrideWith((ref) async {
              final listener = entriesNotifier;
              void refresh() => ref.invalidateSelf();
              listener.addListener(refresh);
              ref.onDispose(() => listener.removeListener(refresh));
              return listener.value;
            }),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final countdown = find.byKey(
        const ValueKey('goal-banner-shell-return-countdown'),
      );
      expect(countdown, findsOneWidget);

      // The deadline passes: the next tick recomputes zero remaining and
      // the caption disappears — it must never state a falsehood about a
      // banner the bar is already showing again.
      current = current.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(countdown, findsNothing);
      // The banner card itself stays, of course.
      expect(find.text('Two walks left this window.'), findsOneWidget);

      // A NEW snooze lands on the same banner: the same countdown element
      // gets the later deadline (didUpdateWidget resync) and re-arms.
      entriesNotifier.value = [
        snoozedEntry(current.add(const Duration(hours: 1))),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(countdown, findsOneWidget);
      expect(find.textContaining('1:00:00'), findsOneWidget);

      // Extending the snooze while the caption is VISIBLE updates the same
      // element in place — the displayed remaining time jumps to the new
      // deadline, proving the resync rather than a remount.
      entriesNotifier.value = [
        snoozedEntry(current.add(const Duration(hours: 2))),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('2:00:00'), findsOneWidget);
    });
  });

  testWidgets('a standing report renders its one-liner instead of the '
      'no-report hint', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          agentConsumptionTotalsProvider.overrideWith(
            (ref, agentId) => Stream.value(
              makeConsumptionTotals(
                callCount: 3,
                inputTokens: 1200,
                outputTokens: 800,
                totalTokens: 2000,
                credits: 0.42,
              ),
            ),
          ),
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven. Keep coasting.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentStateProvider('goal-1').overrideWith(
            (ref) async =>
                AgentDomainEntity.agentState(
                      id: 'goal-1:state',
                      agentId: 'goal-1',
                      slots: const AgentSlots(),
                      updatedAt: DateTime(2026, 8, 12, 18, 30),
                      vectorClock: null,
                      reportFreshAt: DateTime(2026, 8, 12, 18),
                      reportStaleAt: DateTime(2026, 8, 12, 18, 30),
                    )
                    as AgentStateEntity,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seven for seven. Keep coasting.'), findsOneWidget);
    // Header slot + automation row, like the task agent section.
    expect(find.text('Out of date'), findsNWidgets(2));
    expect(find.textContaining('No report yet'), findsNothing);
    // The shared AI panel chrome: same header widget as the task agent
    // section, with the goal's cumulative inference cost pills on the card.
    expect(find.byType(TldrHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-agent-lifetime-pills')),
      findsOneWidget,
    );
  });

  testWidgets('a sections payload with nothing in it falls back to the flat '
      'text, and a malformed one does not crash the card', (tester) async {
    final probeSpec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-probe',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    Future<void> pump(Object? sections) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Two days in.',
              pendingProposals: 0,
              spec: probeSpec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith(
            (ref) async =>
                AgentDomainEntity.agentReport(
                      id: 'report-x',
                      agentId: 'goal-1',
                      scope: AgentReportScopes.current,
                      createdAt: DateTime(2026, 8, 10),
                      vectorClock: null,
                      oneLiner: 'Two days in.',
                      tldr: 'Two days in.',
                      content: 'The rolling window is still filling up.',
                      provenance: {
                        'specVersionId': 'goal-1:spec-probe',
                        GoalReportProvenanceKeys.sections: sections,
                      },
                    )
                    as AgentReportEntity,
          ),
        ],
      ),
    );

    // Every slot empty is not a sectioned report. Treated as one, the card
    // rendered zero headings and zero actions while `content` still held the
    // real text — an empty expansion instead of a fallback.
    await pump({
      GoalReportSectionKeys.currentPeriod: '',
      GoalReportSectionKeys.nextActions: <Object?>[],
    });
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    // No section headings: an all-empty payload is not a sectioned report,
    // and treating it as one rendered an empty expansion while `content`
    // still held the real text.
    expect(find.text('Where things stand'), findsNothing);
    expect(find.text('Data coverage'), findsNothing);

    // Provenance arrives from persisted or synced JSON, so another client
    // version could write a String where a List belongs. That used to be a
    // TypeError the first time the card was expanded.
    await pump({
      GoalReportSectionKeys.currentPeriod: 'Logged today.',
      GoalReportSectionKeys.nextActions: 'walk more',
    });
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    // A String where a List belongs used to be a TypeError the first time
    // the card built its sections.
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active goal with nothing pending pays no card gap for the '
      'revision card', (tester) async {
    Future<void> pump({required int pendingProposals}) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'All good.',
              pendingProposals: pendingProposals,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );

    // The card renders nothing when nothing is pending, so gating its GAP on
    // "the agent is active" left the one broken interval in an otherwise even
    // stack.
    // Nothing pending: the card is not in the tree, so neither is its gap.
    await pump(pendingProposals: 0);
    await tester.pumpAndSettle();
    expect(
      find.byType(ChangeSetSummaryCard, skipOffstage: false),
      findsNothing,
    );
    final withoutCard = tester.getSize(find.byType(GoalAgentDetailPage)).height;

    // A proposal waiting takes the other branch. The list is lazy, so the
    // card itself may sit below the built window — what this pins is that
    // the gate reads the proposal count rather than merely "is active".
    await pump(pendingProposals: 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(GoalAgentDetailPage)).height,
      withoutCard,
    );
  });

  testWidgets('a published assessment silences the Not-enough-data chip, and '
      'a sectionless report still expands to its flat text', (tester) async {
    final legacySpec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final legacyReport =
        AgentDomainEntity.agentReport(
              id: 'report-legacy',
              agentId: 'goal-1',
              scope: AgentReportScopes.current,
              createdAt: DateTime(2026, 8, 10),
              vectorClock: null,
              oneLiner: 'Two days in.',
              tldr: 'Two days in.',
              content: 'The rolling window is still filling up.',
              provenance: const {'specVersionId': 'goal-1:spec-v1'},
            )
            as AgentReportEntity;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.insufficientData,
              attainment: 0.3,
              reportOneLiner: 'Two days in.',
              pendingProposals: 0,
              spec: legacySpec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider(
            'goal-1',
          ).overrideWith((ref) async => legacyReport),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The header sits directly above a report that assesses the goal, so it
    // must not also claim there is not enough data to have written one.
    expect(find.text('Not enough data'), findsNothing);
    expect(find.text('Two days in.'), findsOneWidget);

    // No sections persisted — a report written before they existed — so the
    // composed flat text remains the fallback rendering.
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The rolling window is still filling up.'),
      findsOneWidget,
    );
    expect(find.text('Where things stand'), findsNothing);
  });

  testWidgets('a stale goal report uses the shared countdown, skip, toggle, '
      'and manual refresh controls', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 8, 13, 12);
    var stateReads = 0;
    var agentState =
        AgentDomainEntity.agentState(
              id: 'goal-1:state',
              agentId: 'goal-1',
              slots: const AgentSlots(),
              updatedAt: now,
              vectorClock: null,
              nextWakeAt: now.add(
                const Duration(minutes: 1, seconds: 30),
              ),
              reportFreshAt: now.subtract(const Duration(hours: 1)),
              reportStaleAt: now,
            )
            as AgentStateEntity;
    final completionService = MockGoalHabitCompletionService();
    final goalService = MockGoalAgentService();
    when(
      () => completionService.requestReportRefresh('goal-1'),
    ).thenReturn('refresh-run');
    when(
      () => goalService.updateAutomaticUpdates(
        agentId: 'goal-1',
        enabled: false,
      ),
    ).thenAnswer((_) async {});
    when(() => goalService.skipPendingReportRefresh('goal-1')).thenReturn(null);

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider('goal-1').overrideWith(
              (ref) async => goalIdentity.copyWith(
                config: const AgentConfig(automaticUpdatesEnabled: true),
              ),
            ),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Seven for seven. Keep coasting.',
                pendingProposals: 0,
                spec: null,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith((ref) async => null),
            agentStateProvider('goal-1').overrideWith((ref) async {
              stateReads++;
              return agentState;
            }),
            goalHabitCompletionServiceProvider.overrideWithValue(
              completionService,
            ),
            goalAgentServiceProvider.overrideWithValue(goalService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The read card self-demotes — its header slot carries the
      // out-of-date notice — and the automation row on the same card
      // echoes the verdict, exactly like the task agent section.
      expect(find.text('Out of date'), findsNWidgets(2));
      expect(find.textContaining('1:30'), findsOneWidget);
      expect(find.text('Skip once'), findsOneWidget);
      expect(find.text('Automatic updates'), findsOneWidget);

      await tester.tap(find.text('Update now'));
      verify(
        () => completionService.requestReportRefresh('goal-1'),
      ).called(1);

      await tester.tap(find.text('Skip once'));
      await tester.pump();
      verify(() => goalService.skipPendingReportRefresh('goal-1')).called(1);
      expect(find.textContaining('1:30'), findsNothing);

      // A later evidence change can schedule fresh work after Skip once. The
      // local cancellation must not hide that new persisted deadline.
      agentState = agentState.copyWith(
        nextWakeAt: now.add(const Duration(minutes: 2)),
      );
      ProviderScope.containerOf(
        tester.element(find.byType(GoalAgentDetailPage)),
        listen: false,
      ).invalidate(agentStateProvider('goal-1'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('2:00'), findsOneWidget);

      // Countdown expiry must re-read persisted state so the row can leave
      // its scheduled state once the wake runner clears nextWakeAt.
      final readsBeforeExpiry = stateReads;
      tester
          .widget<AgentAutomationRow>(find.byType(AgentAutomationRow))
          .onCountdownExpired();
      await tester.pump();
      expect(stateReads, greaterThan(readsBeforeExpiry));

      await tester.tap(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Automatic updates').last,
        warnIfMissed: false,
      );
      await tester.pump();
      verify(
        () => goalService.updateAutomaticUpdates(
          agentId: 'goal-1',
          enabled: false,
        ),
      ).called(2);

      when(
        () => goalService.updateAutomaticUpdates(
          agentId: 'goal-1',
          enabled: false,
        ),
      ).thenThrow(StateError('write failed'));
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Automatic updates').last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.text("That didn't save — please try again."), findsOneWidget);
    });
  });

  testWidgets('the initial health load shows a spinner, not the no-report '
      'hint', (tester) async {
    final never = Completer<GoalAgentHealth>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) => never.future),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('No report yet'), findsNothing);
  });

  testWidgets('a failed health load says so instead of claiming there is '
      'no report', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('db gone')),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't load this goal's health right now."),
      findsOneWidget,
    );
    expect(find.textContaining('No report yet'), findsNothing);
  });

  testWidgets("the standing report stays surfaced while the goal's active "
      'banners render uncapped — only its own', (tester) async {
    NudgeBannerEntry entry(String agentId, String headline) => (
      nudge: NudgeEntityView.of(
        AgentDomainEntity.goalNudge(
              id: 'ad-$agentId-$headline',
              agentId: agentId,
              status: NudgeStatus.active,
              brief: NudgeBrief(
                headline: headline,
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity,
      )!,
      subjectTitle: agentId,
      kind: NudgeBannerKind.goal,
      tapRoute: '/goals/details/$agentId',
    );
    final report =
        AgentDomainEntity.agentReport(
              id: 'report-goal-1',
              agentId: 'goal-1',
              scope: AgentReportScopes.current,
              createdAt: DateTime(2026, 8, 10),
              vectorClock: null,
              oneLiner: 'Three walks remain before Sunday.',
              tldr: '**Three walks** remain before Sunday.',
              content:
                  '## Full report\n\nThe current routine needs three walks.',
              provenance: const {
                GoalReportProvenanceKeys.sections: {
                  GoalReportSectionKeys.currentPeriod: 'One walk logged today.',
                  GoalReportSectionKeys.rollingWindow: 'Two of three so far.',
                  GoalReportSectionKeys.coverage: '',
                  GoalReportSectionKeys.nextActions: ['Walk on Saturday.'],
                },
              },
            )
            as AgentReportEntity;
    final delayedHistoricalReport = report.copyWith(
      id: 'report-delayed-history',
      createdAt: DateTime(2026, 8, 11),
      oneLiner: 'Delayed historical report must not replace the head.',
      tldr: 'Delayed historical report must not replace the head.',
      content: 'Delayed historical report must not replace the head.',
    );
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Three walks remain before Sunday.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          activeGoalNudgesProvider.overrideWith(
            (ref) async => [
              entry('goal-1', 'Shoes miss you.'),
              entry('goal-1', 'Third day on the couch.'),
              entry('goal-1', 'The stairs filed a complaint.'),
              entry('goal-2', 'Sleep is a skill too.'),
            ],
          ),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider(
            'goal-1',
          ).overrideWith((ref) async => report),
          agentReportHistoryProvider('goal-1').overrideWith(
            (ref) async => [delayedHistoricalReport, report],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // All three of THIS goal's banners — more than the host strips'
    // two-visible cap — and none of the other goal's. Each is wrapped in
    // the shared exposure tracker: detail views count too.
    expect(find.byType(GoalBannerCard), findsNWidgets(3));
    expect(find.byType(NudgeBannerExposureTracker), findsNWidgets(3));
    expect(find.textContaining('Three walks'), findsOneWidget);
    expect(find.textContaining('Delayed historical report'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
    expect(find.textContaining('The current routine needs'), findsNothing);
    // ...but the action is already on screen, unexpanded.
    expect(find.textContaining('Walk on Saturday.'), findsOneWidget);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    // Sections, under headings the APP supplies — the sentences are authored
    // in the user's language, so the composer could never wrap them in
    // headings without injecting English.
    expect(find.text('Where things stand'), findsOneWidget);
    expect(find.text('One walk logged today.'), findsOneWidget);
    expect(find.text('The wider window'), findsOneWidget);
    // The actions no longer live inside the expansion — they sit with the
    // summary in the COLLAPSED card, because an action reachable only behind
    // "Show more" is one most readers never see.
    expect(find.text("What's next"), findsNothing);
    // A slot the model left empty gets no heading rather than an empty one.
    expect(find.text('Data coverage'), findsNothing);
    // ...and it closes again, easing shut rather than snapping.
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('Where things stand'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
    // The flat composed text is the fallback, not the rendering.
    expect(find.textContaining('The current routine needs'), findsNothing);
    expect(find.text('The stairs filed a complaint.'), findsOneWidget);
    expect(find.text('Sleep is a skill too.'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GoalAgentDetailPage)),
      listen: false,
    );
    container
        .read(locallySnoozedNudgeDeadlinesProvider.notifier)
        .add(
          'ad-goal-1-The stairs filed a complaint.',
          1,
          DateTime.utc(2099),
        );
    await tester.pump();

    // Snooze quiets the SHELL dock, never this page: the goal's own page
    // keeps the banner and captions it with the return countdown instead.
    expect(find.byType(GoalBannerCard), findsNWidgets(3));
    expect(find.text('The stairs filed a complaint.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-banner-shell-return-countdown')),
      findsOneWidget,
    );
    expect(find.text('Shoes miss you.'), findsOneWidget);
    expect(find.text('Third day on the couch.'), findsOneWidget);
  });

  testWidgets("the agent's report and banners sit above the progress "
      'evidence — goal definition first, charts last', (tester) async {
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Three walks remain before Sunday.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 0,
                      ),
                  ],
                  successfulWeeks: 0,
                ),
              ],
            ),
          ),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final readTop = tester.getTopLeft(find.text('AI summary')).dy;
    final progressTop = tester.getTopLeft(find.byType(GoalProgressCard)).dy;
    expect(
      readTop,
      lessThan(progressTop),
      reason:
          'the hero stack (this week + the read) belongs directly under the '
          'goal definition, with the habit and chart evidence below it',
    );
  });

  testWidgets('on desktop the hero cards stack at the FULL content width — '
      'the week strip and the read never share a row', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Two walks landed.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 0,
                      ),
                  ],
                  successfulWeeks: 0,
                ),
              ],
            ),
          ),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final weekCard = find.byType(GoalThisWeekCard);
    final readCard = find.byKey(const ValueKey('goal-agent-read-card'));
    // Stacked, not paired — and the read LEADS: the agent's judgement
    // opens the page, with the deterministic day strip beneath it.
    expect(
      tester.getTopLeft(weekCard).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(readCard).dy),
    );
    // Both span the SAME full content measure the evidence cards use — a
    // shared row would halve them.
    final measure = tester.getSize(find.byType(GoalProgressCard)).width;
    expect(tester.getSize(weekCard).width, moreOrLessEquals(measure));
    expect(tester.getSize(readCard).width, moreOrLessEquals(measure));
  });

  testWidgets('the app-bar chat action opens the conversation, the banner '
      'CTA opens the one-tap logging sheet, and the app-bar title only '
      'appears once the header scrolls away', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    final banner =
        AgentDomainEntity.goalNudge(
              id: 'ad-goal-1',
              agentId: 'goal-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Two walks left this window.',
                cta: 'Log today',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Two walks left.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: 2,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 0,
                      ),
                  ],
                  successfulWeeks: 0,
                ),
              ],
            ),
          ),
          activeGoalNudgesProvider.overrideWith(
            (ref) async => [
              (
                nudge: NudgeEntityView.of(banner)!,
                subjectTitle: 'Move more',
                kind: NudgeBannerKind.goal,
                tapRoute: '/goals/details/goal-1',
              ),
            ],
          ),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // At rest the header H1 owns the name; the app bar copy is transparent.
    AnimatedOpacity appBarTitle() => tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Move more'),
            ),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(appBarTitle().opacity, 0);

    // The mic is the ever-present doorway: the check-ins card can sit below
    // the fold, so capture must not depend on scrolling to it.
    await tester.tap(
      find.byKey(const ValueKey('goal-detail-checkin-action')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
    Navigator.of(tester.element(find.byType(GoalCheckInComposer))).pop();
    await tester.pumpAndSettle();

    // The banner CTA performs the verb: it opens the one-tap logging
    // sheet instead of navigating to the route the page is already on.
    await tester.ensureVisible(find.text('Log today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log today'));
    await tester.pumpAndSettle();
    expect(navigated, isEmpty);
    expect(find.byType(GoalLogTodaySheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-log-today-mark-walk')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(GoalLogTodaySheet), findsNothing);

    // Scrolled away from the header, the app bar reveals the name.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(appBarTitle().opacity, 1);

    // The persistent chat doorway beside the overflow menu.
    await tester.tap(find.byKey(const ValueKey('goal-detail-chat-action')));
    await tester.pump();
    expect(navigated, ['/goals/details/goal-1/chat']);
  });

  testWidgets('a habit-less goal falls back to the anchor scroll and the '
      'reflect row opens the day assessment sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Average 10,000 steps.',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    final banner =
        AgentDomainEntity.goalNudge(
              id: 'ad-goal-1',
              agentId: 'goal-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Two averages left to move.',
                cta: 'Log today',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Averages need work.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                name: 'Daily steps',
                target: 10000,
                days: [
                  for (var day = 5; day <= 11; day++)
                    GoalProgressDay(
                      day: DateTime.utc(2026, 8, day),
                      value: day.isEven ? 11000 : 7000,
                    ),
                ],
              ),
            ),
          ),
          activeGoalNudgesProvider.overrideWith(
            (ref) async => [
              (
                nudge: NudgeEntityView.of(banner)!,
                subjectTitle: 'Move more',
                kind: NudgeBannerKind.goal,
                tapRoute: '/goals/details/goal-1',
              ),
            ],
          ),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // No habit dimensions, so there is nothing to tick off: the CTA opens the
    // check-in composer — "can't do it right now? say when you will" — rather
    // than the logging sheet, and never navigates to the route it is already
    // on.
    await tester.ensureVisible(find.text('Log today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log today'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalLogTodaySheet), findsNothing);
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
    expect(navigated, isEmpty);

    // Dismiss the composer before continuing.
    Navigator.of(tester.element(find.byType(GoalCheckInComposer))).pop();
    await tester.pumpAndSettle();

    // The reflect row opens the day assessment sheet for today.
    await tester.scrollUntilVisible(
      find.text('Reflect on today'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Reflect on today'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDayAssessmentSheet), findsOneWidget);
  });

  testWidgets('the banner CTA never self-navigates while progress is still '
      'resolving', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    final banner =
        AgentDomainEntity.goalNudge(
              id: 'ad-goal-1',
              agentId: 'goal-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Still warming up.',
                cta: 'Log today',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Loading evidence.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          // Progress never resolves: the first load is still in flight.
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) => Completer<GoalProgressView?>().future,
          ),
          activeGoalNudgesProvider.overrideWith(
            (ref) async => [
              (
                nudge: NudgeEntityView.of(banner)!,
                subjectTitle: 'Move more',
                kind: NudgeBannerKind.goal,
                tapRoute: '/goals/details/goal-1',
              ),
            ],
          ),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Log today'));
    await tester.pump();

    // Neither a navigation to the route we are on, nor a sheet for
    // evidence that has not resolved — the CTA heals once progress lands.
    expect(navigated, isEmpty);
    expect(find.byType(GoalLogTodaySheet), findsNothing);
  });

  testWidgets('a banner past its staleAt is filtered out at render time even '
      'while still active — the fresh sibling still renders', (tester) async {
    final now = DateTime(2026, 8, 10, 12);
    NudgeBannerEntry entry(String id, String headline, DateTime staleAt) => (
      nudge: NudgeEntityView.of(
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-1',
              status: NudgeStatus.active,
              brief: NudgeBrief(
                headline: headline,
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
              staleAt: staleAt,
            )
            as GoalNudgeEntity,
      )!,
      subjectTitle: 'goal-1',
      kind: NudgeBannerKind.goal,
      tapRoute: '/goals/details/goal-1',
    );

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.offTrack,
                attainment: 0.4,
                reportOneLiner: null,
                pendingProposals: 0,
                spec: null,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            activeGoalNudgesProvider.overrideWith(
              (ref) async => [
                entry(
                  'ad-stale',
                  'This one already expired.',
                  now.subtract(const Duration(minutes: 1)),
                ),
                entry(
                  'ad-fresh',
                  'This one is still current.',
                  now.add(const Duration(hours: 1)),
                ),
              ],
            ),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider(
              'goal-1',
            ).overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GoalBannerCard), findsOneWidget);
      expect(find.text('This one is still current.'), findsOneWidget);
      expect(find.text('This one already expired.'), findsNothing);
    });
  });

  testWidgets('an error-only health load with a resolved goal identity shows '
      'the unavailable notice under the report section — the not-found '
      'shell is reserved for identity failures', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('health db gone')),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The identity resolved fine, so the page renders the normal detail
    // shell (title from goalIdentity's displayName — spec is null) rather
    // than the "no longer exists" not-found state.
    expect(find.text('This goal agent no longer exists.'), findsNothing);
    expect(
      find.text("Couldn't load this goal's health right now."),
      findsOneWidget,
    );
  });

  testWidgets('past ads never render on the dashboard — the retired-banner '
      'timeline is gone', (tester) async {
    final past =
        AgentDomainEntity.goalNudge(
              id: 'ad-past',
              agentId: 'goal-1',
              status: NudgeStatus.dismissed,
              brief: const NudgeBrief(
                headline: 'Six days of quiet soles.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          goalNudgeHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => [past]),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Retired banners are agent bookkeeping, not day-to-day reading: even
    // with history present the page renders none of it.
    expect(find.textContaining('Six days of quiet soles.'), findsNothing);
    expect(find.text('Dismissed'), findsNothing);
  });

  testWidgets('the page opens in AUTO span mode: the shared range is driven '
      'to the day count that fits the content width', (tester) async {
    final habitsController = FakeHabitsController(
      HabitsState.initial(now: DateTime(2026, 8, 11)),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(() => habitsController),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The fitted span: as many authored-pitch day columns as the content
    // column holds — computed here from the same tokens the page reads, so
    // the test tracks the density rather than a magic number.
    final tokens = tester
        .element(find.byType(GoalAgentDetailPage))
        .designTokens;
    final pitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
    // The same width source the page estimates from (the harness's
    // MediaQuery, not the render box).
    final surfaceWidth = MediaQuery.sizeOf(
      tester.element(find.byType(GoalAgentDetailPage)),
    ).width;
    final contentWidth =
        math.min(
          kUnifiedGoalsContentMaxWidth,
          surfaceWidth - tokens.spacing.step6 * 2,
        ) -
        tokens.spacing.cardPadding * 2;
    final expectedFit = (contentWidth / pitch).floor().clamp(7, 90);
    expect(
      expectedFit,
      isNot(HabitsState.initial(now: DateTime(2026)).timeSpanDays),
      reason: 'the fixture must actually exercise the auto request',
    );
    expect(habitsController.lastTimeSpan, expectedFit);
  });

  testWidgets('desktop keeps chat beside watched habits', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    final completionService = MockGoalHabitCompletionService();
    when(
      () => completionService.record(
        agentId: 'goal-1',
        habitId: 'walk',
        day: DateTime.utc(2026, 8, 8),
        outcome: HabitCompletionType.fail,
      ),
    ).thenAnswer((_) async => true);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk twice each rolling week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 2,
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    GoalNudgeEntity history(
      String id,
      String headline,
      NudgeStatus status,
    ) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-1',
              status: status,
              brief: NudgeBrief(
                headline: headline,
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'digest-$id',
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    final today = DateTime.utc(2026, 8, 11);
    var progressReads = 0;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Two walks landed this week.',
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: 0,
              buffer: 1,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async {
              progressReads++;
              return GoalProgressView(
                today: today,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'walk',
                    name: 'Morning walk',
                    targetCount: 2,
                    days: [
                      for (var offset = 7; offset >= 0; offset--)
                        GoalProgressDay(
                          day: today.subtract(Duration(days: offset)),
                          value: offset == 6 || offset == 0 ? 1 : 0,
                        ),
                    ],
                    successfulWeeks: 5,
                  ),
                  GoalHabitProgressView(
                    habitId: 'monthly-walk',
                    name: 'Monthly walk',
                    targetCount: 20,
                    window: const GoalWindow.calendarMonth(),
                    days: [
                      for (var day = 1; day <= 31; day++)
                        GoalProgressDay(
                          day: DateTime.utc(2026, 8, day),
                          value: day <= 10 ? 1 : 0,
                        ),
                    ],
                    successfulWeeks: null,
                  ),
                ],
              );
            },
          ),
          goalNudgeHistoryProvider('goal-1').overrideWith(
            (ref) async => [
              history('old-1', 'Shoes by the door.', NudgeStatus.retired),
              history(
                'old-2',
                'One lap still counts.',
                NudgeStatus.dismissed,
              ),
            ],
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // §4b: the permanent chat column is gone. The pane stays MOUNTED inside
    // the slid-out drawer (so a draft survives closing), but takes no
    // pointer traffic and no layout column — the dashboard owns the width,
    // capped at the unified-Goals measure.
    expect(find.byType(GoalAgentChatPane), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
      reason: 'a closed drawer must not swallow clicks along the right edge',
    );
    // Off-screen means out of the semantics tree too: a screen reader must
    // not traverse the slid-away drawer's composer and close button.
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isTrue,
    );
    expect(
      tester.getSize(find.byType(GoalProgressCard)).width,
      lessThanOrEqualTo(kUnifiedGoalsContentMaxWidth),
    );
    // Closed drawer: the column centers in what the check-in rail leaves —
    // a fixed left-aligned measure left the right half of wide windows dead,
    // and centering in the whole window would now slide the cards under the
    // rail.
    expect(
      tester.getCenter(find.byType(GoalProgressCard)).dx,
      moreOrLessEquals(
        (desktopSize.width - kGoalTimelineRailWidth) / 2,
        epsilon: 1,
      ),
    );

    // The drawer opens from the named app-bar doorway and closes from its
    // own × — non-modal, the dashboard stays interactive throughout.
    await tester.tap(find.text('Talk to agent'));
    await tester.pumpAndSettle();
    // Open drawer: the column glides to the center of what the drawer
    // leaves free instead of hiding under it.
    expect(
      tester.getCenter(find.byType(GoalProgressCard)).dx,
      moreOrLessEquals(
        (desktopSize.width - kGoalChatDrawerWidth - kGoalTimelineRailWidth) / 2,
        epsilon: 1,
      ),
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isFalse,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isFalse,
      reason: 'the open drawer is part of the accessible page',
    );
    // The drawer header carries the same computed pill as the page: the
    // same widget fed the same status, twice on screen, never disagreeing.
    expect(find.byType(UnifiedGoalStatusPill), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(UnifiedGoalStatusPill),
        matching: find.text('On track'),
      ),
      findsNWidgets(2),
    );
    await tester.tap(find.byKey(const ValueKey('goal-chat-drawer-close')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    // The evidence sections: Habits heading over the habit cards, Signals
    // over the data dimensions (this goal has none), the old Watching list
    // gone — each habit renders once, on its own card.
    await tester.scrollUntilVisible(
      find.text('Habits'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Watching'), findsNothing);
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Monthly walk'), findsOneWidget);
    expect(find.textContaining('· calendar month'), findsOneWidget);
    expect(find.textContaining('null / 6'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('goal-habit-day-walk-2026-08-08')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-missed')));
    await tester.pumpAndSettle();
    verify(
      () => completionService.record(
        agentId: 'goal-1',
        habitId: 'walk',
        day: DateTime.utc(2026, 8, 8),
        outcome: HabitCompletionType.fail,
      ),
    ).called(1);
    expect(progressReads, 2);

    // Retired banners never render — the "Interactions" list is gone from
    // the dashboard even when history exists.
    expect(
      find.textContaining('Shoes by the door.', skipOffstage: false),
      findsNothing,
    );
    expect(
      find.textContaining('One lap still counts.', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('desktop withholds chat from a dormant goal agent', (
    tester,
  ) async {
    const desktopSize = Size(1400, 1000);
    final today = DateTime.utc(2026, 8, 11);
    setTestSurfaceSize(tester, desktopSize);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider('goal-1').overrideWith(
            (ref) async => goalIdentity.copyWith(
              lifecycle: AgentLifecycle.dormant,
            ),
          ),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec:
                  AgentDomainEntity.goalSpecVersion(
                        id: 'goal-1:spec-v1',
                        agentId: 'goal-1',
                        version: 1,
                        status: GoalSpecVersionStatus.active,
                        authoredBy: 'user',
                        title: 'Move more',
                        statement: 'Walk three times a week.',
                        criteria: const GoalCriterion.habit(
                          criterionId: 'walk',
                          habitId: 'walk',
                          window: GoalWindow.rollingDays(count: 7),
                          targetCount: 3,
                        ),
                        createdAt: DateTime(2026, 8),
                        vectorClock: null,
                      )
                      as GoalSpecVersionEntity,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 3,
                  successfulWeeks: null,
                  days: [
                    for (var offset = 6; offset >= 0; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 0,
                      ),
                  ],
                ),
              ],
            ),
          ),
          goalNudgeHistoryProvider('goal-1').overrideWith((ref) async => []),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Move more'), findsNWidgets(3));
    // No Edit doorway on a dormant goal, so the header keeps the statement
    // visible — otherwise the goal's definition has no surface at all.
    expect(find.text('Walk three times a week.'), findsOneWidget);
    expect(find.byType(GoalAgentChatPane), findsNothing);
    expect(find.text('Talk to agent'), findsNothing);
    expect(find.text('Update now'), findsNothing);
    expect(find.byType(PopupMenuButton<HabitCompletionType>), findsNothing);
    expect(find.byType(ChangeSetSummaryCard), findsNothing);

    // The desktop reading measure holds without chat: a dormant goal's
    // cards must not stretch across the whole 1400px pane.
    expect(
      tester.getSize(find.byKey(const ValueKey('goal-agent-read-card'))).width,
      lessThanOrEqualTo(kUnifiedGoalsContentMaxWidth),
    );
  });

  testWidgets('a first health load failure does not claim a data-gap verdict', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) => Future.error(StateError('unavailable'))),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          goalNudgeHistoryProvider('goal-1').overrideWith((ref) async => []),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't load this goal's health right now."),
      findsOneWidget,
    );
    expect(find.text('Not enough data'), findsNothing);
  });

  testWidgets('a completed system-back pop persists the Agents root '
      'through NavService — and canPop stays true for the iOS gesture', (
    tester,
  ) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizedBox.shrink(),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    // Stacked like the real Agents delegate stacks the detail page.
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const GoalAgentDetailPage(agentId: 'goal-1'),
          ),
        );
    await tester.pumpAndSettle();
    final popScope =
        tester.widget(
              find.byWidgetPredicate((w) => w is PopScope),
            )
            as PopScope;
    expect(popScope.canPop, isTrue, reason: 'false kills the iOS gesture');

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(navigated, ['/goals']);
  });

  testWidgets('the AppBar back button routes to the unified Goals root', (
    tester,
  ) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(navigated, ['/goals']);
  });

  testWidgets('delete failures stay on the goal and a later success returns '
      'to the list', (
    tester,
  ) async {
    final service = MockGoalAgentService();
    var attempts = 0;
    when(
      () => service.deleteGoalAgent('goal-1'),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw StateError('database unavailable');
      return true;
    });
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          goalAgentServiceProvider.overrideWithValue(service),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this goal?'), findsOneWidget);
    verifyNever(() => service.deleteGoalAgent(any()));

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this goal?'), findsNothing);
    verifyNever(() => service.deleteGoalAgent(any()));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(DesignSystemButton, 'Delete goal'),
    );
    await tester.pumpAndSettle();

    expect(find.text("That didn't save — please try again."), findsOneWidget);
    expect(navigated, isEmpty);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DesignSystemButton, 'Delete goal'),
    );
    await tester.pumpAndSettle();

    verify(() => service.deleteGoalAgent('goal-1')).called(2);
    expect(navigated, ['/goals']);
  });

  testWidgets('the overflow menu opens the shared agent internals panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          agentStateProvider('goal-1').overrideWith((ref) async => null),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider(
            'goal-1',
          ).overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Open agent internals'), findsOneWidget);

    await tester.tap(find.text('Open agent internals'));
    await tester.pumpAndSettle();

    expect(find.byType(AgentInternalsPanel), findsOneWidget);
    expect(find.text('Agent internals'), findsOneWidget);
  });

  testWidgets('a stale link or non-goal agent renders the not-found state '
      'instead of a blank healthy page', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'task-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider('task-1').overrideWith((ref) async => null),
          goalAgentHealthProvider('task-1').overrideWith(
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
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This goal agent no longer exists.'),
      findsOneWidget,
    );
    expect(find.textContaining('No report yet'), findsNothing);
  });

  testWidgets('the desktop drawer opens from Ask why with a pre-filled '
      'composer, closes on Esc and on an outside tap, and never clobbers '
      'an existing draft', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    final now = DateTime(2026, 8, 13, 12);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          mediaQueryData: const MediaQueryData(size: desktopSize),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Two walks landed this week.',
                pendingProposals: 0,
                spec: spec,
                direction: null,
                deficit: 0,
                buffer: 1,
              ),
            ),
            goalAgentProgressViewForSpanProvider((
              agentId: 'goal-1',
              historyDays: 14,
            )).overrideWith(
              (ref) async => GoalProgressView(
                today: DateTime.utc(2026, 8, 13),
              ),
            ),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith(
              (ref) async =>
                  AgentDomainEntity.agentReport(
                        id: 'report-1',
                        agentId: 'goal-1',
                        scope: AgentReportScopes.current,
                        createdAt: now.subtract(const Duration(hours: 2)),
                        vectorClock: null,
                        oneLiner: 'Two walks landed this week.',
                        tldr: 'Two walks landed this week.',
                        content: 'Two walks landed this week.',
                        provenance: {'specVersionId': 'goal-1:spec-v1'},
                      )
                      as AgentReportEntity,
            ),
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The narrative wears its age (§4b freshness contract).
      expect(find.text('as of 2 h ago'), findsOneWidget);

      bool drawerIgnoring() => tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(GoalAgentChatPane),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring;
      expect(drawerIgnoring(), isTrue);

      // Ask why: the drawer opens with the computed verdict pre-filled.
      await tester.tap(find.byKey(const ValueKey('goal-detail-ask-why')));
      await tester.pumpAndSettle();
      expect(drawerIgnoring(), isFalse);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoalAgentDetailPage)),
        listen: false,
      );
      expect(
        container.read(goalChatControllerProvider('goal-1')).draft,
        'Why is this goal On track right now?',
      );

      // Esc closes — the drawer takes focus on open, so the shortcut has a
      // focus path before the user ever clicks into the composer.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(drawerIgnoring(), isTrue);

      // Talk-to reopens; a click on the dashboard closes it (non-modal — the
      // same click still reaches the dashboard, there is no barrier).
      await tester.tap(find.text('Talk to agent'));
      await tester.pumpAndSettle();
      expect(drawerIgnoring(), isFalse);
      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();
      expect(drawerIgnoring(), isTrue);

      // A composer with words in it is never clobbered by Ask why.
      container
          .read(goalChatControllerProvider('goal-1').notifier)
          .updateDraft('my own words');
      await tester.tap(find.byKey(const ValueKey('goal-detail-ask-why')));
      await tester.pumpAndSettle();
      expect(
        container.read(goalChatControllerProvider('goal-1')).draft,
        'my own words',
      );
    });
  });

  testWidgets('mobile Ask why pre-fills the composer and opens the chat '
      'route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: 'Three walks remain before Sunday.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('goal-detail-ask-why')),
    );
    await tester.tap(find.byKey(const ValueKey('goal-detail-ask-why')));
    await tester.pump();
    expect(navigated, ['/goals/details/goal-1/chat']);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GoalAgentDetailPage)),
      listen: false,
    );
    expect(
      container.read(goalChatControllerProvider('goal-1')).draft,
      'Why is this goal Behind right now?',
    );
  });

  testWidgets('the overflow menu refreshes the read and jumps to the About '
      'section', (tester) async {
    final completionService = MockGoalHabitCompletionService();
    when(
      () => completionService.requestReportRefresh('goal-1'),
    ).thenReturn('refresh-run');
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Update read: the §4b overflow shortcut to the same refresh the
    // automation row offers.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    // `.last`: the automation row on the read card shares the label with
    // the overflow entry; the menu overlay renders last.
    await tester.tap(find.text('Update now').last);
    await tester.pumpAndSettle();
    verify(() => completionService.requestReportRefresh('goal-1')).called(1);

    // The reload affordances live on the read card itself now — no
    // expander, matching the task agent section.
    expect(
      find.widgetWithText(DesignSystemButton, 'Update now'),
      findsOneWidget,
    );
    expect(find.text('About this agent'), findsNothing);
  });

  testWidgets('a goal with habit dimensions renders the goal-scoped '
      'completion-rate card — scoped from the SAME retained progress '
      'snapshot, not the (possibly newer) spec', (tester) async {
    // A metric-only spec beside habit progress models the mid-revision
    // window: health has advanced to a new spec while the progress
    // deliberately retains the old one. The chart must gate AND scope from
    // the progress, or it flashes an empty chart scoped by habits the
    // visible rows do not show.
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    final progress30 = Completer<GoalProgressView?>();
    final progress90 = Completer<GoalProgressView?>();
    final progressV2 = Completer<GoalProgressView?>();
    var currentSpec = spec;
    GoalProgressView progressFor(int targetCount) => GoalProgressView(
      today: today,
      habits: [
        GoalHabitProgressView(
          habitId: 'walk',
          name: 'Walk',
          targetCount: targetCount,
          days: [
            for (var offset = 6; offset >= 0; offset--)
              GoalProgressDay(
                day: today.subtract(Duration(days: offset)),
                value: 0,
              ),
          ],
          successfulWeeks: 0,
        ),
      ],
    );
    final habitsController = FakeHabitsController(
      HabitsState.initial(now: DateTime(2026, 8, 11)).copyWith(
        // An ACTIVE definition for the goal's habit: the scoped chart
        // suppresses itself when every referenced habit is deactivated.
        habitDefinitions: [habitFlossing.copyWith(id: 'walk', name: 'Walk')],
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(() => habitsController),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Two walks landed.',
              pendingProposals: 0,
              spec: currentSpec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 14,
          )).overrideWith((ref) async => progressFor(3)),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 30,
          )).overrideWith(
            (ref) => currentSpec.id == 'goal-1:spec-v2'
                ? progressV2.future
                : progress30.future,
          ),
          goalAgentProgressViewForSpanProvider((
            agentId: 'goal-1',
            historyDays: 90,
          )).overrideWith((ref) => progress90.future),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The "Also in {goal}" suffix is gone — a card lists its own evidence,
    // not the other goals watching the same habit.
    expect(find.textContaining('Also in'), findsNothing);

    // ONE page-level range picker on the Habits heading governs every day
    // track and the chart — the chart card's own picker is hidden here, so
    // the page never renders two controls fighting over one shared span.
    expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
    expect(find.textContaining('0 of 3 · rolling 7 days'), findsOneWidget);
    // The full-width hero stack pushes the evidence sections below the fold
    // on the default test surface.
    tester
        .widget<TimeSpanSegmentedControl>(
          find.byType(TimeSpanSegmentedControl),
        )
        .onValueChanged(30);
    await tester.pump();
    expect(habitsController.lastTimeSpan, 30);
    habitsController.emit(
      habitsController.state.copyWith(timeSpanDays: 30),
    );
    await tester.pump();

    // The new provider-family key is unresolved, but established evidence
    // remains on screen instead of flashing the whole progress section away.
    expect(find.textContaining('0 of 3 · rolling 7 days'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-habit-plot-walk')), findsOneWidget);

    progress30.complete(progressFor(5));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 of 5 · rolling 7 days'), findsOneWidget);
    expect(find.textContaining('0 of 3 · rolling 7 days'), findsNothing);

    tester
        .widget<TimeSpanSegmentedControl>(
          find.byType(TimeSpanSegmentedControl),
        )
        .onValueChanged(90);
    habitsController.emit(
      habitsController.state.copyWith(timeSpanDays: 90),
    );
    await tester.pump();
    expect(find.textContaining('0 of 5 · rolling 7 days'), findsOneWidget);

    progress90.completeError(StateError('range unavailable'));
    await tester.pump();
    await tester.pump();

    // A failed replacement cannot leave 30-day evidence under a 90-day
    // selector. The page snaps back to the last settled span and suppresses
    // the controller-backed chart until that rollback lands.
    expect(habitsController.lastTimeSpan, 30);
    expect(
      tester
          .widget<TimeSpanSegmentedControl>(
            find.byType(TimeSpanSegmentedControl),
          )
          .timeSpanDays,
      30,
    );
    expect(find.textContaining('0 of 5 · rolling 7 days'), findsOneWidget);
    expect(find.byType(HabitCompletionRateChart), findsNothing);

    habitsController.emit(
      habitsController.state.copyWith(timeSpanDays: 30),
    );
    await tester.pump();

    // The goal-scoped chart card: same shell as the habits page, its
    // own title, the chart scoped to this goal's criterion habit ids.
    expect(find.text('Completion rate · this goal'), findsOneWidget);
    expect(
      tester
          .widget<HabitCompletionRateChart>(
            find.byType(HabitCompletionRateChart),
          )
          .habitIds,
      {'walk'},
    );

    currentSpec = spec.copyWith(id: 'goal-1:spec-v2', version: 2);
    ProviderScope.containerOf(
        tester.element(find.byType(GoalAgentDetailPage)),
        listen: false,
      )
      ..invalidate(goalAgentHealthProvider('goal-1'))
      ..invalidate(
        goalAgentProgressViewForSpanProvider((
          agentId: 'goal-1',
          historyDays: 30,
        )),
      );
    await tester.pump();
    await tester.pump();

    // A same-family-key reload after the active spec changes must not promote
    // the previous spec's AsyncValue as though it belonged to the new spec.
    expect(find.textContaining('0 of 5 · rolling 7 days'), findsNothing);
    expect(find.byKey(const ValueKey('goal-habit-plot-walk')), findsNothing);

    progressV2.complete(progressFor(7));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 of 7 · rolling 7 days'), findsOneWidget);
  });

  testWidgets("the read's age ticks across its bucket boundary without any "
      'provider update', (tester) async {
    var current = DateTime(2026, 8, 13, 12, 59, 30);
    final generatedAt = DateTime(2026, 8, 13, 12);
    // The report only counts as the standing read while it matches the
    // ACTIVE spec version.
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    await withClock(Clock(() => current), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: 'Seven for seven.',
                pendingProposals: 0,
                spec: spec,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            goalAgentProgressViewForSpanProvider((
              agentId: 'goal-1',
              historyDays: 14,
            )).overrideWith(
              (ref) async => GoalProgressView(today: DateTime.utc(2026, 8, 13)),
            ),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith(
              (ref) async =>
                  AgentDomainEntity.agentReport(
                        id: 'report-1',
                        agentId: 'goal-1',
                        scope: AgentReportScopes.current,
                        createdAt: generatedAt,
                        vectorClock: null,
                        oneLiner: 'Seven for seven.',
                        tldr: 'Seven for seven.',
                        content: 'Seven for seven.',
                        provenance: const {
                          'specVersionId': 'goal-1:spec-v1',
                        },
                      )
                      as AgentReportEntity,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('as of 59 min ago'), findsOneWidget);

      // Nothing rebuilds the page — only the boundary timer may. Rendered
      // once at build, "59 min ago" would sit there for hours.
      current = current.add(const Duration(seconds: 40));
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('as of 1 h ago'), findsOneWidget);

      // Drain the re-armed hourly timer so the test ends clean.
      current = current.add(const Duration(hours: 1, seconds: 2));
      await tester.pump(const Duration(hours: 1, seconds: 2));
    });
  });

  testWidgets('Ask why never quotes a suppressed No-data verdict', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          // No register yet, but a standing one-liner: the page suppresses
          // the No-data pill as self-contradictory — Ask why must not
          // resurrect that verdict in the composer.
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: null,
              attainment: null,
              reportOneLiner: 'Two days in.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Two days in.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-detail-ask-why')),
      findsNothing,
    );
  });

  testWidgets('a marathon-length agent name cannot overflow the desktop '
      'toolbar — the Talk-to button ellipsizes inside its cap', (
    tester,
  ) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider('goal-1').overrideWith(
            (ref) async => goalIdentity.copyWith(
              displayName:
                  'The Grand Unified Everything Fitness Longevity '
                  'Mobility And General Flourishing Programme',
            ),
          ),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.atRisk,
              attainment: 0.8,
              reportOneLiner: 'Close, not there.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              // A deficit folds the recovery hint into the drawer pill too.
              deficit: 2,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = tester.getSize(
      find.byKey(const ValueKey('goal-detail-talk-to')),
    );
    final measure = tester
        .element(find.byType(GoalAgentDetailPage))
        .designTokens
        .spacing
        .step13;
    expect(button.width, lessThanOrEqualTo(measure));

    // The drawer header carries the same unbounded name over an Expanded
    // chat pane — capped at two lines, it cannot overflow the drawer's
    // column either.
    await tester.tap(find.byKey(const ValueKey('goal-detail-talk-to')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // And it folds the recovery hint into its pill, like the page header.
    expect(
      find.text('At risk · 2 successful days needed to recover'),
      findsNWidgets(2),
    );
  });

  testWidgets('a stale flag with NO displayed read renders no out-of-date '
      'notice — there is nothing whose freshness could be judged', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 13, 12);
    final agentState =
        AgentDomainEntity.agentState(
              id: 'goal-1:state',
              agentId: 'goal-1',
              slots: const AgentSlots(),
              updatedAt: now,
              vectorClock: null,
              reportStaleAt: now,
            )
            as AgentStateEntity;
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 11)),
              ),
            ),
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => goalIdentity),
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
            agentStateProvider(
              'goal-1',
            ).overrideWith((ref) async => agentState),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No report yet'), findsOneWidget);
      expect(find.text('Out of date'), findsNothing);
    });
  });

  testWidgets('a legacy report with content but no one-liner still counts as '
      "report content for the About section's freshness state", (
    tester,
  ) async {
    final now = DateTime(2026, 8, 13, 12);
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Move more',
              statement: 'Walk this week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'walk',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final agentState =
        AgentDomainEntity.agentState(
              id: 'goal-1:state',
              agentId: 'goal-1',
              slots: const AgentSlots(),
              updatedAt: now,
              vectorClock: null,
              reportStaleAt: now,
            )
            as AgentStateEntity;
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 13)),
              ),
            ),
            agentIdentityProvider('goal-1').overrideWith(
              (ref) async => goalIdentity.copyWith(
                config: const AgentConfig(automaticUpdatesEnabled: true),
              ),
            ),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: null,
                pendingProposals: 0,
                spec: spec,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            goalAgentProgressViewForSpanProvider((
              agentId: 'goal-1',
              historyDays: 14,
            )).overrideWith(
              (ref) async => GoalProgressView(today: DateTime.utc(2026, 8, 13)),
            ),
            agentStateProvider(
              'goal-1',
            ).overrideWith((ref) async => agentState),
            selfTargetedPendingChangeSetsProvider(
              'goal-1',
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              'goal-1',
            ).overrideWith((ref) async => {}),
            agentReportProvider('goal-1').overrideWith(
              (ref) async =>
                  AgentDomainEntity.agentReport(
                        id: 'report-1',
                        agentId: 'goal-1',
                        scope: AgentReportScopes.current,
                        createdAt: now.subtract(const Duration(hours: 3)),
                        vectorClock: null,
                        // No oneLiner/tldr: the legacy report shape.
                        content: 'Two walks landed this week.',
                        provenance: const {
                          'specVersionId': 'goal-1:spec-v1',
                        },
                      )
                      as AgentReportEntity,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The read card demotes to the notice (a report IS displayed) and
      // the automation row on the same card echoes it: a legacy report
      // with content but no one-liner still counts as report content.
      expect(find.text('Out of date'), findsNWidgets(2));
    });
  });

  testWidgets('a pending revision proposal mounts the shared change-set card '
      'on the dashboard', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven.',
              pendingProposals: 1,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
  });

  testWidgets('the inline check-ins card reaches the full timeline', (
    tester,
  ) async {
    // Phone-sized on purpose: the card previews three beats inline here,
    // whereas a wide window hoists the whole rail and needs no way through.
    const phoneSize = Size(390, 1400);
    setTestSurfaceSize(tester, phoneSize);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    final at = DateTime(2026, 8, 11, 9);
    GoalAudioCheckIn beat(String id, int minutesAgo) => GoalAudioCheckIn(
      JournalAudio(
        meta: Metadata(
          id: id,
          createdAt: at.subtract(Duration(minutes: minutesAgo)),
          updatedAt: at,
          dateFrom: at.subtract(Duration(minutes: minutesAgo)),
          dateTo: at,
        ),
        data: AudioData(
          dateFrom: at,
          dateTo: at,
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 10),
        ),
        entryText: EntryText(plainText: 'note $id'),
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: phoneSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('db gone')),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
          goalTimelineItemsProvider('goal-1').overrideWithValue([
            for (var i = 0; i < 5; i++) beat('c$i', i),
          ]),
          goalCaptureTargetProvider(
            'goal-1',
          ).overrideWith((ref) async => 'goal-entry-1'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The preview hides two beats, so the way through to the rest is offered
    // — and it goes to the timeline route, not back to the goals list.
    await tester.ensureVisible(
      find.byKey(const ValueKey('goal-checkin-see-all')),
    );
    await tester.tap(find.byKey(const ValueKey('goal-checkin-see-all')));
    await tester.pumpAndSettle();
    expect(navigated, ['/goals/details/goal-1/timeline']);

    // The mic opens the composer with whatever the agent last published as
    // its prepared line, so opening it costs no inference.
    await tester.tap(
      find.byKey(const ValueKey('goal-detail-checkin-action')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
  });

  testWidgets('desktop still offers the drawer while health is erroring — '
      'the header pill is simply absent', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('db gone')),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // A verdictless page keeps the conversation reachable; neither the page
    // header nor the drawer wears a pill it cannot back.
    await tester.tap(find.byKey(const ValueKey('goal-detail-talk-to')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalAgentChatPane), findsOneWidget);
    expect(find.byType(UnifiedGoalStatusPill), findsNothing);
  });

  testWidgets('a narrow desktop pane keeps the drawer a pure overlay — the '
      'column never gets squeezed below a usable width', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        // A 500px sidebar stand-in: the page pane is 900px wide, so
        // subtracting the 400px drawer would leave 500 — under the fold
        // width — and the shift must not happen.
        const Row(
          children: [
            SizedBox(width: 500),
            Expanded(child: GoalAgentDetailPage(agentId: 'goal-1')),
          ],
        ),
        mediaQueryData: const MediaQueryData(size: desktopSize),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(
              HabitsState.initial(now: DateTime(2026, 8, 11)),
            ),
          ),
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => goalIdentity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven.',
              pendingProposals: 0,
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportProvider('goal-1').overrideWith((ref) async => null),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final closedCenter = tester.getCenter(find.text('AI summary')).dx;
    await tester.tap(find.byKey(const ValueKey('goal-detail-talk-to')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.text('AI summary')).dx,
      moreOrLessEquals(closedCenter, epsilon: 1),
      reason:
          'below the fold width the drawer overlays instead of shifting '
          'the column into a sliver',
    );
  });
}
