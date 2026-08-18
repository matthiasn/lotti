import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';

/// Builds the goal timeline's item list from the two stores that hold it.
///
/// [entries] are the journal entries linked to the goal; [assessments] are the
/// agent-side daily reflections. Result is **newest first**, which is the way a
/// goal's story is read — the opposite of an event's, which runs forward
/// through a single day.
///
/// Only the reflection standing for each day appears, scoped to
/// [specVersionId]: a day reflected on three times is one beat, and a verdict
/// passed under superseded criteria must not be shown as a judgement of the
/// current ones.
///
/// A **null** [specVersionId] means the current spec is not known yet, and
/// withholds reflections entirely rather than showing every version's — the
/// underlying projection reads null as "no filter", which would flash old
/// verdicts while providers resolve and leave them standing on a health
/// error.
///
/// Entries that are not check-in kinds are dropped rather than rendered as
/// something they are not — AI responses and tasks are surfaced elsewhere.
List<GoalTimelineItem> goalTimelineItems({
  required List<JournalEntity> entries,
  required List<GoalAssessmentRecord> assessments,
  String? specVersionId,
}) {
  final items = <GoalTimelineItem>[
    for (final entity in entries) ?_checkIn(entity),
    if (specVersionId != null)
      for (final record in latestAssessmentsByDay(
        assessments,
        specVersionId: specVersionId,
      ).values)
        GoalReflectionItem(record),
  ];

  return items..sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    // Two things recorded in the same second still need a stable order, or
    // the rail reshuffles itself between rebuilds.
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
}

GoalTimelineItem? _checkIn(JournalEntity entity) {
  // A deleted check-in stays linked — the link is not tombstoned with the
  // entry — so without this the user's deleted words remain visible and
  // playable here long after they removed them.
  if (entity.isDeleted) return null;
  return switch (entity) {
    final JournalAudio audio => GoalAudioCheckIn(audio),
    final JournalEntry entry
        when (entry.entryText?.plainText.trim() ?? '').isNotEmpty =>
      GoalTextCheckIn(entry),
    _ => null,
  };
}

/// One labelled run of items per local calendar day, in the order [items]
/// arrived.
///
/// The label is produced by [labelForDay] so this stays locale-agnostic; the
/// caller decides whether a day reads as "TODAY" or "FRIDAY · 15 AUG".
List<({String label, List<GoalTimelineItem> items})> groupGoalItemsByDay(
  List<GoalTimelineItem> items, {
  required String Function(DateTime day) labelForDay,
}) {
  final groups = <({String label, List<GoalTimelineItem> items})>[];
  DateTime? currentDay;

  for (final item in items) {
    final local = item.at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      groups.add((label: labelForDay(day), items: <GoalTimelineItem>[]));
    }
    groups.last.items.add(item);
  }
  return groups;
}
