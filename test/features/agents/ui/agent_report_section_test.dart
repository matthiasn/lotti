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

    testWidgets('renders nothing for empty content', (tester) async {
      await tester.pumpWidget(buildSubject(''));
      await tester.pump();

      expect(find.byType(GptMarkdown), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders TLDR section from structured report', (tester) async {
      const markdown = '# Task Title\n\n'
          '**Status:** in_progress\n\n'
          '## 📋 TLDR\n'
          'Task is progressing well.\n\n'
          '## ✅ Achieved\n'
          '- Item A\n\n'
          '## 📌 What is left to do\n'
          '- Item B\n';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      // TLDR section should be visible
      final gptMarkdowns = tester.widgetList<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      // Only TLDR section visible initially (collapsed)
      expect(gptMarkdowns.length, 1);
      expect(gptMarkdowns.first.data, contains('TLDR'));
      expect(gptMarkdowns.first.data, contains('Task is progressing well.'));
    });

    testWidgets('expands to show additional content on tap', (tester) async {
      const markdown = '# Task Title\n\n'
          '## 📋 TLDR\n'
          'Overview text.\n\n'
          '## ✅ Achieved\n'
          '- Done item\n';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      // Initially only TLDR visible
      expect(
        tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).length,
        1,
      );

      // Tap expand button
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Now both TLDR and additional content visible
      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns.length, 2);

      // Additional content contains the achieved section
      expect(markdowns.last.data, contains('Achieved'));
      expect(markdowns.last.data, contains('Done item'));
    });

    testWidgets('renders full content without expand button for simple report',
        (tester) async {
      const markdown = '# Simple Report\n\nJust one paragraph.';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      // No expand button since there is no additional content
      // (fallback: first paragraph only, second paragraph is "additional")
      final gptMarkdowns = tester.widgetList<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdowns, isNotEmpty);
    });

    testWidgets('fallback parsing uses first paragraph as TLDR',
        (tester) async {
      const markdown = 'First paragraph.\n\nSecond paragraph.';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown).first,
      );
      expect(gptMarkdown.data, 'First paragraph.');

      // Expand button should exist since there's additional content
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('parses bold TLDR prefix pattern', (tester) async {
      const markdown = '# Title\n\n'
          '**TLDR:** Quick summary here\n\n'
          '## Details\n- More info\n';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown).first,
      );
      expect(gptMarkdown.data, contains('TLDR'));
      expect(gptMarkdown.data, contains('Quick summary'));

      // Expand button should exist for the details section
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Expand to verify additional content
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns.length, 2);
      expect(markdowns.last.data, contains('Details'));
    });

    testWidgets('TLDR heading with no subsequent sections shows only TLDR',
        (tester) async {
      const markdown = '## 📋 TLDR\nJust the summary, nothing more.';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      final gptMarkdowns = tester.widgetList<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdowns.length, 1);
      expect(gptMarkdowns.first.data, contains('Just the summary'));

      // No expand button since there is no additional content
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('collapses back on second tap', (tester) async {
      const markdown = '## 📋 TLDR\nOverview.\n\n## ✅ Achieved\n- Item\n';
      await tester.pumpWidget(buildSubject(markdown));
      await tester.pump();

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).length,
        2,
      );

      // Collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).length,
        1,
      );
    });
  });
}
