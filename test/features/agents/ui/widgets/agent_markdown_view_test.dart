import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('AgentMarkdownView', () {
    testWidgets('renders GptMarkdown with provided text', (tester) async {
      const markdownText = '# Hello World\n\nThis is a test.';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentMarkdownView(markdownText),
        ),
      );
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.data, markdownText);
    });

    testWidgets('uses custom style when provided', (tester) async {
      const customStyle = TextStyle(
        fontSize: 20,
        color: Colors.red,
        fontWeight: FontWeight.bold,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentMarkdownView(
            'Custom styled text',
            style: customStyle,
          ),
        ),
      );
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.style, customStyle);
    });

    testWidgets('falls back to theme textStyle when no custom style given', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentMarkdownView('Fallback styled text'),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(AgentMarkdownView));
      final theme = Theme.of(context);
      final expectedStyle = theme.textTheme.bodyMedium!.copyWith(
        height: 1.5,
        color: theme.colorScheme.onSurface,
      );

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.style?.fontSize, expectedStyle.fontSize);
      expect(gptMarkdown.style?.height, 1.5);
      expect(gptMarkdown.style?.color, theme.colorScheme.onSurface);
    });
  });
}
