import 'package:intl/intl.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart'
    show isValidDueDateWireValue;
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Rebuilds a proposal's display text in the reader's language from the tool
/// call that produced it.
///
/// `ChangeItem.humanSummary` is generated headlessly during an agent wake,
/// where no `BuildContext` and no locale exist, and is then **persisted into a
/// synced entity** — so it is English on every device forever, and cannot be
/// retranslated in place without rewriting history on every peer. It also
/// backs `ChangeItem.displayDuplicateKey` and the retraction matcher, so its
/// value must stay stable regardless of who is reading.
///
/// The fix is therefore to re-derive the sentence at render time from
/// `toolName` + `args`, which *are* structured data, and to keep the persisted
/// string as the fallback. Returns `null` when the tool has no shape here, or
/// when the args cannot identify the proposal's *subject* (a link with no
/// readable target, a checklist item with no title) — the caller then shows
/// the persisted English rather than nothing.
///
/// A missing or malformed *value* inside a known shape does **not** return
/// `null`: it degrades exactly as the wake-time generator degrades — `?` for
/// an absent status, the verbatim string for an unparseable timestamp —
/// because the persisted summary was built from these same args and carries
/// the identical degradation in English. Falling back would recover no
/// information; it would only surrender the translation. The one exception is
/// a non-numeric estimate: the estimate sentence is an ICU plural, and no
/// language can conjugate "minutes" around a value that is not a number, so
/// that case alone falls back to the persisted summary.
///
/// Values with an enumerable wire vocabulary — task status, task priority,
/// project status — render through the same localized labels the rest of the
/// UI uses for them, normalized the way their apply-path handlers normalize
/// them. A value outside the vocabulary passes through verbatim: what the
/// model actually asked for is still evidence, and the row must not hide it.
///
/// Every shape is a whole sentence from the ARB catalog. Nothing is assembled
/// from fragments in Dart, because word order, case and agreement differ by
/// language: see [knowledge/conventions/localization.md].
String? localizedChangeSummary(
  AppLocalizations messages,
  String toolName,
  Map<String, dynamic> args,
) => switch (toolName) {
  TaskAgentToolNames.setTaskTitle => messages.agentSummarySetTitle(
    _string(args['title'], fallback: '?'),
  ),
  TaskAgentToolNames.updateTaskEstimate => _estimate(messages, args['minutes']),
  TaskAgentToolNames.updateTaskDueDate => messages.agentSummarySetDueDate(
    _dueDate(messages, args['dueDate']),
  ),
  TaskAgentToolNames.updateTaskPriority => messages.agentSummarySetPriority(
    _priority(messages, args['priority']),
  ),
  TaskAgentToolNames.setTaskStatus => messages.agentSummarySetStatus(
    _status(messages, args['status']),
  ),
  TaskAgentToolNames.setTaskLanguage => messages.agentSummarySetLanguage(
    _string(args['languageCode'], fallback: '?'),
  ),
  TaskAgentToolNames.createFollowUpTask => _followUp(messages, args),
  TaskAgentToolNames.linkTask => _link(messages, args),
  TaskAgentToolNames.createTimeEntry => _createTimeEntry(messages, args),
  TaskAgentToolNames.updateRunningTimer =>
    messages.agentSummaryUpdateRunningTimer(_trimmed(args['summary'])),
  TaskAgentToolNames.updateTimeEntry => _updateTimeEntry(messages, args),

  // The literal spelling, not GoalAgentToolNames: `features/agents`
  // must not import goals (the plug-in direction the arch test pins).
  'propose_goal_revision' => _goalRevision(messages, args),

  ProjectAgentToolNames.recommendNextSteps => _recommendNextSteps(
    messages,
    args,
  ),
  ProjectAgentToolNames.updateProjectStatus =>
    messages.agentSummaryUpdateProjectStatus(
      _projectStatus(messages, args['status']),
    ),
  ProjectAgentToolNames.createTask => messages.agentSummaryCreateTask(
    _string(args['title'], fallback: '?'),
  ),

  EventAgentToolNames.suggestFollowUpTask => _suggestFollowUp(messages, args),

  // Batch tools reach the row already exploded into singular items, each
  // carrying the model's own element as its args.
  TaskAgentToolNames.addChecklistItem => _addChecklistItem(messages, args),
  TaskAgentToolNames.updateChecklistItem => _updateChecklistItem(
    messages,
    args,
  ),
  TaskAgentToolNames.migrateChecklistItem => _migrateChecklistItem(
    messages,
    args,
  ),

  _ => null,
};

/// The localized sentence for one directed task relationship, with [target]
/// as its object.
///
/// Mirrors `directedRelationLabel` in `relationship_type_selector.dart`, but
/// resolves a whole sentence rather than the standalone phrase that reads as a
/// dropdown option: "Blocks" cannot be dropped into the middle of a sentence,
/// in English or anywhere else.
String localizedRelationSentence(
  AppLocalizations messages,
  DirectedRelation relation,
  String target,
) => switch ((relation.type, relation.inverse)) {
  (EntryLinkType.blocks, false) => messages.linkSummaryBlocksPrimary(target),
  (EntryLinkType.blocks, true) => messages.linkSummaryBlocksInverse(target),
  (EntryLinkType.followsUp, false) => messages.linkSummaryFollowsUpPrimary(
    target,
  ),
  (EntryLinkType.followsUp, true) => messages.linkSummaryFollowsUpInverse(
    target,
  ),
  (EntryLinkType.duplicates, false) => messages.linkSummaryDuplicatesPrimary(
    target,
  ),
  (EntryLinkType.duplicates, true) => messages.linkSummaryDuplicatesInverse(
    target,
  ),
  (EntryLinkType.fixes, false) => messages.linkSummaryFixesPrimary(target),
  (EntryLinkType.fixes, true) => messages.linkSummaryFixesInverse(target),
  (EntryLinkType.supersedes, false) => messages.linkSummarySupersedesPrimary(
    target,
  ),
  (EntryLinkType.supersedes, true) => messages.linkSummarySupersedesInverse(
    target,
  ),
  // `basic` is symmetric, so it has no primary/inverse reading. `rating` and
  // `project` are not task relationships and cannot reach a link proposal.
  _ => messages.linkSummaryBasic(target),
};

String? _addChecklistItem(
  AppLocalizations messages,
  Map<String, dynamic> args,
) {
  final title = args['title'];
  if (title is! String || title.isEmpty) return null;
  return messages.agentSummaryAddItem(title);
}

/// A checklist update reads as its verb — archive, restore, check, uncheck.
///
/// Returns `null` unless the element carries its own `title`. For an update
/// addressed purely by id the title was resolved from the database during the
/// wake and never stored in `args`, so it survives only in the persisted
/// summary; falling back to that English string beats rendering a bare id.
String? _updateChecklistItem(
  AppLocalizations messages,
  Map<String, dynamic> args,
) {
  final title = args['title'];
  if (title is! String || title.isEmpty) return null;

  final isArchived = args['isArchived'];
  if (isArchived is bool) {
    return isArchived
        ? messages.agentSummaryArchiveItem(title)
        : messages.agentSummaryRestoreItem(title);
  }
  final isChecked = args['isChecked'];
  if (isChecked is bool) {
    return isChecked
        ? messages.agentSummaryCheckItem(title)
        : messages.agentSummaryUncheckItem(title);
  }
  // Neither flag set: the proposal is a rename, and the new title is right
  // here in the args.
  return messages.agentSummaryUpdateItem(title);
}

/// A checklist item moving to a freshly created follow-up task.
///
/// `migrate_checklist_items` requires `title` on every element precisely so it
/// can be displayed, so this is reconstructible where an id-only update is not.
String? _migrateChecklistItem(
  AppLocalizations messages,
  Map<String, dynamic> args,
) {
  final title = args['title'];
  if (title is! String || title.isEmpty) return null;
  return messages.agentSummaryMigrateItem(title);
}

/// A task status rendered through the same localized labels the task header
/// and status selector use.
///
/// The tool value is wire vocabulary (`IN PROGRESS`, `ON HOLD`), normalized
/// the way `TaskStatusHandler` normalizes it. Left raw it kept the row
/// half-English — `Status auf IN PROGRESS setzen` — in an otherwise translated
/// sentence. A value outside the vocabulary passes through verbatim: what the
/// model actually asked for is still evidence, and the proposal row must not
/// hide it.
String _status(AppLocalizations messages, Object? raw) {
  if (raw == null) return '?';
  final text = raw.toString();
  return switch (text.trim().toUpperCase()) {
    'OPEN' => messages.taskStatusOpen,
    'GROOMED' => messages.taskStatusGroomed,
    'IN PROGRESS' => messages.taskStatusInProgress,
    'BLOCKED' => messages.taskStatusBlocked,
    'ON HOLD' => messages.taskStatusOnHold,
    'DONE' => messages.taskStatusDone,
    'REJECTED' => messages.taskStatusRejected,
    _ => text,
  };
}

/// A task priority rendered through the same localized labels the task
/// header and priority selector use.
///
/// The tool vocabulary is `P0`–`P3`, accepted exactly as
/// `TaskPriorityHandler.parsePriority` accepts it. Left raw it kept the code
/// in an otherwise translated sentence, even though accepting the proposal
/// sets a priority the task UI displays as Urgent/High/Medium/Low. A value
/// outside the vocabulary passes through verbatim.
String _priority(AppLocalizations messages, Object? raw) {
  if (raw == null) return '?';
  final text = raw.toString();
  return switch (text.trim().toUpperCase()) {
    'P0' => messages.taskPriorityUrgent,
    'P1' => messages.taskPriorityHigh,
    'P2' => messages.taskPriorityMedium,
    'P3' => messages.taskPriorityLow,
    _ => text,
  };
}

/// A project status rendered through the labels the project status chips use.
///
/// The tool accepts aliases (`blocked`, `hold`, `done`, …) that the apply
/// path collapses into the six `ProjectStatus` variants, so displaying the
/// raw value could describe a different status than accepting the proposal
/// sets — `blocked` actually becomes On Hold. [canonicalProjectStatus] is the
/// same normalization the dispatcher applies; a value outside the vocabulary
/// passes through verbatim.
String _projectStatus(AppLocalizations messages, Object? raw) {
  if (raw == null) return '?';
  final text = raw.toString();
  return switch (canonicalProjectStatus(text)) {
    'open' => messages.projectStatusOpen,
    'active' => messages.projectStatusActive,
    'monitoring' => messages.projectStatusMonitoring,
    'on_hold' => messages.projectStatusOnHold,
    'completed' => messages.projectStatusCompleted,
    'archived' => messages.projectStatusArchived,
    _ => text,
  };
}

/// The estimate sentence, or `null` when `minutes` is not a number.
///
/// The sentence is an ICU plural ("1 minute" / "45 minutes"), so it can only
/// be built around an actual number. A non-numeric value cannot fill a plural
/// slot in any language, and the persisted summary already shows the same
/// malformed value in English — so this is the one malformed-value case that
/// falls back rather than degrading in place.
String? _estimate(AppLocalizations messages, Object? raw) {
  final minutes = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (minutes == null) return null;
  return messages.agentSummarySetEstimate(minutes);
}

/// A due date rendered the way the rest of the task UI renders one.
///
/// The tool argument is a `YYYY-MM-DD` wire string, validated with the same
/// [isValidDueDateWireValue] check `TaskDueDateHandler` applies before
/// writing. Anything else — including a parseable-but-datetime value like
/// `2026-08-01T12:00:00`, which the handler rejects — passes through verbatim
/// rather than being formatted: prettifying it would describe a date the
/// proposal cannot actually set, and the model's malformed value is still
/// evidence of what it asked for.
String _dueDate(AppLocalizations messages, Object? raw) {
  if (raw == null) return '?';
  final text = raw.toString();
  if (!isValidDueDateWireValue(text)) return text;
  return DateFormat.yMMMd(messages.localeName).format(DateTime.parse(text));
}

String? _followUp(AppLocalizations messages, Map<String, dynamic> args) {
  final title = _string(args['title'], fallback: '?');
  final raw = args['relation'];
  final relation = raw is String ? DirectedRelation.fromWireName(raw) : null;
  if (relation == null) return messages.agentSummaryCreateFollowUp(title);
  return messages.agentSummaryCreateFollowUpRelated(
    title,
    localizedNewTaskRelationSentence(messages, relation),
  );
}

/// The relation clause of a *create follow-up* proposal, referring to the
/// task being created.
///
/// The follow-up does not exist yet, so [localizedRelationSentence] has no
/// title to name it — and no single word can be substituted into its
/// `{target}` slot either. That slot is a direct object in some templates and
/// a prepositional object in others, and languages with case decline the two
/// differently: Romanian needs the clitic `o` where `blochează ea` is
/// ungrammatical, German needs dative `ihr` after `von` where `sie` is
/// accusative. So these are their own whole sentences per catalog, with "the
/// new task" declined in place — never a fragment assembled in Dart.
String localizedNewTaskRelationSentence(
  AppLocalizations messages,
  DirectedRelation relation,
) => switch ((relation.type, relation.inverse)) {
  (EntryLinkType.blocks, false) => messages.linkSummaryNewTaskBlocksPrimary,
  (EntryLinkType.blocks, true) => messages.linkSummaryNewTaskBlocksInverse,
  (EntryLinkType.followsUp, false) =>
    messages.linkSummaryNewTaskFollowsUpPrimary,
  (EntryLinkType.followsUp, true) =>
    messages.linkSummaryNewTaskFollowsUpInverse,
  (EntryLinkType.duplicates, false) =>
    messages.linkSummaryNewTaskDuplicatesPrimary,
  (EntryLinkType.duplicates, true) =>
    messages.linkSummaryNewTaskDuplicatesInverse,
  (EntryLinkType.fixes, false) => messages.linkSummaryNewTaskFixesPrimary,
  (EntryLinkType.fixes, true) => messages.linkSummaryNewTaskFixesInverse,
  (EntryLinkType.supersedes, false) =>
    messages.linkSummaryNewTaskSupersedesPrimary,
  (EntryLinkType.supersedes, true) =>
    messages.linkSummaryNewTaskSupersedesInverse,
  // `basic` is symmetric; `rating` and `project` cannot reach a proposal.
  _ => messages.linkSummaryNewTaskBasic,
};

/// A task-relationship proposal, but **only** when a readable target title
/// travels in the args.
///
/// `task_agent_change_handlers.dart` canonicalizes these args down to
/// `relation` + `targetTaskId` on purpose, so formatting-only repeats of the
/// same link share a fingerprint. The resolved target *title* therefore lives
/// only in the persisted summary. Substituting the id would turn
/// `This task blocks "Ship the migration"` into `This task blocks "task-1"`,
/// so a missing title falls back to the persisted English instead: a readable
/// sentence in the wrong language beats an opaque id in the right one.
///
/// Widening the canonical args to carry the title is not a display-only
/// change — it would alter `ChangeItem.fingerprint` and so cross-wake dedup.
String? _link(AppLocalizations messages, Map<String, dynamic> args) {
  final raw = args['relation'];
  final relation = raw is String ? DirectedRelation.fromWireName(raw) : null;
  final target = args['targetTitle'];
  if (relation == null || target is! String || target.isEmpty) return null;
  return localizedRelationSentence(messages, relation, '"$target"');
}

/// Presence and validity of `endTime` are separate facts, exactly as they are
/// in the apply path: an *absent* key means a running timer and renders as an
/// open range, while a *present but malformed* value renders as `?` — the
/// wake-time generator's own degradation. Collapsing the two would describe a
/// proposal the handler will reject as an invalid completed session as if it
/// were a running timer.
String _createTimeEntry(AppLocalizations messages, Map<String, dynamic> args) {
  final start = _hhMm(args['startTime']);
  final range = args.containsKey('endTime')
      ? messages.agentSummaryTimeRangeBetween(
          start ?? '?',
          _hhMm(args['endTime']) ?? '?',
        )
      : messages.agentSummaryTimeRangeFrom(start ?? '?');
  return messages.agentSummaryTimeEntry(range, _trimmed(args['summary']));
}

String _updateTimeEntry(AppLocalizations messages, Map<String, dynamic> args) {
  final start = _hhMm(args['startTime']);
  final end = _hhMm(args['endTime']);
  final summary = _trimmed(args['summary']);

  final range = switch ((start, end)) {
    (final String s, final String e) => messages.agentSummaryTimeRangeBetween(
      s,
      e,
    ),
    (final String s, null) => messages.agentSummaryTimeRangeFrom(s),
    (null, final String e) => messages.agentSummaryTimeRangeUntil(e),
    _ => null,
  };

  if (summary.isEmpty) {
    return range == null
        ? messages.agentSummaryUpdateTimeEntry
        : messages.agentSummaryUpdateTimeEntryRange(range);
  }
  return range == null
      ? messages.agentSummaryReviseTimeEntryText(summary)
      : messages.agentSummaryUpdateTimeEntryRangeText(range, summary);
}

String _recommendNextSteps(
  AppLocalizations messages,
  Map<String, dynamic> args,
) {
  final steps = args['steps'];
  if (steps is List && steps.isNotEmpty) {
    return messages.agentSummaryRecommendNextStepsCount(steps.length);
  }
  return messages.agentSummaryRecommendNextSteps;
}

String _suggestFollowUp(AppLocalizations messages, Map<String, dynamic> args) {
  final title = args['title'];
  return title is String && title.trim().isNotEmpty
      ? messages.agentSummaryFollowUpTask(title.trim())
      : messages.agentSummarySuggestFollowUpTask;
}

/// The wall-clock `HH:mm` for a time-entry argument.
///
/// `null` only when the argument is absent — the caller then omits that end
/// of the range. An unparseable *present* value is returned verbatim instead,
/// exactly as the wake-time generator renders it: dropping it would make two
/// different proposals read identically, and the model's malformed value is
/// still evidence of what it asked for.
String? _hhMm(Object? raw) {
  if (raw is! String) return null;
  final parsed = parseTimeEntryLocalDateTime(raw);
  return parsed == null ? raw : formatTimeEntryHhMm(parsed);
}

String _string(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

String _trimmed(Object? value) => value is String ? value.trim() : '';

/// A goal revision proposal, rebuilt from its structured `changes` map —
/// the persisted humanSummary is English whatever the locale.
String? _goalRevision(AppLocalizations messages, Map<String, dynamic> args) {
  final changes = args['changes'];
  if (changes is! Map) return null;
  final parts = <String>[
    if (changes['targetValue'] != null)
      messages.agentSummaryGoalRevisionTarget(
        _localizedTarget(messages, changes['targetValue']),
      ),
    if (changes['period'] != null)
      messages.agentSummaryGoalRevisionPeriod(
        _localizedWindow(messages, '${changes['period']}'),
      ),
    if (changes['cadence'] != null)
      messages.agentSummaryGoalRevisionCadence(
        _localizedCadence(changes['cadence']),
      ),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Numeric targets follow the reader's decimal/grouping conventions
/// ("7,5" in German); a malformed value passes through verbatim.
String _localizedTarget(AppLocalizations messages, Object? value) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return '$value';
  return NumberFormat.decimalPattern(messages.localeName).format(number);
}

/// The model's window phrase ("rolling 14 days") re-rendered in the
/// reader's language; an unparseable phrase passes through verbatim —
/// still better than hiding the proposal.
String _localizedWindow(AppLocalizations messages, String phrase) =>
    switch (parseGoalWindowPhrase(phrase)) {
      GoalWindowDay() => messages.goalWindowSingleDay,
      GoalWindowRollingDays(:final count) => messages.goalWindowRollingDays(
        count,
      ),
      GoalWindowCalendarWeek() => messages.goalWindowCalendarWeek,
      GoalWindowCalendarMonth() => messages.goalWindowCalendarMonth,
      null => phrase,
    };

/// "4 times per week" → "4"; digits are locale-neutral, the surrounding
/// sentence carries the language.
String _localizedCadence(Object? cadence) =>
    parseGoalCadenceCount(cadence)?.toString() ?? '$cadence';
