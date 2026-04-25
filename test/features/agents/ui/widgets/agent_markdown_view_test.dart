import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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

    testWidgets('applies custom style to body text when provided', (
      tester,
    ) async {
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

      final gptContext = tester.element(find.byType(GptMarkdown));
      final effectiveStyle = DefaultTextStyle.of(gptContext).style;
      expect(effectiveStyle.fontSize, 20);
      expect(effectiveStyle.color, Colors.red);
      expect(effectiveStyle.fontWeight, FontWeight.bold);
    });

    testWidgets('falls back to design system body.bodySmall by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentMarkdownView('Fallback styled text'),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(AgentMarkdownView));
      final expected = context.designTokens.typography.styles.body.bodySmall;

      final gptContext = tester.element(find.byType(GptMarkdown));
      final effectiveStyle = DefaultTextStyle.of(gptContext).style;
      expect(effectiveStyle.fontSize, expected.fontSize);
      expect(effectiveStyle.fontWeight, expected.fontWeight);
      expect(effectiveStyle.fontFamily, expected.fontFamily);
    });
  });
}
