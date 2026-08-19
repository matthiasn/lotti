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
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('identifies the agent and its goal above the durable composer', (
    tester,
  ) async {
    final identity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.goalAgent,
              displayName: 'Juno',
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
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Fitness',
              statement: 'Show up for three workouts each week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'gym',
                habitId: 'gym',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentChatPane(agentId: 'goal-1')),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
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
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juno'), findsOneWidget);
    // The subtitle is current STATE, not the aspiration statement — the
    // statement next to a Behind chip elsewhere read as a status claim.
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Not enough data'), findsNothing);
    expect(
      find.text('Show up for three workouts each week.'),
      findsNothing,
    );
    expect(find.text('Talk to Juno…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'What should I do today?');
    await tester.pump();
    expect(find.byIcon(LottiIcons.send), findsOneWidget);
  });

  testWidgets('an unresolved health load shows NO coarse label — loading is '
      'not a data-gap verdict', (tester) async {
    final identity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.goalAgent,
              displayName: 'Juno',
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
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentChatPane(agentId: 'goal-1')),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
          // Never resolves: the first health load is still in flight.
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) => Completer<GoalAgentHealth>().future),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Juno'), findsOneWidget);
    expect(find.text('Not enough data'), findsNothing);
    expect(find.text('On track'), findsNothing);
  });
}
