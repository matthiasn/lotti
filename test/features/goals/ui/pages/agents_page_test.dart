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

  testWidgets('shows the empty state when no goal agents exist', (
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
    expect(
      find.text(
        'No goal agents yet. Create one and it will quietly watch your '
        'progress.',
      ),
      findsOneWidget,
    );
    expect(find.text('New goal agent'), findsOneWidget);
  });

  testWidgets('a fitness and a sleep agent render side by side with their '
      'health at a glance', (tester) async {
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
            (ref) async => (
              trackStatus: GoalTrackStatus.offTrack,
              attainment: 0.55,
              reportOneLiner: 'Averaging 5.5k of 10k steps.',
              pendingProposals: 1,
              spec: null,
            ),
          ),
          goalAgentHealthProvider('goal-sleep').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expedition fitness'), findsOneWidget);
    expect(find.text('Off track'), findsOneWidget);
    expect(find.text('55% of target'), findsOneWidget);
    expect(find.text('Averaging 5.5k of 10k steps.'), findsOneWidget);
    expect(find.text('Proposal awaiting review'), findsOneWidget);

    expect(find.text('Sleep 8h'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('100% of target'), findsOneWidget);
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
    expect(find.textContaining('No goal agents yet'), findsNothing);
  });
}
