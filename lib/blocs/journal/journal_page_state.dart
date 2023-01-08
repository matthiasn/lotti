import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';

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
    required List<FilterBy?> selectedEntryTypes,
    required Set<String> fullTextMatches,
  }) = _JournalPageState;
}
