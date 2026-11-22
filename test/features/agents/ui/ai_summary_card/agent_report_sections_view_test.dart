import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/agent_report_sections_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const sections = [
    AgentReportSection(
      kind: AgentReportSectionKind.text,
      text: 'The feeder works on the bench.',
    ),
    AgentReportSection(
      kind: AgentReportSectionKind.points,
      title: 'Progress',
      items: [AgentReportSectionItem(text: 'Prototype built')],
    ),
    AgentReportSection(
      kind: AgentReportSectionKind.checklist,
      title: 'Next actions',
      items: [
        AgentReportSectionItem(text: 'Run the test'),
        AgentReportSectionItem(text: 'Order sardines', done: true),
      ],
    ),
  ];

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    makeTestableWidget(
      const AgentReportSectionsView(
        sections: sections,
        bodyStyle: TextStyle(fontSize: 14, height: 1.4),
      ),
    ),
  );

  testWidgets('draws each section in order: title, then its body', (
    tester,
  ) async {
    await pump(tester);

    final order = [
      'The feeder works on the bench.',
      'Progress',
      'Prototype built',
      'Next actions',
      'Run the test',
      'Order sardines',
    ].map((text) => tester.getTopLeft(find.text(text)).dy).toList();
    expect(order, orderedEquals([...order]..sort()));
    // An untitled lead paragraph draws no empty heading above it: the two
    // titled sections are the only headings.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      ),
      findsNWidgets(2),
    );
    expect(
      tester.getSemantics(find.text('Progress')),
      isSemantics(label: 'Progress', isHeader: true),
    );
  });

  testWidgets('a checklist marks open and done rows, and says which', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    Icon iconBeside(String text) => tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: find.text(text), matching: find.byType(Row)),
        matching: find.byType(Icon),
      ),
    );
    final tokens = tester.element(find.text('Run the test')).designTokens;

    expect(iconBeside('Run the test').icon, LottiIcons.checkboxUnchecked);
    expect(iconBeside('Order sardines').icon, LottiIcons.checkboxChecked);
    expect(iconBeside('Order sardines').color, tokens.colors.aiCard.accent);
    // A point carries a typographic bullet, not a checkbox-like glyph.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Prototype built'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(find.text('•'), findsOneWidget);

    expect(
      tester.getSemantics(find.text('Run the test')),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    expect(
      tester.getSemantics(find.text('Order sardines')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    // Points are a list, not a checklist: no checked state at all.
    expect(
      tester.getSemantics(find.text('Prototype built')),
      isSemantics(hasCheckedState: false),
    );
    semantics.dispose();
  });
}
