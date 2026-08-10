import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('renders persisted roles and forwards a composed message', (
    tester,
  ) async {
    var draft = '';
    var sent = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: draft,
              isSending: false,
              onDraftChanged: (value) => setState(() => draft = value),
              onSend: () => sent = true,
              onRetry: () {},
            ),
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: '1',
                role: AgentChatRole.agent,
                text: 'How did the gym go?',
                createdAt: DateTime(2026, 8, 11, 9),
              ),
              AgentChatMessage(
                id: '2',
                role: AgentChatRole.user,
                text: 'I went this morning.',
                createdAt: DateTime(2026, 8, 11, 9, 1),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How did the gym go?'), findsOneWidget);
    expect(find.text('I went this morning.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Keep me honest.');
    await tester.pump();
    expect(draft, 'Keep me honest.');
    await tester.tap(find.byIcon(Icons.send_rounded));
    expect(sent, isTrue);
  });

  testWidgets('shows the in-flight and retry states without losing history', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: 'Still here',
            isSending: true,
            hasFailedTurn: true,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () => retried = true,
          ),
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('•••'), findsOneWidget);
    expect(find.text("That didn't send."), findsOneWidget);
    expect(find.text('Juno is replying…'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(retried, isTrue);
  });
}
