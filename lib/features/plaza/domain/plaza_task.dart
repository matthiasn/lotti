/// Domain model for the project plaza prototype.
///
/// Pure Dart on purpose: the layout and generator layers depend only on this
/// file, so they can be unit-tested without Flutter and lifted out wholesale
/// if the prototype graduates.
library;

/// Lifecycle state of a task as the plaza renders it.
enum PlazaTaskState {
  /// Not started.
  open,

  /// Actively being worked.
  inProgress,

  /// Waiting on something else.
  blocked,

  /// Finished — green and quiet, lights off.
  done,

  /// Abandoned without completion.
  cancelled,
}

/// One task, projected into plaza terms.
///
/// Placement depends on `(createdAt, id)` alone — merge-stable under sync
/// (see the spec's invariant: nothing ever moves). Everything else drives
/// the surface only.
class PlazaTask {
  const PlazaTask({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.state,
    required this.progress,
    required this.checklistItems,
    required this.linkedTaskIds,
    required this.categoryColor,
    this.due,
    this.coverImageUrl,
    this.openChecklistItems = const [],
    this.deleted = false,
  });

  /// Placement tiebreak within a week bucket.
  final String id;

  /// Placement input: bucketed by week, ordered within the bucket.
  final DateTime createdAt;

  final String title;
  final PlazaTaskState state;
  final DateTime? due;

  /// 0..1 for checklist-bearing tasks; 0 when [checklistItems] is 0.
  final double progress;
  final int checklistItems;
  final List<String> linkedTaskIds;

  /// ARGB, kept as an int so this layer stays Flutter-free.
  final int categoryColor;

  /// Cover art for the facade, when the task has any (display only).
  final String? coverImageUrl;

  /// Titles of the still-open checklist items, shown on the facade.
  /// Drives building height together with the title (content-sized
  /// facades, no filler).
  final List<String> openChecklistItems;

  /// Deleted tasks leave a fenced empty lot; the street never closes up.
  final bool deleted;
}
