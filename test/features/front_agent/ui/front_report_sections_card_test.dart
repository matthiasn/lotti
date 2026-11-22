import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/agent_report_sections_view.dart';
import 'package:lotti/features/front_agent/model/front_report_quote.dart';
import 'package:lotti/features/front_agent/ui/front_report_sections_card.dart';

import '../../../widget_test_utils.dart';

void main() {
  final quote = FrontReportQuote(
    taskId: 'habitat',
    title: 'Inspect orbital penguin habitat',
    reportId: 'r-habitat',
    at: DateTime(2026, 11, 20, 9),
    sections: const [
      AgentReportSection(
        kind: AgentReportSectionKind.checklist,
        title: 'Next actions',
        items: [AgentReportSectionItem(text: 'Run the feeder test')],
      ),
    ],
  );

  testWidgets('the task heads the quote, with how old the report is; a tap '
      'on it opens the task', (tester) async {
    final opened = <String>[];
    await withClock(Clock.fixed(DateTime(2026, 11, 22, 9)), () async {
      await tester.pumpWidget(
        makeTestableWidget(
          FrontReportSectionsCard(quote: quote, onOpenTask: opened.add),
        ),
      );
    });

    expect(find.text('Inspect orbital penguin habitat'), findsOneWidget);
    expect(find.text('AI summary · 2 days ago'), findsOneWidget);
    final view = tester.widget<AgentReportSectionsView>(
      find.byType(AgentReportSectionsView),
    );
    expect(view.sections, quote.sections);

    await tester.tap(find.byKey(FrontReportSectionsCardKeys.task('habitat')));
    expect(opened, ['habitat']);
  });
}
