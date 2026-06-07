import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/messages_area.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/typing_indicator.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('MessagesArea', () {
    testWidgets('shows empty state when there are no messages', (tester) async {
      await tester.pumpWidget(
        wrap(
          MessagesArea(
            messages: const <ChatMessage>[],
            scrollController: ScrollController(),
            showTypingIndicator: false,
          ),
        ),
      );

      // The empty state contains the AI icon and helper text
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.text('Ask me about your tasks'), findsOneWidget);
    });

    testWidgets('shows typing indicator at bottom when empty + streaming', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MessagesArea(
            messages: const <ChatMessage>[],
            scrollController: ScrollController(),
            showTypingIndicator: true,
          ),
        ),
      );

      // The empty + streaming state shows exactly one assistant-side
      // typing indicator pinned to the bottom of the stack.
      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(
        tester.widget<TypingIndicator>(find.byType(TypingIndicator)).isUser,
        isFalse,
      );
    });

    testWidgets('renders bubbles and trailing typing indicator', (
      tester,
    ) async {
      final msgs = <ChatMessage>[
        ChatMessage.user('Hello'),
        ChatMessage.assistant('Hi!'),
      ];

      await tester.pumpWidget(
        wrap(
          MessagesArea(
            messages: msgs,
            scrollController: ScrollController(),
            showTypingIndicator: true,
          ),
        ),
      );

      // Expect both message texts
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi!'), findsOneWidget);

      // The trailing list slot renders exactly one typing indicator BELOW
      // the last message bubble.
      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TypingIndicator)).dy,
        greaterThan(tester.getBottomLeft(find.text('Hi!')).dy),
      );
    });
  });
}
