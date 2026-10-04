part of 'task_agent_report_editor.dart';

/// A successful task mutation, stripped to the tool name and decoded inputs.
typedef TaskAgentMutationRecord = ({
  String toolName,
  Map<String, dynamic> arguments,
});

/// The three user-facing fields published by `update_report`.
class TaskAgentReportDraft {
  const TaskAgentReportDraft({
    required this.oneLiner,
    required this.tldr,
    required this.content,
  });

  /// Creates a draft only when all required report fields are non-empty.
  static TaskAgentReportDraft? fromJson(Map<String, dynamic> value) {
    final oneLiner = _nonEmptyString(value['oneLiner']);
    final tldr = _nonEmptyString(value['tldr']);
    final content = _nonEmptyString(value['content']);
    if (oneLiner == null || tldr == null || content == null) return null;
    return TaskAgentReportDraft(
      oneLiner: oneLiner,
      tldr: tldr,
      content: content,
    );
  }

  final String oneLiner;
  final String tldr;
  final String content;

  /// Serializes the draft for the compact editor request and regression checks.
  Map<String, dynamic> toJson() => {
    'oneLiner': oneLiner,
    'tldr': tldr,
    'content': content,
  };
}

/// Known report defects that the bounded repair pass can correct.
enum TaskAgentReportRevisionIssue {
  invalidShape('Return non-empty oneLiner, tldr, and content fields.'),
  missingPriority('Restore the current task priority.'),
  missingDueDate('Restore the current due date and its purpose.'),
  missingEstimate('Restore the current time estimate.'),
  processNarration(
    'Remove task setup, transcription, readiness, and waiting narration. '
    'Remove every reference to the checklist itself, including saying it '
    'has, contains, includes, received, queued, identified, extracted, or '
    'created items; present the actions directly without counting workflow '
    'items. Pending work is never underway, in progress, started, established, '
    'or active without explicit source evidence. When the source says an '
    'investigation is needed, keep it pending. Do not invent generic '
    'downstream fixes or validation after a pending investigation. Do not turn '
    'an unperformed request into waiting for its result.',
  ),
  checkmarkCausality(
    'State a user-marked-complete item neutrally. Remove causal claims and '
    'explanations of what the checkmark does or does not prove.',
  ),
  unsupportedPriority(
    'Remove every priority label or claim unless the original draft or '
    'material task state contains one. Keep action order without calling it '
    'a priority.',
  ),
  fakeLinkSection(
    'Remove Links or Reference sections that contain no HTTP or HTTPS URL.',
  ),
  formalRegister('Use the configured informal language register.'),
  deferredScopeLeak(
    'Remove every mention of explicitly deferred, rejected, omitted, or '
    'out-of-scope concepts, including explanations that they were excluded.',
  ),
  missingActiveRisk(
    'Restore the active constraint, risk, blocker, or root-cause investigation.',
  );

  const TaskAgentReportRevisionIssue(this.correction);

  /// The exact repair instruction sent after this issue is detected.
  final String correction;
}

/// The bounded report-editing outcome.
class TaskAgentReportEditResult {
  const TaskAgentReportEditResult({
    required this.revision,
    required this.hadRevision,
    required this.attempts,
    required this.validationIssues,
    required this.usage,
    required this.error,
    required this.stackTrace,
    this.rejectedReport,
  });

  /// Accepted revision, or `null` when every candidate was rejected.
  final TaskAgentReportDraft? revision;

  /// The last candidate validation rejected, when no revision was accepted.
  ///
  /// Not published anywhere; evaluations record it to show why a repair
  /// failed.
  final TaskAgentReportDraft? rejectedReport;

  /// Whether the editor returned at least one `update_report` candidate.
  final bool hadRevision;

  /// Number of editor calls made.
  final int attempts;

  /// Remaining issues on the last rejected candidate.
  final List<TaskAgentReportRevisionIssue> validationIssues;

  /// Combined usage from every editor attempt.
  final InferenceUsage? usage;

  /// Error from the final attempt, if inference aborted before validation.
  final Object? error;

  /// Stack trace paired with [error].
  final StackTrace? stackTrace;
}

/// How a task agent's published report reaches the user.
enum TaskAgentReportRoute {
  /// Published as written.
  none,

  /// Always revised by the editor before publishing.
  alwaysEdited,

  /// Checked by the deterministic defect detector, and handed to the editor
  /// only when it finds a known defect. A clean report publishes untouched.
  detected,
}

class _TaskAgentReportCaptureStrategy extends ConversationStrategy {
  TaskAgentReportDraft? report;
  bool sawReportCall = false;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      if (call.function.name != TaskAgentToolNames.updateReport) {
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Only update_report is accepted.',
        );
        continue;
      }
      sawReportCall = true;

      TaskAgentReportDraft? candidate;
      try {
        final decoded = jsonDecode(call.function.arguments);
        if (decoded is Map<String, dynamic>) {
          candidate = TaskAgentReportDraft.fromJson(decoded);
        }
      } on FormatException {
        candidate = null;
      }
      if (candidate == null) {
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Invalid report fields.',
        );
        continue;
      }

      report = candidate;
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Report revision captured.',
      );
    }
    return ConversationAction.complete;
  }

  // coverage:ignore-start
  @override
  bool shouldContinue(ConversationManager manager) => false;

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
  // coverage:ignore-end
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _reportFieldText(Map<String, dynamic> report) => [
  report['oneLiner'],
  report['tldr'],
  report['content'],
].whereType<String>().join('\n');
bool _containsReportDate(String report, String isoDate) {
  if (report.contains(isoDate.toLowerCase())) return true;
  final parts = isoDate.split('-');
  if (parts.length != 3) return report.contains(isoDate.toLowerCase());
  final year = parts[0];
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || !report.contains(year)) return false;
  const monthTerms = <int, List<String>>{
    1: ['january', 'januar', 'enero', 'janvier', 'ianuarie', 'leden'],
    2: ['february', 'februar', 'febrero', 'février', 'februarie', 'únor'],
    3: ['march', 'märz', 'marzo', 'mars', 'martie', 'březen'],
    4: ['april', 'abril', 'avril', 'aprilie', 'duben'],
    5: ['may', 'mai', 'mayo', 'mai', 'květen'],
    6: ['june', 'juni', 'junio', 'juin', 'iunie', 'červen'],
    7: ['july', 'juli', 'julio', 'juillet', 'iulie', 'červenec'],
    8: ['august', 'agosto', 'août', 'august', 'srpen'],
    9: ['september', 'septiembre', 'septembre', 'septembrie', 'září'],
    10: ['october', 'oktober', 'octubre', 'octobre', 'octombrie', 'říjen'],
    11: ['november', 'noviembre', 'novembre', 'noiembrie', 'listopad'],
    12: [
      'december',
      'dezember',
      'diciembre',
      'décembre',
      'decembrie',
      'prosinec',
    ],
  };
  final hasDay = RegExp('(^|\\D)0?$day(\\D|\$)').hasMatch(report);
  final hasMonth =
      report.contains(parts[1]) ||
      (monthTerms[month]?.any(report.contains) ?? false);
  return hasDay && hasMonth;
}

bool _containsReportEstimate(String report, num minutes) {
  final normalizedMinutes = minutes.toString().replaceFirst(
    RegExp(r'\.0$'),
    '',
  );
  if (_containsNumberWithUnit(
    report,
    normalizedMinutes,
    const [
      'm',
      'min',
      'mins',
      'minute',
      'minutes',
      'minuten',
      'minuto',
      'minutos',
      'minut',
      'minuty',
    ],
  )) {
    return true;
  }
  final hours = minutes / 60;
  final normalizedHours = hours % 1 == 0
      ? hours.toStringAsFixed(0)
      : hours
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
  return _containsNumberWithUnit(
    report,
    normalizedHours,
    const [
      'h',
      'hr',
      'hrs',
      'hour',
      'hours',
      'stunde',
      'stunden',
      'hora',
      'horas',
      'heure',
      'heures',
      'oră',
      'ore',
      'hodina',
      'hodiny',
      'hodin',
    ],
  );
}

bool _containsNumberWithUnit(
  String report,
  String number,
  List<String> units,
) {
  final decimalVariants = {
    RegExp.escape(number),
    RegExp.escape(number.replaceFirst('.', ',')),
  }.join('|');
  final unitPattern = units.map(RegExp.escape).join('|');
  return RegExp(
    '(^|\\D)(?:$decimalVariants)\\s*-?\\s*(?:$unitPattern)\\b',
  ).hasMatch(report);
}
