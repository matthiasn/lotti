import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_report_lookups.dart';

AgentReportEntity _report(
  String id, {
  List<AgentReportSection> sections = const [],
  String content = '',
}) =>
    AgentDomainEntity.agentReport(
          id: id,
          agentId: 'agent-$id',
          scope: 'current',
          createdAt: DateTime(2026, 11, 20, 9),
          vectorClock: null,
          content: content,
          sections: sections,
        )
        as AgentReportEntity;

void main() {
  const rows = {
    'task:habitat': FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'habitat',
      title: 'Inspect orbital penguin habitat',
    ),
    'task:feeder': FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'feeder',
      title: 'Calibrate the sardine feeder',
    ),
    'task:quiet': FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'quiet',
      title: 'Count the hatchlings',
    ),
    'project:waddle': FrontIndexRow(
      kind: FrontDestinationKind.project,
      id: 'waddle',
      title: 'Project Waddle',
    ),
  };
  final reports = {
    'habitat': _report(
      'r-habitat',
      sections: const [
        AgentReportSection(
          kind: AgentReportSectionKind.points,
          title: 'Latest assessment',
          items: [AgentReportSectionItem(text: 'Seals A–F held')],
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.checklist,
          title: 'Next actions',
          items: [
            AgentReportSectionItem(text: 'Run the feeder test'),
            AgentReportSectionItem(text: 'Load sardines', done: true),
          ],
        ),
        AgentReportSection(
          kind: AgentReportSectionKind.text,
          text: 'Launch is on track.',
        ),
      ],
    ),
    'feeder': _report('r-feeder', content: '## Progress\n\n- Calibrated'),
  };

  FrontReportLookups lookups({List<List<String>>? asked}) => FrontReportLookups(
    reader: (ids) async {
      asked?.add(ids);
      return {
        for (final id in ids) id: ?reports[id],
      };
    },
  );

  test(
    'numbers each section of a sectioned report, and keeps it to quote',
    () async {
      final asked = <List<String>>[];
      final reportLookups = lookups(asked: asked);

      final tooMany = await reportLookups.read({
        'ids': ['task:habitat', 'task:feeder', 'task:quiet', 'project:waddle'],
      }, rowOf: (ref) => rows[ref]);

      // Four is past the cap, and a refusal does not spend the turn's read.
      expect(tooMany.accepted, isFalse);
      expect(asked, isEmpty);

      final read = await reportLookups.read({
        'ids': ['task:habitat', 'task:feeder', 'task:quiet'],
      }, rowOf: (ref) => rows[ref]);

      expect(read.accepted, isTrue);
      expect(asked, [
        ['habitat', 'feeder', 'quiet'],
      ]);
      expect(
        read.response,
        'task:habitat: "Inspect orbital penguin habitat", report of 2026-11-20:\n'
        '1. Latest assessment (points)\n'
        '   - Seals A–F held\n'
        '2. Next actions (checklist)\n'
        '   - [ ] Run the feeder test\n'
        '   - [x] Load sardines\n'
        '3. (no title) (text)\n'
        '   Launch is on track.\n'
        'task:feeder: "Calibrate the sardine feeder", report of 2026-11-20, '
        'written as text, so ReportSections cannot show it:\n'
        '## Progress\n'
        '\n'
        '- Calibrated\n'
        'task:quiet: no report yet',
      );
      // Only the sectioned report can be quoted.
      expect(reportLookups.quotes.keys, ['habitat']);
      expect(reportLookups.quotes['habitat']!.reportId, 'r-habitat');
      expect(
        reportLookups.quotes['habitat']!.title,
        rows['task:habitat']!.title,
      );
      expect(reportLookups.calls, 1);
    },
  );

  test(
    'a project, an unlisted id or a made-up one is not a listed task',
    () async {
      final read = await lookups().read({
        'ids': ['project:waddle', 'task:nope'],
      }, rowOf: (ref) => rows[ref]);

      expect(
        read.response,
        'project:waddle: not a listed task\ntask:nope: not a listed task',
      );
    },
  );

  test('one call a turn; a second is refused', () async {
    final reportLookups = lookups();
    await reportLookups.read({
      'ids': ['task:habitat'],
    }, rowOf: (ref) => rows[ref]);

    final again = await reportLookups.read({
      'ids': ['task:habitat'],
    }, rowOf: (ref) => rows[ref]);

    expect(again.accepted, isFalse);
    expect(again.response, contains('already called this turn'));
    expect(reportLookups.calls, 1);
  });

  test('no ids, or no reader wired, is refused without counting', () async {
    final reportLookups = lookups();
    for (final args in [
      <String, dynamic>{},
      {'ids': <String>[]},
      {'ids': 'task:habitat'},
    ]) {
      final answer = await reportLookups.read(args, rowOf: (ref) => rows[ref]);
      expect(answer.accepted, isFalse, reason: '$args');
      expect(answer.response, contains('1 to 3 task ids'));
    }
    final unwired = await FrontReportLookups().read({
      'ids': ['task:habitat'],
    }, rowOf: (ref) => rows[ref]);
    expect(unwired.accepted, isFalse);
    expect(unwired.response, contains('cannot be read this turn'));
    expect(reportLookups.calls, 0);
  });
}
