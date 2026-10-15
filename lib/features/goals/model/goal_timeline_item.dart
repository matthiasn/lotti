import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';

/// One thing the user has said about a goal, in the order they said it.
///
/// The timeline merges two stores: free-form check-ins are journal entries
/// linked to the goal, while daily reflections are agent-side records. Neither
/// is going to move, so the merge happens here, in a pure layer that can be
/// tested without a database or a widget tree.
@immutable
sealed class GoalTimelineItem {
  const GoalTimelineItem();

  /// When the user said it — the sort key for the whole rail.
  DateTime get at;

  /// Stable identity, used for widget keys and for opening the source.
  String get id;
}

/// A check-in the user made in their own words — spoken or written. Both are
/// journal entries linked to the goal, and both carry the time the user spent
/// on them as the entry's own span.
@immutable
sealed class GoalCheckIn extends GoalTimelineItem {
  const GoalCheckIn();

  /// The journal entry behind the beat.
  JournalEntity get entity;

  /// How long the user spent on this check-in: the recording for a spoken
  /// one, the counted writing session for a written one, or whatever the user
  /// corrected it to. Never negative — a span stored backwards is no time.
  Duration get timeSpent => goalCheckInTimeSpent(entity);
}

/// The check-in [entity] stands for, or null when it is not one.
///
/// The one rule for what counts as a check-in — shared by the goal's
/// timeline and the check-in time criterion, so what the rail shows is what
/// the goal counts. A deleted entry stays linked (links are not tombstoned
/// with their entry), so it is dropped here; a written entry needs words,
/// while a recording counts from the moment it is saved, before any
/// transcript lands.
GoalCheckIn? goalCheckInFrom(JournalEntity entity) {
  if (entity.isDeleted) return null;
  return switch (entity) {
    final JournalAudio audio => GoalAudioCheckIn(audio),
    final JournalEntry entry
        when (entry.entryText?.plainText.trim() ?? '').isNotEmpty =>
      GoalTextCheckIn(entry),
    _ => null,
  };
}

/// The time a check-in entry stands for, read from its own span.
///
/// The one rule the rail's chip and the check-in time criterion share, so the
/// minutes the user sees are the minutes the goal counts.
Duration goalCheckInTimeSpent(JournalEntity entity) {
  final span = entity.meta.dateTo.difference(entity.meta.dateFrom);
  return span.isNegative ? Duration.zero : span;
}

/// A spoken check-in: the headline case, and the reason the feature exists.
@immutable
class GoalAudioCheckIn extends GoalCheckIn {
  const GoalAudioCheckIn(this.audio);

  final JournalAudio audio;

  @override
  JournalEntity get entity => audio;

  @override
  DateTime get at => audio.meta.dateFrom;

  @override
  String get id => audio.meta.id;

  /// The transcript, once there is one. Absent while transcription is still
  /// running — which is normal, because the recording is saved first.
  String? get transcript {
    final text = audio.entryText?.plainText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}

/// A written check-in — the "Write instead" fallback.
@immutable
class GoalTextCheckIn extends GoalCheckIn {
  const GoalTextCheckIn(this.entry);

  final JournalEntry entry;

  @override
  JournalEntity get entity => entry;

  @override
  DateTime get at => entry.meta.dateFrom;

  @override
  String get id => entry.meta.id;

  String get text => entry.entryText?.plainText.trim() ?? '';
}

/// A recorded daily reflection, projected onto the same rail so the two halves
/// of "what I've said about this goal" read as one story.
@immutable
class GoalReflectionItem extends GoalTimelineItem {
  const GoalReflectionItem(this.record);

  final GoalAssessmentRecord record;

  @override
  DateTime get at => record.createdAt;

  @override
  String get id => record.id;
}
