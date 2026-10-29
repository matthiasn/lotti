import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_search_hit.dart';

part 'journal_page_state.freezed.dart';
part 'journal_page_state.g.dart';

/// The task statuses selected by default (open work: not yet done, rejected, or
/// parked). The tasks list starts here; a selection that differs from this set
/// is a user-applied status filter.
const defaultSelectedTaskStatuses = {'OPEN', 'GROOMED', 'IN PROGRESS'};

/// Display filter options for journal entries.
enum DisplayFilter {
  starredEntriesOnly,
  flaggedEntriesOnly,
  privateEntriesOnly,
}

/// Search mode for the journal/tasks page.
enum SearchMode {
  /// Traditional FTS5 full-text search.
  fullText,

  /// Vector-based semantic search via Ollama embeddings.
  vector,
}

/// Filter for agent assignment on tasks.
enum AgentAssignmentFilter {
  /// No filtering — show all tasks regardless of agent assignment.
  all,

  /// Only tasks that have an agent_task link.
  hasAgent,

  /// Only tasks that do NOT have an agent_task link.
  noAgent,
}

/// Narrows the task list to open tasks by where their due date falls
/// relative to today — the "Overdue" and "Due today" smart views above the
/// list.
///
/// Day-granular in the device's local time zone, like every other due-date
/// read-out: a task due at 09:00 today is due today at 18:00, not overdue.
/// Closed tasks (done or rejected) are never overdue and never due, so either
/// narrowing admits open work only, whatever statuses the filter selects.
enum TaskDueFilter {
  /// No due-date constraint.
  all,

  /// Open tasks whose due date is today.
  dueToday,

  /// Open tasks whose due date is before today.
  overdue,
}

/// Sort order options for task lists.
enum TaskSortOption {
  /// Sort by priority first (P0 > P1 > P2 > P3), then by date within each priority
  byPriority,

  /// Sort by creation date (newest first)
  byDate,

  /// Sort by due date (soonest first, then tasks without due dates)
  byDueDate,
}

/// Immutable state for the journal page controller.
/// Immutable view-model for the journal/tasks page, exposed by
/// `JournalPageController`.
///
/// Bundles everything the page UI reads: the search query/mode, the active
/// display filters and per-facet selections (categories, projects, labels,
/// priorities, task statuses, entry types), sort and card-display toggles, the
/// live [PagingController] that feeds the infinite list, and vector-search
/// telemetry (in-flight flag, elapsed, result count, per-id distances). The
/// `pagingController` is excluded from JSON. The persisted subset lives in
/// [TasksFilter].
@freezed
abstract class JournalPageState with _$JournalPageState {
  const factory JournalPageState({
    @Default('') String match,
    @Default(<DisplayFilter>{}) Set<DisplayFilter> filters,
    @Default(false) bool showPrivateEntries,
    @Default(false) bool showTasks,
    @Default([]) List<String> selectedEntryTypes,

    /// Entry types currently permitted by active feature flags (events, habits,
    /// dashboards). The un-narrowed selection equals this set; a strict subset
    /// means the user deselected an allowed type. Distinct from a flag-hidden
    /// type, which never appears here at all.
    @Default([]) List<String> allowedEntryTypes,
    @Default(<String>{}) Set<String> fullTextMatches,
    @JsonKey(includeFromJson: false, includeToJson: false)
    PagingController<int, JournalEntity>? pagingController,
    @Default([]) List<String> taskStatuses,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedProjectIds,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
    @Default(true) bool showDueDate,
    @Default(true) bool showCoverArt,
    @Default(true) bool showProjectsHeader,
    @Default(SearchMode.fullText) SearchMode searchMode,
    @Default(false) bool showDistances,
    @Default(AgentAssignmentFilter.all)
    AgentAssignmentFilter agentAssignmentFilter,
    @Default(TaskDueFilter.all) TaskDueFilter dueFilter,
    @Default(false) bool enableVectorSearch,
    @Default(false) bool enableProjects,
    @Default(false) bool vectorSearchInFlight,
    Duration? vectorSearchElapsed,
    @Default(0) int vectorSearchResultCount,
    @Default(<String, double>{}) Map<String, double> vectorSearchDistances,

    /// The tasks the live full-text search found, by task id, with where
    /// each matched — the snippet its result card shows.
    @Default(<String, TaskSearchHit>{})
    Map<String, TaskSearchHit> taskSearchHits,
  }) = _JournalPageState;
}

/// Filter configuration for persistence.
///
/// Used by:
/// - JournalPageController for persisting filter state
/// - CalendarCategoryVisibilityController for reading shared category visibility
@freezed
abstract class TasksFilter with _$TasksFilter {
  const factory TasksFilter({
    @Default(<String>{}) Set<String> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedProjectIds,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    // An option a newer build added decodes to the default rather than
    // failing the whole filter: a saved filter synced from that build would
    // otherwise be an undecodable message, which the receiver skips for good.
    @JsonKey(unknownEnumValue: TaskSortOption.byPriority)
    @Default(TaskSortOption.byPriority)
    TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
    @Default(true) bool showDueDate,
    @Default(true) bool showCoverArt,
    @Default(true) bool showProjectsHeader,
    @Default(false) bool showDistances,
    @JsonKey(unknownEnumValue: AgentAssignmentFilter.all)
    @Default(AgentAssignmentFilter.all)
    AgentAssignmentFilter agentAssignmentFilter,
    @JsonKey(unknownEnumValue: TaskDueFilter.all)
    @Default(TaskDueFilter.all)
    TaskDueFilter dueFilter,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
