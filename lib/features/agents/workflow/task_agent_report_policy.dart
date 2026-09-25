import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// A task status change that happened after the current report was written.
typedef TaskStatusTransition = ({String from, String to});

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

  /// The status the task had when a report written at [reportCreatedAt] was
  /// published, paired with the one it has now, or `null` when they match.
  ///
  /// The report's prose is never shown to the model, so without this it sees
  /// only the current status and cannot tell that a task moved to DONE since
  /// the report still calling it IN PROGRESS was written. The baseline is
  /// read from the task's own timestamped status history, which every status
  /// change appends to, so reports written before this check existed are
  /// covered too. Returns `null` when there is no report or no status that
  /// predates it.
  static TaskStatusTransition? statusTransitionSinceReport({
    required TaskData? task,
    required DateTime? reportCreatedAt,
  }) {
    if (task == null || reportCreatedAt == null) return null;
    final statusAtReport = [...task.statusHistory, task.status]
        .where((status) => !status.createdAt.isAfter(reportCreatedAt))
        .fold<TaskStatus?>(
          null,
          (latest, status) =>
              latest == null || !status.createdAt.isBefore(latest.createdAt)
              ? status
              : latest,
        );
    if (statusAtReport == null) return null;
    final from = statusAtReport.toDbString;
    final to = task.status.toDbString;
    return from == to ? null : (from: from, to: to);
  }

  /// States a status change as the material fact it is, so the model does
  /// not have to infer it from a report it cannot see.
  static String statusTransitionContext(TaskStatusTransition transition) =>
      '## Material Change Since Last Report\n'
      'The task status changed from ${transition.from} to ${transition.to} '
      'after the current report was written. That report still describes the '
      'task as ${transition.from}, so it is stale: publish an updated report '
      'that reflects the current status.\n\n';

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
  /// The clause must be introduced by "with" or "and" and must end the line:
  /// "No deadline is set yet — the March cutoff will drive the timing" keeps
  /// its reasoning, and "The task can proceed with no due date set, and the
  /// owner will confirm tomorrow" keeps its condition, because the note is not
  /// what the sentence ends on.
  static final _absentMetadataClause = RegExp(
    r'(?:\s*[,;—–-]+\s*|\s+)(?:with|and)\s+no\s+'
    '$_metadataNouns'
    '(?:\\s*(?:,|,?\\s*(?:or|and))\\s*$_metadataNouns)*'
    r'\s*(?:is|are|has\s+been|have\s+been)?\s*'
    '(?:set|recorded|specified|defined|assigned|given|requested)?'
    r'(?:\s+yet)?(?=[.!]?\s*$)',
    caseSensitive: false,
  );

  /// The sentence without any clause that only reports absent metadata.
  ///
  /// Models join the note to real content — "No due date or estimate has been
  /// set, and no code changes have been made yet" — so the sentence is split on
  /// its own conjunctions and each part judged alone. What remains is rejoined
  /// and recapitalised. Only coordinate clauses are split: a subordinate
  /// "though the March cutoff will drive the timing" cannot stand without the
  /// clause it qualifies, so that sentence is left whole.
  /// A list, quote or numbered marker, which belongs to the line rather than
  /// to the sentence it introduces. Report content is free-form Markdown, so
  /// the note arrives as often in a bullet as in a paragraph.
  static final _lineMarker = RegExp(r'^\s*(?:[-*•>]|\d+[.)])\s+');

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

  /// Whether [body] only says the section is empty.
  ///
  /// The opening clause, up to a dash or full stop, must itself be the
  /// negation: "None from you right now — the gate sits with Marta" qualifies,
  /// while "None of the sensors report, so the swap is blocked" does not,
  /// because there the negation is the subject of a real statement.
  static bool _saysNothing(String body) {
    final opening = body
        .split(RegExp(r'\s*[—–]\s*|(?<=[.!;:])\s'))
        .first
        .trim();
    if (RegExp(
      r'^(?:none|nothing)\s+of\b',
      caseSensitive: false,
    ).hasMatch(opening)) {
      return false;
    }
    if (opening.split(RegExp(r'\s+')).length > 6) return false;
    // "None", plus the time and audience fillers models pad it with.
    final bare = opening
        .replaceFirst(
          RegExp(
            r'^(?:none|nothing|n/?a|no\s+\w+(?:\s+\w+)?\s+(?:is\s+|are\s+)?'
            r'(?:needed|required|outstanding|pending|open))\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:from|for|at|on|in|to|of|the|this|your|you|us|we|me|i|'
            'right|now|currently|yet|today|here|moment|time|point|side|'
            'part|present|stage|outstanding|pending|open|needed|required|'
            'blocking|left|else|further|additional|new|action|actions|'
            r'decision|decisions|blocker|blockers|risk|risks)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp('[^A-Za-z]'), '');
    return bare.isEmpty;
  }

  /// [report] cleaned of notes and empty sections, or unchanged when that
  /// would leave nothing.
  ///
  /// A report whose every sentence is filtered away is a report the model
  /// wrote badly, not one it did not write: publishing the empty string would
  /// skip the report a required wake owes and leave the previous one looking
  /// fresh. The draft is published as it stands instead.
  static String withoutPublicationNoise(String report) {
    final cleaned = withoutEmptySections(withoutAbsentMetadataNotes(report));
    return cleaned.trim().isEmpty ? report : cleaned;
  }

  /// [report] without Markdown sections whose body only says "none".
  ///
  /// The contract already asks for empty sections to be omitted, yet models
  /// write "## Decision needed" followed by "None from you right now — the gate
  /// sits with Marta", which repeats what the sections above already say. Four
  /// of the glm-5.3 control's decision-memo failures on 2026-09-15..18 were
  /// exactly this. A section with anything else — a bullet list, a second
  /// paragraph — is kept whole.
  static String withoutEmptySections(String report) {
    final lines = report.split('\n');
    final kept = <String>[];
    for (var index = 0; index < lines.length; index++) {
      final heading = RegExp(r'^(#{2,6})\s+\S').firstMatch(lines[index]);
      if (heading == null) {
        kept.add(lines[index]);
        continue;
      }
      final level = heading.group(1)!.length;
      var end = index + 1;
      while (end < lines.length &&
          !RegExp('^#{2,$level}\\s+\\S').hasMatch(lines[end])) {
        end++;
      }
      final body = lines
          .sublist(index + 1, end)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final isEmptyClaim = body.length == 1 && _saysNothing(body.single.trim());
      if (body.isEmpty || isEmptyClaim) {
        index = end - 1;
        continue;
      }
      kept.add(lines[index]);
    }
    return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
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
      final marker = _lineMarker.stringMatch(line) ?? '';
      final body = line.substring(marker.length);
      final sentences = body.split(RegExp(r'(?<=[.!])\s+'));
      final remaining = sentences
          .where((sentence) => !_absentMetadataNote.hasMatch(sentence))
          .map(_withoutAbsentMetadataClauses)
          .where((sentence) => sentence.isNotEmpty)
          .join(' ')
          .trimRight();
      // A line that was only such a note disappears; one that carried other
      // prose keeps it. Bullets and headings are lines, so neither is joined
      // into its neighbour.
      if (sentences.isNotEmpty && remaining.isEmpty && body.trim().isNotEmpty) {
        continue;
      }
      kept.add(remaining.isEmpty ? line : marker + remaining);
    }
    return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Housekeeping alone does not stale an existing task report. The model may
  /// still publish when independent evidence changes the task's material state.
  /// A status change since the report was written ([taskStatusChanged]) always
  /// stales it, whoever made the change.
  static bool requiresReport({
    required bool hasExistingReport,
    required Iterable<String> successfulToolNames,
    bool taskStatusChanged = false,
  }) =>
      !hasExistingReport ||
      taskStatusChanged ||
      successfulToolNames.any(
        (name) => !const {
          TaskAgentToolNames.assignTaskLabel,
          TaskAgentToolNames.assignTaskLabels,
          TaskAgentToolNames.setTaskLanguage,
        }.contains(name),
      );
}
