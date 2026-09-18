import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Publication requirements shared by task-agent prompts and execution.
abstract final class TaskAgentReportPolicy {
  /// The same publication gate is rendered beside tools and in both scaffolds.
  static const publicationRule =
      'When no report exists yet or a material task change makes the existing '
      'report stale, call `update_report` exactly once as the final action. '
      'Otherwise finish with a brief plain-text note and do not republish '
      'unchanged content. Label or language housekeeping alone does not '
      'require a new report.';

  /// Existing-report context contains no prior report prose.
  static const existingReportContext = '''
## Report Publication State
A report already exists. Before publishing, identify a new or corrected task fact that changes the situation, outcome, next action, deadline, or blocker. A note confirming that things are still the same is not such a change. Different wording, another wake, or a housekeeping label/language proposal does not warrant a new report. Skip optional label/language tidying on a no-change wake; still honor explicit user requests. If no material fact changed, do not call `update_report`; finish with a brief plain-text note. If evidence does change the task or correct a stale claim, publish the updated report after any justified tool calls.

''';

  static const firstReportContext = '''
## First Wake — No prior report exists. Produce an initial report.

''';

  /// Routine initialization is deferred on a quiet wake; explicit intent wins.
  static const languageRule =
      'Write public report fields in the task language. Detect and set language '
      'only when it is currently absent and a report is required. On a no-change '
      'wake, skip routine language initialization. Honor an explicit language '
      'request.';

  /// Resolve conditional additions before drafting, then verify the outline.
  static const conditionalSectionRule =
      'First select the required headings from the active report directive, '
      'then test each conditional section against current evidence. A '
      'conditional addition extends the required heading list: "use exactly" '
      'for that list does not cancel a later conditional addition. For example, '
      'two required sections plus a source section when a URL exists means '
      'three sections when a URL is present. Build this heading outline before '
      'writing the prose, then fill each section. Before calling update_report, '
      'check the content against that outline: every required and activated '
      'conditional heading must be present with its exact spelling. '
      'Evidence activating a section must appear under its requested heading; '
      'an inline link elsewhere does not replace a requested evidence section. '
      'Omit the entire conditional section when its condition is false. Never '
      'invent headings for a directive requesting none.';

  /// Presentation directives cannot invent a decision or a user dependency.
  static const decisionSectionRule =
      'A decision section requires an unresolved decision the user can make now. '
      'Identify source evidence of a specific missing input only the user can '
      'provide now. Do not invent missing criteria or ask the user to reconfirm '
      "criteria that are already stated. Someone else's approval, a future "
      'evaluation result, or a routine next step is not a current user decision. '
      'Report such dependencies with the pending work. For example: a '
      'supplier-owned review still pending means list that dependency under '
      'next actions and omit the optional decision heading; a comparison not '
      'yet run means run the comparison first.';

  static const changedEntitiesRule =
      'These are triggers to inspect, not proof of material progress. '
      'Read what changed before deciding whether to publish a report.';

  static const closingInstruction =
      'Analyze the current state, maintain any attention requests, and call '
      'tools if needed. $publicationRule Add observations if warranted.';

  /// Rendered by production and synthetic eval contexts from the same source.
  static String changedEntitiesContext({
    required Iterable<String> triggerTokens,
    required bool hasReport,
  }) {
    final sorted = triggerTokens.toList()..sort();
    if (sorted.isEmpty) return '';
    return '## Changed Since Last Wake\n'
        'The following entity IDs changed: ${sorted.join(", ")}\n'
        '${hasReport ? '$changedEntitiesRule\n' : ''}\n';
  }

  /// A sentence that only states which metadata the task lacks.
  ///
  /// Anchored at both ends, so a sentence that carries anything else — "No
  /// deadline is set yet — the March cutoff will drive the timing" — is left
  /// alone. Only the bare note is removed.
  static final _absentMetadataNote = RegExp(
    r'^\s*(?:and\s+)?(?:there\s+(?:is|are)\s+)?no\s+'
    '$_metadataNouns'
    '(?:\\s*(?:,|,?\\s*(?:or|and))\\s*$_metadataNouns)*'
    r'\s*(?:is|are|has\s+been|have\s+been)?\s*'
    '(?:set|recorded|specified|defined|assigned|given|requested)?'
    r'(?:\s+yet)?(?:\s+for\s+(?:this|the)\s+\w+)?\s*[.!,;]?\s*$',
    caseSensitive: false,
  );

  /// The metadata a report may be tempted to call absent.
  static const _metadataNouns =
      r'(?:\w+\s+)?(?:estimate|due\s+date|deadline|target\s+date|'
      r'scheduling\s+request|planner\s+time|priority|owner)';

  /// A trailing clause that only appends which metadata the task lacks, as in
  /// "the task is open with no due date or estimate set".
  ///
  /// The clause must be introduced by "with" or "and": "No deadline is set yet
  /// — the March cutoff will drive the timing" keeps its reasoning.
  static final _absentMetadataClause = RegExp(
    r'(?:\s*[,;—–-]+\s*|\s+)(?:with|and)\s+no\s+'
    '$_metadataNouns'
    '(?:\\s*(?:,|,?\\s*(?:or|and))\\s*$_metadataNouns)*'
    r'\s*(?:is|are|has\s+been|have\s+been)?\s*'
    '(?:set|recorded|specified|defined|assigned|given|requested)?'
    r'(?:\s+yet)?(?=[.!,;]|\s*$)',
    caseSensitive: false,
  );

  /// [sentence] without any clause that only reports absent metadata.
  ///
  /// Models join the note to real content — "No due date or estimate has been
  /// set, and no code changes have been made yet" — so the sentence is split on
  /// its own conjunctions and each part judged alone. What remains is rejoined
  /// and recapitalised. Only coordinate clauses are split: a subordinate
  /// "though the March cutoff will drive the timing" cannot stand without the
  /// clause it qualifies, so that sentence is left whole.
  static String _withoutAbsentMetadataClauses(String sentence) {
    final trailingTrimmed = sentence.replaceAll(_absentMetadataClause, '');
    final clauses = trailingTrimmed
        .split(
          RegExp(r';\s+|,\s+(?=(?:and|but)\s+|no\s+)'),
        )
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty)
        .toList();
    if (clauses.length < 2) {
      return _absentMetadataNote.hasMatch(trailingTrimmed)
          ? ''
          : trailingTrimmed;
    }
    final kept = clauses
        .where((clause) => !_absentMetadataNote.hasMatch(clause))
        .map((clause) => clause.replaceFirst(RegExp(r'^(?:and|but)\s+'), ''))
        .toList();
    if (kept.isEmpty) return '';
    if (kept.length == clauses.length) return trailingTrimmed;
    final rejoined = kept.join('; ');
    final ended = RegExp(r'[.!?]$').hasMatch(rejoined)
        ? rejoined
        : '$rejoined.';
    return ended[0].toUpperCase() + ended.substring(1);
  }

  /// [report] without sentences or clauses that only report absent metadata.
  ///
  /// The report contract says to omit absent metadata, yet every efficient
  /// model still writes "No estimate or due date is set." It caused 7 of the
  /// 12 failed `task-workflow` gym samples on 2026-09-15..17, across all three
  /// models, at both temperatures and under both prompt scaffolds. Removing
  /// the sentence keeps everything the model got right instead of discarding
  /// or rewriting the report.
  static String withoutAbsentMetadataNotes(String report) {
    final kept = <String>[];
    for (final line in report.split('\n')) {
      final sentences = line.split(RegExp(r'(?<=[.!])\s+'));
      final remaining = sentences
          .where((sentence) => !_absentMetadataNote.hasMatch(sentence))
          .map(_withoutAbsentMetadataClauses)
          .where((sentence) => sentence.isNotEmpty)
          .join(' ')
          .trimRight();
      // A line that was only such a note disappears; one that carried other
      // prose keeps it. Bullets and headings are lines, so neither is joined
      // into its neighbour.
      if (sentences.isNotEmpty && remaining.isEmpty && line.trim().isNotEmpty) {
        continue;
      }
      kept.add(remaining.isEmpty ? line : remaining);
    }
    return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Housekeeping alone does not stale an existing task report. The model may
  /// still publish when independent evidence changes the task's material state.
  static bool requiresReport({
    required bool hasExistingReport,
    required Iterable<String> successfulToolNames,
  }) =>
      !hasExistingReport ||
      successfulToolNames.any(
        (name) => !const {
          TaskAgentToolNames.assignTaskLabel,
          TaskAgentToolNames.assignTaskLabels,
          TaskAgentToolNames.setTaskLanguage,
        }.contains(name),
      );
}
