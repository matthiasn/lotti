import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/streaming_content.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget wrap(Widget child) => makeTestableWidgetWithScaffold(
    Center(child: child),
  );

  group('StreamingContent', () {
    testWidgets('shows spinner and Thinking label when content is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          StreamingContent(
            content: '',
            isUser: false,
            theme: ThemeData(),
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() because
      // CircularProgressIndicator animates indefinitely.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Thinking...'), findsOneWidget);
    });

    testWidgets('renders visible markdown segments and reasoning disclosure', (
      tester,
    ) async {
      const content =
          'Hello before <think>internal chain of thought</think> hello after';

      await tester.pumpWidget(
        wrap(
          StreamingContent(
            content: content,
            isUser: false, // assistant message path (no SelectionArea)
            theme: ThemeData(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // One reasoning disclosure is rendered for the thinking segment
      expect(find.byType(ThinkingDisclosure), findsOneWidget);

      // Two visible segments -> two markdown widgets
      expect(find.byType(GptMarkdown), findsNWidgets(2));
    });

    testWidgets('wraps user content segments in SelectionArea', (tester) async {
      const content = 'User says <think>draft</think> final';

      await tester.pumpWidget(
        wrap(
          StreamingContent(
            content: content,
            isUser: true,
            theme: ThemeData(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // For user messages, visible segments are wrapped in SelectionArea
      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.byType(GptMarkdown), findsNWidgets(2));
    });

    testWidgets('thinking-only content renders only disclosures', (
      tester,
    ) async {
      const content = '<think>chain of thought</think>';

      await tester.pumpWidget(
        wrap(
          StreamingContent(
            content: content,
            isUser: false,
            theme: ThemeData(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // No visible markdown segments; only the disclosure is present
      expect(find.byType(ThinkingDisclosure), findsOneWidget);
      expect(find.byType(GptMarkdown), findsNothing);
    });
  });

  group('StreamingContent fallback', () {
    testWidgets(
      'renders visible markdown and does not break on malformed content',
      (tester) async {
        // Malformed/open-ended thinking with some visible content before it.
        const malformed =
            'Visible part before bad block\n<thinking>Unclosed block';

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) => StreamingContent(
                content: malformed,
                isUser: true,
                theme: Theme.of(context),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 16));

        // The visible portion should render as markdown and remain selectable
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(find.byType(GptMarkdown), findsOneWidget);
        expect(find.textContaining('Visible part before'), findsOneWidget);
      },
    );
  });
}
