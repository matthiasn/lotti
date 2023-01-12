import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'journal_page_state.freezed.dart';

@freezed
class JournalPageState with _$JournalPageState {
  factory JournalPageState({
    required String match,
    required Set<String> tagIds,
    required bool starredEntriesOnly,
    required bool flaggedEntriesOnly,
    required bool privateEntriesOnly,
    required bool showPrivateEntries,
    required bool showTasks,
    required List<FilterBy?> selectedEntryTypes,
    required Set<String> fullTextMatches,
    required PagingController<int, JournalEntity> pagingController,
    required List<String> taskStatuses,
    required Set<String> selectedTaskStatuses,
  }) = _JournalPageState;
}
