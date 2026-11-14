import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/ui/front_cited_source_row.dart';
import 'package:lotti/widgets/markdown/citation_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  FrontCitedSource source({
    QuerySourceKind kind = QuerySourceKind.text,
    String label = 'Colony chores',
    String quote = 'Fix the hinge this week.',
    bool transcript = false,
  }) => FrontCitedSource(
    id: 'e',
    kind: kind,
    label: label,
    date: DateTime(2026, 10, 27, 18, 2),
    quote: quote,
    transcript: transcript,
  );

  Future<void> pump(
    WidgetTester tester,
    FrontCitedSource cited, {
    int? number,
    VoidCallback? onOpen,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      FrontCitedSourceRow(source: cited, number: number, onOpen: onOpen),
    ),
  );

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text).first).textSpan!.toPlainText();

  testWidgets('names an entry by its label and when, with its quote under '
      'it', (tester) async {
    await pump(tester, source());

    expect(title(tester), 'Colony chores · Oct 27, 2026 18:02');
    expect(find.text('Fix the hinge this week.'), findsOneWidget);
    expect(find.byType(CitationBadge), findsNothing);
  });

  testWidgets('a recording is what it is, never its file name', (
    tester,
  ) async {
    await pump(
      tester,
      source(
        kind: QuerySourceKind.recording,
        label: '2026-10-27_18-02-11-001.m4a',
        transcript: true,
      ),
    );

    expect(title(tester), 'Recording transcript · Oct 27, 2026 18:02');
  });

  testWidgets('a note named by its first line says only when: the quote '
      'already says it', (tester) async {
    await pump(
      tester,
      source(label: 'Fix the hinge'),
    );

    expect(title(tester), 'Oct 27, 2026 18:02');
  });

  testWidgets('is led by its number when the words cite it by one, and '
      'opens on a tap', (tester) async {
    var opened = 0;
    await pump(tester, source(), number: 2, onOpen: () => opened++);

    expect(
      tester.widget<CitationBadge>(find.byType(CitationBadge)).number,
      '2',
    );
    await tester.tap(find.byType(FrontCitedSourceRow));
    expect(opened, 1);
  });
}
