import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_chat_page.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);

  AgentIdentityEntity identity({
    String kind = AgentKinds.relationshipAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: kind,
            displayName: 'Anna',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  testWidgets('heads the chat with the agent and returns to that person on '
      'back', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const RelationshipChatPage(relationshipId: relationshipId),
        overrides: [
          agentIdentityProvider(
            agentId,
          ).overrideWith((ref) async => identity()),
          agentChatProjectionProvider(
            agentId,
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The header names the agent and what it is, over the line that says
    // what it can see — there is no separate app-bar title to disagree with.
    expect(find.text('Anna · briefing agent'), findsOneWidget);
    expect(
      find.text('Knows your check-ins, not the channels'),
      findsOneWidget,
    );
    expect(find.byType(AppBar), findsNothing);
    final chatPadding = tester.widget<Padding>(
      find.byWidgetPredicate(
        (widget) => widget is Padding && widget.child is RelationshipChatPane,
      ),
    );
    expect(
      (chatPadding.padding as EdgeInsets).bottom,
      greaterThan(0),
      reason: 'the composer must clear the overlaid mobile navigation',
    );
    await tester.tap(find.byKey(const ValueKey('person-chat-back')));
    await tester.pump();
    expect(navigated, ['/people/$relationshipId']);
  });

  testWidgets('the header opens the agent internals', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const RelationshipChatPage(relationshipId: relationshipId),
        overrides: [
          agentIdentityProvider(
            agentId,
          ).overrideWith((ref) async => identity()),
          agentChatProjectionProvider(
            agentId,
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentInternalsPanel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('person-chat-internals')));
    await tester.pumpAndSettle();

    expect(find.byType(AgentInternalsPanel), findsOneWidget);
  });

  testWidgets('a non-relationship identity gets no composer, only the '
      'unavailable notice', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const RelationshipChatPage(relationshipId: relationshipId),
        overrides: [
          agentIdentityProvider(
            agentId,
          ).overrideWith((ref) async => identity(kind: AgentKinds.goalAgent)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentChatView), findsNothing);
    expect(
      find.text('No agent yet — mark this person as important first.'),
      findsOneWidget,
    );
  });

  testWidgets('a destroyed relationship agent is treated as absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const RelationshipChatPage(relationshipId: relationshipId),
        overrides: [
          agentIdentityProvider(agentId).overrideWith(
            (ref) async => identity(lifecycle: AgentLifecycle.destroyed),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentChatView), findsNothing);
    expect(
      find.text('No agent yet — mark this person as important first.'),
      findsOneWidget,
    );
  });

  testWidgets('a completed system pop persists the detail route', (
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
            agentId,
          ).overrideWith((ref) async => identity()),
          agentChatProjectionProvider(
            agentId,
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const RelationshipChatPage(relationshipId: relationshipId),
          ),
        );
    await tester.pumpAndSettle();

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(navigated, ['/people/$relationshipId']);
  });
}
