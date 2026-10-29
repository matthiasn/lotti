import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

/// The key a report records for one check-in it had in front of it: the
/// check-in's entry and the digest of the words its summary was distilled
/// from. The digest makes a re-transcription or an edit read as something the
/// report has not seen; the entry keeps two check-ins that say the same thing
/// apart — a concern repeated word for word is still said twice. A summary
/// written before digests existed falls back to its id.
String goalCheckInReflectionKey(GoalCheckInSummary summary) =>
    '${summary.sourceEntryId}:${summary.sourceDigest ?? summary.id}';

/// Which of the check-ins one wake shows verbatim the standing report has
/// already reflected, and which it has not.
///
/// The report a wake writes records [shown]; the next wake compares its own
/// verbatim check-ins against that record. Comparing by recording time
/// instead fails the case this exists for: a voice check-in is recorded, its
/// minutes refresh the report, and the transcript lands after that report —
/// recorded before it, read after it.
class GoalCheckInReflection {
  const GoalCheckInReflection({
    required this.shown,
    required this.unreflectedEntryIds,
  });

  static const none = GoalCheckInReflection(
    shown: [],
    unreflectedEntryIds: {},
  );

  /// Reflection keys of every check-in shown verbatim, oldest first — what a
  /// report written by this wake persists under
  /// [GoalReportProvenanceKeys.checkInsReflected].
  final List<String> shown;

  /// Source entry ids of the shown check-ins absent from the standing
  /// report's record.
  final Set<String> unreflectedEntryIds;

  /// Marks the verbatim `userVoice` entries the report has not reflected, so
  /// the model knows which words are new to it. Every other entry passes
  /// through untouched.
  List<Map<String, Object?>> mark(List<Map<String, Object?>> userVoice) => [
    for (final entry in userVoice)
      if (unreflectedEntryIds.contains(entry['sourceEntryId']))
        {...entry, 'sinceLastReport': true}
      else
        entry,
  ];
}

/// Compares the check-ins [userVoice] shows verbatim against what
/// [standingReport] recorded reflecting.
///
/// Only verbatim entries count: a digest has no words of its own to answer,
/// and a check-in old enough to be folded into one was either reflected long
/// ago or is history now. A report from before the record existed counts as
/// having reflected nothing, so the first wake after it engages once with what
/// it shows.
GoalCheckInReflection goalCheckInReflection({
  required List<Map<String, Object?>> userVoice,
  required List<GoalCheckInSummary> summaries,
  required AgentReportEntity? standingReport,
}) {
  final byEntryId = {
    for (final summary in summaries) summary.sourceEntryId: summary,
  };
  final shown = <String>[];
  final shownEntryIds = <String, String>{};
  for (final entry in userVoice) {
    final summary = byEntryId[entry['sourceEntryId']];
    if (summary == null) continue;
    final key = goalCheckInReflectionKey(summary);
    shown.add(key);
    shownEntryIds[summary.sourceEntryId] = key;
  }
  if (shown.isEmpty) return GoalCheckInReflection.none;

  final recorded =
      standingReport?.provenance[GoalReportProvenanceKeys.checkInsReflected];
  final reflected = {
    if (recorded is List)
      for (final key in recorded)
        if (key is String) key,
  };
  return GoalCheckInReflection(
    shown: shown,
    unreflectedEntryIds: {
      for (final MapEntry(key: entryId, value: key) in shownEntryIds.entries)
        if (!reflected.contains(key)) entryId,
    },
  );
}
