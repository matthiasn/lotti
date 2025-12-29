import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'journal_page_state.freezed.dart';
part 'journal_page_state.g.dart';

enum DisplayFilter {
  starredEntriesOnly,
  flaggedEntriesOnly,
  privateEntriesOnly,
}

/// Sort order options for task lists
enum TaskSortOption {
  /// Sort by priority first (P0 > P1 > P2 > P3), then by date within each priority
  byPriority,

  /// Sort by creation date (newest first)
  byDate,
}

@freezed
abstract class JournalPageState with _$JournalPageState {
  factory JournalPageState({
    required String match,
    required Set<String> tagIds,
    required Set<DisplayFilter> filters,
    required bool showPrivateEntries,
    required bool showTasks,
    required List<String> selectedEntryTypes,
    required Set<String> fullTextMatches,
    required PagingController<int, JournalEntity>? pagingController,
    required List<String> taskStatuses,
    required Set<String> selectedTaskStatuses,
    required Set<String?> selectedCategoryIds,
    required Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _JournalPageState;
}

@freezed
abstract class TasksFilter with _$TasksFilter {
  factory TasksFilter({
    @Default(<String>{}) Set<String> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
