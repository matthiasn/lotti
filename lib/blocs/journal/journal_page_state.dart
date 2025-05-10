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

@freezed
class JournalPageState with _$JournalPageState {
  factory JournalPageState({
    required String match,
    required Set<String> tagIds,
    required Set<DisplayFilter> filters,
    required bool showPrivateEntries,
    required bool showTasks,
    required bool taskAsListView,
    required List<String> selectedEntryTypes,
    required Set<String> fullTextMatches,
    required PagingController<int, JournalEntity>? pagingController,
    required List<String> taskStatuses,
    required Set<String> selectedTaskStatuses,
    required Set<String?> selectedCategoryIds,
  }) = _JournalPageState;
}

@freezed
class TasksFilter with _$TasksFilter {
  factory TasksFilter({
    required Set<String> selectedCategoryIds,
    required Set<String> selectedTaskStatuses,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
