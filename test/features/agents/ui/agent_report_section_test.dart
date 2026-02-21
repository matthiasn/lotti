import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('AgentReportSection', () {
    Widget buildSubject(String content) {
      return makeTestableWidget(
        AgentReportSection(content: content),
      );
    }

    testWidgets('renders markdown content via GptMarkdown', (tester) async {
      const markdown = '# Task Report\n\nTask is progressing well.';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, markdown);
    });

    testWidgets('renders Card wrapper around markdown', (tester) async {
      const markdown = '# Report Title';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, markdown);
    });

    testWidgets('handles empty content gracefully', (tester) async {
      await tester.pumpWidget(buildSubject(''));
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(GptMarkdown), findsNothing);
    });

    testWidgets('passes full markdown string to GptMarkdown', (tester) async {
      const markdown = '## Achieved\n- Task 1 done\n- Task 2 done';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, markdown);
    });

    testWidgets('renders multi-section markdown report', (tester) async {
      const markdown = '# Sprint Report\n\n'
          'Good progress overall.\n\n'
          '## Completed\n- Feature A\n\n'
          '## Remaining\n- Feature B\n';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, markdown);
    });
  });
}
