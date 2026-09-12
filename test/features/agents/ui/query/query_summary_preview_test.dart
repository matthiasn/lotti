import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/ui/query/query_summary_preview.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../test_data/entity_factories.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  for (final tldr in <String?>[null, 'Feeder approved.']) {
    testWidgets('shows the current full report with TLDR=$tldr', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          QuerySummaryPreview(
            title: 'Penguin logistics',
            report: makeTestReport(
              tldr: tldr,
              content: 'Run another zero-gravity test before launch.',
            ),
          ),
        ),
      );
      final markdown = tester.widget<AgentMarkdownView>(
        find.byType(AgentMarkdownView),
      );
      expect(
        markdown.text,
        [
          ?tldr,
          'Run another zero-gravity test before launch.',
        ].join('\n\n'),
      );
      expect(
        markdown.style,
        dsTokensLight.typography.styles.body.bodySmall,
      );
      expect(
        find.ancestor(
          of: find.byType(AgentMarkdownView),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
    });
  }

  for (final report in <AgentReportEntity?>[
    null,
    makeTestReport(content: ' ', tldr: ' '),
  ]) {
    testWidgets('missing or empty report explains its absence ($report)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          QuerySummaryPreview(title: 'Penguin logistics', report: report),
        ),
      );
      expect(find.text('No report available yet.'), findsOneWidget);
      expect(find.byType(AgentMarkdownView), findsNothing);
      expect(find.text('Penguin logistics'), findsOneWidget);
    });
  }
}
