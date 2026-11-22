import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_report_quote.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';

/// The newest usable report of each task, by task id; a task without one is
/// left out.
typedef FrontTaskReportReader =
    Future<Map<String, AgentReportEntity>> Function(List<String> taskIds);

/// What one `read_report` call is answered: what she is told, and whether
/// the call was taken — a refused one is logged as an error.
typedef FrontReportAnswer = ({String response, bool accepted});

/// `read_report` for one turn, and what it read: the reports of listed
/// tasks, section by section, which her reply may then quote with
/// `ReportSections` ([quotes]).
class FrontReportLookups {
  FrontReportLookups({this.reader});

  /// Null when no reports are wired (tests, evals): reading is then
  /// unavailable.
  final FrontTaskReportReader? reader;

  int _reads = 0;
  final _quotes = <String, FrontReportQuote>{};

  /// How many calls were taken this turn.
  int get calls => _reads;

  /// The sectioned reports read this turn, by task id: all her reply may
  /// quote.
  Map<String, FrontReportQuote> get quotes => Map.unmodifiable(_quotes);

  static FrontReportAnswer _refused(String response) =>
      (response: response, accepted: false);

  /// Answers `read_report` for the listed tasks [args] names. [rowOf] finds
  /// a task the turn can see by its `task:<id>` reference.
  Future<FrontReportAnswer> read(
    Map<String, dynamic> args, {
    required FrontIndexRow? Function(String ref) rowOf,
  }) async {
    if (_reads >= frontReportReadsPerTurn) {
      return _refused(
        'Error: read_report was already called this turn. Answer from what '
        'it returned.',
      );
    }
    final raw = args['ids'];
    final refs = raw is List ? raw.whereType<String>().toList() : <String>[];
    if (refs.isEmpty || refs.length > frontReportIdsPerRead) {
      return _refused(
        'Error: read_report needs 1 to $frontReportIdsPerRead task ids as '
        'listed, e.g. "task:<id>".',
      );
    }
    final reader = this.reader;
    if (reader == null) {
      return _refused(
        'Reports cannot be read this turn; say so in your answer.',
      );
    }
    _reads++;
    final rows = {
      for (final ref in refs)
        ref: switch (rowOf(ref.trim())) {
          final row? when row.kind == FrontDestinationKind.task => row,
          _ => null,
        },
    };
    final reports = await reader([
      for (final row in rows.values) ?row?.id,
    ]);
    final buffer = StringBuffer();
    for (final MapEntry(key: ref, value: row) in rows.entries) {
      buffer.write('$ref: ');
      final report = row == null ? null : reports[row.id];
      if (row == null) {
        buffer.writeln('not a listed task');
      } else if (report == null) {
        buffer.writeln('no report yet');
      } else if (report.sections.isEmpty) {
        buffer
          ..writeln(
            '"${row.title}", report of ${_day(report.createdAt)}, written as '
            'text, so ReportSections cannot show it:',
          )
          ..writeln(report.content.trim());
      } else {
        final quote = FrontReportQuote(
          taskId: row.id,
          title: row.title,
          reportId: report.id,
          at: report.createdAt,
          sections: report.sections,
        );
        _quotes[row.id] = quote;
        buffer.writeln('"${row.title}", report of ${_day(report.createdAt)}:');
        for (final (index, section) in quote.sections.indexed) {
          buffer.writeln(_renderSection(index + 1, section));
        }
      }
    }
    return (response: buffer.toString().trimRight(), accepted: true);
  }
}

String _day(DateTime at) => at.toIso8601String().substring(0, 10);

String _renderSection(int number, AgentReportSection section) {
  final title = section.title.isEmpty ? '(no title)' : section.title;
  final body = switch (section.kind) {
    AgentReportSectionKind.text => '   ${section.text}',
    AgentReportSectionKind.points => [
      for (final item in section.items) '   - ${item.text}',
    ].join('\n'),
    AgentReportSectionKind.checklist => [
      for (final item in section.items)
        '   - [${item.done ? 'x' : ' '}] ${item.text}',
    ].join('\n'),
  };
  return '$number. $title (${section.kind.name})\n$body';
}
