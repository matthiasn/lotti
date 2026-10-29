import 'package:meta/meta.dart';

/// A task a full-text search found, and where: the snippet of its best
/// match, and the kind of entity that was in — the task itself, or something
/// belonging to it (an entry, a checklist item, …).
@immutable
class TaskSearchHit {
  const TaskSearchHit({
    required this.taskId,
    required this.snippet,
    required this.matchedType,
  });

  final String taskId;

  /// A few words around the match, the matched ones marked (see
  /// `lib/database/search_hit.dart`).
  final String snippet;

  /// The journal `type` of the entity the snippet is from.
  final String matchedType;

  @override
  bool operator ==(Object other) =>
      other is TaskSearchHit &&
      other.taskId == taskId &&
      other.snippet == snippet &&
      other.matchedType == matchedType;

  @override
  int get hashCode => Object.hash(taskId, snippet, matchedType);
}
