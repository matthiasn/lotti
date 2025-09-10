import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/streaming_content.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(body: Center(child: child)),
      );

  group('StreamingContent', () {
    testWidgets('shows spinner and Thinking label when content is empty',
        (tester) async {
      await tester.pumpWidget(wrap(
        StreamingContent(
          content: '',
          isUser: false,
          theme: ThemeData(),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Thinking...'), findsOneWidget);
    });

    testWidgets('renders visible markdown segments and reasoning disclosure',
        (tester) async {
      const content =
          'Hello before <think>internal chain of thought</think> hello after';

      await tester.pumpWidget(wrap(
        StreamingContent(
          content: content,
          isUser: false, // assistant message path (no SelectionArea)
          theme: ThemeData(),
        ),
      ));

      // One reasoning disclosure is rendered for the thinking segment
      expect(find.byType(ThinkingDisclosure), findsOneWidget);

      // Two visible segments -> two markdown widgets
      expect(find.byType(GptMarkdown), findsNWidgets(2));
    });

    testWidgets('wraps user content segments in SelectionArea', (tester) async {
      const content = 'User says <think>draft</think> final';

      await tester.pumpWidget(wrap(
        StreamingContent(
          content: content,
          isUser: true,
          theme: ThemeData(),
        ),
      ));

      // For user messages, visible segments are wrapped in SelectionArea
      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.byType(GptMarkdown), findsNWidgets(2));
    });

    testWidgets('thinking-only content renders only disclosures',
        (tester) async {
      const content = '<think>chain of thought</think>';

      await tester.pumpWidget(wrap(
        StreamingContent(
          content: content,
          isUser: false,
          theme: ThemeData(),
        ),
      ));

      // No visible markdown segments; only the disclosure is present
      expect(find.byType(ThinkingDisclosure), findsOneWidget);
      expect(find.byType(GptMarkdown), findsNothing);
    });
  });
}
