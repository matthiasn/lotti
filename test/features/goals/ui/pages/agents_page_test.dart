import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';

import '../../../../widget_test_utils.dart';

void main() {
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

  GoalAgentHealth health({
    GoalTrackStatus? trackStatus,
    String? reportOneLiner,
    int pendingProposals = 0,
    GoalHealthDirection? direction,
  }) => (
    trackStatus: trackStatus,
    attainment: null,
    reportOneLiner: reportOneLiner,
    pendingProposals: pendingProposals,
    spec: null,
    direction: direction,
  );

  testWidgets('the empty state is the first-run explainer, not a bare line', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('One agent per goal'), findsOneWidget);
    // The cost-honesty line and the CTA are part of the explainer.
    expect(find.textContaining('fractions of a cent'), findsOneWidget);
    expect(find.text('Set an intention'), findsOneWidget);
  });

  testWidgets('a row shows the coarse health chip, the executive summary '
      'and the direction arrow — and NO percentage', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-fit', 'Expedition fitness'),
              identity('goal-sleep', 'Sleep 8h'),
            ],
          ),
          goalAgentHealthProvider('goal-fit').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.offTrack,
              reportOneLiner: 'The gym has been quiet since Tuesday.',
              pendingProposals: 1,
              direction: GoalHealthDirection.down,
            ),
          ),
          goalAgentHealthProvider('goal-sleep').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.onTrack,
              reportOneLiner: 'Seven solid nights running.',
              direction: GoalHealthDirection.up,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Coarse health: offTrack → Behind, onTrack → Healthy.
    expect(find.text('Behind'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
    // The runtime status vocabulary never reaches the chip.
    expect(find.text('Off track'), findsNothing);
    expect(find.text('On track'), findsNothing);

    // Executive summaries render; no percentage anywhere.
    expect(find.text('The gym has been quiet since Tuesday.'), findsOneWidget);
    expect(find.text('Seven solid nights running.'), findsOneWidget);
    expect(find.textContaining('% of target'), findsNothing);

    // Needs-you badge on the goal with a pending proposal.
    expect(find.text('Proposal awaiting review'), findsOneWidget);

    // Direction arrows: down for the slipping goal, up for the healthy one.
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
  });

  testWidgets('recovering reads Restarting (never a failure), and a goal '
      'with no register yet reads Not enough data', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-a', 'Stretch daily'),
              identity('goal-b', 'Read before bed'),
            ],
          ),
          goalAgentHealthProvider('goal-a').overrideWith(
            (ref) async => health(trackStatus: GoalTrackStatus.recovering),
          ),
          // No trackStatus at all — no register has been written yet.
          goalAgentHealthProvider(
            'goal-b',
          ).overrideWith((ref) async => health()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restarting'), findsOneWidget);
    expect(find.text('Not enough data'), findsOneWidget);
  });

  testWidgets('a single register yields no direction arrow', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-a', 'Stretch daily')],
          ),
          goalAgentHealthProvider('goal-a').overrideWith(
            (ref) async => health(trackStatus: GoalTrackStatus.onTrack),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_flat_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
  });

  testWidgets('a failed first load says so instead of a blank page', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => throw StateError('agent db unavailable'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't load your agents right now."),
      findsOneWidget,
    );
    expect(find.text('One agent per goal'), findsNothing);
  });
}
