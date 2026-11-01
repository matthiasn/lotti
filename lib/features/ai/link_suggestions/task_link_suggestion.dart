import 'package:flutter/foundation.dart';
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';

/// A link between two tasks that a task's own notes or log suggest, waiting
/// for the user to accept or dismiss it.
///
/// Nothing is written for a suggestion: it exists only until the user
/// decides, and accepting it is what creates the link.
@immutable
class TaskLinkSuggestion {
  const TaskLinkSuggestion({
    required this.sourceTaskId,
    required this.targetTaskId,
    required this.targetTitle,
    required this.relation,
    required this.distance,
    required this.mention,
    required this.mentionedAt,
  });

  /// The task whose text mentioned the other one; the relation's subject.
  final String sourceTaskId;

  /// The task the mention most likely meant.
  final String targetTaskId;

  /// The target's title when the suggestion was made, for the sentence the
  /// suggestion row reads.
  final String targetTitle;

  /// "This task …" — read with [sourceTaskId] as the subject.
  final DirectedRelation relation;

  /// How far the target was from the mention, by meaning: the cosine
  /// distance of its nearest embedding, lower meaning closer.
  final double distance;

  /// The sentence that prompted it.
  final PriorWorkMention mention;

  /// When the entry holding [mention] was written — the task's own date for
  /// its notes.
  final DateTime mentionedAt;

  /// Identity of the suggestion: one per pair of tasks, whatever relation it
  /// proposes. Dismissing it dismisses the pair, so a reworded mention of the
  /// same task does not bring it back under another relation.
  String get key => pairKey(sourceTaskId, targetTaskId);

  /// The [key] of a suggestion between [sourceTaskId] and [targetTaskId].
  static String pairKey(String sourceTaskId, String targetTaskId) =>
      '$sourceTaskId|$targetTaskId';

  @override
  bool operator ==(Object other) =>
      other is TaskLinkSuggestion &&
      other.sourceTaskId == sourceTaskId &&
      other.targetTaskId == targetTaskId &&
      other.targetTitle == targetTitle &&
      other.relation == relation &&
      other.distance == distance &&
      other.mention == mention &&
      other.mentionedAt == mentionedAt;

  @override
  int get hashCode => Object.hash(
    sourceTaskId,
    targetTaskId,
    targetTitle,
    relation,
    distance,
    mention,
    mentionedAt,
  );

  @override
  String toString() =>
      'TaskLinkSuggestion($sourceTaskId ${relation.wireName} $targetTaskId, '
      'distance ${distance.toStringAsFixed(3)})';
}

/// One related task a search by meaning found, before it is read back.
typedef RelatedTaskHit = ({String taskId, double distance});

/// What one scan of a task found, and what the next one can reuse.
@immutable
class TaskLinkSuggestionScan {
  const TaskLinkSuggestionScan({
    required this.suggestions,
    required this.watchedIds,
    this.searches = const {},
  });

  static const empty = TaskLinkSuggestionScan(
    suggestions: [],
    watchedIds: {},
  );

  /// Nearest first.
  final List<TaskLinkSuggestion> suggestions;

  /// The ids whose update notifications can change the outcome: the task,
  /// its text entries and the suggested tasks.
  final Set<String> watchedIds;

  /// The searches this scan ran or reused, by query. The next scan of the
  /// same task reuses them, so an edit elsewhere in the task embeds only the
  /// sentences that changed. Hits are ids and distances only; the tasks are
  /// read again on every scan, so a rename, a status change or a deletion is
  /// never served from here.
  final Map<String, List<RelatedTaskHit>> searches;
}
