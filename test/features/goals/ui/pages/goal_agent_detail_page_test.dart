import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_banner_strip.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('renders the health header, statement, no-report hint and '
      'timeline section', (tester) async {
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
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.atRisk,
              attainment: 0.64,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: spec,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportHistoryProvider('goal-1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Move more'), findsOneWidget);
    expect(find.text('At risk'), findsOneWidget);
    expect(find.text('64% of target'), findsOneWidget);
    expect(
      find.text('Average 10,000 steps per day over a rolling week.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'No report yet — the agent reports after its first meaningful '
        'change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Interactions'), findsOneWidget);
  });

  testWidgets('a standing report renders its one-liner instead of the '
      'no-report hint', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: 'Seven for seven. Keep coasting.',
              pendingProposals: 0,
              spec: null,
            ),
          ),
          selfTargetedPendingChangeSetsProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
          agentMessagesByThreadProvider(
            'goal-1',
          ).overrideWith((ref) async => {}),
          agentReportHistoryProvider('goal-1').overrideWith((ref) async => []),
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
          agentReportHistoryProvider('goal-1').overrideWith((ref) async => []),
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

  testWidgets("the goal's active banners render here uncapped — only its "
      'own', (tester) async {
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
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentDetailPage(agentId: 'goal-1'),
        overrides: [
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.4,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
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
          agentReportHistoryProvider('goal-1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // All three of THIS goal's banners — more than the host strips'
    // two-visible cap — and none of the other goal's. Each is wrapped in
    // the shared exposure tracker: detail views count too.
    expect(find.byType(GoalBannerCard), findsNWidgets(3));
    expect(find.byType(GoalBannerExposureTracker), findsNWidgets(3));
    expect(find.text('The stairs filed a complaint.'), findsOneWidget);
    expect(find.text('Sleep is a skill too.'), findsNothing);
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
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
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
          agentReportHistoryProvider('goal-1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Six days of quiet soles.'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
  });
}
