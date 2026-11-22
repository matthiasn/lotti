import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:meta/meta.dart';

/// Sections of one task's report, as her reply quotes them: the task, the
/// report they come from and when it was written, and the sections
/// themselves. Reports are immutable snapshots, so a quote is pinned to the
/// one [reportId] she read: a later update of the task's summary does not
/// change what an earlier answer showed.
@immutable
class FrontReportQuote {
  const FrontReportQuote({
    required this.taskId,
    required this.title,
    required this.reportId,
    required this.at,
    required this.sections,
  });

  final String taskId;

  /// The task's title when she read the report.
  final String title;
  final String reportId;

  /// When the report was written.
  final DateTime at;
  final List<AgentReportSection> sections;

  /// This quote cut to the sections [numbers] name, counted from one as
  /// `read_report` listed them; null when none of them exists.
  FrontReportQuote? pick(Iterable<int> numbers) {
    final picked = [
      for (final number in numbers.toSet())
        if (number >= 1 && number <= sections.length) sections[number - 1],
    ];
    if (picked.isEmpty) return null;
    return FrontReportQuote(
      taskId: taskId,
      title: title,
      reportId: reportId,
      at: at,
      sections: picked,
    );
  }

  Map<String, Object> toJson() => {
    'taskId': taskId,
    'title': title,
    'reportId': reportId,
    'at': at.toUtc().toIso8601String(),
    'sections': [for (final section in sections) section.toJson()],
  };

  /// Reads a stored quote; null for a shape this build does not know or one
  /// left without sections.
  static FrontReportQuote? fromJson(Object? json) {
    if (json is! Map) return null;
    final taskId = json['taskId'];
    final title = json['title'];
    final reportId = json['reportId'];
    final at = DateTime.tryParse('${json['at']}');
    final sections = parseAgentReportSections(json['sections']);
    if (taskId is! String ||
        title is! String ||
        reportId is! String ||
        at == null ||
        sections.isEmpty) {
      return null;
    }
    return FrontReportQuote(
      taskId: taskId,
      title: title,
      reportId: reportId,
      at: at,
      sections: sections,
    );
  }
}
