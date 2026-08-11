import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('the visible message footer follows locale word order', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        locale: const Locale('fr'),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: '1',
                role: AgentChatRole.agent,
                text: 'On y va.',
                createdAt: DateTime(2026, 8, 11, 9),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juno à 09:00'), findsOneWidget);
  });

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

  testWidgets('renders agent markdown and expands a collapsed long reply', (
    tester,
  ) async {
    final longReply = List.generate(
      12,
      (index) => '${index + 1}. **Coaching point ${index + 1}** — details',
    ).join('\n');

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: 'long-reply',
                role: AgentChatRole.agent,
                text: longReply,
                createdAt: DateTime(2026, 8, 11, 9),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentMarkdownView), findsOneWidget);
    expect(
      tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
      longReply,
    );
    expect(tester.widget<GptMarkdown>(find.byType(GptMarkdown)).maxLines, 8);
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GptMarkdown>(find.byType(GptMarkdown)).maxLines,
      isNull,
    );
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(tester.widget<GptMarkdown>(find.byType(GptMarkdown)).maxLines, 8);
  });

  testWidgets('restores an externally retained draft and submits it from the '
      'keyboard', (tester) async {
    var draft = '';
    var sent = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (value) => setState(() => draft = value),
                onSend: () => sent = true,
                onRetry: () {},
              ),
            );
          },
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() => draft = 'Recovered draft');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Recovered draft',
    );

    tester
        .widget<TextField>(find.byType(TextField))
        .onSubmitted
        ?.call('Recovered draft');
    await tester.pump();
    expect(sent, isTrue);
  });

  testWidgets(
    'distinguishes a failed history load from an empty conversation',
    (
      tester,
    ) async {
      final harness = makeTestableWidgetWithContainer(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('database offline')),
        ],
        retry: (_, _) => null,
      );
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load this conversation right now."),
        findsOneWidget,
      );
      expect(find.textContaining('Start a conversation'), findsNothing);
    },
  );

  testWidgets('editing a draft does not pull a scrolled conversation down', (
    tester,
  ) async {
    var draft = '';
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SizedBox(
              height: 420,
              child: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (value) => setState(() => draft = value),
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              for (var index = 0; index < 30; index++)
                AgentChatMessage(
                  id: '$index',
                  role: AgentChatRole.agent,
                  text: 'Message $index with enough text to occupy a row.',
                  createdAt: DateTime(2026, 8, 11, 9, index),
                ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Message 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Still reading');
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Message 0'), findsOneWidget);
    expect(find.textContaining('Message 29'), findsNothing);
  });
}
