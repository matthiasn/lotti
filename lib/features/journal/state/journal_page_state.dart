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

/// Sort order options for task lists.
enum TaskSortOption {
  /// Sort by priority first (P0 > P1 > P2 > P3), then by date within each priority
  byPriority,

  /// Sort by creation date (newest first)
  byDate,
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
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
    @Default(true) bool showDueDate,
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
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
    @Default(true) bool showDueDate,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
