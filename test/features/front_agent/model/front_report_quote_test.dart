import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/front_agent/model/front_report_quote.dart';

void main() {
  final quote = FrontReportQuote(
    taskId: 'task-1',
    title: 'Inspect orbital penguin habitat',
    reportId: 'report-1',
    at: DateTime.utc(2026, 11, 20, 9),
    sections: const [
      AgentReportSection(
        kind: AgentReportSectionKind.text,
        text: 'The feeder works on the bench.',
      ),
      AgentReportSection(
        kind: AgentReportSectionKind.checklist,
        title: 'Next actions',
        items: [
          AgentReportSectionItem(text: 'Run the test'),
          AgentReportSectionItem(text: 'Order sardines', done: true),
        ],
      ),
    ],
  );

  test('pick keeps the named sections, counted from one, once each', () {
    final picked = quote.pick([2, 2, 9, 0])!;
    expect(picked.sections, [quote.sections[1]]);
    expect(picked.reportId, 'report-1');
    expect(quote.pick([3, -1]), isNull);
    expect(quote.pick(const []), isNull);
  });

  test('a stored quote reads back as it was written, checklist marks too', () {
    final stored = jsonDecode(jsonEncode(quote.toJson()));
    final read = FrontReportQuote.fromJson(stored)!;

    expect(read.taskId, quote.taskId);
    expect(read.title, quote.title);
    expect(read.reportId, quote.reportId);
    expect(read.at, quote.at);
    expect(read.sections, quote.sections);
  });

  test('a shape this build does not know reads as nothing', () {
    final stored = quote.toJson();
    for (final broken in [
      null,
      'quote',
      {...stored}..remove('reportId'),
      {...stored, 'at': 'yesterday'},
      {...stored, 'sections': <Object>[]},
    ]) {
      expect(FrontReportQuote.fromJson(broken), isNull, reason: '$broken');
    }
  });
}
