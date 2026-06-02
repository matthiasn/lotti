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

  // A theme whose primary-related colors are all distinct so that the
  // isUser ? onPrimary : primary/onSurfaceVariant branches can be told apart.
  final distinctTheme = ThemeData(
    colorScheme: const ColorScheme.light().copyWith(
      onPrimary: const Color(0xFF111111),
      primary: const Color(0xFF222222),
      onSurfaceVariant: const Color(0xFF333333),
    ),
  );

  group('StreamingContent', () {
    // Empty content renders the spinner + "Thinking..." label, where the
    // spinner color and the label color depend on isUser. Drive both branches
    // and assert the exact resolved colors (lines selecting onPrimary vs
    // primary/onSurfaceVariant).
    for (final isUser in [false, true]) {
      testWidgets(
        'empty content shows spinner + Thinking label with '
        'isUser=$isUser colors',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              StreamingContent(
                content: '',
                isUser: isUser,
                theme: distinctTheme,
              ),
            ),
          );
          // Use pump() instead of pumpAndSettle() because
          // CircularProgressIndicator animates indefinitely.
          await tester.pump();

          expect(find.text('Thinking...'), findsOneWidget);

          final spinner = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          final label = tester.widget<Text>(find.text('Thinking...'));

          final expectedSpinnerColor = isUser
              ? distinctTheme.colorScheme.onPrimary
              : distinctTheme.colorScheme.primary;
          final expectedLabelColor = isUser
              ? distinctTheme.colorScheme.onPrimary
              : distinctTheme.colorScheme.onSurfaceVariant;

          expect(spinner.color, expectedSpinnerColor);
          expect(label.style?.color, expectedLabelColor);
          expect(label.style?.fontStyle, FontStyle.italic);
        },
      );
    }

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
