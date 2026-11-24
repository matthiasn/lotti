import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';

void main() {
  group('parseAgentReportSections', () {
    test('reads every kind, trimming text and keeping checklist marks', () {
      final sections = parseAgentReportSections([
        {'kind': 'text', 'text': '  Feeder test is next.  '},
        {
          'kind': 'points',
          'title': ' Progress ',
          'items': [
            {'text': 'Prototype built'},
            'Bare string row',
          ],
        },
        {
          'kind': 'checklist',
          'title': 'Next actions',
          'items': [
            {'text': 'Run the test', 'done': false},
            {'text': 'Order sardines', 'done': true},
          ],
        },
      ]);

      expect(sections, const [
        AgentReportSection(
          kind: AgentReportSectionKind.text,
          text: 'Feeder test is next.',
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.points,
          title: 'Progress',
          items: [
            AgentReportSectionItem(text: 'Prototype built'),
            AgentReportSectionItem(text: 'Bare string row'),
          ],
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.checklist,
          title: 'Next actions',
          items: [
            AgentReportSectionItem(text: 'Run the test'),
            AgentReportSectionItem(text: 'Order sardines', done: true),
          ],
        ),
      ]);
    });

    test('an array sent as its JSON text is read like the array', () {
      expect(
        parseAgentReportSections(
          '[{"kind": "text", "text": "Calibration is next."}]',
        ),
        const [
          AgentReportSection(
            kind: AgentReportSectionKind.text,
            text: 'Calibration is next.',
          ),
        ],
      );
      expect(parseAgentReportSections('[not json'), isEmpty);
      expect(parseAgentReportSections('## Markdown'), isEmpty);
    });

    test('drops malformed entries instead of failing the report', () {
      expect(
        parseAgentReportSections([
          'not a map',
          {'kind': 'table'},
          {'title': 'no kind and no body'},
          {'kind': 'text', 'text': '   '},
          {'kind': 'points', 'items': 'not a list'},
          {
            'kind': 'points',
            'items': [
              {'text': ' '},
              42,
            ],
          },
        ]),
        isEmpty,
      );
      expect(parseAgentReportSections(null), isEmpty);
      expect(parseAgentReportSections('## Markdown'), isEmpty);
    });
  });

  test('a missing or unknown kind is read from the section shape', () {
    // Mistral Small 4 left `kind` out of every section in a live run.
    expect(
      parseAgentReportSections([
        {'text': 'Calibration is next.'},
        {
          'title': 'Progress',
          'items': [
            {'text': 'Mounted the feeders'},
          ],
        },
        {
          'kind': 'todo',
          'title': 'Next actions',
          'items': [
            {'text': 'Calibrate the portions', 'done': false},
          ],
        },
      ]),
      const [
        AgentReportSection(
          kind: AgentReportSectionKind.text,
          text: 'Calibration is next.',
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.points,
          title: 'Progress',
          items: [AgentReportSectionItem(text: 'Mounted the feeders')],
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.checklist,
          title: 'Next actions',
          items: [AgentReportSectionItem(text: 'Calibrate the portions')],
        ),
      ],
    );
  });

  group('renderAgentReportSectionsMarkdown', () {
    test('writes headings, lists, checkboxes and paragraphs', () {
      expect(
        renderAgentReportSectionsMarkdown(const [
          AgentReportSection(
            kind: AgentReportSectionKind.text,
            text: 'Feeder test is next.',
          ),
          AgentReportSection(
            kind: AgentReportSectionKind.points,
            title: 'Progress',
            items: [
              AgentReportSectionItem(text: 'Prototype built'),
              AgentReportSectionItem(text: '[Spec](https://example.com)'),
            ],
          ),
          AgentReportSection(
            kind: AgentReportSectionKind.checklist,
            title: 'Next actions',
            items: [
              AgentReportSectionItem(text: 'Run the test'),
              AgentReportSectionItem(text: 'Order sardines', done: true),
            ],
          ),
        ]),
        'Feeder test is next.\n\n'
        '## Progress\n\n'
        '- Prototype built\n'
        '- [Spec](https://example.com)\n\n'
        '## Next actions\n\n'
        '- [ ] Run the test\n'
        '- [x] Order sardines',
      );
    });
  });

  group('agent report sections on the synced entity', () {
    final createdAt = DateTime(2026, 11, 22, 9);

    test('survive a JSON round trip', () {
      final report = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: 'agent-1',
        scope: 'current',
        createdAt: createdAt,
        vectorClock: null,
        content: '## Progress\n\n- Prototype built',
        sections: const [
          AgentReportSection(
            kind: AgentReportSectionKind.checklist,
            title: 'Next actions',
            items: [AgentReportSectionItem(text: 'Run it', done: true)],
          ),
        ],
      );

      final decoded = AgentDomainEntity.fromJson(
        jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, report);
    });

    test('a report stored before sections existed decodes with none', () {
      final legacy = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: 'agent-1',
        scope: 'current',
        createdAt: createdAt,
        vectorClock: null,
        content: '## Progress\n\n- Prototype built',
      ).toJson()..remove('sections');

      final decoded = AgentDomainEntity.fromJson(
        jsonDecode(jsonEncode(legacy)) as Map<String, dynamic>,
      );

      expect((decoded as AgentReportEntity).sections, isEmpty);
      expect(decoded.content, '## Progress\n\n- Prototype built');
    });
  });
}
