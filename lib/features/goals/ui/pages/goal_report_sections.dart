import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// The structured sections a goal report carries, or null when it has none —
/// a free-form report, or one written before sections were persisted.
///
/// A payload has to RENDER something to count as a sectioned report. A map of
/// blanks — or one carrying only keys this build does not know — passed the
/// old non-empty check and won the branch, so the card opened on zero
/// headings and zero actions while `content` still held the real text. Only
/// recognized keys count, for the same reason.
Map<String, Object?>? goalReportSections(AgentReportEntity? report) {
  final raw = report?.provenance[GoalReportProvenanceKeys.sections];
  if (raw is! Map) return null;
  final sections = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is String) sections[entry.key as String] = entry.value;
  }
  final renderable =
      _expandedSectionKeys.any(
        (key) => _text(sections[key]) != null,
      ) ||
      goalReportActions(sections) != null;
  return renderable ? sections : null;
}

/// The report's current actions, or null when it has none.
///
/// The card shows them with the summary rather than inside the expandable
/// body: an action reachable only behind "Show more" is an action most
/// readers never see.
List<String>? goalReportActions(Map<String, Object?>? sections) {
  if (sections == null) return null;
  final actions = <String>[
    if (sections[GoalReportSectionKeys.nextActions] case final List<Object?> a)
      for (final item in a) ?_text(item),
  ];
  return actions.isEmpty ? null : actions;
}

/// The report's reflection on what the user said in their check-ins, or null
/// when it has none.
///
/// Shown with the summary, like the actions, and never among the expanded
/// sections, so it is not repeated below.
String? goalReportReflection(Map<String, Object?>? sections) =>
    _text(sections?[GoalReportSectionKeys.reflection]);

/// Whether the report has more than its summary to show behind "Show more".
///
/// A full text identical to the TLDR would make Show more a no-op that merely
/// repeats the same paragraph, so it does not count. A renderable sections
/// payload is expandable even when the flat text happens to equal the TLDR:
/// without that the toggle vanished and the sections became unreachable.
bool goalReportExpandable(AgentReportEntity? report) {
  final tldr = _text(report?.tldr);
  if (tldr == null) return false;
  final content = _text(report?.content);
  return goalReportSections(report) != null ||
      (content != null && content != tldr);
}

/// The expanded report's sections in reading order, each with its heading in
/// the app's language, those the model left empty left out.
///
/// Headings come from the app's catalogs rather than the model, so they read
/// in the user's language whatever language the report was written in.
List<(String heading, String body)> goalReportExpandedSections(
  Map<String, Object?> sections,
  AppLocalizations messages,
) => [
  for (final (key, heading) in <(String, String)>[
    (GoalReportSectionKeys.currentPeriod, messages.goalReportSectionStanding),
    (GoalReportSectionKeys.rollingWindow, messages.goalReportSectionWindow),
    (GoalReportSectionKeys.latestChange, messages.goalReportSectionChange),
    (GoalReportSectionKeys.coverage, messages.goalReportSectionCoverage),
  ])
    if (_text(sections[key]) case final body?) (heading, body),
];

/// What the read-aloud control speaks for a goal report: everything the card
/// shows, in the card's order, so the voice never stops at the summary.
///
/// The summary ([fallback] while there is no report), then what the agent
/// made of the user's check-ins and what comes next — both always on the
/// card — and, while the card is [expanded], the sections behind "Show more"
/// (or the full text, for a report without sections). Collapsed again, the
/// voice reads what the card shows collapsed, as the task card's does.
///
/// Each heading is spoken as a sentence of its own: the voice runs line
/// breaks together, and a heading without a stop would run into its body.
String goalReportSpokenText({
  required AgentReportEntity? report,
  required String? fallback,
  required bool expanded,
  required AppLocalizations messages,
}) {
  final tldr = _text(report?.tldr);
  final content = _text(report?.content);
  final sections = goalReportSections(report);
  final summary = tldr ?? content ?? _text(fallback);
  final reflection = goalReportReflection(sections);
  final actions = goalReportActions(sections);
  return [
    ?summary,
    if (reflection != null) ...[
      _sentence(messages.goalReportSectionReflection),
      reflection,
    ],
    if (actions != null) ...[
      _sentence(messages.goalReportSectionNext),
      for (final action in actions) _sentence(action),
    ],
    if (expanded && goalReportExpandable(report))
      if (sections != null)
        for (final (heading, body) in goalReportExpandedSections(
          sections,
          messages,
        )) ...[_sentence(heading), body]
      else
        ?content,
  ].join('\n\n');
}

/// The keys of the sections behind "Show more".
const List<String> _expandedSectionKeys = [
  GoalReportSectionKeys.currentPeriod,
  GoalReportSectionKeys.rollingWindow,
  GoalReportSectionKeys.latestChange,
  GoalReportSectionKeys.coverage,
];

/// [value] trimmed when it is a non-blank string, else null.
String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

final _terminalMark = RegExp(r'[.!?…:;]$');

/// [text] ending in a stop, so a voice pauses after it.
String _sentence(String text) => _terminalMark.hasMatch(text) ? text : '$text.';
