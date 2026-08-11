import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _MockGoalHabitCompletionService extends Mock
    implements GoalHabitCompletionService {}

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
    final completionService = _MockGoalHabitCompletionService();
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
          goalAgentProgressViewProvider('goal-1').overrideWith(
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

    // App bar + detail header both carry the goal name.
    expect(find.text('Move more'), findsNWidgets(2));
    // Runtime atRisk collapses to the handover's coarse Behind vocabulary,
    // and the detail surface never displays a percentage.
    expect(find.text('Behind'), findsOneWidget);
    expect(find.text('Trending up'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.text('At risk'), findsNothing);
    expect(find.textContaining('% of target'), findsNothing);
    expect(find.text('This rolling week'), findsOneWidget);
    expect(find.text('Daily steps'), findsOneWidget);
    expect(
      find.textContaining(
        'Average 10,000 steps per day over a rolling week.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No report yet — the agent reports after its first meaningful '
        'change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Interactions'), findsNothing);
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
    await tester.tap(find.text('Edit goal'));
    expect(navigated, ['/agents/details/goal-1/edit']);
    navigated.clear();

    await tester.ensureVisible(find.text('Talk to Move more'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talk to Move more'));
    await tester.pump();
    expect(navigated, ['/agents/details/goal-1/chat']);
  });

  testWidgets('a standing report renders its one-liner instead of the '
      'no-report hint', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
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
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seven for seven. Keep coasting.'), findsOneWidget);
    expect(find.textContaining('No report yet'), findsNothing);
  });

  testWidgets('the initial health load shows a spinner, not the no-report '
      'hint', (tester) async {
    final never = Completer<GoalAgentHealth>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
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
    GoalBannerEntry entry(String agentId, String headline) => (
      nudge:
          AgentDomainEntity.goalNudge(
                id: 'ad-$agentId-$headline',
                agentId: agentId,
                status: GoalNudgeStatus.active,
                brief: GoalNudgeBrief(
                  headline: headline,
                  tone: GoalNudgeTone.nudge,
                  animation: GoalBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8, 10),
                updatedAt: DateTime(2026, 8, 10),
                vectorClock: null,
              )
              as GoalNudgeEntity,
      goalTitle: agentId,
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
          goalNudgeExposureFlushProvider.overrideWithValue((_, _) {}),
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
    expect(find.byType(GoalBannerExposureTracker), findsNWidgets(3));
    expect(find.textContaining('Three walks'), findsOneWidget);
    expect(find.textContaining('Delayed historical report'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
    expect(find.textContaining('The current routine needs'), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(find.textContaining('The current routine needs'), findsOneWidget);
    expect(find.text('The stairs filed a complaint.'), findsOneWidget);
    expect(find.text('Sleep is a skill too.'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GoalAgentDetailPage)),
      listen: false,
    );
    container
        .read(locallySnoozedNudgeDeadlinesProvider.notifier)
        .add('ad-goal-1-The stairs filed a complaint.', DateTime.utc(2099));
    await tester.pump();

    expect(find.byType(GoalBannerCard), findsNWidgets(2));
    expect(find.text('The stairs filed a complaint.'), findsNothing);
    expect(find.text('Shoes miss you.'), findsOneWidget);
    expect(find.text('Third day on the couch.'), findsOneWidget);
  });

  testWidgets('a banner past its staleAt is filtered out at render time even '
      'while still active — the fresh sibling still renders', (tester) async {
    final now = DateTime(2026, 8, 10, 12);
    GoalBannerEntry entry(String id, String headline, DateTime staleAt) => (
      nudge:
          AgentDomainEntity.goalNudge(
                id: id,
                agentId: 'goal-1',
                status: GoalNudgeStatus.active,
                brief: GoalNudgeBrief(
                  headline: headline,
                  tone: GoalNudgeTone.nudge,
                  animation: GoalBannerAnimation.steady,
                ),
                briefDigest: 'd-$id',
                createdAt: DateTime(2026, 8, 9),
                updatedAt: DateTime(2026, 8, 9),
                vectorClock: null,
                staleAt: staleAt,
              )
              as GoalNudgeEntity,
      goalTitle: 'goal-1',
    );

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: 'goal-1'),
          overrides: [
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
            goalNudgeExposureFlushProvider.overrideWithValue((_, _) {}),
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

  testWidgets('past ads stay browsable in the timeline with their localized '
      'outcome', (tester) async {
    final past =
        AgentDomainEntity.goalNudge(
              id: 'ad-past',
              agentId: 'goal-1',
              status: GoalNudgeStatus.dismissed,
              brief: const GoalNudgeBrief(
                headline: 'Six days of quiet soles.',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
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
    expect(find.textContaining('Six days of quiet soles.'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
  });

  testWidgets('desktop keeps chat beside watched habits and complete banner '
      'history', (tester) async {
    const desktopSize = Size(1400, 1000);
    setTestSurfaceSize(tester, desktopSize);
    final completionService = _MockGoalHabitCompletionService();
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
      GoalNudgeStatus status,
    ) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-1',
              status: status,
              brief: GoalNudgeBrief(
                headline: headline,
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
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
          goalAgentProgressViewProvider('goal-1').overrideWith(
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
              history('old-1', 'Shoes by the door.', GoalNudgeStatus.retired),
              history(
                'old-2',
                'One lap still counts.',
                GoalNudgeStatus.dismissed,
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

    expect(find.byType(GoalAgentChatPane), findsOneWidget);
    expect(find.text('Talk to Move more'), findsNothing);
    expect(find.text('Watching'), findsOneWidget);
    expect(find.text('Morning walk'), findsNWidgets(2));
    expect(find.text('Monthly walk'), findsNWidgets(2));
    expect(find.text('20× · calendar month'), findsNWidgets(2));
    expect(find.textContaining('null / 6'), findsNothing);
    expect(find.textContaining('signals listed here'), findsOneWidget);
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('goal-watching-meta-walk')),
          )
          .dy,
      greaterThan(
        tester
            .getCenter(
              find.byKey(const ValueKey('goal-watching-name-walk')),
            )
            .dy,
      ),
    );

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

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shoes by the door.'), findsOneWidget);
    expect(find.textContaining('One lap still counts.'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
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
              spec: null,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          activeGoalNudgesProvider.overrideWith((ref) async => []),
          goalAgentProgressViewProvider('goal-1').overrideWith(
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

    expect(find.text('Move more'), findsNWidgets(2));
    expect(find.byType(GoalAgentChatPane), findsNothing);
    expect(find.text('Talk to Move more'), findsNothing);
    expect(find.text('Update now'), findsNothing);
    expect(find.byType(PopupMenuButton<HabitCompletionType>), findsNothing);
    expect(find.byType(ChangeSetSummaryCard), findsNothing);
  });

  testWidgets('a first health load failure does not claim a data-gap verdict', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
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
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const GoalAgentDetailPage(agentId: 'goal-1'),
            ),
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
    expect(navigated, ['/agents']);
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
    expect(navigated, ['/agents']);
  });

  testWidgets('the overflow menu opens the shared agent internals panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
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
}
