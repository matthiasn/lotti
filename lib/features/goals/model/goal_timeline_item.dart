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

/// A spoken check-in: the headline case, and the reason the feature exists.
@immutable
class GoalAudioCheckIn extends GoalTimelineItem {
  const GoalAudioCheckIn(this.audio);

  final JournalAudio audio;

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
class GoalTextCheckIn extends GoalTimelineItem {
  const GoalTextCheckIn(this.entry);

  final JournalEntry entry;

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
