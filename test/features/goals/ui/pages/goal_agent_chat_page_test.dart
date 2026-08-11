import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
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
    final chatPadding = tester.widget<Padding>(
      find.byWidgetPredicate(
        (widget) => widget is Padding && widget.child is GoalAgentChatPane,
      ),
    );
    expect(
      (chatPadding.padding as EdgeInsets).bottom,
      greaterThan(0),
      reason: 'the composer must clear the overlaid mobile navigation',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(navigated, ['/agents/details/goal-1']);
  });

  testWidgets('rejects a non-goal identity without mounting a composer', (
    tester,
  ) async {
    final foreignIdentity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.taskAgent,
              displayName: 'Not a goal',
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
        const GoalAgentChatPage(agentId: 'goal-1'),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => foreignIdentity),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalAgentChatPane), findsNothing);
    expect(
      find.text("Couldn't load this goal's health right now."),
      findsOneWidget,
    );
  });

  testWidgets('a completed system pop persists the detail route', (
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
        const SizedBox.shrink(),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const GoalAgentChatPage(agentId: 'goal-1'),
            ),
          ),
    );
    await tester.pumpAndSettle();

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(navigated, ['/agents/details/goal-1']);
  });
}
