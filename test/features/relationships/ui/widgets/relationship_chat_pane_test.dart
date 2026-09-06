import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);

  AgentIdentityEntity identity({
    String kind = AgentKinds.relationshipAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
    String displayName = 'Anna',
  }) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: kind,
            displayName: displayName,
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

  Future<void> pumpPane(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool showInternalsAction = false,
    Size size = const Size(400, 800),
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: RelationshipChatPane(
            relationshipId: relationshipId,
            onBack: onBack,
            showInternalsAction: showInternalsAction,
          ),
        ),
        mediaQueryData: MediaQueryData(size: size),
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
  }

  testWidgets('names the agent and states the boundary it works within', (
    tester,
  ) async {
    await pumpPane(tester);

    expect(find.text('Anna · briefing agent'), findsOneWidget);
    expect(
      find.text('Knows your check-ins, not the channels'),
      findsOneWidget,
      reason: 'the header says what the agent can see before the user asks',
    );
    expect(find.byType(AgentChatView), findsOneWidget);
  });

  testWidgets('offers back only when the host asks for it', (tester) async {
    await pumpPane(tester);
    expect(find.byKey(const ValueKey('person-chat-back')), findsNothing);

    var backs = 0;
    await pumpPane(tester, onBack: () => backs++);

    await tester.tap(find.byKey(const ValueKey('person-chat-back')));
    await tester.pump();
    expect(backs, 1);
  });

  testWidgets('the internals action is a label where there is room and an '
      'icon where there is not', (tester) async {
    await pumpPane(tester, showInternalsAction: true);
    expect(
      find.byKey(const ValueKey('person-chat-internals')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('person-chat-internals')),
        matching: find.text('Agent internals'),
      ),
      findsNothing,
      reason: 'a phone header has no room for the word beside the name',
    );

    await pumpPane(
      tester,
      showInternalsAction: true,
      size: const Size(1200, 800),
    );

    expect(
      find.widgetWithText(DesignSystemButton, 'Agent internals'),
      findsOneWidget,
    );
  });

  testWidgets('without the action there is no way in from the header', (
    tester,
  ) async {
    await pumpPane(tester, size: const Size(1200, 800));

    expect(find.byKey(const ValueKey('person-chat-internals')), findsNothing);
  });

  testWidgets("an agent that is not this person's says so instead of "
      'offering a composer', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: RelationshipChatPane(relationshipId: relationshipId),
        ),
        overrides: [
          agentIdentityProvider(
            agentId,
          ).overrideWith((ref) async => identity(kind: AgentKinds.goalAgent)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentChatView), findsNothing);
    expect(find.byType(RelationshipChatHeader), findsNothing);
    expect(
      find.text('No agent yet — mark this person as important first.'),
      findsOneWidget,
    );
  });
}
