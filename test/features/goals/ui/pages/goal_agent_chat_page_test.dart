import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_chat_page.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('uses the agent name and returns to that goal detail', (
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
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalAgentChatPage(agentId: 'goal-1'),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
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
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Juno'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(navigated, ['/agents/details/goal-1']);
  });
}
