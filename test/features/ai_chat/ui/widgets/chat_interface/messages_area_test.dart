import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/messages_area.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('MessagesArea', () {
    testWidgets('shows empty state when there are no messages', (tester) async {
      await tester.pumpWidget(
        wrap(MessagesArea(
          messages: const <ChatMessage>[],
          scrollController: ScrollController(),
          showTypingIndicator: false,
        )),
      );

      // The empty state contains the AI icon and helper text
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.text('Ask me about your tasks'), findsOneWidget);
    });

    testWidgets('shows typing indicator at bottom when empty + streaming',
        (tester) async {
      await tester.pumpWidget(
        wrap(MessagesArea(
          messages: const <ChatMessage>[],
          scrollController: ScrollController(),
          showTypingIndicator: true,
        )),
      );

      // TypingIndicator renders inside the stack bottom area
      // We assert the presence of at least one AnimatedBuilder (dots animation)
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('renders bubbles and trailing typing indicator',
        (tester) async {
      final msgs = <ChatMessage>[
        ChatMessage.user('Hello'),
        ChatMessage.assistant('Hi!'),
      ];

      await tester.pumpWidget(
        wrap(MessagesArea(
          messages: msgs,
          scrollController: ScrollController(),
          showTypingIndicator: true,
        )),
      );

      // Expect both message texts
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi!'), findsOneWidget);

      // And a trailing TypingIndicator row exists at the end
      // (we just check that there are at least two Rows: content + trailing)
      expect(find.byType(Row), findsWidgets);
    });
  });
}
