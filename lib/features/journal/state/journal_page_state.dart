import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'journal_page_state.freezed.dart';
part 'journal_page_state.g.dart';

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
@freezed
abstract class JournalPageState with _$JournalPageState {
  const factory JournalPageState({
    @Default('') String match,
    @Default(<String>{}) Set<String> tagIds,
    @Default(<DisplayFilter>{}) Set<DisplayFilter> filters,
    @Default(false) bool showPrivateEntries,
    @Default(false) bool showTasks,
    @Default([]) List<String> selectedEntryTypes,
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
    @Default(false) bool enableVectorSearch,
    @Default(false) bool enableProjects,
    @Default(false) bool vectorSearchInFlight,
    Duration? vectorSearchElapsed,
    @Default(0) int vectorSearchResultCount,
    @Default(<String, double>{}) Map<String, double> vectorSearchDistances,
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
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
    @Default(true) bool showDueDate,
    @Default(true) bool showCoverArt,
    @Default(true) bool showProjectsHeader,
    @Default(false) bool showDistances,
    @Default(AgentAssignmentFilter.all)
    AgentAssignmentFilter agentAssignmentFilter,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
