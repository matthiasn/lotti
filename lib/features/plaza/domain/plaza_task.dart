/// GPU-independent presentation data for task buildings and project portals.
///
/// Pure Dart on purpose: alternative layouts can consume these facts without
/// a GPU or access to the journal database.
library;

/// Lifecycle state of a task as the plaza renders it.
enum PlazaTaskState {
  /// Not started.
  open,

  /// Actively being worked.
  inProgress,

  /// Waiting on something else.
  blocked,

  /// Finished — green and quiet.
  done,

  /// Abandoned without completion.
  cancelled,
}

enum PlazaProjectState { open, active, monitoring, onHold, completed, archived }

/// Aggregate facts on a category's project portal. A portal has no editable
/// checklist: its progress counts completed tasks in the project.
class PlazaProjectInfo {
  const PlazaProjectInfo({
    required this.state,
    required this.taskCount,
    required this.doneCount,
    required this.attentionCount,
    required this.overdueCount,
  });

  final PlazaProjectState state;
  final int taskCount;
  final int doneCount;
  final int attentionCount;
  final int overdueCount;
}

/// One task, projected into plaza terms.
///
/// Timeline placement is ordered by `(createdAt, id)`. Generator parameters
/// control density and completed-work setbacks; category portals use explicit
/// avenue assignments while keeping the real creation dates here.
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
    this.openChecklistItemIds = const [],
    this.deleted = false,
    this.priority = 2,
    this.lastActivityAt,
    this.project,
  });

  /// Placement tiebreak within a week bucket.
  final String id;

  /// Placement input: bucketed by week, ordered within the bucket.
  final DateTime createdAt;

  final String title;
  final PlazaTaskState state;
  final PlazaProjectInfo? project;
  final DateTime? due;

  /// 0..1 for checklist-bearing tasks; 0 when [checklistItems] is 0.
  final double progress;
  final int checklistItems;

  /// Full progress, independent of the capped list of open preview items.
  int get completedItems => (progress.clamp(0, 1) * checklistItems).round();
  final List<String> linkedTaskIds;

  /// ARGB, kept as an int so this layer stays Flutter-free.
  final int categoryColor;

  /// Cover art for the facade, when the task has any (display only).
  final String? coverImageUrl;

  /// Titles of the still-open checklist items, shown on the facade.
  final List<String> openChecklistItems;

  /// Persisted IDs in the same order as [openChecklistItems]. Synthetic
  /// scene fixtures can omit them; app actions must use these IDs rather
  /// than treating a preview position as durable item identity.
  final List<String> openChecklistItemIds;

  /// Synthetic fixtures may retain a deleted task as a fenced empty lot.
  /// Live repository projections omit deleted tasks entirely.
  final bool deleted;

  /// 0 = urgent, 1 = high, 2 = medium, 3 = low (mirrors `TaskPriority`).
  /// Drives building height and the attention score.
  final int priority;

  /// When the task was last touched; null means "at creation". Drives the
  /// stale-in-progress attention signal.
  final DateTime? lastActivityAt;

  /// The instant the task was last worked on, for attention scoring.
  DateTime get activityAt => lastActivityAt ?? createdAt;

  /// Signal weight for building height: how much the task is connected to
  /// and how much of it is still open.
  int get heft =>
      linkedTaskIds.length + checklistItems + openChecklistItems.length;
}
