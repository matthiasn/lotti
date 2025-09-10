import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_bubble.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_timestamp.dart';

void main() {
  Widget _wrap(Widget child) => MaterialApp(
          home: Scaffold(
              body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      )));

  group('MessageBubble', () {
    testWidgets('renders user and assistant content', (tester) async {
      final user = ChatMessage.user('User says');
      final ai = ChatMessage.assistant('Assistant replies');

      await tester.pumpWidget(
        _wrap(Column(
          children: [
            MessageBubble(message: user),
            MessageBubble(message: ai),
          ],
        )),
      );

      expect(find.text('User says'), findsOneWidget);
      expect(find.text('Assistant replies'), findsOneWidget);
    });

    testWidgets('hides timestamp for pure thinking messages', (tester) async {
      final thinkingOnly = ChatMessage.assistant('<thinking>plan</thinking>');
      await tester.pumpWidget(_wrap(MessageBubble(message: thinkingOnly)));

      // Timestamp widget should not be rendered for thinking-only messages
      expect(find.byType(MessageTimestamp), findsNothing);
    });

    testWidgets('shows copy action for assistant visible content',
        (tester) async {
      final ai = ChatMessage.assistant('Visible content');
      await tester.pumpWidget(_wrap(MessageBubble(message: ai)));

      // Tap the copy corner action (tooltip 'Copy')
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      // We don't assert the SnackBar (theme-dependent). The tap should not throw.
    });
  });
}
